import XCTest
@testable import PCFoundation

final class TypeAheadSearchTests: XCTestCase {
    private let names = ["Apple", "apricot", "Banana", "cherry", "Ürdinger"]

    func testPrefixCaseInsensitive() {
        XCTAssertEqual(TypeAheadSearch.match(names: names, query: "ap", from: 0), 0)   // Apple
        XCTAssertEqual(TypeAheadSearch.match(names: names, query: "AP", from: 1), 1)   // apricot
        XCTAssertEqual(TypeAheadSearch.match(names: names, query: "b", from: 0), 2)    // Banana
    }

    func testAnchoredNotSubstring() {
        // "an" is inside Banana but not a prefix → no match.
        XCTAssertNil(TypeAheadSearch.match(names: names, query: "an", from: 0))
    }

    func testCyclesWithWrap() {
        // Same letter from successive positions cycles through matches then wraps.
        XCTAssertEqual(TypeAheadSearch.match(names: names, query: "a", from: 0), 0)
        XCTAssertEqual(TypeAheadSearch.match(names: names, query: "a", from: 1), 1)
        XCTAssertEqual(TypeAheadSearch.match(names: names, query: "a", from: 2), 0)   // wrapped
    }

    func testNoWrapStopsAtEnd() {
        XCTAssertNil(TypeAheadSearch.match(names: names, query: "a", from: 2, wrap: false))
    }

    func testDiacriticInsensitive() {
        XCTAssertEqual(TypeAheadSearch.match(names: names, query: "ur", from: 0), 4)   // Ürdinger
    }

    func testEmptyQueryOrNames() {
        XCTAssertNil(TypeAheadSearch.match(names: names, query: "", from: 0))
        XCTAssertNil(TypeAheadSearch.match(names: [], query: "a", from: 0))
    }
}
