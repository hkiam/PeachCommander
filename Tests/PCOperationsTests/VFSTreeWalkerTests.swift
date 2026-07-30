import XCTest
@testable import PCOperations
import PCVFS

final class VFSTreeWalkerTests: XCTestCase {
    private var dir: URL!
    private let fs = LocalFS()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-walk-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func write(_ rel: String) throws {
        let url = dir.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: url)
    }

    func testCollectsAllFilesRecursively() async throws {
        try write("a.txt")
        try write("sub/b.txt")
        try write("sub/deep/c.bin")
        let files = await VFSTreeWalker.collectFiles(under: VFSPath(filesystemId: "file", path: dir.path), on: fs)
        let names = Set(files.map { ($0.path as NSString).lastPathComponent })
        XCTAssertEqual(names, ["a.txt", "b.txt", "c.bin"])
    }

    func testDepthLimit() async throws {
        try write("top.txt")
        try write("d1/d2/deep.txt")
        // maxDepth 0: only immediate children listed; nested dir not descended.
        let files = await VFSTreeWalker.collectFiles(under: VFSPath(filesystemId: "file", path: dir.path), on: fs, maxDepth: 0)
        let names = Set(files.map { ($0.path as NSString).lastPathComponent })
        XCTAssertEqual(names, ["top.txt"])
    }
}
