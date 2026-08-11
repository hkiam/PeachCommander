// SPDX-License-Identifier: Apache-2.0
// SplitZipReadTests.swift - Reading an archive that was cut into several files (F-382).
//
// The multi-disk fixtures are built by `/usr/bin/zip -s`, i.e. by Info-ZIP itself, because the point
// of the feature is reading what other tools produce and a fixture this test wrote by hand would only
// prove that the reader agrees with the reader.
//
// What makes the format worth a test rather than a line of code is that the obvious implementation
// passes a shallow one: concatenating the parts gives an archive whose *listing* looks plausible —
// entry names and sizes come out of the central directory, which lives entirely in the last part —
// and only extraction notices that every offset was relative to its own disk. So the assertions here
// are about bytes coming back out, not about how many entries were found.

import XCTest
@testable import PCArchive

final class SplitZipReadTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard FileManager.default.fileExists(atPath: "/usr/bin/zip") else {
            throw XCTSkip("/usr/bin/zip is not available on this machine")
        }
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCArchive-Split-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        tempDir = nil
        try super.tearDownWithError()
    }

    @discardableResult
    private func run(_ tool: String, _ arguments: [String], in directory: URL) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// Deterministic, incompressible content: `zip -s` must actually split, and a stored entry keeps
    /// the bytes where the offsets say they are.
    private func payload(_ byteCount: Int, seed: UInt64) -> Data {
        var state = seed
        var bytes = [UInt8]()
        bytes.reserveCapacity(byteCount)
        for _ in 0..<byteCount {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            bytes.append(UInt8((state >> 33) & 0xff))
        }
        return Data(bytes)
    }

    /// A true multi-disk set: `parts.z01`, `parts.z02`, … and `parts.zip` holding the central
    /// directory. Returns the `.zip`, which is the file a user opens.
    private func multiDiskFixture(memberSize: Int, splitSize: String) throws -> (archive: URL, member: Data) {
        let member = payload(memberSize, seed: 0x5EED)
        let memberURL = tempDir.appendingPathComponent("big.bin")
        try member.write(to: memberURL)
        let status = try run("/usr/bin/zip", ["-q", "-0", "-s", splitSize, "parts.zip", "big.bin"],
                             in: tempDir)
        try XCTSkipUnless(status == 0, "zip -s failed with status \(status)")
        return (tempDir.appendingPathComponent("parts.zip"), member)
    }

    // MARK: - The multi-disk format

    func testAnEntrySpanningSeveralPartsComesBackWhole() throws {
        // 300 KB in 100 KB parts, so the single member's bytes cross two boundaries: an
        // implementation that reads only the part the local header sits in returns a short read.
        let (archive, member) = try multiDiskFixture(memberSize: 300 * 1024, splitSize: "100k")

        let reader = try XCTUnwrap(ZipReader(fileURL: archive), "the split set did not open")
        let entries = reader.entries.filter { !$0.isDirectory }
        XCTAssertEqual(entries.map(\.path), ["big.bin"])

        let extracted = try reader.data(for: try XCTUnwrap(entries.first))
        XCTAssertEqual(extracted.count, member.count, "extracted length does not match the source")
        XCTAssertEqual(extracted, member, "the bytes came back changed or out of order")
    }

    /// The listing alone cannot tell a correct reader from one that ignores the disk fields, so this
    /// pins the thing that separates them: `verify()` inflates every entry and checks its CRC.
    func testVerifyFindsNoProblemInASplitArchive() throws {
        let (archive, _) = try multiDiskFixture(memberSize: 260 * 1024, splitSize: "64k")
        let reader = try XCTUnwrap(ZipReader(fileURL: archive))
        XCTAssertEqual(reader.verify(), [], "a correctly read split archive has no integrity problems")
    }

    func testSeveralMembersAcrossPartsKeepTheirOwnBytes() throws {
        // Distinct payloads: swapping two entries' offsets is a failure mode that equal-sized
        // identical content would hide.
        for (index, name) in ["a.bin", "b.bin", "c.bin"].enumerated() {
            try payload(80 * 1024, seed: UInt64(index + 1) * 7919).write(to: tempDir.appendingPathComponent(name))
        }
        let status = try run("/usr/bin/zip", ["-q", "-0", "-s", "64k", "many.zip", "a.bin", "b.bin", "c.bin"],
                             in: tempDir)
        try XCTSkipUnless(status == 0, "zip -s failed with status \(status)")

        let reader = try XCTUnwrap(ZipReader(fileURL: tempDir.appendingPathComponent("many.zip")))
        for (index, name) in ["a.bin", "b.bin", "c.bin"].enumerated() {
            let entry = try XCTUnwrap(reader.entries.first { $0.path == name }, "\(name) is missing")
            XCTAssertEqual(try reader.data(for: entry),
                           payload(80 * 1024, seed: UInt64(index + 1) * 7919),
                           "\(name) came back as another member's bytes")
        }
    }

    /// A set with a hole is not a readable archive. Opening must fail rather than parse the central
    /// directory — which is intact, it lives in the last part — and then hand back wrong bytes.
    func testAMissingPartIsRefusedRatherThanGuessed() throws {
        let (archive, _) = try multiDiskFixture(memberSize: 300 * 1024, splitSize: "100k")
        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("parts.z02"))
        XCTAssertNil(ZipReader(fileURL: archive), "a set missing .z02 must not open")
    }

    // MARK: - A plain byte split (name.zip.001, .002, …)

    func testANumberedByteSplitIsJoinedBackTogether() throws {
        let member = payload(200 * 1024, seed: 0xC0FFEE)
        try member.write(to: tempDir.appendingPathComponent("big.bin"))
        try XCTSkipUnless(try run("/usr/bin/zip", ["-q", "-0", "whole.zip", "big.bin"], in: tempDir) == 0,
                          "zip failed")

        // Cut the finished archive into fixed-size pieces, which is what a "split file" tool does.
        let whole = try Data(contentsOf: tempDir.appendingPathComponent("whole.zip"))
        let chunk = 64 * 1024
        var index = 1
        var offset = 0
        while offset < whole.count {
            let end = min(offset + chunk, whole.count)
            let url = tempDir.appendingPathComponent(String(format: "whole.zip.%03d", index))
            try whole.subdata(in: offset..<end).write(to: url)
            offset = end
            index += 1
        }
        XCTAssertGreaterThan(index, 2, "the fixture must really be split")

        let first = tempDir.appendingPathComponent("whole.zip.001")
        let reader = try XCTUnwrap(ZipReader(fileURL: first), "the numbered split did not open")
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "big.bin" })
        XCTAssertEqual(try reader.data(for: entry), member)
    }

    // MARK: - Regression: an ordinary archive is unaffected

    func testASingleFileArchiveStillReadsTheSameWay() throws {
        let member = payload(4096, seed: 42)
        try member.write(to: tempDir.appendingPathComponent("one.bin"))
        try XCTSkipUnless(try run("/usr/bin/zip", ["-q", "one.zip", "one.bin"], in: tempDir) == 0, "zip failed")

        let reader = try XCTUnwrap(ZipReader(fileURL: tempDir.appendingPathComponent("one.zip")))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "one.bin" })
        XCTAssertEqual(try reader.data(for: entry), member)
        XCTAssertEqual(reader.verify(), [])
    }
}
