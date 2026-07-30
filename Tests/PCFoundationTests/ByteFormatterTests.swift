// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class ByteFormatterTests: XCTestCase {
    private let hi: [UInt8] = [0x48, 0x69]   // "Hi"

    func testText() {
        XCTAssertEqual(ByteFormatter.format(hi, as: .text), "Hi")
        XCTAssertEqual(ByteFormatter.format([], as: .text), "")
    }

    func testHex() {
        XCTAssertEqual(ByteFormatter.format(hi, as: .hex), "48 69")
        XCTAssertEqual(ByteFormatter.format([0x00, 0xFF, 0x0A], as: .hex), "00 FF 0A")
    }

    func testCArray() {
        XCTAssertEqual(ByteFormatter.format(hi, as: .cArray), "{ 0x48, 0x69 }")
        XCTAssertEqual(ByteFormatter.format([], as: .cArray), "{  }")
    }

    func testPythonBytes() {
        XCTAssertEqual(ByteFormatter.format(hi, as: .pythonBytes), "b'\\x48\\x69'")
    }

    func testBase64() {
        XCTAssertEqual(ByteFormatter.format(hi, as: .base64), "SGk=")
        XCTAssertEqual(ByteFormatter.format(Array("Man".utf8), as: .base64), "TWFu")
    }

    func testTextWithNonUTF8FallsBackLossy() {
        // 0xFF is not valid standalone UTF-8; decoding must not crash or return nil-equivalent.
        let s = ByteFormatter.format([0xFF, 0x41], as: .text)
        XCTAssertFalse(s.isEmpty)
    }

    func testAllFormatsHaveLabels() {
        for f in ByteFormat.allCases { XCTAssertFalse(f.label.isEmpty) }
    }
}
