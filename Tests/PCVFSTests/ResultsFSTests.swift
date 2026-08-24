// SPDX-License-Identifier: Apache-2.0
// ResultsFSTests.swift - Tests for `ResultsFS`, the flat read-only VFS over
// a fixed list of real local paths used to feed search results into a
// panel/listbox.

import XCTest
@testable import PCVFS

final class ResultsFSTests: XCTestCase {
    private var tempDir: URL!
    private var filePaths: [String]!
    private var fileContents: [String: Data]!
    private var fs: ResultsFS!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCVFSResults-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDir = dir

        var paths: [String] = []
        var contents: [String: Data] = [:]
        for (index, text) in ["alpha payload", "beta payload, a bit longer", "g"].enumerated() {
            let url = dir.appendingPathComponent("file\(index).txt")
            let data = Data(text.utf8)
            try data.write(to: url)
            paths.append(url.path)
            contents[url.path] = data
        }
        filePaths = paths
        fileContents = contents
        fs = ResultsFS(paths: paths, fsID: "results-test")
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        filePaths = nil
        fileContents = nil
        fs = nil
        try super.tearDownWithError()
    }

    private func collectEntries(_ stream: AsyncThrowingStream<VFSEntryBatch, Error>) async throws -> [VFSEntry] {
        var all: [VFSEntry] = []
        for try await batch in stream {
            all.append(contentsOf: batch.entries)
        }
        return all
    }

    // MARK: - list

    func test_list_root_yieldsOneEntryPerRealPath() async throws {
        let entries = try await collectEntries(fs.list(fs.path("/")))

        XCTAssertEqual(entries.count, filePaths.count)
        XCTAssertEqual(Set(entries.map(\.name)), Set(filePaths))
    }

    func test_list_nonRootDirectory_yieldsEmpty() async throws {
        let entries = try await collectEntries(fs.list(fs.path("/subdir")))
        XCTAssertTrue(entries.isEmpty, "ResultsFS is flat; only the root has entries")
    }

    // MARK: - stat

    func test_stat_returnsCorrectSizeAndKind() async throws {
        let target = filePaths[1]
        let entry = try await fs.stat(fs.path(target))

        XCTAssertEqual(entry.size, Int64(fileContents[target]!.count))
        XCTAssertEqual(entry.kind, .file)
        XCTAssertEqual(entry.name, target)
    }

    func test_stat_missingPath_throwsNotFound() async throws {
        let missing = tempDir.appendingPathComponent("does-not-exist.txt").path
        do {
            _ = try await fs.stat(fs.path(missing))
            XCTFail("expected stat of a missing real path to throw")
        } catch let error as VFSError {
            XCTAssertEqual(error, .notFound(missing))
        }
    }

    // MARK: - localFileIfAvailable

    func test_localFileIfAvailable_returnsURLToRealFile() async throws {
        let target = filePaths[0]
        let url = try await fs.localFileIfAvailable(fs.path(target))

        XCTAssertEqual(url, URL(fileURLWithPath: target))
    }

    func test_localFileIfAvailable_missingPath_returnsNil() async throws {
        let missing = tempDir.appendingPathComponent("gone.txt").path
        let url = try await fs.localFileIfAvailable(fs.path(missing))
        XCTAssertNil(url)
    }

    // MARK: - openRead

    func test_openRead_concatenatedChunks_equalFileBytes() async throws {
        let target = filePaths[1]
        let stream = try await fs.openRead(fs.path(target))
        var readBack = Data()
        for try await element in stream {
            guard let chunk = element as? Data else { continue }
            readBack.append(chunk)
        }
        try await stream.close()

        XCTAssertEqual(readBack, fileContents[target])
    }

    func test_openRead_missingPath_throwsNotFound() async throws {
        let missing = tempDir.appendingPathComponent("nope.txt").path
        do {
            _ = try await fs.openRead(fs.path(missing))
            XCTFail("expected openRead of a missing real path to throw")
        } catch let error as VFSError {
            XCTAssertEqual(error, .notFound(missing))
        }
    }

    // MARK: - Unsupported mutation

    func test_openWrite_throwsUnsupported() async throws {
        do {
            _ = try await fs.openWrite(fs.path(filePaths[0]), options: WriteOptions())
            XCTFail("expected openWrite to throw .unsupported")
        } catch let error as VFSError {
            XCTAssertEqual(error, .unsupported)
        }
    }

    func test_mkdirDeleteRenameSetAttributes_throwUnsupported() async throws {
        await assertThrowsUnsupported { try await self.fs.mkdir(self.fs.path("/newdir")) }
        await assertThrowsUnsupported { try await self.fs.delete(self.fs.path(self.filePaths[0])) }
        await assertThrowsUnsupported {
            try await self.fs.rename(self.fs.path(self.filePaths[0]), to: self.fs.path(self.filePaths[1]))
        }
        await assertThrowsUnsupported {
            try await self.fs.setAttributes(self.fs.path(self.filePaths[0]), attributes: VFSAttributes())
        }
    }

    private func assertThrowsUnsupported(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            XCTFail("expected operation to throw .unsupported")
        } catch let error as VFSError {
            XCTAssertEqual(error, .unsupported)
        } catch {
            XCTFail("expected VFSError.unsupported, got \(error)")
        }
    }

    // MARK: - Capabilities / watch

    func test_capabilities_isReadOnly() {
        XCTAssertEqual(fs.capabilities, [.read])
    }

    func test_watch_returnsNil() {
        XCTAssertNil(fs.watch(fs.path("/")))
    }

    // MARK: - Archive members (F-463)

    /// A row whose path is inside an archive cannot be `lstat`ed. It used to vanish
    /// from the listing silently — feeding ten archive hits to a panel produced an
    /// empty panel and no explanation.
    func test_list_keepsArchiveMembersAlongsideRealFiles() async throws {
        let display = "/somewhere/backup.tar.gz/etc/app.conf"
        let member = Self.memberEntry(name: "app.conf", size: 4096)
        let sources: [ResultsEntrySource] =
            [.local(filePaths[0]),
             .member(display: display, entry: member,
                     origin: SearchOrigin(containers: ["/somewhere/backup.tar.gz"],
                                          member: "etc/app.conf"))]
        let fs = ResultsFS(sources: sources, fsID: "results")

        var names: [String] = []
        for try await batch in fs.list(fs.path("/")) { names += batch.entries.map(\.name) }

        XCTAssertEqual(names.count, 2, "an archive member was dropped: \(names)")
        XCTAssertTrue(names.contains(display))
    }

    /// Listing must not open the archive: the size and date come from the snapshot the
    /// walk already took, or showing 400 hits would mean opening 90 archives.
    func test_list_usesTheSnapshotWithoutResolving() async throws {
        let display = "/a/x.zip/inner/big.bin"
        let stamp = Date(timeIntervalSince1970: 1_000_000)
        let member = Self.memberEntry(name: "big.bin", size: 123_456, modified: stamp)
        let resolverCalls = Counter()
        let fs = ResultsFS(sources: [.member(display: display, entry: member,
                                             origin: SearchOrigin(containers: ["/a/x.zip"],
                                                                  member: "inner/big.bin"))],
                           fsID: "results",
                           resolveMember: { _ in await resolverCalls.increment(); return nil })

        let entry = try await fs.stat(fs.path(display))
        XCTAssertEqual(entry.size, 123_456)
        XCTAssertEqual(entry.modified, stamp)
        let calls = await resolverCalls.count
        XCTAssertEqual(calls, 0, "listing an archive member must not open the archive")
    }

    /// Reading one goes through the host's resolver — this is what makes F3 and F5 work.
    func test_localFileIfAvailable_resolvesAMemberThroughTheHost() async throws {
        let extracted = tempDir.appendingPathComponent("extracted.conf")
        try Data("listen = 0.0.0.0\n".utf8).write(to: extracted)
        let display = "/a/x.tar.gz/etc/app.conf"
        let origin = SearchOrigin(containers: ["/a/x.tar.gz"], member: "etc/app.conf")
        let fs = ResultsFS(sources: [.member(display: display,
                                             entry: Self.memberEntry(name: "app.conf", size: 17),
                                             origin: origin)],
                           fsID: "results",
                           resolveMember: { asked in
                               XCTAssertEqual(asked, origin)
                               return extracted
                           })

        let url = try await fs.localFileIfAvailable(fs.path(display))
        XCTAssertEqual(url, extracted)
    }

    /// No resolver: the row still lists, and reading it says so rather than pretending.
    func test_memberWithoutResolver_listsButCannotBeRead() async throws {
        let display = "/a/x.zip/inner/f.txt"
        let fs = ResultsFS(sources: [.member(display: display,
                                             entry: Self.memberEntry(name: "f.txt", size: 1),
                                             origin: SearchOrigin(containers: ["/a/x.zip"],
                                                                  member: "inner/f.txt"))],
                           fsID: "results")

        var names: [String] = []
        for try await batch in fs.list(fs.path("/")) { names += batch.entries.map(\.name) }
        XCTAssertEqual(names, [display])

        await assertUnsupportedOrNotFound { _ = try await fs.openRead(fs.path(display)) }
    }

    private func assertUnsupportedOrNotFound(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            XCTFail("expected the read to fail")
        } catch let error as VFSError {
            guard case .notFound = error else {
                XCTFail("expected .notFound, got \(error)"); return
            }
        } catch {
            XCTFail("expected VFSError.notFound, got \(error)")
        }
    }

    private actor Counter {
        private(set) var count = 0
        func increment() { count += 1 }
    }

    private static func memberEntry(name: String, size: Int64,
                                    modified: Date = Date(timeIntervalSince1970: 0)) -> VFSEntry {
        VFSEntry(name: name, ext: (name as NSString).pathExtension, kind: .file, size: size,
                 modified: modified, created: nil, posixMode: 0o644, bsdFlags: 0, isHidden: false)
    }
}
