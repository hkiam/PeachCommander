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
