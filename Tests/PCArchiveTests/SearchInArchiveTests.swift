// SearchInArchiveTests.swift - FileSearchEngine descending into zip-family
// archives via an ArchiveFS opener (search-in-archives option).

import XCTest
import PCVFS
@testable import PCArchive

final class SearchInArchiveTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: "/usr/bin/zip"), "zip missing")
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("SearchArch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { if let dir { try? FileManager.default.removeItem(at: dir) } }

    /// Build `dir/<name>` (a zip) containing inner/secret.txt with `content`.
    private func makeZip(named name: String, content: String) throws {
        let payload = dir.appendingPathComponent("payload")
        let inner = payload.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try content.data(using: .utf8)!.write(to: inner.appendingPathComponent("secret.txt"))
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.arguments = ["-r", "-q", dir.appendingPathComponent(name).path, "inner"]
        p.currentDirectoryURL = payload
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        try? FileManager.default.removeItem(at: payload)
    }

    private var opener: FileSearchEngine.ArchiveOpener {
        { fs, path in
            let localURL: URL
            if fs is LocalFS {
                localURL = URL(fileURLWithPath: path)
            } else if let url = (try? await fs.localFileIfAvailable(
                VFSPath(filesystemId: fs.scheme, path: path))) ?? nil {
                localURL = url
            } else { return nil }
            return ArchiveFS(archiveFileURL: localURL, fsID: "zip:\(localURL.path)")
        }
    }

    private func collect(_ query: SearchQuery) async -> [String] {
        var hits: [String] = []
        for await hit in await FileSearchEngine().search(query, fs: LocalFS(), archiveOpener: opener) {
            hits.append(hit.path)
        }
        return hits
    }

    func test_contentSearch_descendsIntoZip_whenEnabled() async throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "plain note".data(using: .utf8)!.write(to: dir.appendingPathComponent("note.txt"))
        try makeZip(named: "data.zip", content: "the needle is here\n")

        let on = await collect(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                           contentText: "needle", searchArchives: true))
        XCTAssertTrue(on.contains { $0.contains("data.zip") && $0.hasSuffix("secret.txt") },
                      "inner archive file not found: \(on)")

        let off = await collect(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                            contentText: "needle", searchArchives: false))
        XCTAssertFalse(off.contains { $0.hasSuffix("secret.txt") }, "should not descend when off: \(off)")
    }

    func test_zipFamilyExtension_jar_isSearched() async throws {
        try makeZip(named: "app.jar", content: "META needle INF\n")
        let hits = await collect(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                             contentText: "needle", searchArchives: true))
        XCTAssertTrue(hits.contains { $0.contains("app.jar") && $0.hasSuffix("secret.txt") },
                      ".jar not searched: \(hits)")
    }

    func test_nestedArchive_isSearchedRecursively() async throws {
        // Build inner.zip (containing inner/secret.txt), then wrap it in outer.zip.
        try makeZip(named: "inner.zip", content: "deeply buried needle\n")
        let wrap = dir.appendingPathComponent("wrap")
        try FileManager.default.createDirectory(at: wrap, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: dir.appendingPathComponent("inner.zip"),
                                         to: wrap.appendingPathComponent("inner.zip"))
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.arguments = ["-r", "-q", dir.appendingPathComponent("outer.zip").path, "inner.zip"]
        p.currentDirectoryURL = wrap
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        try? FileManager.default.removeItem(at: wrap)

        let hits = await collect(SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                                             contentText: "needle", searchArchives: true))
        XCTAssertTrue(hits.contains { $0.contains("outer.zip") && $0.contains("inner.zip")
                                       && $0.hasSuffix("secret.txt") },
                      "nested archive not searched: \(hits)")
    }
}
