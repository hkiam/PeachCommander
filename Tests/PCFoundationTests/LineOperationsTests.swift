// SPDX-License-Identifier: Apache-2.0
// LineOperationsTests.swift - Sorting, deduplicating, filtering and trimming lines (F-359).
//
// The two invariants that fail silently — the file's line terminator and whether it ended with one —
// are asserted for every operation, not only for the one where they were first noticed.

import XCTest
@testable import PCFoundation

final class LineOperationsTests: XCTestCase {

    func testSortIsAlphabeticalAndCaseInsensitive() {
        XCTAssertEqual(LineOperations.apply(.sort(ascending: true), to: "beta\nAlpha\ngamma\n"),
                       "Alpha\nbeta\ngamma\n")
    }

    func testSortDescending() {
        XCTAssertEqual(LineOperations.apply(.sort(ascending: false), to: "a\nc\nb\n"), "c\nb\na\n")
    }

    func testSortComparesNumbersByValue() {
        // What a person means by sorted: file9 before file10. Plain string order gives the opposite.
        XCTAssertEqual(LineOperations.apply(.sort(ascending: true), to: "file10\nfile9\nfile1\n"),
                       "file1\nfile9\nfile10\n")
    }

    func testUniqueKeepsTheFirstOccurrenceAndTheOrder() {
        // Not sort|uniq: deduplicating must not also reorder, or it cannot be used on a log.
        XCTAssertEqual(LineOperations.apply(.unique, to: "b\na\nb\nc\na\n"), "b\na\nc\n")
    }

    func testReverse() {
        XCTAssertEqual(LineOperations.apply(.reverse, to: "1\n2\n3\n"), "3\n2\n1\n")
    }

    func testFilterKeepsMatchingLines() {
        XCTAssertEqual(LineOperations.apply(.filter(needle: "error", keep: true, caseSensitive: true),
                                           to: "ok\nerror: x\nok\nerror: y\n"),
                       "error: x\nerror: y\n")
    }

    func testFilterCanDropMatchingLinesInstead() {
        XCTAssertEqual(LineOperations.apply(.filter(needle: "#", keep: false, caseSensitive: true),
                                           to: "# comment\nkey=1\n# another\n"),
                       "key=1\n")
    }

    func testFilterCanIgnoreCase() {
        XCTAssertEqual(LineOperations.apply(.filter(needle: "ERROR", keep: true, caseSensitive: false),
                                           to: "Error: x\nfine\n"),
                       "Error: x\n")
    }

    func testAnEmptyNeedleFiltersNothingAway() {
        // Otherwise an accidental empty input would delete the file's contents.
        let text = "a\nb\n"
        XCTAssertEqual(LineOperations.apply(.filter(needle: "", keep: true, caseSensitive: true),
                                           to: text), text)
    }

    func testTrailingWhitespaceGoesAndIndentationStays() {
        XCTAssertEqual(LineOperations.apply(.trimTrailingWhitespace, to: "    indented   \n\tcode\t\n"),
                       "    indented\n\tcode\n")
    }

    func testBlankAndWhitespaceOnlyLinesAreRemoved() {
        XCTAssertEqual(LineOperations.apply(.removeBlankLines, to: "a\n\n   \n\t\nb\n"), "a\nb\n")
    }

    // MARK: - The invariants

    func testCRLFSurvivesEveryOperation() {
        let windows = "beta\r\nalpha\r\nbeta\r\n"
        for op: LineOperation in [.sort(ascending: true), .unique, .reverse,
                                 .trimTrailingWhitespace, .removeBlankLines,
                                 .filter(needle: "a", keep: true, caseSensitive: true)] {
            let result = LineOperations.apply(op, to: windows)
            XCTAssertFalse(result.contains("\n\n"), "\(op) produced a stray terminator")
            let survey = LineEndings.survey(result)
            XCTAssertEqual(survey.dominant, .crlf, "\(op) lost the CRLF terminators")
            XCTAssertFalse(survey.isMixed, "\(op) left mixed terminators behind")
        }
    }

    func testAMissingFinalNewlineStaysMissing() {
        XCTAssertEqual(LineOperations.apply(.sort(ascending: true), to: "b\na"), "a\nb")
        XCTAssertEqual(LineOperations.apply(.sort(ascending: true), to: "b\na\n"), "a\nb\n")
    }

    func testATrailingTerminatorIsNotSortedIntoTheMiddle() {
        // The bug this guards: `components(separatedBy:)` yields a trailing empty element, and sorting
        // it puts a blank line at the top of the file.
        XCTAssertEqual(LineOperations.apply(.sort(ascending: true), to: "b\na\n"), "a\nb\n")
    }

    func testEmptyTextIsUntouched() {
        XCTAssertEqual(LineOperations.apply(.unique, to: ""), "")
    }

    func testMixedTerminatorsBecomeConsistent() {
        // Mixed input is the mess the user is fixing; keeping each line's own terminator would preserve
        // it. The dominant one wins.
        let result = LineOperations.apply(.sort(ascending: true), to: "b\r\na\nc\r\n")
        XCTAssertFalse(LineEndings.survey(result).isMixed)
        XCTAssertEqual(result, "a\r\nb\r\nc\r\n")
    }
}
