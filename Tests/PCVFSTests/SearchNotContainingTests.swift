// SearchNotContainingTests.swift - Inverted content search ("NOT containing").

import XCTest
@testable import PCVFS

final class SearchNotContainingTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("SearchNot-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "this file has the needle\n".write(to: dir.appendingPathComponent("has.txt"), atomically: true, encoding: .utf8)
        try "nothing to see here\n".write(to: dir.appendingPathComponent("without.txt"), atomically: true, encoding: .utf8)
    }
    override func tearDownWithError() throws { if let dir { try? FileManager.default.removeItem(at: dir) } }

    private func collect(_ query: SearchQuery) async -> [String] {
        var out: [String] = []
        for await hit in await FileSearchEngine().search(query, fs: LocalFS()) {
            out.append((hit.path as NSString).lastPathComponent)
        }
        return out.sorted()
    }

    func test_notContaining_returnsOnlyFilesWithoutTheTerm() async {
        let hits = await collect(SearchQuery(nameMask: "*.txt", startDirectory: dir.path,
                                             contentText: "needle", contentNotContaining: true))
        XCTAssertEqual(hits, ["without.txt"])
    }

    func test_containing_returnsOnlyFilesWithTheTerm() async {
        let hits = await collect(SearchQuery(nameMask: "*.txt", startDirectory: dir.path,
                                             contentText: "needle", contentNotContaining: false))
        XCTAssertEqual(hits, ["has.txt"])
    }
}
