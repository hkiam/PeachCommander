// SPDX-License-Identifier: Apache-2.0
// LineEndingsTests.swift - Detecting and converting line terminators (F-358).

import XCTest
@testable import PCFoundation

final class LineEndingsTests: XCTestCase {

    func testUnixTextIsLF() {
        let survey = LineEndings.survey("a\nb\nc\n")
        XCTAssertEqual(survey, LineEndingSurvey(lf: 3, crlf: 0, cr: 0))
        XCTAssertEqual(survey.dominant, .lf)
        XCTAssertFalse(survey.isMixed)
    }

    func testACRLFCountsOnceAndNotAsACRPlusAnLF() {
        // The mistake this guards: reporting "mixed" for an ordinary Windows file, which would send
        // the user converting something that is already consistent.
        let survey = LineEndings.survey("a\r\nb\r\n")
        XCTAssertEqual(survey, LineEndingSurvey(lf: 0, crlf: 2, cr: 0))
        XCTAssertEqual(survey.displayName, "CRLF")
        XCTAssertFalse(survey.isMixed)
    }

    func testClassicMacTextIsCR() {
        let survey = LineEndings.survey("a\rb\rc")
        XCTAssertEqual(survey, LineEndingSurvey(lf: 0, crlf: 0, cr: 2))
        XCTAssertEqual(survey.dominant, .cr)
    }

    func testMixedTextIsReportedAsMixed() {
        let survey = LineEndings.survey("a\nb\r\nc\n")
        XCTAssertTrue(survey.isMixed)
        XCTAssertEqual(survey.dominant, .lf)          // two LF against one CRLF
        XCTAssertEqual(survey.displayName, "LF (mixed)")
    }

    func testATrailingCarriageReturnCountsAsACR() {
        XCTAssertEqual(LineEndings.survey("a\r"), LineEndingSurvey(lf: 0, crlf: 0, cr: 1))
    }

    func testASingleLineHasNoTerminatorToReport() {
        XCTAssertTrue(LineEndings.survey("just one line").isEmpty)
        XCTAssertTrue(LineEndings.survey("").isEmpty)
    }

    func testConversionToCRLFAndBack() {
        let unix = "a\nb\nc\n"
        let windows = LineEndings.convert(unix, to: .crlf)
        XCTAssertEqual(windows, "a\r\nb\r\nc\r\n")
        XCTAssertEqual(LineEndings.convert(windows, to: .lf), unix)
    }

    func testConvertingMixedTextMakesItConsistent() {
        // The reason conversion goes via LF: every pairing rule stated once.
        let converted = LineEndings.convert("a\nb\r\nc\rd", to: .crlf)
        XCTAssertEqual(converted, "a\r\nb\r\nc\r\nd")
        XCTAssertFalse(LineEndings.survey(converted).isMixed)
    }

    func testConvertingToCRLFTwiceChangesNothingTheSecondTime() {
        let once = LineEndings.convert("a\nb\n", to: .crlf)
        XCTAssertEqual(LineEndings.convert(once, to: .crlf), once)
    }

    func testTextWithoutTerminatorsIsUnchangedByConversion() {
        XCTAssertEqual(LineEndings.convert("one line", to: .crlf), "one line")
    }
}

extension LineEndingsTests {

    func testLineCountOnUnixText() {
        XCTAssertEqual(LineEndings.lineCount("a\nb\nc\n"), 3)
        XCTAssertEqual(LineEndings.lineCount("a\nb\nc"), 3)
    }

    func testLineCountOnCRLFText() {
        // The bug this exists for: "\r\n" is a single Swift Character, so split(separator: "\n") does
        // not match it and reports 1 for any Windows file. The editor said "1 line(s)" after sorting a
        // four-line file, and only the end-to-end run in the VM showed it.
        XCTAssertEqual(LineEndings.lineCount("a\r\nb\r\nc\r\n"), 3)
        XCTAssertEqual(LineEndings.lineCount("a\r\nb\r\nc"), 3)
    }

    func testLineCountOnClassicMacText() {
        XCTAssertEqual(LineEndings.lineCount("a\rb\rc\r"), 3)
    }

    func testLineCountOfEmptyAndSingleLineText() {
        XCTAssertEqual(LineEndings.lineCount(""), 0)
        XCTAssertEqual(LineEndings.lineCount("one"), 1)
        XCTAssertEqual(LineEndings.lineCount("\n"), 1)
    }

    func testLineCountAgreesWithWCOnMixedText() {
        // wc -l counts terminators; a file whose last line has none still shows that line in an editor,
        // so it counts here.
        XCTAssertEqual(LineEndings.lineCount("a\nb\r\nc\rd"), 4)
    }
}
