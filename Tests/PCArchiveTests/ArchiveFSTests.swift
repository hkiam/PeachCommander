// ArchiveFSTests.swift - Exercises ArchiveFS as a VirtualFileSystem, backed
// by zips built on the fly with the system `/usr/bin/zip` tool.

import XCTest
import PCVFS
@testable import PCArchive

final class ArchiveFSTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard FileManager.default.fileExists(atPath: "/usr/bin/zip") else {
            throw XCTSkip("/usr/bin/zip is not available on this machine")
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCArchive-ArchiveFSTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDir = dir
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    // MARK: - Fixture building

    /// Builds a zip archive from `files` (relative path -> content) using the
    /// system `zip` tool, then opens it as an `ArchiveFS`.
    private func makeArchiveFS(
        named zipName: String = "test.zip",
        files: [String: Data],
        fsID: String = "test-zip"
    ) throws -> ArchiveFS {
        let payloadDir = tempDir.appendingPathComponent("payload-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)

        for (relativePath, data) in files {
            let fileURL = payloadDir.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL)
        }

        let zipURL = tempDir.appendingPathComponent(zipName)
        let topLevelNames = try FileManager.default.contentsOfDirectory(atPath: payloadDir.path).sorted()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipURL.path] + topLevelNames
        process.currentDirectoryURL = payloadDir
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "zip tool exited non-zero")

        return try XCTUnwrap(ArchiveFS(archiveFileURL: zipURL, fsID: fsID))
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

    private static let sampleFiles: [String: Data] = [
        "readme.txt": Data("top-level readme".utf8),
        "docs/guide.txt": Data("guide contents".utf8),
        "docs/notes/detail.txt": Data("detail contents".utf8)
    ]

    // MARK: - Tests

    func test_init_returnsNil_forNonZipFile() throws {
        let notAZip = tempDir.appendingPathComponent("not-a-zip.zip")
        try Data("nope".utf8).write(to: notAZip)

        XCTAssertNil(ArchiveFS(archiveFileURL: notAZip, fsID: "bad"))
    }

    func test_list_root_includesFilesAndSynthesizedDirectories() async throws {
        let fs = try makeArchiveFS(files: Self.sampleFiles)

        let entries = try await collectEntries(fs.list(fs.path("/")))
        XCTAssertTrue(entries.contains { $0.name == "readme.txt" && $0.kind == .file })
        let docs = try XCTUnwrap(entries.first { $0.name == "docs" })
        XCTAssertEqual(docs.kind, .directory, "docs/ should be synthesized since it has no explicit zip entry")
    }

    func test_list_subdirectory_returnsChildren() async throws {
        let fs = try makeArchiveFS(files: Self.sampleFiles)

        let docsEntries = try await collectEntries(fs.list(fs.path("/docs")))
        XCTAssertTrue(docsEntries.contains { $0.name == "guide.txt" && $0.kind == .file })
        XCTAssertTrue(docsEntries.contains { $0.name == "notes" && $0.kind == .directory })
        XCTAssertEqual(docsEntries.count, 2)
    }

    func test_stat_file_returnsSizeAndKind() async throws {
        let fs = try makeArchiveFS(files: Self.sampleFiles)

        let entry = try await fs.stat(fs.path("/readme.txt"))
        XCTAssertEqual(entry.kind, .file)
        XCTAssertEqual(entry.size, Int64(Self.sampleFiles["readme.txt"]!.count))
    }

    func test_stat_directory_returnsDirectoryKind() async throws {
        let fs = try makeArchiveFS(files: Self.sampleFiles)

        let entry = try await fs.stat(fs.path("/docs/notes"))
        XCTAssertEqual(entry.kind, .directory)
    }

    func test_stat_missingPath_throwsNotFound() async throws {
        let fs = try makeArchiveFS(files: Self.sampleFiles)

        do {
            _ = try await fs.stat(fs.path("/does/not/exist.txt"))
            XCTFail("expected stat of a missing path to throw")
        } catch let error as VFSError {
            XCTAssertEqual(error, .notFound(fs.path("/does/not/exist.txt").path))
        }
    }

    func test_openRead_concatenatedChunks_equalFileBytes() async throws {
        let expected = Data(repeating: 0x5A, count: 3 * 1024 * 1024 + 17) // spans multiple 1 MB chunks
        let fs = try makeArchiveFS(files: ["big.bin": expected])

        let stream = try await fs.openRead(fs.path("/big.bin"))
        var readBack = Data()
        var chunkCount = 0
        for try await chunk in stream {
            readBack.append(chunk as! Data) // swiftlint:disable:this force_cast
            chunkCount += 1
        }
        try await stream.close()

        XCTAssertEqual(readBack, expected)
        XCTAssertGreaterThan(chunkCount, 1, "expected the ~3 MB file to span more than one 1 MB chunk")
    }

    func test_openRead_missingPath_throwsNotFound() async throws {
        let fs = try makeArchiveFS(files: Self.sampleFiles)

        do {
            _ = try await fs.openRead(fs.path("/nope.bin"))
            XCTFail("expected openRead of a missing path to throw")
        } catch let error as VFSError {
            XCTAssertEqual(error, .notFound(fs.path("/nope.bin").path))
        }
    }

    func test_openWrite_throwsUnsupported() async throws {
        let fs = try makeArchiveFS(files: Self.sampleFiles)

        do {
            _ = try await fs.openWrite(fs.path("/new.txt"), options: WriteOptions())
            XCTFail("expected openWrite to throw .unsupported")
        } catch let error as VFSError {
            XCTAssertEqual(error, .unsupported)
        }
    }

    func test_mutatingOperations_throwUnsupported() async throws {
        let fs = try makeArchiveFS(files: Self.sampleFiles)

        do {
            try await fs.mkdir(fs.path("/new-dir"))
            XCTFail("expected mkdir to throw .unsupported")
        } catch let error as VFSError {
            XCTAssertEqual(error, .unsupported)
        }

        do {
            try await fs.delete(fs.path("/readme.txt"))
            XCTFail("expected delete to throw .unsupported")
        } catch let error as VFSError {
            XCTAssertEqual(error, .unsupported)
        }

        do {
            try await fs.rename(fs.path("/readme.txt"), to: fs.path("/renamed.txt"))
            XCTFail("expected rename to throw .unsupported")
        } catch let error as VFSError {
            XCTAssertEqual(error, .unsupported)
        }

        do {
            try await fs.setAttributes(fs.path("/readme.txt"), attributes: VFSAttributes())
            XCTFail("expected setAttributes to throw .unsupported")
        } catch let error as VFSError {
            XCTAssertEqual(error, .unsupported)
        }
    }

    func test_watch_returnsNil() throws {
        let fs = try makeArchiveFS(files: Self.sampleFiles)
        XCTAssertNil(fs.watch(fs.path("/")))
    }

    func test_capabilities_isReadOnly() throws {
        let fs = try makeArchiveFS(files: Self.sampleFiles)
        XCTAssertTrue(fs.capabilities.contains(.read))
        XCTAssertFalse(fs.capabilities.contains(.write))
        XCTAssertFalse(fs.capabilities.contains(.rename))
        XCTAssertEqual(fs.scheme, "zip")
    }

    func test_localFileIfAvailable_extractsReadableTempFile() async throws {
        let content = Data("extract me please".utf8)
        let fs = try makeArchiveFS(files: ["extract.txt": content])

        let url = try await fs.localFileIfAvailable(fs.path("/extract.txt"))
        let fileURL = try XCTUnwrap(url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let onDisk = try Data(contentsOf: fileURL)
        XCTAssertEqual(onDisk, content)
    }

    func test_localFileIfAvailable_returnsNilForDirectory() async throws {
        let fs = try makeArchiveFS(files: Self.sampleFiles)
        let url = try await fs.localFileIfAvailable(fs.path("/docs"))
        XCTAssertNil(url)
    }

    // MARK: - Search inside an archive (F-153)

    func test_searchOverArchive_findsEntriesByName() async throws {
        let url = tempDir.appendingPathComponent("s.zip")
        try ZipWriter.create(at: url, files: [
            ("readme.txt", Data("x".utf8)),
            ("src/main.swift", Data("y".utf8)),
            ("src/util.swift", Data("z".utf8)),
        ])
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: url, fsID: "zip:s"))
        let engine = FileSearchEngine()
        let query = SearchQuery(nameMask: "*.swift", startDirectory: "/")
        var hits: [String] = []
        for await hit in await engine.search(query, fs: fs) { hits.append(hit.path) }
        XCTAssertEqual(Set(hits), Set(["/src/main.swift", "/src/util.swift"]))
    }

    // MARK: - Nested archives (F-134)

    /// The extract-and-mount chain the panel uses to browse a zip inside a zip:
    /// mount outer → extract inner.zip to a temp file → mount and list it.
    func test_nestedArchive_extractInnerAndBrowse() async throws {
        let innerURL = tempDir.appendingPathComponent("inner.zip")
        try ZipWriter.create(at: innerURL, files: [("hello.txt", Data("nested payload".utf8))])
        let outerURL = tempDir.appendingPathComponent("outer.zip")
        try ZipWriter.create(at: outerURL, files: [("inner.zip", try Data(contentsOf: innerURL))])

        let outer = try XCTUnwrap(ArchiveFS(archiveFileURL: outerURL, fsID: "zip:outer"))
        let tmp = try await outer.localFileIfAvailable(VFSPath(filesystemId: "zip:outer", path: "/inner.zip"))
        let innerFileURL = try XCTUnwrap(tmp)

        let inner = try XCTUnwrap(ArchiveFS(archiveFileURL: innerFileURL, fsID: "zip:inner"))
        var names: [String] = []
        for try await batch in inner.list(VFSPath(filesystemId: "zip:inner", path: "/")) {
            names.append(contentsOf: batch.entries.map(\.name))
        }
        XCTAssertEqual(names, ["hello.txt"])

        let payload = try await inner.localFileIfAvailable(VFSPath(filesystemId: "zip:inner", path: "/hello.txt"))
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(payload)), Data("nested payload".utf8))
    }
}
