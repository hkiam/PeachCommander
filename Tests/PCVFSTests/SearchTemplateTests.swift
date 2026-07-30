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
}
