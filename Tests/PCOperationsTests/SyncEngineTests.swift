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
@testable import PCVFS

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
                              byContent: Bool = false, ignoreHidden: Bool = false) async -> [SyncItem] {
        await SyncScanner.scan(left: .localDir(left.path), right: .localDir(right.path), mask: mask,
                         withSubdirs: withSubdirs, byContent: byContent, ignoreHidden: ignoreHidden)
    }

    private func item(_ items: [SyncItem], _ rel: String) -> SyncItem? {
        items.first { $0.relativePath == rel }
    }

    // MARK: - What the scan reports

    func testAFileOnOneSideOnlyIsReportedWithNothingOnTheOther() async throws {
        try write("x", to: left, "only-left.txt")
        try write("y", to: right, "only-right.txt")
        let items = await scanBothDirs()
        XCTAssertNotNil(item(items, "only-left.txt")?.leftSize)
        XCTAssertNil(item(items, "only-left.txt")?.rightSize)
        XCTAssertNil(item(items, "only-right.txt")?.leftSize)
        XCTAssertNotNil(item(items, "only-right.txt")?.rightSize)
    }

    func testTheMaskDecidesWhichFilesAreCompared() async throws {
        try write("a", to: left, "keep.txt")
        try write("b", to: left, "skip.log")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: .localDir(right.path),
                                     mask: "*.txt", withSubdirs: true, byContent: false)
        XCTAssertNotNil(item(items, "keep.txt"))
        XCTAssertNil(item(items, "skip.log"), "a file the mask excludes must not be offered for copying")
    }

    func testWithoutSubdirectoriesTheContentsOfAFolderAreNotWalked() async throws {
        try write("deep", to: left, "sub/inner.txt")
        let flat = await scanBothDirs(withSubdirs: false)
        XCTAssertNil(item(flat, "sub/inner.txt"))
        let deep = await scanBothDirs(withSubdirs: true)
        XCTAssertNotNil(item(deep, "sub/inner.txt"))
    }

    func testHiddenItemsAreSkippedOnRequestAtEveryLevel() async throws {
        try write("a", to: left, ".hidden.txt")
        try write("b", to: left, ".hiddendir/inside.txt")
        try write("c", to: left, "visible.txt")
        let items = await scanBothDirs(ignoreHidden: true)
        XCTAssertNil(item(items, ".hidden.txt"))
        XCTAssertNil(item(items, ".hiddendir/inside.txt"), "a dot on any component hides the item")
        XCTAssertNotNil(item(items, "visible.txt"))
    }

    func testComparingByContentTellsEqualFromDifferentAtTheSameSize() async throws {
        try write("aaaa", to: left, "same.txt");  try write("aaaa", to: right, "same.txt")
        try write("aaaa", to: left, "differ.txt"); try write("bbbb", to: right, "differ.txt")
        let items = await scanBothDirs(byContent: true)
        XCTAssertEqual(item(items, "same.txt")?.contentEqual, true)
        // Same size, different bytes: the case a size comparison alone gets wrong.
        XCTAssertEqual(item(items, "differ.txt")?.contentEqual, false)
    }

    func testAZipCanBeOneSide() async throws {
        let zip = root.appendingPathComponent("side.zip")
        try ZipWriter.create(at: zip, files: [(path: "in-zip.txt", data: Data("z".utf8))])
        try write("l", to: left, "in-dir.txt")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: .zip(zip.path),
                                     mask: "*.*", withSubdirs: true, byContent: false)
        XCTAssertNotNil(item(items, "in-dir.txt")?.leftSize)
        XCTAssertNotNil(item(items, "in-zip.txt")?.rightSize)
    }

    // MARK: - What the executor actually does

    func testCopyingLeftToRightPutsTheBytesThere() async throws {
        try write("hello", to: left, "a.txt")
        let items = await scanBothDirs()
        let results = item(items, "a.txt").map { [SyncResult(action: .copyToRight, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                          right: .localDir(right.path), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try String(contentsOf: right.appendingPathComponent("a.txt"), encoding: .utf8),
                       "hello")
    }

    func testCopyingRightToLeftGoesTheOtherWay() async throws {
        try write("world", to: right, "b.txt")
        let items = await scanBothDirs()
        let results = item(items, "b.txt").map { [SyncResult(action: .copyToLeft, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                   right: .localDir(right.path), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try String(contentsOf: left.appendingPathComponent("b.txt"), encoding: .utf8),
                       "world")
    }

    func testDeletingOnTheRightRemovesTheFile() async throws {
        try write("gone", to: right, "c.txt")
        let items = await scanBothDirs()
        let results = item(items, "c.txt").map { [SyncResult(action: .deleteRight, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                   right: .localDir(right.path), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: right.appendingPathComponent("c.txt").path))
    }

    func testAnActionOnAnUntouchedFileLeavesTheOtherFilesAlone() async throws {
        try write("keep me", to: right, "untouched.txt")
        try write("copy me", to: left, "moved.txt")
        let items = await scanBothDirs()
        let results = item(items, "moved.txt").map { [SyncResult(action: .copyToRight, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                   right: .localDir(right.path), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try String(contentsOf: right.appendingPathComponent("untouched.txt"), encoding: .utf8),
                       "keep me", "a file no action named was changed")
    }

    // MARK: - A live filesystem as one side (F-193)
    //
    // Driven through LocalFS, which is a real VirtualFileSystem. The engine only ever talks to the
    // protocol — list, stat, openRead, openWrite, mkdir, delete — so this exercises the same code an
    // FTP or SFTP mount goes through, without a server in the test. That an actual server behaves is a
    // separate claim, and it belongs in the VM scenario against the guest's own sshd; this is why the
    // remote side was written against the protocol rather than against an FTP client.

    private func remoteSide(_ dir: URL) -> SyncSide {
        .remote(RemoteSyncSource(fs: LocalFS(), path: dir.path))
    }

    func testARemoteSideIsEnumeratedIncludingSubdirectories() async throws {
        try write("a", to: right, "top.txt")
        try write("b", to: right, "sub/inner.txt")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        XCTAssertNotNil(item(items, "top.txt")?.rightSize)
        XCTAssertNotNil(item(items, "sub/inner.txt")?.rightSize)
    }

    func testCopyingUpToARemoteSideWritesTheFileThere() async throws {
        try write("upload me", to: left, "up.txt")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        let results = item(items, "up.txt").map { [SyncResult(action: .copyToRight, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                right: remoteSide(right), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try String(contentsOf: right.appendingPathComponent("up.txt"), encoding: .utf8),
                       "upload me")
    }

    func testCopyingDownFromARemoteSideWritesTheFileHere() async throws {
        try write("download me", to: right, "down.txt")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        let results = item(items, "down.txt").map { [SyncResult(action: .copyToLeft, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                right: remoteSide(right), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try String(contentsOf: left.appendingPathComponent("down.txt"), encoding: .utf8),
                       "download me")
    }

    func testDeletingOnARemoteSideRemovesIt() async throws {
        try write("gone", to: right, "del.txt")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        let results = item(items, "del.txt").map { [SyncResult(action: .deleteRight, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                right: remoteSide(right), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: right.appendingPathComponent("del.txt").path))
    }

    func testTwoRemoteSidesAreRefusedRatherThanHalfDone() async throws {
        try write("x", to: right, "f.txt")
        let items = await SyncScanner.scan(left: remoteSide(left), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        let results = item(items, "f.txt").map { [SyncResult(action: .copyToLeft, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: remoteSide(left),
                                                right: remoteSide(right), toTrash: false)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("server to another"), errors[0])
    }

    func testUploadingOnlyTheFileStillCreatesItsFolderOnTheServer() async throws {
        // The case where the folder is *not* copied as its own action: the user deselected that row, or
        // only files were chosen. A server does not create the parent on the way, so without that step
        // the write fails — and nothing else in the suite reaches it, because a folder normally arrives
        // as its own action first.
        try write("deep", to: left, "newdir/inner.txt")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        let fileOnly = item(items, "newdir/inner.txt").map { [SyncResult(action: .copyToRight, item: $0)] } ?? []
        XCTAssertEqual(fileOnly.count, 1, "the file itself must be in the comparison")
        let errors = await SyncExecutor.execute(fileOnly, left: .localDir(left.path),
                                                right: remoteSide(right), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try String(contentsOf: right.appendingPathComponent("newdir/inner.txt"),
                                  encoding: .utf8), "deep")
    }

    // MARK: - The name comes off the wire

    func testAServerCannotNameAnEntryThatEscapesTheLocalFolder() async throws {
        // The listing is the server's to write, and the relative key becomes a local path on the other
        // side — the same shape as a crafted archive member. A component that is not a name is dropped
        // by the scanner, so it is never offered as something to copy.
        let hostile = HostileListingFS()
        let items = await SyncScanner.scan(left: .localDir(left.path),
                                           right: .remote(RemoteSyncSource(fs: hostile, path: "/")),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        XCTAssertNil(item(items, ".."), "a listing entry named \"..\" was accepted as a file to sync")
        XCTAssertNotNil(item(items, "ordinary.txt"), "the honest entry beside it must still arrive")
    }
}

/// A filesystem whose listing contains what a hostile server would send.
private final class HostileListingFS: VirtualFileSystem, @unchecked Sendable {
    let scheme = "hostile"
    var capabilities: VFSCapabilities { [.read] }

    func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        AsyncThrowingStream { continuation in
            func entry(_ name: String, _ kind: VFSEntry.Kind) -> VFSEntry {
                VFSEntry(name: name, ext: "", kind: kind, size: 1, modified: Date(timeIntervalSince1970: 0),
                         created: nil, posixMode: 0o644, bsdFlags: 0, isHidden: false)
            }
            // Only the root is listed; the "" entry would otherwise recurse forever.
            if dir.path == "/" {
                continuation.yield(VFSEntryBatch(entries: [entry("ordinary.txt", .file),
                                                           entry("..", .file)]))
            }
            continuation.finish()
        }
    }

    func stat(_ path: VFSPath) async throws -> VFSEntry { throw VFSError.notFound(path.path) }
    func openRead(_ path: VFSPath) async throws -> VFSReadStream { throw VFSError.notFound(path.path) }
    func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream {
        throw VFSError.notFound(path.path)
    }
    func mkdir(_ path: VFSPath) async throws {}
    func delete(_ path: VFSPath) async throws {}
    func rename(_ from: VFSPath, to: VFSPath) async throws {}
    func setAttributes(_ path: VFSPath, attributes: VFSAttributes) async throws {}
    func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>? { nil }
    func localFileIfAvailable(_ path: VFSPath) async throws -> URL? { nil }
}
