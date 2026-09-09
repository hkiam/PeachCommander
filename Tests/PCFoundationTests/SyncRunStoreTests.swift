// SPDX-License-Identifier: Apache-2.0
// SyncRunStoreTests.swift - What is kept, what goes first, and what a record says when it is short.
//
// The claims worth pinning here are the ones a reader of the code would take on trust: that listing
// runs does not read their rows, that going over the item cap keeps the deletions and drops the
// plain copies rather than the other way round, that the trim takes the oldest, and that marking a
// row acted-on leaves the record of what happened intact.

import XCTest
import PCFoundation

final class SyncRunStoreTests: XCTestCase {
    private var dir: URL!
    private var store: SyncRunStore!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-runs-\(UUID().uuidString)")
        store = SyncRunStore(directory: dir)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func header(_ secondsAgo: Double = 0, mode: String = "mirror",
                        left: String = "/left", right: String = "/right") -> SyncRunHeader {
        SyncRunHeader(runAt: 1_700_000_000 - secondsAgo, leftRoot: left, rightRoot: right,
                      mode: mode)
    }

    private func copyRow(_ path: String) -> SyncRunItem {
        SyncRunItem(relativePath: path, action: "copyToRight", basis: "comparison",
                    outcome: SyncRunItem.Outcome.copied, destinationPath: "/right/" + path,
                    destinationSide: "localDir", created: true, destinationSize: 3,
                    destinationModifiedUnix: 1_700_000_000)
    }

    private func deleteRow(_ path: String) -> SyncRunItem {
        SyncRunItem(relativePath: path, action: "deleteRight", basis: "comparison",
                    outcome: SyncRunItem.Outcome.deleted, destinationPath: "/right/" + path,
                    destinationSide: "localDir", toTrash: true,
                    trashedPath: "/Users/x/.Trash/" + path)
    }

    // MARK: - Writing and reading back

    func test_aRunComesBackAsItWentIn() throws {
        let outcome = store.write(header: header(planned: 2), items: [copyRow("a.txt"),
                                                                      deleteRow("b.txt")])
        guard case .written(let id, let count) = outcome else {
            return XCTFail("nothing was written: \(outcome)")
        }
        XCTAssertEqual(count, 2)

        let runs = store.runs()
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs[0].id, id)
        XCTAssertTrue(runs[0].isReadable)
        XCTAssertEqual(runs[0].header.mode, "mirror")
        XCTAssertTrue(runs[0].header.itemsListed)
        XCTAssertGreaterThan(runs[0].byteSize, 0)

        let items = store.items(id: id)
        XCTAssertEqual(items.map(\.relativePath), ["a.txt", "b.txt"])
        XCTAssertEqual(items[1].trashedPath, "/Users/x/.Trash/b.txt")
        XCTAssertEqual(items[0].created, true)
    }

    /// Listing reads only the header line.
    ///
    /// Proved the way it can be: the rows of this file are not JSON at all, and the run still lists
    /// with its counts intact. A listing that decoded rows would have to either fail or skip them,
    /// and both are visible here. What this does *not* prove is that the bytes were never read —
    /// that claim belongs to `FileHeadLineTests`, which pins the cap that makes the read bounded.
    func test_listingDoesNotDependOnTheRowsBeingReadable() throws {
        guard case .written(let id, _) = store.write(header: header(planned: 1),
                                                     items: [copyRow("a.txt")]) else {
            return XCTFail("nothing was written")
        }
        let url = dir.appendingPathComponent(id + ".jsonl")
        var bytes = FileHeadLine.read(at: url)!
        bytes.append(UInt8(ascii: "\n"))
        bytes.append(Data("{ not json at all\nnor this one\n".utf8))
        try bytes.write(to: url)

        let runs = store.runs()
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs[0].header.planned, 1)
        XCTAssertTrue(runs[0].isReadable)
        // …and the rows themselves are individually tolerated: two bad lines cost two rows.
        XCTAssertTrue(store.items(id: id).isEmpty)
    }

    /// One bad row costs one row, which is the whole reason for JSONL over a single object.
    func test_oneCorruptRowCostsOnlyItself() throws {
        guard case .written(let id, _) = store.write(header: header(planned: 3),
                                                     items: [copyRow("one.txt"),
                                                             copyRow("two.txt")]) else {
            return XCTFail("nothing was written")
        }
        let url = dir.appendingPathComponent(id + ".jsonl")
        var bytes = try Data(contentsOf: url)
        bytes.append(Data("{ broken\n".utf8))
        bytes.append(try JSONEncoder().encode(copyRow("three.txt")))
        bytes.append(UInt8(ascii: "\n"))
        try bytes.write(to: url)

        XCTAssertEqual(store.items(id: id).map(\.relativePath),
                       ["one.txt", "two.txt", "three.txt"])
    }

    /// A header that will not parse is *listed* with `version: 0` rather than hidden — the rule
    /// `SyncStateStore.records()` follows, and for its reason: a record the app knows about and will
    /// not name is worse than an ugly row, because the only thing to do with it is forget it.
    func test_anUnreadableRunIsStillListedAndCanBeForgotten() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{ this is not a header\n".utf8)
            .write(to: dir.appendingPathComponent("20231114T221320Z-abcdef12.jsonl"))

        let runs = store.runs()
        XCTAssertEqual(runs.count, 1)
        XCTAssertFalse(runs[0].isReadable)
        XCTAssertEqual(runs[0].header.version, 0)
        XCTAssertTrue(store.items(id: runs[0].id).isEmpty, "rows were read under a broken header")
        XCTAssertTrue(store.forget(id: runs[0].id))
        XCTAssertTrue(store.runs().isEmpty)
    }

    /// A record from a newer version is refused rather than misread — the one thing a tolerant
    /// decoder cannot do for itself, since it would happily take every field it recognises.
    func test_aNewerVersionIsRefusedRatherThanRead() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var bytes = Data(#"{"version":99,"runAt":1700000000,"leftRoot":"/l","rightRoot":"/r","mode":"mirror"}"#.utf8)
        bytes.append(UInt8(ascii: "\n"))
        bytes.append(try JSONEncoder().encode(copyRow("a.txt")))
        bytes.append(UInt8(ascii: "\n"))
        try bytes.write(to: dir.appendingPathComponent("20231114T221320Z-abcdef12.jsonl"))

        XCTAssertTrue(store.items(id: "20231114T221320Z-abcdef12").isEmpty,
                      "rows from a newer format were read anyway")
        // Still listed, so it can be seen and forgotten.
        XCTAssertEqual(store.runs().count, 1)
    }

    /// Two runs in the same second are two records, not one overwriting the other. Two windows on
    /// one pair is the case; it is not worth a lock, but it is worth not losing one of them.
    func test_twoRunsInTheSameSecondBothSurvive() throws {
        guard case .written(let first, _) = store.write(header: header(), items: [copyRow("a.txt")]),
              case .written(let second, _) = store.write(header: header(), items: [copyRow("b.txt")])
        else { return XCTFail("nothing was written") }
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(store.runs().count, 2)
        XCTAssertEqual(store.items(id: first).map(\.relativePath), ["a.txt"])
        XCTAssertEqual(store.items(id: second).map(\.relativePath), ["b.txt"])
    }

    /// Newest first, and an unreadable record is not buried: it is sorted by its id, which is its
    /// timestamp, rather than by a `runAt` it does not have.
    func test_runsAreListedNewestFirst() throws {
        for ago in [0.0, 86_400, 3600] {
            _ = store.write(header: header(ago, left: "/l\(ago)"), items: [copyRow("a.txt")])
        }
        let ids = store.runs().map(\.id)
        XCTAssertEqual(ids, ids.sorted(by: >))
    }

    // MARK: - The item cap

    /// Above the cap the deletions and the problems stay and the plain copies go, and the header
    /// says so out loud. The other way round would drop exactly the rows somebody opens this record
    /// to find.
    func test_aRunOverTheItemCapKeepsTheDeletionsAndSaysTheCopiesAreMissing() throws {
        var items = (0..<(SyncRunStore.maximumItems + 5)).map { copyRow("bulk/\($0).txt") }
        items.append(deleteRow("gone.txt"))
        items.append(SyncRunItem(relativePath: "kept.txt", action: "deleteRight",
                                 basis: "comparison", outcome: SyncRunItem.Outcome.refused,
                                 reason: "kept: it holds something this comparison did not include"))

        guard case .written(let id, let written) = store.write(header: header(planned: items.count),
                                                              items: items) else {
            return XCTFail("nothing was written")
        }
        XCTAssertEqual(written, 2, "the plain copies were not the rows that were dropped")

        let run = store.runs()[0]
        XCTAssertFalse(run.header.itemsListed)
        XCTAssertEqual(run.header.planned, items.count, "the header lost the real count")
        let why = run.header.undoUnavailable ?? ""
        XCTAssertTrue(why.contains("\(items.count)") && why.contains("\(SyncRunStore.maximumItems)"),
                      why)

        let rows = store.items(id: id).map(\.relativePath)
        XCTAssertEqual(Set(rows), ["gone.txt", "kept.txt"])
    }

    /// Exactly at the cap everything is written — the boundary, so the rule is "more than", not
    /// "as many as".
    func test_aRunExactlyAtTheCapIsWrittenWhole() throws {
        let items = (0..<SyncRunStore.maximumItems).map { copyRow("bulk/\($0).txt") }
        guard case .written(_, let written) = store.write(header: header(planned: items.count),
                                                          items: items) else {
            return XCTFail("nothing was written")
        }
        XCTAssertEqual(written, SyncRunStore.maximumItems)
        XCTAssertTrue(store.runs()[0].header.itemsListed)
    }

    // MARK: - Trimming

    /// The oldest go. Unlike the state records, which are never reaped: losing a state record
    /// changes what the next run *does*, while losing a run's record takes away only the offer to
    /// put something back.
    func test_theOldestRunsAreDroppedFirst() throws {
        // One more than the cap, oldest written first so the trim has something to choose.
        for index in 0...SyncRunStore.maximumRuns {
            let secondsAgo = Double(SyncRunStore.maximumRuns - index) * 60
            _ = store.write(header: header(secondsAgo), items: [copyRow("a.txt")])
        }
        let runs = store.runs()
        XCTAssertEqual(runs.count, SyncRunStore.maximumRuns)
        // The newest survived and the oldest did not.
        let newest = SyncRunRecord.identifier(runAt: Date(timeIntervalSince1970: 1_700_000_000),
                                              leftRoot: "/left", rightRoot: "/right")
        let oldest = SyncRunRecord.identifier(
            runAt: Date(timeIntervalSince1970: 1_700_000_000 - Double(SyncRunStore.maximumRuns) * 60),
            leftRoot: "/left", rightRoot: "/right")
        XCTAssertTrue(runs.contains { $0.id == newest }, "the newest run was trimmed")
        XCTAssertFalse(runs.contains { $0.id == oldest }, "the oldest run survived the trim")
    }

    // MARK: - Marking a row acted on

    /// The row stays and loses its offer — `AuditLog.markUndone`'s semantics. A record that deleted
    /// its rows as they were acted on would have nothing left to refuse a second attempt with, and
    /// would also stop being a record of what the run did.
    func test_markingARowLeavesItInPlaceAndTakesAwayItsOffer() throws {
        guard case .written(let id, _) = store.write(header: header(planned: 2),
                                                     items: [deleteRow("a.txt"),
                                                             deleteRow("b.txt")]) else {
            return XCTFail("nothing was written")
        }
        let marked = store.markUndone(id: id, paths: ["a.txt"],
                                      at: Date(timeIntervalSince1970: 1_700_000_500),
                                      reason: "already put back")
        XCTAssertEqual(marked, 1)

        let rows = store.items(id: id)
        XCTAssertEqual(rows.map(\.relativePath), ["a.txt", "b.txt"], "a row disappeared")
        XCTAssertEqual(rows[0].undoneAt ?? 0, 1_700_000_500, accuracy: 0.001)
        XCTAssertEqual(rows[0].undoUnavailable, "already put back")
        XCTAssertEqual(rows[0].trashedPath, "/Users/x/.Trash/a.txt",
                       "the row forgot what it had done")
        XCTAssertNil(rows[1].undoneAt)
        XCTAssertTrue(store.runs()[0].isReadable, "the header did not survive the rewrite")

        // A second pass changes nothing, which is what stops a double undo.
        XCTAssertEqual(store.markUndone(id: id, paths: ["a.txt"], reason: "again"), 0)
        XCTAssertEqual(store.items(id: id)[0].undoUnavailable, "already put back")
    }

    // MARK: - Forgetting

    func test_forgettingEverythingLeavesNothing() throws {
        _ = store.write(header: header(0), items: [copyRow("a.txt")])
        _ = store.write(header: header(60), items: [copyRow("b.txt")])
        XCTAssertEqual(store.forgetAll(), 2)
        XCTAssertTrue(store.runs().isEmpty)
    }

    func test_forgettingSomethingThatIsNotThereSaysSo() {
        XCTAssertFalse(store.forget(id: "20231114T221320Z-nothere1"))
    }

    func test_anEmptyOrMissingDirectoryListsNothing() {
        XCTAssertTrue(store.runs().isEmpty)
        XCTAssertTrue(store.items(id: "whatever").isEmpty)
        XCTAssertNil(store.header(id: "whatever"))
    }
}

private extension SyncRunStoreTests {
    func header(planned: Int) -> SyncRunHeader {
        var h = header()
        h.planned = planned
        return h
    }
}
