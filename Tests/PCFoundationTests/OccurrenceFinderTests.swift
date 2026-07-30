// OccurrenceFinderTests.swift - Occurrence matching for the editor's mark-all.

import XCTest
@testable import PCFoundation

final class OccurrenceFinderTests: XCTestCase {
    func test_findsAllNonOverlapping() {
        let ranges = OccurrenceFinder.ranges(of: "ab", in: "ab_ab_ab")
        XCTAssertEqual(ranges.map { $0.location }, [0, 3, 6])
        XCTAssertTrue(ranges.allSatisfy { $0.length == 2 })
    }

    func test_caseInsensitiveByDefault() {
        XCTAssertEqual(OccurrenceFinder.ranges(of: "foo", in: "Foo foo FOO").count, 3)
        XCTAssertEqual(OccurrenceFinder.ranges(of: "foo", in: "Foo foo FOO", caseInsensitive: false).count, 1)
    }

    func test_overlappingTermAdvancesByOne() {
        // "aa" in "aaaa": non-overlapping → positions 0 and 2.
        XCTAssertEqual(OccurrenceFinder.ranges(of: "aa", in: "aaaa").map { $0.location }, [0, 2])
    }

    func test_emptyTerm_returnsNothing() {
        XCTAssertTrue(OccurrenceFinder.ranges(of: "", in: "abc").isEmpty)
    }

    func test_noMatch_returnsEmpty() {
        XCTAssertTrue(OccurrenceFinder.ranges(of: "xyz", in: "abcdef").isEmpty)
    }
}
