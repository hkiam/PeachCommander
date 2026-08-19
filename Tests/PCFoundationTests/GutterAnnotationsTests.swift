// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class GutterAnnotationsTests: XCTestCase {
    func testParsesTextAndTooltip() {
        let parsed = GutterAnnotations.parse("a1b2c3 Maik\tadds the parser\nffffff Ada\tfirst commit\n")
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].text, "a1b2c3 Maik")
        XCTAssertEqual(parsed[0].tooltip, "adds the parser")
        XCTAssertEqual(parsed[1].tooltip, "first commit")
    }

    func testARecordWithoutTextLeavesTheLineBlank() {
        let parsed = GutterAnnotations.parse("first\n\nthird\n")
        XCTAssertEqual(parsed.count, 3)
        XCTAssertTrue(parsed[1].isEmpty)
        XCTAssertNil(GutterAnnotations.annotation(parsed, line: 2))
        XCTAssertEqual(GutterAnnotations.annotation(parsed, line: 3)?.text, "third")
        XCTAssertNil(GutterAnnotations.annotation(parsed, line: 4), "past the end is not an error")
        XCTAssertNil(GutterAnnotations.annotation(parsed, line: 0), "lines are 1-based")
    }

    /// Only the *first* tab separates: cutting at the last one moves part of the tooltip into the column
    /// the gutter draws.
    func testATooltipMayContainTabs() {
        let parsed = GutterAnnotations.parse("hash\tsubject\twith a tab")
        XCTAssertEqual(parsed[0].text, "hash")
        XCTAssertEqual(parsed[0].tooltip, "subject\twith a tab")
    }

    /// `"\r\n"` is a single Character in Swift, so a plugin that built its buffer with Windows line
    /// endings would otherwise arrive as one enormous annotation (F-257).
    func testCRLFBufferIsSplitPerLine() {
        let parsed = GutterAnnotations.parse("one\ttip\r\ntwo\ttip\r\n")
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].text, "one")
        XCTAssertEqual(parsed[1].text, "two")
    }

    func testEmptyAndOversizedBuffers() {
        XCTAssertEqual(GutterAnnotations.parse(""), [])
        let many = String(repeating: "x\n", count: GutterAnnotations.lineLimit + 500)
        XCTAssertEqual(GutterAnnotations.parse(many).count, GutterAnnotations.lineLimit,
                       "a buffer for a file nobody reads line by line is cut, not allocated")
    }

    /// Measured on the widest annotation, and capped, so one pathological line cannot push the text out of
    /// the window.
    func testColumnWidthIsMeasuredAndCapped() {
        let parsed = GutterAnnotations.parse("short\nmuch much longer\n")
        let width = GutterAnnotations.columnWidth(parsed, measure: { CGFloat($0.count) * 7 }, cap: 260)
        XCTAssertEqual(width, CGFloat("much much longer".count) * 7)
        XCTAssertEqual(GutterAnnotations.columnWidth(parsed, measure: { _ in 4000 }, cap: 260), 260)
        XCTAssertEqual(GutterAnnotations.columnWidth([], measure: { _ in 100 }), 0)
    }
}
