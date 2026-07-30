// SearchMmapParallelTests.swift - uncapped mmap content search + parallel
// correctness for FileSearchEngine (F-151).

import XCTest
@testable import PCVFS

final class SearchMmapParallelTests: XCTestCase {
    private var tempDir: URL!
    private var fs: LocalFS!

    override func setUpWithError() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCVFSMmap-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDir = dir
        fs = LocalFS()
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        tempDir = nil; fs = nil
    }

    private func collect(_ stream: AsyncStream<SearchHit>) async -> [SearchHit] {
        var hits: [SearchHit] = []
        for await hit in stream { hits.append(hit) }
        return hits
    }

    /// A content match past the old 16 MB cap must still be found, with the right
    /// (large) line number — proving the whole file is searched via mmap (F-151).
    func testContentMatchBeyond16MB() async throws {
        let url = tempDir.appendingPathComponent("huge.txt")
        var data = Data()
        let filler = Data("this is a filler line that pads the file quickly\n".utf8)
        // ~18 MB of filler, then the marker on its own line.
        while data.count < 18 * 1024 * 1024 { data.append(filler) }
        let fillerLines = data.count / filler.count
        data.append(Data("THE_UNIQUE_MARKER_TOKEN\n".utf8))
        try data.write(to: url)

        let q = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path,
                            contentText: "THE_UNIQUE_MARKER_TOKEN")
        let hits = await collect(await FileSearchEngine().search(q, fs: fs))
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual((hits.first?.path as NSString?)?.lastPathComponent, "huge.txt")
        // The marker sits just after `fillerLines` lines → 1-based line fillerLines+1.
        XCTAssertEqual(hits.first?.matchLine, fillerLines + 1)
        XCTAssertEqual(hits.first?.matchPreview, "THE_UNIQUE_MARKER_TOKEN")
    }

    /// Concurrent per-file matching must return exactly the files that contain the
    /// term — no misses, no duplicates — regardless of completion order (F-151).
    func testParallelSearchReturnsExactSet() async throws {
        var expected = Set<String>()
        for i in 0..<40 {
            let name = "file\(i).log"
            let body = (i % 3 == 0) ? "needle_XYZ is here in file \(i)" : "nothing to see in file \(i)"
            try Data(body.utf8).write(to: tempDir.appendingPathComponent(name))
            if i % 3 == 0 { expected.insert(name) }
        }
        let q = SearchQuery(nameMask: "*.log", startDirectory: tempDir.path, contentText: "needle_XYZ")
        let hits = await collect(await FileSearchEngine().search(q, fs: fs))
        let names = hits.map { ($0.path as NSString).lastPathComponent }
        XCTAssertEqual(Set(names), expected)
        XCTAssertEqual(names.count, names.count, "no duplicate hits")
        XCTAssertEqual(Set(names).count, names.count, "hits must be unique")
    }

    /// Whole-word matching over the mmap path rejects substring-only occurrences.
    func testWholeWordOverMmap() async throws {
        try Data("prefix_cat and a lone cat here\n".utf8).write(to: tempDir.appendingPathComponent("a.txt"))
        try Data("only concatenation, no standalone\n".utf8).write(to: tempDir.appendingPathComponent("b.txt"))
        let q = SearchQuery(nameMask: "*.txt", startDirectory: tempDir.path,
                            contentText: "cat", wholeWord: true)
        let hits = await collect(await FileSearchEngine().search(q, fs: fs))
        XCTAssertEqual(Set(hits.map { ($0.path as NSString).lastPathComponent }), ["a.txt"])
    }
}
