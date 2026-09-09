// SPDX-License-Identifier: Apache-2.0
// SyncRunRecordTests.swift - The record's own shape.
//
// Two things are load-bearing and invisible: that a record written by an older version still reads
// (every field additive, every optional defaulted), and that the times survive with their fractional
// seconds — a guard that compares a destination's timestamp for equality would otherwise fail on
// every file it looked at, and the reason would be a date format three files away.

import XCTest
import PCFoundation

final class SyncRunRecordTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    /// A field this version has never heard of does not stop the line reading. Note what this does
    /// and does not prove: `JSONDecoder` ignores unmapped keys by itself, so this holds by the
    /// library's behaviour rather than by anything written here — it is here so that a future
    /// hand-rolled decoder cannot quietly take that away.
    func test_anUnknownFieldDoesNotStopALineReading() throws {
        let header = try decode(SyncRunHeader.self, """
            {"version":1,"runAt":100,"leftRoot":"/a","rightRoot":"/b","mode":"mirror",
             "somethingFromTheFuture":{"nested":true}}
            """)
        XCTAssertEqual(header.mode, "mirror")
        let item = try decode(SyncRunItem.self, """
            {"relativePath":"a.txt","action":"copyToRight","outcome":"copied","futureField":7}
            """)
        XCTAssertEqual(item.relativePath, "a.txt")
    }

    /// A missing field takes its default rather than throwing, which is the whole reason these
    /// decoders are written by hand: the synthesized one throws on an absent key even when the
    /// property has a default, and one unreadable header is the difference between a listed run and
    /// a file the app knows about and will not name.
    func test_missingFieldsTakeTheirDefaults() throws {
        let header = try decode(SyncRunHeader.self, #"{"version":1,"runAt":5}"#)
        XCTAssertEqual(header.leftRoot, "")
        XCTAssertEqual(header.planned, 0)
        XCTAssertTrue(header.withSubdirs, "a record from before this field was written is complete")
        // The one default that has to point this way: a file from a version without the field
        // described a *complete* run, and reading it as incomplete would withdraw an offer for no
        // reason.
        XCTAssertTrue(header.itemsListed)

        let item = try decode(SyncRunItem.self, #"{"relativePath":"a.txt"}"#)
        XCTAssertEqual(item.basis, "comparison")
        XCTAssertNil(item.created, "absent is not the same as false — the write could not answer")
        XCTAssertNil(item.trashedPath)
        XCTAssertNil(item.undoneAt)
    }

    /// `version: 0` is how "this did not read" is expressed, and a header that is missing the field
    /// entirely has to land there too — otherwise a truncated or foreign file would be treated as a
    /// version-1 record with every field defaulted, which is a record that says a run happened.
    func test_aHeaderWithoutAVersionIsNotReadableRatherThanEmpty() throws {
        let header = try decode(SyncRunHeader.self, #"{"runAt":5,"leftRoot":"/a"}"#)
        XCTAssertEqual(header.version, 0)
    }

    /// Fractional seconds survive. This is the assertion that documents why the times here are a
    /// `Double` and not a `Date` with `.iso8601`, which truncates to whole seconds — and a guard
    /// that compares a destination's timestamp for equality against a truncated one never matches.
    func test_timesKeepTheirFractionalSeconds() throws {
        let item = SyncRunItem(relativePath: "a.txt", action: "copyToRight", basis: "comparison",
                               outcome: SyncRunItem.Outcome.copied,
                               destinationModifiedUnix: 1_700_000_000.123456)
        let round = try JSONDecoder().decode(SyncRunItem.self,
                                             from: try JSONEncoder().encode(item))
        XCTAssertEqual(round.destinationModifiedUnix ?? 0, 1_700_000_000.123456, accuracy: 1e-6)
    }

    /// A deletion is never a "plain success", whatever its outcome — it is the row a person opens
    /// this record to find, and the only one that can be put back. That is what decides which rows
    /// survive above the item cap.
    func test_aDeletionIsNeverTreatedAsAPlainSuccess() {
        func row(_ outcome: String, trashed: String? = nil) -> SyncRunItem {
            SyncRunItem(relativePath: "x", action: "a", basis: "comparison", outcome: outcome,
                        trashedPath: trashed)
        }
        XCTAssertTrue(row(SyncRunItem.Outcome.copied).isPlainSuccess)
        XCTAssertTrue(row(SyncRunItem.Outcome.noOp).isPlainSuccess)
        XCTAssertFalse(row(SyncRunItem.Outcome.refused).isPlainSuccess)
        XCTAssertFalse(row(SyncRunItem.Outcome.failed).isPlainSuccess)
        XCTAssertFalse(row(SyncRunItem.Outcome.notAttempted).isPlainSuccess)
        XCTAssertFalse(row(SyncRunItem.Outcome.deleted).isPlainSuccess)
        XCTAssertFalse(row(SyncRunItem.Outcome.deleted, trashed: "/x/.Trash/x").isPlainSuccess)
    }

    // MARK: - The identifier

    private let when = Date(timeIntervalSince1970: 1_700_000_000)   // 2023-11-14T22:13:20Z

    /// Fixed-width UTC, so sorting the filenames sorts the runs. Everything in the store — the
    /// listing's order and which file the trim drops — rests on that and on nothing else.
    func test_theIdentifierSortsChronologicallyAsAString() {
        let ids = [when.addingTimeInterval(-90_000), when, when.addingTimeInterval(3661)]
            .map { SyncRunRecord.identifier(runAt: $0, leftRoot: "/a", rightRoot: "/b") }
        XCTAssertEqual(ids, ids.sorted(), "the identifiers do not sort in the order they happened")
        XCTAssertTrue(ids[1].hasPrefix("20231114T221320Z-"), ids[1])
        XCTAssertEqual(Set(ids.map(\.count)).count, 1, "the identifier is not fixed width")
    }

    /// The same pair either way round names the same run file half, because the pair digest is over
    /// the sorted pair — the rule `SyncState.key` holds, reused here rather than restated, so that
    /// pressing "Swap sides" does not start a second history.
    func test_swappingTheSidesNamesTheSamePair() {
        let a = SyncRunRecord.identifier(runAt: when, leftRoot: "/one", rightRoot: "/two")
        let b = SyncRunRecord.identifier(runAt: when, leftRoot: "/two", rightRoot: "/one")
        XCTAssertEqual(a, b)
    }

    /// And two different pairs in the same second do not collide into one name.
    func test_twoPairsInTheSameSecondGetDifferentNames() {
        let a = SyncRunRecord.identifier(runAt: when, leftRoot: "/one", rightRoot: "/two")
        let b = SyncRunRecord.identifier(runAt: when, leftRoot: "/one", rightRoot: "/three")
        XCTAssertNotEqual(a, b)
    }

    /// No path in the filename. The record's content names the folders; its name must not, because
    /// a filename is the one part of this that is visible without opening anything.
    func test_theIdentifierCarriesNoPath() {
        let id = SyncRunRecord.identifier(runAt: when, leftRoot: "/Users/someone/Secret Project",
                                          rightRoot: "/Volumes/Backup/Secret Project")
        XCTAssertFalse(id.contains("Secret"))
        XCTAssertFalse(id.contains("/"))
    }
}
