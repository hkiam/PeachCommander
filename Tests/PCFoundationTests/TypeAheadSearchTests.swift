// SPDX-License-Identifier: Apache-2.0
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

    // MARK: - Counting the matches, for the visible prefix indicator

    func test_matches_listsEveryPrefixHitInOrder() {
        let names = ["readme.md", "Report.pdf", "notes.txt", "rest.swift"]
        XCTAssertEqual(TypeAheadSearch.matches(names: names, query: "re"), [0, 1, 3])
        // Same case- and diacritic-insensitivity as the jump: the indicator must never claim a count
        // the jump would not agree with.
        XCTAssertEqual(TypeAheadSearch.matches(names: names, query: "RE"), [0, 1, 3])
    }

    func test_matches_isEmptyForAnEmptyQuery() {
        // An empty prefix is "no search in progress", not "everything matches" — otherwise ending a
        // search would flash a count of every entry in the folder.
        XCTAssertEqual(TypeAheadSearch.matches(names: ["a", "b"], query: ""), [])
    }

    // MARK: - Stepping between the matches with the arrow keys

    func test_neighbour_walksForwardsAndBackwardsThroughTheHits() {
        let names = ["readme.md", "Report.pdf", "notes.txt", "rest.swift"]   // hits: 0, 1, 3
        XCTAssertEqual(TypeAheadSearch.neighbour(of: 0, names: names, query: "re", forward: true), 1)
        XCTAssertEqual(TypeAheadSearch.neighbour(of: 1, names: names, query: "re", forward: true), 3)
        XCTAssertEqual(TypeAheadSearch.neighbour(of: 3, names: names, query: "re", forward: false), 1)
        XCTAssertEqual(TypeAheadSearch.neighbour(of: 1, names: names, query: "re", forward: false), 0)
    }

    func test_neighbour_wrapsAtBothEnds() {
        let names = ["readme.md", "Report.pdf", "notes.txt", "rest.swift"]
        XCTAssertEqual(TypeAheadSearch.neighbour(of: 3, names: names, query: "re", forward: true), 0)
        XCTAssertEqual(TypeAheadSearch.neighbour(of: 0, names: names, query: "re", forward: false), 3)
    }

    func test_neighbour_fromACursorThatIsNotItselfAMatch() {
        // Cursor on "notes.txt" (index 2, not a hit): forwards is the hit below it, backwards the
        // one above. Stepping must not require that you are standing on a match already.
        let names = ["readme.md", "Report.pdf", "notes.txt", "rest.swift"]
        XCTAssertEqual(TypeAheadSearch.neighbour(of: 2, names: names, query: "re", forward: true), 3)
        XCTAssertEqual(TypeAheadSearch.neighbour(of: 2, names: names, query: "re", forward: false), 1)
    }

    func test_neighbour_fromTheParentRow() {
        // -1 is the cursor on "..", which is below every row: forwards lands on the first hit,
        // backwards wraps to the last.
        let names = ["readme.md", "Report.pdf", "notes.txt", "rest.swift"]
        XCTAssertEqual(TypeAheadSearch.neighbour(of: -1, names: names, query: "re", forward: true), 0)
        XCTAssertEqual(TypeAheadSearch.neighbour(of: -1, names: names, query: "re", forward: false), 3)
    }

    func test_neighbour_ofASingleMatchIsItself() {
        // One hit means both arrows stay put rather than beeping — the panel moves the cursor to a
        // row it is already on, which is a no-op.
        let names = ["readme.md", "notes.txt"]
        XCTAssertEqual(TypeAheadSearch.neighbour(of: 0, names: names, query: "re", forward: true), 0)
        XCTAssertEqual(TypeAheadSearch.neighbour(of: 0, names: names, query: "re", forward: false), 0)
    }

    func test_neighbour_isNilWithoutMatches() {
        XCTAssertNil(TypeAheadSearch.neighbour(of: 0, names: names, query: "zz", forward: true))
        XCTAssertNil(TypeAheadSearch.neighbour(of: 0, names: names, query: "", forward: true))
        XCTAssertNil(TypeAheadSearch.neighbour(of: 0, names: [], query: "a", forward: false))
    }

    func test_neighbour_agreesWithTheJumpOnWhatCounts() {
        // Same case- and diacritic-insensitive prefix rule as `match`, or the arrows would visit
        // rows the typed letter refuses to land on.
        XCTAssertEqual(TypeAheadSearch.neighbour(of: 0, names: names, query: "A", forward: true), 1)
        XCTAssertEqual(TypeAheadSearch.neighbour(of: 0, names: names, query: "ur", forward: true), 4)
    }

    func test_position_saysWhichMatchTheCursorIsOn() {
        let names = ["readme.md", "Report.pdf", "notes.txt", "rest.swift"]
        XCTAssertEqual(TypeAheadSearch.position(of: 0, names: names, query: "re"), 1)
        XCTAssertEqual(TypeAheadSearch.position(of: 1, names: names, query: "re"), 2)
        XCTAssertEqual(TypeAheadSearch.position(of: 3, names: names, query: "re"), 3)
        // A cursor sitting on something that does not match has no position among the matches.
        XCTAssertNil(TypeAheadSearch.position(of: 2, names: names, query: "re"))
    }
}
