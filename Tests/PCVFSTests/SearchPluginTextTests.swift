// SPDX-License-Identifier: Apache-2.0
// SearchPluginTextTests.swift - Searching text a plugin produces instead of a file's bytes (F-351).
//
// The case this exists for: a .class holds bytecode, so searching its bytes for a phrase from the
// source finds nothing, however obviously the phrase is "in" the class. With a plugin that can turn
// the file into text, the same search succeeds — and must keep costing nothing when nobody asks for
// it, which is why the flag and the provider are tested apart from each other.

import XCTest
@testable import PCVFS

final class SearchPluginTextTests: XCTestCase {
    private var dir: URL!

    /// Stands in for the decompiler: the file's bytes say one thing, its "text" another.
    private struct FakeSourceProvider: ContentFieldProvider {
        let providerName = "fake"
        let fields = [ContentField(id: "source", title: "Decompiled Source", isFullText: true),
                      ContentField(id: "size_hint", title: "Size Hint")]
        /// Counts calls, so "cheap when unused" can be asserted rather than assumed.
        let calls: Counter
        func value(fieldID: String, forFileAt url: URL) async -> ContentValue {
            guard fieldID == "source" else { return .integer(0) }
            await calls.increment()
            guard url.pathExtension == "class" else { return .none }
            return .string("package com.example;\nclass \(url.deletingPathExtension().lastPathComponent) {\n"
                + "  String greeting = \"phrase only in the source\";\n}\n")
        }
    }

    private actor Counter {
        private(set) var count = 0
        func increment() { count += 1 }
    }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("SearchPlugin-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Bytes that deliberately do NOT contain the phrase the provider reports.
        try "\u{CA}\u{FE}\u{BA}\u{BE} bytecode Hello\n"
            .write(to: dir.appendingPathComponent("Hello.class"), atomically: true, encoding: .utf8)
        try "phrase only in the source\n"
            .write(to: dir.appendingPathComponent("plain.txt"), atomically: true, encoding: .utf8)
    }
    override func tearDownWithError() throws { if let dir { try? FileManager.default.removeItem(at: dir) } }

    private func collect(_ query: SearchQuery,
                         provider: FileSearchEngine.TextProvider? = nil) async -> [String] {
        var out: [String] = []
        for await hit in await FileSearchEngine().search(query, fs: LocalFS(), textProvider: provider) {
            out.append((hit.path as NSString).lastPathComponent)
        }
        return out.sorted()
    }

    private func registryProvider(_ registry: ContentFieldRegistry) -> FileSearchEngine.TextProvider {
        { path in await registry.fullText(forFileAt: URL(fileURLWithPath: path)) }
    }

    func testWithoutTheFlagOnlyTheFilesOwnBytesAreSearched() async {
        let registry = ContentFieldRegistry()
        registry.register(FakeSourceProvider(calls: Counter()))
        let hits = await collect(SearchQuery(nameMask: "*", startDirectory: dir.path,
                                            contentText: "phrase only in the source"),
                                 provider: registryProvider(registry))
        // The provider is passed but the query never asked, so the class must not be a hit.
        XCTAssertEqual(hits, ["plain.txt"])
    }

    func testWithTheFlagTheClassIsFoundThroughItsText() async {
        let registry = ContentFieldRegistry()
        registry.register(FakeSourceProvider(calls: Counter()))
        var query = SearchQuery(nameMask: "*", startDirectory: dir.path,
                                contentText: "phrase only in the source")
        query.searchPluginText = true
        let hits = await collect(query, provider: registryProvider(registry))
        XCTAssertEqual(hits, ["Hello.class", "plain.txt"])
    }

    func testClaimedFilesAreSearchedAsTextInsteadOfBytes() async {
        let registry = ContentFieldRegistry()
        registry.register(FakeSourceProvider(calls: Counter()))
        var query = SearchQuery(nameMask: "*", startDirectory: dir.path, contentText: "bytecode")
        query.searchPluginText = true
        // "bytecode" is in the class's *bytes* and not in the text the provider reports. The text
        // replaces the bytes rather than adding to them, so this is deliberately not a hit: mixing the
        // two would report a line number from a document the user is not looking at. The tooltip says
        // "instead of the file's bytes" for this reason.
        let hits = await collect(query, provider: registryProvider(registry))
        XCTAssertEqual(hits, [])
    }

    func testAFileTheProviderDeclinesIsStillSearchedAsBytes() async {
        let registry = ContentFieldRegistry()
        registry.register(FakeSourceProvider(calls: Counter()))
        var query = SearchQuery(nameMask: "*", startDirectory: dir.path, contentText: "only in the source")
        query.searchPluginText = true
        // plain.txt is claimed by nobody, so turning the option on must not stop it being searched
        // normally — otherwise enabling the option would quietly narrow every other result.
        let hits = await collect(query, provider: registryProvider(registry))
        XCTAssertEqual(hits, ["Hello.class", "plain.txt"])
    }

    func testNoProviderIsAskedWhenTheFlagIsOff() async {
        let counter = Counter()
        let registry = ContentFieldRegistry()
        registry.register(FakeSourceProvider(calls: counter))
        _ = await collect(SearchQuery(nameMask: "*", startDirectory: dir.path, contentText: "anything"),
                          provider: registryProvider(registry))
        // Producing the text can mean running a decompiler; an ordinary search must never pay for it.
        let count = await counter.count
        XCTAssertEqual(count, 0)
    }

    func testFullTextFieldsAreNotOfferedAsColumns() {
        let registry = ContentFieldRegistry()
        registry.register(FakeSourceProvider(calls: Counter()))
        let columnWorthy = registry.allQualifiedFields().filter { !$0.field.isFullText }
        XCTAssertEqual(columnWorthy.map(\.qualifiedID), ["fake.size_hint"])
        XCTAssertTrue(registry.hasFullTextProvider)
    }

    func testARegistryWithoutAFullTextFieldReportsSo() {
        let registry = ContentFieldRegistry()
        registry.register(ImageInfoContentProvider())
        // What the Find dialog uses to decide whether the option is worth showing at all.
        XCTAssertFalse(registry.hasFullTextProvider)
    }
}
