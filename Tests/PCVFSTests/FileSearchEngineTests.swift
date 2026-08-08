// SPDX-License-Identifier: Apache-2.0
// FileSearchEngineTests.swift - Tests for `FileSearchEngine` against a
// temporary on-disk tree, driven through `LocalFS` (the same VFS the
// engine is meant to walk in production).

import XCTest
@testable import PCVFS

final class FileSearchEngineTests: XCTestCase {
    private var tempDir: URL!
    private var fs: LocalFS!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCVFSSearch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDir = dir
        fs = LocalFS()
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        fs = nil
        try super.tearDownWithError()
    }

    // MARK: - Fixture helpers

    private func write(_ relativePath: String, contents: String = "x") throws -> String {
        let url = tempDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contents.utf8).write(to: url)
        return url.path
    }

    private func makeDirectory(_ relativePath: String) throws {
        try FileManager.default.createDirectory(
            at: tempDir.appendingPathComponent(relativePath),
            withIntermediateDirectories: true
        )
    }

    private func collect(_ stream: AsyncStream<SearchHit>) async -> [SearchHit] {
        var hits: [SearchHit] = []
        for await hit in stream { hits.append(hit) }
        return hits
    }

    @discardableResult
    private func writeBytes(_ relativePath: String, _ bytes: [UInt8]) throws -> String {
        let url = tempDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(bytes).write(to: url)
        return url.path
    }

    private func setModified(_ path: String, _ date: Date) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: path)
    }

    // MARK: - Whole-word / hex / date / directory filters

    // F-150: multiple start directories are all walked.
    func test_extraStartDirectories_walkAllRoots() async throws {
        _ = try write("dirA/a.txt")
        _ = try write("dirB/b.txt")
        _ = try write("dirC/c.txt")   // not searched
        let engine = FileSearchEngine()
        var q = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.appendingPathComponent("dirA").path)
        q.extraStartDirectories = [tempDir.appendingPathComponent("dirB").path]
        let names = Set(await collect(await engine.search(q, fs: fs)).map { ($0.path as NSString).lastPathComponent })
        XCTAssertEqual(names, ["a.txt", "b.txt"])   // dirC excluded
    }

    // F-150: exclude mask via "include|exclude".
    func test_excludeMask_pipeExcludesMatches() async throws {
        _ = try write("keep.txt")
        _ = try write("skip.bak")
        _ = try write("also.txt")
        let engine = FileSearchEngine()
        let q = SearchQuery(nameMask: "*.txt|*.bak", startDirectory: tempDir.path)
        let names = Set(await collect(await engine.search(q, fs: fs)).map { ($0.path as NSString).lastPathComponent })
        XCTAssertEqual(names, ["keep.txt", "also.txt"])   // *.bak excluded
    }

    // F-152: attribute filters (tri-state hidden / read-only).
    func test_attributeFilter_hiddenAndReadOnly() async throws {
        _ = try write("visible.txt")
        _ = try write(".secret.txt")                       // hidden (dot-prefixed)
        let ro = try write("locked.txt")
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: ro)  // read-only
        let engine = FileSearchEngine()
        let base = { SearchQuery(nameMask: "*.txt", startDirectory: self.tempDir.path) }

        // Only hidden files.
        var q = base(); q.requireHidden = true
        let hidden = await collect(await engine.search(q, fs: fs))
        XCTAssertEqual(Set(hidden.map { ($0.path as NSString).lastPathComponent }), [".secret.txt"])

        // Exclude hidden files.
        q = base(); q.requireHidden = false
        let notHidden = await collect(await engine.search(q, fs: fs))
        XCTAssertFalse(notHidden.contains { ($0.path as NSString).lastPathComponent == ".secret.txt" })
        XCTAssertTrue(notHidden.contains { ($0.path as NSString).lastPathComponent == "visible.txt" })

        // Only read-only files.
        q = base(); q.requireReadOnly = true
        let readOnly = await collect(await engine.search(q, fs: fs))
        XCTAssertEqual(Set(readOnly.map { ($0.path as NSString).lastPathComponent }), ["locked.txt"])

        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: ro)  // restore for cleanup
    }

    func test_wholeWord_matchesOnlyBoundedOccurrences() async throws {
        let hit = try write("hit.txt", contents: "the cat sat")
        _ = try write("miss.txt", contents: "concatenate")
        let engine = FileSearchEngine()
        let q = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path, contentText: "cat", wholeWord: true)
        let hits = await collect(await engine.search(q, fs: fs))
        XCTAssertEqual(Set(hits.map(\.path)), [hit])
    }

    func test_wholeWordOff_matchesSubstring() async throws {
        let a = try write("a.txt", contents: "concatenate")
        let engine = FileSearchEngine()
        let q = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path, contentText: "cat", wholeWord: false)
        let hits = await collect(await engine.search(q, fs: fs))
        XCTAssertEqual(Set(hits.map(\.path)), [a])
    }

    func test_hexContent_matchesByteSequence() async throws {
        let bin = try writeBytes("bin.dat", [0x00, 0xFF, 0x41])
        _ = try writeBytes("other.dat", [0x41, 0x42])   // 0x41 present, but not preceded by 0xFF
        let engine = FileSearchEngine()
        let q = SearchQuery(nameMask: "*", startDirectory: tempDir.path, hexContent: [0xFF, 0x41])
        let hits = await collect(await engine.search(q, fs: fs))
        XCTAssertEqual(Set(hits.map(\.path)), [bin])
    }

    func test_modifiedAfter_excludesOlderFiles() async throws {
        let old = try write("old.txt")
        let new = try write("new.txt")
        try setModified(old, Date(timeIntervalSinceNow: -3600))
        try setModified(new, Date(timeIntervalSinceNow: 3600))
        let engine = FileSearchEngine()
        let q = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path, modifiedAfter: Date())
        let hits = await collect(await engine.search(q, fs: fs))
        XCTAssertEqual(Set(hits.map(\.path)), [new])
    }

    func test_modifiedBefore_excludesNewerFiles() async throws {
        let old = try write("old.txt")
        let new = try write("new.txt")
        try setModified(old, Date(timeIntervalSinceNow: -3600))
        try setModified(new, Date(timeIntervalSinceNow: 3600))
        let engine = FileSearchEngine()
        let q = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path, modifiedBefore: Date())
        let hits = await collect(await engine.search(q, fs: fs))
        XCTAssertEqual(Set(hits.map(\.path)), [old])
    }

    func test_includeDirectories_emitsMatchingDirsNotFiles() async throws {
        _ = try write("logs/a.txt")
        try makeDirectory("data")
        let engine = FileSearchEngine()
        let q = SearchQuery(nameMask: "logs", startDirectory: tempDir.path, includeDirectories: true)
        let hits = await collect(await engine.search(q, fs: fs))
        let names = Set(hits.map { ($0.path as NSString).lastPathComponent })
        XCTAssertTrue(names.contains("logs"))
        XCTAssertFalse(names.contains("data"))
        XCTAssertFalse(names.contains("a.txt"))
    }

    func test_includeDirectoriesOff_doesNotEmitDirs() async throws {
        try makeDirectory("logs")
        let engine = FileSearchEngine()
        let q = SearchQuery(nameMask: "logs", startDirectory: tempDir.path, includeDirectories: false)
        let hits = await collect(await engine.search(q, fs: fs))
        XCTAssertTrue(hits.isEmpty)
    }

    // MARK: - Encoding-aware content search

    private func writeUTF16(_ name: String, _ text: String) throws -> String {
        let url = tempDir.appendingPathComponent(name)
        try text.data(using: .utf16)!.write(to: url)   // includes a BOM
        return url.path
    }

    func test_encodingAware_findsTextInUTF16File() async throws {
        let path = try writeUTF16("u16.txt", "hello world")
        let engine = FileSearchEngine()
        // Raw byte search can't find ASCII "hello" in UTF-16 bytes.
        let plain = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path, contentText: "hello")
        let plainHits = await collect(await engine.search(plain, fs: fs))
        XCTAssertTrue(plainHits.isEmpty)
        // Encoding-aware decodes first, so it matches.
        let aware = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path,
                                contentText: "hello", contentEncodingAware: true)
        let awareHits = await collect(await engine.search(aware, fs: fs))
        XCTAssertEqual(Set(awareHits.map(\.path)), [path])
    }

    func test_encodingAware_wholeWordInUTF16() async throws {
        let hit = try writeUTF16("hit.txt", "the cat sat")
        _ = try writeUTF16("miss.txt", "concatenate")
        let engine = FileSearchEngine()
        let q = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path,
                            contentText: "cat", wholeWord: true, contentEncodingAware: true)
        let hits = await collect(await engine.search(q, fs: fs))
        XCTAssertEqual(Set(hits.map(\.path)), [hit])
    }

    func test_encodingAware_caseInsensitiveUTF16() async throws {
        let path = try writeUTF16("u.txt", "Hello")
        let engine = FileSearchEngine()
        let q = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path,
                            contentText: "hello", caseSensitive: false, contentEncodingAware: true)
        let hits = await collect(await engine.search(q, fs: fs))
        XCTAssertEqual(Set(hits.map(\.path)), [path])
    }

    // MARK: - Match line / preview (grep-style results)

    func test_contentMatch_reportsLineAndPreview() async throws {
        _ = try write("f.txt", contents: "alpha\nbeta needle here\ngamma")
        let engine = FileSearchEngine()
        let q = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path, contentText: "needle")
        let hits = await collect(await engine.search(q, fs: fs))
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.matchLine, 2)
        XCTAssertEqual(hits.first?.matchPreview, "beta needle here")
    }

    func test_contentMatch_encodingAware_reportsLine() async throws {
        _ = try writeUTF16("u.txt", "one\ntwo target\nthree")
        let engine = FileSearchEngine()
        let q = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path,
                            contentText: "target", contentEncodingAware: true)
        let hits = await collect(await engine.search(q, fs: fs))
        XCTAssertEqual(hits.first?.matchLine, 2)
        XCTAssertEqual(hits.first?.matchPreview, "two target")
    }

    func test_nameOnlyMatch_hasNoLineInfo() async throws {
        _ = try write("a.txt")
        let engine = FileSearchEngine()
        let q = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path)
        let hits = await collect(await engine.search(q, fs: fs))
        XCTAssertEqual(hits.count, 1)
        XCTAssertNil(hits.first?.matchLine)
        XCTAssertNil(hits.first?.matchPreview)
    }

    // MARK: - Name matching

    func test_nameSearch_singleMask_returnsExactTxtFiles() async throws {
        let a = try write("a.txt")
        _ = try write("b.md")
        let notes = try write("notes.txt")
        let c = try write("sub/c.txt")
        let d = try write("sub/nested/d.txt")

        let engine = FileSearchEngine()
        let query = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path)
        let stream = await engine.search(query, fs: fs)
        let hits = await collect(stream)

        XCTAssertEqual(Set(hits.map(\.path)), Set([a, notes, c, d]))
    }

    func test_nameSearch_multiMask_returnsUnionOfBothMasks() async throws {
        let a = try write("a.txt")
        let b = try write("b.md")
        _ = try write("c.log")

        let engine = FileSearchEngine()
        let query = SearchQuery(nameMask: "*.txt *.md", startDirectory: tempDir.path)
        let stream = await engine.search(query, fs: fs)
        let hits = await collect(stream)

        XCTAssertEqual(Set(hits.map(\.path)), Set([a, b]))
    }

    func test_nameSearch_starDotStar_matchesEverythingIncludingExtensionless() async throws {
        let a = try write("a.txt")
        let makefile = try write("Makefile")

        let engine = FileSearchEngine()
        let query = SearchQuery(nameMask: "*.*", startDirectory: tempDir.path)
        let stream = await engine.search(query, fs: fs)
        let hits = await collect(stream)

        XCTAssertEqual(Set(hits.map(\.path)), Set([a, makefile]))
    }

    // MARK: - Depth

    func test_maxDepth1_excludesNestedFiles() async throws {
        let top = try write("top.txt")
        _ = try write("sub/nested.txt")

        let engine = FileSearchEngine()
        let query = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path, maxDepth: 1)
        let stream = await engine.search(query, fs: fs)
        let hits = await collect(stream)

        XCTAssertEqual(hits.map(\.path), [top])
    }

    // MARK: - Size filter

    func test_minSize_excludesSmallFiles() async throws {
        let small = try write("small.txt", contents: "hi")
        let big = try write("big.txt", contents: String(repeating: "x", count: 1024))
        _ = small

        let engine = FileSearchEngine()
        let query = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path, minSize: 100)
        let stream = await engine.search(query, fs: fs)
        let hits = await collect(stream)

        XCTAssertEqual(hits.map(\.path), [big])
    }

    func test_maxSize_excludesLargeFiles() async throws {
        let small = try write("small.txt", contents: "hi")
        _ = try write("big.txt", contents: String(repeating: "x", count: 1024))

        let engine = FileSearchEngine()
        let query = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path, maxSize: 10)
        let stream = await engine.search(query, fs: fs)
        let hits = await collect(stream)

        XCTAssertEqual(hits.map(\.path), [small])
    }

    // MARK: - Content search

    func test_contentSearch_findsOnlyMatchingFiles() async throws {
        let hasNeedle = try write("has.txt", contents: "before NEEDLE after")
        _ = try write("without.txt", contents: "nothing here")

        let engine = FileSearchEngine()
        let query = SearchQuery(
            nameMask: "*.txt",
            startDirectory: tempDir.path,
            contentText: "NEEDLE",
            caseSensitive: true
        )
        let stream = await engine.search(query, fs: fs)
        let hits = await collect(stream)

        XCTAssertEqual(hits.map(\.path), [hasNeedle])
    }

    func test_contentSearch_caseInsensitive_matchesDifferentCase() async throws {
        let hasNeedle = try write("has.txt", contents: "before NEEDLE after")

        let engine = FileSearchEngine()
        let query = SearchQuery(
            nameMask: "*.txt",
            startDirectory: tempDir.path,
            contentText: "needle",
            caseSensitive: false
        )
        let stream = await engine.search(query, fs: fs)
        let hits = await collect(stream)

        XCTAssertEqual(hits.map(\.path), [hasNeedle])
    }

    func test_contentSearch_caseSensitive_doesNotMatchDifferentCase() async throws {
        _ = try write("has.txt", contents: "before NEEDLE after")

        let engine = FileSearchEngine()
        let query = SearchQuery(
            nameMask: "*.txt",
            startDirectory: tempDir.path,
            contentText: "needle",
            caseSensitive: true
        )
        let stream = await engine.search(query, fs: fs)
        let hits = await collect(stream)

        XCTAssertEqual(hits, [])
    }

    // MARK: - Symlinks

    func test_symlinkDirectory_notDescended_noInfiniteLoop() async throws {
        try makeDirectory("sub")
        let inner = try write("sub/inner.txt")
        let top = try write("top.txt")

        // A symlink back to the root directory would cause infinite
        // recursion if directory symlinks were followed.
        let linkPath = tempDir.appendingPathComponent("sub/loop").path
        try FileManager.default.createSymbolicLink(atPath: linkPath, withDestinationPath: tempDir.path)

        let engine = FileSearchEngine()
        let query = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path)
        let stream = await engine.search(query, fs: fs)
        let hits = await collect(stream)

        XCTAssertEqual(Set(hits.map(\.path)), Set([inner, top]))
    }

    // MARK: - No matches

    func test_noMatches_yieldsEmptyStream() async throws {
        _ = try write("a.txt")
        _ = try write("b.md")

        let engine = FileSearchEngine()
        let query = SearchQuery(nameMask: "*.nonexistent", startDirectory: tempDir.path)
        let stream = await engine.search(query, fs: fs)
        let hits = await collect(stream)

        XCTAssertEqual(hits, [])
    }

    // MARK: - Scope: search in selected items only (F-153)

    func test_scopePaths_restrictToSelectedFilesAndDirs() async throws {
        let a = try write("a.txt")
        _ = try write("b.txt")             // outside scope
        let subC = try write("sub/c.txt")  // sub is in scope → recursed
        _ = try write("other/d.txt")       // outside scope

        let engine = FileSearchEngine()
        let subDir = tempDir.appendingPathComponent("sub").path
        let query = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path,
                                scopePaths: [a, subDir])
        let hits = await collect(await engine.search(query, fs: fs))

        XCTAssertEqual(Set(hits.map(\.path)), Set([a, subC]))
    }

    // MARK: - Regex matching (F-154)

    func test_nameRegex_matchesPattern() async throws {
        let img1 = try write("IMG_0001.jpg")
        let img2 = try write("IMG_1234.jpg")
        _ = try write("IMG_12.jpg")        // only 2 digits → no match
        _ = try write("photo.jpg")          // no IMG_ prefix → no match

        let engine = FileSearchEngine()
        let query = SearchQuery(nameMask: "^IMG_[0-9]{4}\\.jpg$",
                                startDirectory: tempDir.path, useRegex: true)
        let hits = await collect(await engine.search(query, fs: fs))

        XCTAssertEqual(Set(hits.map(\.path)), Set([img1, img2]))
    }

    func test_contentRegex_matchesPattern() async throws {
        let hit = try write("with-mail.txt", contents: "contact: alice@example.com please")
        _ = try write("no-mail.txt", contents: "just some words")

        let engine = FileSearchEngine()
        // In regex mode the name mask is also a regex; ".*\.txt$" == "*.txt".
        let query = SearchQuery(nameMask: ".*\\.txt$", startDirectory: tempDir.path,
                                contentText: "[a-z]+@[a-z]+\\.[a-z]+", useRegex: true)
        let hits = await collect(await engine.search(query, fs: fs))

        XCTAssertEqual(hits.map(\.path), [hit])
    }

    func test_invalidNameRegex_yieldsEmptyStream() async throws {
        _ = try write("a.txt")

        let engine = FileSearchEngine()
        // Unbalanced group → invalid pattern → no matches (not a crash).
        let query = SearchQuery(nameMask: "a(b", startDirectory: tempDir.path, useRegex: true)
        let hits = await collect(await engine.search(query, fs: fs))

        XCTAssertEqual(hits, [])
    }

    func test_caseInsensitiveNameRegexByDefault() async throws {
        let upper = try write("README.md")

        let engine = FileSearchEngine()
        let query = SearchQuery(nameMask: "readme\\.md", startDirectory: tempDir.path, useRegex: true)
        let hits = await collect(await engine.search(query, fs: fs))

        XCTAssertEqual(hits.map(\.path), [upper])
    }

    // MARK: - A pattern that will not compile (F-154)
    //
    // The engine fails closed on an invalid regular expression: it finishes the stream with no results.
    // That is the right behaviour and the wrong *answer* on its own, because it is indistinguishable
    // from "the term is not in these files" — so the user believes the files are clean and stops.

    private func regexQuery(name: String = "*", content: String? = nil) -> SearchQuery {
        var q = SearchQuery(nameMask: name, startDirectory: "/tmp")
        q.useRegex = true
        q.contentText = content
        return q
    }

    func testAnUnclosedGroupInTheNameMaskIsReported() throws {
        let bad = try XCTUnwrap(regexQuery(name: "(unclosed").firstInvalidPattern())
        XCTAssertEqual(bad.field, "name")
        XCTAssertEqual(bad.pattern, "(unclosed")
        XCTAssertFalse(bad.reason.isEmpty, "the reason is what makes the message worth showing")
    }

    func testABadContentPatternIsReported() throws {
        let bad = try XCTUnwrap(regexQuery(content: "a{2,1}").firstInvalidPattern())
        XCTAssertEqual(bad.field, "content")
    }

    func testAValidQueryReportsNothing() {
        XCTAssertNil(regexQuery(name: "^report[0-9]+\\.txt$", content: "TODO|FIXME").firstInvalidPattern())
    }

    func testWildcardMasksAreNotJudgedAsRegexes() {
        // Without the regex box ticked, "*.txt" is a wildcard mask and "(" is just a character in a
        // file name — reporting either as a broken pattern would be a false alarm on every search.
        var q = SearchQuery(nameMask: "*.txt", startDirectory: "/tmp")
        q.contentText = "("
        XCTAssertNil(q.firstInvalidPattern())
    }

    func testTheMatchEverythingMasksAreNotCompiled() {
        // "*" and "*.*" mean "everything" even in regex mode and never reach the compiler, so they must
        // not be reported as invalid patterns (a bare "*" is not a legal regex).
        XCTAssertNil(regexQuery(name: "*").firstInvalidPattern())
        XCTAssertNil(regexQuery(name: "*.*").firstInvalidPattern())
    }
}
