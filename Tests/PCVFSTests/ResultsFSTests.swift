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
}
