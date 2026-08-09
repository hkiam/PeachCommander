// SPDX-License-Identifier: Apache-2.0
// ShellArchiveEditorTests.swift - Adding files to a tar or 7z archive (F-139).
//
// Copying into an archive worked for zip and nothing else. The panel decides it is "in an archive" by
// asking whether the filesystem is an ArchiveFS — which also opens tar, 7z, rar and iso — so F5 into a
// .tar reached the zip rewriter, which asked ZipReader to read it, got nothing, and reported
// `unreadableArchive`. The archive was readable; it was not a zip.
//
// What each format can actually do was measured with the tools rather than read from a manual page:
// `tar -rf` appends to an uncompressed tar; macOS's bsdtar answers `--delete` with "Option --delete is
// not supported"; `tar -rf` on a .tar.gz says "Cannot append to compressed archive"; `7z a` and `7z d`
// both work in place. Those answers are what ArchiveWriteSupport encodes, and they are asserted here.
//
// The archives are read back with the app's own readers — if a tar can only be verified by the tool
// that wrote it, nothing has been shown about what the panel will display.

import XCTest
@testable import PCArchive
@testable import PCVFS

final class ShellArchiveEditorTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCArcAdd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
        dir = nil
        try super.tearDownWithError()
    }

    @discardableResult
    private func file(_ name: String, _ text: String) throws -> String {
        let url = dir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    /// The entry paths the app's own reader finds in the archive.
    private func entries(of archive: URL) async throws -> [String] {
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: archive, fsID: "t"))
        var names: [String] = []
        var queue = ["/"]
        while let path = queue.popLast() {
            for try await batch in fs.list(VFSPath(filesystemId: "t", path: path)) {
                for entry in batch.entries {
                    let full = path == "/" ? "/" + entry.name : path + "/" + entry.name
                    if entry.kind == .directory { queue.append(full) } else { names.append(full) }
                }
            }
        }
        return names.sorted()
    }

    // MARK: - What each format can do (measured, then encoded)

    func testTheCapabilityOfEachFormat() {
        let tools: (String) -> String? = { name in "/usr/bin/\(name)" }
        XCTAssertEqual(ArchiveWriteSupport.capability(forArchiveAt: "/x/a.zip", toolPath: tools), .rewrite)
        XCTAssertEqual(ArchiveWriteSupport.capability(forArchiveAt: "/x/a.tar", toolPath: tools),
                       .appendTar(tool: "/usr/bin/tar"))
        XCTAssertEqual(ArchiveWriteSupport.capability(forArchiveAt: "/x/a.7z", toolPath: tools),
                       .sevenZip(tool: "/usr/bin/7z"))
    }

    func testACompressedTarIsRefusedForTheRightReason() {
        // Measured: `tar -rf` on one answers "Cannot append to compressed archive". A two-part suffix
        // has to be recognised before its last part, or ".tar.gz" is read as ".gz".
        for name in ["a.tar.gz", "a.tgz", "a.tar.bz2", "a.tar.xz", "a.txz"] {
            XCTAssertEqual(ArchiveWriteSupport.capability(forArchiveAt: "/x/\(name)"),
                           .unsupported(.compressedStream), name)
        }
    }

    func testAFormatThisAppOnlyReadsIsRefusedByName() {
        // The reason carries the format so the message can name it rather than saying "not supported".
        XCTAssertEqual(ArchiveWriteSupport.capability(forArchiveAt: "/x/a.iso"),
                       .unsupported(.formatNotWritable("iso")))
        XCTAssertEqual(ArchiveWriteSupport.capability(forArchiveAt: "/x/a.rar"),
                       .unsupported(.formatNotWritable("rar")))
    }

    func testAMissingToolIsItsOwnReason() {
        // Not the same failure as an unwritable format: 7z is simply not installed on a stock Mac, and
        // the message should say so rather than blame the archive.
        XCTAssertEqual(ArchiveWriteSupport.capability(forArchiveAt: "/x/a.7z", toolPath: { _ in nil }),
                       .unsupported(.toolMissing("7z")))
        XCTAssertFalse(ArchiveWriteSupport.canAdd(toArchiveAt: "/x/a.7z", toolPath: { _ in nil }))
    }

    // MARK: - No AppleDouble litter
    //
    // macOS's tar writes a second `._name` member beside every file, carrying its extended attributes.
    // `tar -tf` hides those again when listing, which is how they went unnoticed — this app's own
    // reader shows them, so a tar packed here looked like it had twice as many files, and unpacking it
    // on Windows or Linux produced the same litter. Measured: without COPYFILE_DISABLE the reader lists
    // ["._a.txt", "a.txt"], with it ["a.txt"].

    func testAPackedTarHasNoAppleDoubleCompanions() async throws {
        try XCTSkipIf(PackEngine.toolPath("tar") == nil, "no tar on this machine")
        let archive = dir.appendingPathComponent("clean.tar")
        try PackEngine.pack(items: [try file("src/a.txt", "eins")], to: archive.path,
                            options: PackOptions(format: .tar))
        let found = try await entries(of: archive)
        XCTAssertEqual(found, ["/a.txt"])
    }

    func testAnAppendedFileBringsNoCompanionEither() async throws {
        try XCTSkipIf(PackEngine.toolPath("tar") == nil, "no tar on this machine")
        let archive = dir.appendingPathComponent("clean.tar")
        try PackEngine.pack(items: [try file("src/a.txt", "eins")], to: archive.path,
                            options: PackOptions(format: .tar))
        try ShellArchiveEditor.add(to: archive, entries: [(try file("src/b.txt", "zwei"), "b.txt")])
        let found = try await entries(of: archive)
        XCTAssertEqual(found, ["/a.txt", "/b.txt"])
    }

    // MARK: - Adding, verified with the app's own reader

    func testAddingToAnUncompressedTar() async throws {
        try XCTSkipIf(PackEngine.toolPath("tar") == nil, "no tar on this machine")
        let archive = dir.appendingPathComponent("box.tar")
        try PackEngine.pack(items: [try file("src/a.txt", "eins")], to: archive.path,
                            options: PackOptions(format: .tar))
        let added = try file("src/b.txt", "zwei")

        try ShellArchiveEditor.add(to: archive, entries: [(added, "b.txt")])

        let found = try await entries(of: archive)
        XCTAssertEqual(found, ["/a.txt", "/b.txt"])
    }

    func testAddingIntoASubdirectoryOfTheArchive() async throws {
        try XCTSkipIf(PackEngine.toolPath("tar") == nil, "no tar on this machine")
        // The panel can be *inside* the archive when you press F5, so the entry path has folders in it.
        // Both tools store the path relative to their working directory, which is what the staging
        // tree is for.
        let archive = dir.appendingPathComponent("box.tar")
        try PackEngine.pack(items: [try file("src/a.txt", "eins")], to: archive.path,
                            options: PackOptions(format: .tar))
        let added = try file("src/deep.txt", "tief")

        try ShellArchiveEditor.add(to: archive, entries: [(added, "docs/notes/deep.txt")])

        let found = try await entries(of: archive)
        XCTAssertEqual(found, ["/a.txt", "/docs/notes/deep.txt"])
    }

    func testAddingToA7z() async throws {
        try XCTSkipIf(PackEngine.toolPath("7z") == nil && PackEngine.toolPath("7za") == nil,
                      "7z is not installed on this machine")
        let archive = dir.appendingPathComponent("box.7z")
        try PackEngine.pack(items: [try file("src/a.txt", "eins")], to: archive.path,
                            options: PackOptions(format: .sevenZip))
        let added = try file("src/b.txt", "zwei")

        try ShellArchiveEditor.add(to: archive, entries: [(added, "b.txt")])

        let found = try await entries(of: archive)
        XCTAssertEqual(found, ["/a.txt", "/b.txt"])
    }

    func testTheOriginalEntriesSurviveTheAdd() async throws {
        try XCTSkipIf(PackEngine.toolPath("tar") == nil, "no tar on this machine")
        // An append that quietly replaced the archive would pass a "the new file is there" check.
        let archive = dir.appendingPathComponent("box.tar")
        try PackEngine.pack(items: [try file("src/keep.txt", "behalten")], to: archive.path,
                            options: PackOptions(format: .tar))
        try ShellArchiveEditor.add(to: archive, entries: [(try file("src/new.txt", "neu"), "new.txt")])

        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: archive, fsID: "t"))
        let stream = try await fs.openRead(VFSPath(filesystemId: "t", path: "/keep.txt"))
        var data = Data()
        for try await element in stream { if let chunk = element as? Data { data.append(chunk) } }
        try? await stream.close()
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "behalten")
    }

    // MARK: - The archive path comes from the panel

    func testAnEntryPathCannotStageOutsideTheStagingTree() throws {
        // The same rule as everywhere else a name from elsewhere becomes a path: a component that is
        // not a name would put the staged file above the temporary tree, and the tool would then add
        // whatever is there.
        let archive = dir.appendingPathComponent("box.tar")
        try PackEngine.pack(items: [try file("src/a.txt", "eins")], to: archive.path,
                            options: PackOptions(format: .tar))
        XCTAssertThrowsError(try ShellArchiveEditor.add(to: archive,
                                                        entries: [(try file("src/b.txt", "x"), "../escaped.txt")]))
    }

    func testAnUnsupportedFormatThrowsItsReason() throws {
        let archive = dir.appendingPathComponent("box.tar.gz")
        try PackEngine.pack(items: [try file("src/a.txt", "eins")], to: archive.path,
                            options: PackOptions(format: .tarGz))
        XCTAssertThrowsError(try ShellArchiveEditor.add(to: archive,
                                                        entries: [(try file("src/b.txt", "x"), "b.txt")])) { error in
            XCTAssertEqual(error as? ShellArchiveEditError, .unsupported(.compressedStream))
        }
    }
}
