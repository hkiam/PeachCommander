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
}
