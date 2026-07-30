import XCTest
@testable import PCVFS

final class OccupiedSpaceCalculatorTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-space-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func write(_ rel: String, _ bytes: Int) throws -> URL {
        let url = dir.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: url)
        return url
    }

    func testFileSizesSummed() async throws {
        let a = try write("a.bin", 100)
        let b = try write("b.bin", 250)
        let space = await OccupiedSpaceCalculator().measure([a.path, b.path])
        XCTAssertEqual(space.bytes, 350)
        XCTAssertEqual(space.files, 2)
        XCTAssertEqual(space.folders, 0)
    }

    func testDirectoryRecursiveSizeCounted() async throws {
        try write("tree/x.bin", 400)
        try write("tree/sub/y.bin", 600)
        let treePath = dir.appendingPathComponent("tree").path
        let space = await OccupiedSpaceCalculator().measure([treePath])
        XCTAssertEqual(space.bytes, 1000)
        XCTAssertEqual(space.files, 0)     // the selected item is a folder
        XCTAssertEqual(space.folders, 1)
    }

    func testMixedSelection() async throws {
        let f = try write("solo.bin", 50)
        try write("d/inner.bin", 200)
        let space = await OccupiedSpaceCalculator().measure([f.path, dir.appendingPathComponent("d").path])
        XCTAssertEqual(space.bytes, 250)
        XCTAssertEqual(space.files, 1)
        XCTAssertEqual(space.folders, 1)
    }

    func testMissingPathsIgnored() async throws {
        let space = await OccupiedSpaceCalculator().measure([dir.appendingPathComponent("ghost").path])
        XCTAssertEqual(space, OccupiedSpace(bytes: 0, files: 0, folders: 0))
    }
}
