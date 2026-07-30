// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCVFS

final class TextEncodingChoiceTests: XCTestCase {
    func testAllHaveUniqueNames() {
        let names = TextEncodingChoice.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertFalse(names.isEmpty)
    }

    func testEncodingsDecodeAscii() {
        // Every listed encoding is an ASCII superset, so "Hi" round-trips.
        for choice in TextEncodingChoice.allCases {
            let data = "Hi".data(using: choice.encoding)
            XCTAssertNotNil(data, "\(choice.displayName) should encode ASCII")
        }
    }

    func testRoundTripFromEncoding() {
        XCTAssertEqual(TextEncodingChoice.from(.utf8), .utf8)
        XCTAssertEqual(TextEncodingChoice.from(.isoLatin1), .isoLatin1)
        XCTAssertEqual(TextEncodingChoice.from(.macOSRoman), .macRoman)
    }

    func testWindows1252DecodesHighBytes() {
        // 0x80 is the euro sign in Windows-1252 but undefined in ISO-8859-1.
        let bytes = Data([0x80])
        XCTAssertEqual(String(data: bytes, encoding: TextEncodingChoice.windows1252.encoding), "\u{20AC}")
    }
}
