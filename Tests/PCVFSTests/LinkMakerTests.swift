import XCTest
@testable import PCVFS

final class LinkMakerTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-link-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func target() throws -> URL {
        let t = dir.appendingPathComponent("target.txt")
        try Data("hello link".utf8).write(to: t)
        return t
    }

    func testSymbolicLink() throws {
        let t = try target()
        let link = dir.appendingPathComponent("sym.txt").path
        try LinkMaker.createLink(kind: .symbolic, at: link, target: t.path)
        let dest = try FileManager.default.destinationOfSymbolicLink(atPath: link)
        XCTAssertEqual(dest, t.path)
        // Reading through the link yields the target's content.
        XCTAssertEqual(try String(contentsOfFile: link, encoding: .utf8), "hello link")
    }

    func testHardLink() throws {
        let t = try target()
        let link = dir.appendingPathComponent("hard.txt").path
        try LinkMaker.createLink(kind: .hard, at: link, target: t.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: link))
        XCTAssertEqual(try String(contentsOfFile: link, encoding: .utf8), "hello link")
        // Same inode as the target (a true hard link).
        let a = try FileManager.default.attributesOfItem(atPath: link)[.systemFileNumber] as! Int
        let b = try FileManager.default.attributesOfItem(atPath: t.path)[.systemFileNumber] as! Int
        XCTAssertEqual(a, b)
    }

    func testAliasResolvesToTarget() throws {
        let t = try target()
        let link = dir.appendingPathComponent("alias.txt").path
        try LinkMaker.createLink(kind: .alias, at: link, target: t.path)
        let resolved = try URL(resolvingAliasFileAt: URL(fileURLWithPath: link), options: [])
        XCTAssertEqual(resolved.resolvingSymlinksInPath().path, t.resolvingSymlinksInPath().path)
    }

    func testDuplicateSymlinkThrows() throws {
        let t = try target()
        let link = dir.appendingPathComponent("dup.txt").path
        try LinkMaker.createLink(kind: .symbolic, at: link, target: t.path)
        XCTAssertThrowsError(try LinkMaker.createLink(kind: .symbolic, at: link, target: t.path))
    }
}
