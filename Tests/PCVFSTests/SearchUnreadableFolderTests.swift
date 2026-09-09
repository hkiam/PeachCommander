// SPDX-License-Identifier: Apache-2.0
// SearchUnreadableFolderTests.swift - A folder a search could not enter is named, not skipped.
//
// `SearchNotice`'s own header says every skip a search makes produces one of these, and it exists
// for the reason it states: "a search that quietly declines to open a file reads exactly like 'the
// term is not in there'." A directory whose listing failed produced nothing at all — one step
// further out, and with the same consequence: somebody searches, finds nothing, and concludes the
// file is not there.

import XCTest
@testable import PCVFS

final class SearchUnreadableFolderTests: XCTestCase {
    private var tempDir: URL!
    private var fs: LocalFS!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-searchunread-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fs = LocalFS()
    }
    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
    }

    private func collect(_ stream: AsyncStream<SearchHit>) async -> [SearchHit] {
        var hits: [SearchHit] = []
        for await hit in stream { hits.append(hit) }
        return hits
    }

    /// The claim: the reachable half is still found, and the folder that could not be read is
    /// reported by name with a reason.
    func test_anUnreadableFolderIsReportedInsteadOfSilentlySkipped() async throws {
        let open = tempDir.appendingPathComponent("open", isDirectory: true)
        let locked = tempDir.appendingPathComponent("locked", isDirectory: true)
        for d in [open, locked] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
        try Data("x".utf8).write(to: open.appendingPathComponent("wanted.txt"))
        try Data("x".utf8).write(to: locked.appendingPathComponent("wanted.txt"))
        try FileManager.default.setAttributes([.posixPermissions: 0o000],
                                              ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                        ofItemAtPath: locked.path) }
        // The premise. Without it the fixture proves nothing.
        XCTAssertNil(try? FileManager.default.contentsOfDirectory(atPath: locked.path))

        let engine = FileSearchEngine()
        let query = SearchQuery(nameMask: "wanted.txt", startDirectory: tempDir.path, maxDepth: 5)
        let hits = await collect(engine.search(query, fs: fs))

        // The half it could read is found — the search did not abort, which would be the worse
        // answer and is what the old comment rightly rejected.
        XCTAssertEqual(hits.count, 1, "the readable half was not searched: \(hits.map(\.path))")
        XCTAssertTrue(hits[0].path.contains("open"), hits[0].path)

        // And the half it could not read is *said*, which is the whole point.
        let notices = await engine.takeNotices()
        XCTAssertEqual(notices.count, 1, "the unreadable folder was skipped silently")
        XCTAssertEqual(notices.first?.reason, .unreadableDirectory)
        XCTAssertTrue(notices.first?.path.contains("locked") ?? false,
                      "the folder has to be named: \(notices.first?.path ?? "nil")")
    }

    /// An ordinary search over readable folders reports nothing. The control: a notice that always
    /// appears is one nobody reads, and the status line would then always carry a warning.
    func test_aReadableTreeReportsNoNotice() async throws {
        let sub = tempDir.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: sub.appendingPathComponent("wanted.txt"))

        let engine = FileSearchEngine()
        let query = SearchQuery(nameMask: "wanted.txt", startDirectory: tempDir.path, maxDepth: 5)
        let hits = await collect(engine.search(query, fs: fs))
        XCTAssertEqual(hits.count, 1)
        let notices = await engine.takeNotices()
        XCTAssertTrue(notices.isEmpty, "\(notices)")
    }

    /// An **empty** readable folder is not a skip either — the two are indistinguishable after the
    /// listing, and confusing them would put a warning on every ordinary search.
    func test_anEmptyReadableFolderIsNotAnotice() async throws {
        let hollow = tempDir.appendingPathComponent("hollow", isDirectory: true)
        try FileManager.default.createDirectory(at: hollow, withIntermediateDirectories: true)

        let engine = FileSearchEngine()
        let query = SearchQuery(nameMask: "*", startDirectory: tempDir.path, maxDepth: 5)
        _ = await collect(engine.search(query, fs: fs))
        let notices = await engine.takeNotices()
        XCTAssertTrue(notices.isEmpty, "an empty folder was reported as a skip: \(notices)")
    }
}
