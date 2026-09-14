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
        server?.terminate()
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
        try fm.createDirectory(at: fs.appendingPathComponent("web/locked"), withIntermediateDirectories: true)
        try write("cannot touch this", "web/locked/pinned.txt")
        // A symlink, which the panel has to draw as a link rather than as an empty file.
        try fm.createSymbolicLink(atPath: fs.appendingPathComponent("web/etc/motd").path,
                                  withDestinationPath: "/etc/hostname")

        // Big enough to blow a one-megabyte budget, so the fallback path can be reached on
        // purpose. Generated here rather than committed — see the fixture rule in CONVENTIONS.md.
        let blob = fs.appendingPathComponent("web/srv/blob.bin")
        try Data(count: 2 * 1024 * 1024).write(to: blob)

        try write("worker one", "worker1/etc/id")
        try write("worker two", "worker2/etc/id")
        try write("batch ran", "batch/var/log/batch.log")
        try write("standalone", "redis/etc/redis.conf")
        try write("locked down", "readonly/etc/frozen.conf")
        try write("a row in the database", "vol-data/rows.db")
        try write("nothing mounts me", "vol-orphan/orphan.txt")

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
                             "Destination": "/data", "RW": true]]],
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
                 "root": "redis", "labels": [:]],
                ["name": "frozen", "id": "c-frozen", "state": "running", "image": "frozen:1",
                 "root": "readonly", "labels": [:], "readOnlyRootfs": true],
            ],
            "volumes": [
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

    private func initPlugin(configRoot: URL) {
        dockerStubConfigRoot = configRoot.path
        var services = PfxHostServices()
        services.getContext = { _, key, out, maxlen in
            guard let key, let out, maxlen > 0, String(cString: key) == "configRoot" else { return 0 }
            _ = dockerStubConfigRoot.withCString { strlcpy(out, $0, Int(maxlen)) }
            return 1
        }
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
        XCTAssertEqual(entries, ["data", "etc", "locked", "srv"])
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
        XCTAssertEqual(standalone, ["frozen", "redis-test"])
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
        XCTAssertEqual(volumes, ["orphaned_data", "stack_data"])
        let inside = try await names(fs, "/Volumes/stack_data")
        XCTAssertEqual(inside, ["rows.db"])
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
        XCTAssertEqual(volume, ["rows.db"])
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
        XCTAssertEqual(entries, ["data", "etc", "locked", "srv"])
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
