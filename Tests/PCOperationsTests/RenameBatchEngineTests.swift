// SPDX-License-Identifier: Apache-2.0
// RenameBatchEngineTests.swift - Renaming a whole folder at once, and taking it back (F-170…F-176).
//
// A batch rename is the one operation where a defect costs a folder rather than a file, and the case
// that breaks a naive implementation is a *cycle*: `a → b` with `b → a`. Renamed in order, the first
// move destroys the second file.
//
// The forward direction staged through temporary names and was right. Undo did not, and that is what
// these tests were written to find out.

import XCTest
@testable import PCOperations

final class RenameBatchEngineTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-ren-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    @discardableResult
    private func write(_ name: String, _ contents: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    private func read(_ name: String) -> String? {
        try? String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    }
    private func names() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
    }

    // MARK: - Cycles

    func testASwapKeepsBothFiles() throws {
        try write("a.txt", "content A")
        try write("b.txt", "content B")

        let outcome = RenameBatchEngine.apply(dir: dir.path,
                                              pairs: [("a.txt", "b.txt"), ("b.txt", "a.txt")])
        XCTAssertEqual(outcome.log.count, 2)
        XCTAssertTrue(outcome.failed.isEmpty, "\(outcome.failed)")
        XCTAssertEqual(read("a.txt"), "content B")
        XCTAssertEqual(read("b.txt"), "content A")
        XCTAssertEqual(try names(), ["a.txt", "b.txt"], "no temporary file may be left behind")
    }

    func testAThreeWayRotationKeepsAllThree() throws {
        try write("1.txt", "one")
        try write("2.txt", "two")
        try write("3.txt", "three")

        RenameBatchEngine.apply(dir: dir.path,
                                pairs: [("1.txt", "2.txt"), ("2.txt", "3.txt"), ("3.txt", "1.txt")])
        XCTAssertEqual(read("2.txt"), "one")
        XCTAssertEqual(read("3.txt"), "two")
        XCTAssertEqual(read("1.txt"), "three")
    }

    func testUndoingASwapPutsBothBack() throws {
        // The forward direction staged; undo did not, so it moved `b` onto the still-present `a`, both
        // moves failed, and the user was told the rename had been undone when nothing had happened.
        try write("a.txt", "content A")
        try write("b.txt", "content B")
        let outcome = RenameBatchEngine.apply(dir: dir.path,
                                              pairs: [("a.txt", "b.txt"), ("b.txt", "a.txt")])

        let undone = RenameBatchEngine.undo(outcome.log)
        XCTAssertEqual(undone.count, 2, "undo reported \(undone.count) of 2 moves")
        XCTAssertEqual(read("a.txt"), "content A")
        XCTAssertEqual(read("b.txt"), "content B")
        XCTAssertEqual(try names(), ["a.txt", "b.txt"])
    }

    func testUndoingAThreeWayRotationRestoresAllThree() throws {
        try write("1.txt", "one")
        try write("2.txt", "two")
        try write("3.txt", "three")
        let outcome = RenameBatchEngine.apply(dir: dir.path,
                                              pairs: [("1.txt", "2.txt"), ("2.txt", "3.txt"), ("3.txt", "1.txt")])
        RenameBatchEngine.undo(outcome.log)
        XCTAssertEqual(read("1.txt"), "one")
        XCTAssertEqual(read("2.txt"), "two")
        XCTAssertEqual(read("3.txt"), "three")
    }

    // MARK: - The ordinary case still works

    func testAPlainBatchRenameAndItsUndo() throws {
        try write("img1.jpg", "1")
        try write("img2.jpg", "2")
        let outcome = RenameBatchEngine.apply(dir: dir.path,
                                              pairs: [("img1.jpg", "holiday-01.jpg"),
                                                      ("img2.jpg", "holiday-02.jpg")])
        XCTAssertEqual(try names(), ["holiday-01.jpg", "holiday-02.jpg"])
        RenameBatchEngine.undo(outcome.log)
        XCTAssertEqual(try names(), ["img1.jpg", "img2.jpg"])
    }

    // MARK: - What must not happen quietly

    func testAnExistingFileOutsideTheBatchIsNotOverwritten() throws {
        try write("source.txt", "the one being renamed")
        try write("occupied.txt", "someone else's file")

        let outcome = RenameBatchEngine.apply(dir: dir.path, pairs: [("source.txt", "occupied.txt")])
        XCTAssertEqual(read("occupied.txt"), "someone else's file", "a rename must not destroy a file "
                       + "that was not part of the batch")
        XCTAssertEqual(read("source.txt"), "the one being renamed", "the source must survive too")
        XCTAssertEqual(outcome.failed.map(\.name), ["source.txt"],
                       "and the caller has to be able to say it did not happen")
    }

    func testAnUnusableNameIsReportedRatherThanDroppedInSilence() throws {
        try write("keep.txt", "x")
        let outcome = RenameBatchEngine.apply(dir: dir.path,
                                              pairs: [("keep.txt", ""), ("keep.txt", "sub/dir.txt"),
                                                      ("keep.txt", ".."), ("keep.txt", ".")])
        XCTAssertEqual(outcome.log.count, 0)
        XCTAssertEqual(outcome.failed.count, 4, "each unusable name has to be reported: \(outcome.failed)")
        XCTAssertEqual(try names(), ["keep.txt"])
    }

    func testAnUnchangedNameIsNotAFailure() throws {
        try write("same.txt", "x")
        let outcome = RenameBatchEngine.apply(dir: dir.path, pairs: [("same.txt", "same.txt")])
        XCTAssertTrue(outcome.log.isEmpty)
        XCTAssertTrue(outcome.failed.isEmpty, "asking for the name a file already has is a no-op, not an error")
    }

    func testAFailedRenameLeavesNoFileParkedUnderATemporaryName() throws {
        // A file left under ".pcren-…" would be hidden in the panel and read as deleted.
        try write("a.txt", "A")
        try write("taken.txt", "T")
        RenameBatchEngine.apply(dir: dir.path, pairs: [("a.txt", "taken.txt")])
        XCTAssertEqual(try names(), ["a.txt", "taken.txt"])
        XCTAssertFalse(try names().contains { $0.hasPrefix(".pcren-") })
    }

    func testRenamingAMissingFileIsReportedAndDoesNotStopTheRest() throws {
        try write("real.txt", "here")
        let outcome = RenameBatchEngine.apply(dir: dir.path,
                                              pairs: [("gone.txt", "new.txt"), ("real.txt", "renamed.txt")])
        XCTAssertEqual(outcome.failed.map(\.name), ["gone.txt"])
        XCTAssertEqual(read("renamed.txt"), "here", "one bad entry must not abandon the whole batch")
    }

    // MARK: - Case

    func testChangingOnlyTheCaseOfANameWorks() throws {
        // On a case-insensitive volume this is a rename onto "itself" as far as the file system is
        // concerned, and it is something people do constantly.
        try write("readme.txt", "x")
        RenameBatchEngine.apply(dir: dir.path, pairs: [("readme.txt", "README.txt")])
        XCTAssertEqual(try names(), ["README.txt"])
    }
}
