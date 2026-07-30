// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class ByteSearchTests: XCTestCase {
    func testParseHexCompactAndSpaced() {
        XCTAssertEqual(ByteSearch.parseHex("4865"), [0x48, 0x65])
        XCTAssertEqual(ByteSearch.parseHex("48 65 6c"), [0x48, 0x65, 0x6c])
        XCTAssertEqual(ByteSearch.parseHex(" ff  00 "), [0xff, 0x00])
    }

    func testParseHexInvalid() {
        XCTAssertNil(ByteSearch.parseHex(""))
        XCTAssertNil(ByteSearch.parseHex("4"))       // odd length
        XCTAssertNil(ByteSearch.parseHex("zz"))
        XCTAssertNil(ByteSearch.parseHex("48 6"))    // odd after compaction
    }

    func testFirstIndex() {
        let bytes: [UInt8] = [1, 2, 3, 2, 3, 4]
        XCTAssertEqual(ByteSearch.firstIndex(of: [2, 3], in: bytes), 1)
        XCTAssertEqual(ByteSearch.firstIndex(of: [2, 3], in: bytes, from: 2), 3)
        XCTAssertNil(ByteSearch.firstIndex(of: [9], in: bytes))
        XCTAssertNil(ByteSearch.firstIndex(of: [], in: bytes))
    }

    func testAllIndicesNonOverlapping() {
        XCTAssertEqual(ByteSearch.allIndices(of: [0xAA, 0xAA], in: [0xAA, 0xAA, 0xAA, 0xAA]), [0, 2])
        XCTAssertEqual(ByteSearch.allIndices(of: [1], in: [1, 2, 1, 1]), [0, 2, 3])
    }
}
