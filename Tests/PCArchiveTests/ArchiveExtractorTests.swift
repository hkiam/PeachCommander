// SPDX-License-Identifier: Apache-2.0
// ArchiveExtractorTests.swift - Extract a nested zip (built with ZipWriter) through
// ArchiveFS and verify every member lands on disk with the right content.

import XCTest
@testable import PCArchive
@testable import PCVFS

final class ArchiveExtractorTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCArchiveExtract-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        try super.tearDownWithError()
    }

    func test_extractAll_writesEveryMemberWithStructure() async throws {
        let zipURL = tempDir.appendingPathComponent("a.zip")
        try ZipWriter.create(at: zipURL, files: [
            (path: "readme.txt", data: Data("top".utf8)),
            (path: "docs/guide.txt", data: Data("guide".utf8)),
            (path: "docs/notes/detail.txt", data: Data("detail".utf8)),
        ])
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: zipURL, fsID: "z"))
        let dest = tempDir.appendingPathComponent("out", isDirectory: true)

        let result = try await ArchiveExtractor.extractAll(from: fs, to: dest)

        XCTAssertEqual(result.files, 3)
        XCTAssertEqual(result.bytes, Int64("top".count + "guide".count + "detail".count))
        XCTAssertEqual(try String(contentsOf: dest.appendingPathComponent("readme.txt"), encoding: .utf8), "top")
        XCTAssertEqual(try String(contentsOf: dest.appendingPathComponent("docs/guide.txt"), encoding: .utf8), "guide")
        XCTAssertEqual(try String(contentsOf: dest.appendingPathComponent("docs/notes/detail.txt"), encoding: .utf8), "detail")
    }
}
