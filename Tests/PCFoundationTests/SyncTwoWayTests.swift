// SPDX-License-Identifier: Apache-2.0
// SyncTwoWayTests.swift - Deciding with a record of the last run, and writing the next one.
//
// One named assertion per cell of the table, because a chain of `if`s over the pair skips exactly
// the cases that lose data. The three that did not exist before this feature are marked; each of
// them is a deletion or a question that a stateless comparison had no way to reach.

import XCTest
@testable import PCFoundation

final class SyncTwoWayTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private var options: SyncOptions {
        var o = SyncOptions()
        o.toleranceSeconds = 2
        o.caseSensitive = true
        return o
    }

    private func reliable(filtered: Set<String> = [], incomplete: Set<String> = []) -> SyncSideScope {
        SyncSideScope(rootEnumerable: true, rootObservedNonEmpty: true, entriesFound: 9,
                      entriesVisited: 9, filtered: filtered, incompleteDirs: incomplete)
    }

    private func unreadable() -> SyncSideScope {
        SyncSideScope(rootEnumerable: false, rootObservedNonEmpty: true, entriesFound: 0,
                      entriesVisited: 0, filtered: [], incompleteDirs: [])
    }

    private func side(_ size: Int64, _ at: Date? = nil, isDirectory: Bool = false) -> SyncStateSide {
        SyncStateSide(size: size, modified: at ?? t0, isDirectory: isDirectory)
    }

    /// `rel`, present on the sides given, with the record given.
    private func decide(_ rel: String = "a.txt",
                        leftNow: (Int64, Date)? = nil, rightNow: (Int64, Date)? = nil,
                        record: SyncStateEntry?,
                        isDirectory: Bool = false,
                        leftScope: SyncSideScope? = nil,
                        rightScope: SyncSideScope? = nil) -> SyncResult {
        let item = SyncItem(relativePath: rel, isDirectory: isDirectory,
                            leftSize: leftNow?.0, leftModified: leftNow?.1,
                            rightSize: rightNow?.0, rightModified: rightNow?.1)
        let state = record.map { [rel: $0] } ?? [:]
        return SyncTwoWay.classify([item], options: options, state: state, stateKnown: true,
                                   leftScope: leftScope ?? reliable(),
                                   rightScope: rightScope ?? reliable())[0]
    }

    // MARK: - Without a record, nothing changes and nothing is deleted

    /// The first run of a pair cannot know whether a one-sided file is new or was deleted, so it
    /// falls back to the existing rules exactly — including that symmetric mode copies rather than
    /// deletes. The mode works from the second run.
    func test_withoutARecordTheExistingRulesApplyAndNothingIsDeleted() {
        let onlyRight = SyncItem(relativePath: "b.txt", isDirectory: false,
                                 leftSize: nil, leftModified: nil, rightSize: 10, rightModified: t0)
        for asymmetric in [false, true] {
            var o = options
            o.asymmetric = asymmetric
            let results = SyncTwoWay.classify([onlyRight], options: o, state: [:], stateKnown: false,
                                              leftScope: reliable(), rightScope: reliable())
            XCTAssertEqual(results, SyncModel.classify([onlyRight], options: o),
                           "the stateless fallback did not match the existing rules")
            XCTAssertEqual(results[0].basis, .comparison)
        }
    }

    // MARK: - The three answers that did not exist before

    /// **New.** The record says the left is untouched and the right is gone, so it goes on the left
    /// too. Without a record this is indistinguishable from "new on the left", and symmetric mode
    /// copies it back — delete something on the laptop, synchronise, and it returns from the backup.
    func test_aDeletionOnTheRightIsPropagatedToTheLeft() {
        let result = decide(leftNow: (10, t0), rightNow: nil,
                            record: SyncStateEntry(relativePath: "a.txt",
                                                   left: side(10), right: side(10)))
        XCTAssertEqual(result.action, .deleteLeft)
        XCTAssertEqual(result.basis, .propagatedDeletion)
    }

    /// **New**, the other way round.
    func test_aDeletionOnTheLeftIsPropagatedToTheRight() {
        let result = decide(leftNow: nil, rightNow: (10, t0),
                            record: SyncStateEntry(relativePath: "a.txt",
                                                   left: side(10), right: side(10)))
        XCTAssertEqual(result.action, .deleteRight)
        XCTAssertEqual(result.basis, .propagatedDeletion)
    }

    /// **New.** Both sides edited since the record. A stateless comparison silently picks the newer
    /// timestamp; with a record the two are distinguishable, and this is a question.
    func test_bothSidesEditedIsAConflict() {
        let result = decide(leftNow: (20, t0.addingTimeInterval(60)),
                            rightNow: (30, t0.addingTimeInterval(90)),
                            record: SyncStateEntry(relativePath: "a.txt",
                                                   left: side(10), right: side(10)))
        XCTAssertEqual(result.action, .conflict)
        XCTAssertEqual(result.basis, .stateConflict)
    }

    /// The case other tools get wrong by deleting quietly: changed here, deleted there.
    func test_changedOnOneSideAndDeletedOnTheOtherIsAConflictNeverADeletion() {
        let changedLeft = decide(leftNow: (99, t0.addingTimeInterval(60)), rightNow: nil,
                                 record: SyncStateEntry(relativePath: "a.txt",
                                                        left: side(10), right: side(10)))
        XCTAssertEqual(changedLeft.action, .conflict)
        XCTAssertEqual(changedLeft.basis, .stateConflict)

        let changedRight = decide(leftNow: nil, rightNow: (99, t0.addingTimeInterval(60)),
                                  record: SyncStateEntry(relativePath: "a.txt",
                                                         left: side(10), right: side(10)))
        XCTAssertEqual(changedRight.action, .conflict)
    }

    // MARK: - A propagated deletion needs the absence proved

    /// Absence is not evidence on its own — the walk may never have started. Where it cannot be
    /// proved the row becomes a conflict, so the user sees that this path was not decided, rather
    /// than nothing, so they do not.
    func test_aDeletionIsNotPropagatedFromASideThatCouldNotBeRead() {
        let result = decide(leftNow: nil, rightNow: (10, t0),
                            record: SyncStateEntry(relativePath: "a.txt",
                                                   left: side(10), right: side(10)),
                            leftScope: unreadable())
        XCTAssertEqual(result.action, .conflict, "a deletion was derived from a side it could not read")
        XCTAssertEqual(result.basis, .stateConflict)
    }

    /// And the same for a path under a folder the walk held back: pruning means the subtree was
    /// never looked at, so nothing under it can be proved gone.
    func test_aDeletionIsNotPropagatedForAPathUnderAHeldBackFolder() {
        let result = decide("build/app.o", leftNow: nil, rightNow: (10, t0),
                            record: SyncStateEntry(relativePath: "build/app.o",
                                                   left: side(10), right: side(10)),
                            leftScope: reliable(filtered: ["build"]))
        XCTAssertEqual(result.action, .conflict)
    }

    // MARK: - The rest of the table

    func test_oneSideMovedAndTheOtherDidNot() {
        let toRight = decide(leftNow: (20, t0.addingTimeInterval(60)), rightNow: (10, t0),
                             record: SyncStateEntry(relativePath: "a.txt",
                                                    left: side(10), right: side(10)))
        XCTAssertEqual(toRight.action, .copyToRight)
        XCTAssertEqual(toRight.basis, .comparison)

        let toLeft = decide(leftNow: (10, t0), rightNow: (20, t0.addingTimeInterval(60)),
                            record: SyncStateEntry(relativePath: "a.txt",
                                                   left: side(10), right: side(10)))
        XCTAssertEqual(toLeft.action, .copyToLeft)
    }

    /// The direction comes from the record, not from which timestamp is larger. Here the side that
    /// changed carries the *older* date — a share with a skewed clock, which is exactly what the
    /// tolerance field and the daylight-hour option exist for.
    func test_theDirectionComesFromTheRecordAndNotFromWhichDateIsLarger() {
        let result = decide(leftNow: (20, t0.addingTimeInterval(-3600)),
                            rightNow: (10, t0),
                            record: SyncStateEntry(relativePath: "a.txt",
                                                   left: side(10), right: side(10)))
        XCTAssertEqual(result.action, .copyToRight,
                       "the side that actually changed did not win")
    }

    func test_aSideTheRecordNeverHadIsCopiedAcross() {
        let leftOnly = decide(leftNow: (10, t0), rightNow: nil, record: nil)
        XCTAssertEqual(leftOnly.action, .copyToRight)
        let rightOnly = decide(leftNow: nil, rightNow: (10, t0), record: nil)
        XCTAssertEqual(rightOnly.action, .copyToLeft)
    }

    func test_neitherSideMovedIsTheOrdinaryVerdict() {
        let result = decide(leftNow: (10, t0), rightNow: (10, t0),
                            record: SyncStateEntry(relativePath: "a.txt",
                                                   left: side(10), right: side(10)))
        XCTAssertEqual(result.action, .equal)
    }

    func test_absentEverywhereIsNoAction() {
        let result = decide(leftNow: nil, rightNow: nil,
                            record: SyncStateEntry(relativePath: "a.txt",
                                                   left: side(10), right: side(10)))
        XCTAssertEqual(result.action, SyncAction.none)
    }

    /// A folder is judged by existence and kind, so an untouched folder whose children changed is
    /// not itself a change — otherwise every folder in the tree becomes a conflict.
    func test_aFolderWhoseChildrenChangedIsNotItselfAChange() {
        let result = decide("Docs", leftNow: (4096, t0.addingTimeInterval(90_000)),
                            rightNow: (4096, t0.addingTimeInterval(50_000)),
                            record: SyncStateEntry(relativePath: "Docs",
                                                   left: side(0, isDirectory: true),
                                                   right: side(0, isDirectory: true)),
                            isDirectory: true)
        XCTAssertEqual(result.action, SyncAction.none, "a folder read as changed on both sides")
    }

    /// Nothing may work out "this is a propagated deletion" from the action alone: a mirror delete
    /// and a propagated one are the same `SyncAction`, and only the basis distinguishes them.
    func test_aMirrorDeleteAndAPropagatedOneShareTheSameAction() {
        let propagated = decide(leftNow: nil, rightNow: (10, t0),
                                record: SyncStateEntry(relativePath: "a.txt",
                                                       left: side(10), right: side(10)))
        var mirror = options
        mirror.asymmetric = true
        let stateless = SyncModel.classify(
            [SyncItem(relativePath: "a.txt", isDirectory: false, leftSize: nil, leftModified: nil,
                      rightSize: 10, rightModified: t0)], options: mirror)[0]
        XCTAssertEqual(propagated.action, stateless.action)
        XCTAssertNotEqual(propagated.basis, stateless.basis,
                          "the two are only distinguishable by the basis, and they were not")
    }

    // MARK: - The record that comes out of a run

    private func summary(_ rel: String, _ change: SyncItemOutcomeSummary.Change)
        -> SyncItemOutcomeSummary {
        SyncItemOutcomeSummary(relativePath: rel, change: change)
    }

    /// The record is built from what the run *did*, and a successful copy records the destination as
    /// it was observed — so the next run sees the two sides agreeing instead of proposing the copy
    /// again.
    func test_aSuccessfulCopyRecordsTheObservedDestination() {
        let item = SyncItem(relativePath: "a.txt", isDirectory: false,
                            leftSize: 10, leftModified: t0, rightSize: nil, rightModified: nil)
        let landed = SyncStateSide(size: 10, modified: t0.addingTimeInterval(5), isDirectory: false)
        let next = SyncState.next(items: [item],
                                  outcomes: [summary("a.txt", .copiedToRight(landed))],
                                  previous: [:], caseSensitive: true, inScope: { _ in true })
        XCTAssertEqual(next.count, 1)
        XCTAssertEqual(next[0].right, landed, "the destination was not recorded as observed")
        XCTAssertEqual(next[0].left?.size, 10)
    }

    /// A copy whose destination was **not** observed cannot be recorded, so the destination side is
    /// left empty and the next run proposes the copy again. Repeating a copy is harmless; recording
    /// the source's timestamp as the destination's would make the whole tree read as changed on
    /// every run, on any side that cannot carry a timestamp.
    func test_aCopyWithNoObservedDestinationIsNotRecordedAsDone() {
        let item = SyncItem(relativePath: "a.txt", isDirectory: false,
                            leftSize: 10, leftModified: t0, rightSize: nil, rightModified: nil)
        let next = SyncState.next(items: [item],
                                  outcomes: [summary("a.txt", .copiedToRight(nil))],
                                  previous: [:], caseSensitive: true, inScope: { _ in true })
        XCTAssertNil(next[0].right)
        XCTAssertNotNil(next[0].left)
    }

    /// The failure that would undo the whole feature: a propagated deletion that did not work must
    /// not be recorded as "gone on both sides", or the next run finds the file on one side with no
    /// record of it and copies it back — resurrecting exactly what the user deleted.
    func test_aDeletionThatFailedIsProposedAgainRatherThanResurrected() {
        // The scan saw the left gone and the right there; the delete on the right failed.
        let item = SyncItem(relativePath: "a.txt", isDirectory: false,
                            leftSize: nil, leftModified: nil, rightSize: 10, rightModified: t0)
        let previous = ["a.txt": SyncStateEntry(relativePath: "a.txt",
                                                left: side(10), right: side(10))]
        let next = SyncState.next(items: [item],
                                  outcomes: [summary("a.txt", .nothingHappened)],
                                  previous: previous, caseSensitive: true, inScope: { _ in true })
        // The previous record stands, and that is the point: it still remembers that both sides had
        // the file, which is what makes the pending deletion a deletion. Writing the scan's view
        // here instead — left gone, right there — reads on the next run as "new on the right", and
        // the file comes back. Measured; my first version of this test asserted that wrong shape.
        XCTAssertEqual(next.count, 1)
        XCTAssertEqual(next[0].left, side(10), "the last agreement was forgotten")
        XCTAssertEqual(next[0].right, side(10))

        // And that record proposes the same deletion next time, rather than a copy back.
        let again = SyncTwoWay.classify([item], options: options,
                                        state: [next[0].relativePath: next[0]], stateKnown: true,
                                        leftScope: reliable(), rightScope: reliable())
        XCTAssertEqual(again[0].action, .deleteRight, "the deletion was not proposed again")
    }

    /// A successful deletion clears that side.
    func test_aSuccessfulDeletionClearsItsSide() {
        let item = SyncItem(relativePath: "a.txt", isDirectory: false,
                            leftSize: nil, leftModified: nil, rightSize: 10, rightModified: t0)
        let next = SyncState.next(items: [item],
                                  outcomes: [summary("a.txt", .deletedRight)],
                                  previous: [:], caseSensitive: true, inScope: { _ in true })
        XCTAssertEqual(next, [], "a path gone from both sides kept a record")
    }

    /// A path absent everywhere loses its record — otherwise creating the file again a month later
    /// on one side reads as a deletion on the other, and the new file is removed.
    func test_aPathGoneFromBothSidesLosesItsRecord() {
        let previous = ["a.txt": SyncStateEntry(relativePath: "a.txt",
                                                left: side(10), right: side(10))]
        let next = SyncState.next(items: [], outcomes: [], previous: previous,
                                  caseSensitive: true, inScope: { _ in true })
        XCTAssertEqual(next, [])
    }

    /// But only when both walks could account for it. Out of scope, the record stands — a run with a
    /// narrower mask must not erase the history of the files it did not consider.
    func test_aPathOutOfScopeKeepsItsRecord() {
        let previous = ["photo.jpg": SyncStateEntry(relativePath: "photo.jpg",
                                                    left: side(10), right: side(10))]
        let next = SyncState.next(items: [], outcomes: [], previous: previous,
                                  caseSensitive: true, inScope: { _ in false })
        XCTAssertEqual(next.map(\.relativePath), ["photo.jpg"],
                       "a run with a narrower mask erased what it did not look at")
    }

    /// Keys are normalised once, so the record a run writes is the one the next run finds.
    func test_theRecordIsKeyedTheWayItWillBeLookedUp() {
        let item = SyncItem(relativePath: "README.md", isDirectory: false,
                            leftSize: 10, leftModified: t0, rightSize: 10, rightModified: t0)
        let next = SyncState.next(items: [item], outcomes: [], previous: [:],
                                  caseSensitive: false, inScope: { _ in true })
        XCTAssertEqual(next.map(\.relativePath), ["readme.md"])
    }
}
