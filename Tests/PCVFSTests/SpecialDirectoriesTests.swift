import XCTest
@testable import PCVFS

final class SpecialDirectoriesTests: XCTestCase {
    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("pc-home-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home.appendingPathComponent("Desktop"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: home.appendingPathComponent("Documents"), withIntermediateDirectories: true)
        // No Downloads dir → should be filtered out.
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: home) }

    func testExistingDirsOnly() {
        let dirs = SpecialDirectories.all(home: home.path)
        let names = dirs.map(\.name)
        XCTAssertTrue(names.contains("Home"))
        XCTAssertTrue(names.contains("Desktop"))
        XCTAssertTrue(names.contains("Documents"))
        XCTAssertFalse(names.contains("Downloads"))   // absent → filtered
        XCTAssertTrue(names.contains("Root"))         // "/" always exists
    }

    func testHomePathMapping() {
        let dirs = SpecialDirectories.all(home: home.path)
        XCTAssertEqual(dirs.first { $0.name == "Home" }?.path, home.path)
        XCTAssertEqual(dirs.first { $0.name == "Desktop" }?.path, home.path + "/Desktop")
    }
}
