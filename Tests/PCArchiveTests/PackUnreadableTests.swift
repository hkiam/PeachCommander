// SPDX-License-Identifier: Apache-2.0
// PackUnreadableTests.swift - Packing refuses what it cannot read, instead of archiving a claim.
//
// Its own file rather than a case in `PackEngineTests`, which skips itself unless 7z is installed:
// this exercises the built-in zip writer and needs no tool, and a test that silently skips reads
// exactly like a test that passes.
//
// The file half has always thrown. The **folder** half did not: `?? []` on a directory it could not
// list wrote an entry saying the folder was empty and reported the pack as complete, so somebody
// archiving a tree as a backup got a silently incomplete one. Same shape as the sync walk's
// unreadable subtree, and as `ArchiveEditor.add`'s zero-byte entry.

import XCTest
@testable import PCArchive

final class PackUnreadableTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-packunread-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private var archive: String { dir.appendingPathComponent("out.zip").path }

    func test_aFolderThatCannotBeListedIsRefusedRatherThanArchivedAsEmpty() throws {
        let src = dir.appendingPathComponent("src", isDirectory: true)
        let vault = src.appendingPathComponent("vault", isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        try Data("hidden".utf8).write(to: vault.appendingPathComponent("inside.txt"))
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: vault.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                       ofItemAtPath: vault.path) }
        // The premise. Without it the fixture proves nothing.
        XCTAssertNil(try? FileManager.default.contentsOfDirectory(atPath: vault.path))

        do {
            try PackEngine.packZipWithBuiltInWriter(items: [vault.path], to: archive,
                                                    parent: src.path)
            XCTFail("an unlistable folder was archived as an empty one")
        } catch let error as PackError {
            guard case .failed(let message, _) = error else {
                return XCTFail("expected a named failure, got \(error)")
            }
            XCTAssertTrue(message.contains("vault"), "the folder has to be named: \(message)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: archive),
                       "a refused pack must not leave an archive behind")
    }

    /// A folder that really is empty is still archived. The control: without it the guard could have
    /// been "no children means refuse", which would stop an ordinary empty directory being packed.
    func test_aGenuinelyEmptyFolderIsStillArchived() throws {
        let src = dir.appendingPathComponent("src", isDirectory: true)
        let hollow = src.appendingPathComponent("hollow", isDirectory: true)
        try FileManager.default.createDirectory(at: hollow, withIntermediateDirectories: true)

        try PackEngine.packZipWithBuiltInWriter(items: [hollow.path], to: archive,
                                                parent: src.path)
        guard let reader = ZipReader(fileURL: URL(fileURLWithPath: archive)) else {
            return XCTFail("no archive was written")
        }
        XCTAssertEqual(reader.entries.map(\.path), ["hollow/"])
    }

    /// And the file half, which has always thrown — asserted so the two halves stay together if one
    /// of them is ever touched.
    func test_aFileThatCannotBeReadIsRefused() throws {
        let src = dir.appendingPathComponent("src", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        let secret = src.appendingPathComponent("secret.txt")
        try Data("real".utf8).write(to: secret)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: secret.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644],
                                                       ofItemAtPath: secret.path) }
        XCTAssertNil(try? Data(contentsOf: secret))

        XCTAssertThrowsError(try PackEngine.packZipWithBuiltInWriter(items: [secret.path],
                                                                     to: archive, parent: src.path))
    }
}
