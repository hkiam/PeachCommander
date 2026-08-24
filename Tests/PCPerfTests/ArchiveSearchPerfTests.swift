// SPDX-License-Identifier: Apache-2.0
// ArchiveSearchPerfTests.swift - What opening an archive during a search is allowed to cost (F-463).
//
// Widening the search from the zip family to tar, tar.gz and everything a plugin adds made
// the readers' cost reachable from a walk. Guards went in with it — the tar is mapped
// rather than read, a gzip payload declaring more than the ceiling is refused before
// anything is allocated, and a walk prefers a backend that can seek. None of that is
// visible in a correctness test: every one of those failures still returns the right
// answer, just after reading a great deal more than it had to.
//
// performance.md budgets the whole app at "< 300 MB RAM after a browsing spree", which is
// the number the ceilings here are derived from.
//
// Fixtures are built in setUp rather than taken from PC_FIXTURES_DIR: they are repeated
// text, so a gigabyte of them is a couple of megabytes on disk and a second to make, and a
// test that builds what it measures cannot fail because /tmp was reaped between runs.

import XCTest
import PCVFS
import PCArchive

final class ArchiveSearchPerfTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: "/usr/bin/tar"), "tar missing")
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArchPerf-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let dir { try? FileManager.default.removeItem(at: dir) }
    }

    // MARK: - Measuring

    /// Resident growth across `body`, in bytes.
    ///
    /// `phys_footprint` is what Activity Monitor calls Memory, and it is the number
    /// performance.md's budget is written against. Sampled either side rather than
    /// continuously: what these tests catch is a reader that materialises an archive, and
    /// that shows up as a residue long after the call returns.
    private func footprintDelta(_ body: () -> Void) -> Int64 {
        let before = Self.footprint()
        body()
        return Int64(Self.footprint()) - Int64(before)
    }

    private static func footprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }

    /// A tar of repeated text: `megabytes` uncompressed, a rounding error on disk.
    @discardableResult
    private func makeTar(named name: String, megabytes: Int, compressed: Bool) throws -> URL {
        let payload = dir.appendingPathComponent("stage-\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        let line = "the quick brown fox jumps over the lazy dog\n"                    // 44 bytes
        let chunk = String(repeating: line, count: 24_000)                            // ~1 MB
        var body = ""
        body.reserveCapacity(chunk.utf8.count * megabytes)
        for _ in 0..<megabytes { body += chunk }
        try Data(body.utf8).write(to: payload.appendingPathComponent("big.txt"))

        let url = dir.appendingPathComponent(name)
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        p.arguments = [compressed ? "-czf" : "-cf", url.path, "big.txt"]
        p.currentDirectoryURL = payload
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        try? FileManager.default.removeItem(at: payload)
        return url
    }

    /// A tar with many members and almost no bytes — the header walk, not the payload.
    private func makeManyMemberTar(named name: String, members: Int) throws -> URL {
        let payload = dir.appendingPathComponent("stage-\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        for i in 0..<members {
            try Data("hay\n".utf8).write(to: payload.appendingPathComponent("f\(i).txt"))
        }
        let url = dir.appendingPathComponent(name)
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        p.arguments = ["-cf", url.path, "."]
        p.currentDirectoryURL = payload
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        try? FileManager.default.removeItem(at: payload)
        return url
    }

    // MARK: - Budgets

    /// A plain tar is mapped, and `parse` only touches header blocks — so opening one is
    /// O(members), not O(bytes). Before the mapping went in, this read 200 MB into memory
    /// to build a tree over data it never looked at.
    func testPlainTarIsMappedNotRead() throws {
        let url = try makeTar(named: "plain.tar", megabytes: 200, compressed: false)

        var reader: TarReader?
        let delta = footprintDelta { reader = TarReader(fileURL: url) }
        XCTAssertNotNil(reader)
        XCTAssertLessThan(delta, 32 * 1024 * 1024,
                          "opening a 200 MB tar cost \(delta / 1_048_576) MB of footprint")
    }

    /// The worst case the widening created, and the one a size ceiling alone does not
    /// catch: a gzip stream that is not a tar. It used to be inflated in full — a
    /// `dump.sql.gz` decompressed cover to cover — and only then rejected.
    func testNonTarGzipIsRejectedWithoutInflatingIt() throws {
        let big = String(repeating: "INSERT INTO t VALUES (1);\n", count: 4_000_000)   // ~104 MB
        let raw = dir.appendingPathComponent("dump.sql")
        try Data(big.utf8).write(to: raw)
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
        p.arguments = ["-q", raw.path]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()

        let url = dir.appendingPathComponent("dump.sql.gz")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "gzip missing")

        var reader: TarReader?
        let started = Date()
        let delta = footprintDelta {
            reader = TarReader(fileURL: url, limits: .init(maxExpandedBytes: 8 * 1024 * 1024))
        }
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertNil(reader, "it is not a tar and must be refused")
        XCTAssertLessThan(delta, 32 * 1024 * 1024,
                          "refusing it cost \(delta / 1_048_576) MB of footprint")
        XCTAssertLessThan(elapsed, 1.0, "refusing it took \(elapsed)s")
    }

    /// The ceiling is read off the gzip trailer, so an over-size payload costs nothing at
    /// all — the difference between declining to open an archive and allocating a
    /// gigabyte to discover we should have declined.
    func testOverSizedTarGzIsRefusedBeforeAllocating() throws {
        let url = try makeTar(named: "big.tar.gz", megabytes: 300, compressed: true)

        var reader: TarReader?
        let delta = footprintDelta {
            reader = TarReader(fileURL: url, limits: .init(maxExpandedBytes: 8 * 1024 * 1024))
        }
        XCTAssertNil(reader)
        XCTAssertLessThan(delta, 16 * 1024 * 1024,
                          "refusing it cost \(delta / 1_048_576) MB of footprint")
        // And without the ceiling it opens, so the refusal is the ceiling's doing and not
        // the archive being unreadable.
        XCTAssertNotNil(TarReader(fileURL: url), "control: it is a readable tar.gz")
    }

    /// A walk meets archives with many members; building the tree over them is the part
    /// that scales with the count. The budget is generous — this is a floor against an
    /// accidental O(n²), not a tuning target.
    func testManyMemberTarOpensQuickly() throws {
        let url = try makeManyMemberTar(named: "many.tar", members: 20_000)

        let started = Date()
        let fs = ArchiveFS(archiveFileURL: url, fsID: "zip:\(url.path)")
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertNotNil(fs)
        XCTAssertLessThan(elapsed, 3.0, "opening a 20,000-member tar took \(elapsed)s")
    }

    /// A search over a folder of archives must not accumulate them. Each is opened,
    /// walked and released; what stays behind should be the results, not the archives.
    func testSearchingAFolderOfArchivesDoesNotAccumulateThem() async throws {
        for i in 0..<8 {
            try makeTar(named: "a\(i).tar.gz", megabytes: 12, compressed: true)
        }
        let registry = ArchiveRegistry(backends: [NativeArchiveBackend()])
        await registry.refresh()

        let before = Self.footprint()
        var hits = 0
        for await _ in await FileSearchEngine().search(
            SearchQuery(nameMask: "*.*", startDirectory: dir.path,
                        contentText: "quick brown fox", searchArchives: true),
            fs: LocalFS(), archiveOpener: registry) { hits += 1 }
        let delta = Int64(Self.footprint()) - Int64(before)

        XCTAssertEqual(hits, 8, "every archive should have matched once")
        XCTAssertLessThan(delta, 150 * 1024 * 1024,
                          "eight 12 MB archives left \(delta / 1_048_576) MB behind")
    }
}
