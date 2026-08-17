// SPDX-License-Identifier: Apache-2.0
// SettingsSearchIndexTests.swift - Finding a setting by name across the settings pages (F-408).
//
// The ranking is the feature. A search field that *finds* the setting but puts it fourth, behind three
// paragraphs that mention the same word, is the version this replaced — and that was only visible when
// the real dialog was driven. These are the orderings that made it usable, held in place.

import XCTest
@testable import PCFoundation

final class SettingsSearchIndexTests: XCTestCase {

    /// A miniature of the real dialog: a page name, the settings on it, and the prose underneath them.
    private func index() -> SettingsSearchIndex {
        SettingsSearchIndex([
            SettingsSearchEntry(name: "Colors", page: "Colors", ref: 0),
            SettingsSearchEntry(name: "Show hidden files", page: "Display",
                                keywords: ["show hidden changed"], ref: 1),
            SettingsSearchEntry(name: "Keep a backup copy (.bak) of the previous contents when saving",
                                page: "Edit/View",
                                keywords: ["Applies to the built-in text editor, the hex editor and the compare window.",
                                           "editor backups changed"], ref: 2),
            SettingsSearchEntry(name: "Colors by file type…", page: "Display", ref: 3),
            SettingsSearchEntry(name: "Keep-alive interval (seconds)", page: "FTP",
                                keywords: ["ftp keep alive changed"], ref: 4),
            SettingsSearchEntry(name: "Größe", page: "Display", ref: 5),
        ])
    }

    private func names(_ query: String) -> [String] {
        index().search(query).map(\.name)
    }

    // MARK: - Finding

    func test_aNameIsFoundByASubstringOfIt() {
        XCTAssertEqual(names("hidden"), ["Show hidden files"])
    }

    func test_theSearchCrossesPages() {
        // The point of the feature: one query, all sixteen pages.
        let pages = index().search("colors").map(\.page)
        XCTAssertEqual(Set(pages), ["Colors", "Display"])
    }

    func test_aWordInTheNoteFindsTheSettingItExplains() {
        // "hex" is nowhere in the checkbox's title; it is in the sentence underneath it.
        XCTAssertEqual(names("hex"), ["Keep a backup copy (.bak) of the previous contents when saving"])
    }

    func test_theActionsWordsFindASettingWhoseLabelIsTranslated() {
        // The keyword "editor backups changed" comes from the selector the control calls, which is the
        // only searchable text in this dialog that is *not* in the user's language.
        XCTAssertEqual(names("backups"), ["Keep a backup copy (.bak) of the previous contents when saving"])
    }

    func test_aPageNameGathersItsOwnSettings() {
        XCTAssertEqual(names("ftp"), ["Keep-alive interval (seconds)"])
    }

    func test_caseAndDiacriticsAreIgnored() {
        XCTAssertEqual(names("GROSSE"), ["Größe"])
        XCTAssertEqual(names("grosse"), ["Größe"])
    }

    // MARK: - Ranking

    func test_theSettingCalledColorsOutranksTheOnesMerelyMentioningIt() {
        // A hit in the name beats a hit in a longer name, and both beat prose: "Colors" first.
        XCTAssertEqual(names("colors").first, "Colors")
    }

    func test_aWordStartBeatsAMatchInsideAWord() {
        let index = SettingsSearchIndex([
            SettingsSearchEntry(name: "Uncheck all", page: "P", ref: 0),   // "check" mid-word
            SettingsSearchEntry(name: "Check for updates", page: "P", ref: 1),
        ])
        XCTAssertEqual(index.search("check").map(\.name).first, "Check for updates")
    }

    func test_aShortLabelBeatsALongOneWithTheSameHit() {
        let index = SettingsSearchIndex([
            SettingsSearchEntry(name: "Verify files after copy, including every attribute and its checksum",
                                page: "P", ref: 0),
            SettingsSearchEntry(name: "Verify", page: "P", ref: 1),
        ])
        XCTAssertEqual(index.search("verify").map(\.name).first, "Verify")
    }

    func test_aNameHitBeatsAPageHit() {
        let index = SettingsSearchIndex([
            SettingsSearchEntry(name: "Keep-alive interval", page: "FTP", ref: 0),
            SettingsSearchEntry(name: "FTP", page: "FTP", ref: 1),
        ])
        XCTAssertEqual(index.search("ftp").map(\.name).first, "FTP")
    }

    // MARK: - Narrowing and refusing

    func test_everyWordMustMatchSomewhere() {
        XCTAssertEqual(names("hidden display"), ["Show hidden files"])
        XCTAssertEqual(names("hidden zip"), [], "an unmatched word must narrow to nothing, not be ignored")
    }

    func test_aWordIsNotFoundAsScatteredLetters() {
        // The version before this used subsequence matching, and in the running app "hidden" returned
        // "Eine Dateisuche im Betrachter fortsetzen" — h, i, d, d, e, n in that order and nothing more.
        XCTAssertEqual(names("hdn"), [])
    }

    func test_anEmptyQueryMatchesNothing() {
        XCTAssertEqual(names(""), [])
        XCTAssertEqual(names("   "), [])
    }

    func test_aQueryThatMatchesNothingReturnsNothing() {
        XCTAssertEqual(names("mainframe"), [])
    }

    // MARK: - Stability

    func test_theOrderIsStableForEqualScores() {
        // Two identical settings on different pages: index order decides, so the list does not reshuffle
        // between keystrokes under the reader's cursor.
        let index = SettingsSearchIndex([
            SettingsSearchEntry(name: "Same", page: "A", ref: 7),
            SettingsSearchEntry(name: "Same", page: "B", ref: 9),
        ])
        XCTAssertEqual(index.search("same").map(\.ref), [7, 9])
    }

    func test_theLimitIsHonoured() {
        let many = (0..<40).map { SettingsSearchEntry(name: "Option \($0)", page: "P", ref: $0) }
        XCTAssertEqual(SettingsSearchIndex(many).search("option").count, SettingsSearchIndex.defaultLimit)
        XCTAssertEqual(SettingsSearchIndex(many).search("option", limit: 5).count, 5)
    }

    func test_refIsCarriedThroughUntouched() {
        // The caller resolves it back to a control; an index that renumbered would open the wrong page.
        XCTAssertEqual(index().search("keep-alive").map(\.ref), [4])
    }
}
