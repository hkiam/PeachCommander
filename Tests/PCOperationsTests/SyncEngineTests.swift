// SPDX-License-Identifier: Apache-2.0
// SyncEngineTests.swift - What the sync will do, and what it then does (F-193).
//
// The scanner and the executor had no tests at all. They lived in SyncWindowController, and no test
// bundle imports PCApp — so the code that decides which files get copied, and the code that copies
// them, was checked only by using the window. F-193's evidence was a symbol name.
//
// These pin the behaviour that exists today, before a remote (FTP/SFTP) side is added to it: a
// refactor of code nobody is watching is a rewrite with extra steps.

import XCTest
@testable import PCArchive
@testable import PCFoundation
@testable import PCOperations

final class SyncEngineTests: XCTestCase {
    private var root: URL!
    private var left: URL!
    private var right: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCSync-\(UUID().uuidString)", isDirectory: true)
        left = root.appendingPathComponent("left", isDirectory: true)
        right = root.appendingPathComponent("right", isDirectory: true)
        for dir in [left!, right!] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        root = nil; left = nil; right = nil
        try super.tearDownWithError()
    }

    @discardableResult
    private func write(_ text: String, to dir: URL, _ rel: String) throws -> URL {
        let url = dir.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func scanBothDirs(mask: String = "*.*", withSubdirs: Bool = true,
                              byContent: Bool = false, ignoreHidden: Bool = false) -> [SyncItem] {
        SyncScanner.scan(left: .localDir(left.path), right: .localDir(right.path), mask: mask,
                         withSubdirs: withSubdirs, byContent: byContent, ignoreHidden: ignoreHidden)
    }

    private func item(_ items: [SyncItem], _ rel: String) -> SyncItem? {
        items.first { $0.relativePath == rel }
    }

    // MARK: - What the scan reports

    func testAFileOnOneSideOnlyIsReportedWithNothingOnTheOther() throws {
        try write("x", to: left, "only-left.txt")
        try write("y", to: right, "only-right.txt")
        let items = scanBothDirs()
        XCTAssertNotNil(item(items, "only-left.txt")?.leftSize)
        XCTAssertNil(item(items, "only-left.txt")?.rightSize)
        XCTAssertNil(item(items, "only-right.txt")?.leftSize)
        XCTAssertNotNil(item(items, "only-right.txt")?.rightSize)
    }

    func testTheMaskDecidesWhichFilesAreCompared() throws {
        try write("a", to: left, "keep.txt")
        try write("b", to: left, "skip.log")
        let items = SyncScanner.scan(left: .localDir(left.path), right: .localDir(right.path),
                                     mask: "*.txt", withSubdirs: true, byContent: false)
        XCTAssertNotNil(item(items, "keep.txt"))
        XCTAssertNil(item(items, "skip.log"), "a file the mask excludes must not be offered for copying")
    }

    func testWithoutSubdirectoriesTheContentsOfAFolderAreNotWalked() throws {
        try write("deep", to: left, "sub/inner.txt")
        let flat = scanBothDirs(withSubdirs: false)
        XCTAssertNil(item(flat, "sub/inner.txt"))
        let deep = scanBothDirs(withSubdirs: true)
        XCTAssertNotNil(item(deep, "sub/inner.txt"))
    }

    func testHiddenItemsAreSkippedOnRequestAtEveryLevel() throws {
        try write("a", to: left, ".hidden.txt")
        try write("b", to: left, ".hiddendir/inside.txt")
        try write("c", to: left, "visible.txt")
        let items = scanBothDirs(ignoreHidden: true)
        XCTAssertNil(item(items, ".hidden.txt"))
        XCTAssertNil(item(items, ".hiddendir/inside.txt"), "a dot on any component hides the item")
        XCTAssertNotNil(item(items, "visible.txt"))
    }

    func testComparingByContentTellsEqualFromDifferentAtTheSameSize() throws {
        try write("aaaa", to: left, "same.txt");  try write("aaaa", to: right, "same.txt")
        try write("aaaa", to: left, "differ.txt"); try write("bbbb", to: right, "differ.txt")
        let items = scanBothDirs(byContent: true)
        XCTAssertEqual(item(items, "same.txt")?.contentEqual, true)
        // Same size, different bytes: the case a size comparison alone gets wrong.
        XCTAssertEqual(item(items, "differ.txt")?.contentEqual, false)
    }

    func testAZipCanBeOneSide() throws {
        let zip = root.appendingPathComponent("side.zip")
        try ZipWriter.create(at: zip, files: [(path: "in-zip.txt", data: Data("z".utf8))])
        try write("l", to: left, "in-dir.txt")
        let items = SyncScanner.scan(left: .localDir(left.path), right: .zip(zip.path),
                                     mask: "*.*", withSubdirs: true, byContent: false)
        XCTAssertNotNil(item(items, "in-dir.txt")?.leftSize)
        XCTAssertNotNil(item(items, "in-zip.txt")?.rightSize)
    }

    // MARK: - What the executor actually does

    func testCopyingLeftToRightPutsTheBytesThere() throws {
        try write("hello", to: left, "a.txt")
        let items = scanBothDirs()
        let results = item(items, "a.txt").map { [SyncResult(action: .copyToRight, item: $0)] } ?? []
        let errors = SyncExecutor.execute(results, left: .localDir(left.path),
                                          right: .localDir(right.path), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try String(contentsOf: right.appendingPathComponent("a.txt"), encoding: .utf8),
                       "hello")
    }

    func testCopyingRightToLeftGoesTheOtherWay() throws {
        try write("world", to: right, "b.txt")
        let items = scanBothDirs()
        let results = item(items, "b.txt").map { [SyncResult(action: .copyToLeft, item: $0)] } ?? []
        XCTAssertEqual(SyncExecutor.execute(results, left: .localDir(left.path),
                                            right: .localDir(right.path), toTrash: false), [])
        XCTAssertEqual(try String(contentsOf: left.appendingPathComponent("b.txt"), encoding: .utf8),
                       "world")
    }

    func testDeletingOnTheRightRemovesTheFile() throws {
        try write("gone", to: right, "c.txt")
        let items = scanBothDirs()
        let results = item(items, "c.txt").map { [SyncResult(action: .deleteRight, item: $0)] } ?? []
        XCTAssertEqual(SyncExecutor.execute(results, left: .localDir(left.path),
                                            right: .localDir(right.path), toTrash: false), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: right.appendingPathComponent("c.txt").path))
    }

    func testAnActionOnAnUntouchedFileLeavesTheOtherFilesAlone() throws {
        try write("keep me", to: right, "untouched.txt")
        try write("copy me", to: left, "moved.txt")
        let items = scanBothDirs()
        let results = item(items, "moved.txt").map { [SyncResult(action: .copyToRight, item: $0)] } ?? []
        XCTAssertEqual(SyncExecutor.execute(results, left: .localDir(left.path),
                                            right: .localDir(right.path), toTrash: false), [])
        XCTAssertEqual(try String(contentsOf: right.appendingPathComponent("untouched.txt"), encoding: .utf8),
                       "keep me", "a file no action named was changed")
    }
}
