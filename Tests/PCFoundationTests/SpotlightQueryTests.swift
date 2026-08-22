// SPDX-License-Identifier: Apache-2.0
// SpotlightQueryTests.swift - The structured query the assistant's words are translated into (F-446).
//
// The predicate is what decides whether "that PDF from last month" finds anything, and it is built from
// fields a language model filled in. Two failure shapes are worth pinning: a query that says nothing
// must not become "every file on the volume", and a field that was asked for must actually narrow the
// search rather than being dropped on the floor. Both are invisible in a live index — a wrong predicate
// returns *results*, just the wrong ones.

import XCTest
@testable import PCFoundation

final class SpotlightQueryTests: XCTestCase {

    // MARK: - Saying nothing

    func testAnEmptyQueryBuildsNoPredicate() {
        // Not "match everything": a whole-volume dump is not an answer to any question, and the caller
        // reports the emptiness instead.
        XCTAssertNil(SpotlightPredicate.build(SpotlightQuery()))
        XCTAssertNil(SpotlightPredicate.build(SpotlightQuery(nameMask: "*")))
        XCTAssertNil(SpotlightPredicate.build(SpotlightQuery(nameMask: "*.*", contentText: "")))
        XCTAssertNil(SpotlightPredicate.build(SpotlightQuery(nameMask: "   ")))
    }

    func testAnyOneFieldIsEnough() {
        XCTAssertFalse(SpotlightQuery(nameMask: "report").isEmpty)
        XCTAssertFalse(SpotlightQuery(contentText: "invoice").isEmpty)
        XCTAssertFalse(SpotlightQuery(kind: .pdf).isEmpty)
        XCTAssertFalse(SpotlightQuery(modifiedWithinDays: 7).isEmpty)
        XCTAssertFalse(SpotlightQuery(largerThanBytes: 1).isEmpty)
    }

    // MARK: - The fields narrow the search

    func testKindBecomesAConformanceClauseNotAnExtension() {
        // The tree attribute carries the conformance chain, which is why `.image` finds a HEIC without
        // anyone naming HEIC.
        let p = SpotlightPredicate.build(SpotlightQuery(kind: .image))
        XCTAssertEqual(p?.predicateFormat, "kMDItemContentTypeTree == \"public.image\"")
    }

    func testEveryKindMapsToASystemUTI() {
        for kind in SpotlightQuery.Kind.allCases {
            XCTAssertTrue(kind.uti.contains("."), "\(kind.rawValue) has no UTI-shaped value")
            XCTAssertFalse(kind.uti.hasPrefix("."), "\(kind.rawValue)")
        }
    }

    func testTheRelativeWindowResolvesAgainstTheClockItIsGiven() {
        // `now` is injected so this can be asserted at all; the app passes the real clock.
        let now = Date(timeIntervalSince1970: 1_000_000_000)
        let p = SpotlightPredicate.build(SpotlightQuery(modifiedWithinDays: 10), now: now)
        XCTAssertNotNil(p)
        XCTAssertTrue(p!.predicateFormat.contains("kMDItemContentModificationDate >="),
                      p!.predicateFormat)
        // Ten days back, not ten days forward — and asserted as a number, because `predicateFormat`
        // renders an NSDate as seconds since its own reference date (2001-01-01) rather than as a
        // readable date. Checking for a year string passed for the wrong reason or not at all.
        let expected = now.addingTimeInterval(-10 * 86_400).timeIntervalSinceReferenceDate
        XCTAssertTrue(p!.predicateFormat.contains(String(format: "%.6f", expected)),
                      "expected \(expected) in \(p!.predicateFormat)")
    }

    func testAZeroOrNegativeWindowIsNotAFilter() {
        // Zero is how "no window" arrives from a tool argument that cannot be absent, and "the last
        // zero days" would match nothing at all.
        XCTAssertNil(SpotlightPredicate.build(SpotlightQuery(modifiedWithinDays: 0)))
        XCTAssertNil(SpotlightPredicate.build(SpotlightQuery(modifiedWithinDays: -5)))
    }

    func testSizeBoundsBecomeNumericComparisons() {
        let p = SpotlightPredicate.build(SpotlightQuery(largerThanBytes: 1_048_576))
        XCTAssertEqual(p?.predicateFormat, "kMDItemFSSize >= 1048576")
    }

    func testFieldsCombineWithAnd() {
        // "that PDF contract from last month", as the model would fill it in.
        let q = SpotlightQuery(nameMask: "contract", kind: .pdf, modifiedWithinDays: 30)
        let format = SpotlightPredicate.build(q)!.predicateFormat
        XCTAssertTrue(format.contains("AND"), format)
        XCTAssertTrue(format.contains("*contract*"), format)
        XCTAssertTrue(format.contains("com.adobe.pdf"), format)
        XCTAssertTrue(format.contains("kMDItemContentModificationDate"), format)
    }

    func testContentTextSurvivesAnEmptyNameMask() {
        // "find the file that mentions Aachen" has no name at all, and the content clause must not be
        // dropped along with the name clause.
        let format = SpotlightPredicate.build(SpotlightQuery(contentText: "Aachen"))!.predicateFormat
        XCTAssertTrue(format.contains("kMDItemTextContent"), format)
    }

    // MARK: - Parsing what a model actually sends

    func testKindParsingIsToleratedInThePluralAndTheSynonym() {
        XCTAssertEqual(SpotlightQuery.Kind(loose: "PDFs"), .pdf)
        XCTAssertEqual(SpotlightQuery.Kind(loose: "photos"), .image)
        XCTAssertEqual(SpotlightQuery.Kind(loose: "video"), .movie)
        XCTAssertEqual(SpotlightQuery.Kind(loose: "  Folders "), .folder)
        XCTAssertEqual(SpotlightQuery.Kind(loose: "apps"), .application)
        XCTAssertEqual(SpotlightQuery.Kind(loose: "source-code"), .source)
    }

    func testAnUnknownKindIsNilRatherThanAGuess() {
        // The caller turns nil into "I do not know that kind" instead of silently widening the search
        // to every file, which is the failure that reads as a wrong answer.
        XCTAssertNil(SpotlightQuery.Kind(loose: "spreadsheet"))
        XCTAssertNil(SpotlightQuery.Kind(loose: ""))
        XCTAssertNil(SpotlightQuery.Kind(loose: "gubbins"))
    }
}
