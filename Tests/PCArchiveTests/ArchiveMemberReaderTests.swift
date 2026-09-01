// SPDX-License-Identifier: Apache-2.0
// ArchiveMemberReaderTests.swift - Reading one member a piece at a time (F-479).
//
// The whole point of the incremental reader is that the member never exists whole, so the property
// worth guarding is not "it works" but "it produces exactly what the one-shot path produces" — for
// every size, every chunk size, and both compression methods. A streaming inflate that is subtly
// wrong does not crash; it hands back plausible bytes, which is the failure this file exists for.

import XCTest
@testable import PCArchive
@testable import PCVFS

final class ArchiveMemberReaderTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCMemberReader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    /// Compressible on purpose in places and not in others: a run of one byte and a run of random
    /// bytes take different paths through deflate, and a reader that is right about one can be
    /// wrong about the other.
    private func payload(_ size: Int) -> Data {
        var data = Data(capacity: size)
        var seed: UInt64 = 0x2545_F491_4F6C_DD1D
        for i in 0..<size {
            if i % 3 == 0 {
                data.append(0x41)
            } else {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                data.append(UInt8(truncatingIfNeeded: seed >> 33))
            }
        }
        return data
    }

    private func drain(_ reader: ArchiveMemberReader, chunk: Int) throws -> Data {
        var out = Data()
        while let piece = try reader.next(maxBytes: chunk) {
            XCTAssertFalse(piece.isEmpty, "an empty piece before the end is indistinguishable from the end")
            out.append(piece)
        }
        return out
    }

    // MARK: - The same bytes as the one-shot path

    func test_deflatedMemberStreamsExactlyWhatTheWholeReadProduces() throws {
        for size in [0, 1, 100, 65_535, 1 << 20, (1 << 20) + 7] {
            let content = payload(size)
            let url = dir.appendingPathComponent("d-\(size).zip")
            try ZipWriter.create(at: url, files: [(path: "m.bin", data: content)])
            let zip = try XCTUnwrap(ZipReader(fileURL: url))
            let entry = try XCTUnwrap(zip.entries.first { $0.path == "m.bin" })

            let whole = try zip.data(for: entry)
            XCTAssertEqual(whole, content, "size \(size): the one-shot read is the reference")

            for chunk in [1, 7, 4096, 1 << 20] {
                guard let reader = try zip.reader(for: entry, password: nil) else {
                    if size == 0 { continue }          // an empty member may decline; nothing to stream
                    return XCTFail("size \(size): no incremental reader for a plain deflated member")
                }
                XCTAssertEqual(try drain(reader, chunk: chunk), content,
                               "size \(size), chunk \(chunk)")
            }
        }
    }

    func test_storedMemberStreamsWithoutCopyingTheWhole() throws {
        // Stored entries are ranges of the mapped archive; the reader hands out slices of it.
        let content = payload(300_000)
        let src = dir.appendingPathComponent("ssrc", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try content.write(to: src.appendingPathComponent("m.bin"))
        let url = dir.appendingPathComponent("stored.zip")
        // `ZipWriter` deflates whenever that is smaller, so a stored entry comes from `zip -0` —
        // the same way `ZipReaderTests` builds one.
        let zipTool = Process()
        zipTool.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zipTool.arguments = ["-q", "-0", url.path, "m.bin"]
        zipTool.currentDirectoryURL = src
        try zipTool.run(); zipTool.waitUntilExit()
        try XCTSkipUnless(zipTool.terminationStatus == 0, "zip could not build the fixture")
        let zip = try XCTUnwrap(ZipReader(fileURL: url))
        let entry = try XCTUnwrap(zip.entries.first { $0.path == "m.bin" })
        XCTAssertEqual(entry.compressionMethod, 0, "this fixture is meant to be stored")
        let reader = try XCTUnwrap(zip.reader(for: entry, password: nil))
        XCTAssertEqual(try drain(reader, chunk: 8192), content)
    }

    // MARK: - What declines, and still works

    func test_aDirectoryOffersNoReader() throws {
        let url = dir.appendingPathComponent("dirs.zip")
        try ZipWriter.create(at: url, files: [(path: "sub/", data: Data()),
                                              (path: "sub/f.txt", data: Data("x".utf8))])
        let zip = try XCTUnwrap(ZipReader(fileURL: url))
        let entry = try XCTUnwrap(zip.entries.first { $0.isDirectory })
        XCTAssertNil(try zip.reader(for: entry, password: nil))
    }

    /// Encrypted members keep the one-shot path on purpose — the streaming inflate deliberately does
    /// not touch the decryption code. What must hold is that they still *read*.
    func test_anEncryptedMemberDeclinesAndIsStillReadableWhole() throws {
        let sevenZip = "/opt/homebrew/bin/7z"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: sevenZip), "7z not installed")
        let content = Data(String(repeating: "secret. ", count: 5000).utf8)
        let src = dir.appendingPathComponent("src", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try content.write(to: src.appendingPathComponent("s.txt"))
        let url = dir.appendingPathComponent("enc.zip")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: sevenZip)
        p.arguments = ["a", "-tzip", "-mem=AES256", "-pgeheim", "-y", url.path, "s.txt"]
        p.currentDirectoryURL = src
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        try XCTSkipUnless(p.terminationStatus == 0, "7z could not build the fixture")

        let zip = try XCTUnwrap(ZipReader(fileURL: url))
        let entry = try XCTUnwrap(zip.entries.first { $0.path == "s.txt" })
        XCTAssertTrue(entry.isEncrypted)
        XCTAssertNil(try zip.reader(for: entry, password: "geheim"),
                     "an encrypted member must keep the one-shot path")
        XCTAssertEqual(try zip.data(for: entry, password: "geheim"), content)
    }

    // MARK: - A broken member must end, and end loudly

    func test_aCorruptMemberEndsAndAnswersTheWayTheWholeReadDoes() throws {
        // Two things at once. **It must end**: a round that consumes nothing and produces nothing
        // will do the same next time, so without a per-round progress check the reader spins forever
        // on a broken member — a hang, worse than any wrong answer. And **it must agree with the
        // one-shot path**, which is the contract of this whole file: whatever `data(for:)` says
        // about a damaged archive, the incremental reader has to say too.
        //
        // Note what neither of them promises: deflate carries no integrity check of its own and
        // *neither path verifies the entry's CRC-32*, so corruption that still inflates to the
        // declared length comes back as bytes rather than as an error. That is pre-existing and
        // stated here rather than asserted away.
        let content = payload(400_000)
        let url = dir.appendingPathComponent("truncated.zip")
        try ZipWriter.create(at: url, files: [(path: "m.bin", data: content)])
        var bytes = try Data(contentsOf: url)
        let cut = bytes.count / 2
        let span = Swift.min(2048, bytes.count - cut)
        bytes.replaceSubrange(cut..<(cut + span), with: Data(repeating: 0, count: span))
        let broken = dir.appendingPathComponent("broken.zip")
        try bytes.write(to: broken)

        guard let zip = ZipReader(fileURL: broken),
              let entry = zip.entries.first(where: { $0.path == "m.bin" }) else {
            return   // refused outright, which is also a clean answer
        }
        let whole = Result { try zip.data(for: entry) }
        guard let reader = try zip.reader(for: entry, password: nil) else {
            return XCTFail("a plain deflated member must offer an incremental reader")
        }
        // Bounded by construction: `drain` stops when `next` returns nil or throws, and the reader
        // has to do one or the other. A hang here is the defect, and the test timing out is the
        // report.
        let streamed = Result { try drain(reader, chunk: 64 * 1024) }

        switch (whole, streamed) {
        case (.success(let a), .success(let b)):
            XCTAssertEqual(a, b, "the two paths disagree about a damaged member")
        case (.failure, .failure):
            break   // both refused it, which is the answer this fixture usually produces
        default:
            XCTFail("one path refused the member and the other did not")
        }
    }

    // MARK: - Through the filesystem, which is what the app actually uses

    func test_openReadUsesTheIncrementalPathAndDeliversTheMember() async throws {
        let content = payload(3 * (1 << 20))
        let url = dir.appendingPathComponent("fs.zip")
        try ZipWriter.create(at: url, files: [(path: "big.bin", data: content)])
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: url, fsID: "z"))

        let stream = try await fs.openRead(fs.path("/big.bin"))
        XCTAssertTrue(stream is ArchiveMemberStream, "openRead did not take the incremental path")
        var got = Data()
        for try await element in stream {
            if let chunk = element as? Data { got.append(chunk) }
        }
        try await stream.close()
        XCTAssertEqual(got, content)
    }

    func test_aTarMemberStreamsToo() async throws {
        // A tar member is a range of the tar the reader holds, so this is slicing — but it has to be
        // offered, or `openRead` silently keeps materialising every member.
        let tarURL = dir.appendingPathComponent("t.tar")
        let src = dir.appendingPathComponent("tsrc", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        let content = payload(200_000)
        try content.write(to: src.appendingPathComponent("m.bin"))
        let tar = Process()
        tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tar.arguments = ["-cf", tarURL.path, "-C", src.path, "m.bin"]
        try tar.run(); tar.waitUntilExit()
        try XCTSkipUnless(tar.terminationStatus == 0, "tar could not build the fixture")

        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: tarURL, fsID: "t"))
        let stream = try await fs.openRead(fs.path("/m.bin"))
        XCTAssertTrue(stream is ArchiveMemberStream)
        var got = Data()
        for try await element in stream {
            if let chunk = element as? Data { got.append(chunk) }
        }
        try await stream.close()
        XCTAssertEqual(got, content)
    }
}
