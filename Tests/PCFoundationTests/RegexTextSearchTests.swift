// SPDX-License-Identifier: Apache-2.0
// RegexTextSearchTests.swift - Regex find/replace for the editor (F-151).
//
// What is tested is the *editor* behaviour layered on NSRegularExpression, not the regex engine:
// wrapping at the ends, a selection used as a scope rather than a starting point, `$1` in a
// replacement, and the empty match that would otherwise make "find next" stand still.

import XCTest
@testable import PCFoundation

final class RegexTextSearchTests: XCTestCase {

    private func regex(_ pattern: String, caseInsensitive: Bool = false) throws -> NSRegularExpression {
        let made = RegexTextSearch.compile(pattern, caseInsensitive: caseInsensitive)
        XCTAssertNil(made.error, "pattern did not compile: \(made.error ?? "")")
        return try XCTUnwrap(made.regex)
    }

    // MARK: - Compiling

    func test_aBadPatternGivesAReasonNotSilence() {
        let made = RegexTextSearch.compile("a(b", caseInsensitive: false)
        XCTAssertNil(made.regex)
        XCTAssertNotNil(made.error, "without a reason this is indistinguishable from 'not found'")
    }

    func test_caretIsALineAnchor() throws {
        let text = "alpha\nbeta\n"
        let hit = RegexTextSearch.next(try regex("^beta"), in: text, from: 0)
        XCTAssertEqual(hit, NSRange(location: 6, length: 4))
    }

    // MARK: - Walking

    func test_nextFindsTheFollowingMatch() throws {
        let text = "one two one two"
        let first = try XCTUnwrap(RegexTextSearch.next(try regex("one"), in: text, from: 0))
        XCTAssertEqual(first, NSRange(location: 0, length: 3))
        let second = RegexTextSearch.next(try regex("one"), in: text,
                                          from: RegexTextSearch.advance(past: first))
        XCTAssertEqual(second, NSRange(location: 8, length: 3))
    }

    func test_nextWrapsAtTheEnd() throws {
        // What ⌘G means in every editor. Stopping instead reads as "no more matches" when there are
        // several above the caret.
        let text = "one two one"
        let wrapped = RegexTextSearch.next(try regex("one"), in: text, from: 11)
        XCTAssertEqual(wrapped, NSRange(location: 0, length: 3))
    }

    func test_previousWalksBackwardsAndWraps() throws {
        let text = "one two one two one"
        XCTAssertEqual(RegexTextSearch.previous(try regex("one"), in: text, before: 16),
                       NSRange(location: 8, length: 3))
        // From the very start there is nothing behind, so it wraps to the last match.
        XCTAssertEqual(RegexTextSearch.previous(try regex("one"), in: text, before: 0),
                       NSRange(location: 16, length: 3))
    }

    func test_aPatternThatMatchesNowhereAnswersNil() throws {
        XCTAssertNil(RegexTextSearch.next(try regex("zzz"), in: "abc", from: 0))
        XCTAssertNil(RegexTextSearch.previous(try regex("zzz"), in: "abc", before: 3))
    }

    func test_anEmptyMatchDoesNotStallTheWalk() throws {
        // `x*` matches the empty string at every position. Continuing at the match's end would hand
        // back the same empty match for ever — "find next" with a cursor that never moves.
        let empty = NSRange(location: 4, length: 0)
        XCTAssertEqual(RegexTextSearch.advance(past: empty), 5)
        XCTAssertEqual(RegexTextSearch.advance(past: NSRange(location: 4, length: 2)), 6)
    }

    // MARK: - Scope

    func test_theScopeIsABoundaryNotAStartingPoint() throws {
        // "In selection" must not find something below the selection — the difference between a
        // scope and an offset, and the one that quietly rewrites the wrong lines.
        let text = "one\ntwo\none\n"
        let scope = NSRange(location: 0, length: 8)          // the first two lines
        let inside = RegexTextSearch.next(try regex("one"), in: text, from: 0, scope: scope)
        XCTAssertEqual(inside, NSRange(location: 0, length: 3))
        // Searching past the end of the scope wraps *within it*, never past it.
        let wrapped = RegexTextSearch.next(try regex("one"), in: text, from: 8, scope: scope)
        XCTAssertEqual(wrapped, NSRange(location: 0, length: 3))
    }

    func test_allCountsOnlyWithinTheScope() throws {
        let text = "hit hit hit"
        XCTAssertEqual(RegexTextSearch.all(try regex("hit"), in: text).count, 3)
        XCTAssertEqual(RegexTextSearch.all(try regex("hit"), in: text,
                                           scope: NSRange(location: 0, length: 7)).count, 2)
    }

    // MARK: - Replacing

    func test_replaceAllRewritesTheScopeAndCountsIt() throws {
        let text = "a1 a2 a3"
        let out = RegexTextSearch.replaceAll(try regex("a(\\d)"), in: text, template: "b$1")
        XCTAssertEqual(out.text, "b1 b2 b3")
        XCTAssertEqual(out.count, 3)
    }

    func test_replaceAllInSelectionReturnsOnlyTheSelection() throws {
        // Only the scope comes back, so the caller can splice it in as one undoable edit. Returning
        // the whole document would make "replace in selection" and "replace everywhere" the same
        // call with a different name.
        let text = "keep a1\nchange a2\n"
        let scope = NSRange(location: 8, length: 10)          // the second line, newline included
        let out = RegexTextSearch.replaceAll(try regex("a(\\d)"), in: text, template: "[$1]", scope: scope)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out.text, "change [2]\n")
    }

    func test_replaceAllWithNoMatchChangesNothing() throws {
        let out = RegexTextSearch.replaceAll(try regex("zzz"), in: "abc", template: "x")
        XCTAssertEqual(out.count, 0)
        XCTAssertEqual(out.text, "abc")
    }

    func test_aReplacementCanShrinkOrGrowTheScope() throws {
        // The scope's length changes with the replacement, and cutting it back out has to account
        // for that — an off-by-one here corrupts the document rather than merely misreporting.
        let grow = RegexTextSearch.replaceAll(try regex("x"), in: "axb", template: "LONGER",
                                              scope: NSRange(location: 1, length: 1))
        XCTAssertEqual(grow.text, "LONGER")
        let shrink = RegexTextSearch.replaceAll(try regex("LONG"), in: "aLONGb", template: "",
                                                scope: NSRange(location: 1, length: 4))
        XCTAssertEqual(shrink.text, "")
    }

    func test_replaceOneUsesThatMatchesOwnGroups() throws {
        let text = "a1 a2"
        let second = NSRange(location: 3, length: 2)
        XCTAssertEqual(RegexTextSearch.replaceOne(try regex("a(\\d)"), in: text, at: second,
                                                  template: "<$1>"), "<2>")
    }

    func test_replaceOneRefusesARangeThatIsNotAMatch() throws {
        // A stale selection — the document changed under it — must be refused, not rewritten.
        let text = "a1 a2"
        XCTAssertNil(RegexTextSearch.replaceOne(try regex("a(\\d)"), in: text,
                                                at: NSRange(location: 2, length: 2), template: "x"))
    }
}
