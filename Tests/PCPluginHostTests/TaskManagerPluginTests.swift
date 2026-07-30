// TaskManagerPluginTests.swift - The external TaskManager PFX plugin
// (Plugins/TaskManager/taskmanager.c) driven through the host adapter: it must
// expose a non-local "TaskManager" volume, publish its process content columns,
// list running processes as entries, and resolve per-process column values by
// the "(pid)" identity encoded in each entry name. Compiled on the fly with
// clang, like PFXFileSystemTests, so no prebuilt bundle is needed.

import XCTest
import PCVFS
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
        p.arguments = ["-dynamiclib", "-std=c11", "-I", sdk.path, "-o", out.path, src.path]
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
                       ["pid", "cpu", "threads", "state", "user", "ppid", "command"])
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
        XCTAssertEqual(st.kind, .file)
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
