// SPDX-License-Identifier: Apache-2.0
// TrashRestoreTests.swift - The one shared step for putting a file back.
//
// Two callers now use it — the synchronisation run log and the assistant's undo of a
// `move_to_trash` — so it gets its own tests rather than being covered only through theirs. The
// assertion that matters is the refusal: a put-back that overwrites is a deletion wearing a
// recovery's clothes, and it is the only way this operation can destroy anything.

import XCTest
import PCFoundation

final class TrashRestoreTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-restore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func file(_ name: String, _ text: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
        return url
    }

    /// The bytes come back, at the path asked for, and the Trash no longer holds it — moved, not
    /// copied. Compared as bytes: a path that exists proves only that something is there.
    func test_theBytesComeBackAndTheTrashEntryIsGone() throws {
        let inTrash = try file("trash/notes.txt", "the bytes that have to survive")
        let original = dir.appendingPathComponent("home/notes.txt")
        try FileManager.default.createDirectory(at: original.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)

        XCTAssertNil(TrashRestore.refusal(from: inTrash.path, to: original.path))
        XCTAssertEqual(TrashRestore.restore(from: inTrash.path, to: original.path),
                       .restored(to: original.path))
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8),
                       "the bytes that have to survive")
        XCTAssertFalse(FileManager.default.fileExists(atPath: inTrash.path))
    }

    /// The only refusal whose failure destroys something. Whatever is at that path now was not put
    /// there by the operation being undone.
    func test_anOccupiedPathIsRefusedAndLeftAlone() throws {
        let inTrash = try file("trash/notes.txt", "the old one")
        let original = try file("home/notes.txt", "something else entirely")

        XCTAssertEqual(TrashRestore.refusal(from: inTrash.path, to: original.path),
                       "something is at that path again")
        XCTAssertEqual(TrashRestore.restore(from: inTrash.path, to: original.path),
                       .refused(reason: "something is at that path again"))
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "something else entirely")
        XCTAssertTrue(FileManager.default.fileExists(atPath: inTrash.path),
                      "the item was taken out of the Trash for nothing")
    }

    func test_anItemNoLongerInTheTrashIsRefused() throws {
        let original = dir.appendingPathComponent("home/notes.txt")
        XCTAssertEqual(TrashRestore.refusal(from: dir.appendingPathComponent("trash/gone.txt").path,
                                            to: original.path),
                       "it is no longer in the Trash")
    }

    /// A **dangling** symlink occupies the path, and `FileManager.fileExists` says it does not
    /// because it follows the link. `lstat` answers about the link itself, which is what the guard
    /// needs: restoring over it would replace something somebody put there.
    func test_aDanglingSymlinkCountsAsOccupied() throws {
        let inTrash = try file("trash/notes.txt", "the real file")
        let original = dir.appendingPathComponent("home/notes.txt")
        try FileManager.default.createDirectory(at: original.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: original.path,
                                                   withDestinationPath: "/nowhere/at/all")

        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path),
                       "the fixture is not a dangling link, so this proves nothing")
        XCTAssertEqual(TrashRestore.refusal(from: inTrash.path, to: original.path),
                       "something is at that path again")
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: original.path),
                       "/nowhere/at/all", "the symlink was replaced")
    }

    /// The folder it came from may be gone — a folder deleted whole takes its own entry with it.
    /// Created rather than refused, because refusing would make a subtree unrecoverable for the
    /// sake of one empty directory.
    func test_aMissingParentIsCreated() throws {
        let inTrash = try file("trash/deep.txt", "in a folder that is no longer there")
        let original = dir.appendingPathComponent("home/a/b/deep.txt")

        XCTAssertEqual(TrashRestore.restore(from: inTrash.path, to: original.path),
                       .restored(to: original.path))
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8),
                       "in a folder that is no longer there")
    }
}
