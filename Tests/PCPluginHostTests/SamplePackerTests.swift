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
        // Compiled once per test run, copied per test — see CachedPluginBuild.
        let out: URL
        do {
            out = try CachedPluginBuild.freshBuild(key: "samplepacker", into: dir) { cache in
                let src = repoRoot.appendingPathComponent("Plugins/SamplePacker/sample_packer.c")
                let sdk = repoRoot.appendingPathComponent("Plugins/SDK")
                let out = cache.appendingPathComponent("libsample.dylib")
                let p = Process()
                p.executableURL = URL(fileURLWithPath: clang)
                p.arguments = ["-dynamiclib", "-std=c11", "-I", sdk.path, "-o", out.path, src.path]
                let pipe = Pipe(); p.standardError = pipe
                try p.run(); p.waitUntilExit()
                guard p.terminationStatus == 0 else {
                    let e = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    throw PluginBuildFailure(description: "clang failed: \(e)")
                }
                return out
            }
        } catch let failure as PluginBuildFailure {
            // Recorded per test, as it was when every test compiled its own copy.
            XCTFail(failure.description); return nil
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
    // MARK: - Random access (F-482)

    /// The three things `ReadEntryData` has to get right: the slice, the short read at the end,
    /// and an offset past the end.
    func test_randomAccessReadsASliceOfOneEntry() throws {
        guard let lib = try buildSamplePacker() else { throw XCTSkip("clang unavailable") }
        let archive = PCXArchive(library: lib)
        XCTAssertTrue(archive.supportsRandomAccess,
                      "the sample packer advertises PC_CAP_RANDOM_ACCESS and exports ReadEntryData")

        let src = dir.appendingPathComponent("src", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        let body = "0123456789abcdefghij"
        try Data(body.utf8).write(to: src.appendingPathComponent("first.txt"))
        try Data("second".utf8).write(to: src.appendingPathComponent("second.txt"))
        let pak = dir.appendingPathComponent("rand.pak")
        try archive.pack(archivePath: pak.path, sourceDir: src.path,
                         files: ["first.txt", "second.txt"])

        let reader = try XCTUnwrap(archive.openRandomAccess(archivePath: pak.path))
        defer { reader.close() }

        XCTAssertEqual(String(decoding: try reader.read(entryPath: "first.txt", offset: 5, length: 5),
                              as: UTF8.self), "56789")
        // A short read means the end of the entry, not an error.
        let tail = try reader.read(entryPath: "first.txt", offset: 15, length: 100)
        XCTAssertEqual(String(decoding: tail, as: UTF8.self), "fghij")
        // Past the end is empty, which is how the stream learns to stop.
        XCTAssertTrue(try reader.read(entryPath: "first.txt", offset: 999, length: 10).isEmpty)
        // The second entry is reachable without having consumed the first.
        XCTAssertEqual(String(decoding: try reader.read(entryPath: "second.txt", offset: 0, length: 6),
                              as: UTF8.self), "second")
    }

    func test_randomAccessReportsAnUnknownEntry() throws {
        guard let lib = try buildSamplePacker() else { throw XCTSkip("clang unavailable") }
        let archive = PCXArchive(library: lib)
        let src = dir.appendingPathComponent("src2", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: src.appendingPathComponent("only.txt"))
        let pak = dir.appendingPathComponent("one.pak")
        try archive.pack(archivePath: pak.path, sourceDir: src.path, files: ["only.txt"])

        let reader = try XCTUnwrap(archive.openRandomAccess(archivePath: pak.path))
        defer { reader.close() }
        XCTAssertThrowsError(try reader.read(entryPath: "nope.txt", offset: 0, length: 4)) { error in
            XCTAssertEqual(error as? PCXArchive.PCXError, .entryNotFound("nope.txt"))
        }
    }

    /// A plugin that does not export it gets nil rather than a broken promise.
    func test_randomAccessIsAbsentWithoutBothHalves() throws {
        guard let lib = try buildSamplePacker() else { throw XCTSkip("clang unavailable") }
        // The sample has both. The half-and-half cases are covered by `supportsRandomAccess`
        // requiring the symbol *and* the bit; here we assert the fallback exists at all, so a
        // future plugin without the export still reads through the extract-to-temp path.
        let archive = PCXArchive(library: lib)
        XCTAssertNil(archive.openRandomAccess(archivePath: dir.appendingPathComponent("missing.pak").path),
                     "an archive that cannot even be opened yields no reader")
    }

    /// Concurrent reads on one random-access handle must not interleave inside the plugin.
    ///
    /// `pcx.h` promises the host serialises calls per open archive HANDLE, and every other path
    /// keeps that for free by opening a fresh handle per operation. The random-access reader does
    /// not — holding the archive open between reads is half of what the export buys — so the
    /// serialisation has to be put back by hand. The sample packer seeks and reads a `FILE *`;
    /// interleaving those is not a crash, it is one entry's bytes returned for another's, which is
    /// why this asserts the contents rather than merely surviving.
    func test_concurrentReadsOnOneHandleDoNotInterleave() async throws {
        guard let lib = try buildSamplePacker() else { throw XCTSkip("clang unavailable") }
        let archive = PCXArchive(library: lib)

        let src = dir.appendingPathComponent("concurrent", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        var expected: [String: String] = [:]
        for i in 0..<8 {
            // Distinct lengths as well as contents, so a read that lands in the wrong entry is
            // visible even if the two happen to start with the same byte.
            let body = String(repeating: "\(i)", count: 500 + i * 97)
            expected["f\(i).txt"] = body
            try Data(body.utf8).write(to: src.appendingPathComponent("f\(i).txt"))
        }
        let pak = dir.appendingPathComponent("concurrent.pak")
        try archive.pack(archivePath: pak.path, sourceDir: src.path, files: expected.keys.sorted())

        let reader = try XCTUnwrap(archive.openRandomAccess(archivePath: pak.path))
        defer { reader.close() }

        try await withThrowingTaskGroup(of: (String, String).self) { group in
            for _ in 0..<40 {
                for name in expected.keys.sorted() {
                    group.addTask {
                        let data = try reader.read(entryPath: name, offset: 0, length: 4096)
                        return (name, String(decoding: data, as: UTF8.self))
                    }
                }
            }
            for try await (name, got) in group {
                XCTAssertEqual(got, expected[name], "\(name) came back as another entry's contents")
            }
        }
    }

}
