// SPDX-License-Identifier: Apache-2.0
// RecentLinesTests.swift - The per-field search histories of the Find dialog (F-406), and the
// most-recently-used file behind them, which the editor's filter history (F-356) now shares.

import XCTest
@testable import PCFoundation

final class RecentLinesTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("recent-lines-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    private func list(limit: Int = RecentLines.defaultLimit) -> RecentLines {
        RecentLines(url: root.appendingPathComponent("entries.txt"), limit: limit)
    }

    // MARK: - Order

    func test_mostRecentFirst() {
        let recent = list()
        for entry in ["*.txt", "*.swift", "*.log"] { recent.remember(entry) }
        XCTAssertEqual(recent.load(), ["*.log", "*.swift", "*.txt"])
    }

    func test_reusingAnEntryPromotesItRatherThanDuplicatingIt() {
        // The whole point of "sorted by last use": searching for something again must move it to the
        // top, not add a second copy that pushes the rest of the list down twice as fast.
        let recent = list()
        for entry in ["a", "b", "c", "a"] { recent.remember(entry) }
        XCTAssertEqual(recent.load(), ["a", "c", "b"])
    }

    func test_theOldestEntryIsDroppedAtTheLimit() {
        let recent = list(limit: 3)
        for entry in ["1", "2", "3", "4"] { recent.remember(entry) }
        XCTAssertEqual(recent.load(), ["4", "3", "2"])
    }

    func test_twentyEntriesByDefault() {
        let recent = list()
        for i in 1...25 { recent.remember("term\(i)") }
        XCTAssertEqual(recent.load().count, 20)
        XCTAssertEqual(recent.load().first, "term25")
        XCTAssertEqual(recent.load().last, "term6")
    }

    // MARK: - What is not stored

    func test_aMissingFileIsAnEmptyHistoryAndNotAnError() {
        XCTAssertEqual(list().load(), [])
    }

    func test_blankAndWhitespaceOnlyEntriesAreIgnored() {
        let recent = list()
        recent.remember("")
        recent.remember("   ")
        XCTAssertEqual(recent.load(), [])
    }

    func test_anEntrySpanningLinesIsRefusedRatherThanStoredAsTwo() {
        // One entry per line is the whole format; a stored newline would read back as two terms, and
        // the second would be a search nobody typed.
        let recent = list()
        recent.remember("keep")
        recent.remember("first\nsecond")
        XCTAssertEqual(recent.load(), ["keep"])
    }

    func test_surroundingWhitespaceIsNotPartOfTheEntry() {
        let recent = list()
        recent.remember(" *.swift ")
        recent.remember("*.swift")
        XCTAssertEqual(recent.load(), ["*.swift"], "the same term with stray spaces is the same term")
    }

    func test_theFileIsReadableOnlyByItsOwner() throws {
        // A search term says as much as the files it finds — a host name, a bucket, a token somebody
        // went looking for.
        let recent = list()
        recent.remember("secret-bucket-name")
        let perms = try FileManager.default.attributesOfItem(atPath: root.appendingPathComponent("entries.txt").path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.int16Value, 0o600)
    }

    // MARK: - Clearing

    func test_clearForgetsEverythingAndLeavesNoFileBehind() {
        let recent = list()
        recent.remember("*.swift")
        recent.clear()
        XCTAssertEqual(recent.load(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("entries.txt").path))
    }

    func test_clearingAnEmptyHistoryIsHarmless() {
        list().clear()
        XCTAssertEqual(list().load(), [])
    }

    func test_rememberingAfterAClearStartsANewList() {
        let recent = list()
        recent.remember("old")
        recent.clear()
        recent.remember("new")
        XCTAssertEqual(recent.load(), ["new"])
    }

    // MARK: - The Find dialog's two fields

    func test_theTwoFindFieldsDoNotShareAList() {
        // A dropdown that offered `*.log` next to `TODO(` would make both fields worse.
        let history = FindFilesHistory(configRoot: root)
        history.names.remember("*.swift")
        history.texts.remember("@MainActor")
        XCTAssertEqual(history.names.load(), ["*.swift"])
        XCTAssertEqual(history.texts.load(), ["@MainActor"])
    }

    func test_clearEmptiesBothFindHistories() {
        let history = FindFilesHistory(configRoot: root)
        history.names.remember("*.swift")
        history.texts.remember("@MainActor")
        history.clear()
        XCTAssertEqual(history.names.load(), [])
        XCTAssertEqual(history.texts.load(), [])
    }

    func test_findHistoriesSurviveANewInstance() {
        // The dialog is built afresh every time it opens, so the history has to come from disk.
        FindFilesHistory(configRoot: root).names.remember("*.swift")
        XCTAssertEqual(FindFilesHistory(configRoot: root).names.load(), ["*.swift"])
    }

    func test_aTermWithINIPunctuationSurvivesTheRoundTrip() {
        // Why this is a text file and not a section of an .ini: every character below means something
        // to an INI parser, and a search term is arbitrary text.
        let history = FindFilesHistory(configRoot: root)
        let term = #"[section] key = "value" ; # end"#
        history.texts.remember(term)
        XCTAssertEqual(history.texts.load(), [term])
    }

    // MARK: - The editor's filter history, on the same mechanism (F-356)

    func test_theEditorFilterHistoryStillPromotesAndPersists() {
        let history = TextPipeHistory(configRoot: root)
        history.remember("sort")
        history.remember("jq .")
        history.remember("sort")
        XCTAssertEqual(history.load(), ["sort", "jq ."])
        XCTAssertEqual(TextPipeHistory(configRoot: root).load(), ["sort", "jq ."])
        XCTAssertEqual(TextPipeHistory.limit, 20)
    }

    func test_theEditorAndFindHistoriesAreSeparateFiles() {
        TextPipeHistory(configRoot: root).remember("sort")
        XCTAssertEqual(FindFilesHistory(configRoot: root).names.load(), [])
        XCTAssertEqual(FindFilesHistory(configRoot: root).texts.load(), [])
    }
}
