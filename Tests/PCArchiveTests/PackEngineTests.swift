// SPDX-License-Identifier: Apache-2.0
// PackEngineTests.swift - Round-trips PackEngine across formats, AES passwords,
// and multi-volume splits, verifying with the system extractors.

import XCTest
@testable import PCArchive

final class PackEngineTests: XCTestCase {
    private var dir: URL!
    private let files = ["a.txt": "alpha alpha alpha\n",
                         "sub/b.txt": String(repeating: "beta ", count: 400)]

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(PackEngine.toolPath("7z") != nil, "7z not installed")
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("PackEngine-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        if let dir { try? FileManager.default.removeItem(at: dir) }
    }

    /// Create the payload under `dir/src` and return the item paths to pack.
    private func makePayload() throws -> [String] {
        let src = dir.appendingPathComponent("src")
        for (rel, content) in files {
            let url = src.appendingPathComponent(rel)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.data(using: .utf8)!.write(to: url)
        }
        // Pack the two top-level items: a.txt and sub/.
        return [src.appendingPathComponent("a.txt").path, src.appendingPathComponent("sub").path]
    }

    /// Run a tool, returning (status, stdout).
    @discardableResult
    private func run(_ tool: String, _ args: [String], cwd: URL? = nil) throws -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        if let cwd { p.currentDirectoryURL = cwd }
        let out = Pipe(); p.standardOutput = out; p.standardError = out
        try p.run(); p.waitUntilExit()
        return (p.terminationStatus, String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
    }

    /// Extract `archive` into a fresh dir and assert both payload files match.
    private func assertExtractsToPayload(_ archive: String, tar: Bool, password: String? = nil) throws {
        let outDir = dir.appendingPathComponent("out-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        if tar {
            let (st, log) = try run("/usr/bin/tar", ["-xf", archive, "-C", outDir.path])
            XCTAssertEqual(st, 0, "tar extract failed: \(log)")
        } else {
            var args = ["x", archive, "-o\(outDir.path)", "-y"]
            if let password { args.append("-p\(password)") }
            let (st, log) = try run(PackEngine.toolPath("7z")!, args)
            XCTAssertEqual(st, 0, "7z extract failed: \(log)")
        }
        let a = try String(contentsOf: outDir.appendingPathComponent("a.txt"), encoding: .utf8)
        let b = try String(contentsOf: outDir.appendingPathComponent("sub/b.txt"), encoding: .utf8)
        XCTAssertEqual(a, files["a.txt"])
        XCTAssertEqual(b, files["sub/b.txt"])
    }

    // MARK: - Formats

    func test_roundTrip_allFormats() throws {
        let cases: [(PackFormat, Bool)] = [
            (.zip, false), (.sevenZip, false),
            (.tar, true), (.tarGz, true), (.tarBz2, true), (.tarXz, true),
        ]
        for (format, isTar) in cases {
            let items = try makePayload()
            let archive = dir.appendingPathComponent("out.\(format.fileExtension)").path
            try PackEngine.pack(items: items, to: archive, options: PackOptions(format: format))
            XCTAssertTrue(FileManager.default.fileExists(atPath: archive), "\(format) not created")
            try assertExtractsToPayload(archive, tar: isTar)
            try FileManager.default.removeItem(at: dir.appendingPathComponent("src"))
        }
    }

    // MARK: - Password (AES-256)

    func test_zipAES_wrongPasswordFails_rightPasswordExtracts() throws {
        let items = try makePayload()
        let archive = dir.appendingPathComponent("secret.zip").path
        try PackEngine.pack(items: items, to: archive, options: PackOptions(format: .zip, password: "s3cr3t"))
        // Wrong password → extraction/test fails.
        let (wrongStatus, _) = try run(PackEngine.toolPath("7z")!, ["t", archive, "-pWRONG", "-y"])
        XCTAssertNotEqual(wrongStatus, 0)
        // Right password → payload recovered.
        try assertExtractsToPayload(archive, tar: false, password: "s3cr3t")
    }

    func test_sevenZipAES_roundTrips() throws {
        let items = try makePayload()
        let archive = dir.appendingPathComponent("secret.7z").path
        try PackEngine.pack(items: items, to: archive, options: PackOptions(format: .sevenZip, password: "pw123"))
        let (wrongStatus, _) = try run(PackEngine.toolPath("7z")!, ["t", archive, "-pnope", "-y"])
        XCTAssertNotEqual(wrongStatus, 0)
        try assertExtractsToPayload(archive, tar: false, password: "pw123")
    }

    // MARK: - Split volumes

    func test_split_createsVolumes_andRecombines() throws {
        let items = try makePayload()
        let archive = dir.appendingPathComponent("big.7z").path
        // Store (level 0) + 512-byte volumes → the ~2 KB payload yields several
        // volumes (compression would otherwise shrink it below one volume).
        try PackEngine.pack(items: items, to: archive,
                            options: PackOptions(format: .sevenZip, splitSize: 512, level: 0))
        XCTAssertTrue(FileManager.default.fileExists(atPath: archive + ".001"), "first volume missing")
        XCTAssertTrue(FileManager.default.fileExists(atPath: archive + ".002"), "expected multiple volumes")
        // 7z extracts starting from the first volume.
        try assertExtractsToPayload(archive + ".001", tar: false)
    }

    // MARK: - Unsupported combinations

    func test_passwordOnTar_throwsUnsupported() throws {
        let items = try makePayload()
        XCTAssertThrowsError(
            try PackEngine.pack(items: items, to: dir.appendingPathComponent("x.tar").path,
                                options: PackOptions(format: .tar, password: "pw"))
        ) { XCTAssertEqual($0 as? PackError, .unsupportedOption("encryption not supported for tar")) }
    }

    func test_rar_reportsToolNotFound_whenMissing() throws {
        try XCTSkipUnless(PackEngine.toolPath("rar") == nil, "rar is installed; skip the missing-tool path")
        let items = try makePayload()
        XCTAssertThrowsError(
            try PackEngine.pack(items: items, to: dir.appendingPathComponent("x.rar").path,
                                options: PackOptions(format: .rar))
        ) { XCTAssertEqual($0 as? PackError, .toolNotFound("rar")) }
    }

    // MARK: - The password must not be in the argument list (F-136)
    //
    // `-p<password>` puts it in the process's argv, where `ps` shows it in full to anything running as
    // the same user for as long as the archive takes to write. Measured before it was changed: a running
    // pack showed "-pGEHEIMES-PASSWORT" in `ps -ww` output. `7z -p` with no value reads it from standard
    // input instead — verified by packing that way and opening the result with the password.

    func test_thePasswordNeverAppearsInTheArguments() throws {
        let secret = "correct-horse-battery-staple"
        for format in [PackFormat.zip, .sevenZip, .rar] {
            let options = PackOptions(format: format, password: secret)
            guard let built = try? PackEngine.command(for: options, archivePath: "/tmp/a.\(format.fileExtension)",
                                                      names: ["file.txt"]) else {
                continue    // the tool for this format is not installed here
            }
            XCTAssertFalse(built.args.contains { $0.contains(secret) },
                           "\(format.rawValue): the password is in the argument list: \(built.args)")
            XCTAssertEqual(built.stdin, secret, "\(format.rawValue): it has to reach the tool somehow")
        }
    }

    func test_noPasswordMeansNothingOnStandardInput() throws {
        guard let built = try? PackEngine.command(for: PackOptions(format: .zip),
                                                  archivePath: "/tmp/a.zip", names: ["file.txt"]) else {
            throw XCTSkip("7z is not installed here")
        }
        XCTAssertNil(built.stdin)
        XCTAssertFalse(built.args.contains("-p"), "an empty -p would make the packer wait for input")
    }

    func test_aNameBeginningWithADashIsPassedAfterASeparator() throws {
        // Without `--` the packer reads "-x.txt" as a switch; tar answered "Can't specify both -x and -c"
        // and packing that folder failed outright, in every format.
        for format in [PackFormat.tar, .tarGz, .zip, .sevenZip] {
            guard let built = try? PackEngine.command(for: PackOptions(format: format),
                                                      archivePath: "/tmp/a.\(format.fileExtension)",
                                                      names: ["-x.txt", "plain.txt"]) else { continue }
            let separator = try XCTUnwrap(built.args.firstIndex(of: "--"),
                                          "\(format.rawValue): no -- before the names: \(built.args)")
            let dash = try XCTUnwrap(built.args.firstIndex(of: "-x.txt"))
            XCTAssertLessThan(separator, dash, "\(format.rawValue): the separator must come first")
        }
    }
}
