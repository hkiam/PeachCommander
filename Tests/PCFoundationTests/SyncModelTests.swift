// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

/// Tests for `SyncModel.classify`, the pure "Synchronize Directories"
/// decision function. All dates are fixed via `Date(timeIntervalSince1970:)`
/// so the tests are fully deterministic (no `Date()`/`Date.now`).
final class SyncModelTests: XCTestCase {

    // A fixed reference instant; offsets below are all relative to this so
    // the exact wall-clock value never matters.
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private let symmetric = SyncOptions()
    private let asymmetric = SyncOptions(asymmetric: true)

    // MARK: - Only-one-side files

    func testOnlyLeftFile_CopyToRight_Symmetric() {
        let item = SyncItem(relativePath: "a.txt", isDirectory: false,
                             leftSize: 100, leftModified: t0,
                             rightSize: nil, rightModified: nil)
        let results = SyncModel.classify([item], options: symmetric)
        XCTAssertEqual(results.map(\.action), [.copyToRight])
    }

    func testOnlyLeftFile_CopyToRight_Asymmetric() {
        let item = SyncItem(relativePath: "a.txt", isDirectory: false,
                             leftSize: 100, leftModified: t0,
                             rightSize: nil, rightModified: nil)
        let results = SyncModel.classify([item], options: asymmetric)
        XCTAssertEqual(results.map(\.action), [.copyToRight])
    }

    func testOnlyRightFile_CopyToLeft_Symmetric() {
        let item = SyncItem(relativePath: "b.txt", isDirectory: false,
                             leftSize: nil, leftModified: nil,
                             rightSize: 100, rightModified: t0)
        let results = SyncModel.classify([item], options: symmetric)
        XCTAssertEqual(results.map(\.action), [.copyToLeft])
    }

    func testOnlyRightFile_DeleteRight_Asymmetric() {
        let item = SyncItem(relativePath: "b.txt", isDirectory: false,
                             leftSize: nil, leftModified: nil,
                             rightSize: 100, rightModified: t0)
        let results = SyncModel.classify([item], options: asymmetric)
        XCTAssertEqual(results.map(\.action), [.deleteRight])
    }

    // MARK: - Both present, size + date comparison

    func testBothEqualSizeAndDate_Equal() {
        let item = SyncItem(relativePath: "c.txt", isDirectory: false,
                             leftSize: 100, leftModified: t0,
                             rightSize: 100, rightModified: t0)
        let results = SyncModel.classify([item], options: symmetric)
        XCTAssertEqual(results.map(\.action), [.equal])
    }

    func testLeftNewer_CopyToRight() {
        let item = SyncItem(relativePath: "c.txt", isDirectory: false,
                             leftSize: 200, leftModified: t0.addingTimeInterval(100),
                             rightSize: 100, rightModified: t0)
        let results = SyncModel.classify([item], options: symmetric)
        XCTAssertEqual(results.map(\.action), [.copyToRight])
    }

    func testRightNewer_CopyToLeft() {
        let item = SyncItem(relativePath: "c.txt", isDirectory: false,
                             leftSize: 100, leftModified: t0,
                             rightSize: 200, rightModified: t0.addingTimeInterval(100))
        let results = SyncModel.classify([item], options: symmetric)
        XCTAssertEqual(results.map(\.action), [.copyToLeft])
    }

    func testSameTimeDifferentSize_Conflict() {
        let item = SyncItem(relativePath: "c.txt", isDirectory: false,
                             leftSize: 100, leftModified: t0,
                             rightSize: 200, rightModified: t0)
        let results = SyncModel.classify([item], options: symmetric)
        XCTAssertEqual(results.map(\.action), [.conflict])
    }

    func testAsymmetric_AnyDiff_CopyToRight_EvenWhenRightIsNewer() {
        // In mirror mode the right side is a backup of left: any
        // difference resolves to copyToRight, regardless of which side
        // has the newer timestamp.
        let item = SyncItem(relativePath: "c.txt", isDirectory: false,
                             leftSize: 100, leftModified: t0,
                             rightSize: 200, rightModified: t0.addingTimeInterval(100))
        let results = SyncModel.classify([item], options: asymmetric)
        XCTAssertEqual(results.map(\.action), [.copyToRight])
    }

    // MARK: - Directories

    func testAsymmetric_RightOnlyDir_DeleteRight() {
        let item = SyncItem(relativePath: "sub", isDirectory: true,
                             leftSize: nil, leftModified: nil,
                             rightSize: 0, rightModified: t0)
        let results = SyncModel.classify([item], options: asymmetric)
        XCTAssertEqual(results.map(\.action), [.deleteRight])
    }

    func testAsymmetric_LeftOnlyDir_CopyToRight() {
        let item = SyncItem(relativePath: "sub", isDirectory: true,
                             leftSize: 0, leftModified: t0,
                             rightSize: nil, rightModified: nil)
        let results = SyncModel.classify([item], options: asymmetric)
        XCTAssertEqual(results.map(\.action), [.copyToRight])
    }

    func testBothPresentDir_None() {
        let item = SyncItem(relativePath: "sub", isDirectory: true,
                             leftSize: 0, leftModified: t0,
                             rightSize: 0, rightModified: t0)
        // Both-present directories are structural placeholders in either
        // mode: no action of their own.
        XCTAssertEqual(SyncModel.classify([item], options: symmetric).map(\.action), [.none])
        XCTAssertEqual(SyncModel.classify([item], options: asymmetric).map(\.action), [.none])
    }

    /// A folder that exists on one side only is copied, in symmetric mode too.
    ///
    /// This used to be `.none`, on the reasoning that execution derives the mkdir from the files
    /// that need moving. That holds for every folder except an empty one, which has no files to be
    /// created by — so an empty folder was silently never synchronized, and the two trees kept that
    /// difference for ever. Changed deliberately; this test is the old one turned round.
    func testSymmetric_OnlyOneSideDir_IsCopiedSoAnEmptyFolderSurvives() {
        let onLeft = SyncItem(relativePath: "sub", isDirectory: true,
                              leftSize: 0, leftModified: t0,
                              rightSize: nil, rightModified: nil)
        XCTAssertEqual(SyncModel.classify([onLeft], options: symmetric).map(\.action), [.copyToRight])

        let onRight = SyncItem(relativePath: "sub", isDirectory: true,
                               leftSize: nil, leftModified: nil,
                               rightSize: 0, rightModified: t0)
        XCTAssertEqual(SyncModel.classify([onRight], options: symmetric).map(\.action), [.copyToLeft])
    }

    /// And a folder on *both* sides still has nothing to do — that part was right.
    func testADirectoryPresentOnBothSidesStillHasNoActionOfItsOwn() {
        let item = SyncItem(relativePath: "sub", isDirectory: true,
                            leftSize: 0, leftModified: t0,
                            rightSize: 0, rightModified: t0)
        XCTAssertEqual(SyncModel.classify([item], options: symmetric).map(\.action), [.none])
        XCTAssertEqual(SyncModel.classify([item], options: asymmetric).map(\.action), [.none])
    }

    // MARK: - Content-based comparison

    func testByContentEqual_TimesDiffer_IgnoreDateTrue_Equal() {
        var options = SyncOptions(byContent: true, ignoreDate: true)
        options.toleranceSeconds = 2
        let item = SyncItem(relativePath: "d.txt", isDirectory: false,
                             leftSize: 100, leftModified: t0,
                             rightSize: 100, rightModified: t0.addingTimeInterval(500),
                             contentEqual: true)
        let results = SyncModel.classify([item], options: options)
        XCTAssertEqual(results.map(\.action), [.equal])
    }

    func testByContentDiffer_DecideByNewer_Left() {
        let options = SyncOptions(byContent: true, ignoreDate: false)
        let item = SyncItem(relativePath: "d.txt", isDirectory: false,
                             leftSize: 100, leftModified: t0.addingTimeInterval(50),
                             rightSize: 100, rightModified: t0,
                             contentEqual: false)
        let results = SyncModel.classify([item], options: options)
        XCTAssertEqual(results.map(\.action), [.copyToRight])
    }

    func testByContentDiffer_DecideByNewer_Right() {
        let options = SyncOptions(byContent: true, ignoreDate: false)
        let item = SyncItem(relativePath: "d.txt", isDirectory: false,
                             leftSize: 100, leftModified: t0,
                             rightSize: 100, rightModified: t0.addingTimeInterval(50),
                             contentEqual: false)
        let results = SyncModel.classify([item], options: options)
        XCTAssertEqual(results.map(\.action), [.copyToLeft])
    }

    func testByContentEqualButTimesDiffer_IgnoreDateFalse_CopiesByNewer() {
        // contentEqual == true but timestamps disagree and ignoreDate is
        // false: this is NOT "equal" -- it falls through to the
        // newer-wins logic, same as a real content difference would.
        let options = SyncOptions(byContent: true, ignoreDate: false)
        let item = SyncItem(relativePath: "d.txt", isDirectory: false,
                             leftSize: 100, leftModified: t0.addingTimeInterval(30),
                             rightSize: 100, rightModified: t0,
                             contentEqual: true)
        let results = SyncModel.classify([item], options: options)
        XCTAssertEqual(results.map(\.action), [.copyToRight])
    }

    // MARK: - Tolerance and DST handling

    func testIgnoreDaylightHour_1800sDiff_Equal() {
        // A 30-minute (1800s) gap is well within the +/-1 hour DST/FAT
        // slack that ignoreDaylightHour grants, so same-size files are
        // still considered equal.
        let options = SyncOptions(ignoreDaylightHour: true)
        let item = SyncItem(relativePath: "e.txt", isDirectory: false,
                             leftSize: 100, leftModified: t0,
                             rightSize: 100, rightModified: t0.addingTimeInterval(1800))
        let results = SyncModel.classify([item], options: options)
        XCTAssertEqual(results.map(\.action), [.equal])
    }

    func testToleranceBoundary_ExactlyAtTolerance_Equal() {
        // Delta exactly equal to toleranceSeconds (2s) must still count as
        // "within tolerance" (the comparison is <=, not <).
        let item = SyncItem(relativePath: "f.txt", isDirectory: false,
                             leftSize: 100, leftModified: t0.addingTimeInterval(2),
                             rightSize: 100, rightModified: t0)
        let results = SyncModel.classify([item], options: symmetric)
        XCTAssertEqual(results.map(\.action), [.equal])
    }

    func testToleranceBoundary_JustOverTolerance_CopyToRight() {
        // A delta just past the tolerance window is no longer "equal", and
        // decides a winner by newer timestamp (left is newer here).
        let item = SyncItem(relativePath: "f.txt", isDirectory: false,
                             leftSize: 100, leftModified: t0.addingTimeInterval(2.5),
                             rightSize: 100, rightModified: t0)
        let results = SyncModel.classify([item], options: symmetric)
        XCTAssertEqual(results.map(\.action), [.copyToRight])
    }

    // MARK: - Multi-item ordering

    func testMultiItemList_PreservesOrderAndClassifiesEach() {
        let onlyLeft = SyncItem(relativePath: "only-left.txt", isDirectory: false,
                                 leftSize: 10, leftModified: t0,
                                 rightSize: nil, rightModified: nil)
        let onlyRight = SyncItem(relativePath: "only-right.txt", isDirectory: false,
                                  leftSize: nil, leftModified: nil,
                                  rightSize: 10, rightModified: t0)
        let equalItem = SyncItem(relativePath: "same.txt", isDirectory: false,
                                  leftSize: 10, leftModified: t0,
                                  rightSize: 10, rightModified: t0)
        let conflictItem = SyncItem(relativePath: "conflict.txt", isDirectory: false,
                                     leftSize: 10, leftModified: t0,
                                     rightSize: 20, rightModified: t0)
        let dir = SyncItem(relativePath: "sub", isDirectory: true,
                            leftSize: 0, leftModified: t0,
                            rightSize: 0, rightModified: t0)

        let items = [onlyLeft, onlyRight, equalItem, conflictItem, dir]
        let results = SyncModel.classify(items, options: symmetric)

        XCTAssertEqual(results.map(\.action), [
            .copyToRight, // only-left.txt
            .copyToLeft,  // only-right.txt
            .equal,       // same.txt
            .conflict,    // conflict.txt
            .none         // sub (directory, both present)
        ])
        // Order and item identity must both be preserved, index-for-index.
        XCTAssertEqual(results.map(\.item.relativePath), items.map(\.relativePath))
        for (result, original) in zip(results, items) {
            XCTAssertEqual(result.item, original)
        }
    }

    // MARK: - The result filter (F-192 follow-up)

    /// Every action the grid can hold, in a fixed order, so each test below can say exactly which
    /// indices it expects back.
    private let everyAction: [SyncAction] = [
        .copyToRight,   // 0
        .copyToLeft,    // 1
        .equal,         // 2
        .conflict,      // 3
        .deleteRight,   // 4
        .deleteLeft     // 5
    ]

    func testTheUnfilteredGridShowsEveryRowInOrder() {
        XCTAssertEqual(SyncModel.visibleRows(actions: everyAction, direction: .all, hideEqual: false),
                       [0, 1, 2, 3, 4, 5])
    }

    /// A delete on the right is a change that lands on the right, so it belongs to the same
    /// direction as a copy to the right — the filter is about which side is written, not read.
    func testFilteringToTheRightKeepsTheCopyAndTheDeleteThatLandThere() {
        XCTAssertEqual(SyncModel.visibleRows(actions: everyAction, direction: .toRight, hideEqual: false),
                       [0, 4])
    }

    func testFilteringToTheLeftKeepsTheCopyAndTheDeleteThatLandThere() {
        XCTAssertEqual(SyncModel.visibleRows(actions: everyAction, direction: .toLeft, hideEqual: false),
                       [1, 5])
    }

    /// The rows that change neither side are what a direction filter is asking to be rid of, so
    /// neither the identical files nor the conflicts survive one — including when "hide identical"
    /// is off, which only ever *adds* a reason to drop a row.
    func testADirectionFilterAlsoDropsTheIdenticalAndConflictingRows() {
        for direction in [SyncDirectionFilter.toRight, .toLeft] {
            let rows = SyncModel.visibleRows(actions: everyAction, direction: direction, hideEqual: false)
            XCTAssertFalse(rows.contains(2), "identical row survived \(direction)")
            XCTAssertFalse(rows.contains(3), "conflict row survived \(direction)")
        }
    }

    func testHidingIdenticalRowsLeavesTheConflictsAlone() {
        XCTAssertEqual(SyncModel.visibleRows(actions: everyAction, direction: .all, hideEqual: true),
                       [0, 1, 3, 4, 5])
    }

    /// The window lets a row's direction be reversed by hand, and the filter has to follow what the
    /// row says now: the same list, one action flipped, moves that row between the two filters.
    func testAReversedRowMovesToTheOtherDirectionsFilter() {
        var actions = everyAction
        XCTAssertEqual(SyncModel.visibleRows(actions: actions, direction: .toRight, hideEqual: false), [0, 4])
        actions[0] = .copyToLeft
        XCTAssertEqual(SyncModel.visibleRows(actions: actions, direction: .toRight, hideEqual: false), [4])
        XCTAssertEqual(SyncModel.visibleRows(actions: actions, direction: .toLeft, hideEqual: false), [0, 1, 5])
    }

    func testAnEmptyGridFiltersToNothingRatherThanFailing() {
        for direction in SyncDirectionFilter.allCases {
            XCTAssertEqual(SyncModel.visibleRows(actions: [], direction: direction, hideEqual: true), [])
        }
    }

    /// The tolerance was carried by `SyncOptions` from the day it was written and nothing could set
    /// it: two seconds, for everyone. Two is right for FAT, and wrong for a share whose clock is a
    /// few seconds off its client — there the whole tree reads as changed. Now that the window has a
    /// field for it, this pins that a raised value really is what decides.
    func testARaisedToleranceMakesAClockSkewedPairEqual() {
        let item = SyncItem(relativePath: "a.txt", isDirectory: false,
                            leftSize: 10, leftModified: t0,
                            rightSize: 10, rightModified: t0.addingTimeInterval(8))
        XCTAssertEqual(SyncModel.classify([item], options: SyncOptions()).map(\.action), [.copyToLeft])
        var wider = SyncOptions()
        wider.toleranceSeconds = 10
        XCTAssertEqual(SyncModel.classify([item], options: wider).map(\.action), [.equal])
    }

    /// And it cannot swallow a real difference: raising the tolerance says "these timestamps are the
    /// same moment", not "these files are the same".
    func testARaisedToleranceStillComparesTheSizes() {
        let item = SyncItem(relativePath: "a.txt", isDirectory: false,
                            leftSize: 10, leftModified: t0,
                            rightSize: 20, rightModified: t0.addingTimeInterval(8))
        var wider = SyncOptions()
        wider.toleranceSeconds = 10
        XCTAssertEqual(SyncModel.classify([item], options: wider).map(\.action), [.conflict])
    }

    // MARK: - A mirror does not delete a folder it did not look into

    // A folder "on a side" needs a size on that side: `classify` reads presence off
    // `leftSize`/`rightSize`, not off the dates. Written with only a date, the first version of
    // these described a folder that was on neither side — and two of them then passed for the wrong
    // reason, which a third one caught by disagreeing.

    /// Deleting a folder is recursive, so a mirror that removes a stray folder removes whatever the
    /// comparison held back inside it — the mask's exclusions, hidden files, the filter's, or the
    /// whole content when subdirectories were switched off. The scanner marks such a folder and the
    /// answer here is "leave it alone".
    func test_aMirrorDoesNotDeleteAFolderWithHeldBackContent() {
        let folder = SyncItem(relativePath: "Old", isDirectory: true,
                              leftSize: nil, leftModified: nil,
                              rightSize: 0, rightModified: t0,
                              contentEqual: nil, hasHeldBackContent: true)
        XCTAssertEqual(SyncModel.classify([folder], options: asymmetric).map(\.action), [SyncAction.none])
    }

    /// Without the marking it is still a delete: this is the behaviour the flag turns off, and if
    /// this test ever agreed with the one above, the flag would have stopped meaning anything.
    func test_aMirrorStillDeletesAStrayFolderThatHeldNothingBack() {
        let folder = SyncItem(relativePath: "Old", isDirectory: true,
                              leftSize: nil, leftModified: nil,
                              rightSize: 0, rightModified: t0)
        XCTAssertEqual(SyncModel.classify([folder], options: asymmetric).map(\.action), [.deleteRight])
    }

    /// Only the delete is withdrawn. A left-only folder is still created on the right whatever it
    /// holds back — creating a folder takes nothing away, and the alternative is a mirror that never
    /// reproduces a folder with an excluded file in it.
    func test_aLeftOnlyFolderIsStillCreatedOnTheRight() {
        let folder = SyncItem(relativePath: "New", isDirectory: true,
                              leftSize: 0, leftModified: t0,
                              rightSize: nil, rightModified: nil,
                              contentEqual: nil, hasHeldBackContent: true)
        XCTAssertEqual(SyncModel.classify([folder], options: asymmetric).map(\.action), [.copyToRight])
    }

    /// And in symmetric mode the flag changes nothing, because nothing there deletes.
    func test_theFlagChangesNothingWithoutAMirror() {
        let folder = SyncItem(relativePath: "Old", isDirectory: true,
                              leftSize: nil, leftModified: nil,
                              rightSize: 0, rightModified: t0,
                              contentEqual: nil, hasHeldBackContent: true)
        XCTAssertEqual(SyncModel.classify([folder], options: symmetric).map(\.action), [.copyToLeft])
    }

}
