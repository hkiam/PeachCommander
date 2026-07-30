// SpotlightPredicateTests.swift - Predicate construction for Spotlight search.

import XCTest
@testable import PCFoundation

final class SpotlightPredicateTests: XCTestCase {
    func test_wildcardMask_usesLikeVerbatim() {
        let p = SpotlightPredicate.build(nameMask: "*.swift", contentText: nil)
        XCTAssertEqual(p.predicateFormat, "kMDItemFSName LIKE[cd] \"*.swift\"")
    }

    func test_plainToken_becomesSubstring() {
        let p = SpotlightPredicate.build(nameMask: "report", contentText: nil)
        XCTAssertEqual(p.predicateFormat, "kMDItemFSName LIKE[cd] \"*report*\"")
    }

    func test_multipleMasks_areOred() {
        let p = SpotlightPredicate.build(nameMask: "*.swift *.h", contentText: nil)
        XCTAssertTrue(p.predicateFormat.contains("OR"))
        XCTAssertTrue(p.predicateFormat.contains("*.swift"))
        XCTAssertTrue(p.predicateFormat.contains("*.h"))
    }

    func test_contentText_addsContentClause_andedWithName() {
        let p = SpotlightPredicate.build(nameMask: "*.txt", contentText: "hello")
        XCTAssertTrue(p.predicateFormat.contains("kMDItemTextContent CONTAINS[cd] \"hello\""))
        XCTAssertTrue(p.predicateFormat.contains("AND"))
        XCTAssertTrue(p.predicateFormat.contains("kMDItemFSName"))
    }

    func test_matchAllMask_withContent_onlyContentClause() {
        let p = SpotlightPredicate.build(nameMask: "*.*", contentText: "needle")
        XCTAssertEqual(p.predicateFormat, "kMDItemTextContent CONTAINS[cd] \"needle\"")
    }

    func test_emptyEverything_matchesAllNames() {
        let p = SpotlightPredicate.build(nameMask: "", contentText: nil)
        XCTAssertEqual(p.predicateFormat, "kMDItemFSName LIKE[cd] \"*\"")
    }
}
