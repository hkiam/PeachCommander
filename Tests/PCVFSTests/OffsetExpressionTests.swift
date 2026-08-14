// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCVFS

/// The arithmetic half of "Go to offset" (F-400). The single-number cases live in
/// HexAddressTests, which goes through the same evaluator and so pins that the feature
/// did not change what a bare number means.
final class OffsetExpressionTests: XCTestCase {

    func testTheExampleFromTheRequest() {
        // 0x1000 = 4096, and the two additions are the field offset and its length prefix.
        XCTAssertEqual(OffsetExpression.evaluate("0x1000 + 15 + 1"), 4112)
        XCTAssertEqual(OffsetExpression.evaluate("0x1000+15+1"), 4112)
    }

    func testBasesMixFreelyInOneExpression() {
        XCTAssertEqual(OffsetExpression.evaluate("0x100 + 16"), 272)
        XCTAssertEqual(OffsetExpression.evaluate("$ff + 1"), 256)
        XCTAssertEqual(OffsetExpression.evaluate("1000h - 0b1010"), 4086)
        XCTAssertEqual(OffsetExpression.evaluate("0o777 + 1"), 512)
        XCTAssertEqual(OffsetExpression.evaluate("0b1111 * 0x10"), 240)
    }

    func testPrecedenceAndParentheses() {
        XCTAssertEqual(OffsetExpression.evaluate("2 + 3 * 4"), 14)
        XCTAssertEqual(OffsetExpression.evaluate("(2 + 3) * 4"), 20)
        XCTAssertEqual(OffsetExpression.evaluate("0x1000 / 0x10"), 256)
        XCTAssertEqual(OffsetExpression.evaluate("((0x10))"), 16)
    }

    func testSubtractionIsLeftAssociativeAndMayDipBelowZeroOnTheWay() {
        // Right-associative would give 0x10 - (5 - 20 + 10) = 21.
        XCTAssertEqual(OffsetExpression.evaluate("0x10 - 5 - 20 + 10"), 1)
        XCTAssertEqual(OffsetExpression.evaluate("100 - 50 - 50"), 0)
    }

    func testUnderscoresGroupDigits() {
        XCTAssertEqual(OffsetExpression.evaluate("0x1000_0000"), 0x1000_0000)
        XCTAssertEqual(OffsetExpression.evaluate("1_000 + 1"), 1001)
    }

    func testAnHSuffixWinsOverABasePrefix() {
        // "0b1h" is the hex number 0xB1, not binary 1 with a stray h.
        XCTAssertEqual(OffsetExpression.evaluate("0b1h"), 0xB1)
    }

    /// A negative *result* is not an offset. Clamping it to 0 would look exactly like a
    /// deliberate jump to the start of the file, which is why this is a refusal.
    func testANegativeResultIsRefused() {
        XCTAssertNil(OffsetExpression.evaluate("10 - 20"))
        XCTAssertNil(OffsetExpression.evaluate("-5"))
        XCTAssertNil(OffsetExpression.evaluate("0 - 0x1"))
    }

    func testMalformedExpressions() {
        XCTAssertNil(OffsetExpression.evaluate(""))
        XCTAssertNil(OffsetExpression.evaluate("   "))
        XCTAssertNil(OffsetExpression.evaluate("+"))
        XCTAssertNil(OffsetExpression.evaluate("2 +"))
        XCTAssertNil(OffsetExpression.evaluate("2 3"))
        XCTAssertNil(OffsetExpression.evaluate("(2 + 3"))
        XCTAssertNil(OffsetExpression.evaluate("2 + 3)"))
        XCTAssertNil(OffsetExpression.evaluate("()"))
        XCTAssertNil(OffsetExpression.evaluate("0x10 ? 2"))
        XCTAssertNil(OffsetExpression.evaluate("16 MB"))
        XCTAssertNil(OffsetExpression.evaluate("_"))
    }

    func testDivisionByZeroIsRefusedRatherThanCrashing() {
        XCTAssertNil(OffsetExpression.evaluate("0x10 / 0"))
        XCTAssertNil(OffsetExpression.evaluate("1 / (2 - 2)"))
    }

    /// Int64 arithmetic traps on overflow, so every operator is checked: a hex dump of a
    /// large file is exactly where somebody types a big number twice.
    func testOverflowIsRefusedRatherThanTrapping() {
        XCTAssertNil(OffsetExpression.evaluate("0x7fffffffffffffff + 1"))
        XCTAssertNil(OffsetExpression.evaluate("0x7fffffffffffffff * 2"))
        XCTAssertNil(OffsetExpression.evaluate("0xffffffffffffffff"))   // does not fit Int64 at all
    }

    func testUnaryPlusAndRepeatedSigns() {
        XCTAssertEqual(OffsetExpression.evaluate("+0x10"), 16)
        XCTAssertEqual(OffsetExpression.evaluate("10 - -5"), 15)
        XCTAssertEqual(OffsetExpression.evaluate("10 + --5"), 15)
    }
}
