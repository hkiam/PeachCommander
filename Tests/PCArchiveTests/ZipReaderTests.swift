// SPDX-License-Identifier: Apache-2.0
// ZipReaderTests.swift - Exercises ZipReader against zips built on the fly
// with the system `/usr/bin/zip` tool (default deflate, forced store via
// `-0`, nested directories, and a larger deflate-compressible payload).

import XCTest
@testable import PCArchive

final class ZipReaderTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard FileManager.default.fileExists(atPath: "/usr/bin/zip") else {
            throw XCTSkip("/usr/bin/zip is not available on this machine")
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCArchive-ZipReaderTests-\(UUID().uuidString)", isDirectory: true)
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

    /// Builds a zip archive from `files` (relative path -> content), using
    /// the system `zip` tool. `emptyDirectories` are created (with no
    /// files inside) so directory-only entries can be exercised.
    private func makeZip(
        named zipName: String = "test.zip",
        files: [String: Data],
        emptyDirectories: [String] = [],
        stored: Bool = false
    ) throws -> URL {
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
        for relativeDir in emptyDirectories {
            try FileManager.default.createDirectory(
                at: payloadDir.appendingPathComponent(relativeDir),
                withIntermediateDirectories: true
            )
        }

        let zipURL = tempDir.appendingPathComponent(zipName)
        let topLevelNames = try FileManager.default.contentsOfDirectory(atPath: payloadDir.path).sorted()

        var arguments = ["-r"]
        if stored { arguments.append("-0") }
        arguments.append(zipURL.path)
        arguments.append(contentsOf: topLevelNames)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = arguments
        process.currentDirectoryURL = payloadDir
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "zip tool exited non-zero")

        return zipURL
    }

    /// Deterministic pseudo-random bytes (repeatable across runs).
    private func deterministicData(count: Int, seed: UInt64 = 0xC0FFEE) -> Data {
        var state = seed
        var bytes = [UInt8](repeating: 0, count: count)
        for i in 0..<count {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            bytes[i] = UInt8((state >> 33) & 0xFF)
        }
        return Data(bytes)
    }

    // MARK: - Tests

    func test_init_returnsNil_forNonZipFile() throws {
        let notAZip = tempDir.appendingPathComponent("not-a-zip.zip")
        try Data("this is definitely not a zip file".utf8).write(to: notAZip)

        XCTAssertNil(ZipReader(fileURL: notAZip))
    }

    func test_init_returnsNil_forMissingFile() {
        let missing = tempDir.appendingPathComponent("does-not-exist.zip")
        XCTAssertNil(ZipReader(fileURL: missing))
    }

    func test_entries_matchNamesAndSizes() throws {
        let files: [String: Data] = [
            "alpha.txt": Data("alpha contents".utf8),
            "beta.txt": Data("beta contents, a bit longer than alpha".utf8),
            "gamma.txt": Data("gamma!".utf8)
        ]
        let zipURL = try makeZip(files: files)

        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))
        XCTAssertEqual(reader.entries.count, files.count)

        for entry in reader.entries {
            let expected = try XCTUnwrap(files[entry.path], "unexpected entry path \(entry.path)")
            XCTAssertEqual(entry.uncompressedSize, Int64(expected.count))
            XCTAssertFalse(entry.isDirectory)
        }
    }

    func test_data_returnsOriginalBytes_forEachEntry() throws {
        let files: [String: Data] = [
            "one.txt": Data("one".utf8),
            "two.txt": Data(repeating: 0x41, count: 5_000),
            "three.txt": Data("three-with-unicode-café".utf8)
        ]
        let zipURL = try makeZip(files: files)
        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))

        for entry in reader.entries {
            let expected = try XCTUnwrap(files[entry.path])
            let actual = try reader.data(for: entry)
            XCTAssertEqual(actual, expected, "round-trip mismatch for \(entry.path)")
        }
    }

    func test_storedEntry_roundTrips() throws {
        let content = Data("stored, not deflated".utf8)
        let zipURL = try makeZip(files: ["stored.txt": content], stored: true)
        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))

        let entry = try XCTUnwrap(reader.entries.first { $0.path == "stored.txt" })
        XCTAssertEqual(try reader.data(for: entry), content)
    }

    func test_nestedDirectoryPaths_present() throws {
        let files: [String: Data] = [
            "sub/nested/deep.txt": Data("deep content".utf8),
            "sub/shallow.txt": Data("shallow content".utf8)
        ]
        let zipURL = try makeZip(files: files)
        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))

        let deep = try XCTUnwrap(reader.entries.first { $0.path == "sub/nested/deep.txt" })
        XCTAssertFalse(deep.isDirectory)
        XCTAssertEqual(try reader.data(for: deep), files["sub/nested/deep.txt"])

        let shallow = try XCTUnwrap(reader.entries.first { $0.path == "sub/shallow.txt" })
        XCTAssertEqual(try reader.data(for: shallow), files["sub/shallow.txt"])
    }

    func test_emptyDirectoryEntry_isDirectory() throws {
        let zipURL = try makeZip(files: ["file.txt": Data("x".utf8)], emptyDirectories: ["empty-dir"])
        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))

        let dirEntry = reader.entries.first { $0.path.hasPrefix("empty-dir") }
        let dir = try XCTUnwrap(dirEntry, "expected an entry for the empty directory")
        XCTAssertTrue(dir.isDirectory)
        XCTAssertTrue(dir.path.hasSuffix("/"))
        XCTAssertEqual(try reader.data(for: dir), Data(), "directory data should be empty")
    }

    func test_largerFile_deflateRoundTripsExactly() throws {
        // Highly repetitive text (~200 KB) so zip's default heuristic picks
        // deflate over store, exercising the Compression-framework path.
        let line = "The quick brown fox jumps over the lazy dog.\n"
        var text = ""
        while text.utf8.count < 200 * 1024 {
            text += line
        }
        let content = Data(text.utf8)
        let zipURL = try makeZip(files: ["big.txt": content])

        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "big.txt" })
        XCTAssertLessThan(entry.compressedSize, entry.uncompressedSize, "expected deflate to shrink repetitive text")

        let decoded = try reader.data(for: entry)
        XCTAssertEqual(decoded.count, content.count)
        XCTAssertEqual(decoded, content)
    }

    func test_unicodeFilename_roundTrips() throws {
        let name = "café-🍑.txt"
        let content = Data("unicode payload".utf8)
        let zipURL = try makeZip(files: [name: content])

        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == name })
        XCTAssertEqual(try reader.data(for: entry), content)
    }

    func test_modified_isCloseToCreationTime() throws {
        let zipURL = try makeZip(files: ["timestamped.txt": Data("t".utf8)])
        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "timestamped.txt" })

        let modified = try XCTUnwrap(entry.modified)
        // DOS timestamps have 2-second resolution and are stored in local
        // time (interpreted here as UTC); allow generous slack so the
        // assertion isn't sensitive to the host's timezone offset.
        XCTAssertLessThan(abs(modified.timeIntervalSinceNow), 60 * 60 * 30)
    }

    func test_pseudoRandomBinaryFile_deflateRoundTrips() throws {
        let content = deterministicData(count: 50_000, seed: 0xABCD1234)
        let zipURL = try makeZip(files: ["binary.dat": content])

        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))
        let entry = try XCTUnwrap(reader.entries.first { $0.path == "binary.dat" })
        XCTAssertEqual(try reader.data(for: entry), content)
    }

    // MARK: - Does "test archive" actually detect anything? (F-135)
    //
    // A verifier that always answers "intact" is worse than none: it is the answer someone acts on
    // before deleting the originals. Nothing checked that this one says no to a broken archive.

    /// Byte range of the first member's *compressed data*, read out of its local header.
    ///
    /// Computed rather than guessed: my first attempt flipped byte 80 of a 140-byte archive, which is
    /// in the central directory — 4000 bytes of repeated text deflate to 32 — so nothing the CRC covers
    /// changed and the test reported the product broken.
    private func firstMemberDataRange(_ bytes: Data) -> Range<Int>? {
        func u16(_ at: Int) -> Int { Int(bytes[at]) | Int(bytes[at + 1]) << 8 }
        func u32(_ at: Int) -> Int { u16(at) | u16(at + 2) << 16 }
        guard bytes.count > 30, bytes[0] == 0x50, bytes[1] == 0x4B, bytes[2] == 0x03, bytes[3] == 0x04
        else { return nil }
        let start = 30 + u16(26) + u16(28)          // header + name + extra
        let length = u32(18)                        // compressed size
        guard length > 0, start + length <= bytes.count else { return nil }
        return start..<(start + length)
    }

    private func flipAByteOfTheFirstMembersData(_ url: URL) throws {
        var bytes = try Data(contentsOf: url)
        let range = try XCTUnwrap(firstMemberDataRange(bytes), "could not find the compressed data")
        bytes[range.lowerBound] = bytes[range.lowerBound] ^ 0xFF
        try bytes.write(to: url)
    }

    func test_verify_acceptsAnIntactArchive() throws {
        let url = tempDir.appendingPathComponent("intact.zip")
        try ZipWriter.create(at: url, files: [
            (path: "a.txt", data: Data(String(repeating: "content ", count: 500).utf8)),
            (path: "b.txt", data: Data("second".utf8)),
        ])
        let reader = try XCTUnwrap(ZipReader(fileURL: url))
        XCTAssertEqual(reader.verify(), [], "a good archive must not be reported as damaged either")
    }

    func test_verify_findsAFlippedByteInTheData() throws {
        let url = tempDir.appendingPathComponent("damaged.zip")
        let payload = Data(String(repeating: "content ", count: 500).utf8)
        try ZipWriter.create(at: url, files: [(path: "a.txt", data: payload)])
        // Inside the compressed bytes: the checksum in the directory still says what the file used to
        // be, so this is exactly the damage a CRC exists to find.
        try flipAByteOfTheFirstMembersData(url)

        let reader = try XCTUnwrap(ZipReader(fileURL: url))
        let problems = reader.verify()
        XCTAssertFalse(problems.isEmpty, "a flipped byte went unnoticed — the archive was reported intact")
        XCTAssertEqual(problems.first?.path, "a.txt")
    }

    func test_verify_reportsEveryDamagedMemberAndNotOnlyTheFirst() throws {
        // Stopping at the first problem would tell the user one file is bad when three are.
        let url = tempDir.appendingPathComponent("multi.zip")
        let payload = Data(String(repeating: "x", count: 400).utf8)
        try ZipWriter.create(at: url, files: [
            (path: "one.txt", data: payload),
            (path: "two.txt", data: payload),
            (path: "three.txt", data: payload),
        ])
        // Walk the local headers and flip one byte of every member's data, so the count is exact
        // instead of depending on where a third of the file happens to fall.
        var bytes = try Data(contentsOf: url)
        var cursor = 0
        var damaged = 0
        while cursor + 30 <= bytes.count, bytes[cursor] == 0x50, bytes[cursor + 1] == 0x4B,
              bytes[cursor + 2] == 0x03, bytes[cursor + 3] == 0x04 {
            func u16(_ at: Int) -> Int { Int(bytes[at]) | Int(bytes[at + 1]) << 8 }
            func u32(_ at: Int) -> Int { u16(at) | u16(at + 2) << 16 }
            let start = cursor + 30 + u16(cursor + 26) + u16(cursor + 28)
            let length = u32(cursor + 18)
            guard length > 0, start + length <= bytes.count else { break }
            bytes[start] = bytes[start] ^ 0xFF
            damaged += 1
            cursor = start + length
        }
        XCTAssertEqual(damaged, 3, "the fixture did not have three members to damage")
        try bytes.write(to: url)

        let reader = try XCTUnwrap(ZipReader(fileURL: url))
        XCTAssertEqual(reader.verify().count, 3, "three damaged members, \(reader.verify().count) reported")
    }
}
