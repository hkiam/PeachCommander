// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCVFS

/// `LocalFS.list` reads a directory through `getattrlistbulk(2)` — one syscall per batch instead of an
/// `lstat` per name, which is what made a folder on an SMB share take seconds to open.
///
/// The risk in that change is not that it fails, it is that it succeeds and quietly answers something
/// slightly different: a mode read from the wrong offset, a date taken from the wrong clock, a hidden
/// file that stops being hidden. So the test here is differential rather than a list of expected
/// values — every entry `list` produces is compared field for field against what `stat` produces for
/// the same path, and `stat` still goes down the untouched per-file path. Anything the bulk reader
/// gets wrong shows up as a disagreement between the two.
final class BulkListingTests: XCTestCase {
    private var dir: URL!
    private let fs = LocalFS()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-bulk-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    // MARK: - Fixture

    /// One of each thing the reader has to get right, including the three it deliberately hands back
    /// to the per-file path (a directory, a symlink, an alias) and the two ways a file is hidden.
    private func makeFixture() throws {
        func write(_ name: String, _ text: String = "content") throws -> URL {
            let url = dir.appendingPathComponent(name)
            try text.data(using: .utf8)!.write(to: url)
            return url
        }
        let plain = try write("plain.txt")
        _ = try write(".dotfile")                       // hidden by name
        let flagged = try write("flagged.txt")          // hidden by UF_HIDDEN (F-028)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: flagged.path)
        XCTAssertEqual(chflags(flagged.path, UInt32(UF_HIDDEN)), 0, "could not set UF_HIDDEN")

        let script = try write("script.sh", "#!/bin/sh\n")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        _ = try write("no-extension")
        _ = try write("archive.tar.gz")                 // the extension is the last component only

        let sub = dir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        let bundle = dir.appendingPathComponent("Thing.app")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)

        try FileManager.default.createSymbolicLink(atPath: dir.appendingPathComponent("link-file").path,
                                                   withDestinationPath: plain.path)
        try FileManager.default.createSymbolicLink(atPath: dir.appendingPathComponent("link-dir").path,
                                                   withDestinationPath: sub.path)
        try FileManager.default.createSymbolicLink(atPath: dir.appendingPathComponent("link-broken").path,
                                                   withDestinationPath: dir.appendingPathComponent("gone").path)

        // A Finder alias: a regular file the bulk record can spot but not resolve.
        let alias = dir.appendingPathComponent("FileAlias")
        let bookmark = try plain.bookmarkData(options: .suitableForBookmarkFile,
                                              includingResourceValuesForKeys: nil, relativeTo: nil)
        try URL.writeBookmarkData(bookmark, to: alias)
    }

    // MARK: - Helpers

    private func listed() async throws -> [VFSEntry] {
        var all: [VFSEntry] = []
        for try await batch in fs.list(LocalFS.path(dir.path)) { all.append(contentsOf: batch.entries) }
        return all
    }

    /// Drives the bulk reader directly, so a test can say whether it answered at all.
    private func bulkAnswered() throws -> Bool {
        var answered = false
        var thrown: Error?
        let stream = AsyncThrowingStream<VFSEntryBatch, Error> { continuation in
            do { answered = try LocalBulkList.list(dir.path, into: continuation) }
            catch { thrown = error }
            continuation.finish()
        }
        _ = stream
        if let thrown { throw thrown }
        return answered
    }

    // MARK: - Tests

    /// The guard on every other test in this file: if the volume declined the bulk read, the
    /// comparison below would be the per-file path against itself and would prove nothing.
    func testTheBulkReaderIsTheOneAnswering() throws {
        try makeFixture()
        XCTAssertTrue(try bulkAnswered(),
                      "getattrlistbulk declined the temp directory — the differential test below "
                      + "would then be comparing the per-file path against itself")
    }

    /// The main event: `list` and `stat` must not disagree about anything.
    func testEveryFieldMatchesThePerFileWalk() async throws {
        try makeFixture()
        let entries = try await listed()
        XCTAssertFalse(entries.isEmpty)

        for entry in entries {
            let full = dir.appendingPathComponent(entry.name).path
            let reference = try await fs.stat(LocalFS.path(full))
            let what = "entry “\(entry.name)”"
            XCTAssertEqual(entry.name, reference.name, "name of \(what)")
            XCTAssertEqual(entry.ext, reference.ext, "ext of \(what)")
            XCTAssertEqual(entry.kind, reference.kind, "kind of \(what)")
            XCTAssertEqual(entry.size, reference.size, "size of \(what)")
            XCTAssertEqual(entry.modified, reference.modified, "modified of \(what)")
            XCTAssertEqual(entry.created, reference.created, "created of \(what)")
            XCTAssertEqual(entry.posixMode, reference.posixMode, "posixMode of \(what)")
            XCTAssertEqual(entry.bsdFlags, reference.bsdFlags, "bsdFlags of \(what)")
            XCTAssertEqual(entry.isHidden, reference.isHidden, "isHidden of \(what)")
            XCTAssertEqual(entry.linkTarget, reference.linkTarget, "linkTarget of \(what)")
        }
    }

    /// Nothing gained and nothing lost: the same names the directory actually holds, no `.` or `..`,
    /// and none of them twice. A batching bug is most likely to show up as a repeat.
    func testTheNamesAreExactlyTheDirectoryContents() async throws {
        try makeFixture()
        let names = try await listed().map(\.name)
        let expected = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertEqual(Set(names), Set(expected))
        XCTAssertEqual(names.count, Set(names).count, "an entry was listed more than once")
        XCTAssertFalse(names.contains("."))
        XCTAssertFalse(names.contains(".."))
    }

    /// The two ways a file is hidden on macOS, checked by name rather than only through the reference
    /// comparison — `UF_HIDDEN` is read out of a field that moves if the unpacking order is wrong, and
    /// a silent regression there is exactly what F-028 was about.
    func testBothKindsOfHiddenSurvive() async throws {
        try makeFixture()
        let byName = Dictionary(uniqueKeysWithValues: try await listed().map { ($0.name, $0) })
        XCTAssertEqual(byName[".dotfile"]?.isHidden, true, "a dot-file must list as hidden")
        XCTAssertEqual(byName["flagged.txt"]?.isHidden, true, "UF_HIDDEN must list as hidden")
        XCTAssertEqual(byName["plain.txt"]?.isHidden, false)
    }

    /// The mode has to arrive intact, and it is the field that reads back as `0` when `FNDRINFO` is
    /// unpacked in the order it is usually *written* rather than the order the kernel packs it.
    func testPermissionsArriveIntact() async throws {
        try makeFixture()
        let byName = Dictionary(uniqueKeysWithValues: try await listed().map { ($0.name, $0) })
        XCTAssertEqual(byName["script.sh"]?.posixMode, 0o755)
        XCTAssertEqual(byName["flagged.txt"]?.posixMode, 0o600)
    }

    /// A listing bigger than one `getattrlistbulk` buffer, so the batching loop is actually exercised;
    /// with a small directory the whole thing fits in one call and the loop never runs twice.
    func testAManyEntryDirectoryIsListedWholeAndOnce() async throws {
        for i in 0..<3000 {
            try "x".data(using: .utf8)!.write(to: dir.appendingPathComponent("file-\(i).dat"))
        }
        let names = try await listed().map(\.name)
        XCTAssertEqual(names.count, 3000)
        XCTAssertEqual(Set(names).count, 3000, "entries were repeated across batches")
    }

    /// An empty directory is a real case (a freshly made folder) and the loop must simply produce
    /// nothing rather than an entry or an error.
    func testAnEmptyDirectoryListsAsEmpty() async throws {
        let entries = try await listed()
        XCTAssertTrue(entries.isEmpty)
    }

    /// A path that is not a directory must still fail the way it always did.
    func testListingSomethingThatIsNotADirectoryStillFails() async throws {
        let file = dir.appendingPathComponent("a-file.txt")
        try "x".data(using: .utf8)!.write(to: file)
        do {
            for try await _ in fs.list(LocalFS.path(file.path)) {}
            XCTFail("listing a regular file should not succeed")
        } catch {
            // expected
        }
    }
}
