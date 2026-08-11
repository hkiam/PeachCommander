// SPDX-License-Identifier: Apache-2.0
// FileStampTests.swift - Telling a rewritten file from an untouched one (F-384).
//
// The case that matters is the one mtime alone gets wrong: a program that rewrites an archive by
// writing a temporary file and renaming it over the original. `rename(2)` does not touch the source's
// modification time, so the new file can carry an older mtime than the file it replaced — and the
// inode is the only thing that moved. That is not a hypothetical: it is what a safe writer does, and
// what Info-ZIP does when it updates an archive in place.

import XCTest
@testable import PCVFS

final class FileStampTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCVFS-Stamp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let dir { try? FileManager.default.removeItem(at: dir) }
        dir = nil
        try super.tearDownWithError()
    }

    func testAnUntouchedFileKeepsItsStamp() throws {
        let file = dir.appendingPathComponent("a.zip")
        try Data("one".utf8).write(to: file)

        let before = FileStamp.of(file.path)
        XCTAssertNotNil(before)
        XCTAssertEqual(FileStamp.of(file.path), before, "reading it twice must not look like a change")
    }

    func testAMissingFileHasNoStamp() {
        XCTAssertNil(FileStamp.of(dir.appendingPathComponent("absent.zip").path))
    }

    func testARewriteInPlaceIsSeen() throws {
        let file = dir.appendingPathComponent("b.zip")
        try Data("one".utf8).write(to: file)
        let before = FileStamp.of(file.path)

        try Data("different length".utf8).write(to: file)

        XCTAssertNotEqual(FileStamp.of(file.path), before)
    }

    /// The one the inode is in the stamp for: same bytes, same length, and an mtime deliberately set
    /// back to the original's — everything a size-and-mtime check looks at is unchanged, and the file
    /// is still a different file.
    func testAReplacementByRenameIsSeenEvenWithTheOldTimestamp() throws {
        // `utimensat`, not `utimes`: the latter takes microseconds, and a stamp compared to the
        // nanosecond then differs by the sub-second remainder — which made the first version of this
        // test fail on its own premise rather than on what it is about.
        var pinned = [timespec(tv_sec: 1_700_000_000, tv_nsec: 123_456_789),
                      timespec(tv_sec: 1_700_000_000, tv_nsec: 123_456_789)]

        let file = dir.appendingPathComponent("c.zip")
        try Data("payload".utf8).write(to: file)
        XCTAssertEqual(utimensat(AT_FDCWD, file.path, &pinned, 0), 0)
        let before = try XCTUnwrap(FileStamp.of(file.path))

        let replacement = dir.appendingPathComponent("c.zip.tmp")
        try Data("payload".utf8).write(to: replacement)
        XCTAssertEqual(utimensat(AT_FDCWD, replacement.path, &pinned, 0), 0)
        XCTAssertEqual(rename(replacement.path, file.path), 0)

        let after = try XCTUnwrap(FileStamp.of(file.path))
        XCTAssertEqual(after.size, before.size, "the fixture is only interesting if the size matches")
        XCTAssertEqual(after.modified, before.modified, "…and the mtime too")
        XCTAssertNotEqual(after.inode, before.inode, "but it is a different file")
        XCTAssertNotEqual(after, before, "so the stamp must say so")
    }
}
