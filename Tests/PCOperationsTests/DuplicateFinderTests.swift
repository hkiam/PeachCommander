// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCOperations
import PCFoundation
import PCVFS

final class DuplicateFinderTests: XCTestCase {
    private var dir: URL!
    private let fs = LocalFS()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-dup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    @discardableResult
    private func write(_ rel: String, _ content: String) throws -> URL {
        let url = dir.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.data(using: .utf8)!.write(to: url)
        return url
    }
    private func vpath(_ url: URL) -> VFSPath { VFSPath(filesystemId: "file", path: url.path) }

    func testFindsIdenticalContentOnly() async throws {
        let a = try write("a.txt", "duplicate-content")
        let b = try write("b.txt", "duplicate-content")          // identical to a
        let c = try write("c.txt", "different-conten!")          // SAME size as a, different bytes
        let d = try write("sub/d.log", "another dup here")
        let e = try write("sub/e.log", "another dup here")       // identical to d
        _ = try write("unique.txt", "one of a kind entirely")

        // Sanity: a and c must be the same size (so tier-1 can't separate them).
        let sizeA = try FileManager.default.attributesOfItem(atPath: a.path)[.size] as! Int
        let sizeC = try FileManager.default.attributesOfItem(atPath: c.path)[.size] as! Int
        XCTAssertEqual(sizeA, sizeC)

        let groups = await DuplicateFinder.find(paths: [a, b, c, d, e].map(vpath), on: fs)
        let sets = Set(groups.map { Set($0.paths) })
        XCTAssertEqual(sets, [Set([a.path, b.path]), Set([d.path, e.path])])
        // c (same size, different content) must NOT be grouped with a/b.
        XCTAssertFalse(groups.contains { $0.paths.contains(c.path) })
    }

    func testCollectFilesRecursesAndSkipsDirs() async throws {
        try write("top.txt", "x")
        try write("sub/nested.txt", "y")
        try write("sub/deep/z.bin", "z")
        let files = await DuplicateFinder.collectFiles(under: vpath(dir), on: fs)
        let names = Set(files.map { ($0.path as NSString).lastPathComponent })
        XCTAssertEqual(names, ["top.txt", "nested.txt", "z.bin"])
    }

    func testNoDuplicatesReturnsEmpty() async throws {
        let a = try write("a.txt", "aaa")
        let b = try write("b.txt", "bbbb")   // different size
        let groups = await DuplicateFinder.find(paths: [a, b].map(vpath), on: fs)
        XCTAssertTrue(groups.isEmpty)
    }

    func testGroupsSortedByWastedSpace() async throws {
        // Two small dupes vs two big dupes → big group first.
        let big1 = try write("big1", String(repeating: "A", count: 1000))
        let big2 = try write("big2", String(repeating: "A", count: 1000))
        let small1 = try write("small1", "hi")
        let small2 = try write("small2", "hi")
        let groups = await DuplicateFinder.find(paths: [small1, small2, big1, big2].map(vpath), on: fs)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first?.size, 1000)   // biggest wasted space first
    }

    // MARK: - Things that look identical but are not separate copies (F-158)
    //
    // The results window offers to delete what this finds, so a wrong grouping is not a cosmetic
    // problem. Two of them are worth pinning: a link and its target hold the same bytes but deleting
    // "the duplicate" frees nothing at best and destroys the only copy at worst.

    func testASymlinkIsNotReportedAsADuplicateOfItsTarget() async throws {
        let target = try write("real.txt", "the only copy")
        let link = dir.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let groups = await DuplicateFinder.find(paths: [vpath(target), vpath(link)], on: fs)
        XCTAssertTrue(groups.isEmpty, "a symlink and its target are one file; offering to delete the "
                      + "\"duplicate\" invites deleting the data and keeping the pointer. Groups: \(groups)")
    }

    func testAHardLinkIsNotReportedAsASeparateCopy() async throws {
        // Same inode: deleting one frees no space at all, so listing the pair as recoverable waste is
        // simply untrue.
        let target = try write("original.txt", "shared bytes")
        let link = dir.appendingPathComponent("hard.txt")
        try FileManager.default.linkItem(at: target, to: link)

        let groups = await DuplicateFinder.find(paths: [vpath(target), vpath(link)], on: fs)
        XCTAssertTrue(groups.isEmpty, "two names for one file are not two copies. Groups: \(groups)")
    }

    func testTwoRealCopiesAreStillFoundAlongsideALink() async throws {
        // The negative cases above must not be bought by making the finder blind: a genuine duplicate
        // sitting next to a link still has to be reported.
        let a = try write("a.txt", "same content here")
        let b = try write("b.txt", "same content here")
        let link = dir.appendingPathComponent("a-link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: a)

        let groups = await DuplicateFinder.find(paths: [vpath(a), vpath(b), vpath(link)], on: fs)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.paths, [a.path, b.path].sorted())
    }
}
