// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class ByteSizeParseTests: XCTestCase {
    func testPlainBytes() {
        XCTAssertEqual(ByteSize.parse("700"), 700)
        XCTAssertEqual(ByteSize.parse("0"), 0)
    }
    func testBinaryUnits() {
        XCTAssertEqual(ByteSize.parse("1K"), 1024)
        XCTAssertEqual(ByteSize.parse("10M"), 10 * 1024 * 1024)
        XCTAssertEqual(ByteSize.parse("2G"), 2 * 1024 * 1024 * 1024)
        XCTAssertEqual(ByteSize.parse("1.5M"), Int64(1.5 * 1024 * 1024))
    }
    func testUnitSuffixVariants() {
        XCTAssertEqual(ByteSize.parse("500MB"), 500 * 1024 * 1024)
        XCTAssertEqual(ByteSize.parse(" 700 m "), 700 * 1024 * 1024)
        XCTAssertEqual(ByteSize.parse("100b"), 100)
    }
    func testInvalid() {
        XCTAssertNil(ByteSize.parse(""))
        XCTAssertNil(ByteSize.parse("abc"))
        XCTAssertNil(ByteSize.parse("-5M"))
    }
}
