// SPDX-License-Identifier: Apache-2.0
// DockerPluginTests.swift — the Docker plugin, end to end against a stand-in engine on a real
// Unix socket.
//
// Built the way `Tools/build-docker-plugin.sh` builds it, pointed at `Fixtures/dockerd.py`, and
// driven through `PFXFileSystem` — the same path the application uses, so what these tests
// exercise is the C ABI and not a Swift API nobody calls.
//
// The fixture answers the way the daemon answers rather than the way an HTTP client would like it
// to, which is what makes it worth having: a HEAD carries a Content-Length and no body, an
// archive of a directory is the whole subtree, an attached exec is an unframed stream of
// multiplexed frames, and an upload carrying extended attributes is refused. Every one of those
// is a shape the plugin got wrong at some point against the real engine.

import XCTest
import AppKit
import PCVFS
import CPFX
import CContrib
@testable import PCPluginHost

/// The config root the stub host hands the plugin. A file-scope variable because a
/// `@convention(c)` callback cannot capture, and this has to be readable from inside one.
private nonisolated(unsafe) var dockerStubConfigRoot = ""

/// What the stub host answers a contributed command, and what the command did to it. File-scope for
/// the same reason as the config root: a `@convention(c)` callback cannot capture.
private nonisolated(unsafe) var dockerStubCursor = ""
private nonisolated(unsafe) var dockerStubScheme = ""
private nonisolated(unsafe) var dockerStubOpened: [String] = []
/// How many times the plugin has reported progress, and after how many it is told to stop.
///
/// Without a `progress` in the services table the plugin cannot be interrupted at all — the ABI's
/// only channel for "carry on?" is that callback — so a cancellation could not be tested before it
/// existed here. Counting the calls is also what proves the transfer *stopped* rather than ran to
/// the end and reported afterwards.
private nonisolated(unsafe) var dockerStubProgressCalls = 0
private nonisolated(unsafe) var dockerStubCancelAfter = Int.max
private nonisolated(unsafe) var dockerStubInformed: [String] = []

private let dockerStubCursorPath: @convention(c) (UnsafeMutableRawPointer?,
                                                  UnsafeMutablePointer<CChar>?, Int32) -> Int32 = {
    _, out, maxlen in
    guard let out, maxlen > 0, !dockerStubCursor.isEmpty else { return 0 }
    _ = dockerStubCursor.withCString { strlcpy(out, $0, Int(maxlen)) }
    return 1
}

private let dockerStubGetContext: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?,
                                                  UnsafeMutablePointer<CChar>?, Int32) -> Int32 = {
    _, key, out, maxlen in
    guard let key, let out, maxlen > 0, String(cString: key) == "panelScheme" else { return 0 }
    _ = dockerStubScheme.withCString { strlcpy(out, $0, Int(maxlen)) }
    return 1
}

private let dockerStubProgress: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?,
                                                Int32) -> Int32 = { _, _, _ in
    dockerStubProgressCalls += 1
    return dockerStubProgressCalls > dockerStubCancelAfter ? Int32(PC_ABORT) : Int32(PC_CONTINUE)
}

private let dockerStubOpenPath: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?)
    -> Void = { _, path in
    if let path { dockerStubOpened.append(String(cString: path)) }
}

private let dockerStubPresentInfo: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?,
                                                   UnsafePointer<CChar>?) -> Void = { _, _, message in
    if let message { dockerStubInformed.append(String(cString: message)) }
}

final class DockerPluginTests: XCTestCase {
    private var dir: URL!
    private var socketPath: String!
    private var server: Process!
    private var droppingServer: Process!
    private var lib: PluginLibrary!

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    // MARK: - Fixture wiring

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("docker-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        lib = try Self.buildPlugin(repoRoot: repoRoot, into: dir)
        try makeEngine()
        try startServer()

        setenv("PC_DOCKER_HOST", "unix://\(socketPath!)", 1)
        // Tell the plugin where "configuration" is before anything connects: connecting saves the
        // chosen endpoint, and without this every run would write into the developer's own
        // settings.
        initPlugin(configRoot: dir.appendingPathComponent("config"))
    }

    override func tearDownWithError() throws {
        unsetenv("PC_DOCKER_HOST")
        unsetenv("PC_DOCKER_EXEC")
        unsetenv("PC_DOCKER_CONFIRM")
        dockerStubProgressCalls = 0
        dockerStubCancelAfter = .max
        server?.terminate()
        droppingServer?.terminate()
        if let dir { try? FileManager.default.removeItem(at: dir) }
    }

    /// Compile the plugin exactly as `Tools/build-docker-plugin.sh` does, and open it.
    ///
    /// The source list must stay in step with that script; `Tools/check-plugin-sources.py` is what
    /// keeps them in step, because forgetting a file here builds a plugin the tests cannot see and
    /// forgetting it there ships one that does not link.
    static func buildPlugin(repoRoot: URL, into dir: URL) throws -> PluginLibrary {
        let out = try CachedPluginBuild.freshBuild(key: "docker", into: dir) { cache in
            let swiftc = "/usr/bin/swiftc"
            try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: swiftc), "swiftc unavailable")
            let out = cache.appendingPathComponent("libdocker.dylib")
            let sources = ["docker", "DockerEngine", "DockerAPI", "DockerTar", "DockerTree",
                           "DockerFS", "DockerWrite", "DockerSettings", "DockerConnectDialog",
                           "DockerCommands", "DockerTextWindow", "DockerSettingsView"]
                .map { repoRoot.appendingPathComponent("Plugins/Docker/\($0).swift").path }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: swiftc)
            process.arguments = ["-emit-library", "-module-name", "Docker", "-framework", "AppKit",
                                 "-import-objc-header",
                                 repoRoot.appendingPathComponent("Plugins/Docker/DockerBridging.h").path,
                                 "-Xcc", "-I\(repoRoot.appendingPathComponent("Plugins/SDK").path)",
                                 "-o", out.path]
                + sources
                + [repoRoot.appendingPathComponent("Plugins/SDK/PluginLoc.swift").path]
            let pipe = Pipe()
            process.standardError = pipe
            try process.run()
            process.waitUntilExit()
            // A compiler that RAN and refused the plugin is a failure, not a skip — the skip above
            // is for a machine without swiftc. Conflating the two once made a whole file of tests
            // report success while the plugin no longer compiled.
            guard process.terminationStatus == 0 else {
                let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                                  encoding: .utf8) ?? ""
                throw PluginBuildFailure(description: "the Docker plugin did not compile:\n\(text)")
            }
            return out
        }
        // `ContribSymbols.optional` as well as the PFX ones: `PluginLibrary.symbol` answers from the
        // table it resolved at open time, so a symbol nobody asked for is not "missing from the
        // dylib" — it was never looked up. Without it `PcRunCommand` comes back nil and the failure
        // reads as a plugin that does not export it.
        guard case .success(let lib) = PluginLibrary.open(
            path: out.path, required: PFXSymbols.required,
            optional: PFXSymbols.optional + ContribSymbols.optional) else {
            throw PluginBuildFailure(description: "the Docker plugin compiled but could not be loaded")
        }
        return lib
    }

    /// A small engine: one compose stack (a single-replica service, a replicated one, a stopped
    /// one), a standalone container, and two volumes — one mounted by a container and one that
    /// nothing mounts at all.
    private func makeEngine() throws {
        let fm = FileManager.default
        let fs = dir.appendingPathComponent("fs")

        func write(_ text: String, _ path: String) throws {
            let url = fs.appendingPathComponent(path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url)
        }

        try write("server {}", "web/etc/nginx/nginx.conf")
        try write("hello from the web container", "web/etc/hostname")
        try write("deep", "web/srv/a/b/c/d/e/f/g/h/i/j/k/l/m/a-name-long-enough-to-need-the-ustar-prefix-field.txt")
        try fm.createDirectory(at: fs.appendingPathComponent("web/data"), withIntermediateDirectories: true)
        try fm.createDirectory(at: fs.appendingPathComponent("web/database"), withIntermediateDirectories: true)
        try fm.createDirectory(at: fs.appendingPathComponent("web/hostlogs"), withIntermediateDirectories: true)
        try fm.createDirectory(at: fs.appendingPathComponent("web/locked"), withIntermediateDirectories: true)
        try write("cannot touch this", "web/locked/pinned.txt")
        // A symlink, which the panel has to draw as a link rather than as an empty file.
        try fm.createSymbolicLink(atPath: fs.appendingPathComponent("web/etc/motd").path,
                                  withDestinationPath: "/etc/hostname")

        // Big enough to blow a one-megabyte budget, so the fallback path can be reached on
        // purpose. Generated here rather than committed — see the fixture rule in CONVENTIONS.md.
        let blob = fs.appendingPathComponent("web/srv/blob.bin")
        try Data(count: 2 * 1024 * 1024).write(to: blob)
        // A file whose download reports progress many times, so "it stopped" and "it finished and
        // then complained" are told apart by counting.
        try Data(count: 4 * 1024 * 1024).write(to: fs.appendingPathComponent("web/big.bin"))

        try write("worker one", "worker1/etc/id")
        try write("worker two", "worker2/etc/id")
        try write("batch ran", "batch/var/log/batch.log")
        try write("standalone", "redis/etc/redis.conf")
        // A container carrying a real file of the reserved name: its own file has to win, or the
        // provider would hide a file that is genuinely in the image.
        try write("this one is real", "shadow/docker-logs.txt")
        // A name that is long *and* not ASCII. Long enough that USTAR cannot hold it, so the engine
        // describes it in a PAX record — whose length field counts BYTES, while a Swift String
        // indexes in Characters. The two agree for ASCII and part company here.
        try write("umlauts", "web/names/" + String(repeating: "ü", count: 60) + ".txt")
        try write("locked down", "readonly/etc/frozen.conf")
        try write("a row in the database", "vol-data/rows.db")
        try write("nothing mounts me", "vol-orphan/orphan.txt")
        try write("deeper", "vol-inner/deep.txt")
        // The mount point as it exists inside the volume it nests in — a real container shows the
        // directory whether or not anything is mounted over it.
        try fm.createDirectory(at: fs.appendingPathComponent("vol-data/inner"),
                               withIntermediateDirectories: true)

        let spec: [String: Any] = [
            "images": ["alpine:3"],
            "tools": ["ls", "rm", "mv"],
            // What a non-root container user cannot write, reported by the utilities themselves.
            "denyWrites": ["/locked"],
            "containers": [
                ["name": "stack-web-1", "id": "c-web", "state": "running", "image": "nginx:1",
                 "root": "web",
                 "labels": ["com.docker.compose.project": "stack",
                            "com.docker.compose.service": "web"],
                 "mounts": [["Type": "volume", "Name": "stack_data",
                             "Destination": "/data", "RW": true],
                            // Nested inside the one above: the deeper mount must win for a path
                            // under it, or the Mount column names the wrong volume.
                            ["Type": "volume", "Name": "stack_inner",
                             "Destination": "/data/inner", "RW": true],
                            // A read-only bind, so the four-letter tag and the host path have a
                            // case of their own.
                            ["Type": "bind", "Source": "/host/logs",
                             "Destination": "/hostlogs", "RW": false]]],
                ["name": "stack-worker-1", "id": "c-w1", "state": "running", "image": "worker:1",
                 "root": "worker1",
                 "labels": ["com.docker.compose.project": "stack",
                            "com.docker.compose.service": "worker"]],
                ["name": "stack-worker-2", "id": "c-w2", "state": "running", "image": "worker:1",
                 "root": "worker2",
                 "labels": ["com.docker.compose.project": "stack",
                            "com.docker.compose.service": "worker"]],
                ["name": "stack-batch-1", "id": "c-batch", "state": "exited", "image": "batch:1",
                 "root": "batch",
                 "labels": ["com.docker.compose.project": "stack",
                            "com.docker.compose.service": "batch"]],
                ["name": "redis-test", "id": "c-redis", "state": "running", "image": "redis:7",
                 "root": "redis", "labels": [:],
                 "log": "ready to accept connections\nbackground saving started\n"],
                ["name": "shadowed", "id": "c-shadow", "state": "running", "image": "shadow:1",
                 "root": "shadow", "labels": [:], "log": "this log must not be reachable"],
                ["name": "frozen", "id": "c-frozen", "state": "running", "image": "frozen:1",
                 "root": "readonly", "labels": [:], "readOnlyRootfs": true],
            ],
            "volumes": [
                ["name": "stack_inner", "root": "vol-inner", "labels": [:]],
                ["name": "stack_data", "root": "vol-data",
                 "labels": ["com.docker.compose.project": "stack",
                            "com.docker.compose.volume": "data"]],
                ["name": "orphaned_data", "root": "vol-orphan", "labels": [:]],
            ],
        ]
        try JSONSerialization.data(withJSONObject: spec, options: [.prettyPrinted])
            .write(to: dir.appendingPathComponent("spec.json"))
    }

    private func startServer() throws {
        let python = "/usr/bin/python3"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: python), "python3 unavailable")
        // Short, because a Unix socket path has a hard 104-byte limit and the temporary directory
        // is most of one already.
        socketPath = "/tmp/pcd-\(UUID().uuidString.prefix(8)).sock"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = [URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/dockerd.py").path, dir.path, socketPath]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        server = process

        // Wait for the socket rather than sleeping a guessed amount: a fixed wait is either slow
        // or occasionally short, and "occasionally short" reads as the plugin failing to connect.
        for _ in 0..<400 {
            if FileManager.default.fileExists(atPath: socketPath + ".ready") { return }
            Thread.sleep(forTimeInterval: 0.02)
        }
        throw XCTSkip("the Docker fixture never came up")
    }

    /// Write the plugin's own settings file before connecting, which is how a test chooses the
    /// budgets that decide which listing path a directory takes.
    private func writeSettings(probeMB: Int, maxMB: Int) throws {
        let url = dir.appendingPathComponent("config/Docker/docker.ini")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("[Docker]\nProbeBudgetMB=\(probeMB)\nMaxBudgetMB=\(maxMB)\n".utf8).write(to: url)
    }

    /// A second engine on its own socket, whose first archive response is cut off after `after`
    /// bytes. Its own process because the setting is global to the fixture: sharing the one every
    /// other test uses would make this test's behaviour depend on the order they run in.
    private func startDroppingServer(after bytes: Int, key: String = "dropArchiveAfter") throws -> String {
        let python = "/usr/bin/python3"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: python), "python3 unavailable")
        let root = dir.appendingPathComponent("drop-root")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        // The same filesystem, a spec that differs in one key.
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("fs"),
                                                   withDestinationURL: dir.appendingPathComponent("fs"))
        var spec = try JSONSerialization.jsonObject(
            with: Data(contentsOf: dir.appendingPathComponent("spec.json"))) as? [String: Any] ?? [:]
        spec[key] = bytes
        try JSONSerialization.data(withJSONObject: spec)
            .write(to: root.appendingPathComponent("spec.json"))

        let path = "/tmp/pcd-drop-\(UUID().uuidString.prefix(8)).sock"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = [URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/dockerd.py").path, root.path, path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        droppingServer = process
        for _ in 0..<400 {
            if FileManager.default.fileExists(atPath: path + ".ready") { return path }
            Thread.sleep(forTimeInterval: 0.02)
        }
        throw XCTSkip("the dropping Docker fixture never came up")
    }

    private func initPlugin(configRoot: URL) {
        dockerStubConfigRoot = configRoot.path
        var services = PfxHostServices()
        services.getContext = { _, key, out, maxlen in
            guard let key, let out, maxlen > 0, String(cString: key) == "configRoot" else { return 0 }
            _ = dockerStubConfigRoot.withCString { strlcpy(out, $0, Int(maxlen)) }
            return 1
        }
        // Deliberately NOT main-actor isolated, the same as `PFXHostBridge`: the plugin reports from
        // the queue its transfer runs on, so a hop here would trap rather than hop.
        services.progress = dockerStubProgress
        PFXPlugin(library: lib).initialize(services: services)
    }

    private func makeFS() throws -> PFXFileSystem {
        typealias ConnectFn = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
        let connect = try XCTUnwrap(lib.symbol("PfxConnect"))
        let conn = try XCTUnwrap(unsafeBitCast(connect, to: ConnectFn.self)(nil),
                                 "PfxConnect returned nil — the plugin did not accept the endpoint")
        let plugin = PFXPlugin(library: lib)
        let fsID = plugin.connectionId(conn)
        return PFXFileSystem(plugin: plugin, conn: conn, fsID: fsID,
                             capabilities: plugin.capabilities, retaining: nil,
                             contentQualifier: fsID, progressSink: nil)
    }

    private func vpath(_ path: String) -> VFSPath { VFSPath(filesystemId: "docker", path: path) }

    private func collect(_ fs: PFXFileSystem, _ path: String) async throws -> [VFSEntry] {
        var all: [VFSEntry] = []
        for try await batch in fs.list(vpath(path)) { all += batch.entries }
        return all
    }

    private func names(_ fs: PFXFileSystem, _ path: String) async throws -> [String] {
        try await collect(fs, path).map(\.name).sorted()
    }

    /// One of the mount's own columns for one entry, addressed the way the panel addresses it:
    /// "<connection id>.<field>". The qualifier is full of colons and dots, which is exactly where
    /// a host that split on the first "." used to lose every plugin column.
    private func column(_ fs: PFXFileSystem, _ field: String, _ path: String) -> String? {
        fs.contentDisplay(fieldID: "\(fs.scheme).\(field)", path: path)
    }

    // MARK: - Connecting and the shape of the tree

    func test_connect_namesTheEngine() throws {
        // What the host turns into the drive chip: `NetworkConnectionID` splits this into a name
        // and the kind "docker", with no change needed on the host side for a new scheme.
        XCTAssertEqual(try makeFS().scheme, "docker:Docker")
    }

    func test_theRootIsTheThreeSections() async throws {
        let entries = try await collect(try makeFS(), "/")
        XCTAssertEqual(entries.map(\.name),
                       ["Compose Projects", "Standalone Containers", "Volumes"])
        XCTAssertTrue(entries.allSatisfy { $0.kind == .directory })
    }

    func test_composeProjectsAreGroupedByLabel() async throws {
        let fs = try makeFS()
        let projects = try await names(fs, "/Compose Projects")
        XCTAssertEqual(projects, ["stack"])
        let services = try await names(fs, "/Compose Projects/stack")
        XCTAssertEqual(services, ["batch", "web", "worker"])
    }

    func test_aServiceWithOneContainerHasNoContainerLevel() async throws {
        let fs = try makeFS()
        // `…/stack/web` is the container's own root, not a list holding one container.
        let entries = try await names(fs, "/Compose Projects/stack/web")
        // `docker-logs.txt` is the container's log offered as a file — see `DockerLog`. It is in the
        // root listing whichever way that listing was produced.
        XCTAssertEqual(entries, ["big.bin", "data", "database", "docker-logs.txt", "etc", "hostlogs", "locked", "names", "srv"])
    }

    func test_aReplicatedServiceKeepsItsContainerLevel() async throws {
        let fs = try makeFS()
        let replicas = try await names(fs, "/Compose Projects/stack/worker")
        XCTAssertEqual(replicas, ["stack-worker-1", "stack-worker-2"])
        let inside = try await names(fs, "/Compose Projects/stack/worker/stack-worker-2/etc")
        XCTAssertEqual(inside, ["id"])
    }

    func test_standaloneContainersExcludeComposeMembers() async throws {
        let fs = try makeFS()
        let standalone = try await names(fs, "/Standalone Containers")
        XCTAssertEqual(standalone, ["frozen", "redis-test", "shadowed"])
    }

    func test_aStoppedContainerIsListedAndItsFilesystemIsReadable() async throws {
        let fs = try makeFS()
        // The thing that makes this provider feel like a drive rather than a process list: the
        // archive API answers for a container that has not run for a month.
        let services = try await names(fs, "/Compose Projects/stack")
        XCTAssertTrue(services.contains("batch"))
        let logs = try await names(fs, "/Compose Projects/stack/batch/var/log")
        XCTAssertEqual(logs, ["batch.log"])
    }

    // MARK: - What a listing says about each entry

    func test_aSymlinkIsReportedAsALink() async throws {
        let fs = try makeFS()
        let entries = try await collect(fs, "/Compose Projects/stack/web/etc")
        let link = try XCTUnwrap(entries.first { $0.name == "motd" })
        // The only channel a PFX plugin has for this is the S_IF* field of `mode` — see the note
        // on PfxFindData in pfx.h. Without the host reading it, a link is drawn as a plain file.
        XCTAssertEqual(link.kind, .symlinkFile)
        XCTAssertEqual(link.attrColumnString.first, "l")
        let plain = try XCTUnwrap(entries.first { $0.name == "hostname" })
        XCTAssertEqual(plain.kind, .file)
        XCTAssertEqual(plain.attrColumnString.first, "-")
    }

    func test_permissionBitsSurviveTheTrip() async throws {
        let fs = try makeFS()
        let entries = try await collect(fs, "/Compose Projects/stack/web/etc")
        let file = try XCTUnwrap(entries.first { $0.name == "hostname" })
        // The engine reports a Go FileMode, whose type bits are nothing like S_IFMT. Read as
        // POSIX without translating, this is a file of an impossible type with plausible
        // permissions — which looks right in a listing and is not.
        XCTAssertEqual(file.posixMode & 0o777, 0o644)
    }

    func test_contentColumnsCarryStatusAccessImageAndMount() async throws {
        let fs = try makeFS()
        _ = try await collect(fs, "/Compose Projects/stack")
        XCTAssertEqual(column(fs, "status", "/Compose Projects/stack/web"), "● running")
        XCTAssertEqual(column(fs, "image", "/Compose Projects/stack/web"), "nginx:1")

        // The requirement the Mount column exists for: a directory that is really a volume says
        // so, and names the volume, so the user can go to it under /Volumes.
        _ = try await collect(fs, "/Compose Projects/stack/web")
        XCTAssertEqual(column(fs, "access", "/Compose Projects/stack/web/data"), "VOL")
        XCTAssertEqual(column(fs, "mount", "/Compose Projects/stack/web/data"), "Volume: stack_data")
    }

    func test_aStoppedContainerSaysSoInTheStatusColumn() async throws {
        let fs = try makeFS()
        _ = try await collect(fs, "/Compose Projects/stack")
        XCTAssertEqual(column(fs, "status", "/Compose Projects/stack/batch"), "○ stopped")
    }

    // MARK: - Volumes

    func test_volumesAreDrivesOfTheirOwn() async throws {
        let fs = try makeFS()
        let volumes = try await names(fs, "/Volumes")
        XCTAssertEqual(volumes, ["orphaned_data", "stack_data", "stack_inner"])
        let inside = try await names(fs, "/Volumes/stack_data")
        // `inner` is the directory the nested mount sits on, and it is genuinely in this volume.
        XCTAssertEqual(inside, ["inner", "rows.db"])
    }

    func test_aVolumeNothingMountsIsStillBrowsable() async throws {
        // The point of listing volumes separately at all: a volume outlives the container that
        // made it, and that is usually where the data actually is. Reaching it means creating a
        // container around it, which the plugin does and then removes.
        let fs = try makeFS()
        let inside = try await names(fs, "/Volumes/orphaned_data")
        XCTAssertEqual(inside, ["orphan.txt"])
    }

    func test_theHelperContainerIsRemovedOnDisconnect() async throws {
        let fs = try makeFS()
        _ = try await names(fs, "/Volumes/orphaned_data")
        XCTAssertEqual(try engineContainerNames().filter { $0.hasPrefix("peachcommander-") }.count, 1,
                       "the volume should have been reached through a container made for it")
        await fs.disconnect()
        XCTAssertEqual(try engineContainerNames().filter { $0.hasPrefix("peachcommander-") }, [],
                       "a throwaway container outlived the mount that made it")
    }

    // MARK: - Reading

    func test_readingAFile() async throws {
        let fs = try makeFS()
        let found = try await fs.localFileIfAvailable(vpath("/Compose Projects/stack/web/etc/hostname"))
        let local = try XCTUnwrap(found)
        XCTAssertEqual(try String(contentsOf: local, encoding: .utf8),
                       "hello from the web container")
    }

    func test_readingASymlinkFollowsIt() async throws {
        // Docker's archive of a symlink is the *link*: a zero-byte entry. Copied out as-is it
        // reads as an empty file, which is indistinguishable from the file being empty.
        let fs = try makeFS()
        let found = try await fs.localFileIfAvailable(vpath("/Compose Projects/stack/web/etc/motd"))
        let local = try XCTUnwrap(found)
        XCTAssertEqual(try String(contentsOf: local, encoding: .utf8),
                       "hello from the web container")
    }

    func test_aNameTooLongForOneTarFieldSurvives() async throws {
        // USTAR splits a name over 100 bytes across its `prefix` field. Getting the split wrong
        // writes to a different path than the one asked for, quietly.
        let fs = try makeFS()
        let deep = "/Compose Projects/stack/web/srv/a/b/c/d/e/f/g/h/i/j/k/l/m"
        let deepest = try await names(fs, deep)
        XCTAssertEqual(deepest, ["a-name-long-enough-to-need-the-ustar-prefix-field.txt"])
    }

    // MARK: - Writing

    func test_writingAFileIntoAContainer() async throws {
        let fs = try makeFS()
        let source = dir.appendingPathComponent("upload.txt")
        try Data("written by the file manager".utf8).write(to: source)
        try await copyIn(fs, source, to: "/Compose Projects/stack/web/etc/added.conf")
        let afterUpload = try await names(fs, "/Compose Projects/stack/web/etc")
        XCTAssertTrue(afterUpload.contains("added.conf"))

        // The fixture refuses a tar carrying extended attributes with the same 500 the engine
        // sends, because macOS's own tar stamps `com.apple.provenance` on everything it packs and
        // the upload then fails *after* writing the file.
        let readBack = try await fs.localFileIfAvailable(vpath("/Compose Projects/stack/web/etc/added.conf"))
        let back = try XCTUnwrap(readBack)
        XCTAssertEqual(try String(contentsOf: back, encoding: .utf8), "written by the file manager")
    }

    func test_writingIntoAVolume() async throws {
        let fs = try makeFS()
        let source = dir.appendingPathComponent("row.txt")
        try Data("another row".utf8).write(to: source)
        try await copyIn(fs, source, to: "/Volumes/orphaned_data/added.txt")
        let after = try await names(fs, "/Volumes/orphaned_data")
        XCTAssertEqual(after, ["added.txt", "orphan.txt"])
    }

    func test_creatingADirectory() async throws {
        let fs = try makeFS()
        try await fs.mkdir(vpath("/Compose Projects/stack/web/etc/conf.d"))
        let after = try await names(fs, "/Compose Projects/stack/web/etc")
        XCTAssertTrue(after.contains("conf.d"))
    }

    func test_deletingAndRenaming() async throws {
        let fs = try makeFS()
        try await fs.rename(vpath("/Compose Projects/stack/web/etc/hostname"),
                            to: vpath("/Compose Projects/stack/web/etc/hostname.bak"))
        let renamed = try await names(fs, "/Compose Projects/stack/web/etc")
        XCTAssertTrue(renamed.contains("hostname.bak"))
        try await fs.delete(vpath("/Compose Projects/stack/web/etc/hostname.bak"))
        let deleted = try await names(fs, "/Compose Projects/stack/web/etc")
        XCTAssertFalse(deleted.contains("hostname.bak"))
    }

    // MARK: - The refusals, which are the part worth getting right

    func test_deletingInAStoppedContainerIsRefusedRatherThanFaked() async throws {
        // There is no delete endpoint in the Docker Engine API at all; the only way is to run
        // something in the container, and a stopped container cannot run anything. Saying so is
        // the honest answer — the alternative is a file that looks deleted and is not.
        let fs = try makeFS()
        await assertThrows(.unsupported) {
            try await fs.delete(self.vpath("/Compose Projects/stack/batch/var/log/batch.log"))
        }
    }

    func test_aReadOnlyRootfsRefusesAWrite() async throws {
        let fs = try makeFS()
        let source = dir.appendingPathComponent("nope.txt")
        try Data("no".utf8).write(to: source)
        await assertThrows(.permissionDenied(.modeBits)) {
            try await self.copyIn(fs, source, to: "/Standalone Containers/frozen/etc/nope.conf")
        }
    }

    func test_aPathTheContainersUserMayNotTouchReportsPermissionDenied() async throws {
        // The engine hands back the utility's own sentence and nothing else, so "Operation not
        // permitted" has to be read out of it. Running the command as root instead would be the
        // application overriding the image's permissions, which is not its decision to make.
        let fs = try makeFS()
        await assertThrows(.permissionDenied(.modeBits)) {
            try await fs.delete(self.vpath("/Compose Projects/stack/web/locked/pinned.txt"))
        }
    }

    func test_writingToTheVirtualLevelsIsRefused() async throws {
        let fs = try makeFS()
        await assertThrows(.unsupported) {
            try await fs.mkdir(self.vpath("/Compose Projects/nowhere"))
        }
    }

    func test_aMissingPathIsNotFound() async throws {
        let fs = try makeFS()
        await assertThrows(.notFound("")) {
            _ = try await fs.stat(self.vpath("/Compose Projects/stack/web/etc/absent.conf"))
        }
    }

    // MARK: - Listing without running anything in the container

    func test_theProviderWorksWithExecSwitchedOffEntirely() async throws {
        // The guarantee the design rests on: the archive API is the foundation and `exec` is a
        // fallback for one case. With it off, everything that reads still reads.
        setenv("PC_DOCKER_EXEC", "0", 1)
        let fs = try makeFS()
        let etc = try await names(fs, "/Compose Projects/stack/web/etc")
        XCTAssertEqual(etc, ["hostname", "motd", "nginx"])
        let volume = try await names(fs, "/Volumes/stack_data")
        XCTAssertEqual(volume, ["inner", "rows.db"])
        // …and the two operations that genuinely cannot be done without it say so.
        await assertThrows(.unsupported) {
            try await fs.delete(self.vpath("/Compose Projects/stack/web/etc/hostname"))
        }
    }

    func test_aDirectoryTooLargeToReadAsAnArchiveIsListedByTheContainerItself() async throws {
        // Both budgets are set below the size of this subtree, so the archive route cannot answer
        // at all — a correct listing here is proof that the fallback ran and that it produced the
        // same answer, not merely that the directory was small enough the first way.
        try writeSettings(probeMB: 1, maxMB: 1)
        let fs = try makeFS()
        let entries = try await names(fs, "/Compose Projects/stack/web")
        // `docker-logs.txt` is the container's log offered as a file — see `DockerLog`. It is in the
        // root listing whichever way that listing was produced.
        XCTAssertEqual(entries, ["big.bin", "data", "database", "docker-logs.txt", "etc", "hostlogs", "locked", "names", "srv"])
        // The metadata still comes from the engine's own stat, not from parsing `ls -l` output.
        let srv = try await collect(fs, "/Compose Projects/stack/web").first { $0.name == "srv" }
        XCTAssertEqual(srv?.kind, .directory)
    }

    func test_withoutTheFallbackSuchADirectoryFailsRatherThanShowingHalfOfIt() async throws {
        // The alternative to failing is a directory that lists three of its twenty entries and
        // looks like a directory with three entries. This is the honest answer.
        try writeSettings(probeMB: 1, maxMB: 1)
        setenv("PC_DOCKER_EXEC", "0", 1)
        let fs = try makeFS()
        await assertThrows(.unsupported) {
            _ = try await self.collect(fs, "/Compose Projects/stack/web")
        }
    }

    // MARK: - The container and volume actions (contributions)

    func test_copyIdentifierTakesTheFullContainerId() throws {
        let fs = try makeFS()
        try runCommand("plugin.docker.copyid", cursor: "/Compose Projects/stack/web", on: fs)
        // The full id, not the twelve characters the ID column shows: this is for pasting into a
        // `docker` command, and a short id is a prefix that can stop being unique.
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "c-web")
    }

    func test_jumpToVolumeGoesToTheVolumeTheDirectoryReallyIs() throws {
        let fs = try makeFS()
        try runCommand("plugin.docker.jumptovolume",
                       cursor: "/Compose Projects/stack/web/data", on: fs)
        // The destination is a path in the *mount*, which is the whole reason the host's `openPath`
        // had to stop asking `FileManager` whether it exists.
        XCTAssertEqual(dockerStubOpened, ["/Volumes/stack_data"])
    }

    func test_jumpToVolumeRefusesADirectoryThatIsNotOne() throws {
        let fs = try makeFS()
        try runCommand("plugin.docker.jumptovolume",
                       cursor: "/Compose Projects/stack/web/etc", on: fs)
        XCTAssertEqual(dockerStubOpened, [], "nothing should have been navigated to")
        XCTAssertFalse(dockerStubInformed.isEmpty, "the refusal has to say something")
    }

    func test_openComposeProjectGoesToTheProject() throws {
        let fs = try makeFS()
        try runCommand("plugin.docker.composeproject",
                       cursor: "/Compose Projects/stack/web", on: fs)
        XCTAssertEqual(dockerStubOpened, ["/Compose Projects/stack"])
    }

    func test_anActionOutsideADockerPanelIsRefused() throws {
        let fs = try makeFS()
        // The declarative `when` gates these to a Docker drive, but a command is also reachable from
        // the command browser, a shortcut and the button bar — none of which consult it.
        try runCommand("plugin.docker.copyid", cursor: "/Users/someone/notes.txt",
                       scheme: "file", on: fs)
        XCTAssertEqual(dockerStubOpened, [])
        XCTAssertFalse(dockerStubInformed.isEmpty)
    }

    // MARK: - Which mount owns a path

    func test_aMountDoesNotClaimAPathThatMerelyStartsWithItsName() async throws {
        // "/database" begins with the string "/data" and is **not** under the volume mounted there.
        // It also has no mount of its own, which is what makes this distinguishing: with a mount at
        // the neighbouring path the correct answer would win on length anyway, and the test would
        // pass for a matcher that compares strings instead of paths. Measured — it did.
        let fs = try makeFS()
        _ = try await collect(fs, "/Compose Projects/stack/web")
        XCTAssertEqual(column(fs, "mount", "/Compose Projects/stack/web/data"),
                       "Volume: stack_data")
        XCTAssertEqual(column(fs, "mount", "/Compose Projects/stack/web/database"), "",
                       "a directory that merely starts with a mount's name was claimed by it")
        XCTAssertEqual(column(fs, "access", "/Compose Projects/stack/web/database"), "RW")
        // And a bind still reports as one, with the host path behind it.
        XCTAssertEqual(column(fs, "mount", "/Compose Projects/stack/web/hostlogs"),
                       "Bind: /host/logs")
        XCTAssertEqual(column(fs, "access", "/Compose Projects/stack/web/hostlogs"), "BIND RO")
    }

    func test_theDeepestMountWinsForAPathInsideAnother() async throws {
        // `/data/inner` sits inside `/data`. The row has to name the volume the directory really
        // is, not the one it happens to be nested in — and Jump to Volume goes by the same answer.
        let fs = try makeFS()
        _ = try await collect(fs, "/Compose Projects/stack/web/data")
        XCTAssertEqual(column(fs, "mount", "/Compose Projects/stack/web/data/inner"),
                       "Volume: stack_inner")
        let inside = try await names(fs, "/Compose Projects/stack/web/data/inner")
        XCTAssertEqual(inside, ["deep.txt"])
    }

    // MARK: - A connection that dies in the middle of an answer

    func test_aConnectionLostMidBodyIsNotRetriedOverAHalfWrittenFile() async throws {
        // The retry exists for a kept-alive socket the daemon has since closed, which fails before
        // answering. Applied to a drop *mid-body* it re-delivers the answer from the beginning into
        // a consumer that is half-way through one: the file on disk keeps what arrived before the
        // drop and then gets a whole fresh stream appended. This engine drops once, so with the
        // retry in place the call would *succeed* — with a file larger than the original.
        let socket = try startDroppingServer(after: 64 * 1024)
        setenv("PC_DOCKER_HOST", "unix://\(socket)", 1)
        let fs = try makeFS()

        let destination = dir.appendingPathComponent("torn.bin")
        await assertThrows(.connectionLost(retryable: true)) {
            _ = try await fs.downloadFile(self.vpath("/Compose Projects/stack/web/big.bin"),
                                          to: destination, resume: false)
        }

        // And the mount still works afterwards. A response abandoned mid-body used to leave the
        // socket cached with the rest of it unread, so the next request read the tail of the old
        // answer as its own response head.
        let etc = try await names(fs, "/Compose Projects/stack/web/etc")
        XCTAssertEqual(etc, ["hostname", "motd", "nginx"])
    }

    func test_anAnswerAbandonedMidBodyDoesNotPoisonTheNextRequest() async throws {
        // The case a dropped connection cannot produce: the answer goes wrong while the socket is
        // still perfectly usable. The plugin gives up on a response it is half-way through, and if
        // it keeps that socket the next request reads the rest of this answer as its own response
        // head. A dead connection self-heals — the write fails and the retry opens a fresh one — so
        // only a *live* one with an unread tail shows whether the socket is really dropped.
        let socket = try startDroppingServer(after: 64 * 1024, key: "badChunkAfter")
        setenv("PC_DOCKER_HOST", "unix://\(socket)", 1)
        let fs = try makeFS()

        // *That* it fails is not the claim — a garbled answer is reported as bad data, which is
        // what it is. The claim is the line after it.
        let destination = dir.appendingPathComponent("garbled.bin")
        do {
            _ = try await fs.downloadFile(vpath("/Compose Projects/stack/web/big.bin"),
                                          to: destination, resume: false)
            XCTFail("a malformed chunk size should not have been read as a file")
        } catch {}

        // The mount still works. This is the assertion the socket-dropping `defer` exists for, and
        // it is why this test exists at all: the *dropped-connection* test passes with or without
        // that defer, because a dead socket heals itself on the next write. Only a live one with an
        // unread tail can tell.
        let etc = try await names(fs, "/Compose Projects/stack/web/etc")
        XCTAssertEqual(etc, ["hostname", "motd", "nginx"])
    }

    func test_aLongNonAsciiNameSurvivesThePaxHeaderThatCarriesIt() async throws {
        let fs = try makeFS()
        let expected = String(repeating: "ü", count: 60) + ".txt"
        let entries = try await names(fs, "/Compose Projects/stack/web/names")
        XCTAssertEqual(entries, [expected],
                       "the name came back as something else")
    }

    // MARK: - Names a tar header cannot hold

    func test_aFileNameLongerThanATarHeaderFieldArrivesWithItsName() async throws {
        // USTAR's name field is 100 bytes and its prefix field splits on a "/" — which a *file name*
        // has none of, so a long name has nowhere to go. macOS allows 255 bytes.
        let fs = try makeFS()
        let long = String(repeating: "a", count: 120) + ".txt"
        let source = dir.appendingPathComponent("long-source.txt")
        try Data("payload".utf8).write(to: source)
        try await copyIn(fs, source, to: "/Compose Projects/stack/web/etc/\(long)")

        let after = try await names(fs, "/Compose Projects/stack/web/etc")
        XCTAssertTrue(after.contains(long),
                      "the name was not preserved; the directory holds \(after)")
    }

    // MARK: - Stopping a transfer

    func test_cancellingADownloadStopsItAndSaysItWasCancelled() async throws {
        let fs = try makeFS()
        dockerStubCancelAfter = 1
        let destination = dir.appendingPathComponent("cancelled.bin")
        await assertThrows(.cancelled) {
            _ = try await fs.downloadFile(self.vpath("/Compose Projects/stack/web/big.bin"),
                                          to: destination, resume: false)
        }
        // It *stopped*. The flag used to be read only after the transfer had finished, so Cancel on
        // a large file downloaded the whole thing and then reported — the button delayed the bad
        // news and nothing else. A completed 4 MB read reports progress about a hundred times.
        XCTAssertLessThan(dockerStubProgressCalls, 10,
                          "the transfer ran on after Cancel (\(dockerStubProgressCalls) reports)")
        // And what it managed to write is gone, rather than left at the destination looking like a
        // copy that worked.
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func test_aCompletedDownloadIsNotMistakenForACancelledOne() async throws {
        // The control: without it "fewer than ten reports" would also pass for a transfer that never
        // reported at all, and the cancellation test would be measuring nothing.
        let fs = try makeFS()
        let destination = dir.appendingPathComponent("whole.bin")
        _ = try await fs.downloadFile(vpath("/Compose Projects/stack/web/big.bin"),
                                      to: destination, resume: false)
        XCTAssertGreaterThan(dockerStubProgressCalls, 50)
        XCTAssertEqual((try? FileManager.default.attributesOfItem(atPath: destination.path)[.size]
                        as? NSNumber)??.int64Value, 4 * 1024 * 1024)
    }

    func test_cancellingAnUploadSaysItWasCancelledRatherThanCorrupt() async throws {
        // It used to throw the plugin's "the engine answered something unreadable" error, which the
        // host renders as a data fault: stopping a copy is not the copy having been corrupt.
        let fs = try makeFS()
        let source = dir.appendingPathComponent("big-upload.bin")
        try Data(count: 4 * 1024 * 1024).write(to: source)
        dockerStubCancelAfter = 1
        await assertThrows(.cancelled) {
            _ = try await fs.uploadFile(source,
                                        to: self.vpath("/Compose Projects/stack/web/etc/up.bin"),
                                        resume: false)
        }
    }

    // MARK: - The log as a file

    func test_theContainersLogIsOfferedAsAFileInItsRoot() async throws {
        let fs = try makeFS()
        let entries = try await collect(fs, "/Standalone Containers/redis-test")
        let log = try XCTUnwrap(entries.first { $0.name == "docker-logs.txt" })
        XCTAssertEqual(log.kind, .file)
        // Read-only, because there is nothing in the container to write to.
        XCTAssertEqual(log.posixMode & 0o222, 0)
    }

    func test_readingTheLogFileGivesTheLog() async throws {
        let fs = try makeFS()
        let found = try await fs.localFileIfAvailable(
            vpath("/Standalone Containers/redis-test/docker-logs.txt"))
        let local = try XCTUnwrap(found)
        let text = try String(contentsOf: local, encoding: .utf8)
        XCTAssertTrue(text.contains("ready to accept connections"), "got: \(text)")
        // Demultiplexed: the engine frames a non-TTY container's log the way it frames an attached
        // exec, and a reader that forgot that would show eight bytes of header before the first line.
        XCTAssertFalse(text.hasPrefix("\u{01}"))
    }

    func test_aRealFileOfThatNameWinsOverTheLog() async throws {
        // Hiding a file that is genuinely in the image would be the worse trade, so the container's
        // own file is what the row means — and what reading it gives.
        let fs = try makeFS()
        let entries = try await collect(fs, "/Standalone Containers/shadowed")
        XCTAssertEqual(entries.filter { $0.name == "docker-logs.txt" }.count, 1)
        let found = try await fs.localFileIfAvailable(
            vpath("/Standalone Containers/shadowed/docker-logs.txt"))
        let local = try XCTUnwrap(found)
        XCTAssertEqual(try String(contentsOf: local, encoding: .utf8), "this one is real")
    }

    func test_theLogRefusesToBeWrittenOver() async throws {
        // Without this, a copy onto the row would create a real file of that name inside the
        // container — which then wins, and looks exactly like the log having been overwritten.
        let fs = try makeFS()
        let source = dir.appendingPathComponent("nope.txt")
        try Data("no".utf8).write(to: source)
        await assertThrows(.unsupported) {
            try await self.copyIn(fs, source, to: "/Standalone Containers/redis-test/docker-logs.txt")
        }
        await assertThrows(.unsupported) {
            try await fs.delete(self.vpath("/Standalone Containers/redis-test/docker-logs.txt"))
        }
    }

    func test_theLogsTimestampMovesSoAStaleCopyCannotBeServed() async throws {
        // `MemberStage` keys its temporary copies by size and modification time. A log that reported
        // neither changing would be fetched once and shown for the rest of the session.
        let fs = try makeFS()
        let first = try await collect(fs, "/Standalone Containers/redis-test")
            .first { $0.name == "docker-logs.txt" }?.modified
        try await Task.sleep(nanoseconds: 1_100_000_000)
        let second = try await collect(fs, "/Standalone Containers/redis-test")
            .first { $0.name == "docker-logs.txt" }?.modified
        XCTAssertNotEqual(first, second)
    }

    // MARK: - Lifecycle

    func test_stoppingAContainerChangesWhatTheStatusColumnSays() async throws {
        setenv("PC_DOCKER_CONFIRM", "1", 1)
        let fs = try makeFS()
        _ = try await collect(fs, "/Compose Projects/stack")
        XCTAssertEqual(column(fs, "status", "/Compose Projects/stack/web"), "● running")

        try runCommand("plugin.docker.lifecycle.stop", cursor: "/Compose Projects/stack/web", on: fs)

        // Re-listed, because the column is answered from the listing that was taken before — which
        // is exactly why the command tells the panel to reload.
        _ = try await collect(fs, "/Compose Projects/stack")
        XCTAssertEqual(column(fs, "status", "/Compose Projects/stack/web"), "○ stopped")
    }

    func test_refusingTheConfirmationChangesNothing() async throws {
        // The half that matters more: a state-changing action that ran anyway would be found by
        // nobody until it had already happened.
        setenv("PC_DOCKER_CONFIRM", "0", 1)
        let fs = try makeFS()
        try runCommand("plugin.docker.lifecycle.stop", cursor: "/Compose Projects/stack/web", on: fs)
        _ = try await collect(fs, "/Compose Projects/stack")
        XCTAssertEqual(column(fs, "status", "/Compose Projects/stack/web"), "● running")
    }

    func test_startingAContainerThatIsAlreadyRunningIsNotAnError() async throws {
        // The engine answers 304 for "it is already like that". Read as a failure it would report
        // "the engine refused" for the one case where nothing was wrong.
        setenv("PC_DOCKER_CONFIRM", "1", 1)
        let fs = try makeFS()
        try runCommand("plugin.docker.lifecycle.start", cursor: "/Compose Projects/stack/web", on: fs)
        XCTAssertEqual(dockerStubInformed, [], "a 304 must not be reported as a refusal")
    }

    func test_lifecycleOnSomethingThatIsNotAContainerIsRefused() throws {
        setenv("PC_DOCKER_CONFIRM", "1", 1)
        let fs = try makeFS()
        try runCommand("plugin.docker.lifecycle.stop", cursor: "/Volumes/orphaned_data", on: fs)
        XCTAssertFalse(dockerStubInformed.isEmpty)
    }

    // MARK: - Helpers

    /// Invoke a contributed command with a stub host table, the way the panel's context menu does.
    ///
    /// `fs` is taken and held for the length of the call, and that is load-bearing rather than
    /// tidiness: the plugin registers the mounted engine when `PfxConnect` succeeds and forgets it in
    /// `PfxDisconnect`, so a mount whose `PFXFileSystem` has already been released leaves a command
    /// with no engine to talk to. Discarding the result of `makeFS()` made every one of these tests
    /// fail as "the command did nothing", which is also what a genuinely broken command looks like.
    private func runCommand(_ id: String, cursor: String, scheme: String = "docker:Docker",
                            on fs: PFXFileSystem) throws {
        typealias RunCommand = @convention(c) (UnsafePointer<CChar>?,
                                               UnsafePointer<PcHostServices>?) -> Void
        let symbol = try XCTUnwrap(lib.symbol("PcRunCommand"),
                                   "the plugin does not export PcRunCommand")
        dockerStubCursor = cursor
        dockerStubScheme = scheme
        dockerStubOpened = []
        dockerStubInformed = []
        NSPasteboard.general.clearContents()

        var services = PcHostServices()
        services.cursorPath = dockerStubCursorPath
        services.getContext = dockerStubGetContext
        services.openPath = dockerStubOpenPath
        services.presentInfo = dockerStubPresentInfo
        try withExtendedLifetime(fs) {
            withUnsafePointer(to: &services) { table in
                id.withCString { unsafeBitCast(symbol, to: RunCommand.self)($0, table) }
            }
        }
    }

    private func copyIn(_ fs: PFXFileSystem, _ source: URL, to path: String) async throws {
        let data = try Data(contentsOf: source)
        let stream = try await fs.openWrite(vpath(path), options: WriteOptions())
        try await stream.write(data)
        try await stream.close()
    }

    private func engineContainerNames() throws -> [String] {
        // Asked of the fixture directly, over its own socket, so the assertion does not depend on
        // the thing it is checking.
        let listing = try DockerFixtureClient(socketPath: socketPath).containerNames()
        return listing
    }

    private func assertThrows(_ expected: VFSError, _ body: () async throws -> Void,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await body()
            XCTFail("expected \(expected), but the call succeeded", file: file, line: line)
        } catch let error as VFSError {
            switch (error, expected) {
            case (.unsupported, .unsupported),
                 (.permissionDenied, .permissionDenied),
                 (.notFound, .notFound),
                 (.cancelled, .cancelled),
                 (.connectionLost, .connectionLost):
                break
            default:
                XCTFail("expected \(expected), got \(error)", file: file, line: line)
            }
        } catch {
            XCTFail("expected \(expected), got \(error)", file: file, line: line)
        }
    }
}

/// The smallest possible HTTP client for the fixture's socket, so a test can ask the engine what
/// it holds without going through the plugin it is testing.
private struct DockerFixtureClient {
    let socketPath: String

    func containerNames() throws -> [String] {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return [] }
        defer { close(fd) }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(socketPath.utf8)
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            raw.copyBytes(from: bytes)
            raw[bytes.count] = 0
        }
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { return [] }
        let request = "GET /v1.44/containers/json?all=true HTTP/1.1\r\nHost: docker\r\nConnection: close\r\n\r\n"
        _ = Data(request.utf8).withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }

        var response = Data()
        var buffer = [UInt8](repeating: 0, count: 65536)
        while true {
            let got = read(fd, &buffer, buffer.count)
            if got <= 0 { break }
            response.append(contentsOf: buffer[0..<got])
        }
        guard let separator = response.range(of: Data("\r\n\r\n".utf8)) else { return [] }
        let body = response[separator.upperBound...]
        guard let list = try? JSONSerialization.jsonObject(with: Data(body)) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { ($0["Names"] as? [String])?.first }
            .map { $0.hasPrefix("/") ? String($0.dropFirst()) : $0 }
    }
}
