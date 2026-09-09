// SPDX-License-Identifier: Apache-2.0
// ArchiveEditorTests.swift - Rewrite-based in-archive delete/rename (F-133).

import XCTest
@testable import PCArchive

final class ArchiveEditorTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCArchive-ArchiveEditorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDir = dir
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        tempDir = nil
        try super.tearDownWithError()
    }

    private func makeZip(_ files: [(path: String, data: Data)]) throws -> URL {
        let url = tempDir.appendingPathComponent("a.zip")
        try ZipWriter.create(at: url, files: files)
        return url
    }

    /// A file that cannot be read must stop the add, not become a zero-byte entry.
    ///
    /// This is the shape that made it dangerous: F6 into an archive trashes the sources once the add
    /// reports success, so an entry with the right name, the right path and no content was written
    /// while the original went to the Trash — and the operation was reported as done. Both callers
    /// treat a throw as "nothing was added", so throwing is what stops that.
    func test_anUnreadableFileStopsTheAddInsteadOfWritingAnEmptyEntry() throws {
        let url = try makeZip([(path: "keep.txt", data: Data("keep".utf8))])
        let locked = tempDir.appendingPathComponent("secret.txt")
        try Data("real content".utf8).write(to: locked)
        try FileManager.default.setAttributes([.posixPermissions: 0o000],
                                              ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644],
                                                       ofItemAtPath: locked.path) }
        // The premise: this process really cannot read it. Without that the test proves nothing.
        XCTAssertNil(try? Data(contentsOf: locked), "the fixture is readable, so nothing is tested")

        do {
            try ArchiveEditor.add(to: url, entries: [(localPath: locked.path, arcPath: "secret.txt")])
            XCTFail("an unreadable file was added as an empty entry")
        } catch let error as ArchiveEditError {
            XCTAssertEqual(error, .unreadableItems([locked.path]))
        }
        // And the archive is untouched: the throw happens before the rewrite, so nothing is left
        // half-updated over it.
        XCTAssertEqual(try paths(url), ["keep.txt"])
    }

    /// A folder that cannot be listed must stop the add too — it became an *empty folder* entry,
    /// which is a claim about what is inside it.
    func test_anUnlistableFolderStopsTheAddInsteadOfClaimingItIsEmpty() throws {
        let url = try makeZip([(path: "keep.txt", data: Data("keep".utf8))])
        let folder = tempDir.appendingPathComponent("vault", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("hidden".utf8).write(to: folder.appendingPathComponent("inside.txt"))
        try FileManager.default.setAttributes([.posixPermissions: 0o000],
                                              ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                       ofItemAtPath: folder.path) }
        XCTAssertNil(try? FileManager.default.contentsOfDirectory(atPath: folder.path),
                     "the fixture is listable, so nothing is tested")

        do {
            try ArchiveEditor.add(to: url, entries: [(localPath: folder.path, arcPath: "vault")])
            XCTFail("an unlistable folder was added as an empty folder")
        } catch let error as ArchiveEditError {
            XCTAssertEqual(error, .unreadableItems([folder.path]))
        }
        XCTAssertEqual(try paths(url), ["keep.txt"])
    }

    /// A folder that really is empty still becomes an empty folder entry. The control: without it
    /// the guard above could have been "no children means refuse", which would stop an ordinary
    /// empty directory from being archived at all.
    func test_aGenuinelyEmptyFolderIsStillAdded() throws {
        let url = try makeZip([(path: "keep.txt", data: Data("keep".utf8))])
        let folder = tempDir.appendingPathComponent("hollow", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        try ArchiveEditor.add(to: url, entries: [(localPath: folder.path, arcPath: "hollow")])
        XCTAssertEqual(try paths(url), ["keep.txt", "hollow/"])
    }

    /// Every unreadable path at once, not the first one — `RenameBatchPlan`'s rule: a dialog per
    /// unreadable file in a folder of them is a dialog nobody reads to the end.
    func test_everyUnreadablePathIsNamed() throws {
        let url = try makeZip([(path: "keep.txt", data: Data("keep".utf8))])
        var locked: [String] = []
        for name in ["one.txt", "two.txt"] {
            let file = tempDir.appendingPathComponent(name)
            try Data("x".utf8).write(to: file)
            try FileManager.default.setAttributes([.posixPermissions: 0o000],
                                                  ofItemAtPath: file.path)
            locked.append(file.path)
        }
        defer {
            for p in locked {
                try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: p)
            }
        }

        do {
            try ArchiveEditor.add(to: url, entries: locked.map {
                (localPath: $0, arcPath: ($0 as NSString).lastPathComponent)
            })
            XCTFail("unreadable files were added")
        } catch let error as ArchiveEditError {
            XCTAssertEqual(error, .unreadableItems(locked))
        }
    }

    private func paths(_ url: URL) throws -> Set<String> {
        let reader = try XCTUnwrap(ZipReader(fileURL: url))
        return Set(reader.entries.map(\.path))
    }

    private func data(_ url: URL, _ path: String) throws -> Data {
        let reader = try XCTUnwrap(ZipReader(fileURL: url))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == path })
        return try reader.data(for: entry)
    }

    // MARK: - Remove

    func test_remove_dropsFileAndKeepsOthers() throws {
        let url = try makeZip([
            ("a.txt", Data("A".utf8)),
            ("b.txt", Data("B".utf8)),
            ("sub/c.txt", Data("C".utf8)),
        ])
        try ArchiveEditor.remove(from: url, paths: ["/b.txt"])
        XCTAssertEqual(try paths(url), ["a.txt", "sub/c.txt"])
        XCTAssertEqual(try data(url, "a.txt"), Data("A".utf8))    // survivor bytes intact
    }

    func test_remove_directoryDropsEverythingUnderIt() throws {
        let url = try makeZip([
            ("keep.txt", Data("K".utf8)),
            ("sub/one.txt", Data("1".utf8)),
            ("sub/deep/two.txt", Data("2".utf8)),
        ])
        try ArchiveEditor.remove(from: url, paths: ["/sub"])
        XCTAssertEqual(try paths(url), ["keep.txt"])
    }

    // MARK: - Rename

    func test_rename_file() throws {
        let url = try makeZip([
            ("old.txt", Data("hello".utf8)),
            ("other.txt", Data("x".utf8)),
        ])
        try ArchiveEditor.rename(in: url, from: "/old.txt", to: "/new.txt")
        XCTAssertEqual(try paths(url), ["new.txt", "other.txt"])
        XCTAssertEqual(try data(url, "new.txt"), Data("hello".utf8))
    }

    func test_rename_directoryRenamesAllDescendants() throws {
        let url = try makeZip([
            ("dir/a.txt", Data("A".utf8)),
            ("dir/nested/b.txt", Data("B".utf8)),
            ("outside.txt", Data("O".utf8)),
        ])
        try ArchiveEditor.rename(in: url, from: "/dir", to: "/renamed")
        XCTAssertEqual(try paths(url), ["renamed/a.txt", "renamed/nested/b.txt", "outside.txt"])
        XCTAssertEqual(try data(url, "renamed/nested/b.txt"), Data("B".utf8))
    }

    // MARK: - Add (F-133 copy-into / F-139 archive-to-archive)

    func test_add_fileIntoSubdirKeepsExistingEntries() throws {
        let url = try makeZip([("keep.txt", Data("K".utf8))])
        let local = tempDir.appendingPathComponent("new.txt")
        try Data("NEW".utf8).write(to: local)
        try ArchiveEditor.add(to: url, entries: [(local.path, "sub/new.txt")])
        XCTAssertEqual(try paths(url), ["keep.txt", "sub/new.txt"])
        XCTAssertEqual(try data(url, "sub/new.txt"), Data("NEW".utf8))
    }

    func test_add_overwritesExistingEntry() throws {
        let url = try makeZip([("a.txt", Data("OLD".utf8))])
        let local = tempDir.appendingPathComponent("a.txt")
        try Data("REPLACED".utf8).write(to: local)
        try ArchiveEditor.add(to: url, entries: [(local.path, "/a.txt")])
        XCTAssertEqual(try paths(url), ["a.txt"])
        XCTAssertEqual(try data(url, "a.txt"), Data("REPLACED".utf8))
    }

    func test_add_directoryRecursesIntoArcPath() throws {
        let url = try makeZip([("root.txt", Data("R".utf8))])
        let dir = tempDir.appendingPathComponent("folder")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("nested"), withIntermediateDirectories: true)
        try Data("1".utf8).write(to: dir.appendingPathComponent("one.txt"))
        try Data("2".utf8).write(to: dir.appendingPathComponent("nested/two.txt"))
        try ArchiveEditor.add(to: url, entries: [(dir.path, "dest/folder")])
        XCTAssertEqual(try paths(url), ["root.txt", "dest/folder/one.txt", "dest/folder/nested/two.txt"])
        XCTAssertEqual(try data(url, "dest/folder/nested/two.txt"), Data("2".utf8))
    }

    // MARK: - Integrity (F-135)

    func test_verify_intactArchiveHasNoProblems() throws {
        let url = try makeZip([
            ("a.txt", Data("hello world".utf8)),
            ("sub/b.txt", Data(String(repeating: "content ", count: 500).utf8)),
        ])
        let reader = try XCTUnwrap(ZipReader(fileURL: url))
        XCTAssertEqual(reader.verify(), [])
    }

    func test_verify_detectsCorruptedEntry() throws {
        let url = try makeZip([("data.txt", Data("the quick brown fox jumps".utf8))])
        var bytes = try Data(contentsOf: url)
        // Flip the first payload byte: local header (30) + name ("data.txt" = 8).
        let payloadOffset = 30 + "data.txt".utf8.count
        XCTAssertGreaterThan(bytes.count, payloadOffset)
        bytes[payloadOffset] ^= 0xFF
        try bytes.write(to: url)

        let reader = try XCTUnwrap(ZipReader(fileURL: url))
        let problems = reader.verify()
        XCTAssertFalse(problems.isEmpty)
        XCTAssertEqual(problems.first?.path, "data.txt")
    }
}
