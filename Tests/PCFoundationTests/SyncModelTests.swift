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

    func testSymmetric_OnlyLeftDir_None() {
        // Unlike asymmetric mode, symmetric mode never assigns a directory
        // an action of its own -- execution derives mkdir/rmdir from the
        // files that need moving.
        let item = SyncItem(relativePath: "sub", isDirectory: true,
                             leftSize: 0, leftModified: t0,
                             rightSize: nil, rightModified: nil)
        let results = SyncModel.classify([item], options: symmetric)
        XCTAssertEqual(results.map(\.action), [.none])
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
}
