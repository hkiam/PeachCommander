// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCVFS

final class HexFormatterTests: XCTestCase {
    func testDefault16BytesPerRow() {
        let bytes: [UInt8] = Array(0x41...0x50)   // 'A'..'P', 16 bytes
        let row = HexFormatter.row(bytes: bytes, offset: 0)
        XCTAssertEqual(row,
            "00000000  41 42 43 44 45 46 47 48 49 4a 4b 4c 4d 4e 4f 50  ABCDEFGHIJKLMNOP")
    }

    func testConfigurableWidth8() {
        // F-111: an 8-byte line width groups 8 hex columns + an 8-char ASCII gutter.
        let bytes: [UInt8] = Array(0x41...0x48)   // 'A'..'H'
        let row = HexFormatter.row(bytes: bytes, offset: 8, bytesPerRow: 8)
        XCTAssertEqual(row, "00000008  41 42 43 44 45 46 47 48  ABCDEFGH")
    }

    func testConfigurableWidth32PadsShortTail() {
        // A partial final row keeps alignment: missing columns are blanked.
        let bytes: [UInt8] = [0x41, 0x42]   // only 2 of 32
        let row = HexFormatter.row(bytes: bytes, offset: 0, bytesPerRow: 32)
        XCTAssertTrue(row.hasPrefix("00000000  41 42 "))
        // 32 hex columns * 3 chars - 1 trailing = 95 chars in the hex field.
        // Verify overall length is stable regardless of how many bytes are present.
        let full = HexFormatter.row(bytes: Array(repeating: 0, count: 32), offset: 0, bytesPerRow: 32)
        XCTAssertEqual(row.count, full.count)
    }

    // MARK: - The layout the views map the pointer through (F-489 follow-up)
    //
    // These hold `RowLayout` against what `row` actually renders. That is the whole point of the
    // type: the hex-mode viewer used to compute its column positions itself, that copy covered the
    // hex columns only, and the ASCII gutter could not be selected — silently, because a row that
    // is drawn correctly looks correct however the pointer is mapped.

    /// Read the characters `layout` claims are at a column, out of the row it claims them for.
    private func text(_ row: String, at column: Int, length: Int) -> String {
        let start = row.index(row.startIndex, offsetBy: column)
        return String(row[start..<row.index(start, offsetBy: length)])
    }

    func testLayoutPointsAtTheHexPairsThatWereRendered() {
        let bytes: [UInt8] = Array(0x41...0x50)
        let row = HexFormatter.row(bytes: bytes, offset: 0)
        let layout = HexFormatter.layout(offset: 0)
        for i in 0..<16 {
            XCTAssertEqual(text(row, at: layout.hexColumn(forByte: i), length: 2),
                           String(format: "%02x", bytes[i]), "hex column \(i)")
        }
    }

    func testLayoutPointsAtTheGutterCharactersThatWereRendered() {
        let bytes: [UInt8] = Array(0x41...0x50)
        let row = HexFormatter.row(bytes: bytes, offset: 0)
        let layout = HexFormatter.layout(offset: 0)
        for i in 0..<16 {
            XCTAssertEqual(text(row, at: layout.asciiColumn(forByte: i), length: 1),
                           String(UnicodeScalar(bytes[i])), "gutter column \(i)")
        }
    }

    func testLayoutFollowsANarrowerRow() {
        let bytes: [UInt8] = Array(0x41...0x48)
        let row = HexFormatter.row(bytes: bytes, offset: 8, bytesPerRow: 8)
        let layout = HexFormatter.layout(offset: 8, bytesPerRow: 8)
        XCTAssertEqual(text(row, at: layout.hexColumn(forByte: 0), length: 2), "41")
        XCTAssertEqual(text(row, at: layout.asciiColumn(forByte: 0), length: 1), "A")
        XCTAssertEqual(text(row, at: layout.asciiColumn(forByte: 7), length: 1), "H")
    }

    func testLayoutFollowsAnOffsetWiderThanEightDigits() {
        // Past 4 GB the offset field grows, and every column after it moves with it.
        let offset: Int64 = 0x1_0000_0000
        let bytes: [UInt8] = Array(0x41...0x50)
        let row = HexFormatter.row(bytes: bytes, offset: offset)
        let layout = HexFormatter.layout(offset: offset)
        XCTAssertEqual(layout.offsetDigits, 9)
        XCTAssertEqual(text(row, at: layout.hexColumn(forByte: 0), length: 2), "41")
        XCTAssertEqual(text(row, at: layout.asciiColumn(forByte: 15), length: 1), "P")
    }

    func testTheGutterStartsWhereTheHexColumnsEnd() {
        // The two spaces between the halves belong to neither, and a view that puts the gutter one
        // character out maps every click in it to the wrong byte.
        let layout = HexFormatter.layout(offset: 0)
        XCTAssertEqual(layout.hexColumn, 10)
        XCTAssertEqual(layout.asciiColumn, 10 + 16 * 3 + 1)
        let row = HexFormatter.row(bytes: Array(0x41...0x50), offset: 0)
        XCTAssertEqual(text(row, at: layout.asciiColumn - 2, length: 2), "  ")
    }
}
