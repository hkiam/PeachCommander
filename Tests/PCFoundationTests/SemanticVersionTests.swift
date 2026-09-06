// SPDX-License-Identifier: Apache-2.0
// SemanticVersionTests.swift - Parsing and ordering of major.minor.patch (F-482).

import XCTest
@testable import PCFoundation

final class SemanticVersionTests: XCTestCase {
    func test_parsesOneTwoOrThreeComponents() {
        XCTAssertEqual(SemanticVersion("1"), SemanticVersion(1, 0, 0))
        XCTAssertEqual(SemanticVersion("1.2"), SemanticVersion(1, 2, 0))
        XCTAssertEqual(SemanticVersion("1.2.3"), SemanticVersion(1, 2, 3))
        XCTAssertEqual(SemanticVersion(" 0.8.2 "), SemanticVersion(0, 8, 2))
    }

    /// Anything not understood is nil, never 0.0.0.
    ///
    /// 0.0.0 sorts below every real version, so a typo would read as "older than what is
    /// installed" and turn a mistyped upgrade into a silent downgrade.
    func test_refusesWhatItCannotOrder() {
        for bad in ["", "  ", "x", "1.2.3.4", "1.2.3-beta", "1..2", "1.-2", "v1.2.3", "1.2.x"] {
            XCTAssertNil(SemanticVersion(bad), "“\(bad)” must not parse")
        }
    }

    /// The comparison every dotted-string sort gets wrong.
    func test_ordersNumericallyNotLexically() {
        XCTAssertTrue(SemanticVersion("2.10.0")! > SemanticVersion("2.9.0")!)
        XCTAssertTrue(SemanticVersion("1.0.10")! > SemanticVersion("1.0.9")!)
        XCTAssertTrue(SemanticVersion("0.9.0")! > SemanticVersion("0.8.99")!)
        XCTAssertEqual(SemanticVersion("1.2")!, SemanticVersion("1.2.0")!)
    }

    func test_describesItselfAsAFullTriple() {
        XCTAssertEqual(SemanticVersion("1.2")!.description, "1.2.0")
        XCTAssertEqual(SemanticVersion(0, 8, 2).description, "0.8.2")
    }

    func test_hostVersionCanBeOverriddenForTests() {
        let saved = HostVersion.override
        defer { HostVersion.override = saved }
        HostVersion.override = SemanticVersion(9, 9, 9)
        XCTAssertEqual(HostVersion.current, SemanticVersion(9, 9, 9))
    }
}
