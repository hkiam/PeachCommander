// SPDX-License-Identifier: Apache-2.0
// SyncStateTests.swift - The record of what the two sides looked like when they last agreed.
//
// Each of these is a case where getting it wrong loses data silently rather than loudly: a record
// read as "nothing was there" instead of "nothing is known", a folder that reads as changed on every
// run, an edit inside the last hour swallowed by a widened tolerance, a swapped pair that reads every
// left as a right.

import XCTest
@testable import PCFoundation

final class SyncStateTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func file(_ size: Int64, _ at: Date) -> SyncStateSide {
        SyncStateSide(size: size, modified: at, isDirectory: false)
    }

    private func dir(_ at: Date) -> SyncStateSide {
        SyncStateSide(size: 0, modified: at, isDirectory: true)
    }

    // MARK: - Has this side moved?

    func test_aFileWithTheSameSizeAndTimeIsUnchanged() {
        XCTAssertTrue(SyncState.unchanged(file(100, t0), size: 100, modified: t0,
                                          isDirectory: false, toleranceSeconds: 2))
        XCTAssertTrue(SyncState.unchanged(file(100, t0), size: 100,
                                          modified: t0.addingTimeInterval(1.5),
                                          isDirectory: false, toleranceSeconds: 2))
        XCTAssertFalse(SyncState.unchanged(file(100, t0), size: 101, modified: t0,
                                           isDirectory: false, toleranceSeconds: 2))
        XCTAssertFalse(SyncState.unchanged(file(100, t0), size: 100,
                                           modified: t0.addingTimeInterval(30),
                                           isDirectory: false, toleranceSeconds: 2))
    }

    /// A folder's timestamp changes whenever a child does. Comparing it would make every folder in
    /// the tree read as changed — and a folder changed on one side against a deleted one on the other
    /// is a conflict, so the whole tree would come back as conflicts.
    func test_aDirectoryIsUnchangedWhileItStillExists() {
        XCTAssertTrue(SyncState.unchanged(dir(t0), size: 4096,
                                          modified: t0.addingTimeInterval(90_000),
                                          isDirectory: true, toleranceSeconds: 2))
    }

    /// A file where a folder was, or the other way round, is never "unchanged" — that has to reach
    /// the decision layer as something to ask about, not as a deletion.
    func test_aKindChangeIsAChange() {
        XCTAssertFalse(SyncState.unchanged(dir(t0), size: 10, modified: t0,
                                           isDirectory: false, toleranceSeconds: 2))
        XCTAssertFalse(SyncState.unchanged(file(10, t0), size: 0, modified: t0,
                                           isDirectory: true, toleranceSeconds: 2))
    }

    /// The daylight-hour widening must not reach this comparison. It exists for two sides' clocks
    /// against each other, not for a side against its own past — and applied here, a file edited
    /// within the last hour whose size happens to be unchanged reads as untouched, which turns
    /// "changed here, deleted there" into a silent deletion.
    func test_theDaylightHourNeverWidensTheComparisonAgainstTheRecord() {
        // `unchanged` takes a plain tolerance and has no way to be told about the DST hour: an edit
        // twenty minutes later is a change at any sane tolerance.
        XCTAssertFalse(SyncState.unchanged(file(100, t0), size: 100,
                                           modified: t0.addingTimeInterval(1_200),
                                           isDirectory: false, toleranceSeconds: 2))
        // And the option that would have widened it is not part of this call's vocabulary at all,
        // which is the structural half of the same claim.
        var options = SyncOptions()
        options.ignoreDaylightHour = true
        options.toleranceSeconds = 2
        XCTAssertFalse(SyncState.unchanged(file(100, t0), size: 100,
                                           modified: t0.addingTimeInterval(1_200),
                                           isDirectory: false,
                                           toleranceSeconds: options.toleranceSeconds))
    }

    // MARK: - How a side stands against its record

    func test_everyWayASideCanStandAgainstItsRecord() {
        let now = file(100, t0)
        XCTAssertEqual(SyncState.change(recorded: nil, now: nil, toleranceSeconds: 2), .neverThere)
        XCTAssertEqual(SyncState.change(recorded: nil, now: now, toleranceSeconds: 2), .appeared)
        XCTAssertEqual(SyncState.change(recorded: now, now: nil, toleranceSeconds: 2), .disappeared)
        XCTAssertEqual(SyncState.change(recorded: now, now: now, toleranceSeconds: 2), .unchanged)
        XCTAssertEqual(SyncState.change(recorded: now, now: file(200, t0), toleranceSeconds: 2),
                       .changed)
    }

    // MARK: - What a path key is

    /// Where composition genuinely matters: the **key**, because a digest is over bytes.
    ///
    /// Measured while writing this, and it corrected the claim the code's comment first made: Swift
    /// compares and hashes `String` by canonical equivalence, so a decomposed name and a composed one
    /// already find each other in a dictionary — `XCTAssertEqual` below on the two strings passes on
    /// its own. What differs is `Data(_.utf8)`, and that is what the key digests. Without
    /// precomposing there, one folder reached two ways would keep two separate histories and neither
    /// would ever see the other's deletions.
    func test_theKeyIsTheSameForTwoSpellingsOfTheSameName() {
        let composed = "/Users/me/Bücher"
        let decomposed = composed.decomposedStringWithCanonicalMapping
        XCTAssertEqual(composed, decomposed, "Swift already compares these as equal")
        XCTAssertNotEqual(Array(composed.utf8), Array(decomposed.utf8),
                          "the fixture is not actually two spellings on disk")
        XCTAssertEqual(SyncState.key(leftRoot: composed, rightRoot: "/tmp/b"),
                       SyncState.key(leftRoot: decomposed, rightRoot: "/tmp/b"),
                       "one folder reached two ways would keep two separate histories")
    }

    /// And the entry keys are stable in their bytes, which is what makes a record file the same from
    /// one run to the next.
    func test_normalisingAPathIsStableInItsBytes() {
        let decomposed = "Bücher/Öl.txt".decomposedStringWithCanonicalMapping
        XCTAssertEqual(Array(SyncState.normalise(decomposed, caseSensitive: true).utf8),
                       Array("Bücher/Öl.txt".precomposedStringWithCanonicalMapping.utf8))
    }

    /// Case folding follows the comparison's own setting, so the record agrees with the pairing that
    /// produced it.
    func test_caseFoldingFollowsTheComparisonsSetting() {
        XCTAssertEqual(SyncState.normalise("README.md", caseSensitive: false), "readme.md")
        XCTAssertEqual(SyncState.normalise("README.md", caseSensitive: true), "README.md")
    }

    /// Over the sorted pair, so "Swap sides" finds the same record instead of silently starting a
    /// second history for the same two folders.
    func test_theKeyIsTheSameWhicheverSideIsLeft() {
        XCTAssertEqual(SyncState.key(leftRoot: "/a/one", rightRoot: "/b/two"),
                       SyncState.key(leftRoot: "/b/two", rightRoot: "/a/one"))
        XCTAssertNotEqual(SyncState.key(leftRoot: "/a/one", rightRoot: "/b/two"),
                          SyncState.key(leftRoot: "/a/one", rightRoot: "/b/three"))
    }

    func test_theKeyIgnoresTrailingSlashesAndDotSegments() {
        XCTAssertEqual(SyncState.key(leftRoot: "/a/one/", rightRoot: "/b/two"),
                       SyncState.key(leftRoot: "/a/./one", rightRoot: "/b/two"))
    }

    func test_theKeyIsAUsableFilename() {
        let key = SyncState.key(leftRoot: "/Users/me/A Folder", rightRoot: "/Volumes/Disk/B")
        XCTAssertEqual(key.count, 32)
        XCTAssertFalse(key.contains("/"))
        XCTAssertTrue(key.allSatisfy { $0.isHexDigit })
    }

    // MARK: - It has to survive being written and read

    /// Field by field with defaults, for the reason `SyncOptions` records: a record written before
    /// the next field existed must still decode, and one that will not decode must cost its own line
    /// and nothing else.
    func test_anEntryFromAnOlderVersionStillDecodes() throws {
        let json = Data(#"{"relativePath":"a.txt","left":{"size":10,"modifiedUnix":1000}}"#.utf8)
        let entry = try JSONDecoder().decode(SyncStateEntry.self, from: json)
        XCTAssertEqual(entry.relativePath, "a.txt")
        XCTAssertEqual(entry.left?.size, 10)
        XCTAssertEqual(entry.left?.isDirectory, false, "a missing key did not take its default")
        XCTAssertNil(entry.right)
    }

    func test_anEntryWithAnUnknownFutureFieldStillDecodes() throws {
        let json = Data(#"{"relativePath":"a.txt","digest":"deadbeef","left":{"size":1,"modifiedUnix":2}}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(SyncStateEntry.self, from: json).relativePath, "a.txt")
    }

    /// Sub-second precision survives, which `JSONEncoder`'s `.iso8601` strategy would have truncated
    /// away — harmless at the default two-second tolerance and not harmless as soon as somebody
    /// types a smaller one into the window's tolerance field.
    func test_aTimestampSurvivesWithItsFraction() throws {
        let odd = Date(timeIntervalSince1970: 1_700_000_000.375)
        let side = SyncStateSide(size: 1, modified: odd, isDirectory: false)
        let back = try JSONDecoder().decode(SyncStateSide.self,
                                            from: JSONEncoder().encode(side))
        XCTAssertEqual(back.modifiedUnix, 1_700_000_000.375, accuracy: 0.0001)
    }

    /// A record with no version is not the current version. Zero is not valid, so it falls out as
    /// unreadable rather than being read as version one by a default.
    func test_aHeaderWithNoVersionIsNotTakenForTheCurrentOne() throws {
        let json = Data(#"{"leftRoot":"/a","rightRoot":"/b"}"#.utf8)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode(SyncStateHeader.self, from: json).version, 0)
    }

    func test_anEntryCanSwapItsSides() {
        let entry = SyncStateEntry(relativePath: "a.txt", left: file(1, t0), right: file(2, t0))
        XCTAssertEqual(entry.swapped.left?.size, 2)
        XCTAssertEqual(entry.swapped.right?.size, 1)
        XCTAssertEqual(entry.swapped.swapped, entry)
    }
}
