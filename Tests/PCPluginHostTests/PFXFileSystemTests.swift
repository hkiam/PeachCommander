// SPDX-License-Identifier: Apache-2.0
// PFXFileSystemTests.swift - Host PFX file-system adapter driven through the real
// SampleFS C plugin (Plugins/SampleFS/sample_fs.c): directory enumeration,
// empty/absent dirs, buffer-safe names, and mid-stream cancellation (F-232).
//
// Plus `PFXProgressSink`, the channel a plugin reports transfer progress on. It is tested here
// rather than through a plugin on purpose: what needs proving is the concurrency contract — the
// plugin calls it from its connection queue, never the main thread — and no plugin is needed to
// show that.

import XCTest
import PCVFS
@testable import PCPluginHost

/// The transfer progress channel, on its own.
final class PFXProgressSinkTests: XCTestCase {
    func test_withNoHandler_theAnswerIsCarryOn() {
        // The default matters more than it looks. `report` is called by every plugin that bothers to
        // report progress, including when nothing is listening — and answering "abort" to an absent
        // listener would cancel every transfer in the app.
        let sink = PFXProgressSink()
        XCTAssertTrue(sink.report("file.txt", 0))
        XCTAssertTrue(sink.report("file.txt", 99))
    }

    func test_theHandlerSeesTheNameAndPercentAndCanStopTheTransfer() {
        let sink = PFXProgressSink()
        var seen: [(String, Int)] = []
        sink.begin { name, pct in
            seen.append((name, pct))
            return pct < 50
        }
        XCTAssertTrue(sink.report("big.bin", 10))
        XCTAssertTrue(sink.report("big.bin", 49))
        XCTAssertFalse(sink.report("big.bin", 50), "the handler asked to stop and was not believed")
        XCTAssertEqual(seen.map(\.1), [10, 49, 50])
    }

    func test_endRemovesTheHandler_soTheNextTransferIsNotCancelledByTheLastOne() {
        // One slot, reused for every transfer on the connection. A handler left behind after its
        // transfer finished would answer for the next one — and a handler that had said "abort"
        // would abort a transfer nobody cancelled.
        let sink = PFXProgressSink()
        sink.begin { _, _ in false }
        XCTAssertFalse(sink.report("first", 1))
        sink.end()
        XCTAssertTrue(sink.report("second", 1))
    }

    func test_reportingFromAnotherThreadDoesNotTrap() {
        // The whole reason this type is not main-actor isolated: the plugin reports from the queue
        // its transfer is running on. Its sibling callbacks in PFXHostBridge go through
        // `MainActor.assumeIsolated`, which does not hop off the main thread — it traps.
        let sink = PFXProgressSink()
        let counter = NSLock()
        var count = 0
        sink.begin { _, _ in counter.lock(); count += 1; counter.unlock(); return true }
        let queue = DispatchQueue(label: "test.pfx.progress")
        let done = expectation(description: "reported off the main thread")
        queue.async {
            XCTAssertFalse(Thread.isMainThread)
            for pct in 0...20 { _ = sink.report("f", pct) }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        counter.lock(); let final = count; counter.unlock()
        XCTAssertEqual(final, 21)
    }
}

final class PFXFileSystemTests: XCTestCase {
    private var dir: URL!
    private var lib: PluginLibrary!

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    override func setUpWithError() throws {
        let clang = "/usr/bin/clang"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: clang), "clang unavailable")
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("samplefs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let src = repoRoot.appendingPathComponent("Plugins/SampleFS/sample_fs.c")
        let sdk = repoRoot.appendingPathComponent("Plugins/SDK")
        let out = dir.appendingPathComponent("libsamplefs.dylib")
        let p = Process(); p.executableURL = URL(fileURLWithPath: clang)
        p.arguments = ["-dynamiclib", "-std=c11", "-I", sdk.path, "-o", out.path, src.path]
        let pipe = Pipe(); p.standardError = pipe
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let e = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            // A compiler that RAN and refused this is a failure, not a skip. The skip belongs to a
            // machine without clang; reusing it here means the day SampleFS stops compiling, this
            // file reports success and says nothing.
            XCTFail("SampleFS did not compile:\n\(e)")
            throw NSError(domain: "PFXFileSystemTests", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "build failed"])
        }
        let hooks = ["SampleFsOpenFinds", "SampleFsFindNextCalls", "SampleFsResetCounters",
                     "SampleFsDisconnects"]
        guard case .success(let lib) = PluginLibrary.open(
            path: out.path, required: PFXSymbols.required, optional: PFXSymbols.optional + hooks) else {
            XCTFail("SampleFS compiled but could not be loaded")
            throw NSError(domain: "PFXFileSystemTests", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "load failed"])
        }
        self.lib = lib
    }

    override func tearDownWithError() throws { if let dir { try? FileManager.default.removeItem(at: dir) } }

    // MARK: - Fixture wiring

    private func makeFS() -> PFXFileSystem {
        typealias ConnectFn = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
        let conn = unsafeBitCast(lib.symbol("PfxConnect")!, to: ConnectFn.self)(nil)!
        return PFXFileSystem(plugin: PFXPlugin(library: lib), conn: conn,
                             fsID: "samplefs", capabilities: [.read], retaining: nil,
                             contentQualifier: "sfs")
    }

    func test_contentFacet_fieldsAndValues() async throws {
        let fs = makeFS()
        XCTAssertTrue(fs.isVolatile)
        XCTAssertEqual(fs.contentFields.map(\.name), ["kind", "score"])
        XCTAssertEqual(fs.qualifiedContentFields.map(\.qualifiedID), ["sfs.kind", "sfs.score"])
        // readme.txt -> kind "file", score = length of "readme.txt" (10).
        XCTAssertEqual(fs.contentDisplay(fieldID: "sfs.kind", path: "/readme.txt"), "file")
        XCTAssertEqual(fs.contentDisplay(fieldID: "sfs.score", path: "/readme.txt"), "10")
        XCTAssertEqual(fs.contentDisplay(fieldID: "sfs.kind", path: "/sub"), "dir")
        // A field this mount doesn't own resolves to nil.
        XCTAssertNil(fs.contentDisplay(fieldID: "other.x", path: "/readme.txt"))
    }

    private func vpath(_ path: String) -> VFSPath { VFSPath(filesystemId: "samplefs", path: path) }

    private func hook(_ name: String) -> Int {
        guard let ptr = lib.symbol(name) else { return -1 }
        typealias Fn = @convention(c) () -> Int32
        return Int(unsafeBitCast(ptr, to: Fn.self)())
    }

    private func collect(_ fs: PFXFileSystem, _ path: String) async throws -> [VFSEntry] {
        var all: [VFSEntry] = []
        for try await batch in fs.list(vpath(path)) { all += batch.entries }
        return all
    }

    /// Wait until the plugin reports no live `PfxFindFirst` handles.
    ///
    /// `SampleFsOpenFinds` counts *live* handles, and PFXFileSystem enumerates on a
    /// background queue, closing the handle from the stream's `onTermination` — so
    /// the close can land after `collect` has already returned. Asserting the count
    /// immediately therefore fails intermittently and looks like a leak that isn't
    /// one. Poll instead of sleeping a fixed amount: fast in the normal case, still
    /// bounded if the handle really does leak.
    private func waitForNoOpenHandles(timeout ticks: Int = 200) async throws {
        var waited = 0
        while hook("SampleFsOpenFinds") != 0, waited < ticks {
            try await Task.sleep(nanoseconds: 5_000_000); waited += 1
        }
    }

    // MARK: - Tests

    func test_list_root_returnsEntries_filteringDotDirs() async throws {
        let fs = makeFS()
        let names = try await collect(fs, "/").map(\.name).sorted()
        XCTAssertTrue(names.contains("readme.txt"), "root: \(names)")
        XCTAssertTrue(names.contains("sub"))
        XCTAssertTrue(names.contains("empty"))
        // The find-handle must be released once enumeration completes.
        XCTAssertEqual(hook("SampleFsOpenFinds"), 0, "find handle leaked")
    }

    func test_stat_and_kinds() async throws {
        let fs = makeFS()
        let entries = try await collect(fs, "/")
        let sub = try XCTUnwrap(entries.first { $0.name == "sub" })
        XCTAssertEqual(sub.kind, .directory)
        let readme = try XCTUnwrap(entries.first { $0.name == "readme.txt" })
        XCTAssertEqual(readme.kind, .file)
        XCTAssertEqual(readme.size, 12)

        let st = try await fs.stat(vpath("/readme.txt"))
        XCTAssertEqual(st.name, "readme.txt")
        XCTAssertEqual(st.size, 12)
    }

    func test_nonTerminatedName_isReadBounded() async throws {
        // The sentinel entry fills the whole 1024-byte name buffer with 'a' and no
        // NUL; the host must read exactly 1024 chars without an out-of-bounds read.
        let fs = makeFS()
        let entries = try await collect(fs, "/")
        let big = try XCTUnwrap(entries.first { $0.name.count == 1024 },
                                "expected a 1024-char name, got: \(entries.map { $0.name.count })")
        XCTAssertTrue(big.name.allSatisfy { $0 == "a" })
    }

    func test_emptyDirectory_yieldsNoEntries() async throws {
        let fs = makeFS()
        let entries = try await collect(fs, "/empty")
        XCTAssertTrue(entries.isEmpty, "empty dir should list nothing: \(entries.map(\.name))")
        try await waitForNoOpenHandles()
        XCTAssertEqual(hook("SampleFsOpenFinds"), 0, "listing an empty dir leaked its find handle")
    }

    func test_missingDirectory_throwsNotFound() async throws {
        let fs = makeFS()
        do {
            _ = try await collect(fs, "/does-not-exist")
            XCTFail("expected notFound")
        } catch let e as VFSError {
            if case .notFound = e {} else { XCTFail("expected notFound, got \(e)") }
        }
    }

    // MARK: - The disconnect contract (pfx.h)
    //
    // Disconnect used to happen in `deinit`, fire-and-forget, so `cm_FtpDisconnect` skipped plugin
    // mounts entirely and a plugin had no reliable moment to let go. Now the host asks for it — and
    // asking is what makes these three things worth pinning: `PfxDisconnect` frees the plugin's own
    // state, so a second call is a double free, and any later call would be reading memory the
    // plugin has already handed back.

    private func resetCounters() {
        typealias Reset = @convention(c) () -> Void
        unsafeBitCast(lib.symbol("SampleFsResetCounters")!, to: Reset.self)()
    }

    func test_disconnect_reachesThePluginExactlyOnce() async throws {
        resetCounters()
        do {
            let fs = makeFS()
            await fs.disconnect()
            XCTAssertEqual(hook("SampleFsDisconnects"), 1, "the plugin was not told to disconnect")
            // Asking twice is what a second panel leaving the same mount looks like.
            await fs.disconnect()
            XCTAssertEqual(hook("SampleFsDisconnects"), 1, "disconnected twice")
        }
        // …and the object going away afterwards must not free the connection a second time. This is
        // the double free the old `deinit`-only design would have caused the moment anything else
        // called disconnect.
        try await settle()
        XCTAssertEqual(hook("SampleFsDisconnects"), 1, "deinit disconnected an already-closed mount")
    }

    func test_deallocWithoutAnExplicitDisconnect_stillTellsThePlugin() async throws {
        // The other half: nothing that used to work may have stopped. A mount simply dropped —
        // no command, no quit — is still handed back.
        resetCounters()
        do { _ = makeFS() }
        try await settle()
        XCTAssertEqual(hook("SampleFsDisconnects"), 1, "a dropped mount never reached PfxDisconnect")
    }

    func test_afterDisconnect_callsFailInsteadOfReachingTheFreedConnection() async throws {
        resetCounters()
        let fs = makeFS()
        await fs.disconnect()

        // Every entry point that would otherwise pass the handle back into the plugin. Each of
        // these is a use-after-free if it is not refused — the connection has been freed.
        do {
            _ = try await fs.stat(vpath("/readme.txt"))
            XCTFail("stat reached a disconnected mount")
        } catch let e as VFSError {
            XCTAssertEqual(e, .connectionLost(retryable: false))
        }
        do {
            _ = try await collect(fs, "/")
            XCTFail("list reached a disconnected mount")
        } catch let e as VFSError {
            XCTAssertEqual(e, .connectionLost(retryable: false))
        }
        // The column read has nowhere to report an error to, so it answers with an empty cell
        // rather than a stale value — and, above all, without calling the plugin.
        XCTAssertNil(fs.contentDisplay(fieldID: "sfs.kind", path: "/readme.txt"))
        XCTAssertNil(fs.lookup(query: "anything"))
        XCTAssertEqual(hook("SampleFsDisconnects"), 1, "a call after disconnect re-entered the plugin")
    }

    /// Give the deallocation and its queued `PfxDisconnect` a moment to land.
    ///
    /// Polling rather than a fixed sleep, for the same reason `waitForNoOpenHandles` does: the
    /// disconnect is queued on the mount's serial queue, so asserting immediately is a race that
    /// fails now and then and reads as a leak.
    private func settle(timeout ticks: Int = 200) async throws {
        var waited = 0
        while hook("SampleFsDisconnects") == 0, waited < ticks {
            try await Task.sleep(nanoseconds: 5_000_000); waited += 1
        }
        try await Task.sleep(nanoseconds: 20_000_000)   // and a beat for a *second*, wrong, call
    }

    func test_cancellingMidStream_stopsEnumeration_andClosesHandle() async throws {
        typealias Reset = @convention(c) () -> Void
        unsafeBitCast(lib.symbol("SampleFsResetCounters")!, to: Reset.self)()
        let fs = makeFS()
        // Read only the first batch of the 1000-entry "/big" dir, then stop.
        var first = 0
        for try await batch in fs.list(vpath("/big")) {
            first = batch.entries.count
            break
        }
        XCTAssertGreaterThan(first, 0)
        // The handle should be closed and enumeration must not have run to the end.
        try await waitForNoOpenHandles()
        XCTAssertEqual(hook("SampleFsOpenFinds"), 0, "cancelled listing leaked its find handle")
        XCTAssertLessThan(hook("SampleFsFindNextCalls"), 1000, "enumeration did not stop early on cancel")
    }
}
