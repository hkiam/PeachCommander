// SPDX-License-Identifier: Apache-2.0
// UILanguageChoicesTests.swift - The Language page lists every translation, each in its own name.

import XCTest
@testable import PCFoundation

final class UILanguageChoicesTests: XCTestCase {
    /// Each language is named as its speakers name it, so it can be found from any menu language.
    func testEachLanguageIsNamedInItself() {
        let byCode = Dictionary(uniqueKeysWithValues:
            UILanguageChoices.choices(localizations: ["en", "de", "fr", "zh-Hans"]).map { ($0.code, $0.label) })
        XCTAssertEqual(byCode["de"], "Deutsch")
        XCTAssertEqual(byCode["fr"], "Français")
        XCTAssertEqual(byCode["en"], "English")
        XCTAssertEqual(byCode["zh-Hans"], "简体中文")
    }

    /// Base is not a language, and a localization listed twice is offered once.
    func testBaseAndDuplicatesAreLeftOut() {
        let codes = UILanguageChoices.choices(localizations: ["Base", "en", "de", "en"]).map(\.code)
        XCTAssertEqual(codes.sorted(), ["de", "en"])
    }

    /// Sorted by the name shown, not by code: "Deutsch" before "English" before "Français".
    func testSortedByTheNameShown() {
        let labels = UILanguageChoices.choices(localizations: ["fr", "en", "de"]).map(\.label)
        XCTAssertEqual(labels, ["Deutsch", "English", "Français"])
    }
}
