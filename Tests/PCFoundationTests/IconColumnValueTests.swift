// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class IconColumnValueTests: XCTestCase {
    func testSplitsTheSymbolFromTheWords() {
        let (symbol, text) = IconColumnValue.split("pencil.circle.fill\tModified")
        XCTAssertEqual(symbol, "pencil.circle.fill")
        XCTAssertEqual(text, "Modified")
    }

    /// What a plugin sends for a row it has no icon for — and what every non-icon field's value looks like.
    func testAValueWithoutATabIsTextThroughout() {
        let (symbol, text) = IconColumnValue.split("Modified (staged)")
        XCTAssertNil(symbol)
        XCTAssertEqual(text, "Modified (staged)")
        XCTAssertEqual(IconColumnValue.split("").text, "")
    }

    func testAnEmptySymbolFieldMeansNoIcon() {
        let (symbol, text) = IconColumnValue.split("\tUnchanged")
        XCTAssertNil(symbol, "an empty name is not a symbol")
        XCTAssertEqual(text, "Unchanged")
    }

    /// Only the first tab separates: the text may contain one, and cutting at the last would move part of
    /// the words into the symbol name.
    func testOnlyTheFirstTabSeparates() {
        let (symbol, text) = IconColumnValue.split("star\tone\ttwo")
        XCTAssertEqual(symbol, "star")
        XCTAssertEqual(text, "one\ttwo")
    }
}
