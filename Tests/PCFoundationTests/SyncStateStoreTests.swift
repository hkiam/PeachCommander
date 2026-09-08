// SPDX-License-Identifier: Apache-2.0
// SyncStateStoreTests.swift - Reading and writing a pair's record.
//
// The whole reason this store is written by hand rather than as one `Codable` blob is what happens
// when it cannot be read, so most of these tests are about exactly that. Written with literal JSONL
// where the case needs it: a round trip through the encoder always writes every key and therefore
// cannot see an older or a broken file at all.

import XCTest
@testable import PCFoundation

final class SyncStateStoreTests: XCTestCase {
    private var dir: URL!
    private var store: SyncStateStore!
    private let left = "/tmp/pair-left"
    private let right = "/tmp/pair-right"
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-syncstate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        store = SyncStateStore(directory: dir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
        dir = nil; store = nil
    }

    private func header(l: String? = nil, r: String? = nil) -> SyncStateHeader {
        SyncStateHeader(leftRoot: l ?? left, rightRoot: r ?? right, runAt: t0,
                        options: SyncOptions(), fileMask: "*.*", withSubdirs: true,
                        ignoreHidden: false)
    }

    private func entry(_ path: String, leftSize: Int64? = 10, rightSize: Int64? = 10) -> SyncStateEntry {
        SyncStateEntry(relativePath: path,
                       left: leftSize.map { SyncStateSide(size: $0, modified: t0, isDirectory: false) },
                       right: rightSize.map { SyncStateSide(size: $0, modified: t0, isDirectory: false) })
    }

    private func fileURL(_ l: String? = nil, _ r: String? = nil) -> URL {
        dir.appendingPathComponent(SyncState.key(leftRoot: l ?? left, rightRoot: r ?? right) + ".jsonl")
    }

    // MARK: - The round trip

    func test_aRecordComesBackAsItWentIn() {
        let entries = [entry("a.txt"), entry("sub/b.txt", rightSize: nil)]
        XCTAssertEqual(store.save(header: header(), entries: entries),
                       .written(entries: 2))
        let loaded = store.load(leftRoot: left, rightRoot: right)
        XCTAssertTrue(loaded.isKnown)
        XCTAssertEqual(loaded.header?.entryCount, 2)
        XCTAssertEqual(Set(loaded.entries.keys), ["a.txt", "sub/b.txt"])
        XCTAssertEqual(loaded.entries["a.txt"], entries[0])
        XCTAssertNil(loaded.entries["sub/b.txt"]?.right, "a one-sided record lost its shape")
    }

    // MARK: - The distinction that matters most

    /// "No record" and "nothing was there" are opposite statements, and `[:]` cannot tell them
    /// apart. A deletion may follow from the second and never from the first.
    func test_noFileIsUnknownAndNotAnEmptyRecord() {
        let loaded = store.load(leftRoot: left, rightRoot: right)
        XCTAssertFalse(loaded.isKnown)
        guard case .unknown(let reason) = loaded else { return XCTFail("expected unknown") }
        XCTAssertTrue(reason.contains("no record"), reason)
        XCTAssertEqual(loaded.entries, [:], "and it still answers an empty map to a caller that asks")
    }

    /// A record whose header will not parse is unknown too — and, crucially, is **not** overwritten
    /// by the next save. `load` cannot tell "no record" from "could not read it", so writing over
    /// the second would throw away a history a later version might still have made sense of.
    func test_anUnreadableHeaderIsUnknownAndIsNotOverwritten() throws {
        try Data("{ this is not a header\n".utf8).write(to: fileURL())
        let before = try Data(contentsOf: fileURL())

        guard case .unknown(let reason) = store.load(leftRoot: left, rightRoot: right) else {
            return XCTFail("a broken header was read as a record")
        }
        XCTAssertTrue(reason.contains("could not be read"), reason)

        let outcome = store.save(header: header(), entries: [entry("a.txt")])
        guard case .refused(let why) = outcome else {
            return XCTFail("an unreadable record was overwritten: \(outcome)")
        }
        XCTAssertTrue(why.contains("left alone"), why)
        XCTAssertEqual(try Data(contentsOf: fileURL()), before)
    }

    /// One bad line costs one path. That is the whole reason for JSONL over a single object: a
    /// path with no record cannot be deleted, so the failure direction is right by construction.
    func test_oneCorruptLineCostsOnlyItsOwnPath() throws {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        var out = try encoder.encode(header())
        out.append(UInt8(ascii: "\n"))
        out.append(try encoder.encode(entry("good-one.txt")))
        out.append(UInt8(ascii: "\n"))
        out.append(contentsOf: Array("{ not an entry at all\n".utf8))
        out.append(try encoder.encode(entry("good-two.txt")))
        out.append(UInt8(ascii: "\n"))
        try out.write(to: fileURL())

        let loaded = store.load(leftRoot: left, rightRoot: right)
        XCTAssertTrue(loaded.isKnown, "one bad line cost the whole record")
        XCTAssertEqual(Set(loaded.entries.keys), ["good-one.txt", "good-two.txt"])
    }

    /// A record from a *newer* version is refused rather than misread. This is the one thing a
    /// tolerant decoder cannot do for itself: it would read a field whose meaning had changed as
    /// though nothing had.
    func test_aNewerFormatVersionIsRefusedRatherThanRead() throws {
        var future = header()
        future.version = SyncStateHeader.currentVersion + 1
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        var out = try encoder.encode(future)
        out.append(UInt8(ascii: "\n"))
        try out.write(to: fileURL())

        guard case .unknown(let reason) = store.load(leftRoot: left, rightRoot: right) else {
            return XCTFail("a newer record was read as though it were this version's")
        }
        XCTAssertTrue(reason.contains("newer version"), reason)
    }

    /// The roots are in the header as a collision check — a digest is short, and a file copied by
    /// hand into the directory would otherwise attach one pair's history to another.
    func test_aRecordNamingDifferentFoldersIsNotUsed() throws {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        var out = try encoder.encode(header(l: "/tmp/somewhere", r: "/tmp/else"))
        out.append(UInt8(ascii: "\n"))
        // Written under *this* pair's filename, with someone else's roots inside.
        try out.write(to: fileURL())
        guard case .unknown(let reason) = store.load(leftRoot: left, rightRoot: right) else {
            return XCTFail("a record for another pair was accepted")
        }
        XCTAssertTrue(reason.contains("different ones"), reason)
    }

    // MARK: - Swapping the sides

    /// The window has a "Swap sides" button. The key is over the sorted pair so the record is still
    /// found — and every entry has to come back the other way round, or the next run reads every
    /// left as a right and proposes the exact opposite of the truth.
    func test_aRecordFoundWithTheSidesSwappedComesBackExchanged() {
        store.save(header: header(), entries: [entry("a.txt", leftSize: 111, rightSize: 222)])

        let sameWay = store.load(leftRoot: left, rightRoot: right)
        XCTAssertEqual(sameWay.entries["a.txt"]?.left?.size, 111)

        let swapped = store.load(leftRoot: right, rightRoot: left)
        XCTAssertTrue(swapped.isKnown, "swapping the sides lost the record")
        XCTAssertEqual(swapped.entries["a.txt"]?.left?.size, 222,
                       "the sides were not exchanged on the way in")
        XCTAssertEqual(swapped.entries["a.txt"]?.right?.size, 111)
        XCTAssertEqual(swapped.header?.leftRoot, right, "the header still named the old orientation")
    }

    // MARK: - The cap

    /// A stated refusal rather than a silent slowdown — and above all rather than a *truncated*
    /// record, whose missing paths would read as deletions on the next run.
    func test_aPairAboveTheCapWritesNoRecordAndSaysWhy() {
        let many = (0..<(SyncStateStore.maximumEntries + 1)).map { entry("f\($0).txt") }
        guard case .refused(let reason) = store.save(header: header(), entries: many) else {
            return XCTFail("a record beyond the cap was written")
        }
        XCTAssertTrue(reason.contains("deletions will not be propagated"), reason)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL().path),
                       "a refused save left a file behind")
    }

    // MARK: - Forgetting

    /// The file goes, rather than an empty one being left: "no record" stays one state instead of
    /// two — the rule `RecentLines.clear` and `CommentStore` already follow.
    func test_forgettingRemovesTheFileRatherThanEmptyingIt() {
        store.save(header: header(), entries: [entry("a.txt")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL().path))
        XCTAssertTrue(store.forget(leftRoot: left, rightRoot: right))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL().path))
        XCTAssertFalse(store.load(leftRoot: left, rightRoot: right).isKnown)
    }

    /// The directory is created on write, the way `MacroStore` and `SessionStore` do — `ConfigPaths`
    /// creates only the root.
    func test_theDirectoryIsCreatedOnWrite() throws {
        let fresh = dir.appendingPathComponent("not-there-yet", isDirectory: true)
        let other = SyncStateStore(directory: fresh)
        XCTAssertEqual(other.save(header: header(), entries: [entry("a.txt")]),
                       .written(entries: 1))
        XCTAssertTrue(other.load(leftRoot: left, rightRoot: right).isKnown)
    }
}
