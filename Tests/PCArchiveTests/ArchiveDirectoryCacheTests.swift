// SPDX-License-Identifier: Apache-2.0
// ArchiveDirectoryCacheTests.swift - Reusing an opened archive, and the cases where
// reusing one would be wrong (F-463).

import XCTest
import PCVFS
@testable import PCArchive

final class ArchiveDirectoryCacheTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: "/usr/bin/zip"), "zip missing")
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("ArchCache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { if let dir { try? FileManager.default.removeItem(at: dir) } }

    /// Builds `dir/<name>.zip` holding one file with `content`.
    @discardableResult
    private func makeZip(named name: String, content: String) throws -> URL {
        let payload = dir.appendingPathComponent("payload-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        try content.data(using: .utf8)!.write(to: payload.appendingPathComponent("a.txt"))
        let url = dir.appendingPathComponent(name)
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.arguments = ["-q", "-j", url.path, payload.appendingPathComponent("a.txt").path]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        try? FileManager.default.removeItem(at: payload)
        return url
    }

    private func open(_ url: URL) throws -> ArchiveFS {
        try XCTUnwrap(ArchiveFS(archiveFileURL: url, fsID: "zip:\(url.path)"))
    }

    func test_theSameFileComesBackAsTheSameOpenArchive() throws {
        let cache = ArchiveDirectoryCache()
        let url = try makeZip(named: "a.zip", content: "one")
        let first = try open(url)
        cache.store(first, for: url)

        XCTAssertTrue(cache.archive(for: url) === first,
                      "a second open of the same file must not parse it again")
    }

    /// mtime alone would miss this: rewriting an archive by writing a temporary file and
    /// renaming it over the old one carries the source's mtime across. Size and inode are
    /// why the stamp catches it.
    func test_aRewrittenArchiveIsNotServedFromTheCache() throws {
        let cache = ArchiveDirectoryCache()
        let url = try makeZip(named: "b.zip", content: "one")
        cache.store(try open(url), for: url)
        XCTAssertNotNil(cache.archive(for: url))

        try FileManager.default.removeItem(at: url)
        _ = try makeZip(named: "b.zip", content: "a different and longer payload entirely")

        XCTAssertNil(cache.archive(for: url), "the file changed; the parse of the old one is stale")
    }

    /// An extraction lives in the temp directory under a name used once, and is deleted
    /// as soon as the descent that made it is done. Remembering it is pure waste.
    func test_anExtractionInTheTempDirectoryIsNotRemembered() throws {
        let cache = ArchiveDirectoryCache()
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCArchive-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        let source = try makeZip(named: "c.zip", content: "one")
        let inTemp = staging.appendingPathComponent("c.zip")
        try FileManager.default.copyItem(at: source, to: inTemp)

        cache.store(try open(inTemp), for: inTemp)
        XCTAssertEqual(cache.count, 0)
    }

    /// The byte budget is what stops "32 archives" from meaning gigabytes: a mapped zip
    /// retains nothing, while a gzip-wrapped tar has to be inflated whole to be read.
    func test_aMappedZipRetainsNothingAndAnInflatedTarRetainsItsSize() throws {
        let zip = try makeZip(named: "d.zip", content: String(repeating: "x", count: 100_000))
        XCTAssertEqual(try open(zip).retainedBytes, 0, "a mapped zip must not count against the budget")

        let payload = dir.appendingPathComponent("tarpayload")
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        try String(repeating: "y", count: 100_000).data(using: .utf8)!
            .write(to: payload.appendingPathComponent("big.txt"))
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        p.arguments = ["-czf", dir.appendingPathComponent("d.tar.gz").path, "big.txt"]
        p.currentDirectoryURL = payload
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()

        let tar = try open(dir.appendingPathComponent("d.tar.gz"))
        XCTAssertGreaterThan(tar.retainedBytes, 100_000,
                             "an inflated tar is held in full and has to be budgeted for")
    }

    /// A password typed for one panel must not silently apply to a search, or to the
    /// other panel, just because the archive happened to still be open.
    func test_anEncryptedArchiveIsNotRemembered() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: "/usr/bin/zip"), "zip missing")
        let payload = dir.appendingPathComponent("secret")
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        try "classified\n".data(using: .utf8)!.write(to: payload.appendingPathComponent("s.txt"))
        let url = dir.appendingPathComponent("e.zip")
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.arguments = ["-q", "-j", "-P", "hunter2", url.path,
                       payload.appendingPathComponent("s.txt").path]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()

        let fs = try open(url)
        try XCTSkipUnless(fs.hasEncryptedEntries, "zip did not encrypt the fixture")
        let cache = ArchiveDirectoryCache()
        cache.store(fs, for: url)
        XCTAssertEqual(cache.count, 0)
    }

    func test_removeAllEmptiesTheCache() throws {
        let cache = ArchiveDirectoryCache()
        let url = try makeZip(named: "f.zip", content: "one")
        cache.store(try open(url), for: url)
        XCTAssertEqual(cache.count, 1)
        cache.removeAll()
        XCTAssertEqual(cache.count, 0)
    }
}
