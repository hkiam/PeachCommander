// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCVFS

final class HexAddressTests: XCTestCase {
    func testDecimal() {
        XCTAssertEqual(HexAddress.parse("26"), 26)
        XCTAssertEqual(HexAddress.parse("  0 "), 0)
        XCTAssertEqual(HexAddress.parse("1048576"), 1_048_576)
    }

    func testHexPrefixes() {
        XCTAssertEqual(HexAddress.parse("0x1A"), 26)
        XCTAssertEqual(HexAddress.parse("0X1a"), 26)
        XCTAssertEqual(HexAddress.parse("$ff"), 255)
        XCTAssertEqual(HexAddress.parse("1Ah"), 26)
        XCTAssertEqual(HexAddress.parse("DEADh"), 0xDEAD)
    }

    func testInvalid() {
        XCTAssertNil(HexAddress.parse(""))
        XCTAssertNil(HexAddress.parse("   "))
        XCTAssertNil(HexAddress.parse("xyz"))
        XCTAssertNil(HexAddress.parse("-5"))
        XCTAssertNil(HexAddress.parse("0x"))
        XCTAssertNil(HexAddress.parse("12g"))
        XCTAssertNil(HexAddress.parse("0xGG"))
    }
}
