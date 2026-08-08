// SPDX-License-Identifier: Apache-2.0
// SearchTemplateTests.swift - Round-trip + query-mapping tests for saved search
// templates and their JSON store.

import XCTest
@testable import PCVFS

final class SearchTemplateTests: XCTestCase {
    private var url: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCVFSTemplates-\(UUID().uuidString)/templates.json")
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        url = nil
        try super.tearDownWithError()
    }

    func test_missingFile_loadsEmpty() {
        XCTAssertTrue(SearchTemplateStore(url: url).load().isEmpty)
    }

    func test_saveLoad_roundTrips() {
        let store = SearchTemplateStore(url: url)
        let t = SearchTemplate(name: "Swift TODOs", nameMask: "*.swift", contentText: "TODO",
                               wholeWord: true, modifiedAfter: Date(timeIntervalSince1970: 1_600_000_000),
                               contentEncodingAware: true, maxDepth: 3)
        XCTAssertTrue(store.save([t]))
        let loaded = store.load()
        XCTAssertEqual(loaded, [t])
    }

    func test_upsert_replacesByNameCaseInsensitive_andSorts() {
        let store = SearchTemplateStore(url: url)
        store.upsert(SearchTemplate(name: "Beta", nameMask: "*.b"))
        store.upsert(SearchTemplate(name: "alpha", nameMask: "*.a"))
        let after = store.upsert(SearchTemplate(name: "BETA", nameMask: "*.b2"))   // replaces "Beta"
        XCTAssertEqual(after.map(\.name), ["alpha", "BETA"])                        // sorted, one Beta
        XCTAssertEqual(after.first(where: { $0.name == "BETA" })?.nameMask, "*.b2")
    }

    func test_remove() {
        let store = SearchTemplateStore(url: url)
        store.upsert(SearchTemplate(name: "one"))
        store.upsert(SearchTemplate(name: "two"))
        let after = store.remove(named: "ONE")
        XCTAssertEqual(after.map(\.name), ["two"])
    }

    func test_makeQuery_mapsFieldsIncludingHex() {
        let t = SearchTemplate(name: "hex", nameMask: "*", caseSensitive: true,
                               hexContent: "48 65", minSize: 10, includeDirectories: true, maxDepth: 2)
        let q = t.makeQuery(startDirectory: "/tmp", scopePaths: ["/tmp/a"])
        XCTAssertEqual(q.nameMask, "*")
        XCTAssertEqual(q.startDirectory, "/tmp")
        XCTAssertEqual(q.maxDepth, 2)
        XCTAssertTrue(q.caseSensitive)
        XCTAssertEqual(q.minSize, 10)
        XCTAssertTrue(q.includeDirectories)
        XCTAssertEqual(q.hexContent, [0x48, 0x65])
        XCTAssertEqual(q.scopePaths, ["/tmp/a"])
    }

    // MARK: - What happens when the format changes underneath (F-156)
    //
    // These live in one JSON file that Codable writes and reads, and a decode failure becomes `?? []` —
    // i.e. *every saved template silently disappears*. That is one added non-optional property away at
    // any time, and the user's reaction would be "the app forgot my searches", with nothing in the file
    // to suggest it is still all there.

    private func makeDir() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
    }

    func testAFileFromAnOlderVersionStillLoads() throws {
        try makeDir()
        // Only the fields an early version would have written. Everything since must have a default.
        let older = """
        [{"name":"Große Bilder","nameMask":"*.jpg","caseSensitive":false,"useRegex":false,
          "wholeWord":false,"includeDirectories":false,"contentEncodingAware":false,"maxDepth":0}]
        """
        let url = self.url.deletingLastPathComponent().appendingPathComponent("older.json")
        try Data(older.utf8).write(to: url)

        let loaded = SearchTemplateStore(url: url).load()
        XCTAssertEqual(loaded.map { $0.name }, ["Große Bilder"],
                       "a template file written by an earlier version must not vanish on load")
        XCTAssertEqual(loaded.first?.nameMask, "*.jpg")
    }

    func testAFileWithAnUnknownFutureFieldStillLoads() throws {
        try makeDir()
        // The other direction: a newer version wrote a field this one does not know. Ignoring it beats
        // discarding the user's templates.
        let newer = """
        [{"name":"Neu","nameMask":"*.md","caseSensitive":false,"useRegex":false,"wholeWord":false,
          "includeDirectories":false,"contentEncodingAware":false,"maxDepth":0,
          "somethingAddedLater":"whatever"}]
        """
        let url = self.url.deletingLastPathComponent().appendingPathComponent("newer.json")
        try Data(newer.utf8).write(to: url)
        XCTAssertEqual(SearchTemplateStore(url: url).load().map { $0.name }, ["Neu"])
    }

    func testAGenuinelyBrokenFileIsNotMistakenForAnEmptyList() throws {
        try makeDir()
        // Corrupt is corrupt — but it must not be indistinguishable from "no templates yet", because
        // saving over it would then destroy what could still be recovered by hand.
        let url = self.url.deletingLastPathComponent().appendingPathComponent("broken.json")
        try Data("this is not json".utf8).write(to: url)
        let store = SearchTemplateStore(url: url)
        XCTAssertTrue(store.load().isEmpty)
        // The file is still there for the user to look at.
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
}
