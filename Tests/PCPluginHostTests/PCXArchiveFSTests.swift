// PCXArchiveFSTests.swift - VFS battery over a plugin-backed archive (I14 T03/T04).

import XCTest
import PCVFS
@testable import PCPluginHost

final class PCXArchiveFSTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pcxfs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func buildLib() throws -> PluginLibrary? {
        let clang = "/usr/bin/clang"
        guard FileManager.default.isExecutableFile(atPath: clang) else { return nil }
        let out = dir.appendingPathComponent("libsample.dylib")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: clang)
        p.arguments = ["-dynamiclib", "-std=c11", "-I", repoRoot.appendingPathComponent("Plugins/SDK").path,
                       "-o", out.path, repoRoot.appendingPathComponent("Plugins/SamplePacker/sample_packer.c").path]
        let pipe = Pipe(); p.standardError = pipe
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            XCTFail("clang: \(String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")")
            return nil
        }
        guard case .success(let lib) = PluginLibrary.open(path: out.path, required: PCXSymbols.required,
                                                          optional: PCXSymbols.optional) else {
            XCTFail("open"); return nil
        }
        return lib
    }

    private func collect(_ fs: PCXArchiveFS, _ path: String) async throws -> [VFSEntry] {
        var out: [VFSEntry] = []
        for try await batch in fs.list(fs.path(path)) { out.append(contentsOf: batch.entries) }
        return out
    }

    func testTreeListingAndReads() async throws {
        guard let lib = try buildLib() else { throw XCTSkip("clang unavailable") }
        let archive = PCXArchive(library: lib)

        // Author an archive: two root files + one nested under "sub".
        let src = dir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try "AAA".write(to: src.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "BBBB".write(to: src.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        try "CC".write(to: src.appendingPathComponent("c.txt"), atomically: true, encoding: .utf8)
        let pak = dir.appendingPathComponent("t.pak").path
        try archive.pack(archivePath: pak, sourceDir: src.path, files: ["a.txt", "b.txt"])
        try archive.pack(archivePath: pak, sourceDir: src.path, files: ["c.txt"], subPath: "sub")

        guard let fs = PCXArchiveFS(archivePath: pak, library: lib, fsID: "pcx:test") else {
            return XCTFail("FS init failed")
        }

        // Root listing: a.txt, b.txt, and a synthesized "sub" directory.
        let root = try await collect(fs, "/")
        XCTAssertEqual(Set(root.map(\.name)), ["a.txt", "b.txt", "sub"])
        let subNode = root.first { $0.name == "sub" }
        XCTAssertEqual(subNode?.kind, .directory)
        XCTAssertEqual(root.first { $0.name == "b.txt" }?.size, 4)

        // Nested listing.
        let sub = try await collect(fs, "/sub")
        XCTAssertEqual(sub.map(\.name), ["c.txt"])

        // stat + read a nested file through the plugin.
        let stat = try await fs.stat(fs.path("/sub/c.txt"))
        XCTAssertEqual(stat.size, 2)
        let url = try await fs.localFileIfAvailable(fs.path("/sub/c.txt"))
        XCTAssertEqual(try url.map { try String(contentsOf: $0, encoding: .utf8) }, "CC")

        // openRead a root file.
        var bytes = Data()
        let stream = try await fs.openRead(fs.path("/a.txt"))
        for try await element in stream {
            if let chunk = element as? Data { bytes.append(contentsOf: chunk) }
        }
        XCTAssertEqual(String(data: bytes, encoding: .utf8), "AAA")
    }

    func testInitFailsOnNonArchive() throws {
        guard let lib = try buildLib() else { throw XCTSkip("clang unavailable") }
        let bogus = dir.appendingPathComponent("not.pak")
        try Data("garbage".utf8).write(to: bogus)
        XCTAssertNil(PCXArchiveFS(archivePath: bogus.path, library: lib, fsID: "x"))
    }
}
