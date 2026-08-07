// SPDX-License-Identifier: Apache-2.0
// LinkMakerTests.swift - Do the three kinds of link actually differ from each other? (F-093)
//
// Nothing verified this. All three go through one call and produce a file that *looks* right in a
// listing, so a hard link created as a copy, or an alias written as a plain file, would be noticed only
// when the user later moved the target and found the link no longer followed it.
//
// The witnesses are `stat` and the bytes on disk rather than Foundation: `linkItem` and `bookmarkData`
// are the same layer the code calls, so asking Foundation whether it worked mostly checks that one API
// agrees with itself. An inode number and a file's first four bytes do not.

import XCTest
@testable import PCVFS

final class LinkMakerTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-link-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func stat(_ format: String, _ path: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/stat")
        process.arguments = ["-f", format, path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeTarget(_ name: String, _ contents: String = "target contents") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Symbolic

    func testASymbolicLinkStoresTheTargetVerbatim() throws {
        let target = try makeTarget("target.txt")
        let link = dir.appendingPathComponent("sym.txt")
        try LinkMaker.createLink(kind: .symbolic, at: link.path, target: target.path)

        // %Y is what the link *stores*, not what it resolves to.
        XCTAssertEqual(stat("%Y", link.path), target.path)
        XCTAssertEqual(try String(contentsOf: link, encoding: .utf8), "target contents")
    }

    func testARelativeSymlinkIsNotRewrittenToAnAbsoluteOne() throws {
        // A relative link is relative on purpose: it keeps working when the pair is moved together, and
        // silently rewriting it to an absolute path would take that away.
        _ = try makeTarget("rel-target.txt")
        let link = dir.appendingPathComponent("rel.txt")
        try LinkMaker.createLink(kind: .symbolic, at: link.path, target: "rel-target.txt")
        XCTAssertEqual(stat("%Y", link.path), "rel-target.txt")
    }

    func testASymlinkMayPointAtSomethingThatIsNotThereYet() throws {
        // POSIX allows it and users rely on it (a link laid down before its target). Refusing would be a
        // restriction this app has no reason to add.
        let link = dir.appendingPathComponent("dangling.txt")
        try LinkMaker.createLink(kind: .symbolic, at: link.path, target: "/nowhere/at/all.txt")
        XCTAssertEqual(stat("%Y", link.path), "/nowhere/at/all.txt")
    }

    // MARK: - Hard

    func testAHardLinkIsTheSameFileAndNotACopy() throws {
        let target = try makeTarget("hard-target.txt")
        let link = dir.appendingPathComponent("hard.txt")
        try LinkMaker.createLink(kind: .hard, at: link.path, target: target.path)

        // The inode is the check that separates a hard link from a copy; both read the same bytes.
        let targetInode = stat("%i", target.path)
        XCTAssertFalse(targetInode.isEmpty)
        XCTAssertEqual(stat("%i", link.path), targetInode, "a hard link that is really a copy diverges "
                       + "the moment either side is written to")
        XCTAssertEqual(stat("%l", target.path), "2", "the target's link count must have gone up")

        // …and writing through one is visible through the other, which a copy would not be.
        try "changed".write(to: link, atomically: false, encoding: .utf8)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "changed")
    }

    func testAHardLinkToAMissingTargetFails() throws {
        let link = dir.appendingPathComponent("nope.txt")
        XCTAssertThrowsError(try LinkMaker.createLink(kind: .hard, at: link.path,
                                                      target: dir.appendingPathComponent("absent").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: link.path),
                       "a failed link must not leave a file behind")
    }

    // MARK: - Finder alias

    func testAnAliasIsABookmarkFileAndResolvesToTheTarget() throws {
        let target = try makeTarget("alias-target.txt")
        let link = dir.appendingPathComponent("alias.txt")
        try LinkMaker.createLink(kind: .alias, at: link.path, target: target.path)

        // "book" is the magic at the front of a bookmark file — read from the bytes, so this does not
        // depend on Foundation agreeing with itself about what it wrote.
        let head = try FileHandle(forReadingFrom: link).readData(ofLength: 4)
        XCTAssertEqual(String(decoding: head, as: UTF8.self), "book",
                       "an alias written as anything else is a file the Finder will not follow")

        // It is a real file, not a symlink: %Y is empty for anything that is not a link.
        XCTAssertEqual(stat("%Y", link.path), "")

        // `bookmarkData(withContentsOf:)`, not `Data(contentsOf:)`: an alias file wraps the bookmark, and
        // handing the raw bytes to the resolver fails with "not the correct format". (My first version
        // did exactly that and reported the product broken.)
        var stale = false
        let resolved = try URL(resolvingBookmarkData: try URL.bookmarkData(withContentsOf: link),
                               options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        XCTAssertEqual(resolved.resolvingSymlinksInPath().path,
                       target.resolvingSymlinksInPath().path)
    }

    func testAnAliasStillResolvesAfterTheTargetIsRenamed() throws {
        // This is the one thing an alias offers over a symlink, and the only reason to have both.
        let target = try makeTarget("moving.txt")
        let link = dir.appendingPathComponent("follows.txt")
        try LinkMaker.createLink(kind: .alias, at: link.path, target: target.path)

        let renamed = dir.appendingPathComponent("moved.txt")
        try FileManager.default.moveItem(at: target, to: renamed)

        var stale = false
        let resolved = try URL(resolvingBookmarkData: try URL.bookmarkData(withContentsOf: link),
                               options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        XCTAssertEqual(resolved.lastPathComponent, "moved.txt",
                       "an alias that stops resolving after a rename is just a worse symlink")
    }

    // MARK: - The three are actually different

    func testTheThreeKindsProduceThreeDifferentThings() throws {
        let target = try makeTarget("three.txt")
        var inodes: [String] = []
        for (kind, name) in [(LinkKind.symbolic, "s.txt"), (.hard, "h.txt"), (.alias, "a.txt")] {
            let link = dir.appendingPathComponent(name)
            try LinkMaker.createLink(kind: kind, at: link.path, target: target.path)
            inodes.append(stat("%i", link.path))
        }
        let targetInode = stat("%i", target.path)
        XCTAssertEqual(inodes[1], targetInode, "hard link shares the inode")
        XCTAssertNotEqual(inodes[0], targetInode, "a symlink is its own file")
        XCTAssertNotEqual(inodes[2], targetInode, "an alias is its own file")
        XCTAssertFalse(stat("%Y", dir.appendingPathComponent("s.txt").path).isEmpty, "symlink is a link")
        XCTAssertTrue(stat("%Y", dir.appendingPathComponent("a.txt").path).isEmpty, "alias is not a link")
    }
}
