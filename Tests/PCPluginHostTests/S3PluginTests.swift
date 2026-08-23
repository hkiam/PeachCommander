// SPDX-License-Identifier: Apache-2.0
// S3PluginTests.swift - The S3 plugin, end to end against a real socket that checks its signatures.
//
// Built the way Tools/build-s3-plugin.sh builds it, pointed at Fixtures/s3server.py, and driven
// through `PFXFileSystem` — the same path the app uses. Skips rather than fails when swiftc or
// python3 is unavailable, as the other plugin-building tests here do.
//
// The fixture *verifies* SigV4 rather than accepting it, which is what makes these tests worth
// having. Every assertion below about a listing or an object is also an assertion that the canonical
// request, the signed headers and the payload hash were all right — a signing bug does not produce a
// subtly wrong listing here, it produces 403 on everything.

import XCTest
import PCVFS
import CPFX
@testable import PCPluginHost

/// The config root the stub host hands the plugin. A file-scope variable because a `@convention(c)`
/// callback cannot capture, and this has to be readable from inside one.
private nonisolated(unsafe) var s3StubConfigRoot = ""

final class S3PluginTests: XCTestCase {
    private var dir: URL!
    private var serving: URL!
    private var server: Process!
    private var port = 0
    private var lib: PluginLibrary!
    private var inited: PFXPlugin!

    private static let accessKey = "peachtestkey"
    private static let secretKey = "peachtestsecret"

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    // MARK: - Fixture wiring

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("s3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        lib = try Self.buildPlugin(repoRoot: repoRoot, into: dir)
        serving = try makeTree()
        (server, port) = try startServer(root: serving, maxKeys: nil)

        // The connect facet reads these instead of showing its modal dialog, and they are set on the
        // test process because that is the process whose environment `PfxConnect` inspects.
        setenv("PC_S3_ENDPOINT", "http://127.0.0.1:\(port)", 1)
        setenv("PC_S3_REGION", "us-east-1", 1)
        setenv("PC_S3_ACCESS_KEY", Self.accessKey, 1)
        setenv("PC_S3_SECRET_KEY", Self.secretKey, 1)
        setenv("PC_S3_PATH_STYLE", "1", 1)
        setenv("PC_S3_PROFILE", "fixture", 1)

        // Tell the plugin where "configuration" is before anything connects. Not politeness:
        // connecting can append to the profile list, and without this every run would write a
        // throwaway localhost profile into the developer's own settings.
        initPlugin(configRoot: dir.appendingPathComponent("config"))
    }

    override func tearDownWithError() throws {
        for name in ["PC_S3_ENDPOINT", "PC_S3_REGION", "PC_S3_ACCESS_KEY",
                     "PC_S3_SECRET_KEY", "PC_S3_PATH_STYLE", "PC_S3_PROFILE"] {
            unsetenv(name)
        }
        server?.terminate()
        if let dir { try? FileManager.default.removeItem(at: dir) }
    }

    /// Compile the plugin exactly as `Tools/build-s3-plugin.sh` does, and open it.
    ///
    /// Shared with `S3ConformanceTests` and `S3LiveTests`, which drive the same plugin against a
    /// real MinIO server — two copies of this would be two source lists to forget a file from.
    ///
    /// The compile itself happens once per test run (see `CachedPluginBuild`); each caller still
    /// gets its own copy of the dylib in `dir`, so each `dlopen` is a separate image with its own
    /// globals. That matters here more than elsewhere: connecting writes profiles, and two tests
    /// sharing one image would share what the first one wrote.
    static func buildPlugin(repoRoot: URL, into dir: URL) throws -> PluginLibrary {
        let out = try CachedPluginBuild.freshBuild(key: "s3", into: dir) { cache in
            let swiftc = "/usr/bin/swiftc"
            try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: swiftc), "swiftc unavailable")
            let out = cache.appendingPathComponent("libs3.dylib")
            // Must stay in step with Tools/build-s3-plugin.sh. Tools/check-plugin-sources.py is what
            // keeps them in step, because forgetting one here builds a plugin the tests cannot see and
            // forgetting it there ships a plugin that does not link.
            let sources = ["s3", "S3Signer", "S3XML", "S3Client", "S3Transfer", "S3Write",
                           "S3Profiles", "S3AWSConfig", "S3ConnectDialog"]
                .map { repoRoot.appendingPathComponent("Plugins/S3/\($0).swift").path }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: swiftc)
            p.arguments = ["-emit-library", "-module-name", "S3", "-framework", "AppKit",
                           "-import-objc-header",
                           repoRoot.appendingPathComponent("Plugins/S3/S3Bridging.h").path,
                           "-Xcc", "-I\(repoRoot.appendingPathComponent("Plugins/SDK").path)",
                           "-o", out.path]
                + sources
                + [repoRoot.appendingPathComponent("Plugins/SDK/PluginLoc.swift").path]
            let pipe = Pipe(); p.standardError = pipe
            try p.run(); p.waitUntilExit()
            // A compiler that RAN and refused the plugin is a failure, not a skip. The skip above is for
            // a machine without swiftc; using it here too meant that when the plugin genuinely stopped
            // compiling — a source file missing from the list, say — every test in this file quietly
            // skipped and the suite reported success. That happened, and the only trace was a compiler
            // error buried in a log that ended with "** TEST SUCCEEDED **".
            //
            // The failure is cached along with the artifact, so it is still every test in the class
            // that goes red — the compiler just only runs once to establish it.
            guard p.terminationStatus == 0 else {
                let e = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                throw PluginBuildFailure(description: "the S3 plugin did not compile:\n\(e)")
            }
            return out
        }
        guard case .success(let lib) = PluginLibrary.open(
            path: out.path, required: PFXSymbols.required, optional: PFXSymbols.optional) else {
            throw PluginBuildFailure(description: "the S3 plugin compiled but could not be loaded")
        }
        return lib
    }

    /// Two buckets: one with nested prefixes and awkward names, one flat.
    private func makeTree() throws -> URL {
        let root = dir.appendingPathComponent("store")
        let fm = FileManager.default
        for sub in ["photos/2006", "photos/2007", "backups"] {
            try fm.createDirectory(at: root.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
        try Data("hello s3".utf8).write(to: root.appendingPathComponent("photos/readme.txt"))
        try Data("nested".utf8).write(to: root.appendingPathComponent("photos/2006/a.jpg"))
        // A key with a space and a "+". Both are encoded differently in a path than in a query, and
        // both are where a signer that encodes one way and addresses another falls over.
        try Data("odd bytes".utf8).write(to: root.appendingPathComponent("photos/odd +name.txt"))
        try Data("top".utf8).write(to: root.appendingPathComponent("backups/top.bin"))
        return root
    }

    private func startServer(root: URL, maxKeys: Int?,
                            dieAfterListings: Int? = nil,
                            failPart: Int? = nil,
                            region: String = "us-east-1",
                            flaky: Int? = nil,
                            flakyMethods: String? = nil,
                            statsFile: URL? = nil) throws -> (Process, Int) {
        let python = "/usr/bin/python3"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: python), "python3 unavailable")
        let chosen = try Self.freePort()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: python)
        p.arguments = [URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/s3server.py").path, root.path, String(chosen)]
        var env = ProcessInfo.processInfo.environment
        env["PC_S3_FIXTURE_KEY"] = Self.accessKey
        env["PC_S3_FIXTURE_SECRET"] = Self.secretKey
        env["PC_S3_FIXTURE_REGION"] = region
        if let maxKeys { env["PC_S3_FIXTURE_MAX_KEYS"] = String(maxKeys) }
        if let dieAfterListings { env["PC_S3_FIXTURE_DIE_AFTER_LISTINGS"] = String(dieAfterListings) }
        if let failPart { env["PC_S3_FIXTURE_FAIL_PART"] = String(failPart) }
        if let flaky { env["PC_S3_FIXTURE_FLAKY"] = String(flaky) }
        if let flakyMethods { env["PC_S3_FIXTURE_FLAKY_METHODS"] = flakyMethods }
        if let statsFile { env["PC_S3_FIXTURE_STATS_FILE"] = statsFile.path }
        p.environment = env
        p.standardOutput = Pipe(); p.standardError = Pipe()
        try p.run()
        try waitForServer(port: chosen)
        return (p, chosen)
    }

    /// A port nobody is using, taken by binding one and letting go.
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

    /// Poll until it answers, rather than sleeping a guessed amount: a fixed wait is either slow or
    /// occasionally short, and "occasionally short" reads as the plugin failing to connect.
    private func waitForServer(port: Int) throws {
        let url = URL(string: "http://127.0.0.1:\(port)/")!
        for _ in 0..<200 {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 1
            // Marked as a probe so the fixture does not count it and does not spend a configured
            // transient failure on it — polling until a 200 arrives would otherwise consume exactly
            // the 503s a retry test is trying to hand the plugin.
            request.setValue("1", forHTTPHeaderField: "x-fixture-ping")
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
        throw XCTSkip("the S3 fixture never came up")
    }

    private func initPlugin(configRoot: URL) {
        s3StubConfigRoot = configRoot.path
        var s = PfxHostServices()
        s.getContext = { _, key, out, maxlen in
            guard let key, let out, maxlen > 0, String(cString: key) == "configRoot" else { return 0 }
            _ = s3StubConfigRoot.withCString { strlcpy(out, $0, Int(maxlen)) }
            return 1
        }
        let plugin = PFXPlugin(library: lib)
        plugin.initialize(services: s)
        inited = plugin
    }

    private func makeFS() throws -> PFXFileSystem {
        typealias ConnectFn = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
        let connect = try XCTUnwrap(lib.symbol("PfxConnect"))
        let conn = try XCTUnwrap(unsafeBitCast(connect, to: ConnectFn.self)(nil),
                                 "PfxConnect returned nil — the plugin did not accept the endpoint")
        let plugin = PFXPlugin(library: lib)
        let fsID = plugin.connectionId(conn)
        // The qualifier the app uses is the connection id, and content field ids are
        // "<qualifier>.<leaf>" — without it `contentDisplay` resolves nothing and a column test would
        // pass by asking about a field that does not exist.
        return PFXFileSystem(plugin: plugin, conn: conn, fsID: fsID,
                             capabilities: plugin.capabilities, retaining: nil,
                             contentQualifier: fsID)
    }

    private func vpath(_ path: String) -> VFSPath { VFSPath(filesystemId: "s3", path: path) }

    private func collect(_ fs: PFXFileSystem, _ path: String) async throws -> [VFSEntry] {
        var all: [VFSEntry] = []
        for try await batch in fs.list(vpath(path)) { all += batch.entries }
        return all
    }

    // MARK: - Connecting

    func test_connect_namesTheEndpoint() throws {
        let fs = try makeFS()
        // What the host turns into the drive chip: `NetworkConnectionID` splits this into the host
        // and the kind "S3", with no change needed on the host side for a new scheme.
        XCTAssertEqual(fs.scheme, "s3:127.0.0.1:\(port)")
    }

    // MARK: - Listing

    func test_theRootOfTheMountIsTheBucketList() async throws {
        let fs = try makeFS()
        let entries = try await collect(fs, "/")
        XCTAssertEqual(entries.map(\.name).sorted(), ["backups", "photos"])
        // Buckets are directories, and a directory has no meaningful size.
        XCTAssertTrue(entries.allSatisfy { $0.kind == .directory })
        XCTAssertTrue(entries.allSatisfy { $0.size == -1 })
        // The owner block in a ListAllMyBucketsResult also contains a <DisplayName>; a parser that
        // keys on element names alone lists the account as a bucket.
        XCTAssertFalse(entries.contains { $0.name == "fixture-owner" })
    }

    func test_aBucketListsItsTopLevel_withPrefixesAsDirectories() async throws {
        let fs = try makeFS()
        let entries = try await collect(fs, "/photos")
        XCTAssertEqual(entries.map(\.name).sorted(), ["2006", "2007", "odd +name.txt", "readme.txt"])
        XCTAssertEqual(entries.first { $0.name == "2006" }?.kind, .directory)
        let readme = try XCTUnwrap(entries.first { $0.name == "readme.txt" })
        XCTAssertEqual(readme.kind, .file)
        XCTAssertEqual(readme.size, Int64("hello s3".utf8.count))
        XCTAssertGreaterThan(readme.modified.timeIntervalSince1970, 0,
                            "LastModified was not parsed — every object would sort as 1970")
    }

    func test_anEmptyPrefixIsStillADirectory() async throws {
        // "2007/" exists only as a prefix marker with nothing under it. An empty directory is a real
        // and ordinary thing, and reporting it as missing would be worse than showing it empty.
        let fs = try makeFS()
        let entries = try await collect(fs, "/photos/2007")
        XCTAssertEqual(entries.map(\.name), [])
    }

    func test_aPrefixIsNotListedInsideItself() async throws {
        // S3 has no directories: "photos/2006/" may exist as a zero-byte object, and it arrives in
        // both CommonPrefixes and Contents. Taken from both, the panel shows the folder twice — once
        // as a folder and once as an empty file — and the directory being listed appears inside
        // itself, which is an endless chain in the panel.
        let fs = try makeFS()
        let entries = try await collect(fs, "/photos/2006")
        XCTAssertEqual(entries.map(\.name), ["a.jpg"])
    }

    func test_descendingIntoAPrefix() async throws {
        let fs = try makeFS()
        let entries = try await collect(fs, "/photos/2006")
        XCTAssertEqual(entries.map(\.name), ["a.jpg"])
        XCTAssertEqual(entries.first?.size, Int64("nested".utf8.count))
    }

    func test_aBucketThatDoesNotExistIsReported() async throws {
        let fs = try makeFS()
        do {
            _ = try await collect(fs, "/no-such-bucket")
            XCTFail("listed a bucket the server does not have")
        } catch let e as VFSError {
            if case .notFound = e {} else { XCTFail("expected notFound, got \(e)") }
        }
    }

    func test_aPrefixThatDoesNotExistIsReported() async throws {
        let fs = try makeFS()
        do {
            _ = try await collect(fs, "/photos/nope")
            XCTFail("listed a prefix with nothing under it as though it existed")
        } catch let e as VFSError {
            if case .notFound = e {} else { XCTFail("expected notFound, got \(e)") }
        }
    }

    // MARK: - Reading

    func test_readingAnObjectReturnsItsBytes() async throws {
        let fs = try makeFS()
        let downloaded = try await fs.localFileIfAvailable(vpath("/photos/readme.txt"))
        let url = try XCTUnwrap(downloaded)
        XCTAssertEqual(try Data(contentsOf: url), Data("hello s3".utf8))
    }

    func test_aKeyWithASpaceAndAPlusIsAddressedAndSignedTheSameWay() async throws {
        // The test that earns the fixture's signature checking. A space must be "%20" and a "+" must
        // be "%2B" in both the URL and the canonical request; encode them differently in the two and
        // the server answers SignatureDoesNotMatch, which arrives here as an error rather than as
        // bytes. Form-encoding the "+" as a space would fetch a different key entirely.
        let fs = try makeFS()
        let downloaded = try await fs.localFileIfAvailable(vpath("/photos/odd +name.txt"))
        let url = try XCTUnwrap(downloaded)
        XCTAssertEqual(try Data(contentsOf: url), Data("odd bytes".utf8))
    }

    func test_readingAnObjectThatIsNotThereIsReported() async throws {
        let fs = try makeFS()
        do {
            _ = try await fs.localFileIfAvailable(vpath("/photos/ghost.txt"))
            XCTFail("read an object the server does not have")
        } catch let e as VFSError {
            if case .notFound = e {} else { XCTFail("expected notFound, got \(e)") }
        }
    }

    // MARK: - Stat

    func test_stat_knowsBucketsPrefixesAndObjects() async throws {
        let fs = try makeFS()

        let bucket = try await fs.stat(vpath("/photos"))
        XCTAssertEqual(bucket.kind, .directory)

        // A prefix has no object of its own here, so HEAD answers 404 and the plugin has to recognise
        // it by listing. Reported as a missing file, "go up" out of a folder would fail.
        let prefix = try await fs.stat(vpath("/photos/2006"))
        XCTAssertEqual(prefix.kind, .directory)

        let object = try await fs.stat(vpath("/photos/readme.txt"))
        XCTAssertEqual(object.kind, .file)
        XCTAssertEqual(object.size, Int64("hello s3".utf8.count))
        XCTAssertGreaterThan(object.modified.timeIntervalSince1970, 0)
    }

    func test_stat_ofTheMountRootDoesNotAskTheServer() async throws {
        // "/" is the bucket list. There is no S3 request that describes it, and inventing one means
        // the panel cannot enter its own root.
        let fs = try makeFS()
        let root = try await fs.stat(vpath("/"))
        XCTAssertEqual(root.kind, .directory)
    }

    // MARK: - Paging

    func test_aListingLongerThanOnePageReturnsEverything() async throws {
        // The plugin asks for 1000 keys and pages when the answer is truncated. With the fixture
        // capped at 3 keys a 40-object directory is fourteen pages, which is the only way to find out
        // whether the continuation token is carried and whether the last page is included.
        let root = dir.appendingPathComponent("paged")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("many"),
                                                withIntermediateDirectories: true)
        let expected = (0..<40).map { String(format: "object-%02d.txt", $0) }
        for name in expected {
            try Data(name.utf8).write(to: root.appendingPathComponent("many/\(name)"))
        }
        let (extra, extraPort) = try startServer(root: root, maxKeys: 3)
        defer { extra.terminate() }

        setenv("PC_S3_ENDPOINT", "http://127.0.0.1:\(extraPort)", 1)
        let fs = try makeFS()
        let names = try await collect(fs, "/many").map(\.name).sorted()
        XCTAssertEqual(names, expected)
    }

    func test_aServerThatDiesBetweenPagesIsNotReportedAsAShortDirectory() async throws {
        // The defect lazy paging creates. `PfxFindNext` returning 0 means "no more entries" and
        // nothing else, so a connection lost between two pages looks exactly like reaching the end:
        // the panel shows part of the directory and calls it complete. That is worse than an error,
        // because nothing on screen suggests anything is missing. The host now asks `PfxLastError`
        // once the enumeration finishes, and acts only on a lost connection.
        let root = dir.appendingPathComponent("dying")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("many"),
                                                withIntermediateDirectories: true)
        for index in 0..<40 {
            let name = String(format: "object-%02d.txt", index)
            try Data(name.utf8).write(to: root.appendingPathComponent("many/\(name)"))
        }
        // Three keys per page, and the server stops existing after answering the first one.
        let (dying, dyingPort) = try startServer(root: root, maxKeys: 3, dieAfterListings: 1)
        defer { dying.terminate() }

        setenv("PC_S3_ENDPOINT", "http://127.0.0.1:\(dyingPort)", 1)
        let fs = try makeFS()
        do {
            let partial = try await collect(fs, "/many")
            XCTFail("a directory cut off after \(partial.count) of 40 entries was reported as complete")
        } catch let error as VFSError {
            guard case .connectionLost = error else {
                return XCTFail("a server that died mid-listing was reported as \(error)")
            }
        }
    }

    // MARK: - Writing

    /// Open multipart uploads on `bucket`, asked through the real API (`GET /<bucket>?uploads`).
    /// Unsigned, which the fixture allows for reads — this is the test looking, not the plugin.
    private func openMultipartUploads(bucket: String, port: Int) throws -> Int {
        let url = URL(string: "http://127.0.0.1:\(port)/\(bucket)?uploads")!
        let done = DispatchSemaphore(value: 0)
        var text = ""
        URLSession.shared.dataTask(with: url) { data, _, _ in
            text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 10)
        return text.components(separatedBy: "<Upload>").count - 1
    }

    func test_theMountTakesWritesAndRenames() throws {
        let fs = try makeFS()
        XCTAssertTrue(fs.capabilities.contains(.write))
        XCTAssertTrue(fs.capabilities.contains(.rename))
        // The conformance the panel reads to decide that F5 into this drive is an upload rather than
        // a local copy against a remote path string. Asked through a `VirtualFileSystem`-typed value
        // because that is how the panel holds it — asking the concrete type is a question the
        // compiler answers, and the warning it emits for that is right: it proves nothing at runtime.
        let asPanelSeesIt: VirtualFileSystem = fs
        XCTAssertTrue(asPanelSeesIt is ResumableFileUploading)
    }

    func test_uploadingAnObject() async throws {
        let fs = try makeFS()
        let local = dir.appendingPathComponent("upload.txt")
        try Data("sent to s3".utf8).write(to: local)
        let result = try await fs.uploadFile(local, to: vpath("/photos/upload.txt"), resume: true)
        XCTAssertEqual(result.written, Int64("sent to s3".utf8.count))
        XCTAssertEqual(try Data(contentsOf: serving.appendingPathComponent("photos/upload.txt")),
                       Data("sent to s3".utf8))
    }

    func test_uploadingOverAnExistingObjectReplacesIt() async throws {
        let fs = try makeFS()
        let local = dir.appendingPathComponent("replacement.txt")
        try Data("second".utf8).write(to: local)
        _ = try await fs.uploadFile(local, to: vpath("/photos/readme.txt"), resume: false)
        XCTAssertEqual(try Data(contentsOf: serving.appendingPathComponent("photos/readme.txt")),
                       Data("second".utf8))
    }

    func test_uploadingAKeyWithASpaceAndAPlus() async throws {
        // The signing question again, in the other direction: a PUT signs its own payload hash and
        // its own canonical URI, and a key that encodes differently in the two is a 403.
        let fs = try makeFS()
        let local = dir.appendingPathComponent("weird.txt")
        try Data("weird".utf8).write(to: local)
        _ = try await fs.uploadFile(local, to: vpath("/photos/up +load.txt"), resume: false)
        XCTAssertEqual(try Data(contentsOf: serving.appendingPathComponent("photos/up +load.txt")),
                       Data("weird".utf8))
    }

    func test_aLargeObjectGoesUpInParts() async throws {
        // The multipart path, forced with a low threshold rather than a multi-gigabyte fixture:
        // otherwise this code would ship having never run.
        setenv("PC_S3_MULTIPART_THRESHOLD", "1024", 1)
        // And a part size, which is a separate knob for a reason: the 5 MiB floor S3 imposes means a
        // low threshold alone still sends a small file as a single part, so the test would exercise
        // the multipart code and prove nothing about assembling several parts.
        setenv("PC_S3_PART_SIZE", "4096", 1)
        defer { unsetenv("PC_S3_MULTIPART_THRESHOLD"); unsetenv("PC_S3_PART_SIZE") }
        let fs = try makeFS()
        let local = dir.appendingPathComponent("big.bin")
        // Distinguishable per byte, so a reassembly that ordered the parts wrongly does not pass.
        // 20 000 bytes at 4 KiB a part is five parts, the last one short.
        let payload = Data((0..<20_000).map { UInt8($0 % 251) })
        try payload.write(to: local)

        let result = try await fs.uploadFile(local, to: vpath("/photos/big.bin"), resume: false)
        XCTAssertEqual(result.written, Int64(payload.count))
        XCTAssertEqual(try Data(contentsOf: serving.appendingPathComponent("photos/big.bin")),
                       payload, "the parts were reassembled in the wrong order, or one was lost")
        XCTAssertEqual(try openMultipartUploads(bucket: "photos", port: port), 0,
                       "a completed upload left an open multipart behind")
        // Guards the guard: if the part size ever stops taking effect this is one part again, and the
        // assertions above would pass while testing a plain PUT.
        XCTAssertGreaterThan(payload.count / 4096, 1, "this no longer sends more than one part")
    }

    func test_aFailedMultipartUploadIsAborted() async throws {
        // The one that matters for the user's bill. Parts of an upload that was neither completed nor
        // aborted stay in the bucket, are charged for, and do not appear in any listing — so every
        // failure path has to abort, and "it probably does" is not good enough.
        let root = dir.appendingPathComponent("failing")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("photos"),
                                                withIntermediateDirectories: true)
        let (failing, failingPort) = try startServer(root: root, maxKeys: nil, failPart: 2)
        defer { failing.terminate() }
        setenv("PC_S3_ENDPOINT", "http://127.0.0.1:\(failingPort)", 1)
        setenv("PC_S3_MULTIPART_THRESHOLD", "1024", 1)
        setenv("PC_S3_PART_SIZE", "4096", 1)
        defer { unsetenv("PC_S3_MULTIPART_THRESHOLD"); unsetenv("PC_S3_PART_SIZE") }

        let fs = try makeFS()
        let local = dir.appendingPathComponent("doomed.bin")
        try Data(repeating: 0x41, count: 20_000).write(to: local)
        do {
            _ = try await fs.uploadFile(local, to: vpath("/photos/doomed.bin"), resume: false)
            XCTFail("an upload whose second part was refused reported success")
        } catch is VFSError {}

        XCTAssertEqual(try openMultipartUploads(bucket: "photos", port: failingPort), 0,
                       "the failed upload left parts behind that the user would be charged for")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("photos/doomed.bin").path),
            "a half-uploaded object was assembled anyway")
    }

    func test_creatingAFolderCreatesAPrefixMarker() async throws {
        let fs = try makeFS()
        try await fs.mkdir(vpath("/photos/reports"))
        let entries = try await collect(fs, "/photos")
        XCTAssertTrue(entries.contains { $0.name == "reports" && $0.kind == .directory })
        // The marker itself must not also show up as a file inside the new folder.
        let inside = try await collect(fs, "/photos/reports").map(\.name)
        XCTAssertEqual(inside, [])
    }

    func test_creatingAFolderAtTheRootCreatesABucket() async throws {
        // The root of the mount IS the bucket list, so there is nothing else "new folder" could mean
        // there — and refusing it would leave no way to make a bucket at all.
        let fs = try makeFS()
        try await fs.mkdir(vpath("/fresh-bucket"))
        let buckets = try await collect(fs, "/").map(\.name).sorted()
        XCTAssertEqual(buckets, ["backups", "fresh-bucket", "photos"])
    }

    func test_deletingAnObject() async throws {
        let fs = try makeFS()
        try await fs.delete(vpath("/photos/readme.txt"))
        let names = try await collect(fs, "/photos").map(\.name)
        XCTAssertFalse(names.contains("readme.txt"))
    }

    func test_deletingAFolderRemovesEverythingUnderIt() async throws {
        // The one a naive implementation gets wrong and reports as a success. A DELETE on the key
        // "photos/2006" answers 204 — there is no object by that name — so a plugin that treats a
        // folder as an object tells the user the folder is gone while every object in it stays.
        let fs = try makeFS()
        try await fs.delete(vpath("/photos/2006"))
        let names = try await collect(fs, "/photos").map(\.name)
        XCTAssertFalse(names.contains("2006"), "the folder is still listed")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: serving.appendingPathComponent("photos/2006/a.jpg").path),
            "the folder was reported deleted and its contents are still there")
    }

    func test_deletingAnEmptyBucket() async throws {
        let fs = try makeFS()
        try await fs.mkdir(vpath("/throwaway"))
        try await fs.delete(vpath("/throwaway"))
        let buckets = try await collect(fs, "/").map(\.name).sorted()
        XCTAssertEqual(buckets, ["backups", "photos"])
    }

    func test_deletingABucketWithObjectsInItFails() async throws {
        let fs = try makeFS()
        do {
            try await fs.delete(vpath("/photos"))
            XCTFail("deleted a bucket that still contains objects")
        } catch is VFSError {}
        let buckets = try await collect(fs, "/").map(\.name).sorted()
        XCTAssertEqual(buckets, ["backups", "photos"])
    }

    func test_renamingAnObject() async throws {
        let fs = try makeFS()
        try await fs.rename(vpath("/photos/readme.txt"), to: vpath("/photos/renamed.txt"))
        let names = try await collect(fs, "/photos").map(\.name).sorted()
        XCTAssertTrue(names.contains("renamed.txt"))
        XCTAssertFalse(names.contains("readme.txt"), "the original was left behind")
        XCTAssertEqual(try Data(contentsOf: serving.appendingPathComponent("photos/renamed.txt")),
                       Data("hello s3".utf8))
    }

    func test_renamingAnObjectIntoAnotherFolderIsAMove() async throws {
        let fs = try makeFS()
        try await fs.rename(vpath("/photos/readme.txt"), to: vpath("/photos/2006/readme.txt"))
        let names = try await collect(fs, "/photos/2006").map(\.name).sorted()
        XCTAssertEqual(names, ["a.jpg", "readme.txt"])
    }

    func test_renamingAcrossBuckets() async throws {
        // A drag from one bucket chip to another. The copy source names its own bucket, and assuming
        // one bucket would copy an object of the same name that happens to exist in the target.
        let fs = try makeFS()
        try await fs.rename(vpath("/photos/readme.txt"), to: vpath("/backups/readme.txt"))
        XCTAssertEqual(try Data(contentsOf: serving.appendingPathComponent("backups/readme.txt")),
                       Data("hello s3".utf8))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: serving.appendingPathComponent("photos/readme.txt").path))
    }

    func test_renamingAFolderMovesEveryKeyUnderIt() async throws {
        let fs = try makeFS()
        try await fs.rename(vpath("/photos/2006"), to: vpath("/photos/archive"))
        let top = try await collect(fs, "/photos").map(\.name).sorted()
        XCTAssertTrue(top.contains("archive"))
        XCTAssertFalse(top.contains("2006"), "the old folder is still listed")
        let inside = try await collect(fs, "/photos/archive").map(\.name)
        XCTAssertEqual(inside, ["a.jpg"])
        XCTAssertEqual(try Data(contentsOf: serving.appendingPathComponent("photos/archive/a.jpg")),
                       Data("nested".utf8))
    }

    func test_renamingABucketIsRefusedRatherThanFaked() async throws {
        // S3 cannot rename a bucket, and there is no sequence of calls that adds up to one: it would
        // mean copying every object and deleting the bucket, which is not what a rename dialog asked
        // for. Saying so beats doing it.
        let fs = try makeFS()
        do {
            try await fs.rename(vpath("/photos"), to: vpath("/pictures"))
            XCTFail("claimed to rename a bucket")
        } catch let e as VFSError {
            XCTAssertEqual(e, .unsupported)
        }
        let buckets = try await collect(fs, "/").map(\.name).sorted()
        XCTAssertEqual(buckets, ["backups", "photos"])
    }

    func test_aDirectoryLargerThanThreePagesArrivesWhole() async throws {
        // At the protocol's real page size, not a lowered one. 2 500 objects is three pages, and the
        // failure this catches is an off-by-one at a page boundary or a dropped last page — both of
        // which look like a complete directory that is quietly missing files, which is the worst
        // shape a file manager can fail in.
        let root = dir.appendingPathComponent("big")
        let bucket = root.appendingPathComponent("many")
        try FileManager.default.createDirectory(at: bucket, withIntermediateDirectories: true)
        let expected = (0..<2_500).map { String(format: "object-%04d.txt", $0) }
        for name in expected {
            try Data("x".utf8).write(to: bucket.appendingPathComponent(name))
        }
        let (big, bigPort) = try startServer(root: root, maxKeys: nil)
        defer { big.terminate() }
        setenv("PC_S3_ENDPOINT", "http://127.0.0.1:\(bigPort)", 1)

        let fs = try makeFS()
        let names = try await collect(fs, "/many").map(\.name).sorted()
        XCTAssertEqual(names.count, expected.count, "the listing lost objects across page boundaries")
        XCTAssertEqual(names, expected)
    }

    // MARK: - A server that goes away

    func test_aDeadServerIsReportedAsALostConnection_notAsAMissingDirectory() async throws {
        // `PfxFindFirst` can only answer NULL, and without `PfxLastError` the host reads that as "no
        // such directory" — so a server dying mid-listing tells the user their folder is gone and
        // leaves the panel inside a mount that can no longer answer anything.
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

    // MARK: - Retrying, and what must not be retried

    /// The fixture's request counters, keyed by method (plus "ALL").
    private func requestCounts(_ statsFile: URL) -> [String: Int] {
        guard let text = try? String(contentsOf: statsFile, encoding: .utf8) else { return [:] }
        var out: [String: Int] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2, let value = Int(parts[1]) { out[parts[0]] = value }
        }
        return out
    }

    func test_aThrottledListingIsRetried() async throws {
        // `SlowDown` is what S3 says when it wants fewer requests, and giving up on the first one
        // turns a busy moment into "this folder does not exist".
        let root = dir.appendingPathComponent("flaky")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("bucket"),
                                                withIntermediateDirectories: true)
        try Data("survived".utf8).write(to: root.appendingPathComponent("bucket/there.txt"))
        let stats = dir.appendingPathComponent("stats-get.txt")
        // Two 503s, then the truth. The plugin allows three attempts.
        let (flaky, flakyPort) = try startServer(root: root, maxKeys: nil, flaky: 2,
                                                flakyMethods: "GET", statsFile: stats)
        defer { flaky.terminate() }
        setenv("PC_S3_ENDPOINT", "http://127.0.0.1:\(flakyPort)", 1)

        let fs = try makeFS()
        let names = try await collect(fs, "/bucket").map(\.name)
        XCTAssertEqual(names, ["there.txt"], "the listing gave up on a transient failure")
        XCTAssertGreaterThanOrEqual(requestCounts(stats)["GET"] ?? 0, 3,
                                    "the listing succeeded without ever retrying")
    }

    func test_aThrottledListingThatNeverRecoversStopsRatherThanSpinning() async throws {
        // The other half: the retries are bounded. A sleep on the connection queue cannot be
        // cancelled — the ABI's only cancellation channel is the progress callback, which a listing
        // does not have — so an unbounded retry would be a frozen panel.
        let root = dir.appendingPathComponent("hopeless")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("bucket"),
                                                withIntermediateDirectories: true)
        let stats = dir.appendingPathComponent("stats-hopeless.txt")
        let (flaky, flakyPort) = try startServer(root: root, maxKeys: nil, flaky: 99,
                                                flakyMethods: "GET", statsFile: stats)
        defer { flaky.terminate() }
        setenv("PC_S3_ENDPOINT", "http://127.0.0.1:\(flakyPort)", 1)

        let fs = try makeFS()
        do {
            _ = try await collect(fs, "/bucket")
            XCTFail("a server that answered 503 to everything produced a listing")
        } catch is VFSError {}
        // Three attempts, not thirty.
        XCTAssertLessThanOrEqual(requestCounts(stats)["GET"] ?? 0, 4,
                                 "the retry loop is not bounded")
    }

    func test_startingAMultipartUploadIsNotRetried() async throws {
        // The one place a retry is a correctness bug rather than a delay. A retried
        // `POST ?uploads` starts a SECOND multipart upload and orphans the first — which the user
        // pays for and cannot see. So POST is never retried, and this counts to prove it.
        let root = dir.appendingPathComponent("nopost")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("bucket"),
                                                withIntermediateDirectories: true)
        let stats = dir.appendingPathComponent("stats-post.txt")
        let (flaky, flakyPort) = try startServer(root: root, maxKeys: nil, flaky: 99,
                                                flakyMethods: "POST", statsFile: stats)
        defer { flaky.terminate() }
        setenv("PC_S3_ENDPOINT", "http://127.0.0.1:\(flakyPort)", 1)
        setenv("PC_S3_MULTIPART_THRESHOLD", "1024", 1)
        setenv("PC_S3_PART_SIZE", "4096", 1)
        defer { unsetenv("PC_S3_MULTIPART_THRESHOLD"); unsetenv("PC_S3_PART_SIZE") }

        let fs = try makeFS()
        let local = dir.appendingPathComponent("multi.bin")
        try Data(repeating: 0x42, count: 20_000).write(to: local)
        do {
            _ = try await fs.uploadFile(local, to: vpath("/bucket/multi.bin"), resume: false)
            XCTFail("an upload whose CreateMultipartUpload was refused reported success")
        } catch is VFSError {}

        XCTAssertEqual(requestCounts(stats)["POST"], 1,
                       "CreateMultipartUpload was retried, which orphans the first upload")
    }

    func test_aThrottledBatchDeleteIsRetried() async throws {
        // The other side of the POST rule. `POST ?delete` is idempotent — deleting a key that is
        // already gone succeeds — and a recursive delete is a run of these, so refusing to retry left
        // a folder half deleted with no record of which half. Excluding POST by verb alone did
        // exactly that.
        let root = dir.appendingPathComponent("delflaky")
        let bucket = root.appendingPathComponent("bucket/folder")
        try FileManager.default.createDirectory(at: bucket, withIntermediateDirectories: true)
        for index in 0..<3 {
            try Data("x".utf8).write(to: bucket.appendingPathComponent("f\(index).txt"))
        }
        let stats = dir.appendingPathComponent("stats-del.txt")
        let (flaky, flakyPort) = try startServer(root: root, maxKeys: nil, flaky: 1,
                                                flakyMethods: "POST", statsFile: stats)
        defer { flaky.terminate() }
        setenv("PC_S3_ENDPOINT", "http://127.0.0.1:\(flakyPort)", 1)

        let fs = try makeFS()
        try await fs.delete(vpath("/bucket/folder"))
        let names = try await collect(fs, "/bucket").map(\.name)
        XCTAssertFalse(names.contains("folder"), "the folder survived a throttled batch delete")
        XCTAssertGreaterThanOrEqual(requestCounts(stats)["POST"] ?? 0, 2,
                                    "the batch delete was not retried")
    }

    // MARK: - Regions and anonymous access

    func test_aBucketInAnotherRegionIsFollowedRatherThanFailing() async throws {
        // Buckets do not have to be in the connection's region, and AWS answers a request signed for
        // the wrong one with a 400 whose code says so and whose body names the right region. Without
        // following that, every access to such a bucket fails with a message that explains nothing —
        // and the user has no way to discover which region to enter.
        let root = dir.appendingPathComponent("elsewhere")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("frankfurt"),
                                                withIntermediateDirectories: true)
        try Data("guten tag".utf8).write(to: root.appendingPathComponent("frankfurt/hallo.txt"))
        // The server only accepts signatures for eu-central-1 …
        let (remote, remotePort) = try startServer(root: root, maxKeys: nil, region: "eu-central-1")
        defer { remote.terminate() }
        // … and the plugin is configured for us-east-1, which is the situation being tested.
        setenv("PC_S3_ENDPOINT", "http://127.0.0.1:\(remotePort)", 1)
        setenv("PC_S3_REGION", "us-east-1", 1)

        let fs = try makeFS()
        let names = try await collect(fs, "/frankfurt").map(\.name)
        XCTAssertEqual(names, ["hallo.txt"], "the region redirect was not followed")

        // And the answer is remembered: reading the object afterwards goes through a different code
        // path (the transfer session, which builds its own requests), so this also checks that the
        // learned region reaches it.
        let downloaded = try await fs.localFileIfAvailable(vpath("/frankfurt/hallo.txt"))
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(downloaded)), Data("guten tag".utf8))
    }

    func test_aRegionRedirectIsFollowedForATransferThatHasNotListedFirst() async throws {
        // The transfer paths sign their own requests and cannot use `send`'s retry, so they carry
        // their own. Reached directly here — without a listing to warm the cache — because in normal
        // use a listing comes first and would hide a missing retry on this path.
        let root = dir.appendingPathComponent("cold")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("bucket"),
                                                withIntermediateDirectories: true)
        try Data("cold start".utf8).write(to: root.appendingPathComponent("bucket/only.txt"))
        let (remote, remotePort) = try startServer(root: root, maxKeys: nil, region: "ap-south-1")
        defer { remote.terminate() }
        setenv("PC_S3_ENDPOINT", "http://127.0.0.1:\(remotePort)", 1)
        setenv("PC_S3_REGION", "us-east-1", 1)

        let fs = try makeFS()
        let downloaded = try await fs.localFileIfAvailable(vpath("/bucket/only.txt"))
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(downloaded)), Data("cold start".utf8))
    }

    func test_connectingAnonymouslyReadsAPublicBucket() async throws {
        // No credentials means no signature at all, not a signature made with an empty key. The
        // fixture allows unsigned reads, which is what a public bucket is.
        setenv("PC_S3_ACCESS_KEY", "", 1)
        setenv("PC_S3_SECRET_KEY", "", 1)
        let fs = try makeFS()
        let names = try await collect(fs, "/photos").map(\.name).sorted()
        XCTAssertEqual(names, ["2006", "2007", "odd +name.txt", "readme.txt"])
    }

    func test_anAnonymousConnectionCannotWrite() async throws {
        // The fixture refuses unsigned writes, as the real service does for a bucket that is readable
        // but not writable — the common shape of a public bucket. It must be an error rather than a
        // silent no-op.
        setenv("PC_S3_ACCESS_KEY", "", 1)
        setenv("PC_S3_SECRET_KEY", "", 1)
        let fs = try makeFS()
        let local = dir.appendingPathComponent("nope.txt")
        try Data("nope".utf8).write(to: local)
        do {
            _ = try await fs.uploadFile(local, to: vpath("/photos/nope.txt"), resume: false)
            XCTFail("an anonymous connection uploaded an object")
        } catch is VFSError {}
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: serving.appendingPathComponent("photos/nope.txt").path))
    }

    // MARK: - Credentials and the config root

    func test_aWrongSecretFailsRatherThanListingSomething() throws {
        // Proves the fixture is checking signatures at all. Without this the whole file could be
        // passing against a server that ignores the Authorization header, and the signer would be
        // untested by every test above.
        setenv("PC_S3_SECRET_KEY", "not-the-secret", 1)
        let fs = try makeFS()
        let listed = XCTestExpectation(description: "listing finished")
        var failed = false
        Task {
            do { _ = try await self.collect(fs, "/") }
            catch { failed = true }
            listed.fulfill()
        }
        wait(for: [listed], timeout: 20)
        XCTAssertTrue(failed, "a wrong secret listed the bucket — the fixture is not checking signatures")
    }

    private var profilesFile: URL {
        dir.appendingPathComponent("config/s3/profiles.json")
    }

    func test_anEnvironmentConnectionIsNotSavedAsAProfile() throws {
        // The environment path is for tests and for someone who already exported credentials. It is
        // not the user asking for the connection to be kept, and a run that left a throwaway
        // localhost profile behind would put a dead drive chip in their drive bar.
        _ = try makeFS()
        XCTAssertFalse(FileManager.default.fileExists(atPath: profilesFile.path))
    }

    func test_theProfileListIsNotWrittenAnywhereElse() throws {
        // The half that actually protects the user: proving nothing appeared in the test's directory
        // says nothing about whether something appeared in the real one.
        let real = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PeachCommander/s3/profiles.json")
        let before = try? Data(contentsOf: real)
        _ = try makeFS()
        let after = try? Data(contentsOf: real)
        XCTAssertEqual(before, after, "connecting touched the real profile list")
    }

    func test_aHostThatAnswersNothingLeavesThePluginWorking() throws {
        // `getContext` is NULL on an older host and answers 0 for keys it does not know. Neither may
        // be fatal — an unanswered key means "use your default", not "give up".
        var s = PfxHostServices()
        s.getContext = { _, _, _, _ in 0 }
        PFXPlugin(library: lib).initialize(services: s)
        var bare = PfxHostServices()
        bare.getContext = nil
        PFXPlugin(library: lib).initialize(services: bare)
        let fs = try makeFS()
        XCTAssertEqual(fs.scheme, "s3:127.0.0.1:\(port)")
    }

    // MARK: - Content columns

    func test_thePluginPublishesTheColumnsItsListingsAlreadyKnow() throws {
        let plugin = PFXPlugin(library: lib)
        let fields = plugin.contentFields()
        XCTAssertEqual(fields.map(\.name), ["storageclass", "etag"])
        XCTAssertEqual(fields.map(\.title), ["Storage Class", "ETag"])
        // Both are strings: an ETag is a hash that only wants comparing, and sorting either
        // numerically would order them by nothing.
        XCTAssertTrue(fields.allSatisfy { !$0.isNumericSort })
        XCTAssertTrue(fields.allSatisfy { !$0.isRightAligned })
    }

    func test_aColumnValueComesFromTheListingRatherThanAnExtraRequest() async throws {
        // The whole design decision. Storage class and ETag arrive in every ListObjectsV2 answer, so
        // asking the server per row would turn one request into one per visible file — on a service
        // that charges per request, from the main thread, while the panel draws.
        let stats = dir.appendingPathComponent("stats-columns.txt")
        let (counted, countedPort) = try startServer(root: serving, maxKeys: nil, statsFile: stats)
        defer { counted.terminate() }
        setenv("PC_S3_ENDPOINT", "http://127.0.0.1:\(countedPort)", 1)

        let fs = try makeFS()
        _ = try await collect(fs, "/photos")
        let afterListing = requestCounts(stats)["GET"] ?? 0

        let storage = fs.contentDisplay(fieldID: "\(fs.scheme).storageclass",
                                        path: "/photos/readme.txt")
        XCTAssertEqual(storage, "STANDARD")
        let etag = fs.contentDisplay(fieldID: "\(fs.scheme).etag", path: "/photos/readme.txt")
        XCTAssertEqual(etag, "fixture-8", "the ETag did not survive the listing")

        XCTAssertEqual(requestCounts(stats)["GET"] ?? 0, afterListing,
                       "reading two columns cost a request")
    }

    func test_aColumnForSomethingNoListingSawIsEmptyRatherThanFetched() async throws {
        // A bucket, a prefix, or a row from a directory navigated away from two moves ago. An empty
        // cell is the honest answer; going to the server for it is the cost this design exists to
        // avoid, and doing it from the drawing path is worse than the cost.
        let fs = try makeFS()
        _ = try await collect(fs, "/photos")
        XCTAssertNil(fs.contentDisplay(fieldID: "\(fs.scheme).storageclass", path: "/photos"))
        XCTAssertNil(fs.contentDisplay(fieldID: "\(fs.scheme).etag", path: "/photos/2006"))
        XCTAssertNil(fs.contentDisplay(fieldID: "\(fs.scheme).etag", path: "/backups/top.bin"))
    }

    func test_columnsSurviveTwoPanelsOnOneMount() async throws {
        // Both panels share one `PFXFileSystem`, and the plugin keeps the values from the LAST TWO
        // directories for exactly this reason: with one, the second panel's listing would empty the
        // first panel's columns while it was still drawing them.
        let fs = try makeFS()
        _ = try await collect(fs, "/photos")
        _ = try await collect(fs, "/backups")
        fs.invalidateContentCache()   // the host clears its own cache per listing; the plugin's stands
        XCTAssertEqual(fs.contentDisplay(fieldID: "\(fs.scheme).storageclass",
                                         path: "/backups/top.bin"), "STANDARD")
        XCTAssertEqual(fs.contentDisplay(fieldID: "\(fs.scheme).storageclass",
                                         path: "/photos/readme.txt"), "STANDARD",
                       "the second listing threw away the first one's columns")
    }

    // MARK: - Connecting the chip the user clicked

    /// Write a profile into the config root the plugin was told about, as the connect dialog would.
    private func saveProfile(name: String, anonymous: Bool, accessKeyID: String = "") throws {
        let dir = self.dir.appendingPathComponent("config/s3", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let json = """
        [{"accessKeyID":"\(accessKeyID)","anonymous":\(anonymous),        "host":"127.0.0.1:\(port)","name":"\(name)","pathStyle":true,        "region":"us-east-1","useTLS":false}]
        """
        try Data(json.utf8).write(to: dir.appendingPathComponent("profiles.json"))
    }

    private typealias ConnectVolumeFn =
        @convention(c) (UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?

    /// Call `PfxConnectVolume` the way the host does when a drive chip is clicked.
    private func connectVolume(_ volumeID: String) throws -> UnsafeMutableRawPointer? {
        let symbol = try XCTUnwrap(lib.symbol("PfxConnectVolume"),
                                   "the plugin does not export PfxConnectVolume")
        let f = unsafeBitCast(symbol, to: ConnectVolumeFn.self)
        return volumeID.withCString { f($0, nil) }
    }

    func test_aSavedProfileBecomesAChipThatConnectsWithoutAsking() async throws {
        // The defect this entry point exists for. `PfxConnect` takes no argument, so a plugin
        // publishing a chip per saved connection could only fall back to its dialog — the chip
        // promised a shortcut and delivered a form, and in the VM harness it hung on a modal nothing
        // could answer.
        try saveProfile(name: "Fixture", anonymous: true)

        let plugin = PFXPlugin(library: lib)
        let volumes = plugin.volumes()
        XCTAssertEqual(volumes.map(\.name), ["Fixture"], "the saved profile produced no drive chip")
        XCTAssertFalse(volumes[0].isLocal, "a saved connection is not a local path")
        XCTAssertTrue(plugin.connectsVolumesDirectly,
                      "the host would fall back to the dialog for this plugin")

        let conn = try XCTUnwrap(try connectVolume(volumes[0].id),
                                 "clicking the chip did not connect")
        let fs = PFXFileSystem(plugin: plugin, conn: conn, fsID: plugin.connectionId(conn),
                               capabilities: plugin.capabilities, retaining: nil)
        // And it really is connected: the bucket list is the root of the mount.
        let names = try await collect(fs, "/").map(\.name).sorted()
        XCTAssertEqual(names, ["backups", "photos"])
        await fs.disconnect()
    }

    func test_aChipFromAConfigurationThatHasChangedFailsRatherThanConnectingSomethingElse() throws {
        // A volume id left over from a profile that has since been renamed or removed. Answering with
        // *a* connection would mount whatever happened to be first, under the name of a drive the user
        // no longer has; NULL is what tells the host the mount did not happen so it drops the chip.
        try saveProfile(name: "Fixture", anonymous: true)
        XCTAssertNil(try connectVolume("s3:Gone"))
        XCTAssertNil(try connectVolume(""))
    }

    func test_aProfileWhoseSecretIsGoneDoesNotSilentlyConnectAnonymously() throws {
        // The dangerous shape. A profile that needs a key, whose Keychain entry has been removed,
        // must not quietly become an anonymous connection — that would list whatever is public and
        // look like success, while the private bucket the user asked for was never reached. No `crypt`
        // callback is provided here, which is exactly the "the Keychain has nothing" case.
        try saveProfile(name: "Private", anonymous: false, accessKeyID: Self.accessKey)
        XCTAssertNil(try connectVolume("s3:Private"))
    }

    // MARK: - Volumes

    func test_withNothingSavedThereAreNoChipsButStillAWayIn() throws {
        // The empty case, which is what catches a plugin that advertises a volume with no name. The
        // connect facet must still be offered, or there is no way to make a first profile at all.
        let plugin = PFXPlugin(library: lib)
        XCTAssertEqual(plugin.volumes().count, 0)
        XCTAssertEqual(plugin.connectTitle(), "Amazon S3 Connect…")
    }

    func test_thePluginFreesItsConnection() async throws {
        let fs = try makeFS()
        let listed = try await collect(fs, "/")
        XCTAssertFalse(listed.isEmpty)
        await fs.disconnect()
        do {
            _ = try await collect(fs, "/")
            XCTFail("listed a disconnected mount")
        } catch let e as VFSError {
            XCTAssertEqual(e, .connectionLost(retryable: false))
        }
        await fs.disconnect()   // must not free the connection a second time
    }
}
