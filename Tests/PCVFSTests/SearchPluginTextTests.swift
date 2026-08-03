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

/// The size of the text a full-text provider may return.
///
/// Split out because the limit is not in the search at all but in the host's content-plugin bridge,
/// and a review found it set to 1 KB — twenty lines of a decompiled class, with everything below
/// reported as absent.
final class SearchPluginTextSizeTests: XCTestCase {
    private var dir: URL!

    private struct LongTextProvider: ContentFieldProvider {
        let providerName = "long"
        let fields = [ContentField(id: "source", title: "Source", isFullText: true)]
        func value(fieldID: String, forFileAt url: URL) async -> ContentValue {
            var lines = ["// a long decompiled result"]
            for i in 0..<400 { lines.append("    private int filler\(i) = \(i);") }
            lines.append("    static final String DEEP = \"needle far below the first kilobyte\";")
            return .string(lines.joined(separator: "\n"))
        }
    }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("SearchSize-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "bytes".write(to: dir.appendingPathComponent("Hello.class"), atomically: true, encoding: .utf8)
    }
    override func tearDownWithError() throws { if let dir { try? FileManager.default.removeItem(at: dir) } }

    func testAMatchFarIntoTheProvidedTextIsFound() async {
        let registry = ContentFieldRegistry()
        registry.register(LongTextProvider())
        var query = SearchQuery(nameMask: "*.class", startDirectory: dir.path,
                                contentText: "needle far below the first kilobyte")
        query.searchPluginText = true
        var hits: [String] = []
        for await hit in await FileSearchEngine().search(
            query, fs: LocalFS(),
            textProvider: { path in await registry.fullText(forFileAt: URL(fileURLWithPath: path)) }) {
            hits.append((hit.path as NSString).lastPathComponent)
            // The line number must come from the *provided* text, not from the file's own bytes.
            XCTAssertEqual(hit.matchLine, 402)
        }
        XCTAssertEqual(hits, ["Hello.class"])
    }
}

/// The provider-backed search runs several files at once (review item 3).
///
/// The point is not raw speed but that the work being overlapped is an *engine run*: one decompiler
/// invocation per file, seconds each. A sequential walk over a package of classes is minutes.
final class SearchPluginTextConcurrencyTests: XCTestCase {
    private var dir: URL!

    private actor Tracker {
        private(set) var peak = 0
        private var active = 0
        func enter() { active += 1; peak = max(peak, active) }
        func leave() { active -= 1 }
    }

    private struct SlowProvider: ContentFieldProvider {
        let providerName = "slow"
        let fields = [ContentField(id: "source", title: "Source", isFullText: true)]
        let tracker: Tracker
        func value(fieldID: String, forFileAt url: URL) async -> ContentValue {
            await tracker.enter()
            // Stands in for starting a decompiler: long enough that overlap is measurable.
            try? await Task.sleep(nanoseconds: 120_000_000)
            await tracker.leave()
            return .string("class X { String s = \"needle\"; }")
        }
    }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("SearchConc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for i in 0..<6 {
            try "bytes".write(to: dir.appendingPathComponent("F\(i).class"), atomically: true, encoding: .utf8)
        }
    }
    override func tearDownWithError() throws { if let dir { try? FileManager.default.removeItem(at: dir) } }

    func testSeveralFilesAreDecompiledAtOnce() async {
        let tracker = Tracker()
        let registry = ContentFieldRegistry()
        registry.register(SlowProvider(tracker: tracker))
        var query = SearchQuery(nameMask: "*.class", startDirectory: dir.path, contentText: "needle")
        query.searchPluginText = true
        var hits = 0
        for await _ in await FileSearchEngine().search(
            query, fs: LocalFS(),
            textProvider: { path in await registry.fullText(forFileAt: URL(fileURLWithPath: path)) }) {
            hits += 1
        }
        XCTAssertEqual(hits, 6)
        let peak = await tracker.peak
        XCTAssertGreaterThan(peak, 1,
                             "the provider was called one file at a time — the concurrent path is not "
                             + "being used, which is how this started: correctness was fixed by making "
                             + "it sequential and the cost was left behind")
    }
}

/// Searching inside the provider instead of copying its text out (review item 2 / F-354).
final class SearchProviderSideSearchTests: XCTestCase {
    private var dir: URL!

    /// A provider that refuses to hand over its text at all and can only search it — the shape the
    /// feature exists for, since a document does not fit a buffer.
    private struct SearchOnlyProvider: ContentFieldProvider {
        let providerName = "searchonly"
        let fields = [ContentField(id: "source", title: "Source", isFullText: true)]
        func value(fieldID: String, forFileAt url: URL) async -> ContentValue { .none }
        func searchFullText(fieldID: String, forFileAt url: URL, needle: String,
                            matchCase: Bool) async -> (line: Int, preview: String)? {
            guard url.pathExtension == "class" else { return nil }
            let options: String.CompareOptions = matchCase ? [] : [.caseInsensitive]
            guard "a class whose text nobody copied".range(of: needle, options: options) != nil else {
                return nil
            }
            return (99, "line 99 as the provider sees it")
        }
    }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("SearchSide-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "bytes".write(to: dir.appendingPathComponent("Hello.class"), atomically: true, encoding: .utf8)
    }
    override func tearDownWithError() throws { if let dir { try? FileManager.default.removeItem(at: dir) } }

    func testTheProvidersOwnSearchIsUsedAndItsLineReported() async {
        let registry = ContentFieldRegistry()
        registry.register(SearchOnlyProvider())
        var query = SearchQuery(nameMask: "*.class", startDirectory: dir.path, contentText: "nobody copied")
        query.searchPluginText = true
        var hits: [SearchHit] = []
        for await hit in await FileSearchEngine().search(
            query, fs: LocalFS(),
            textProvider: { path in await registry.fullText(forFileAt: URL(fileURLWithPath: path)) },
            textSearcher: { path, needle, matchCase in
                await registry.searchFullText(forFileAt: URL(fileURLWithPath: path),
                                              needle: needle, matchCase: matchCase)
            }) {
            hits.append(hit)
        }
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.matchLine, 99, "the line must come from the provider, not be re-derived")
        XCTAssertEqual(hits.first?.matchPreview, "line 99 as the provider sees it")
    }

    func testARegexQueryIsNotDelegatedToTheProvider() async {
        let registry = ContentFieldRegistry()
        registry.register(SearchOnlyProvider())
        var query = SearchQuery(nameMask: "*.class", startDirectory: dir.path,
                                contentText: "nobody.*copied", useRegex: true)
        query.searchPluginText = true
        var hits = 0
        for await _ in await FileSearchEngine().search(
            query, fs: LocalFS(),
            textProvider: { path in await registry.fullText(forFileAt: URL(fileURLWithPath: path)) },
            textSearcher: { path, needle, matchCase in
                await registry.searchFullText(forFileAt: URL(fileURLWithPath: path),
                                              needle: needle, matchCase: matchCase)
            }) {
            hits += 1
        }
        // A regex is the host's dialect, not something a plugin promised to speak. Delegating it would
        // have this provider match "nobody.*copied" literally and answer line 99 — a wrong hit.
        XCTAssertEqual(hits, 0)
    }
}
