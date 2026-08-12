// SPDX-License-Identifier: Apache-2.0
// TaskManagerPluginTests.swift - The external TaskManager PFX plugin
// (Plugins/TaskManager/taskmanager.c) driven through the host adapter: it must
// expose a non-local "TaskManager" volume, publish its process content columns,
// list running processes as entries, and resolve per-process column values by
// the "(pid)" identity encoded in each entry name. Compiled on the fly with
// clang, like PFXFileSystemTests, so no prebuilt bundle is needed.

import XCTest
import PCVFS
import PCFoundation
@testable import PCPluginHost

final class TaskManagerPluginTests: XCTestCase {
    private var dir: URL!
    private var lib: PluginLibrary!

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    override func setUpWithError() throws {
        let clang = "/usr/bin/clang"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: clang), "clang unavailable")
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("taskman-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let src = repoRoot.appendingPathComponent("Plugins/TaskManager/taskmanager.c")
        let sdk = repoRoot.appendingPathComponent("Plugins/SDK")
        let out = dir.appendingPathComponent("libtaskman.dylib")
        let p = Process(); p.executableURL = URL(fileURLWithPath: clang)
        // Security/CoreFoundation for the signature column (F-393) — the same frameworks
        // Tools/build-taskmanager-plugin.sh links, or this compiles a plugin the app does not have.
        p.arguments = ["-dynamiclib", "-std=c11", "-I", sdk.path,
                       "-framework", "CoreFoundation", "-framework", "Security",
                       "-o", out.path, src.path]
        let pipe = Pipe(); p.standardError = pipe
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let e = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw XCTSkip("clang failed: \(e)")
        }
        guard case .success(let lib) = PluginLibrary.open(
            path: out.path, required: PFXSymbols.required, optional: PFXSymbols.optional) else {
            throw XCTSkip("open failed")
        }
        self.lib = lib
    }

    override func tearDownWithError() throws { if let dir { try? FileManager.default.removeItem(at: dir) } }

    private func makeFS() -> PFXFileSystem {
        typealias ConnectFn = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
        let conn = unsafeBitCast(lib.symbol("PfxConnect")!, to: ConnectFn.self)(nil)!
        return PFXFileSystem(plugin: PFXPlugin(library: lib), conn: conn,
                             fsID: "taskman", capabilities: [.read], retaining: nil,
                             contentQualifier: "taskman")
    }

    private func collect(_ fs: PFXFileSystem, _ path: String) async throws -> [VFSEntry] {
        var all: [VFSEntry] = []
        for try await batch in fs.list(VFSPath(filesystemId: "taskman", path: path)) { all += batch.entries }
        return all
    }

    func test_volume_isNonLocalTaskManager() {
        let volumes = PFXPlugin(library: lib).volumes()
        XCTAssertEqual(volumes.count, 1)
        let v = try? XCTUnwrap(volumes.first)
        XCTAssertEqual(v?.name, "TaskManager")
        XCTAssertEqual(v?.isLocal, false)   // clicking connects + mounts, not a path nav
        XCTAssertEqual(v?.icon, "📊")       // plugin defines its own drive-chip icon
        XCTAssertEqual(v?.order, 1)         // …and pins itself right after the boot drive
    }

    func test_contentFields_areTheProcessColumns() {
        let fs = makeFS()
        XCTAssertTrue(fs.isVolatile)        // PC_PFX_CAP_VOLATILE -> host auto-refreshes
        XCTAssertEqual(fs.contentFields.map(\.name),
                       ["pid", "cpu", "mem", "rss", "threads", "state", "user", "ppid",
                        "read", "written", "wakeups", "signed", "command"])
        // PFX_FT_SIZE == 2: the host renders those in KB/MB and sorts by the number behind it.
        // "mem" carries what the Size column used to, which now reads "<DIR>" (F-391).
        // Two memory columns on purpose (F-394): the footprint is what a process is accountable
        // for and is readable only for our own; the resident size is filled for every process,
        // from `ps` where proc_pidinfo will not answer.
        XCTAssertEqual(fs.contentFields.filter { $0.type == 2 }.map(\.name),
                       ["mem", "rss", "read", "written"])
        // PFX_FT_STRING == 0 is the only type that sorts lexically.
        XCTAssertTrue(fs.contentFields.allSatisfy { $0.isNumericSort == ($0.type != 0) })
        XCTAssertEqual(fs.qualifiedContentFields.map(\.qualifiedID).first, "taskman.pid")
    }

    func test_listsProcesses_andResolvesOwnProcessRow() async throws {
        let fs = makeFS()
        let entries = try await collect(fs, "/")
        XCTAssertGreaterThan(entries.count, 10, "expected the running process list")

        // Every entry name ends in "(<pid>)"; the host path "/<name>" carries it.
        let mine = getpid()
        let ours = try XCTUnwrap(entries.first { $0.name.hasSuffix("(\(mine))") },
                                 "the test process (pid \(mine)) should be listed")
        let path = "/\(ours.name)"

        // The pid column must resolve back to our own pid via the "(pid)" identity.
        XCTAssertEqual(fs.contentDisplay(fieldID: "taskman.pid", path: path), "\(mine)")
        // Our own process has task info: a positive thread count.
        let threads = try XCTUnwrap(fs.contentDisplay(fieldID: "taskman.threads", path: path))
        XCTAssertGreaterThan(Int(threads) ?? 0, 0)
        // Command is our executable path (the test runner), not empty.
        let command = try XCTUnwrap(fs.contentDisplay(fieldID: "taskman.command", path: path))
        XCTAssertFalse(command.isEmpty)
        // A field this mount doesn't own resolves to nil.
        XCTAssertNil(fs.contentDisplay(fieldID: "other.x", path: path))
    }

    func test_statResolvesByPidIdentity() async throws {
        let fs = makeFS()
        let entries = try await collect(fs, "/")
        let mine = getpid()
        let ours = try XCTUnwrap(entries.first { $0.name.hasSuffix("(\(mine))") })
        let st = try await fs.stat(VFSPath(filesystemId: "taskman", path: "/\(ours.name)"))
        XCTAssertTrue(st.name.hasSuffix("(\(mine))"))
        // A process is a folder since F-391: entering it lists the files it has open.
        XCTAssertEqual(st.kind, .directory)
    }

    func test_lookup_findsProcessOwningPort() async throws {
        // Bind a listening TCP socket in THIS process on an ephemeral port.
        let sock = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        try XCTSkipUnless(sock >= 0, "socket() failed")
        defer { Darwin.close(sock) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = INADDR_ANY
        addr.sin_port = 0
        let bindRc = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        try XCTSkipUnless(bindRc == 0 && Darwin.listen(sock, 1) == 0, "bind/listen failed")
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.getsockname(sock, $0, &len) }
        }
        let port = Int(UInt16(bigEndian: addr.sin_port))
        XCTAssertGreaterThan(port, 0)

        let fs = makeFS()
        _ = try await collect(fs, "/")   // build the snapshot the lookup scans
        let mine = getpid()
        let hit = fs.lookup(query: "port:\(port)")
        XCTAssertEqual(hit?.hasSuffix("(\(mine))"), true, "port \(port) → \(hit ?? "nil"), want pid \(mine)")
        XCTAssertNil(fs.lookup(query: "port:1"), "no process should own port 1 here")
    }

    // MARK: - A process is a folder of the files it has open (F-391)

    /// Our own row, after a listing (which is what builds the snapshot).
    private func ownRowPath(_ fs: PFXFileSystem) async throws -> String {
        let entries = try await collect(fs, "/")
        let ours = try XCTUnwrap(entries.first { $0.name.hasSuffix("(\(getpid()))") })
        return "/\(ours.name)"
    }

    func test_processFolder_listsTheFilesItHasOpen() async throws {
        let file = dir.appendingPathComponent("open-me.txt")
        try Data("abc".utf8).write(to: file)
        let fd = open(file.path, O_RDONLY)
        try XCTSkipUnless(fd >= 0, "open failed")
        defer { close(fd) }

        let fs = makeFS()
        let path = try await ownRowPath(fs)
        let files = try await collect(fs, path)
        // Entry names carry the file's path with ":" for "/" — the host's own convention for a
        // name containing a slash, which is what lets a row be a path and still be one leaf.
        // The kernel answers with the resolved path ("/private/var/…" for a "/var/…" temp dir), so
        // the row is asserted to BE an absolute path ending in the file — not to be one spelling.
        let names = files.map { PathUtils.displayName(fromPOSIX: $0.name) }
        XCTAssertTrue(names.contains { $0.hasPrefix("/") && $0.hasSuffix("/open-me.txt") },
                      "the open file should be listed as its path; got \(names.prefix(5))")
        let row = try XCTUnwrap(files.first { PathUtils.displayName(fromPOSIX: $0.name).hasSuffix("open-me.txt") })
        XCTAssertEqual(row.size, 3)
        XCTAssertEqual(row.kind, .file, "an open file is a file, not a folder to descend into")
    }

    func test_processFolder_rowResolvesToTheRealFileForViewing() async throws {
        let file = dir.appendingPathComponent("view-me.txt")
        try Data("content-to-view".utf8).write(to: file)
        let fd = open(file.path, O_RDONLY)
        try XCTSkipUnless(fd >= 0, "open failed")
        defer { close(fd) }

        let fs = makeFS()
        let path = try await ownRowPath(fs)
        let files = try await collect(fs, path)
        let row = try XCTUnwrap(files.first { PathUtils.displayName(fromPOSIX: $0.name).hasSuffix("view-me.txt") })
        let vpath = VFSPath(filesystemId: "taskman", path: "\(path)/\(row.name)")
        // F3 asks the mount for a local copy; for these rows that copy is the file itself.
        let local = try await fs.localFileIfAvailable(vpath)
        let url = try XCTUnwrap(local)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "content-to-view")
    }

    /// Deleting a process is a signal; deleting a row *inside* one would be a file. The plugin
    /// refuses rather than parsing the parent's "(pid)" out of the path and signalling it.
    func test_processFolder_deletingAnOpenFileRowIsRefused() async throws {
        let file = dir.appendingPathComponent("keep-me.txt")
        try Data("x".utf8).write(to: file)
        let fd = open(file.path, O_RDONLY)
        try XCTSkipUnless(fd >= 0, "open failed")
        defer { close(fd) }

        let fs = makeFS()
        let path = try await ownRowPath(fs)
        let files = try await collect(fs, path)
        let row = try XCTUnwrap(files.first { PathUtils.displayName(fromPOSIX: $0.name).hasSuffix("keep-me.txt") })
        do {
            try await fs.delete(VFSPath(filesystemId: "taskman", path: "\(path)/\(row.name)"))
            XCTFail("deleting an open-file row must not be accepted")
        } catch {
            // …and this process is still running, which is the part that matters.
            XCTAssertEqual(kill(getpid(), 0), 0)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    // MARK: - Memory, I/O and signer columns (F-392, F-393)

    func test_metricColumns_areFilledForOurOwnProcess() async throws {
        let fs = makeFS()
        let path = try await ownRowPath(fs)
        // Raw bytes from the plugin; the host is what turns them into "1.0 MB".
        let mem = try XCTUnwrap(fs.contentSortValue(fieldID: "taskman.mem", path: path))
        XCTAssertGreaterThan(Int64(mem) ?? 0, 0, "footprint should be a real byte count")
        XCTAssertEqual(fs.contentDisplay(fieldID: "taskman.mem", path: path)?.hasSuffix("B"), true,
                       "a size column is rendered by the host, not by the plugin")
        for field in ["taskman.read", "taskman.written", "taskman.wakeups"] {
            let raw = try XCTUnwrap(fs.contentSortValue(fieldID: field, path: path))
            XCTAssertNotNil(Int64(raw), "\(field) must be a number, blank only when unreadable")
        }
    }

    func test_signedColumn_namesWhoSignedTheBinary() async throws {
        let fs = makeFS()
        _ = try await collect(fs, "/")
        _ = try await collect(fs, "/")   // the cache fills a few per refresh, under a time budget
        let path = try await ownRowPath(fs)
        // The test runner is an Apple binary; whatever it is, the column must name a signer for
        // *someone* — the point of the column is that it works where the metrics do not.
        let entries = try await collect(fs, "/")
        let signed = entries.compactMap { fs.contentDisplay(fieldID: "taskman.signed", path: "/\($0.name)") }
            .filter { !$0.isEmpty }
        XCTAssertFalse(signed.isEmpty, "no signature was read at all")
        XCTAssertTrue(signed.contains("Apple"), "Apple's own binaries should be named as such")
        XCTAssertNotNil(fs.contentDisplay(fieldID: "taskman.signed", path: path))
    }

    /// The info report (F3) reads the signature on demand, so it never depends on the cache.
    func test_processInfo_reportsSignatureAndEntitlements() async throws {
        let fs = makeFS()
        let path = try await ownRowPath(fs)
        let copy = try await fs.localFileIfAvailable(VFSPath(filesystemId: "taskman", path: path))
        let local = try XCTUnwrap(copy)
        let text = try String(contentsOf: local, encoding: .utf8)
        XCTAssertTrue(text.contains("Signature:"), "the report should name who signed the binary")
        XCTAssertTrue(text.contains("Signed by:"))
        XCTAssertTrue(text.contains("Hardened runtime:"))
    }

    // MARK: - "file:<path>" lookup (F-390)

    /// The tagged line for THIS process, or nil if it is not among the hits.
    private func handleKind(_ fs: PFXFileSystem, _ path: String) -> String? {
        guard let answer = fs.lookup(query: "file:\(path)") else { return nil }
        let mine = "/\(ProcessInfo.processInfo.processName) (\(getpid()))"
        for line in answer.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1)
            // Only the "(pid)" identifies us — the name is the kernel's, not processName's.
            guard parts.count == 2, parts[0].hasSuffix("(\(getpid()))") else { continue }
            return String(parts[1])
        }
        XCTFail("no line for this process in:\n\(answer)\n(looked for \(mine))")
        return nil
    }

    func test_lookupFile_reportsReadWriteAndBothForOurOwnHandles() async throws {
        let file = dir.appendingPathComponent("handles.txt")
        try Data("x".utf8).write(to: file)
        let fs = makeFS()
        _ = try await collect(fs, "/")   // build the snapshot the lookup scans

        let ro = open(file.path, O_RDONLY)
        try XCTSkipUnless(ro >= 0, "open O_RDONLY failed")
        defer { close(ro) }
        XCTAssertEqual(handleKind(fs, file.path), "r", "a read-only handle must not read as a write")

        let wo = open(file.path, O_WRONLY)
        try XCTSkipUnless(wo >= 0, "open O_WRONLY failed")
        defer { close(wo) }
        XCTAssertEqual(handleKind(fs, file.path), "b", "one handle of each is both")
    }

    func test_lookupFile_singleReadWriteHandleIsBoth() async throws {
        let file = dir.appendingPathComponent("rw.txt")
        try Data("x".utf8).write(to: file)
        let fs = makeFS()
        _ = try await collect(fs, "/")
        let fd = open(file.path, O_RDWR)
        try XCTSkipUnless(fd >= 0, "open O_RDWR failed")
        defer { close(fd) }
        XCTAssertEqual(handleKind(fs, file.path), "b")
    }

    func test_lookupFile_writeOnlyHandleIsWrite() async throws {
        let file = dir.appendingPathComponent("wo.txt")
        try Data("x".utf8).write(to: file)
        let fs = makeFS()
        _ = try await collect(fs, "/")
        let fd = open(file.path, O_WRONLY)
        try XCTSkipUnless(fd >= 0, "open O_WRONLY failed")
        defer { close(fd) }
        XCTAssertEqual(handleKind(fs, file.path), "w")
    }

    /// The same file under another spelling must be the same file. Identity is (device, inode),
    /// not the path string — a `/tmp` vs `/private/tmp` mismatch would report "nobody has it open"
    /// for a file that is very much open.
    func test_lookupFile_matchesByInodeNotByPathSpelling() async throws {
        let file = dir.appendingPathComponent("alias.txt")
        try Data("x".utf8).write(to: file)
        let link = dir.appendingPathComponent("alias-hardlink.txt")
        try FileManager.default.linkItem(at: file, to: link)
        let fs = makeFS()
        _ = try await collect(fs, "/")
        let fd = open(file.path, O_RDONLY)
        try XCTSkipUnless(fd >= 0, "open failed")
        defer { close(fd) }
        XCTAssertEqual(handleKind(fs, link.path), "r", "a hard link is the same inode")
        // The temp dir lives under /var, which is a symlink to /private/var: the resolved and the
        // unresolved spelling must agree.
        let resolved = URL(fileURLWithPath: file.path).resolvingSymlinksInPath().path
        if resolved != file.path { XCTAssertEqual(handleKind(fs, resolved), "r") }
    }

    func test_lookupFile_missesAreNilAndNeverThePortAnswer() async throws {
        let fs = makeFS()
        _ = try await collect(fs, "/")
        XCTAssertNil(fs.lookup(query: "file:/no/such/file/at/all"), "a path that does not exist")
        let untouched = dir.appendingPathComponent("nobody-has-me.txt")
        try Data("x".utf8).write(to: untouched)
        XCTAssertNil(fs.lookup(query: "file:\(untouched.path)"), "a file nobody holds open")
        XCTAssertNil(fs.lookup(query: "file:"), "an empty path is not a query")
    }

    func test_delete_escalatesSigtermThenSigkill() async throws {
        // A child that ignores SIGTERM, so only the escalation (SIGKILL) can kill it.
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sh")
        child.arguments = ["-c", "trap '' TERM; sleep 30"]
        try child.run()
        let pid = child.processIdentifier
        // Give the shell time to install its `trap '' TERM` before we signal it,
        // otherwise the first SIGTERM races in before the handler and kills it.
        try await Task.sleep(nanoseconds: 400_000_000)
        try XCTSkipUnless(kill(pid, 0) == 0, "child did not start")
        // Only the trailing "(pid)" matters to the plugin — build the path directly.
        // The SAME connection must serve both deletes: escalation state is per-conn.
        let fs = makeFS()
        let path = VFSPath(filesystemId: "taskman", path: "/child (\(pid))")

        // 1st delete → SIGTERM, which the child ignores: it stays alive.
        try await fs.delete(path)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(kill(pid, 0), 0, "a TERM-ignoring child must survive the first delete")

        // 2nd delete on the still-alive process → SIGKILL: it dies.
        try await fs.delete(path)
        child.waitUntilExit()
        XCTAssertEqual(child.terminationReason, .uncaughtSignal)
        XCTAssertEqual(child.terminationStatus, SIGKILL)
    }
}
