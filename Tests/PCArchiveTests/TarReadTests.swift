// TarReadTests.swift - Native tar / tar.gz browsing through ArchiveFS.

import XCTest
import PCVFS
@testable import PCArchive

final class TarReadTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: "/usr/bin/tar"), "tar missing")
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("TarRead-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { if let dir { try? FileManager.default.removeItem(at: dir) } }

    /// Build a payload tree and pack it with `tar` using `flags`, returning the archive URL.
    private func makeTar(named name: String, flags: [String]) throws -> URL {
        let payload = dir.appendingPathComponent("payload")
        let sub = payload.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try "hello from tar\n".data(using: .utf8)!.write(to: payload.appendingPathComponent("top.txt"))
        try "nested needle\n".data(using: .utf8)!.write(to: sub.appendingPathComponent("deep.txt"))
        let archive = dir.appendingPathComponent(name)
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        p.arguments = flags + [archive.path, "-C", payload.path, "."]
        p.environment = ["COPYFILE_DISABLE": "1"]   // no ._ AppleDouble members
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        try? FileManager.default.removeItem(at: payload)
        return archive
    }

    private func read(_ fs: ArchiveFS, _ path: String) async throws -> String {
        var data = Data()
        let stream = try await fs.openRead(fs.path(path))
        for try await chunk in stream { data.append(chunk as! Data) }
        try await stream.close()
        return String(decoding: data, as: UTF8.self)
    }

    private func listNames(_ fs: ArchiveFS, _ dir: String) async throws -> [String] {
        var names: [String] = []
        for try await batch in fs.list(fs.path(dir)) { names += batch.entries.map(\.name) }
        return names.sorted()
    }

    func test_plainTar_listsAndReads() async throws {
        let url = try makeTar(named: "a.tar", flags: ["-cf"])
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: url, fsID: "tar:a"))
        let root = try await listNames(fs, "/")
        XCTAssertTrue(root.contains("top.txt"), "root listing: \(root)")
        XCTAssertTrue(root.contains("sub"), "root listing: \(root)")
        let top = try await read(fs, "/top.txt")
        XCTAssertEqual(top, "hello from tar\n")
        let deep = try await read(fs, "/sub/deep.txt")
        XCTAssertEqual(deep, "nested needle\n")
    }

    func test_tarGz_listsAndReads() async throws {
        let url = try makeTar(named: "a.tar.gz", flags: ["-czf"])
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: url, fsID: "tar:agz"))
        let deep = try await read(fs, "/sub/deep.txt")
        XCTAssertEqual(deep, "nested needle\n", "tar.gz inner read")
        let sub = try await listNames(fs, "/sub")
        XCTAssertEqual(sub, ["deep.txt"])
    }

    func test_tgz_extension_alsoWorks() async throws {
        let url = try makeTar(named: "a.tgz", flags: ["-czf"])
        let fs = try XCTUnwrap(ArchiveFS(archiveFileURL: url, fsID: "tar:tgz"))
        let top = try await read(fs, "/top.txt")
        XCTAssertEqual(top, "hello from tar\n")
    }

    func test_notAnArchive_returnsNil() throws {
        let junk = dir.appendingPathComponent("junk.bin")
        try Data(repeating: 0x42, count: 2048).write(to: junk)
        XCTAssertNil(ArchiveFS(archiveFileURL: junk, fsID: "x"))
    }
}
