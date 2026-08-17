// SPDX-License-Identifier: Apache-2.0
// ViewerSearchSeedTests.swift - Handing a file-search's term to the viewer that opens one of its hits
// (F-407).
//
// The translation is where this feature can be wrong in a way nobody notices: a seed that carries the
// wrong bytes sends the reader to a byte offset in the middle of nothing, and a seed made from a search
// that had no content term at all prefills a search box with something that never matched.

import XCTest
@testable import PCVFS

final class ViewerSearchSeedTests: XCTestCase {

    private func template(content: String? = nil, hex: String? = nil,
                          caseSensitive: Bool = false, regex: Bool = false,
                          wholeWord: Bool = false) -> SearchTemplate {
        SearchTemplate(name: "t", nameMask: "*.*", contentText: content, caseSensitive: caseSensitive,
                       useRegex: regex, wholeWord: wholeWord, hexContent: hex)
    }

    // MARK: - What is carried

    func test_aTextSearchCarriesTheTermAndItsBytes() {
        let seed = ViewerSearchSeed(template: template(content: "TODO(maik)"))
        XCTAssertEqual(seed?.term, "TODO(maik)")
        XCTAssertEqual(seed?.needle, Array("TODO(maik)".utf8))
        XCTAssertEqual(seed?.isRegex, false)
        XCTAssertEqual(seed?.isHex, false)
    }

    func test_caseSensitivityIsCarriedBothWays() {
        XCTAssertEqual(ViewerSearchSeed(template: template(content: "x", caseSensitive: true))?.caseSensitive, true)
        XCTAssertEqual(ViewerSearchSeed(template: template(content: "x"))?.caseSensitive, false)
    }

    func test_aRegexSearchStaysARegex() {
        // Seeding `^func .*Test\(` as literal text would find nothing and look like a broken feature.
        let seed = ViewerSearchSeed(template: template(content: #"^func .*Test\("#, regex: true))
        XCTAssertEqual(seed?.isRegex, true)
        XCTAssertEqual(seed?.term, #"^func .*Test\("#)
    }

    func test_nonASCIITermsCarryTheirUTF8Bytes() {
        // The viewer searches bytes; a term with an umlaut in it is two bytes per character, and the
        // needle has to be those bytes rather than the scalars.
        let seed = ViewerSearchSeed(template: template(content: "Grüße"))
        XCTAssertEqual(seed?.needle, Array("Grüße".utf8))
        XCTAssertEqual(seed?.needle.count, 7)
    }

    // MARK: - Hex

    func test_aHexSearchCarriesTheParsedBytesAndKeepsTheTypedTerm() {
        let seed = ViewerSearchSeed(template: template(hex: "48 65 6C"))
        XCTAssertEqual(seed?.needle, [0x48, 0x65, 0x6C])
        XCTAssertEqual(seed?.term, "48 65 6C", "the field showed hex, so the search field must too")
        XCTAssertEqual(seed?.isHex, true)
        XCTAssertEqual(seed?.isRegex, false)
    }

    func test_hexWinsOverContentTextWhenBothAreSomehowSet() {
        // The dialog reroutes the find text into `hexContent` in hex mode, so a template carrying both is
        // one the engine would treat as hex; the seed must not disagree with the search that ran.
        let seed = ViewerSearchSeed(template: template(content: "ignored", hex: "41"))
        XCTAssertEqual(seed?.needle, [0x41])
        XCTAssertEqual(seed?.isHex, true)
    }

    func test_unparsableHexIsNoSeedAtAll() {
        // Nothing was searched for, so there is no hit to jump to and nothing honest to prefill.
        XCTAssertNil(ViewerSearchSeed(template: template(hex: "zz zz")))
    }

    // MARK: - When there is nothing to seed

    func test_aNameOnlySearchProducesNoSeed() {
        XCTAssertNil(ViewerSearchSeed(template: template()))
    }

    func test_anEmptyContentTermProducesNoSeed() {
        XCTAssertNil(ViewerSearchSeed(template: template(content: "")))
        XCTAssertNil(ViewerSearchSeed(template: template(hex: "")))
    }

    // MARK: - What is deliberately dropped

    func test_wholeWordIsNotCarried() {
        // The viewer's search has no word boundaries. Carrying the flag would mean claiming a restriction
        // the viewer cannot apply; the term is still seeded, and the file-search's own results are what
        // the "whole word" option shaped.
        let seed = ViewerSearchSeed(template: template(content: "log", wholeWord: true))
        XCTAssertEqual(seed?.term, "log")
        XCTAssertEqual(seed?.needle, Array("log".utf8))
    }

    func test_twoSeedsFromTheSameTemplateAreEqual() {
        // Equatable is what lets a caller keep the last seed and compare it; a struct that compared by
        // identity would make "the same search" untestable.
        let t = template(content: "x", caseSensitive: true)
        XCTAssertEqual(ViewerSearchSeed(template: t), ViewerSearchSeed(template: t))
    }
}
