// SPDX-License-Identifier: Apache-2.0
// ContentFieldValuesTests.swift - Reading a line list out of a plugin content field (F-379).
//
// The viewer scrolls to whatever comes out of here, so a wrong number is not a cosmetic problem: it
// jumps to a place the note is not about. The negative cases matter more than the positive one — the
// input comes from a plugin, and a plugin is allowed to answer nonsense.

import XCTest
@testable import PCPluginHost

final class ContentFieldValuesTests: XCTestCase {

    func testTheShapeTheNotesPluginActuallyProduces() {
        // Measured against the built plugin (dlopen + ContentGetValue field 2), not assumed.
        XCTAssertEqual(ContentFieldValues.lineNumbers("3,12"), [3, 12])
        XCTAssertEqual(ContentFieldValues.lineNumbers("7"), [7])
    }

    func testSpacesAroundTheNumbersAreAllowed() {
        XCTAssertEqual(ContentFieldValues.lineNumbers("3, 12 ,  40"), [3, 12, 40])
    }

    func testNothingIsInventedFromRubbish() {
        XCTAssertEqual(ContentFieldValues.lineNumbers(""), [])
        XCTAssertEqual(ContentFieldValues.lineNumbers("soon"), [])
        XCTAssertEqual(ContentFieldValues.lineNumbers(",,,"), [])
        XCTAssertEqual(ContentFieldValues.lineNumbers("12abc"), [])
        // A partly readable answer keeps the readable part rather than being thrown away whole.
        XCTAssertEqual(ContentFieldValues.lineNumbers("3,,x,12"), [3, 12])
    }

    func testLinesAreOneBased() {
        // A 0 would address the line *above* the first one wherever this is used.
        XCTAssertEqual(ContentFieldValues.lineNumbers("0,1"), [1])
        XCTAssertEqual(ContentFieldValues.lineNumbers("-4"), [])
    }

    func testTheResultIsAscendingAndFreeOfDuplicates() {
        // The plugin sorts numerically today; the viewer must not depend on it continuing to.
        XCTAssertEqual(ContentFieldValues.lineNumbers("12,3,12,3"), [3, 12])
    }

    func testAVeryLargeLineNumberSurvives() {
        // 32-bit truncation would turn a line in a big log into a line near the top.
        XCTAssertEqual(ContentFieldValues.lineNumbers("3000000000"), [3_000_000_000])
    }
}
