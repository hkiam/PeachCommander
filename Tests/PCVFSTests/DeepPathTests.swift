// SPDX-License-Identifier: Apache-2.0
// DeepPathTests.swift - Files whose absolute path no syscall will accept (F-383).
//
// The fixture cannot be built with the API under test, and that is the point: a tree this deep only
// comes into existence through relative steps. So it is built by chdir-ing down, the way the real ones
// are made (an unpacker working inside its output folder, a checkout of a checkout), and only then
// handed to LocalFS as one absolute path of about 2.5 KB.
//
// Every test here asserts twice over: that the operation works through the descriptor walk, and — where
// it is cheap to show — that the plain path call it replaces really does fail with ENAMETOOLONG. Without
// the second half these would pass on a system where PATH_MAX was not the constraint, which would make
// them a test of nothing.

import XCTest
@testable import PCVFS

final class DeepPathTests: XCTestCase {
    private var root: URL!
    /// The deep directory, as one absolute path far past PATH_MAX.
    private var deep: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCVFS-Deep-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        deep = try buildDeepTree(under: root, segments: 40, segmentLength: 60)
        // The premise: this really is past what a path argument may be.
        XCTAssertGreaterThan(deep.utf8.count, Int(PATH_MAX),
                             "the fixture is not deep enough to test anything")
    }

    override func tearDownWithError() throws {
        if let root { removeDeepTree(at: root) }
        root = nil
        deep = nil
        try super.tearDownWithError()
    }

    /// Builds `segments` nested directories by descending into each one, so no single syscall ever
    /// sees more than one component. Returns the absolute path of the deepest directory.
    private func buildDeepTree(under base: URL, segments: Int, segmentLength: Int) throws -> String {
        let name = String(repeating: "d", count: segmentLength)
        let fm = FileManager.default
        let previous = fm.currentDirectoryPath
        defer { fm.changeCurrentDirectoryPath(previous) }
        guard fm.changeCurrentDirectoryPath(base.path) else {
            throw XCTSkip("could not enter the fixture root")
        }
        var path = base.path
        for _ in 0..<segments {
            guard mkdir(name, 0o755) == 0 || errno == EEXIST else {
                throw XCTSkip("mkdir failed at depth: \(String(cString: strerror(errno)))")
            }
            guard fm.changeCurrentDirectoryPath(name) else {
                throw XCTSkip("could not descend into the fixture")
            }
            path += "/" + name
        }
        return path
    }

    /// Tears the tree down from the inside out; `removeItem` cannot reach the bottom of it either.
    private func removeDeepTree(at base: URL) {
        let fd = DeepPath.openDirectory((base.path as NSString).deletingLastPathComponent)
        guard fd >= 0 else { return }
        defer { close(fd) }
        _ = DeepPath.removeRecursively((base.path as NSString).lastPathComponent, in: fd)
    }

    /// A file inside the deep directory, created relative to a descriptor for it.
    @discardableResult
    private func makeFile(_ name: String, contents: String) throws -> String {
        let dir = DeepPath.openDirectory(deep)
        try XCTSkipUnless(dir >= 0, "could not open the deep directory")
        defer { close(dir) }
        let fd = name.withCString { openat(dir, $0, O_WRONLY | O_CREAT | O_TRUNC, 0o644) }
        try XCTSkipUnless(fd >= 0, "could not create the fixture file")
        defer { close(fd) }
        _ = contents.withCString { write(fd, $0, strlen($0)) }
        return deep + "/" + name
    }

    // MARK: - The premise

    func testThePlainSyscallReallyDoesFailAtThisDepth() throws {
        var info = stat()
        XCTAssertEqual(lstat(deep, &info), -1, "lstat on a 2.5 KB path was expected to fail")
        XCTAssertEqual(errno, ENAMETOOLONG, "it failed, but not for the reason under test")
        XCTAssertNil(try? FileManager.default.contentsOfDirectory(atPath: deep),
                     "FileManager was expected to be unable to list this")
    }

    // MARK: - Listing and stat

    func testListingADirectoryTooDeepToName() async throws {
        try makeFile("one.txt", contents: "1")
        try makeFile("two.txt", contents: "22")

        var names: [String] = []
        for try await batch in LocalFS().list(LocalFS.path(deep)) {
            names.append(contentsOf: batch.entries.map(\.name))
        }
        XCTAssertEqual(names.sorted(), ["one.txt", "two.txt"])
    }

    func testStatReadsSizeAndKindAtDepth() async throws {
        let file = try makeFile("sized.txt", contents: "hello")

        let entry = try await LocalFS().stat(LocalFS.path(file))
        XCTAssertEqual(entry.name, "sized.txt")
        XCTAssertEqual(entry.size, 5)
        XCTAssertEqual(entry.kind, .file)
    }

    func testStatOfTheDeepDirectoryItselfSaysDirectory() async throws {
        let entry = try await LocalFS().stat(LocalFS.path(deep))
        XCTAssertEqual(entry.kind, .directory)
    }

    // MARK: - Reading and writing

    func testReadingAFileAtDepth() async throws {
        let file = try makeFile("read.txt", contents: "deep contents")

        let stream = try await LocalFS().openRead(LocalFS.path(file))
        var received = Data()
        for try await element in stream {
            guard let chunk = element as? Data else { continue }
            received.append(chunk)
        }
        try await stream.close()
        XCTAssertEqual(String(data: received, encoding: .utf8), "deep contents")
    }

    func testWritingAFileAtDepth() async throws {
        let path = deep + "/written.txt"
        let stream = try await LocalFS().openWrite(LocalFS.path(path),
                                                   options: WriteOptions(create: true, truncate: true))
        try await stream.write(Data("written through a descriptor".utf8))
        try await stream.close()

        let written = try await LocalFS().stat(LocalFS.path(path))
        XCTAssertEqual(written.size, 28)
    }

    // MARK: - Creating, renaming, deleting

    func testCreatingADirectoryPastTheLimit() async throws {
        let made = deep + "/made/deeper/still"
        try await LocalFS().mkdir(LocalFS.path(made))
        let created = try await LocalFS().stat(LocalFS.path(made))
        XCTAssertEqual(created.kind, .directory)
    }

    func testRenamingWithinTheDeepDirectory() async throws {
        let from = try makeFile("before.txt", contents: "x")
        let to = deep + "/after.txt"

        try await LocalFS().rename(LocalFS.path(from), to: LocalFS.path(to))
        let renamed = try await LocalFS().stat(LocalFS.path(to))
        XCTAssertEqual(renamed.name, "after.txt")
        let gone = try? await LocalFS().stat(LocalFS.path(from))
        XCTAssertNil(gone, "the old name should be gone")
    }

    func testDeletingAFileAtDepth() async throws {
        let file = try makeFile("doomed.txt", contents: "x")
        try await LocalFS().delete(LocalFS.path(file))
        let gone = try? await LocalFS().stat(LocalFS.path(file))
        XCTAssertNil(gone)
    }

    /// The recursive case: a non-empty directory at depth. `unlinkat` alone cannot do this, so a
    /// version that forgot to empty it first fails here with ENOTEMPTY rather than silently.
    func testDeletingANonEmptyDirectoryAtDepth() async throws {
        let branch = deep + "/branch"
        try await LocalFS().mkdir(LocalFS.path(branch + "/inner"))
        let dir = DeepPath.openDirectory(branch + "/inner")
        try XCTSkipUnless(dir >= 0)
        let fd = "leaf.txt".withCString { openat(dir, $0, O_WRONLY | O_CREAT, 0o644) }
        close(dir)
        try XCTSkipUnless(fd >= 0)
        close(fd)

        try await LocalFS().delete(LocalFS.path(branch))
        let gone = try? await LocalFS().stat(LocalFS.path(branch))
        XCTAssertNil(gone, "the whole branch should be gone")
    }

    // MARK: - The shallow path is untouched

    func testAShortPathStillGoesThroughTheOrdinaryCalls() async throws {
        let file = root.appendingPathComponent("shallow.txt")
        try "shallow".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertFalse(DeepPath.isDeep(file.path))
        let entry = try await LocalFS().stat(LocalFS.path(file.path))
        XCTAssertEqual(entry.size, 7)
    }

    func testTheLimitIsCountedInBytesNotCharacters() {
        // 400 four-byte characters is 1600 bytes and 400 Characters: a length check on the String
        // would call this short and then hand the kernel something it refuses.
        let emoji = String(repeating: "🍑", count: 400)
        XCTAssertLessThan(emoji.count, DeepPath.syscallLimit)
        XCTAssertTrue(DeepPath.isDeep(emoji))
    }
}
