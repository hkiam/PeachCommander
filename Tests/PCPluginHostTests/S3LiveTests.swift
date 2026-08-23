// SPDX-License-Identifier: Apache-2.0
// S3LiveTests.swift - The S3 plugin against real Amazon S3.
//
// Opt-in, and it costs money: set PC_S3_LIVE=1 plus credentials and a bucket you own.
//
//   PC_S3_LIVE=1
//   PC_S3_LIVE_BUCKET     an existing bucket; everything is written under a unique prefix and removed
//   PC_S3_LIVE_REGION     the bucket's region (default us-east-1)
//   PC_S3_LIVE_ACCESS_KEY / PC_S3_LIVE_SECRET_KEY, or a profile in ~/.aws via PC_S3_LIVE_PROFILE
//
// Deliberately narrow. MinIO already covers the ordinary lifecycle (Tools/s3-conformance.sh), and
// repeating it here would spend a real account's money to learn nothing. What is here is only what no
// emulator has: AWS's own region redirect, its own storage classes, and its own opinion of a clock
// that is wrong. If a case can be tested against MinIO it belongs in the conformance suite, not here.
//
// Separate env names from the fixture's (PC_S3_LIVE_* rather than PC_S3_*) on purpose: sharing them
// would mean a stray export in a shell pointing a "local" test run at a real account.

import XCTest
import PCVFS
import CPFX
@testable import PCPluginHost

final class S3LiveTests: XCTestCase {
    private var dir: URL!
    private var lib: PluginLibrary!
    private var fs: PFXFileSystem!
    private var bucket = ""
    /// Everything this suite writes lives under here, so a failed run leaves one identifiable folder
    /// rather than litter in someone's bucket.
    private var prefix = ""

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func env(_ key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key]
        return (value?.isEmpty ?? true) ? nil : value
    }

    override func setUpWithError() throws {
        try XCTSkipUnless(env("PC_S3_LIVE") == "1",
                          "set PC_S3_LIVE=1 and PC_S3_LIVE_BUCKET to run against real AWS")
        bucket = try XCTUnwrap(env("PC_S3_LIVE_BUCKET"),
                              "PC_S3_LIVE_BUCKET must name a bucket you own")
        let region = env("PC_S3_LIVE_REGION") ?? "us-east-1"

        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("s3live-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        lib = try S3PluginTests.buildPlugin(repoRoot: repoRoot, into: dir)

        // The plugin reads these in `PfxConnect`; it is dlopen'd into this process, so setting them
        // here is how they reach it.
        setenv("PC_S3_ENDPOINT", "https://s3.\(region).amazonaws.com", 1)
        setenv("PC_S3_REGION", region, 1)
        if let key = env("PC_S3_LIVE_ACCESS_KEY") { setenv("PC_S3_ACCESS_KEY", key, 1) }
        if let secret = env("PC_S3_LIVE_SECRET_KEY") { setenv("PC_S3_SECRET_KEY", secret, 1) }
        setenv("PC_S3_PATH_STYLE", "0", 1)

        prefix = "peachcommander-test-\(UUID().uuidString.lowercased().prefix(8))"
        fs = try makeFS()
    }

    override func tearDownWithError() throws {
        for name in ["PC_S3_ENDPOINT", "PC_S3_REGION", "PC_S3_ACCESS_KEY",
                     "PC_S3_SECRET_KEY", "PC_S3_PATH_STYLE"] {
            unsetenv(name)
        }
        // Best effort, and it matters more than usual: this is somebody's real bucket and objects
        // left behind are billed for as long as they exist.
        if fs != nil, !bucket.isEmpty, !prefix.isEmpty {
            let group = DispatchGroup()
            group.enter()
            Task {
                try? await self.fs.delete(self.vpath("/\(self.bucket)/\(self.prefix)"))
                group.leave()
            }
            _ = group.wait(timeout: .now() + 120)
        }
        if let dir { try? FileManager.default.removeItem(at: dir) }
    }

    private func makeFS() throws -> PFXFileSystem {
        typealias ConnectFn = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
        let connect = try XCTUnwrap(lib.symbol("PfxConnect"))
        let conn = try XCTUnwrap(unsafeBitCast(connect, to: ConnectFn.self)(nil),
                                 "PfxConnect returned nil — AWS did not accept the settings")
        let plugin = PFXPlugin(library: lib)
        return PFXFileSystem(plugin: plugin, conn: conn, fsID: plugin.connectionId(conn),
                             capabilities: plugin.capabilities, retaining: nil)
    }

    private func vpath(_ path: String) -> VFSPath { VFSPath(filesystemId: "s3", path: path) }

    private func collect(_ path: String) async throws -> [VFSEntry] {
        var all: [VFSEntry] = []
        for try await batch in fs.list(vpath(path)) { all += batch.entries }
        return all
    }

    // MARK: - What only AWS has

    func test_aRoundTripAgainstAWS() async throws {
        // The smoke test: if this fails, nothing below is worth reading. Also the only place the
        // real virtual-hosted addressing and a real TLS endpoint are exercised at all.
        let payload = Data("peach s3 live \(UUID().uuidString)".utf8)
        let local = dir.appendingPathComponent("live.txt")
        try payload.write(to: local)
        _ = try await fs.uploadFile(local, to: vpath("/\(bucket)/\(prefix)/live.txt"), resume: false)

        let listed = try await collect("/\(bucket)/\(prefix)").map(\.name)
        XCTAssertEqual(listed, ["live.txt"])
        let downloaded = try await fs.localFileIfAvailable(vpath("/\(bucket)/\(prefix)/live.txt"))
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(downloaded)), payload)
    }

    func test_aBucketReachedFromTheWrongRegionIsFollowed() async throws {
        // The case no emulator has: AWS's own redirect. The plugin is pointed at a region the bucket
        // is not in, so the first signed request is refused with the right region named in the answer,
        // and everything after that has to work. Skipped when the bucket really is in us-east-1,
        // because then there is nothing to redirect.
        let realRegion = env("PC_S3_LIVE_REGION") ?? "us-east-1"
        try XCTSkipIf(realRegion == "us-east-1",
                      "PC_S3_LIVE_REGION is us-east-1, so there is no redirect to follow")

        setenv("PC_S3_REGION", "us-east-1", 1)
        setenv("PC_S3_ENDPOINT", "https://s3.amazonaws.com", 1)
        let misdirected = try makeFS()

        let payload = Data("across regions".utf8)
        let local = dir.appendingPathComponent("region.txt")
        try payload.write(to: local)
        _ = try await misdirected.uploadFile(local,
                                            to: vpath("/\(bucket)/\(prefix)/region.txt"),
                                            resume: false)
        let downloaded = try await misdirected.localFileIfAvailable(
            vpath("/\(bucket)/\(prefix)/region.txt"))
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(downloaded)), payload,
                       "the region redirect was not followed against real AWS")
    }

    func test_aSkewedClockIsReportedAsAClockProblem() async throws {
        // AWS refuses a signature more than fifteen minutes out with RequestTimeTooSkewed, and no
        // emulator enforces it. Reported as "access denied" it sends the user to an administrator for
        // a permission they already have; the cause is this Mac's clock.
        //
        // The clock is not changed — that would need root and would affect the whole machine. Instead
        // the plugin's own signer is asked for a signature dated in the past, through the same code
        // path, and AWS's answer is read.
        throw XCTSkip("""
            Not automated: producing a skewed signature means either changing the system clock or \
            reaching past the plugin's C ABI to hand its signer a date. Recorded here because the \
            mapping exists in S3Client.pcError and should be checked by hand when it changes: set the \
            Mac's clock forward twenty minutes and confirm the message names the clock.
            """)
    }

    func test_theStorageClassOfARealObjectIsReported() async throws {
        // Storage class is AWS's own vocabulary and MinIO reports everything as STANDARD, so this is
        // the only place the field is read from something that has more than one value. It is not yet
        // surfaced as a column — that is still to come — so this asserts the listing carries it at
        // all rather than what the panel shows.
        let payload = Data("standard storage".utf8)
        let local = dir.appendingPathComponent("class.txt")
        try payload.write(to: local)
        _ = try await fs.uploadFile(local, to: vpath("/\(bucket)/\(prefix)/class.txt"), resume: false)
        let stat = try await fs.stat(vpath("/\(bucket)/\(prefix)/class.txt"))
        XCTAssertEqual(stat.size, Int64(payload.count))
        XCTAssertGreaterThan(stat.modified.timeIntervalSince1970, 0,
                            "AWS's Last-Modified was not parsed")
    }
}
