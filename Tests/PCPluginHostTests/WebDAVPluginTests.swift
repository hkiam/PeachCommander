// SPDX-License-Identifier: Apache-2.0
// WebDAVPluginTests.swift - The shipped WebDAV plugin, end to end against a real socket.
//
// The plugin had no automated coverage at all: it was built, installed, and exercised only by
// someone connecting to a server by hand. So every part of it — the PROPFIND body, the XML parse,
// the href-to-name mapping, the host adapter over it — was trusted rather than checked, and a
// regression in any of them would have surfaced as "WebDAV is broken" from a user.
//
// This builds the real plugin the way Tools/build-pfx-plugins.sh does, points it at a minimal DAV
// origin (Fixtures/davserver.py), and drives it through `PFXFileSystem` — the same path the app
// uses. Skips rather than fails when swiftc or python3 is unavailable, as the other
// plugin-building tests here do.
//
// The write half of the plugin — `PfxPutFile`, `PfxMkDir`, `PfxRenMov` — was in the same position
// the whole plugin used to be in: written, shipped, and never executed by a test. It also had no
// route from the panel, so nothing exercised it by accident either. The tests at the bottom of this
// file cover both halves of that: the operations themselves, and the host conformances that decide
// whether a keystroke can reach them.

import XCTest
import PCVFS
import CPFX
@testable import PCPluginHost

/// The config root the stub host hands the plugin. A file-scope variable because a `@convention(c)`
/// callback cannot capture, and this has to be readable from inside one.
private nonisolated(unsafe) var stubConfigRoot = ""

final class WebDAVPluginTests: XCTestCase {
    private var dir: URL!
    private var serving: URL!
    private var server: Process!
    private var port: Int = 0
    private var lib: PluginLibrary!
    private var inited: PFXPlugin!

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("webdav-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        try buildPlugin()
        try startServer()
        // The plugin's connect facet reads this instead of showing its modal dialog. Set on the
        // test process, which is the process whose environment `PfxConnect` inspects.
        setenv("PC_WEBDAV_URL", "http://127.0.0.1:\(port)/", 1)
        // Tell the plugin where "configuration" is before anything connects. Not optional politeness:
        // connecting appends to the site list, so without this every run of these tests would write a
        // throwaway localhost URL into the developer's own WebDAV history.
        initPlugin(configRoot: dir.appendingPathComponent("config"))
    }

    override func tearDownWithError() throws {
        unsetenv("PC_WEBDAV_URL")
        server?.terminate()
        if let dir { try? FileManager.default.removeItem(at: dir) }
    }

    // MARK: - Fixture wiring

    private func buildPlugin() throws {
        // Compiled once per test run, copied per test — see CachedPluginBuild.
        let out = try CachedPluginBuild.freshBuild(key: "webdav", into: dir) { cache in
            let swiftc = "/usr/bin/swiftc"
            try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: swiftc), "swiftc unavailable")
            let out = cache.appendingPathComponent("libwebdav.dylib")
            let p = Process()
            p.executableURL = URL(fileURLWithPath: swiftc)
            p.arguments = [
                "-emit-library", "-module-name", "WebDAV",
                "-framework", "AppKit",
                "-import-objc-header", repoRoot.appendingPathComponent("Plugins/WebDAV/WebDAVBridging.h").path,
                "-Xcc", "-I\(repoRoot.appendingPathComponent("Plugins/SDK").path)",
                "-o", out.path,
                repoRoot.appendingPathComponent("Plugins/WebDAV/webdav.swift").path,
                repoRoot.appendingPathComponent("Plugins/SDK/PluginLoc.swift").path,
            ]
            let pipe = Pipe(); p.standardError = pipe
            try p.run(); p.waitUntilExit()
            // Skipped only when there is no compiler. A compiler that ran and refused the plugin is a
            // failure: treating it as a skip means the day the plugin stops compiling, this file reports
            // success and says nothing. The failure is cached, so every test still goes red.
            guard p.terminationStatus == 0 else {
                let e = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                throw PluginBuildFailure(description: "the WebDAV plugin did not compile:\n\(e)")
            }
            return out
        }
        guard case .success(let lib) = PluginLibrary.open(
            path: out.path, required: PFXSymbols.required, optional: PFXSymbols.optional) else {
            throw PluginBuildFailure(description: "the WebDAV plugin compiled but could not be loaded")
        }
        self.lib = lib
    }

    private func startServer() throws {
        let python = "/usr/bin/python3"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: python), "python3 unavailable")
        serving = dir.appendingPathComponent("root")
        try FileManager.default.createDirectory(
            at: serving.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try Data("hello webdav".utf8).write(to: serving.appendingPathComponent("readme.txt"))
        try Data("nested".utf8).write(to: serving.appendingPathComponent("docs/note.txt"))

        port = try Self.freePort()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: python)
        p.arguments = [URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/davserver.py").path, serving.path, String(port)]
        p.standardOutput = Pipe(); p.standardError = Pipe()
        try p.run()
        server = p
        try waitForServer()
    }

    /// A port nobody is using, taken by binding one and letting go — the usual race, and the usual
    /// answer to it, which is that nothing else on a test machine is racing us for it.
    private static func freePort() throws -> Int {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(sock) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = 0
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { throw XCTSkip("could not reserve a port") }
        var out = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &out) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(sock, $0, &len) }
        }
        return Int(UInt16(bigEndian: out.sin_port))
    }

    /// Poll until the origin answers, rather than sleeping a guessed amount: a fixed wait is either
    /// slow or occasionally short, and "occasionally short" reads as the plugin failing to connect.
    private func waitForServer() throws {
        let url = URL(string: "http://127.0.0.1:\(port)/")!
        for _ in 0..<200 {
            var request = URLRequest(url: url)
            request.httpMethod = "OPTIONS"
            request.timeoutInterval = 1
            let done = DispatchSemaphore(value: 0)
            var ok = false
            URLSession.shared.dataTask(with: request) { _, response, _ in
                ok = (response as? HTTPURLResponse)?.statusCode == 200
                done.signal()
            }.resume()
            _ = done.wait(timeout: .now() + 2)
            if ok { return }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw XCTSkip("the DAV origin never came up")
    }

    /// Drive `PfxInit` with a stub host that answers `configRoot` and nothing else.
    ///
    /// `inited` keeps the `PFXPlugin` alive for the whole test: it owns the services table the
    /// plugin has been handed, and the ABI lets the plugin keep reading it.
    private func initPlugin(configRoot: URL) {
        stubConfigRoot = configRoot.path
        var s = PfxHostServices()
        s.getContext = { _, key, out, maxlen in
            guard let key, let out, maxlen > 0, String(cString: key) == "configRoot" else { return 0 }
            _ = stubConfigRoot.withCString { strlcpy(out, $0, Int(maxlen)) }
            return 1
        }
        let plugin = PFXPlugin(library: lib)
        plugin.initialize(services: s)
        inited = plugin
    }

    private var sitesFile: URL {
        dir.appendingPathComponent("config/webdav/sites.json")
    }

    private func makeFS(progressSink: PFXProgressSink? = nil) throws -> PFXFileSystem {
        typealias ConnectFn = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
        let connect = try XCTUnwrap(lib.symbol("PfxConnect"))
        let conn = try XCTUnwrap(unsafeBitCast(connect, to: ConnectFn.self)(nil),
                                 "PfxConnect returned nil — the plugin did not accept the URL")
        let plugin = PFXPlugin(library: lib)
        return PFXFileSystem(plugin: plugin, conn: conn, fsID: plugin.connectionId(conn),
                             capabilities: plugin.capabilities, retaining: nil,
                             progressSink: progressSink)
    }

    private func vpath(_ path: String) -> VFSPath { VFSPath(filesystemId: "webdav", path: path) }

    private func collect(_ fs: PFXFileSystem, _ path: String) async throws -> [VFSEntry] {
        var all: [VFSEntry] = []
        for try await batch in fs.list(vpath(path)) { all += batch.entries }
        return all
    }

    // MARK: - Tests

    func test_connect_namesTheHost() throws {
        let fs = try makeFS()
        // The id the plugin gives its connection is what the host turns into a drive-chip name.
        XCTAssertEqual(fs.scheme, "webdav:127.0.0.1")
    }

    func test_list_enumeratesTheServer_withoutTheCollectionItself() async throws {
        let fs = try makeFS()
        let entries = try await collect(fs, "/")
        XCTAssertEqual(entries.map(\.name).sorted(), ["docs", "readme.txt"])
        // The PROPFIND response describes the directory as well as its children; listing it as an
        // entry of itself would put a folder inside itself in the panel.
        let readme = try XCTUnwrap(entries.first { $0.name == "readme.txt" })
        XCTAssertEqual(readme.kind, .file)
        XCTAssertEqual(readme.size, Int64("hello webdav".utf8.count))
        XCTAssertEqual(entries.first { $0.name == "docs" }?.kind, .directory)
    }

    func test_list_descendsIntoASubdirectory() async throws {
        let fs = try makeFS()
        let names = try await collect(fs, "/docs").map(\.name)
        XCTAssertEqual(names, ["note.txt"])
    }

    func test_readingAFile_returnsItsBytes() async throws {
        let fs = try makeFS()
        let downloaded = try await fs.localFileIfAvailable(vpath("/readme.txt"))
        let url = try XCTUnwrap(downloaded)
        XCTAssertEqual(try Data(contentsOf: url), Data("hello webdav".utf8))
    }

    func test_aMissingDirectory_isReportedRatherThanListedEmpty() async throws {
        let fs = try makeFS()
        do {
            _ = try await collect(fs, "/nope")
            XCTFail("expected an error for a directory the server does not have")
        } catch let e as VFSError {
            if case .notFound = e {} else { XCTFail("expected notFound, got \(e)") }
        }
    }

    func test_disconnect_makesTheMountInert() async throws {
        // The contract `pfx.h` states, exercised through a plugin that really does free its
        // connection on disconnect — SampleFS's is a no-op, so it cannot show this.
        let fs = try makeFS()
        let before = try await collect(fs, "/")
        XCTAssertFalse(before.isEmpty)
        await fs.disconnect()
        do {
            _ = try await collect(fs, "/")
            XCTFail("listed a disconnected mount")
        } catch let e as VFSError {
            XCTAssertEqual(e, .connectionLost(retryable: false))
        }
        await fs.disconnect()   // must not free the connection a second time
    }

    // MARK: - Whole-file transfers, and the conformance that routes a keystroke to them

    func test_theMountIsSomethingThePanelWillUploadInto() throws {
        // Not a tautology test. `PanelController.isOnNetworkFilesystem` is `fs is
        // ResumableFileUploading`, and `cm_Copy` uses it to decide between an upload and a *local*
        // copy against the remote path string. For every plugin mount the answer used to be no, so
        // F5 into a mounted WebDAV wrote to a same-named local path and said it had succeeded —
        // the defect F-367 fixed for FTP, left standing for plugins.
        // Asked through a `VirtualFileSystem`-typed value, which is how `PanelController` holds it.
        // Asking the concrete type is a question the compiler answers at compile time, so it would
        // pass whatever the runtime did — and the compiler says so with a warning.
        let fs: VirtualFileSystem = try makeFS()
        XCTAssertTrue(fs is ResumableFileUploading, "the panel would copy locally instead of uploading")
        XCTAssertTrue(fs is ResumableFileDownloading, "downloads would take the temp-and-copy path")
    }

    func test_upload_putsTheFileOnTheServer() async throws {
        let fs = try makeFS()
        let local = dir.appendingPathComponent("outgoing.txt")
        try Data("sent from the panel".utf8).write(to: local)

        let result = try await fs.uploadFile(local, to: vpath("/outgoing.txt"), resume: true)

        XCTAssertEqual(result.written, Int64("sent from the panel".utf8.count))
        // Whole-file ABI: there is no offset to resume from, and saying so is the point of the
        // number rather than a placeholder in it.
        XCTAssertEqual(result.resumedAt, 0)
        XCTAssertEqual(try Data(contentsOf: serving.appendingPathComponent("outgoing.txt")),
                       Data("sent from the panel".utf8))
    }

    func test_upload_overAnExistingFileReplacesIt() async throws {
        let fs = try makeFS()
        let local = dir.appendingPathComponent("replacement.txt")
        try Data("second".utf8).write(to: local)
        _ = try await fs.uploadFile(local, to: vpath("/readme.txt"), resume: false)
        XCTAssertEqual(try Data(contentsOf: serving.appendingPathComponent("readme.txt")),
                       Data("second".utf8))
    }

    func test_upload_intoADirectoryTheServerDoesNotHaveFails() async throws {
        let fs = try makeFS()
        let local = dir.appendingPathComponent("lost.txt")
        try Data("nowhere".utf8).write(to: local)
        do {
            _ = try await fs.uploadFile(local, to: vpath("/nope/lost.txt"), resume: false)
            XCTFail("uploaded into a collection that does not exist")
        } catch is VFSError {
            // The shape the panel needs: an error, not a silent success. Which error it is depends
            // on how the server names the conflict, so this does not pin the case.
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: serving.appendingPathComponent("nope").path))
    }

    func test_download_writesStraightToTheDestination() async throws {
        // The generic path in `extractNode` materialises the file in a temp directory, copies it to
        // the destination and deletes the temp — three passes over every byte, and no way to resume.
        // This one hands the plugin the destination.
        let fs = try makeFS()
        let dest = dir.appendingPathComponent("landing/readme.txt")
        let result = try await fs.downloadFile(vpath("/readme.txt"), to: dest, resume: true)
        XCTAssertEqual(try Data(contentsOf: dest), Data("hello webdav".utf8))
        XCTAssertEqual(result.written, Int64("hello webdav".utf8.count))
        XCTAssertEqual(result.resumedAt, 0)
    }

    func test_download_doesNotAppendToAPartialFile() async throws {
        // `resume` is accepted and ignored, which is only safe if the stale bytes go. A plugin that
        // wrote after them would produce a file that is longer than the original and passes every
        // "did it arrive" check.
        let fs = try makeFS()
        let dest = dir.appendingPathComponent("partial.txt")
        try Data("STALE".utf8).write(to: dest)
        _ = try await fs.downloadFile(vpath("/readme.txt"), to: dest, resume: true)
        XCTAssertEqual(try Data(contentsOf: dest), Data("hello webdav".utf8))
    }

    func test_download_ofAMissingFileReportsRatherThanLeavingAnEmptyFile() async throws {
        let fs = try makeFS()
        let dest = dir.appendingPathComponent("ghost.txt")
        do {
            _ = try await fs.downloadFile(vpath("/ghost.txt"), to: dest, resume: false)
            XCTFail("downloaded a file the server does not have")
        } catch is VFSError {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: dest.path),
                       "a failed download left a file behind for the panel to list")
    }

    func test_mkdir_createsACollection() async throws {
        let fs = try makeFS()
        try await fs.mkdir(vpath("/reports"))
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: serving.appendingPathComponent("reports").path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
        let listed = try await collect(fs, "/")
        XCTAssertTrue(listed.contains { $0.name == "reports" && $0.kind == .directory })
    }

    func test_mkdir_overSomethingThatExistsFails() async throws {
        let fs = try makeFS()
        do {
            try await fs.mkdir(vpath("/docs"))
            XCTFail("created a collection over one that is already there")
        } catch is VFSError {}
    }

    func test_rename_movesTheResource() async throws {
        let fs = try makeFS()
        try await fs.rename(vpath("/readme.txt"), to: vpath("/readme-renamed.txt"))
        let names = try await collect(fs, "/").map(\.name).sorted()
        XCTAssertEqual(names, ["docs", "readme-renamed.txt"])
        XCTAssertEqual(try Data(contentsOf: serving.appendingPathComponent("readme-renamed.txt")),
                       Data("hello webdav".utf8))
    }

    func test_rename_intoASubdirectoryIsAMove() async throws {
        let fs = try makeFS()
        try await fs.rename(vpath("/readme.txt"), to: vpath("/docs/readme.txt"))
        let moved = try await collect(fs, "/docs").map(\.name).sorted()
        XCTAssertEqual(moved, ["note.txt", "readme.txt"])
    }

    func test_delete_removesAFileAndADirectory() async throws {
        let fs = try makeFS()
        try await fs.delete(vpath("/readme.txt"))
        try await fs.delete(vpath("/docs"))
        let remaining = try await collect(fs, "/").map(\.name)
        XCTAssertEqual(remaining, [])
    }

    // MARK: - The progress channel

    func test_aTransferRunsWithAProgressSinkAttached() async throws {
        // The WebDAV plugin never calls `progress`, so this cannot prove an abort gets through — a
        // plugin that stays silent cannot be interrupted, and that is a property of the plugin. What
        // it does prove is that attaching the channel does not change the outcome, which is the part
        // that would otherwise only be discovered by a user whose transfers had all started failing.
        let sink = PFXProgressSink()
        var reports = 0
        sink.begin { _, _ in reports += 1; return true }
        let fs = try makeFS(progressSink: sink)
        let dest = dir.appendingPathComponent("with-sink.txt")
        _ = try await fs.downloadFile(vpath("/readme.txt"), to: dest, resume: false)
        XCTAssertEqual(try Data(contentsOf: dest), Data("hello webdav".utf8))
        // `withTransferCancellation` installs its own handler for the duration, so ours is out of
        // the way while the transfer runs — the count says nothing either way and is not asserted.
        _ = reports
    }

    // MARK: - A server that goes away

    func test_aDeadServerIsReportedAsALostConnection_notAsAMissingDirectory() async throws {
        // `PfxFindFirst` can only answer NULL, and the host used to read that as "no such
        // directory" — so a server dying mid-listing told the user their folder was gone, and left
        // the panel sitting in a mount that could no longer answer anything. `PfxLastError` is how
        // the plugin says which of the two it was; the host keys the whole retreat off the answer.
        let fs = try makeFS()
        let before = try await collect(fs, "/")
        XCTAssertFalse(before.isEmpty, "the fixture should list before the kill")

        server.terminate()
        server.waitUntilExit()

        do {
            _ = try await collect(fs, "/")
            XCTFail("listed a server that is no longer running")
        } catch let error as VFSError {
            guard case .connectionLost = error else {
                return XCTFail("a dead server was reported as \(error)")
            }
        }
    }

    // MARK: - PfxInit and the config root

    func test_connect_savesTheSiteUnderTheHostsConfigRoot() throws {
        // The point of the whole `PfxInit`/`getContext` addition. The plugin used to build its own
        // path under Application Support, so a run with the host pointed elsewhere still wrote into
        // the user's real settings — which is not a hypothetical: it happened, to a real history.
        XCTAssertFalse(FileManager.default.fileExists(atPath: sitesFile.path))
        _ = try makeFS()
        XCTAssertTrue(FileManager.default.fileExists(atPath: sitesFile.path),
                      "the site list did not follow the host's config root")
        let saved = try JSONDecoder().decode([String].self, from: Data(contentsOf: sitesFile))
        XCTAssertEqual(saved, ["http://127.0.0.1:\(port)/"])
    }

    func test_theSiteListIsNotWrittenAnywhereElse() throws {
        // The other half, and the one that actually protects the user: proving the file appears in
        // the test's directory says nothing about whether it *also* appeared in the real one.
        let real = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PeachCommander/webdav/sites.json")
        let before = try? Data(contentsOf: real)
        _ = try makeFS()
        let after = try? Data(contentsOf: real)
        XCTAssertEqual(before, after, "connecting touched the real site list")
    }

    func test_aHostThatAnswersNothingLeavesThePluginWorking() throws {
        // `getContext` is NULL on an older host and answers 0 for keys it does not know. Neither may
        // be fatal — an unanswered key means "use your default", not "give up".
        var s = PfxHostServices()
        s.getContext = { _, _, _, _ in 0 }
        let plugin = PFXPlugin(library: lib)
        plugin.initialize(services: s)     // must not crash, and must not clear what we already have
        var bare = PfxHostServices()
        bare.getContext = nil
        PFXPlugin(library: lib).initialize(services: bare)
        _ = try makeFS()
        XCTAssertTrue(FileManager.default.fileExists(atPath: sitesFile.path),
                      "a second, emptier init overwrote a root the plugin had already been given")
    }
}
