// SPDX-License-Identifier: Apache-2.0
// SamplePackerTests.swift - End-to-end round trip through the real SamplePacker
// C plugin (Plugins/SamplePacker/sample_packer.c) via the PCX adapter.

import XCTest
@testable import PCPluginHost

final class SamplePackerTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("samplepak-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func buildSamplePacker() throws -> PluginLibrary? {
        let clang = "/usr/bin/clang"
        guard FileManager.default.isExecutableFile(atPath: clang) else { return nil }
        let src = repoRoot.appendingPathComponent("Plugins/SamplePacker/sample_packer.c")
        let sdk = repoRoot.appendingPathComponent("Plugins/SDK")
        let out = dir.appendingPathComponent("libsample.dylib")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: clang)
        p.arguments = ["-dynamiclib", "-std=c11", "-I", sdk.path, "-o", out.path, src.path]
        let pipe = Pipe(); p.standardError = pipe
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let e = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTFail("clang failed: \(e)"); return nil
        }
        guard case .success(let lib) = PluginLibrary.open(
            path: out.path, required: PCXSymbols.required, optional: PCXSymbols.optional) else {
            XCTFail("open failed"); return nil
        }
        return lib
    }

    func testPackListExtractDeleteRoundTrip() throws {
        guard let lib = try buildSamplePacker() else { throw XCTSkip("clang unavailable") }
        let archive = PCXArchive(library: lib)
        XCTAssertTrue(archive.canPack)
        XCTAssertTrue(archive.canDelete)

        // Two source files.
        let srcDir = dir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try "alpha contents".write(to: srcDir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "beta!".write(to: srcDir.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)

        let pak = dir.appendingPathComponent("out.pak").path

        // Pack → creates the archive with two entries.
        try archive.pack(archivePath: pak, sourceDir: srcDir.path, files: ["a.txt", "b.txt"])
        var entries = try archive.list(archivePath: pak).sorted { $0.path < $1.path }
        XCTAssertEqual(entries.map(\.path), ["a.txt", "b.txt"])
        XCTAssertEqual(entries.first(where: { $0.path == "a.txt" })?.size, Int64("alpha contents".utf8.count))

        // Extract one and verify its bytes.
        let outFile = dir.appendingPathComponent("a-out.txt")
        try archive.extract(archivePath: pak, entryPath: "a.txt", to: outFile.path)
        XCTAssertEqual(try String(contentsOf: outFile, encoding: .utf8), "alpha contents")

        // Delete one → one entry remains.
        try archive.delete(archivePath: pak, entries: ["a.txt"])
        entries = try archive.list(archivePath: pak)
        XCTAssertEqual(entries.map(\.path), ["b.txt"])

        // Extract the survivor.
        let bOut = dir.appendingPathComponent("b-out.txt")
        try archive.extract(archivePath: pak, entryPath: "b.txt", to: bOut.path)
        XCTAssertEqual(try String(contentsOf: bOut, encoding: .utf8), "beta!")
    }

    func testPackWithSubPathPrefix() throws {
        guard let lib = try buildSamplePacker() else { throw XCTSkip("clang unavailable") }
        let archive = PCXArchive(library: lib)
        let srcDir = dir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try "x".write(to: srcDir.appendingPathComponent("f.txt"), atomically: true, encoding: .utf8)
        let pak = dir.appendingPathComponent("sub.pak").path
        try archive.pack(archivePath: pak, sourceDir: srcDir.path, files: ["f.txt"], subPath: "docs")
        let entries = try archive.list(archivePath: pak)
        XCTAssertEqual(entries.map(\.path), ["docs/f.txt"])
    }
}
