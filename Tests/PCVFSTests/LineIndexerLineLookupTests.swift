// SPDX-License-Identifier: Apache-2.0
// LineIndexerLineLookupTests.swift - `line(containing:in:)`, the byte-offset → line lookup the
// viewer's virtual text views use to show a search hit.

import XCTest
@testable import PCVFS

final class LineIndexerLineLookupTests: XCTestCase {

    private let starts: [Int64] = [0, 10, 10, 25, 40]   // note the empty line at 10

    func testAnOffsetOnALineStartIsThatLine() {
        XCTAssertEqual(LineIndexer.line(containing: 0, in: starts), 0)
        XCTAssertEqual(LineIndexer.line(containing: 25, in: starts), 3)
        XCTAssertEqual(LineIndexer.line(containing: 40, in: starts), 4)
    }

    func testAnOffsetInsideALineIsThatLine() {
        XCTAssertEqual(LineIndexer.line(containing: 5, in: starts), 0)
        XCTAssertEqual(LineIndexer.line(containing: 24, in: starts), 2)
        XCTAssertEqual(LineIndexer.line(containing: 39, in: starts), 3)
    }

    func testAnEmptyLineResolvesToTheLastOneStartingThere() {
        // Two lines start at 10 — an empty line. The later one is the one an offset of 10 belongs
        // to, which is what a reader sees: the caret sits on the line that has room for it.
        XCTAssertEqual(LineIndexer.line(containing: 10, in: starts), 2)
    }

    func testAnOffsetPastTheEndClampsToTheLastLine() {
        XCTAssertEqual(LineIndexer.line(containing: 10_000, in: starts), 4)
    }

    func testAnOffsetBeforeTheFirstLineIsTheFirstLine() {
        XCTAssertEqual(LineIndexer.line(containing: -5, in: starts), 0)
    }

    func testAnEmptyIndexIsAnsweredRatherThanTrapped() {
        XCTAssertEqual(LineIndexer.line(containing: 42, in: []), 0)
    }
}
