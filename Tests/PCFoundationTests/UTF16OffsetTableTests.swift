// SPDX-License-Identifier: Apache-2.0
// UTF16OffsetTableTests.swift - Grapheme index → UTF-16 offset, and why it is a table (F-414).
//
// The mapping used to be written inline as `String(chars[0..<i]).utf16.count`, which copies everything
// before the position every time it is asked. The viewer's code view asks once per syntax token while
// *drawing*, so a file with very long lines froze the window: measured at 193,934 ms to build thirty lines
// of a real 2 MB JSON Lines log, against 126 ms with the table. Both properties are tested here — that the
// answers are identical to the naive computation, including for characters that are not one UTF-16 unit,
// and that the cost is linear rather than quadratic.

import XCTest
@testable import PCFoundation

final class UTF16OffsetTableTests: XCTestCase {

    /// The naive version this replaced, kept as the oracle.
    private func naiveOffset(_ characters: [Character], _ index: Int) -> Int {
        String(characters[0..<index]).utf16.count
    }

    private func assertMatchesNaive(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let characters = Array(text)
        let table = UTF16OffsetTable(characters)
        for index in 0...characters.count {
            XCTAssertEqual(table.offset(at: index), naiveOffset(characters, index),
                           "offset at \(index) of \(text.debugDescription)", file: file, line: line)
        }
    }

    func testASCII() { assertMatchesNaive("let x = 42  // plain") }

    func testEmpty() {
        let table = UTF16OffsetTable([])
        XCTAssertEqual(table.offset(at: 0), 0)
        XCTAssertEqual(table.range(0, 0), NSRange(location: 0, length: 0))
    }

    /// Characters outside the BMP are two UTF-16 units, which is the case the index-equals-offset
    /// shortcut must not be taken for.
    func testAstralCharacters() { assertMatchesNaive("a🐈b🇩🇪c") }

    /// A grapheme cluster can be many units: a family emoji, a flag, a combining sequence.
    func testCombiningSequences() { assertMatchesNaive("e\u{0301}xposé 👩‍👩‍👧‍👦 end") }

    func testGermanAndCJK() { assertMatchesNaive("Größe 大きさ ok") }

    func testRangeMapping() {
        let characters = Array("a🐈bc")
        let table = UTF16OffsetTable(characters)
        XCTAssertEqual(table.range(0, 1), NSRange(location: 0, length: 1))    // "a"
        XCTAssertEqual(table.range(1, 2), NSRange(location: 1, length: 2))    // the cat, two units
        XCTAssertEqual(table.range(2, 4), NSRange(location: 3, length: 2))    // "bc"
    }

    /// A range that has drifted past the end must clamp rather than produce an NSRange outside the string:
    /// the callers are drawing code, and an out-of-range attribute range is a crash.
    func testOutOfRangeClamps() {
        let table = UTF16OffsetTable(Array("abc"))
        XCTAssertEqual(table.offset(at: 99), 3)
        XCTAssertEqual(table.offset(at: -5), 0)
        XCTAssertEqual(table.range(2, 99), NSRange(location: 2, length: 1))
        XCTAssertEqual(table.range(5, 1), NSRange(location: 3, length: 0))
    }

    /// The property that fixes the freeze: asking for many offsets on a long line costs one pass, not one
    /// per question. Generous bound — this runs in a debug build on shared CI hardware; the naive version
    /// needs ~200 seconds for the same work, so anything in the same order as the limit still catches a
    /// return to quadratic behaviour.
    func testManyLookupsOnALongLineAreLinear() {
        let line = Array(String(repeating: "{\"key\":\"value\"},", count: 4_000))   // ~64k characters
        let table = UTF16OffsetTable(line)
        let start = Date()
        var total = 0
        for index in stride(from: 0, to: line.count, by: 16) { total += table.offset(at: index) }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(total, 0)
        XCTAssertLessThan(elapsed, 1.0, "4,000 lookups over a 64k line took \(elapsed) s")
    }

    /// And the same for the non-ASCII path, which does allocate the table.
    func testTheTablePathIsAlsoLinear() {
        let line = Array(String(repeating: "Größe 🐈 ", count: 8_000))
        let table = UTF16OffsetTable(line)
        let start = Date()
        var total = 0
        for index in stride(from: 0, to: line.count, by: 8) { total += table.offset(at: index) }
        XCTAssertGreaterThan(total, 0)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.0)
    }
}
