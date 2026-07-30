// ZipWriterTests.swift - Round-trips ZipWriter output through ZipReader
// (and, for integrity, through the system `unzip -t`), covering deflate and
// store paths, nested directories, an explicit directory entry, and an
// empty file.

import XCTest
@testable import PCArchive

final class ZipWriterTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCArchive-ZipWriterTests-\(UUID().uuidString)", isDirectory: true)
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

    // MARK: - Fixture helpers

    /// Writes `files` to a fresh zip in `tempDir` and returns its URL.
    private func makeZip(named zipName: String = "test.zip", files: [(path: String, data: Data)]) throws -> URL {
        let zipURL = tempDir.appendingPathComponent(zipName)
        try ZipWriter.create(at: zipURL, files: files)
        return zipURL
    }

    /// Deterministic pseudo-random bytes (repeatable across runs), useful
    /// for an "incompressible" payload where deflate would not help.
    private func deterministicData(count: Int, seed: UInt64 = 0xABCD1234) -> Data {
        var state = seed
        var bytes = [UInt8](repeating: 0, count: count)
        for i in 0..<count {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            bytes[i] = UInt8((state >> 33) & 0xFF)
        }
        return Data(bytes)
    }

    // MARK: - Tests

    func test_roundTrip_threeFilesIncludingNestedPath() throws {
        let files: [(path: String, data: Data)] = [
            ("alpha.txt", Data("alpha contents".utf8)),
            ("sub/dir/file.txt", Data("nested file contents".utf8)),
            ("beta.txt", Data("beta contents, a bit longer than alpha".utf8))
        ]
        let zipURL = try makeZip(files: files)

        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))
        XCTAssertEqual(reader.entries.count, files.count)

        for (path, expected) in files {
            let entry = try XCTUnwrap(reader.entries.first { $0.path == path }, "missing entry \(path)")
            XCTAssertFalse(entry.isDirectory)
            XCTAssertEqual(entry.uncompressedSize, Int64(expected.count))
            XCTAssertEqual(try reader.data(for: entry), expected, "round-trip mismatch for \(path)")
        }
    }

    func test_largeCompressibleFile_deflatesAndRoundTrips() throws {
        let line = "The quick brown fox jumps over the lazy dog.\n"
        var text = ""
        while text.utf8.count < 300 * 1024 {
            text += line
        }
        let content = Data(text.utf8)
        let zipURL = try makeZip(files: [("big.txt", content)])

        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "big.txt" })
        XCTAssertLessThan(entry.compressedSize, entry.uncompressedSize, "expected deflate to shrink repetitive text")

        let decoded = try reader.data(for: entry)
        XCTAssertEqual(decoded.count, content.count)
        XCTAssertEqual(decoded, content)
    }

    func test_incompressibleAndTinyFiles_storeAndRoundTrip() throws {
        let tiny = Data("x".utf8)
        let random = deterministicData(count: 4_096)
        let zipURL = try makeZip(files: [
            ("tiny.txt", tiny),
            ("random.dat", random)
        ])

        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))

        let tinyEntry = try XCTUnwrap(reader.entries.first { $0.path == "tiny.txt" })
        XCTAssertEqual(try reader.data(for: tinyEntry), tiny)

        let randomEntry = try XCTUnwrap(reader.entries.first { $0.path == "random.dat" })
        XCTAssertEqual(try reader.data(for: randomEntry), random)
    }

    func test_emptyFile_roundTrips() throws {
        let zipURL = try makeZip(files: [("empty.txt", Data())])

        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "empty.txt" })
        XCTAssertFalse(entry.isDirectory)
        XCTAssertEqual(entry.uncompressedSize, 0)
        XCTAssertEqual(try reader.data(for: entry), Data())
    }

    func test_directoryEntry_isReportedAsDirectory() throws {
        let zipURL = try makeZip(files: [
            ("d/", Data()),
            ("d/file.txt", Data("inside d".utf8))
        ])

        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))
        let dirEntry = try XCTUnwrap(reader.entries.first { $0.path == "d/" })
        XCTAssertTrue(dirEntry.isDirectory)
        XCTAssertEqual(try reader.data(for: dirEntry), Data())

        let fileEntry = try XCTUnwrap(reader.entries.first { $0.path == "d/file.txt" })
        XCTAssertFalse(fileEntry.isDirectory)
        XCTAssertEqual(try reader.data(for: fileEntry), Data("inside d".utf8))
    }

    func test_unzipTool_verifiesIntegrity() throws {
        guard FileManager.default.fileExists(atPath: "/usr/bin/unzip") else {
            throw XCTSkip("/usr/bin/unzip is not available on this machine")
        }

        let line = "Integrity check payload line.\n"
        var text = ""
        while text.utf8.count < 50 * 1024 {
            text += line
        }
        let files: [(path: String, data: Data)] = [
            ("readme.txt", Data("hello from ZipWriter".utf8)),
            ("sub/dir/file.txt", Data("nested".utf8)),
            ("big.txt", Data(text.utf8)),
            ("empty.txt", Data()),
            ("d/", Data())
        ]
        let zipURL = try makeZip(files: files)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-t", zipURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0, "unzip -t reported archive integrity failure")
    }

    func test_multipleEntries_haveDistinctCRCsAndDecompressIndependently() throws {
        let files: [(path: String, data: Data)] = [
            ("first.txt", Data("first content, unique".utf8)),
            ("second.txt", Data("second content, also unique and different".utf8))
        ]
        let zipURL = try makeZip(files: files)

        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))
        for (path, expected) in files {
            let entry = try XCTUnwrap(reader.entries.first { $0.path == path })
            XCTAssertEqual(try reader.data(for: entry), expected)
        }
    }

    func test_pseudoRandomBinaryFile_roundTrips() throws {
        let content = deterministicData(count: 50_000, seed: 0xC0FFEE)
        let zipURL = try makeZip(files: [("binary.dat", content)])

        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "binary.dat" })
        XCTAssertEqual(try reader.data(for: entry), content)
    }
}
