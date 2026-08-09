// SPDX-License-Identifier: Apache-2.0
// ForeignReaderTests.swift - What this app writes, read by something that is not this app.
//
// The AppleDouble litter in every tar we packed was invisible for one reason: the tool that wrote it
// and the reader that read it agreed with each other. `tar -tf` hid the `._` members and our own
// browser showed them, and nobody had ever put a third party in between. So the formats this app
// produces for *other* programs are checked here against readers that know nothing about our code —
// python's zipfile and csv modules, and `shasum -c`.
//
// One finding worth writing down, because it looks like a defect and is not: macOS's bundled
// Info-ZIP `unzip` (6.00) ignores the UTF-8 filename flag. It renders "Grüße Straße.txt" as
// "Gr+++?e Stra+?e.txt" and then fails to write the file at all. The archive is correct — the flag is
// set, and python and 7z both read the name exactly — so `unzip` is not used as a witness here.

import XCTest
@testable import PCArchive
@testable import PCFoundation

final class ForeignReaderTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCForeign-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
        dir = nil
        try super.tearDownWithError()
    }

    /// Run a tool and return its output. Standard input is /dev/null: a tool that stops to ask a
    /// question would otherwise hang the whole test run, which is exactly what happened while writing
    /// these — `unzip` prompting about a name it had mangled.
    @discardableResult
    private func run(_ args: [String]) throws -> (out: String, status: Int32) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = args
        p.currentDirectoryURL = dir
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        p.standardInput = FileHandle.nullDevice
        try p.run()
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        return (out.trimmingCharacters(in: .whitespacesAndNewlines), p.terminationStatus)
    }

    // MARK: - A zip we wrote, read by python

    func testAZipWeWroteIsReadableByAnotherProgram() throws {
        let zip = dir.appendingPathComponent("box.zip")
        try ZipWriter.create(at: zip, files: [
            (path: "plain.txt", data: Data("eins\n".utf8)),
            (path: "ordner/tief.txt", data: Data("zwei\n".utf8)),
            (path: "Grüße Straße.txt", data: Data("drei\n".utf8)),
        ])
        let script = """
        import sys, zipfile
        z = zipfile.ZipFile(sys.argv[1])
        assert z.testzip() is None, 'CRC mismatch'
        for i in z.infolist():
            print(('utf8' if i.flag_bits & 0x800 else 'no-utf8'), i.filename, sep='\\t')
        print('content', z.read('ordner/tief.txt').decode(), sep='\\t')
        """
        let result = try run(["python3", "-c", script, zip.path])
        XCTAssertEqual(result.status, 0, result.out)
        // The UTF-8 filename flag has to be set, or every reader but ours guesses CP437 — which is what
        // macOS's own `unzip` does, turning the name into "Gr+++?e Stra+?e.txt".
        XCTAssertTrue(result.out.contains("utf8\tGrüße Straße.txt"), result.out)
        XCTAssertTrue(result.out.contains("utf8\tordner/tief.txt"), result.out)
        XCTAssertTrue(result.out.contains("content\tzwei"), result.out)
    }

    // MARK: - A checksum file we wrote, verified by shasum

    func testAChecksumFileWeWroteIsVerifiedByShasum() throws {
        let names = ["plain.txt", "zwei Wörter.txt"]
        for name in names { try Data("eins\n".utf8).write(to: dir.appendingPathComponent(name)) }
        var entries: [ChecksumEntry] = []
        for name in names {
            let digest = String(try run(["shasum", "-a", "256", name]).out.split(separator: " ").first ?? "")
            entries.append(ChecksumEntry(digest: digest, filename: name))
        }
        try ChecksumFile.generate(entries, format: .digestFirst)
            .write(to: dir.appendingPathComponent("sums.sha256"), atomically: true, encoding: .utf8)

        let verify = try run(["shasum", "-a", "256", "-c", "sums.sha256"])
        XCTAssertEqual(verify.status, 0, verify.out)
        XCTAssertTrue(verify.out.contains("plain.txt: OK"), verify.out)
        // A name with a space is where a two-column format usually comes apart.
        XCTAssertTrue(verify.out.contains("zwei Wörter.txt: OK"), verify.out)
    }

    // MARK: - A CSV we wrote, parsed by python's csv module

    func testACSVWeWroteIsParsedTheWayWeMeantIt() throws {
        // Every one of these is a name macOS will let you create, and every one of them breaks a CSV
        // that is written by joining with commas.
        let names = ["plain.txt", "mit,Komma.txt", "mit\"Anführung.txt",
                     "mit\r\nZeilenumbruch.txt", "Grüße; Straße.txt"]
        let rows = names.enumerated().map { index, name in
            FileListRow(name: name, ext: "txt", size: Int64(index + 1),
                        modified: Date(timeIntervalSince1970: 0))
        }
        let file = dir.appendingPathComponent("liste.csv")
        try FileListFormatter.format(rows, as: .csv)
            .write(to: file, atomically: true, encoding: .utf8)

        let script = """
        import csv, json, sys
        with open(sys.argv[1], newline='', encoding='utf-8') as f:
            rows = list(csv.reader(f))
        print(json.dumps([r[0] for r in rows], ensure_ascii=False))
        """
        let result = try run(["python3", "-c", script, file.path])
        XCTAssertEqual(result.status, 0, result.out)
        let parsed = try JSONDecoder().decode([String].self, from: Data(result.out.utf8))
        // Header plus one row per file — a name containing a line break must not become two rows, which
        // is what happened before the CRLF fix: six files came out as eight lines.
        XCTAssertEqual(parsed, ["Name"] + names, "a foreign parser read something else than we wrote")
    }
}
