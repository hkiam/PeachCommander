// SPDX-License-Identifier: Apache-2.0
// DirCompareMarkerTests - Unit tests for DirCompareMarker

import XCTest
@testable import PCFoundation

final class DirCompareMarkerTests: XCTestCase {

    // Fixed, deterministic reference times -- never use Date().
    private let base = Date(timeIntervalSince1970: 1_700_000_000)
    private lazy var basePlus1 = base.addingTimeInterval(1)        // within default tolerance (2s)
    private lazy var basePlus2 = base.addingTimeInterval(2)        // exactly at default tolerance (2s) -> still "same"
    private lazy var basePlus3 = base.addingTimeInterval(3)        // just outside default tolerance -> "newer"
    private lazy var basePlus100 = base.addingTimeInterval(100)    // clearly newer

    private func file(_ name: String, size: Int64 = 100, modified: Date) -> DirCompareEntry {
        DirCompareEntry(name: name, isDirectory: false, size: size, modified: modified)
    }

    private func dir(_ name: String, modified: Date) -> DirCompareEntry {
        DirCompareEntry(name: name, isDirectory: true, size: 0, modified: modified)
    }

    // MARK: - Only on one side

    func testOnlyLeft_marksLeft() {
        let left = [file("a.txt", modified: base)]
        let right: [DirCompareEntry] = []
        let result = DirCompareMarker.compare(left: left, right: right)
        XCTAssertEqual(result.leftMarks, ["a.txt"])
        XCTAssertEqual(result.rightMarks, [])
    }

    func testOnlyRight_marksRight() {
        let left: [DirCompareEntry] = []
        let right = [file("b.txt", modified: base)]
        let result = DirCompareMarker.compare(left: left, right: right)
        XCTAssertEqual(result.leftMarks, [])
        XCTAssertEqual(result.rightMarks, ["b.txt"])
    }

    // MARK: - Same name, different times

    func testLeftNewer_marksLeftOnly() {
        let left = [file("a.txt", modified: basePlus100)]
        let right = [file("a.txt", modified: base)]
        let result = DirCompareMarker.compare(left: left, right: right)
        XCTAssertEqual(result.leftMarks, ["a.txt"])
        XCTAssertEqual(result.rightMarks, [])
    }

    func testRightNewer_marksRightOnly() {
        let left = [file("a.txt", modified: base)]
        let right = [file("a.txt", modified: basePlus100)]
        let result = DirCompareMarker.compare(left: left, right: right)
        XCTAssertEqual(result.leftMarks, [])
        XCTAssertEqual(result.rightMarks, ["a.txt"])
    }

    // MARK: - Same time

    func testSameTimeSameSize_marksNeither() {
        let left = [file("a.txt", size: 100, modified: base)]
        let right = [file("a.txt", size: 100, modified: base)]
        let result = DirCompareMarker.compare(left: left, right: right)
        XCTAssertEqual(result.leftMarks, [])
        XCTAssertEqual(result.rightMarks, [])
    }

    func testSameTimeDifferentSize_marksBoth() {
        let left = [file("a.txt", size: 100, modified: base)]
        let right = [file("a.txt", size: 200, modified: base)]
        let result = DirCompareMarker.compare(left: left, right: right)
        XCTAssertEqual(result.leftMarks, ["a.txt"])
        XCTAssertEqual(result.rightMarks, ["a.txt"])
    }

    // MARK: - Tolerance boundary

    func testWithinTolerance_treatedAsEqual_sameSize_marksNeither() {
        let left = [file("a.txt", size: 100, modified: base)]
        let right = [file("a.txt", size: 100, modified: basePlus1)]
        let result = DirCompareMarker.compare(left: left, right: right, toleranceSeconds: 2)
        XCTAssertEqual(result.leftMarks, [])
        XCTAssertEqual(result.rightMarks, [])
    }

    func testExactlyAtTolerance_treatedAsEqual() {
        // delta == toleranceSeconds should still count as "same time".
        let left = [file("a.txt", size: 100, modified: base)]
        let right = [file("a.txt", size: 100, modified: basePlus2)]
        let result = DirCompareMarker.compare(left: left, right: right, toleranceSeconds: 2)
        XCTAssertEqual(result.leftMarks, [])
        XCTAssertEqual(result.rightMarks, [])
    }

    func testJustOutsideTolerance_treatedAsNewer() {
        // basePlus3 is 3s after base, outside the default 2s tolerance, so
        // the right file (newer) should be marked.
        let left = [file("a.txt", modified: base)]
        let right = [file("a.txt", modified: basePlus3)]
        let result = DirCompareMarker.compare(left: left, right: right, toleranceSeconds: 2)
        XCTAssertEqual(result.leftMarks, [])
        XCTAssertEqual(result.rightMarks, ["a.txt"])
    }

    func testWithinToleranceButDifferentSize_marksBoth() {
        let left = [file("a.txt", size: 100, modified: base)]
        let right = [file("a.txt", size: 250, modified: basePlus1)]
        let result = DirCompareMarker.compare(left: left, right: right, toleranceSeconds: 2)
        XCTAssertEqual(result.leftMarks, ["a.txt"])
        XCTAssertEqual(result.rightMarks, ["a.txt"])
    }

    // MARK: - Directories

    func testDirectoriesAreIgnored_onBothSides() {
        // Same name, one directory, one clearly "newer" if it were a file --
        // directories must never be marked nor cause files to be marked.
        let left = [dir("Sub", modified: basePlus100)]
        let right = [dir("Sub", modified: base)]
        let result = DirCompareMarker.compare(left: left, right: right)
        XCTAssertEqual(result.leftMarks, [])
        XCTAssertEqual(result.rightMarks, [])
    }

    func testDirectoryOnlyOnOneSide_isNeverMarked() {
        let left = [dir("OnlyLeftDir", modified: base)]
        let right: [DirCompareEntry] = []
        let result = DirCompareMarker.compare(left: left, right: right)
        XCTAssertEqual(result.leftMarks, [])
        XCTAssertEqual(result.rightMarks, [])
    }

    // MARK: - Case sensitivity

    func testCaseInsensitiveMatch_marksOriginalCasingOnNewerSide() {
        // "Readme.txt" on the left matches "readme.txt" on the right when
        // case-insensitive; the left copy is newer, so only the left
        // panel's own casing ("Readme.txt") should be marked.
        let left = [file("Readme.txt", modified: basePlus100)]
        let right = [file("readme.txt", modified: base)]
        let result = DirCompareMarker.compare(left: left, right: right, caseSensitive: false)
        XCTAssertEqual(result.leftMarks, ["Readme.txt"])
        XCTAssertEqual(result.rightMarks, [])
    }

    func testCaseSensitiveMode_treatsDifferentCasingAsDistinctFiles() {
        // With caseSensitive: true, "Readme.txt" and "readme.txt" don't
        // match at all, so each is "only on its own side".
        let left = [file("Readme.txt", modified: base)]
        let right = [file("readme.txt", modified: base)]
        let result = DirCompareMarker.compare(left: left, right: right, caseSensitive: true)
        XCTAssertEqual(result.leftMarks, ["Readme.txt"])
        XCTAssertEqual(result.rightMarks, ["readme.txt"])
    }

    // MARK: - Mixed realistic scenario

    func testMixedScenario_exactMarksOnBothSides() {
        let left: [DirCompareEntry] = [
            file("onlyLeft.txt", modified: base),                        // only on left
            file("leftNewer.txt", modified: basePlus100),                // newer on left
            file("rightNewer.txt", modified: base),                      // newer on right
            file("same.txt", size: 42, modified: base),                  // identical
            file("sameSizeDiffers.txt", size: 10, modified: base),       // same time, diff size
            dir("SharedDir", modified: basePlus100),                     // directory, ignored
        ]
        let right: [DirCompareEntry] = [
            file("onlyRight.txt", modified: base),                       // only on right
            file("leftNewer.txt", modified: base),
            file("rightNewer.txt", modified: basePlus100),
            file("same.txt", size: 42, modified: base),
            file("sameSizeDiffers.txt", size: 99, modified: base),
            dir("SharedDir", modified: base),
        ]

        let result = DirCompareMarker.compare(left: left, right: right)

        XCTAssertEqual(result.leftMarks, ["onlyLeft.txt", "leftNewer.txt", "sameSizeDiffers.txt"])
        XCTAssertEqual(result.rightMarks, ["onlyRight.txt", "rightNewer.txt", "sameSizeDiffers.txt"])
    }

    func testEmptyPanels_produceEmptyResult() {
        let result = DirCompareMarker.compare(left: [], right: [])
        XCTAssertEqual(result.leftMarks, [])
        XCTAssertEqual(result.rightMarks, [])
    }
}
