// SPDX-License-Identifier: Apache-2.0
// SearchCommentsTests.swift - Find Files looks in a file's comment too (F-373).
//
// A comment is where somebody wrote down *why* a file matters, and until now the only way to find that
// again was to walk the directories with the Comment column switched on.
//
// The rules being pinned down here are the ones a user would notice if they were wrong: the comment is an
// additional place to look and not a replacement, "not containing" inverts the whole question, and whole
// word / case / regex mean the same thing in a comment as in file content.

import XCTest
@testable import PCVFS

final class SearchCommentsTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-search-comments-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ name: String, _ contents: String) throws {
        try contents.write(to: root.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    /// Run a search and return the hit file names, sorted.
    private func hits(_ query: SearchQuery,
                      comments: [String: String] = [:]) async -> [(name: String, preview: String)] {
        let engine = FileSearchEngine()
        let provider: FileSearchEngine.CommentProvider = { path in
            comments[(path as NSString).lastPathComponent]
        }
        var out: [(name: String, preview: String)] = []
        for await hit in await engine.search(query, fs: LocalFS(), commentProvider: provider) {
            out.append(((hit.path as NSString).lastPathComponent, hit.matchPreview ?? ""))
        }
        return out.sorted { $0.name < $1.name }
    }

    private func query(_ text: String) -> SearchQuery {
        var q = SearchQuery(nameMask: "*", startDirectory: root.path, contentText: text)
        q.searchComments = true
        return q
    }

    // MARK: - The comment as a second place to look

    func testAFileIsFoundByItsComment() async throws {
        try write("invoice.pdf", "binary-ish content with nothing to find")
        let found = await hits(query("customer"), comments: ["invoice.pdf": "the customer's original"])
        XCTAssertEqual(found.map(\.name), ["invoice.pdf"])
        XCTAssertTrue(found[0].preview.hasPrefix("comment: "),
                      "the preview must say where the term was found: \(found[0].preview)")
    }

    func testAFileIsStillFoundByItsContent() async throws {
        // The comment is additional. Breaking the content path while adding a second one would be a poor
        // trade, and this is the test that notices.
        try write("notes.txt", "the customer approved it")
        let found = await hits(query("customer"), comments: [:])
        XCTAssertEqual(found.map(\.name), ["notes.txt"])
        XCTAssertFalse(found[0].preview.hasPrefix("comment: "))
    }

    func testTheContentMatchWinsWhenBothMatch() async throws {
        // A line number and a line of the file are more useful than the comment, and asking the provider
        // at all is skipped in that case.
        try write("both.txt", "the customer approved it")
        let found = await hits(query("customer"), comments: ["both.txt": "customer again"])
        XCTAssertEqual(found.count, 1)
        XCTAssertFalse(found[0].preview.hasPrefix("comment: "), found[0].preview)
    }

    func testWithoutTheOptionTheCommentIsNotSearched() async throws {
        try write("invoice.pdf", "nothing")
        var q = SearchQuery(nameMask: "*", startDirectory: root.path, contentText: "customer")
        q.searchComments = false
        let result1 = await hits(q, comments: ["invoice.pdf": "the customer's original"]).count
        XCTAssertEqual(result1, 0)
    }

    func testWithoutAProviderTheOptionDoesNothing() async throws {
        // The same contract `searchPluginText` has: the flag needs the host to supply the source.
        try write("invoice.pdf", "nothing")
        let engine = FileSearchEngine()
        var count = 0
        for await _ in await engine.search(query("customer"), fs: LocalFS()) { count += 1 }
        XCTAssertEqual(count, 0)
    }

    // MARK: - The inverted search

    func testNotContainingMeansInNeitherContentNorComment() async throws {
        // The interesting case: a file whose *comment* holds the term must not be reported as "does not
        // contain" it. Inverting only the content half would say the opposite of the truth.
        try write("clean.txt", "nothing of interest")
        try write("commented.txt", "nothing of interest")
        var q = query("customer")
        q.contentNotContaining = true
        let found = await hits(q, comments: ["commented.txt": "the customer's original"])
        XCTAssertEqual(found.map(\.name), ["clean.txt"])
    }

    // MARK: - The same rules as for content

    func testWholeWordAppliesToACommentToo() async throws {
        try write("a.txt", "x")
        try write("b.txt", "x")
        var q = query("cat")
        q.wholeWord = true
        let found = await hits(q, comments: ["a.txt": "one cat here", "b.txt": "concatenated"])
        XCTAssertEqual(found.map(\.name), ["a.txt"])
    }

    func testCaseSensitivityAppliesToACommentToo() async throws {
        try write("a.txt", "x")
        var q = query("Customer")
        q.caseSensitive = true
        let result2 = await hits(q, comments: ["a.txt": "the customer"]).count
        XCTAssertEqual(result2, 0)
        q.caseSensitive = false
        let result3 = await hits(q, comments: ["a.txt": "the customer"]).count
        XCTAssertEqual(result3, 1)
    }

    func testARegexAppliesToACommentToo() async throws {
        try write("a.txt", "x")
        var q = query("invoice-[0-9]{4}")
        q.useRegex = true
        let result4 = await hits(q, comments: ["a.txt": "supersedes invoice-2026"]).map(\.name)
        XCTAssertEqual(result4, ["a.txt"])
    }

    func testAHexQueryIsNotAppliedToAComment() async throws {
        // "These bytes" is not a question about text somebody typed, and answering it anyway would report
        // a hit whose preview the user cannot connect to anything.
        try write("a.txt", "x")
        var q = SearchQuery(nameMask: "*", startDirectory: root.path)
        q.searchComments = true
        q.hexContent = Array("customer".utf8)
        let result5 = await hits(q, comments: ["a.txt": "the customer's original"]).count
        XCTAssertEqual(result5, 0)
    }

    func testAnEmptyCommentIsNotAMatch() async throws {
        try write("a.txt", "x")
        let result6 = await hits(query("customer"), comments: ["a.txt": ""]).count
        XCTAssertEqual(result6, 0)
    }

    func testTheNameMaskStillLimitsTheSearch() async throws {
        try write("a.txt", "x")
        try write("b.log", "x")
        var q = SearchQuery(nameMask: "*.log", startDirectory: root.path, contentText: "customer")
        q.searchComments = true
        let found = await hits(q, comments: ["a.txt": "customer", "b.log": "customer"])
        XCTAssertEqual(found.map(\.name), ["b.log"])
    }
}
