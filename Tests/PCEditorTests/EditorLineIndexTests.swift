// SPDX-License-Identifier: Apache-2.0
// EditorLineIndexTests.swift - The line index behind the editor's gutter (F-355).
//
// The gutter's job is to agree with "go to line 42" and with every compiler message, so the interesting
// cases are the ones where counting is easy to get wrong: the last line without a newline, a trailing
// newline, CRLF, and text where a byte offset and a UTF-16 offset part ways.

import XCTest
@testable import PCFoundation

final class EditorLineIndexTests: XCTestCase {

    func testEmptyTextIsOneLine() {
        XCTAssertEqual(EditorLineIndex(text: "").count, 1)
        XCTAssertEqual(EditorLineIndex(text: "").line(containing: 0), 1)
    }

    func testLinesAreCountedWithoutATrailingNewline() {
        let index = EditorLineIndex(text: "a\nb\nc")
        XCTAssertEqual(index.count, 3)
        XCTAssertEqual(index.line(containing: 0), 1)
        XCTAssertEqual(index.line(containing: 2), 2)
        XCTAssertEqual(index.line(containing: 4), 3)
    }

    func testATrailingNewlineDoesNotInventAnExtraLine() {
        // A file ending in "\n" has three lines, not four — which is what wc -l and every editor agree
        // on, and what "go to line 3" must mean.
        XCTAssertEqual(EditorLineIndex(text: "a\nb\nc\n").count, 3)
    }

    func testCRLFCountsAsOneSeparator() {
        let index = EditorLineIndex(text: "a\r\nb\r\nc")
        XCTAssertEqual(index.count, 3)
        // "a\r\n" is three UTF-16 units, so line 2 begins at 3.
        XCTAssertEqual(index.line(containing: 3), 2)
    }

    func testLoneCarriageReturnIsAlsoASeparator() {
        XCTAssertEqual(EditorLineIndex(text: "a\rb\rc").count, 3)
    }

    func testOffsetsAreUTF16NotBytes() {
        // The reason this index exists rather than reusing PCVFS's byte-based LineIndexer: "ä" is two
        // bytes and one UTF-16 unit, so a byte offset would put the second line in the wrong place.
        let index = EditorLineIndex(text: "ä\nb")
        XCTAssertEqual(index.count, 2)
        XCTAssertEqual(index.line(containing: 1), 1, "the newline still belongs to line 1")
        XCTAssertEqual(index.line(containing: 2), 2)
    }

    func testAnOffsetPastTheEndClampsToTheLastLine() {
        // The caret may sit one past the last character; the gutter must still highlight a line.
        let index = EditorLineIndex(text: "a\nb")
        XCTAssertEqual(index.line(containing: 999), 2)
    }

    func testRebuildReplacesTheWholeIndex() {
        var index = EditorLineIndex(text: "a\nb\nc")
        index.rebuild(from: "only one line")
        XCTAssertEqual(index.count, 1)
    }
}

private extension EditorLineIndex {
    init(text: String) { self.init(text: text as NSString) }
}
