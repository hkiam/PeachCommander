// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCOperations
import PCFoundation
import PCVFS

final class CommentStoreTests: XCTestCase {
    private var dir: URL!
    private let fs = LocalFS()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-cmt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private var dirPath: VFSPath { VFSPath(filesystemId: "file", path: dir.path) }
    private var descPath: String { dir.appendingPathComponent("descript.ion").path }

    func testSetThenGet() async throws {
        try await CommentStore.setComment("hello world", for: "a.txt", inDir: dirPath, on: fs)
        let c = await CommentStore.comment(for: "a.txt", inDir: dirPath, on: fs)
        XCTAssertEqual(c, "hello world")
        XCTAssertTrue(FileManager.default.fileExists(atPath: descPath))
    }

    func testMultipleFilesAndOverwrite() async throws {
        try await CommentStore.setComment("one", for: "a.txt", inDir: dirPath, on: fs)
        try await CommentStore.setComment("two", for: "b.txt", inDir: dirPath, on: fs)
        try await CommentStore.setComment("one-updated", for: "a.txt", inDir: dirPath, on: fs)
        let a = await CommentStore.comment(for: "a.txt", inDir: dirPath, on: fs)
        let b = await CommentStore.comment(for: "b.txt", inDir: dirPath, on: fs)
        XCTAssertEqual(a, "one-updated")
        XCTAssertEqual(b, "two")
    }

    func testClearingLastCommentRemovesFile() async throws {
        try await CommentStore.setComment("temp", for: "only.txt", inDir: dirPath, on: fs)
        XCTAssertTrue(FileManager.default.fileExists(atPath: descPath))
        try await CommentStore.setComment(nil, for: "only.txt", inDir: dirPath, on: fs)
        XCTAssertFalse(FileManager.default.fileExists(atPath: descPath))
        let gone = await CommentStore.comment(for: "only.txt", inDir: dirPath, on: fs)
        XCTAssertNil(gone)
    }

    func testGetWithoutFileReturnsNil() async {
        let none = await CommentStore.comment(for: "any.txt", inDir: dirPath, on: fs)
        XCTAssertNil(none)
    }

    func testBulkCommentsReturnsWholeMap() async throws {
        try await CommentStore.setComment("first", for: "a.txt", inDir: dirPath, on: fs)
        try await CommentStore.setComment("has spaces here", for: "b file.txt", inDir: dirPath, on: fs)
        let map = await CommentStore.comments(inDir: dirPath, on: fs)
        XCTAssertEqual(map["a.txt"], "first")
        XCTAssertEqual(map["b file.txt"], "has spaces here")
        XCTAssertEqual(map.count, 2)
    }

    func testBulkCommentsWithoutFileIsEmpty() async {
        let map = await CommentStore.comments(inDir: dirPath, on: fs)
        XCTAssertTrue(map.isEmpty)
    }
}
