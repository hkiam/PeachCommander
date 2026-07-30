// SPDX-License-Identifier: Apache-2.0
// TextScanningTests.swift - Unit tests for BracketMatcher and IdentifierScanner.

import XCTest
@testable import PCFoundation

final class TextScanningTests: XCTestCase {
    // MARK: BracketMatcher

    func test_bracket_openForward() {
        let s = "a(b[c]d)e" as NSString   // ( at 1, ) at 7
        let m = BracketMatcher.match(in: s, caret: 2)   // caret just after '('
        XCTAssertEqual(m?.bracket.location, 1)
        XCTAssertEqual(m?.partner.location, 7)
    }

    func test_bracket_closeBackward() {
        let s = "{x}" as NSString          // } at 2, { at 0
        let m = BracketMatcher.match(in: s, caret: 3)   // caret just after '}'
        XCTAssertEqual(m?.bracket.location, 2)
        XCTAssertEqual(m?.partner.location, 0)
    }

    func test_bracket_nestedDifferentTypes() {
        let s = "([])" as NSString         // [ at 1, ] at 2
        let m = BracketMatcher.match(in: s, caret: 2)   // caret just after '['
        XCTAssertEqual(m?.bracket.location, 1)
        XCTAssertEqual(m?.partner.location, 2)
    }

    func test_bracket_noneWhenNotAdjacent() {
        XCTAssertNil(BracketMatcher.match(in: "abc" as NSString, caret: 1))
    }

    func test_bracket_unbalancedReturnsNil() {
        XCTAssertNil(BracketMatcher.match(in: "(a" as NSString, caret: 1))
    }

    // MARK: IdentifierScanner

    func test_identifier_insideWord() {
        let s = "foo.barBaz(x)" as NSString
        XCTAssertEqual(IdentifierScanner.word(in: s, at: 5), "barBaz")
        XCTAssertEqual(IdentifierScanner.word(in: s, at: 1), "foo")
    }

    func test_identifier_pastWordStepsBack() {
        XCTAssertEqual(IdentifierScanner.word(in: "abc()" as NSString, at: 3), "abc")
    }

    func test_identifier_onOperatorReturnsNil() {
        XCTAssertNil(IdentifierScanner.word(in: "a + b" as NSString, at: 2))
    }

    func test_identifier_underscoreAndDigits() {
        XCTAssertEqual(IdentifierScanner.word(in: "my_var2 = 1" as NSString, at: 0), "my_var2")
    }
}
