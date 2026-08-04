// SPDX-License-Identifier: Apache-2.0
// Zip64ReadTests.swift - Reading archives that outgrew the classic 32-bit fields (F-362).
//
// Fixtures are built with python's `zipfile`, a reference implementation, the way the other archive
// tests use `/usr/bin/zip`. Two of the three shapes can be produced honestly at a few hundred kilobytes;
// the third — a central directory past the 4 GB mark — is assembled byte-faithfully instead of writing
// four gigabytes, because the only thing under test is which field the parser believes.
//
// The case worth having a test for at all is the *silent* one: an entry whose size does not fit in 32
// bits parses without complaint and reports 4294967295 bytes at an offset where no local header sits.

import XCTest
@testable import PCArchive

final class Zip64ReadTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard FileManager.default.fileExists(atPath: "/usr/bin/python3") else {
            throw XCTSkip("/usr/bin/python3 is not available on this machine")
        }
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCArchive-Zip64-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        tempDir = nil
        try super.tearDownWithError()
    }

    /// Run `script` with the archive path as argv[1] and return that path.
    private func build(_ name: String, _ script: String) throws -> URL {
        let zipURL = tempDir.appendingPathComponent(name)
        let scriptURL = tempDir.appendingPathComponent("build-\(UUID().uuidString).py")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [scriptURL.path, zipURL.path]
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()
        try XCTSkipUnless(process.terminationStatus == 0, "fixture build failed: \(message)")
        return zipURL
    }

    // MARK: - A per-entry ZIP64 extra field

    /// An entry in the shape a >4 GB member has: its size and offset fields hold the 0xFFFFFFFF
    /// sentinel, the real values live in a ZIP64 extra field, and the archive carries a ZIP64
    /// end-of-central-directory record — because that is how such an archive really looks.
    ///
    /// Crafted rather than produced, and every part of that sentence was learned the hard way:
    ///
    ///   * python's `force_zip64` writes the extra field but leaves the *true* small values in the
    ///     classic fields, so a fixture built that way passes whether the extra field is read or not —
    ///     which is what the first version of these tests did.
    ///   * sentinels in an archive with no ZIP64 EOCD record are a shape that does not occur: both
    ///     python and Info-ZIP refuse or ignore the extra field there.
    ///   * the header's extra-field length counts the whole field including its 4-byte id and size, not
    ///     just the payload. Four bytes short and every reference implementation calls it corrupt.
    ///
    /// So the fixture is validated by python reading it back before this test asserts anything.
    private func entryZip64() throws -> URL {
        try build("entry.zip", """
        import struct, sys, zipfile

        path = sys.argv[1]
        with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as z:
            z.writestr("big.txt", "hello zip64\\n")
            z.writestr("plain.txt", "no zip64 here\\n")

        d = bytearray(open(path, "rb").read())
        eocd = d.rfind(b"PK\\x05\\x06")
        count = struct.unpack_from("<H", d, eocd + 10)[0]
        cd_size = struct.unpack_from("<I", d, eocd + 12)[0]
        cd_off = struct.unpack_from("<I", d, eocd + 16)[0]

        # Walk the central directory to the record for big.txt.
        off = cd_off
        while off < cd_off + cd_size:
            n, e, c = struct.unpack_from("<HHH", d, off + 28)
            if bytes(d[off + 46:off + 46 + n]).decode() == "big.txt":
                break
            off += 46 + n + e + c

        csize, usize = struct.unpack_from("<II", d, off + 20)
        lho = struct.unpack_from("<I", d, off + 42)[0]
        # Real values into a ZIP64 extra field; the order is fixed by the specification.
        extra = struct.pack("<HHQQQ", 0x0001, 24, usize, csize, lho)
        struct.pack_into("<II", d, off + 20, 0xFFFFFFFF, 0xFFFFFFFF)
        struct.pack_into("<I", d, off + 42, 0xFFFFFFFF)
        struct.pack_into("<H", d, off + 30, len(extra))   # the WHOLE field, id and size included
        n = struct.unpack_from("<H", d, off + 28)[0]
        d[off + 46 + n:off + 46 + n] = extra
        # The insert sits before the EOCD, so its offset moved with it.
        eocd += len(extra)
        cd_size += len(extra)
        struct.pack_into("<I", d, eocd + 12, cd_size)

        # And make it a real ZIP64 archive: the record plus its locator, before the classic EOCD.
        body = bytes(d[:eocd])
        record = struct.pack("<IQHHIIQQQQ", 0x06064b50, 44, 45, 45, 0, 0,
                             count, count, cd_size, cd_off)
        locator = struct.pack("<IIQI", 0x07064b50, 0, len(body), 1)
        open(path, "wb").write(body + record + locator + bytes(d[eocd:]))

        # The fixture is only worth anything if a reference implementation agrees it is an archive.
        with zipfile.ZipFile(path) as z:
            assert z.read("big.txt") == b"hello zip64\\n", "crafted fixture is not a valid zip"
        """)
    }

    func testAnEntryWithAZip64ExtraFieldReportsItsRealSize() throws {
        let reader = try XCTUnwrap(ZipReader(fileURL: try entryZip64()))
        let big = try XCTUnwrap(reader.entries.first { $0.path == "big.txt" })
        // The failure this replaces: 0xFFFFFFFF read as a size, i.e. 4294967295 for a 12-byte file.
        XCTAssertEqual(big.uncompressedSize, 12)
        XCTAssertNotEqual(big.uncompressedSize, 4_294_967_295)
    }

    func testSuchAnEntryStillExtracts() throws {
        // The local header offset is in the same extra field. Reading the classic sentinel instead sent
        // the extractor to offset 0xFFFFFFFF and produced "bad local file header signature".
        let reader = try XCTUnwrap(ZipReader(fileURL: try entryZip64()))
        let big = try XCTUnwrap(reader.entries.first { $0.path == "big.txt" })
        XCTAssertEqual(try reader.data(for: big), Data("hello zip64\n".utf8))
    }

    func testAPlainEntryInTheSameArchiveIsUnaffected() throws {
        let reader = try XCTUnwrap(ZipReader(fileURL: try entryZip64()))
        let plain = try XCTUnwrap(reader.entries.first { $0.path == "plain.txt" })
        XCTAssertEqual(plain.uncompressedSize, 14)
        XCTAssertEqual(try reader.data(for: plain), Data("no zip64 here\n".utf8))
    }

    func testVerifyPassesOnAZip64Archive() throws {
        // Sizes and CRCs must line up end to end, not just look plausible in the listing.
        let reader = try XCTUnwrap(ZipReader(fileURL: try entryZip64()))
        XCTAssertEqual(reader.verify(), [])
    }

    // MARK: - More entries than a 16-bit count can hold

    func testAnArchiveWithMoreThan65535EntriesListsThemAll() throws {
        let zipURL = try build("many.zip", """
        import sys, zipfile
        with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_STORED, allowZip64=True) as z:
            for i in range(70000):
                z.writestr("f%05d.txt" % i, "x")
        """)
        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))
        // The classic count field holds 0xFFFF here; believing it would list 65535 of 70000.
        XCTAssertEqual(reader.entries.count, 70_000)
        let last = try XCTUnwrap(reader.entries.last)
        XCTAssertEqual(last.path, "f69999.txt")
        XCTAssertEqual(try reader.data(for: last), Data("x".utf8))
    }

    // MARK: - A central directory past the 4 GB mark

    /// A small archive rewritten to look like one whose central directory sits beyond 4 GB: the classic
    /// offset field carries the sentinel and the real one lives in a ZIP64 EOCD record.
    func testTheDirectoryOffsetIsTakenFromTheZip64Record() throws {
        let zipURL = try build("sentinel.zip", """
        import struct, sys, zipfile

        path = sys.argv[1]
        with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as z:
            z.writestr("one.txt", "first\\n")
            z.writestr("two.txt", "second\\n")

        data = bytearray(open(path, "rb").read())
        eocd = data.rfind(b"PK\\x05\\x06")
        count = struct.unpack_from("<H", data, eocd + 10)[0]
        cd_size = struct.unpack_from("<I", data, eocd + 12)[0]
        cd_off = struct.unpack_from("<I", data, eocd + 16)[0]

        # ZIP64 end-of-central-directory record: the real count, size and offset.
        record = struct.pack("<IQHHIIQQQQ", 0x06064b50, 44, 45, 45, 0, 0,
                             count, count, cd_size, cd_off)
        body = data[:eocd]
        locator = struct.pack("<IIQI", 0x07064b50, 0, len(body), 1)
        # The classic record keeps sentinels, which is what a real >4 GB archive stores.
        struct.pack_into("<I", data, eocd + 16, 0xFFFFFFFF)
        open(path, "wb").write(bytes(body) + record + locator + bytes(data[eocd:]))
        """)
        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))
        XCTAssertEqual(reader.entries.map(\.path), ["one.txt", "two.txt"])
        XCTAssertEqual(try reader.data(for: reader.entries[1]), Data("second\n".utf8))
    }

    // MARK: - Not believing a broken ZIP64 record

    func testALocatorPointingNowhereIsRefusedRatherThanTrusted() throws {
        // If the record cannot be read, the sentinels are all that is left — and using them as real
        // values would list an entry at offset 0xFFFFFFFF. Refusing lets ArchiveFS fall back to bsdtar.
        let zipURL = try build("broken.zip", """
        import struct, sys, zipfile

        path = sys.argv[1]
        with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as z:
            z.writestr("one.txt", "first\\n")

        data = bytearray(open(path, "rb").read())
        eocd = data.rfind(b"PK\\x05\\x06")
        # A locator whose record offset is far outside the file.
        locator = struct.pack("<IIQI", 0x07064b50, 0, 1 << 40, 1)
        struct.pack_into("<I", data, eocd + 16, 0xFFFFFFFF)
        open(path, "wb").write(bytes(data[:eocd]) + locator + bytes(data[eocd:]))
        """)
        XCTAssertNil(ZipReader(fileURL: zipURL),
                     "a ZIP64 record outside the archive must not be parsed as a classic zip")
    }

    // MARK: - The classic case is untouched

    func testAClassicArchiveIsReadExactlyAsBefore() throws {
        let zipURL = try build("classic.zip", """
        import sys, zipfile
        with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
            z.writestr("a.txt", "alpha\\n")
            z.writestr("dir/b.txt", "beta\\n")
        """)
        let reader = try XCTUnwrap(ZipReader(fileURL: zipURL))
        XCTAssertEqual(reader.entries.map(\.path), ["a.txt", "dir/b.txt"])
        XCTAssertEqual(try reader.data(for: reader.entries[0]), Data("alpha\n".utf8))
        XCTAssertEqual(reader.verify(), [])
    }
}

// MARK: - Through the layer the panels actually use

extension Zip64ReadTests {

    /// `ZipReader` reading it is one thing; the panel goes through `ArchiveFS`, and until now a ZIP64
    /// archive either fell through to the bsdtar source by accident or listed wrong sizes. This is the
    /// path a user takes when pressing Enter on the archive.
    func testAZip64ArchiveIsBrowsableThroughArchiveFS() async throws {
        let zipURL = try entryZip64()
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: zipURL, fsID: "zip:z64"))
        var names: [String: Int64] = [:]
        for try await batch in fs.list(fs.path("/")) {
            for entry in batch.entries { names[entry.name] = entry.size }
        }
        XCTAssertEqual(names["big.txt"], 12)
        XCTAssertEqual(names["plain.txt"], 14)
        let file = try await fs.localFileIfAvailable(fs.path("/big.txt"))
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(file)), Data("hello zip64\n".utf8))
    }
}
