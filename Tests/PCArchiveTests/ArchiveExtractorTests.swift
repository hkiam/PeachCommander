// SPDX-License-Identifier: Apache-2.0
// ArchiveExtractorTests.swift - Extract a nested zip (built with ZipWriter) through
// ArchiveFS and verify every member lands on disk with the right content.

import XCTest
@testable import PCArchive
@testable import PCVFS

final class ArchiveExtractorTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCArchiveExtract-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        try super.tearDownWithError()
    }

    func test_extractAll_writesEveryMemberWithStructure() async throws {
        let zipURL = tempDir.appendingPathComponent("a.zip")
        try ZipWriter.create(at: zipURL, files: [
            (path: "readme.txt", data: Data("top".utf8)),
            (path: "docs/guide.txt", data: Data("guide".utf8)),
            (path: "docs/notes/detail.txt", data: Data("detail".utf8)),
        ])
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: zipURL, fsID: "z"))
        let dest = tempDir.appendingPathComponent("out", isDirectory: true)

        let result = try await ArchiveExtractor.extractAll(from: fs, to: dest)

        XCTAssertEqual(result.files, 3)
        XCTAssertEqual(result.bytes, Int64("top".count + "guide".count + "detail".count))
        XCTAssertEqual(try String(contentsOf: dest.appendingPathComponent("readme.txt"), encoding: .utf8), "top")
        XCTAssertEqual(try String(contentsOf: dest.appendingPathComponent("docs/guide.txt"), encoding: .utf8), "guide")
        XCTAssertEqual(try String(contentsOf: dest.appendingPathComponent("docs/notes/detail.txt"), encoding: .utf8), "detail")
    }

    // MARK: - A crafted archive must not write outside the destination (F-131)
    //
    // "Zip Slip": a member named "../../evil.txt" extracted naively lands outside the folder the user
    // chose. Nothing here validated it, and the failure is completely silent — the extraction reports
    // success and a file appears somewhere the user was not looking, possibly overwriting one that
    // matters.

    /// The member is written out as it arrives now, not assembled in memory first — so the two
    /// things `.atomic` used to give have to be checked by hand: nothing half-written is left where
    /// a whole file is expected, and the scratch file does not survive.
    func test_extractAll_leavesNoScratchFileBehind() async throws {
        let zipURL = tempDir.appendingPathComponent("b.zip")
        // Bigger than one chunk, so more than one write goes into the same scratch file.
        let payload = Data(repeating: 0x42, count: 3 * 1024 * 1024)
        try ZipWriter.create(at: zipURL, files: [(path: "big.bin", data: payload)])
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: zipURL, fsID: "z"))
        let dest = tempDir.appendingPathComponent("out", isDirectory: true)

        let result = try await ArchiveExtractor.extractAll(from: fs, to: dest)

        XCTAssertEqual(result.bytes, Int64(payload.count))
        XCTAssertEqual(try Data(contentsOf: dest.appendingPathComponent("big.bin")), payload)
        let left = try FileManager.default.contentsOfDirectory(atPath: dest.path)
        XCTAssertEqual(left.sorted(), ["big.bin"], "a .pcpart scratch file survived the extraction")
    }

    func test_extractAll_overwritesAnExistingFileRatherThanAppendingToIt() async throws {
        // The scratch-and-move has to replace, not merge: an unpack over a previous one used to be
        // a plain atomic write, and a move onto an existing path fails unless it is cleared first.
        let zipURL = tempDir.appendingPathComponent("c.zip")
        try ZipWriter.create(at: zipURL, files: [(path: "note.txt", data: Data("new".utf8))])
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: zipURL, fsID: "z"))
        let dest = tempDir.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        try Data("a much longer previous content".utf8)
            .write(to: dest.appendingPathComponent("note.txt"))

        _ = try await ArchiveExtractor.extractAll(from: fs, to: dest)

        XCTAssertEqual(try String(contentsOf: dest.appendingPathComponent("note.txt"), encoding: .utf8), "new")
    }

    func test_extractAll_refusesToWriteAboveTheDestination() async throws {
        let zipURL = tempDir.appendingPathComponent("evil.zip")
        try ZipWriter.create(at: zipURL, files: [
            (path: "harmless.txt", data: Data("fine".utf8)),
            (path: "../escaped.txt", data: Data("should never be written here".utf8)),
            (path: "../../deeper.txt", data: Data("nor here".utf8)),
        ])
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: zipURL, fsID: "evil"))
        // Two levels of private folder below `tempDir`, so both "../" and "../../" have somewhere to
        // land that still belongs to this test. Checking the *system* temp directory instead — which is
        // what the first version did — made this test fail on a file its own earlier, pre-fix run had
        // left there, and the failure read as "still broken".
        let middle = tempDir.appendingPathComponent("middle", isDirectory: true)
        let dest = middle.appendingPathComponent("out", isDirectory: true)

        _ = try? await ArchiveExtractor.extractAll(from: fs, to: dest)

        for outside in ["escaped.txt", "deeper.txt"] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: middle.appendingPathComponent(outside).path),
                           "\(outside) was written beside the chosen folder")
            XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent(outside).path),
                           "\(outside) was written above the chosen folder")
        }
        // …and the harmless member still arrives: refusing the dangerous one must not abandon the rest.
        XCTAssertEqual(try? String(contentsOf: dest.appendingPathComponent("harmless.txt"), encoding: .utf8),
                       "fine")
    }

    func test_extractAll_keepsAnAbsoluteMemberNameInsideTheDestination() async throws {
        // A member stored as "/etc/passwd" is the same attack with a different spelling.
        let zipURL = tempDir.appendingPathComponent("abs.zip")
        try ZipWriter.create(at: zipURL, files: [
            (path: "/absolute.txt", data: Data("contained".utf8)),
        ])
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: zipURL, fsID: "abs"))
        let dest = tempDir.appendingPathComponent("out2", isDirectory: true)
        _ = try? await ArchiveExtractor.extractAll(from: fs, to: dest)

        XCTAssertFalse(FileManager.default.fileExists(atPath: "/absolute.txt"))
        let landed = FileManager.default.fileExists(atPath: dest.appendingPathComponent("absolute.txt").path)
        XCTAssertTrue(landed, "it may be refused or contained, but it must not vanish without a trace "
                      + "while the extraction reports success")
    }
}
