// VFSConformanceTests.swift - Reusable VFS protocol conformance battery
// (SPEC-006 §6). `runVFSConformance` exercises the `VirtualFileSystem`
// contract end-to-end against any writable filesystem rooted at `root`; it
// is intended to be reused verbatim by archive/FTP/plugin FS test suites
// later (SPEC-007, SPEC-011, SPEC-012), so it is deliberately not marked
// `private` and takes no LocalFS-specific assumptions beyond the protocol.

import XCTest
@testable import PCVFS

/// Runs the VFS conformance battery against `fs`, rooted at a writable,
/// otherwise-empty directory `root`.
///
/// Covers: listing (batched, including dotfiles), stat (files and
/// directories), nested mkdir, chunked write/read round-trips, rename,
/// delete, unicode filenames, missing-path errors, and capability flags.
/// `test` is accepted so failures are attributed to the calling test case;
/// callers own creating and tearing down `root` itself.
func runVFSConformance(_ fs: VirtualFileSystem, root: VFSPath, test: XCTestCase) async throws {
    // capabilities: this battery exercises read/write/rename, so a
    // conforming filesystem must advertise all three.
    XCTAssertTrue(fs.capabilities.contains(.read), "expected .read capability")
    XCTAssertTrue(fs.capabilities.contains(.write), "expected .write capability")
    XCTAssertTrue(fs.capabilities.contains(.rename), "expected .rename capability")

    // list: 3 files + 1 subdirectory + 1 dotfile, all yielded across
    // however many batches the implementation chooses to emit.
    let subdir = root.joining("subdir")
    try await fs.mkdir(subdir)
    for name in ["one.txt", "two.txt", "three.txt", ".hidden"] {
        try await writeAll(fs, root.joining(name), Data("battery".utf8))
    }
    let listed = try await collectEntries(fs.list(root))
    XCTAssertEqual(listed.count, 5, "expected 3 files + 1 subdir + 1 dotfile")
    XCTAssertTrue(
        listed.contains { $0.name == ".hidden" },
        "the VFS lists everything; dotfile filtering is a UI concern"
    )
    XCTAssertTrue(listed.contains { $0.name == "subdir" && $0.kind == .directory })

    // stat: a known-size file, and a directory.
    let known = root.joining("known.bin")
    let knownBytes = deterministicData(count: 12345)
    try await writeAll(fs, known, knownBytes)
    let knownEntry = try await fs.stat(known)
    XCTAssertEqual(knownEntry.size, Int64(knownBytes.count))
    XCTAssertEqual(knownEntry.kind, .file)
    let subdirEntry = try await fs.stat(subdir)
    XCTAssertEqual(subdirEntry.kind, .directory)

    // mkdir: nested directory creation.
    let nested = subdir.joining("nested")
    try await fs.mkdir(nested)
    let nestedEntry = try await fs.stat(nested)
    XCTAssertEqual(nestedEntry.kind, .directory)

    // write + read round-trip, including a chunk large enough to matter
    // (300 KB) alongside a small header chunk.
    let roundTrip = root.joining("roundtrip.bin")
    let header = Data("PEACH-HEADER".utf8)
    let bulk = deterministicData(count: 300 * 1024, seed: 0x5EED)
    let writeStream = try await fs.openWrite(roundTrip, options: WriteOptions(create: true, truncate: true))
    try await writeStream.write(header)
    try await writeStream.write(bulk)
    try await writeStream.close()

    let readStream = try await fs.openRead(roundTrip)
    var readBack = Data()
    for try await chunk in readStream {
        readBack.append(chunk as! Data) // swiftlint:disable:this force_cast
    }
    try await readStream.close()
    XCTAssertEqual(readBack, header + bulk)

    // rename: source gone, destination present.
    let renameSrc = root.joining("rename-src.txt")
    let renameDst = root.joining("rename-dst.txt")
    try await writeAll(fs, renameSrc, Data("rename me".utf8))
    try await fs.rename(renameSrc, to: renameDst)
    do {
        _ = try await fs.stat(renameSrc)
        XCTFail("expected stat on the renamed-away source to throw")
    } catch {
        // expected
    }
    let renamedEntry = try await fs.stat(renameDst)
    XCTAssertEqual(renamedEntry.kind, .file)

    // delete: stat afterwards throws.
    let toDelete = root.joining("delete-me.txt")
    try await writeAll(fs, toDelete, Data("bye".utf8))
    try await fs.delete(toDelete)
    do {
        _ = try await fs.stat(toDelete)
        XCTFail("expected stat on a deleted path to throw")
    } catch {
        // expected
    }

    // unicode filename round-trips through write/list/stat.
    let unicodeName = "café-🍑.txt"
    let unicodePath = root.joining(unicodeName)
    let unicodeBytes = Data("unicode payload".utf8)
    try await writeAll(fs, unicodePath, unicodeBytes)
    let unicodeStat = try await fs.stat(unicodePath)
    XCTAssertEqual(unicodeStat.size, Int64(unicodeBytes.count))
    let rootAfterUnicode = try await collectEntries(fs.list(root))
    XCTAssertTrue(rootAfterUnicode.contains { $0.name == unicodeName })

    // openRead of a missing path throws.
    do {
        _ = try await fs.openRead(root.joining("does-not-exist.bin"))
        XCTFail("expected openRead of a missing path to throw")
    } catch {
        // expected
    }
}

/// Writes `data` to `path` in one shot (create + truncate) — test setup
/// convenience, not part of the battery's assertions.
private func writeAll(_ fs: VirtualFileSystem, _ path: VFSPath, _ data: Data) async throws {
    let stream = try await fs.openWrite(path, options: WriteOptions(create: true, truncate: true))
    try await stream.write(data)
    try await stream.close()
}

/// Collects every entry from a `list(_:)` stream, across all batches.
private func collectEntries(_ stream: AsyncThrowingStream<VFSEntryBatch, Error>) async throws -> [VFSEntry] {
    var all: [VFSEntry] = []
    for try await batch in stream {
        all.append(contentsOf: batch.entries)
        if batch.isLastBatch { break }
    }
    return all
}

/// Deterministic pseudo-random bytes (repeatable across runs; not
/// cryptographic) for exercising chunked write/read without checking in
/// large binary fixtures.
private func deterministicData(count: Int, seed: UInt64 = 0xC0FFEE) -> Data {
    var state = seed
    var bytes = [UInt8](repeating: 0, count: count)
    for i in 0..<count {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        bytes[i] = UInt8((state >> 33) & 0xFF)
    }
    return Data(bytes)
}

/// Runs the conformance battery against `LocalFS`, plus focused tests for
/// each individual protocol method.
final class VFSConformanceTests: XCTestCase {
    private var tempDir: URL!
    private var fs: LocalFS!
    private var root: VFSPath!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCVFSConformance-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDir = dir
        fs = LocalFS()
        root = LocalFS.path(dir.path)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        fs = nil
        root = nil
        try super.tearDownWithError()
    }

    // MARK: - Full battery

    func test_battery_againstLocalFS() async throws {
        try await runVFSConformance(fs, root: root, test: self)
    }

    // MARK: - Focused per-method tests

    func test_list_yieldsAllEntriesAcrossBatches() async throws {
        try await writeAll(fs, root.joining("a.txt"), Data("a".utf8))
        try await writeAll(fs, root.joining("b.txt"), Data("b".utf8))
        try await writeAll(fs, root.joining("c.txt"), Data("c".utf8))
        try await fs.mkdir(root.joining("d"))

        let entries = try await collectEntries(fs.list(root))
        XCTAssertEqual(entries.count, 4)
        XCTAssertEqual(Set(entries.map(\.name)), ["a.txt", "b.txt", "c.txt", "d"])
    }

    func test_list_includesDotfiles() async throws {
        try await writeAll(fs, root.joining(".dotfile"), Data("hidden".utf8))
        try await writeAll(fs, root.joining("visible.txt"), Data("visible".utf8))

        let entries = try await collectEntries(fs.list(root))
        XCTAssertEqual(entries.count, 2, "the VFS lists everything; the UI filters dotfiles")
        let dotfile = entries.first { $0.name == ".dotfile" }
        XCTAssertNotNil(dotfile)
        XCTAssertEqual(dotfile?.isHidden, true)
    }

    func test_stat_file_sizeAndKind() async throws {
        let bytes = deterministicData(count: 4096)
        let path = root.joining("sized.bin")
        try await writeAll(fs, path, bytes)

        let entry = try await fs.stat(path)
        XCTAssertEqual(entry.size, Int64(bytes.count))
        XCTAssertEqual(entry.kind, .file)
    }

    func test_stat_directory_kind() async throws {
        let dir = root.joining("a-directory")
        try await fs.mkdir(dir)

        let entry = try await fs.stat(dir)
        XCTAssertEqual(entry.kind, .directory)
    }

    func test_mkdir_nested_createsDirectory() async throws {
        let nested = root.joining("a").joining("b")
        try await fs.mkdir(nested)

        let entry = try await fs.stat(nested)
        XCTAssertEqual(entry.kind, .directory)
    }

    func test_writeRead_roundTrip_withLargeChunk() async throws {
        let path = root.joining("large-roundtrip.bin")
        let chunk1 = Data("small-chunk-".utf8)
        let chunk2 = deterministicData(count: 300 * 1024, seed: 0xABCD1234)

        let writeStream = try await fs.openWrite(path, options: WriteOptions(create: true, truncate: true))
        try await writeStream.write(chunk1)
        try await writeStream.write(chunk2)
        try await writeStream.close()

        let readStream = try await fs.openRead(path)
        var readBack = Data()
        for try await chunk in readStream {
            readBack.append(chunk as! Data) // swiftlint:disable:this force_cast
        }
        try await readStream.close()

        XCTAssertEqual(readBack, chunk1 + chunk2)
    }

    func test_rename_movesEntry_oldGoneNewPresent() async throws {
        let src = root.joining("old-name.txt")
        let dst = root.joining("new-name.txt")
        try await writeAll(fs, src, Data("payload".utf8))

        try await fs.rename(src, to: dst)

        do {
            _ = try await fs.stat(src)
            XCTFail("stat on the renamed-away source should throw")
        } catch {
            // expected
        }
        let entry = try await fs.stat(dst)
        XCTAssertEqual(entry.kind, .file)
    }

    func test_delete_removesEntry_statThrowsNotFound() async throws {
        let path = root.joining("to-delete.txt")
        try await writeAll(fs, path, Data("temporary".utf8))

        try await fs.delete(path)

        do {
            _ = try await fs.stat(path)
            XCTFail("stat on a deleted path should throw .notFound")
        } catch let error as VFSError {
            XCTAssertEqual(error, .notFound(path.path))
        }
    }

    func test_unicodeFilename_roundTrips() async throws {
        let name = "café-🍑.txt"
        let path = root.joining(name)
        let bytes = Data("unicode payload".utf8)
        try await writeAll(fs, path, bytes)

        let entry = try await fs.stat(path)
        XCTAssertEqual(entry.size, Int64(bytes.count))

        let entries = try await collectEntries(fs.list(root))
        XCTAssertTrue(entries.contains { $0.name == name })
    }

    func test_openRead_missingPath_throwsNotFound() async throws {
        let missing = root.joining("nope.bin")
        do {
            _ = try await fs.openRead(missing)
            XCTFail("expected openRead of a missing path to throw")
        } catch let error as VFSError {
            XCTAssertEqual(error, .notFound(missing.path))
        }
    }

    func test_capabilities_containsReadWriteRename() {
        XCTAssertTrue(fs.capabilities.contains(.read))
        XCTAssertTrue(fs.capabilities.contains(.write))
        XCTAssertTrue(fs.capabilities.contains(.rename))
    }
}
