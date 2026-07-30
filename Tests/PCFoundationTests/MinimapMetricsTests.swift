// SPDX-License-Identifier: Apache-2.0
// MinimapMetricsTests.swift - Unit tests for the minimap's per-line metrics.

import XCTest
@testable import PCFoundation

final class MinimapMetricsTests: XCTestCase {
    func test_indentAndLength_perLine_plusTrailingEmptyLine() {
        let (lines, maxCols) = MinimapMetrics.lineMetrics("abc\n    de\n")
        XCTAssertEqual(lines.count, 3)                      // two lines + trailing empty
        XCTAssertEqual(lines[0].indent, 0); XCTAssertEqual(lines[0].length, 3)
        XCTAssertEqual(lines[1].indent, 4); XCTAssertEqual(lines[1].length, 2)
        XCTAssertEqual(lines[2].indent, 0); XCTAssertEqual(lines[2].length, 0)
        XCTAssertEqual(maxCols, 60)                         // short file → the 60 floor
    }

    func test_maxCols_clampedTo140() {
        let (_, maxCols) = MinimapMetrics.lineMetrics(String(repeating: "x", count: 300))
        XCTAssertEqual(maxCols, 140)
    }

    func test_empty_hasNoLines() {
        XCTAssertTrue(MinimapMetrics.lineMetrics("").lines.isEmpty)
    }

    func test_noTrailingNewline_noExtraLine() {
        let (lines, _) = MinimapMetrics.lineMetrics("a\nbb")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[1].length, 2)
    }

    func test_tabsCountAsIndent() {
        let (lines, _) = MinimapMetrics.lineMetrics("\t\tx")
        XCTAssertEqual(lines[0].indent, 2)
        XCTAssertEqual(lines[0].length, 1)
    }
}
