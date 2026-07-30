// SPDX-License-Identifier: Apache-2.0
// SelectionSummaryFormatterTests - Unit tests for SelectionSummaryFormatter

import XCTest
@testable import PCFoundation

final class SelectionSummaryFormatterTests: XCTestCase {

    private let en = Locale(identifier: "en_US")
    private let de = Locale(identifier: "de_DE")

    // MARK: - dynamicSize: plain byte range (< 1000)

    func testDynamicSize_zero() {
        XCTAssertEqual(SelectionSummaryFormatter.dynamicSize(0, locale: en), "0")
    }

    func testDynamicSize_bytesUnderThousand() {
        XCTAssertEqual(SelectionSummaryFormatter.dynamicSize(999, locale: en), "999")
    }

    // MARK: - dynamicSize: K / M / G boundaries

    func testDynamicSize_kiloThresholdExact() {
        // 1000 bytes is the first value in the "K" branch.
        XCTAssertEqual(SelectionSummaryFormatter.dynamicSize(1000, locale: en), "1.0 K")
    }

    func testDynamicSize_kiloValue() {
        // 2560 / 1024 == 2.5 exactly.
        XCTAssertEqual(SelectionSummaryFormatter.dynamicSize(2560, locale: en), "2.5 K")
    }

    func testDynamicSize_megaThresholdExact() {
        // 1000 * 1024 bytes is the first value in the "M" branch.
        XCTAssertEqual(SelectionSummaryFormatter.dynamicSize(1000 * 1024, locale: en), "1.0 M")
    }

    func testDynamicSize_megaValue() {
        // 2621440 / (1024*1024) == 2.5 exactly.
        XCTAssertEqual(SelectionSummaryFormatter.dynamicSize(2_621_440, locale: en), "2.5 M")
    }

    func testDynamicSize_gigaThresholdExact() {
        // 1000 * 1024 * 1024 bytes is the first value in the "G" branch.
        XCTAssertEqual(SelectionSummaryFormatter.dynamicSize(1000 * 1024 * 1024, locale: en), "1.0 G")
    }

    func testDynamicSize_gigaValue() {
        // 1288490188 / (1024*1024*1024) rounds to 1.2 exactly.
        XCTAssertEqual(SelectionSummaryFormatter.dynamicSize(1_288_490_188, locale: en), "1.2 G")
    }

    func testDynamicSize_kiloBoundaryRoundsUpToNextInteger() {
        // 1023999 is just under the "M" threshold, so it stays in the "K"
        // branch, but 1023999 / 1024 == 999.9990234375, which rounds to
        // 1000.0 at one fractional digit -- the classic TC boundary quirk.
        XCTAssertEqual(SelectionSummaryFormatter.dynamicSize(1_023_999, locale: en), "1,000.0 K")
    }

    // MARK: - dynamicSize: grouping of large byte counts

    func testDynamicSize_largeValueUsesGroupingSeparator_en() {
        // 5,000,000,000,000 bytes / (1024^3) rounds to 4656.6, which needs a
        // thousands separator in its integer part.
        XCTAssertEqual(SelectionSummaryFormatter.dynamicSize(5_000_000_000_000, locale: en), "4,656.6 G")
    }

    func testDynamicSize_largeValueUsesGroupingSeparator_de() {
        // Same magnitude as above, but German grouping uses "." and the
        // decimal separator is ",".
        XCTAssertEqual(SelectionSummaryFormatter.dynamicSize(5_000_000_000_000, locale: de), "4.656,6 G")
    }

    // MARK: - dynamicSize: locale-aware decimal separator

    func testDynamicSize_decimalSeparator_en() {
        XCTAssertEqual(SelectionSummaryFormatter.dynamicSize(2_621_440, locale: en), "2.5 M")
    }

    func testDynamicSize_decimalSeparator_de() {
        XCTAssertEqual(SelectionSummaryFormatter.dynamicSize(2_621_440, locale: de), "2,5 M")
    }

    func testDynamicSize_groupingBoundary_de() {
        XCTAssertEqual(SelectionSummaryFormatter.dynamicSize(1_023_999, locale: de), "1.000,0 K")
    }

    // MARK: - summary

    func testSummary_partialSelection_en() {
        let result = SelectionSummaryFormatter.summary(
            selectedCount: 3,
            totalCount: 41,
            selectedBytes: 2_202_009,   // dynamicSize -> "2.1 M"
            totalBytes: 356_515_840,    // dynamicSize -> "340.0 M"
            locale: en
        )
        XCTAssertEqual(result, "3 of 41 files, 2.1 M of 340.0 M")
    }

    func testSummary_zeroSelection_en() {
        let result = SelectionSummaryFormatter.summary(
            selectedCount: 0,
            totalCount: 41,
            selectedBytes: 0,
            totalBytes: 356_515_840,
            locale: en
        )
        XCTAssertEqual(result, "0 of 41 files, 0 of 340.0 M")
    }

    func testSummary_partialSelection_de_usesGermanDecimalSeparator() {
        let result = SelectionSummaryFormatter.summary(
            selectedCount: 3,
            totalCount: 41,
            selectedBytes: 2_202_009,
            totalBytes: 356_515_840,
            locale: de
        )
        XCTAssertEqual(result, "3 of 41 files, 2,1 M of 340,0 M")
    }

    func testSummary_allSelected() {
        let result = SelectionSummaryFormatter.summary(
            selectedCount: 41,
            totalCount: 41,
            selectedBytes: 356_515_840,
            totalBytes: 356_515_840,
            locale: en
        )
        XCTAssertEqual(result, "41 of 41 files, 340.0 M of 340.0 M")
    }

    // MARK: - detailed (files/folders breakdown)

    func testDetailed_partialSelection_en() {
        let result = SelectionSummaryFormatter.detailed(
            selectedFiles: 2, totalFiles: 40,
            selectedDirs: 1, totalDirs: 5,
            selectedBytes: 2_202_009, totalBytes: 356_515_840,
            locale: en
        )
        XCTAssertEqual(result, "2/40 files, 1/5 folders · 2.1 M / 340.0 M")
    }

    func testDetailed_nothingSelected_en() {
        let result = SelectionSummaryFormatter.detailed(
            selectedFiles: 0, totalFiles: 40,
            selectedDirs: 0, totalDirs: 5,
            selectedBytes: 0, totalBytes: 356_515_840,
            locale: en
        )
        XCTAssertEqual(result, "0/40 files, 0/5 folders · 0 / 340.0 M")
    }
}
