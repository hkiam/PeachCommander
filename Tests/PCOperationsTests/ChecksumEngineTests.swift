// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCOperations
import PCFoundation
import PCVFS

final class ChecksumEngineTests: XCTestCase {
    private var dir: URL!
    private let fs = LocalFS()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-checksum-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func write(_ name: String, _ content: String) throws -> String {
        let url = dir.appendingPathComponent(name)
        try content.data(using: .utf8)!.write(to: url)
        return url.path
    }

    private func vpath(_ path: String) -> VFSPath { VFSPath(filesystemId: "file", path: path) }
    private var baseDir: VFSPath { vpath(dir.path) }

    func testComputeMatchesAlgorithm() async throws {
        let content = "The quick brown fox jumps over the lazy dog"
        let path = try write("fox.txt", content)
        let digest = try await ChecksumEngine.compute(vpath(path), on: fs, algorithm: .sha256)
        XCTAssertEqual(digest, ChecksumAlgorithm.sha256.hex(of: Data(content.utf8)))
    }

    // Underpins verify-after-copy (F-090): a good copy has an equal CRC-32,
    // a corrupted one differs.
    func testCrc32VerifiesGoodCopyAndCatchesCorruption() async throws {
        let source = try write("src.bin", "verify-after-copy payload 12345")
        let goodCopy = try write("good.bin", "verify-after-copy payload 12345")
        let badCopy = try write("bad.bin", "verify-after-copy payload 1234X")
        let src = try await ChecksumEngine.compute(vpath(source), on: fs, algorithm: .crc32)
        let good = try await ChecksumEngine.compute(vpath(goodCopy), on: fs, algorithm: .crc32)
        let bad = try await ChecksumEngine.compute(vpath(badCopy), on: fs, algorithm: .crc32)
        XCTAssertEqual(src, good)
        XCTAssertNotEqual(src, bad)
    }

    func testComputeStreamsLargeFile() async throws {
        // Bigger than one read chunk to exercise incremental hashing.
        let bytes = Data((0..<300_000).map { UInt8($0 & 0xFF) })
        let url = dir.appendingPathComponent("big.bin")
        try bytes.write(to: url)
        let digest = try await ChecksumEngine.compute(vpath(url.path), on: fs, algorithm: .md5)
        XCTAssertEqual(digest, ChecksumAlgorithm.md5.hex(of: bytes))
    }

    func testCreateThenVerifyOK() async throws {
        _ = try write("a.txt", "alpha")
        _ = try write("b.txt", "beta")
        let entries = await ChecksumEngine.create(filenames: ["a.txt", "b.txt"], baseDir: baseDir,
                                                  on: fs, algorithm: .sha256)
        XCTAssertEqual(entries.count, 2)
        let results = await ChecksumEngine.verify(entries, baseDir: baseDir, on: fs, algorithm: .sha256)
        XCTAssertEqual(results.map(\.status), [.ok, .ok])
    }

    func testVerifyDetectsMismatchAndMissing() async throws {
        _ = try write("a.txt", "alpha")
        var entries = await ChecksumEngine.create(filenames: ["a.txt"], baseDir: baseDir, on: fs, algorithm: .crc32)
        // Tamper the file so the recomputed digest differs.
        _ = try write("a.txt", "ALPHA-changed")
        entries.append(ChecksumEntry(digest: "deadbeef", filename: "ghost.txt"))   // missing file
        let results = await ChecksumEngine.verify(entries, baseDir: baseDir, on: fs, algorithm: .crc32)
        guard case .mismatch = results[0].status else { return XCTFail("expected mismatch, got \(results[0].status)") }
        XCTAssertEqual(results[1].status, .unreadable)
    }

    func testAlgorithmForExtension() {
        XCTAssertEqual(ChecksumEngine.algorithm(forExtension: "sfv"), .crc32)
        XCTAssertEqual(ChecksumEngine.algorithm(forExtension: "MD5"), .md5)
        XCTAssertEqual(ChecksumEngine.algorithm(forExtension: "sha256"), .sha256)
        XCTAssertEqual(ChecksumEngine.algorithm(forExtension: "unknown"), .sha256)
    }
}
