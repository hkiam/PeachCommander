// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCOperations
import PCFoundation
import PCVFS

final class SplitCombineEngineTests: XCTestCase {
    private var dir: URL!
    private let fs = LocalFS()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-split-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func vpath(_ name: String) -> VFSPath { VFSPath(filesystemId: "file", path: dir.appendingPathComponent(name).path) }
    private var dirPath: VFSPath { VFSPath(filesystemId: "file", path: dir.path) }

    // MARK: - The sizes and the sidecar that were never exercised (F-095)

    func testAWindowsWrittenSidecarIsAccepted() async throws {
        // .crc is a Total Commander format, so these files arrive written on Windows — with CRLF, and
        // sometimes a byte-order mark. `parse` compared each Character against "\n" and "\r", and in
        // Swift a CRLF is one Character equal to neither, so the sidecar parsed into nothing and
        // `combine` refused the whole set with `badCRCFile`. Loud, but it defeated the one thing the
        // format exists for.
        let original = Data((0..<500).map { UInt8($0 & 0xFF) })
        try original.write(to: dir.appendingPathComponent("tc.bin"))
        _ = try await SplitCombineEngine.split(vpath("tc.bin"), partSize: 200, into: dirPath, on: fs)
        try FileManager.default.removeItem(at: dir.appendingPathComponent("tc.bin"))

        // Rewrite the sidecar exactly as a Windows tool would have.
        let sidecar = dir.appendingPathComponent("tc.bin.crc")
        let text = try String(contentsOf: sidecar, encoding: .utf8)
        try ("\u{FEFF}" + text.replacingOccurrences(of: "\n", with: "\r\n"))
            .write(to: sidecar, atomically: true, encoding: .utf8)

        let result = try await SplitCombineEngine.combine(crcPath: vpath("tc.bin.crc"), into: dirPath, on: fs)
        XCTAssertTrue(result.crcOK)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("tc.bin")), original)
    }

    func testAFileThatDividesExactlyProducesNoEmptyTrailingPart() async throws {
        // The boundary an off-by-one lands on: 600 bytes in 200-byte parts is exactly three, and a
        // fourth, empty part would make the set look truncated to anything counting them.
        let original = Data((0..<600).map { UInt8($0 & 0xFF) })
        try original.write(to: dir.appendingPathComponent("exact.bin"))
        _ = try await SplitCombineEngine.split(vpath("exact.bin"), partSize: 200, into: dirPath, on: fs)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("exact.bin.003").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("exact.bin.004").path),
                       "an exactly-dividing file must not get an empty fourth part")

        try FileManager.default.removeItem(at: dir.appendingPathComponent("exact.bin"))
        let result = try await SplitCombineEngine.combine(crcPath: vpath("exact.bin.crc"), into: dirPath, on: fs)
        XCTAssertTrue(result.crcOK)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("exact.bin")), original)
    }

    func testAOneBytePartSizeStillRoundTrips() async throws {
        // Degenerate but legal, and the case where every chunk boundary is also a part boundary.
        let original = Data([1, 2, 3, 4, 5])
        try original.write(to: dir.appendingPathComponent("tiny.bin"))
        let info = try await SplitCombineEngine.split(vpath("tiny.bin"), partSize: 1, into: dirPath, on: fs)
        XCTAssertEqual(info.size, 5)
        try FileManager.default.removeItem(at: dir.appendingPathComponent("tiny.bin"))
        let result = try await SplitCombineEngine.combine(crcPath: vpath("tiny.bin.crc"), into: dirPath, on: fs)
        XCTAssertTrue(result.crcOK)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("tiny.bin")), original)
    }

    func testAnEmptyFileRoundTrips() async throws {
        // Splitting nothing is a thing users do by accident; it must not produce a set that cannot be
        // put back together.
        try Data().write(to: dir.appendingPathComponent("empty.bin"))
        let info = try await SplitCombineEngine.split(vpath("empty.bin"), partSize: 100, into: dirPath, on: fs)
        XCTAssertEqual(info.size, 0)
        try FileManager.default.removeItem(at: dir.appendingPathComponent("empty.bin"))
        let result = try await SplitCombineEngine.combine(crcPath: vpath("empty.bin.crc"), into: dirPath, on: fs)
        XCTAssertTrue(result.crcOK)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("empty.bin")), Data())
    }

    func testAGapInThePartsIsNotSilentlyIgnored() async throws {
        // Combine stops at the first part it cannot read, so a missing middle part yields a short file.
        // That is acceptable only because the CRC says so — this pins that it does.
        let original = Data((0..<500).map { UInt8($0 & 0xFF) })
        try original.write(to: dir.appendingPathComponent("gap.bin"))
        _ = try await SplitCombineEngine.split(vpath("gap.bin"), partSize: 200, into: dirPath, on: fs)
        try FileManager.default.removeItem(at: dir.appendingPathComponent("gap.bin"))
        try FileManager.default.removeItem(at: dir.appendingPathComponent("gap.bin.002"))

        let result = try await SplitCombineEngine.combine(crcPath: vpath("gap.bin.crc"), into: dirPath, on: fs)
        XCTAssertFalse(result.crcOK, "a missing part must not be reported as a good reassembly")
    }

    func testANameWithSpacesAndNonASCIIRoundTrips() async throws {
        let original = Data("Grüße aus Zürich".utf8)
        let name = "zwei wörter.bin"
        try original.write(to: dir.appendingPathComponent(name))
        _ = try await SplitCombineEngine.split(vpath(name), partSize: 4, into: dirPath, on: fs)
        try FileManager.default.removeItem(at: dir.appendingPathComponent(name))
        let result = try await SplitCombineEngine.combine(crcPath: vpath(name + ".crc"), into: dirPath, on: fs)
        XCTAssertTrue(result.crcOK)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(name)), original)
    }

    func testSplitCreatesPartsAndCRC() async throws {
        let original = Data((0..<1000).map { UInt8($0 & 0xFF) })
        try original.write(to: dir.appendingPathComponent("data.bin"))
        let info = try await SplitCombineEngine.split(vpath("data.bin"), partSize: 300, into: dirPath, on: fs)

        XCTAssertEqual(info.size, 1000)
        XCTAssertEqual(info.crc32, CRC32.checksum(original))
        // 4 parts: 300, 300, 300, 100.
        let fm = FileManager.default
        for (i, expected) in [300, 300, 300, 100].enumerated() {
            let part = dir.appendingPathComponent(SplitInfo.partName("data.bin", index: i + 1))
            let size = try fm.attributesOfItem(atPath: part.path)[.size] as! Int
            XCTAssertEqual(size, expected, "part \(i + 1)")
        }
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("data.bin.crc").path))
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent("data.bin.005").path))
    }

    func testSplitThenCombineReproducesOriginal() async throws {
        let original = Data((0..<2500).map { UInt8(($0 * 3) & 0xFF) })
        try original.write(to: dir.appendingPathComponent("orig.dat"))
        _ = try await SplitCombineEngine.split(vpath("orig.dat"), partSize: 512, into: dirPath, on: fs)
        // Remove the original so combine must rebuild it from parts.
        try FileManager.default.removeItem(at: dir.appendingPathComponent("orig.dat"))

        let (info, ok) = try await SplitCombineEngine.combine(crcPath: vpath("orig.dat.crc"), into: dirPath, on: fs)
        XCTAssertTrue(ok)
        XCTAssertEqual(info.filename, "orig.dat")
        let rebuilt = try Data(contentsOf: dir.appendingPathComponent("orig.dat"))
        XCTAssertEqual(rebuilt, original)
    }

    func testCombineDetectsCorruptPart() async throws {
        let original = Data(repeating: 0x5A, count: 800)
        try original.write(to: dir.appendingPathComponent("f"))
        _ = try await SplitCombineEngine.split(vpath("f"), partSize: 300, into: dirPath, on: fs)
        // Corrupt part 2.
        try Data(repeating: 0x00, count: 300).write(to: dir.appendingPathComponent("f.002"))
        let (_, ok) = try await SplitCombineEngine.combine(crcPath: vpath("f.crc"), into: dirPath, on: fs)
        XCTAssertFalse(ok)   // CRC mismatch
    }

    func testSinglePartWhenPartSizeExceedsFile() async throws {
        let original = Data("small".utf8)
        try original.write(to: dir.appendingPathComponent("s.txt"))
        let info = try await SplitCombineEngine.split(vpath("s.txt"), partSize: 1 << 20, into: dirPath, on: fs)
        XCTAssertEqual(info.size, 5)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("s.txt.001").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("s.txt.002").path))
    }
}
