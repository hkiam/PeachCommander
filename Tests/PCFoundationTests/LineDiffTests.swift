// Golden tests for the Myers line-diff engine (LineDiff).

import XCTest
@testable import PCFoundation

final class LineDiffTests: XCTestCase {

    // MARK: - Row builders (keep expected arrays readable)

    private func eq(_ l: Int, _ r: Int) -> DiffRow {
        DiffRow(op: .equal, leftIndex: l, rightIndex: r)
    }
    private func ins(_ r: Int) -> DiffRow {
        DiffRow(op: .insert, leftIndex: nil, rightIndex: r)
    }
    private func del(_ l: Int) -> DiffRow {
        DiffRow(op: .delete, leftIndex: l, rightIndex: nil)
    }
    private func chg(_ l: Int, _ r: Int) -> DiffRow {
        DiffRow(op: .change, leftIndex: l, rightIndex: r)
    }

    // MARK: - Line diff: structural cases

    func testIdenticalFiles() {
        let lines = ["alpha", "beta", "gamma"]
        let rows = LineDiff.compare(left: lines, right: lines)
        XCTAssertEqual(rows, [eq(0, 0), eq(1, 1), eq(2, 2)])
    }

    func testInsertAtEnd() {
        let rows = LineDiff.compare(left: ["a", "b"], right: ["a", "b", "c"])
        XCTAssertEqual(rows, [eq(0, 0), eq(1, 1), ins(2)])
    }

    func testInsertAtStart() {
        let rows = LineDiff.compare(left: ["b", "c"], right: ["a", "b", "c"])
        XCTAssertEqual(rows, [ins(0), eq(0, 1), eq(1, 2)])
    }

    func testInsertInMiddle() {
        let rows = LineDiff.compare(left: ["a", "c"], right: ["a", "b", "c"])
        XCTAssertEqual(rows, [eq(0, 0), ins(1), eq(1, 2)])
    }

    func testPureDelete() {
        let rows = LineDiff.compare(left: ["a", "b", "c"], right: ["a", "c"])
        XCTAssertEqual(rows, [eq(0, 0), del(1), eq(2, 1)])
    }

    func testSingleChange() {
        let rows = LineDiff.compare(left: ["a", "b", "c"], right: ["a", "B", "c"])
        XCTAssertEqual(rows, [eq(0, 0), chg(1, 1), eq(2, 2)])
    }

    func testMultipleChanges() {
        let rows = LineDiff.compare(left: ["a", "b", "c", "d"],
                                    right: ["A", "b", "C", "d"])
        XCTAssertEqual(rows, [chg(0, 0), eq(1, 1), chg(2, 2), eq(3, 3)])
    }

    // MARK: - Line diff: coalescing of adjacent delete/insert blocks

    func testAdjacentBlockCoalescedWithLeftoverInsert() {
        // 2 deletes then 3 inserts => 2 changes + 1 leftover insert.
        let rows = LineDiff.compare(left: ["a", "b", "c", "d"],
                                    right: ["a", "X", "Y", "Z", "d"])
        XCTAssertEqual(rows, [eq(0, 0), chg(1, 1), chg(2, 2), ins(3), eq(3, 4)])
    }

    func testAdjacentBlockCoalescedWithLeftoverDelete() {
        // 3 deletes then 1 insert => 1 change + 2 leftover deletes.
        let rows = LineDiff.compare(left: ["a", "b", "c", "d", "e"],
                                    right: ["a", "X", "e"])
        XCTAssertEqual(rows, [eq(0, 0), chg(1, 1), del(2), del(3), eq(4, 2)])
    }

    // MARK: - Line diff: normalization options

    func testIgnoreCaseOff() {
        let rows = LineDiff.compare(left: ["Hello"], right: ["hello"])
        XCTAssertEqual(rows, [chg(0, 0)])
    }

    func testIgnoreCaseOn() {
        let opts = DiffOptions(ignoreCase: true)
        let rows = LineDiff.compare(left: ["Hello"], right: ["hello"], options: opts)
        XCTAssertEqual(rows, [eq(0, 0)])
    }

    func testWhitespaceAll() {
        let opts = DiffOptions(whitespace: .all)
        let rows = LineDiff.compare(left: ["a b\tc"], right: ["abc"], options: opts)
        XCTAssertEqual(rows, [eq(0, 0)])
        // Without the option the lines differ.
        let strict = LineDiff.compare(left: ["a b\tc"], right: ["abc"])
        XCTAssertEqual(strict, [chg(0, 0)])
    }

    func testWhitespaceLeadingTrailing() {
        let opts = DiffOptions(whitespace: .leadingTrailing)
        // Interior whitespace is preserved; only the ends are trimmed.
        let rows = LineDiff.compare(left: ["   a b   "], right: ["a b"], options: opts)
        XCTAssertEqual(rows, [eq(0, 0)])
        // Interior difference still counts as a change.
        let changed = LineDiff.compare(left: ["  ab  "], right: ["a b"], options: opts)
        XCTAssertEqual(changed, [chg(0, 0)])
    }

    func testIgnoreLineEndings() {
        let opts = DiffOptions(ignoreLineEndings: true)
        let rows = LineDiff.compare(left: ["line\r"], right: ["line"], options: opts)
        XCTAssertEqual(rows, [eq(0, 0)])
        // Without the option the trailing carriage return makes them differ.
        let strict = LineDiff.compare(left: ["line\r"], right: ["line"])
        XCTAssertEqual(strict, [chg(0, 0)])
    }

    // MARK: - Line diff: unicode

    func testUnicodeLinesEqual() {
        // Combining acute vs precomposed: canonically equivalent, so equal.
        let rows = LineDiff.compare(left: ["cafe\u{301} \u{1F351}"],
                                    right: ["caf\u{e9} \u{1F351}"])
        XCTAssertEqual(rows, [eq(0, 0)])
    }

    func testUnicodeLinesChanged() {
        let rows = LineDiff.compare(left: ["\u{1F351} peach"],
                                    right: ["\u{1F34E} apple"])
        XCTAssertEqual(rows, [chg(0, 0)])
    }

    // MARK: - Line diff: large input

    func testHugeLineChange() {
        let left = [String(repeating: "a", count: 10_000)]
        let right = [String(repeating: "a", count: 9_999) + "b"]
        let rows = LineDiff.compare(left: left, right: right)
        XCTAssertEqual(rows, [chg(0, 0)])
    }

    // MARK: - Line diff: empty inputs

    func testEmptyLeft() {
        let rows = LineDiff.compare(left: [], right: ["a", "b"])
        XCTAssertEqual(rows, [ins(0), ins(1)])
    }

    func testEmptyRight() {
        let rows = LineDiff.compare(left: ["a", "b"], right: [])
        XCTAssertEqual(rows, [del(0), del(1)])
    }

    func testBothEmpty() {
        let rows = LineDiff.compare(left: [], right: [])
        XCTAssertEqual(rows, [])
    }

    // MARK: - Intra-line (character) diff

    func testIntraLineEqual() {
        let (l, r) = LineDiff.intraLine("hello", "hello")
        XCTAssertEqual(l, [])
        XCTAssertEqual(r, [])
    }

    func testIntraLinePrefixChange() {
        let (l, r) = LineDiff.intraLine("abc", "Xbc")
        XCTAssertEqual(l, [0..<1])
        XCTAssertEqual(r, [0..<1])
    }

    func testIntraLineSuffixChange() {
        let (l, r) = LineDiff.intraLine("abc", "abX")
        XCTAssertEqual(l, [2..<3])
        XCTAssertEqual(r, [2..<3])
    }

    func testIntraLineMiddleChange() {
        let (l, r) = LineDiff.intraLine("abc", "aXc")
        XCTAssertEqual(l, [1..<2])
        XCTAssertEqual(r, [1..<2])
    }

    func testIntraLineFullChange() {
        let (l, r) = LineDiff.intraLine("abc", "xyz")
        XCTAssertEqual(l, [0..<3])
        XCTAssertEqual(r, [0..<3])
    }

    func testIntraLineUnicodeGrapheme() {
        // "cafe" + combining acute forms a single grapheme cluster "é",
        // so only the final grapheme (index 3) differs from plain "cafe".
        let (l, r) = LineDiff.intraLine("cafe\u{301}", "cafe")
        XCTAssertEqual(l, [3..<4])
        XCTAssertEqual(r, [3..<4])
    }

    func testIntraLineMultipleDisjointRanges() {
        // Differences at both ends, with a matching middle "b".
        let (l, r) = LineDiff.intraLine("abc", "XbY")
        XCTAssertEqual(l, [0..<1, 2..<3])
        XCTAssertEqual(r, [0..<1, 2..<3])
    }
}
