// SPDX-License-Identifier: Apache-2.0
// SyncUndoRunnerTests.swift - The move itself, against a real filesystem.
//
// Real files, because the two claims here cannot be made against a fake. That a put-back restores
// the *bytes* — a path that exists proves only that something is there. And that a step which was
// fine when the plan was made is refused when the world has changed since: between the plan and the
// move sits a confirmation dialog somebody reads, which is a time window with an unbounded pause in
// it.

import XCTest
@testable import PCOperations
import PCFoundation

final class SyncUndoRunnerTests: XCTestCase {
    private var base: URL!, right: URL!, trash: URL!

    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-undo-\(UUID().uuidString)")
        right = base.appendingPathComponent("right")
        // A stand-in for the Trash. The runner does not care where `from` is — it is a path out of
        // the record — so nothing is gained by really trashing here, and a test that fills the
        // user's Trash to prove a `moveItem` would be a poor trade.
        trash = base.appendingPathComponent("trash")
        for dir in [right!, trash!] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: base) }

    private func header() -> SyncRunHeader {
        SyncRunHeader(runAt: 1_700_000_000, leftRoot: base.appendingPathComponent("left").path,
                      rightRoot: right.path, mode: "mirror")
    }

    private func staged(_ name: String, _ contents: String) throws -> SyncUndoPlan.Step {
        let from = trash.appendingPathComponent(name)
        try Data(contents.utf8).write(to: from)
        return SyncUndoPlan.Step(relativePath: name, from: from.path,
                                 to: right.appendingPathComponent(name).path)
    }

    /// The bytes come back, at the path the record named. Compared as bytes rather than by existence:
    /// the whole use of this feature is getting a particular file back.
    func test_aPutBackRestoresTheFileWithItsBytes() throws {
        let step = try staged("gone.txt", "the bytes that have to survive")
        let report = SyncUndoRunner.run([step], header: header())

        XCTAssertEqual(report.putBack, ["gone.txt"])
        XCTAssertTrue(report.refusals.isEmpty, "\(report.refusals)")
        XCTAssertEqual(try String(contentsOf: right.appendingPathComponent("gone.txt"),
                                  encoding: .utf8), "the bytes that have to survive")
        XCTAssertFalse(FileManager.default.fileExists(atPath: step.from),
                       "the item is still in the Trash as well")
    }

    /// The step was fine when it was planned and is not at the moment of the move. This is the
    /// window the re-check exists for, and the refusal has to leave the intruder alone.
    func test_aPathOccupiedBetweenPlanAndMoveIsRefusedAndTheIntruderSurvives() throws {
        let step = try staged("gone.txt", "what the run deleted")
        // …the world changes while the confirmation is on screen.
        let occupied = right.appendingPathComponent("gone.txt")
        try Data("something else entirely".utf8).write(to: occupied)

        let report = SyncUndoRunner.run([step], header: header())

        XCTAssertTrue(report.putBack.isEmpty)
        XCTAssertEqual(report.refusals.map(\.path), ["gone.txt"])
        XCTAssertEqual(try String(contentsOf: occupied, encoding: .utf8),
                       "something else entirely", "the put-back overwrote the file that was there")
        XCTAssertTrue(FileManager.default.fileExists(atPath: step.from),
                      "the item was taken out of the Trash for nothing")
    }

    /// Gone from the Trash between plan and move — somebody emptied it.
    func test_anItemRemovedFromTheTrashBetweenPlanAndMoveIsRefused() throws {
        let step = try staged("gone.txt", "briefly there")
        try FileManager.default.removeItem(atPath: step.from)

        let report = SyncUndoRunner.run([step], header: header())
        XCTAssertTrue(report.putBack.isEmpty)
        XCTAssertTrue(report.refusals[0].reason.contains("no longer in the Trash"),
                      report.refusals[0].reason)
    }

    /// A step naming a destination outside the run's roots is refused here too, not only in the
    /// plan. The two checks are far enough apart that one of them will be edited alone one day —
    /// which is the reason `download` already checks containment twice.
    func test_aStepPointingOutsideTheRootsIsRefusedAtTheMoveAsWell() throws {
        let from = trash.appendingPathComponent("stray.txt")
        try Data("nope".utf8).write(to: from)
        let outside = base.appendingPathComponent("elsewhere.txt")
        let step = SyncUndoPlan.Step(relativePath: "stray.txt", from: from.path, to: outside.path)

        let report = SyncUndoRunner.run([step], header: header())
        XCTAssertTrue(report.putBack.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.path))
        XCTAssertTrue(report.refusals[0].reason.contains("outside both folders"),
                      report.refusals[0].reason)
    }

    /// A file whose folder went with it lands anyway. A mirror deletes a folder recursively, so the
    /// parent may simply not be there; refusing would make a whole subtree un-put-backable for the
    /// sake of one empty directory.
    func test_aFileWhoseFolderIsGoneStillLands() throws {
        let from = trash.appendingPathComponent("deep.txt")
        try Data("in a folder that is no longer there".utf8).write(to: from)
        let step = SyncUndoPlan.Step(relativePath: "a/b/deep.txt", from: from.path,
                                     to: right.appendingPathComponent("a/b/deep.txt").path)

        let report = SyncUndoRunner.run([step], header: header())
        XCTAssertEqual(report.putBack, ["a/b/deep.txt"])
        XCTAssertEqual(try String(contentsOf: right.appendingPathComponent("a/b/deep.txt"),
                                  encoding: .utf8), "in a folder that is no longer there")
    }

    /// One refusal does not stop the rest. A run's worth of steps is not a transaction — there is no
    /// way to make it one — and stopping at the first problem would leave the recovery half done
    /// with no way to ask for the other half.
    func test_oneRefusalDoesNotStopTheOtherSteps() throws {
        let good = try staged("first.txt", "one")
        let blocked = try staged("second.txt", "two")
        try Data("occupied".utf8).write(to: right.appendingPathComponent("second.txt"))
        let alsoGood = try staged("third.txt", "three")

        let report = SyncUndoRunner.run([good, blocked, alsoGood], header: header())
        XCTAssertEqual(report.putBack, ["first.txt", "third.txt"])
        XCTAssertEqual(report.refusals.map(\.path), ["second.txt"])
    }

    /// The facts come from `lstat`, so a symlink is reported as itself. A check that followed the
    /// link would call the path free when the link is dangling, and the put-back would then replace
    /// a symlink somebody put there.
    func test_aDanglingSymlinkCountsAsSomethingBeingThere() throws {
        let step = try staged("linked.txt", "the real file")
        let link = right.appendingPathComponent("linked.txt")
        try FileManager.default.createSymbolicLink(atPath: link.path,
                                                   withDestinationPath: "/nowhere/at/all")

        let report = SyncUndoRunner.run([step], header: header())
        XCTAssertTrue(report.putBack.isEmpty, "a dangling symlink was treated as a free path")
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path),
                       "/nowhere/at/all", "the symlink was replaced")
        // A **refusal**, not a failure, and that is the assertion with the teeth in it. Written
        // first with only the two checks above, this test passed with `stat` in place of `lstat` —
        // measured — because `stat` on a dangling link fails, the path reads as free, and the
        // `moveItem` then fails on its own. Same outcome for the file, wholly different thing to
        // tell the user: "something is there" is an answer, "Operation could not be completed" is
        // not.
        XCTAssertEqual(report.refusals.map(\.path), ["linked.txt"])
        XCTAssertTrue(report.failures.isEmpty,
                      "reported as an I/O failure rather than as an occupied path: \(report.failures)")
    }
}
