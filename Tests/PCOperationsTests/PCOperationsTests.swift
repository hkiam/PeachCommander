// PCOperationsTests.swift - Integration tests for the file-operation engine.
//
// SAFETY: every test operates only under a unique temp directory created in
// setUp and removed in tearDown. Nothing touches the user's real files.

import XCTest
@testable import PCOperations

final class PCOperationsTests: XCTestCase {
    private var root: String = ""
    private let fm = FileManager.default

    override func setUpWithError() throws {
        root = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("pcops-\(UUID().uuidString)")
        try fm.createDirectory(atPath: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(atPath: root)
    }

    // MARK: - Helpers

    private func path(_ rel: String) -> String { (root as NSString).appendingPathComponent(rel) }

    private func writeFile(_ rel: String, bytes: Int) throws -> String {
        let p = path(rel)
        try fm.createDirectory(atPath: (p as NSString).deletingLastPathComponent,
                               withIntermediateDirectories: true)
        let data = Data((0..<bytes).map { UInt8($0 & 0xFF) })
        try data.write(to: URL(fileURLWithPath: p))
        return p
    }

    private func contents(_ p: String) -> Data? { fm.contents(atPath: p) }

    // MARK: - Copy

    func testCopySingleFileContentIdentical() async throws {
        let src = try writeFile("src.bin", bytes: 100_000)
        let dstDir = path("out"); try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        let q = TransferQueue()
        var opts = CopyOptions(); opts.useCloneWhenPossible = false
        let processed = try await q.runToCompletion(.copy(items: [src], toDirectory: dstDir, options: opts))
        XCTAssertEqual(processed, [src])
        XCTAssertEqual(contents(path("out/src.bin")), contents(src))
    }

    func testCopyViaCloneContentIdentical() async throws {
        let src = try writeFile("clone.bin", bytes: 50_000)
        let dstDir = path("out"); try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        let q = TransferQueue()
        var opts = CopyOptions(); opts.useCloneWhenPossible = true
        _ = try await q.runToCompletion(.copy(items: [src], toDirectory: dstDir, options: opts))
        XCTAssertEqual(contents(path("out/clone.bin")), contents(src))
    }

    func testCopyPreservesPermissionsAndMtime() async throws {
        let src = try writeFile("perm.bin", bytes: 1000)
        try fm.setAttributes([.posixPermissions: 0o640], ofItemAtPath: src)
        let mtime = Date(timeIntervalSince1970: 1_600_000_000)
        try fm.setAttributes([.modificationDate: mtime], ofItemAtPath: src)
        let dstDir = path("out"); try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        var opts = CopyOptions(); opts.useCloneWhenPossible = false
        _ = try await TransferQueue().runToCompletion(.copy(items: [src], toDirectory: dstDir, options: opts))
        let attrs = try fm.attributesOfItem(atPath: path("out/perm.bin"))
        XCTAssertEqual(attrs[.posixPermissions] as? Int, 0o640)
        let copiedMtime = attrs[.modificationDate] as? Date
        XCTAssertEqual(copiedMtime?.timeIntervalSince1970 ?? 0, mtime.timeIntervalSince1970, accuracy: 2.0)
    }

    func testCopyDirectoryTreeRecursive() async throws {
        _ = try writeFile("tree/a.txt", bytes: 10)
        _ = try writeFile("tree/sub/b.txt", bytes: 20)
        _ = try writeFile("tree/sub/deep/c.txt", bytes: 30)
        let dstDir = path("out"); try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        _ = try await TransferQueue().runToCompletion(.copy(items: [path("tree")], toDirectory: dstDir, options: CopyOptions()))
        XCTAssertTrue(fm.fileExists(atPath: path("out/tree/a.txt")))
        XCTAssertTrue(fm.fileExists(atPath: path("out/tree/sub/b.txt")))
        XCTAssertTrue(fm.fileExists(atPath: path("out/tree/sub/deep/c.txt")))
        XCTAssertEqual(contents(path("out/tree/sub/deep/c.txt"))?.count, 30)
    }

    func testCopySymlinkPreservedAsLink() async throws {
        let target = try writeFile("real.txt", bytes: 5)
        let link = path("link.txt")
        try fm.createSymbolicLink(atPath: link, withDestinationPath: target)
        let dstDir = path("out"); try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        _ = try await TransferQueue().runToCompletion(.copy(items: [link], toDirectory: dstDir, options: CopyOptions()))
        let copied = path("out/link.txt")
        let dest = try fm.destinationOfSymbolicLink(atPath: copied)
        XCTAssertEqual(dest, target)
    }

    // MARK: - Overwrite resolution

    func testCopyOverwriteSkip() async throws {
        let src = try writeFile("f.bin", bytes: 100)
        let dstDir = path("out"); try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        _ = try writeFile("out/f.bin", bytes: 999) // pre-existing, different size
        _ = try await TransferQueue().runToCompletion(
            .copy(items: [src], toDirectory: dstDir, options: CopyOptions()),
            resolver: SkipAllResolver())
        XCTAssertEqual(contents(path("out/f.bin"))?.count, 999) // unchanged
    }

    func testCopyOverwriteReplace() async throws {
        let src = try writeFile("f.bin", bytes: 100)
        let dstDir = path("out"); try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        _ = try writeFile("out/f.bin", bytes: 999)
        var opts = CopyOptions(); opts.useCloneWhenPossible = false
        _ = try await TransferQueue().runToCompletion(
            .copy(items: [src], toDirectory: dstDir, options: opts),
            resolver: OverwriteAllResolver())
        XCTAssertEqual(contents(path("out/f.bin"))?.count, 100)
    }

    func testCopyRenameResolver() async throws {
        let src = try writeFile("f.bin", bytes: 100)
        let dstDir = path("out"); try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        _ = try writeFile("out/f.bin", bytes: 999)
        _ = try await TransferQueue().runToCompletion(
            .copy(items: [src], toDirectory: dstDir, options: CopyOptions()),
            resolver: FixedRenameResolver(newName: "f (2).bin"))
        XCTAssertEqual(contents(path("out/f.bin"))?.count, 999)     // original untouched
        XCTAssertEqual(contents(path("out/f (2).bin"))?.count, 100) // renamed copy
    }

    func testOnlyNewerSkipsOlderSource() async throws {
        let src = try writeFile("f.bin", bytes: 100)
        try fm.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1000)], ofItemAtPath: src)
        let dstDir = path("out"); try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        let dst = try writeFile("out/f.bin", bytes: 999)
        try fm.setAttributes([.modificationDate: Date(timeIntervalSince1970: 5000)], ofItemAtPath: dst)
        var opts = CopyOptions(); opts.onlyNewer = true; opts.useCloneWhenPossible = false
        _ = try await TransferQueue().runToCompletion(
            .copy(items: [src], toDirectory: dstDir, options: opts),
            resolver: OverwriteAllResolver())
        XCTAssertEqual(contents(path("out/f.bin"))?.count, 999) // newer target kept
    }

    // MARK: - Cancellation

    func testCancelBeforeStartLeavesNoTarget() async throws {
        let src = try writeFile("big.bin", bytes: 500_000)
        let dstDir = path("out"); try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        let q = TransferQueue()
        await q.control.cancel()
        var opts = CopyOptions(); opts.useCloneWhenPossible = false
        do {
            _ = try await q.runToCompletion(.copy(items: [src], toDirectory: dstDir, options: opts))
            XCTFail("expected cancellation")
        } catch let e as OperationError {
            XCTAssertEqual(e, .cancelled)
        }
        XCTAssertFalse(fm.fileExists(atPath: path("out/big.bin")))
    }

    func testCancelMidCopyRemovesPartialTarget() async throws {
        let src = try writeFile("big.bin", bytes: 8_000_000)
        let dstDir = path("out"); try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        let q = TransferQueue()
        var opts = CopyOptions()
        opts.useCloneWhenPossible = false
        opts.chunkSize = 32_768
        opts.maxBytesPerSecond = 2_000_000 // ~4s copy → plenty of time to cancel mid-file
        let task = Task { try await q.runToCompletion(.copy(items: [src], toDirectory: dstDir, options: opts)) }
        try await Task.sleep(nanoseconds: 300_000_000)
        await q.control.cancel()
        do { _ = try await task.value; XCTFail("expected cancellation") }
        catch let e as OperationError { XCTAssertEqual(e, .cancelled) }
        XCTAssertFalse(fm.fileExists(atPath: path("out/big.bin")), "partial target must be cleaned up")
    }

    func testPauseThenResumeCompletes() async throws {
        let src = try writeFile("p.bin", bytes: 2_000_000)
        let dstDir = path("out"); try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        let q = TransferQueue()
        var opts = CopyOptions(); opts.useCloneWhenPossible = false; opts.chunkSize = 16_384
        await q.control.pause()
        let task = Task { try await q.runToCompletion(.copy(items: [src], toDirectory: dstDir, options: opts)) }
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(fm.fileExists(atPath: path("out/p.bin")) &&
                       (contents(path("out/p.bin"))?.count ?? 0) == 2_000_000)
        await q.control.resume()
        _ = try await task.value
        XCTAssertEqual(contents(path("out/p.bin"))?.count, 2_000_000)
    }

    // MARK: - Move

    func testMoveSameVolumeRenames() async throws {
        let src = try writeFile("m.bin", bytes: 1234)
        let dstDir = path("out"); try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        _ = try await TransferQueue().runToCompletion(.move(items: [src], toDirectory: dstDir, options: CopyOptions()))
        XCTAssertFalse(fm.fileExists(atPath: src))
        XCTAssertEqual(contents(path("out/m.bin"))?.count, 1234)
    }

    func testMoveDirectoryTree() async throws {
        _ = try writeFile("dir/x.txt", bytes: 3)
        _ = try writeFile("dir/y/z.txt", bytes: 4)
        let dstDir = path("out"); try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        _ = try await TransferQueue().runToCompletion(.move(items: [path("dir")], toDirectory: dstDir, options: CopyOptions()))
        XCTAssertFalse(fm.fileExists(atPath: path("dir")))
        XCTAssertTrue(fm.fileExists(atPath: path("out/dir/y/z.txt")))
    }

    // MARK: - Delete

    func testPermanentDeleteTree() async throws {
        _ = try writeFile("del/a.txt", bytes: 1)
        _ = try writeFile("del/sub/b.txt", bytes: 2)
        _ = try await TransferQueue().runToCompletion(.delete(items: [path("del")]))
        XCTAssertFalse(fm.fileExists(atPath: path("del")))
    }

    func testPermanentDeleteSymlinkKeepsTarget() async throws {
        let target = try writeFile("keep.txt", bytes: 7)
        let link = path("dellink")
        try fm.createSymbolicLink(atPath: link, withDestinationPath: target)
        _ = try await TransferQueue().runToCompletion(.delete(items: [link]))
        XCTAssertFalse(fm.fileExists(atPath: link))
        XCTAssertTrue(fm.fileExists(atPath: target), "symlink target must survive")
    }

    func testTrashRemovesFromOriginalLocation() async throws {
        let src = try writeFile("trashme.txt", bytes: 5)
        let processed = try await TransferQueue().runToCompletion(.trash(items: [src]))
        XCTAssertEqual(processed, [src])
        XCTAssertFalse(fm.fileExists(atPath: src))
    }

    // MARK: - MkDir

    func testMkDirNested() throws {
        let created = try MkDirEngine.create(spec: "a/b/c", in: root)
        XCTAssertEqual(created.count, 1)
        XCTAssertTrue(fm.fileExists(atPath: path("a/b/c")))
    }

    func testMkDirMultiple() throws {
        let created = try MkDirEngine.create(spec: "one|two|three", in: root)
        XCTAssertEqual(created.count, 3)
        XCTAssertTrue(fm.fileExists(atPath: path("one")))
        XCTAssertTrue(fm.fileExists(atPath: path("two")))
        XCTAssertTrue(fm.fileExists(atPath: path("three")))
    }

    // MARK: - Event stream

    func testEventStreamEmitsProgressAndCompleted() async throws {
        _ = try writeFile("evt/a.bin", bytes: 200_000)
        _ = try writeFile("evt/b.bin", bytes: 200_000)
        let dstDir = path("out"); try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        let q = TransferQueue()
        var opts = CopyOptions(); opts.useCloneWhenPossible = false
        var sawCompleted = false
        var lastProgress: OpProgress?
        for await event in q.run(.copy(items: [path("evt")], toDirectory: dstDir, options: opts)) {
            switch event {
            case .progress(let p): lastProgress = p
            case .completed(let processed): sawCompleted = true; XCTAssertEqual(processed, [path("evt")])
            case .failed(let e): XCTFail("unexpected failure: \(e)")
            case .cancelled: XCTFail("unexpected cancel")
            case .log: break
            }
        }
        XCTAssertTrue(sawCompleted)
        XCTAssertNotNil(lastProgress)
        XCTAssertEqual(lastProgress?.filesTotal, 2)
    }
}

/// Test resolver that renames on conflict.
struct FixedRenameResolver: OperationResolver {
    let newName: String
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .rename(newName) }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .abort }
}
