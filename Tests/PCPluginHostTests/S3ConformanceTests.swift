// SPDX-License-Identifier: Apache-2.0
// S3ConformanceTests.swift - The S3 plugin against a real MinIO server, in Docker.
//
// Run by Tools/s3-conformance.sh, which starts the container and sets the environment. Skipped
// entirely unless PC_S3_DOCKER=1, and NOT run in CI: ci.yml is on macos-26 GitHub runners, which have
// no Docker. That is deliberate.
//
// What this adds over Fixtures/s3server.py: the fixture verifies SigV4 by recomputing it the way the
// plugin computes it, so a shared misunderstanding of the spec would pass on both sides. MinIO is an
// independent implementation with its own signature check, its own multipart assembly and its own
// error codes — and it ENFORCES the 5 MiB minimum part size, which the fixture does not. The
// multipart test below therefore uses real part sizes, and is the only place the production defaults
// are exercised at all.

import XCTest
import PCVFS
import CPFX
@testable import PCPluginHost

final class S3ConformanceTests: XCTestCase {
    private var dir: URL!
    private var lib: PluginLibrary!
    private var bucket = ""
    private var fs: PFXFileSystem!

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Settings written by Tools/s3-conformance.sh, applied to this process.
    ///
    /// Read from a file rather than inherited from the environment because this is a host-less
    /// unit-test bundle: a plain `export` from the script does not reach it, and neither does
    /// xcodebuild's `TEST_RUNNER_` prefix. Both were tried, and the result was eight silently skipped
    /// tests under a green script.
    ///
    /// `setenv` on this process rather than passing values around, because the *plugin* is what reads
    /// them — it is dlopen'd in-process and looks at `ProcessInfo` in `PfxConnect`.
    @discardableResult
    private static func applySettings(repoRoot: URL) -> Bool {
        let file = repoRoot.appendingPathComponent("build/s3-conformance.env")
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return false }
        var sawMarker = false
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            setenv(parts[0], parts[1], 1)
            if parts[0] == "PC_S3_DOCKER", parts[1] == "1" { sawMarker = true }
        }
        return sawMarker
    }

    override func setUpWithError() throws {
        try XCTSkipUnless(Self.applySettings(repoRoot: repoRoot),
                          "not a Docker run — start it with Tools/s3-conformance.sh")

        try XCTSkipUnless(ProcessInfo.processInfo.environment["PC_S3_ENDPOINT"] != nil,
                          "PC_S3_ENDPOINT is not in build/s3-conformance.env")

        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("s3conf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        lib = try S3PluginTests.buildPlugin(repoRoot: repoRoot, into: dir)

        // A bucket per test, named the way S3 requires: lower case, DNS-safe, no underscores. Sharing
        // one across tests would make them order-dependent against a server that really persists.
        bucket = "pc-conf-" + UUID().uuidString.lowercased().prefix(12)
        fs = try makeFS()
        try await_mkdir("/\(bucket)")
    }

    override func tearDownWithError() throws {
        // Best effort: leaving buckets behind in a container that is about to be destroyed is
        // harmless, but PC_S3_KEEP=1 leaves the container running and then it is not.
        if fs != nil, !bucket.isEmpty {
            let group = DispatchGroup()
            group.enter()
            Task {
                try? await self.fs.delete(self.vpath("/\(self.bucket)/"))
                try? await self.fs.delete(self.vpath("/\(self.bucket)"))
                group.leave()
            }
            _ = group.wait(timeout: .now() + 60)
        }
        if let dir { try? FileManager.default.removeItem(at: dir) }
    }

    // MARK: - Plumbing

    private func makeFS() throws -> PFXFileSystem {
        typealias ConnectFn = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
        let connect = try XCTUnwrap(lib.symbol("PfxConnect"))
        let conn = try XCTUnwrap(unsafeBitCast(connect, to: ConnectFn.self)(nil),
                                 "PfxConnect returned nil — MinIO did not accept the endpoint")
        let plugin = PFXPlugin(library: lib)
        return PFXFileSystem(plugin: plugin, conn: conn, fsID: plugin.connectionId(conn),
                             capabilities: plugin.capabilities, retaining: nil)
    }

    private func vpath(_ path: String) -> VFSPath { VFSPath(filesystemId: "s3", path: path) }

    /// `setUpWithError` cannot be async, and the bucket has to exist before any test runs.
    private func await_mkdir(_ path: String) throws {
        let group = DispatchGroup()
        group.enter()
        var failure: Error?
        Task {
            do { try await self.fs.mkdir(self.vpath(path)) } catch { failure = error }
            group.leave()
        }
        guard group.wait(timeout: .now() + 60) == .success else {
            throw XCTSkip("MinIO did not answer in time")
        }
        if let failure { throw failure }
    }

    private func collect(_ path: String) async throws -> [VFSEntry] {
        var all: [VFSEntry] = []
        for try await batch in fs.list(vpath(path)) { all += batch.entries }
        return all
    }

    private func upload(_ bytes: Data, to key: String) async throws {
        let local = dir.appendingPathComponent("upload-\(UUID().uuidString)")
        try bytes.write(to: local)
        _ = try await fs.uploadFile(local, to: vpath("/\(bucket)/\(key)"), resume: false)
        try? FileManager.default.removeItem(at: local)
    }

    // MARK: - Tests

    func test_theBucketWeCreatedIsListed() async throws {
        let names = try await collect("/").map(\.name)
        XCTAssertTrue(names.contains(bucket), "CreateBucket succeeded but ListBuckets does not show it")
    }

    func test_aRoundTripThroughMinIO() async throws {
        let payload = Data("hello from a real server".utf8)
        try await upload(payload, to: "greeting.txt")
        let downloaded = try await fs.localFileIfAvailable(vpath("/\(bucket)/greeting.txt"))
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(downloaded)), payload)
    }

    func test_aKeyWithAwkwardCharactersSurvivesAnIndependentSignatureCheck() async throws {
        // The single most valuable assertion in this file. The fixture checks signatures by
        // recomputing them the way the plugin does; MinIO checks them its own way. A key with a
        // space, a "+", a "=" and a "~" exercises every rule where the two could have agreed on the
        // same mistake — "~" in particular is unreserved and must NOT be encoded, which several
        // percent-encoders get wrong.
        let key = "odd +name=v~1.txt"
        let payload = Data("awkward".utf8)
        try await upload(payload, to: key)
        let downloaded = try await fs.localFileIfAvailable(vpath("/\(bucket)/\(key)"))
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(downloaded)), payload)
        let listed = try await collect("/\(bucket)").map(\.name)
        XCTAssertTrue(listed.contains(key))
    }

    func test_aMultipartUploadAtRealPartSizes() async throws {
        // MinIO enforces S3's 5 MiB minimum part size; the Python fixture does not. So this is the
        // only test anywhere that exercises the production defaults — 12 MiB at the default part size
        // is three parts, and a part below the minimum would be rejected outright.
        setenv("PC_S3_MULTIPART_THRESHOLD", String(8 * 1024 * 1024), 1)
        defer { unsetenv("PC_S3_MULTIPART_THRESHOLD") }
        // Rebuilt so the connection picks the threshold up.
        fs = try makeFS()

        // Distinguishable per byte, so parts assembled out of order do not pass.
        var payload = Data(capacity: 12 * 1024 * 1024)
        for index in 0..<(12 * 1024 * 1024) { payload.append(UInt8(index % 251)) }
        try await upload(payload, to: "big.bin")

        let stat = try await fs.stat(vpath("/\(bucket)/big.bin"))
        XCTAssertEqual(stat.size, Int64(payload.count))
        let downloaded = try await fs.localFileIfAvailable(vpath("/\(bucket)/big.bin"))
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(downloaded)), payload,
                       "the parts were assembled in the wrong order, or one was lost")
    }

    func test_foldersPrefixesAndRecursiveDelete() async throws {
        try await fs.mkdir(vpath("/\(bucket)/reports"))
        try await upload(Data("q1".utf8), to: "reports/q1.txt")
        try await upload(Data("q2".utf8), to: "reports/q2.txt")

        let top = try await collect("/\(bucket)")
        XCTAssertTrue(top.contains { $0.name == "reports" && $0.kind == .directory })
        let inside = try await collect("/\(bucket)/reports").map(\.name).sorted()
        XCTAssertEqual(inside, ["q1.txt", "q2.txt"])

        try await fs.delete(vpath("/\(bucket)/reports"))
        let after = try await collect("/\(bucket)").map(\.name)
        XCTAssertFalse(after.contains("reports"), "the folder is still listed after a delete")
    }

    func test_aServerSideRenameMovesTheObject() async throws {
        try await upload(Data("before".utf8), to: "before.txt")
        try await fs.rename(vpath("/\(bucket)/before.txt"), to: vpath("/\(bucket)/after.txt"))
        let names = try await collect("/\(bucket)").map(\.name)
        XCTAssertTrue(names.contains("after.txt"))
        XCTAssertFalse(names.contains("before.txt"), "the original was left behind")
        let downloaded = try await fs.localFileIfAvailable(vpath("/\(bucket)/after.txt"))
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(downloaded)), Data("before".utf8))
    }

    func test_realErrorCodesForThingsThatAreNotThere() async throws {
        do {
            _ = try await collect("/\(bucket)/no-such-prefix")
            XCTFail("listed a prefix MinIO does not have")
        } catch let e as VFSError {
            if case .notFound = e {} else { XCTFail("MinIO's answer mapped to \(e)") }
        }
        do {
            _ = try await fs.localFileIfAvailable(vpath("/\(bucket)/ghost.txt"))
            XCTFail("read an object MinIO does not have")
        } catch let e as VFSError {
            if case .notFound = e {} else { XCTFail("MinIO's answer mapped to \(e)") }
        }
    }

    func test_aNonEmptyBucketIsNotDeleted() async throws {
        try await upload(Data("keeps the bucket alive".utf8), to: "resident.txt")
        do {
            try await fs.delete(vpath("/\(bucket)"))
            XCTFail("deleted a bucket that still holds an object")
        } catch is VFSError {}
        let buckets = try await collect("/").map(\.name)
        XCTAssertTrue(buckets.contains(bucket))
    }
}
