// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

/// The model behind the history palette (F-402): weighting, de-duplication, eviction, pruning and the
/// round-trip through one INI value. All of it without a window, which is the point of it living here.
final class GlobalHistoryTests: XCTestCase {

    private func folder(_ path: String, ago: TimeInterval = 0, count: Int = 1,
                        pinned: Bool = false) -> HistoryEntry {
        HistoryEntry(kind: .folder, path: path, lastUsed: Date().addingTimeInterval(-ago),
                     useCount: count, pinned: pinned)
    }

    // MARK: - Recording

    func testASecondVisitCountsInsteadOfPilingUp() {
        var h = GlobalHistory()
        h.record(folder("/Users/mel/src", ago: 600))
        h.record(folder("/Users/mel/src"))          // a separate visit, ten minutes later
        h.record(folder("/Users/mel/docs"))
        XCTAssertEqual(h.entries.count, 2)
        XCTAssertEqual(h.entries.first { $0.path == "/Users/mel/src" }?.useCount, 2)
    }

    /// One user action can reach `record` twice — the palette counts the entry it opened, and the
    /// navigation that follows reports the same folder again a moment later (asynchronously, so no flag
    /// around the call can cover it). A refresh of the same directory is the same shape. Counting those
    /// twice would inflate exactly the number the ranking is built on.
    func testTwoRecordsOfOneActionCountOnce() {
        var h = GlobalHistory()
        h.record(folder("/Users/mel/src"))
        h.record(folder("/Users/mel/src"))          // same moment
        XCTAssertEqual(h.entries.count, 1)
        XCTAssertEqual(h.entries[0].useCount, 1)
        // Far enough apart is two uses again, or the history would stop counting altogether.
        h.record(HistoryEntry(kind: .folder, path: "/Users/mel/src",
                              lastUsed: Date().addingTimeInterval(GlobalHistory.coalesceWindow + 1)))
        XCTAssertEqual(h.entries[0].useCount, 2)
    }

    func testTheNewestUseRefreshesThePanelButKeepsTheCount() {
        var h = GlobalHistory()
        h.record(HistoryEntry(kind: .folder, path: "/a",
                              lastUsed: Date().addingTimeInterval(-600), panel: .left))
        h.record(HistoryEntry(kind: .folder, path: "/a", panel: .right))
        XCTAssertEqual(h.entries.count, 1)
        XCTAssertEqual(h.entries[0].panel, .right)
        XCTAssertEqual(h.entries[0].useCount, 2)
    }

    /// The same path as a folder and as a file are two entries: opening a file is not visiting a folder.
    func testIdentityIsPerKind() {
        var h = GlobalHistory()
        h.record(HistoryEntry(kind: .folder, path: "/x"))
        h.record(HistoryEntry(kind: .file, path: "/x"))
        XCTAssertEqual(h.entries.count, 2)
    }

    /// A shell command is "the same command" wherever it was run, like a shell history.
    func testACommandIsIdentifiedByItsLineNotItsDirectory() {
        var h = GlobalHistory()
        h.record(HistoryEntry(kind: .command, path: "/one", detail: "git status",
                              lastUsed: Date().addingTimeInterval(-600)))
        h.record(HistoryEntry(kind: .command, path: "/two", detail: "git status"))
        XCTAssertEqual(h.entries.count, 1)
        XCTAssertEqual(h.entries[0].useCount, 2)
    }

    /// Two copies into one folder from different sources are two things to repeat.
    func testOperationsDifferByWhatTheyActedOn() {
        var h = GlobalHistory()
        h.record(HistoryEntry(kind: .operation, path: "/backup", detail: "Copy", payload: "a.txt"))
        h.record(HistoryEntry(kind: .operation, path: "/backup", detail: "Copy", payload: "b.txt"))
        XCTAssertEqual(h.entries.count, 2)
    }

    // MARK: - Weighting

    func testFrequentBeatsMerelyRecent() {
        var h = GlobalHistory()
        h.record(folder("/often", ago: 3 * 86_400, count: 40))
        h.record(folder("/once", ago: 30 * 60, count: 1))
        XCTAssertEqual(h.ranked().first?.path, "/often")
    }

    func testRecentBeatsEquallyUsedButOld() {
        var h = GlobalHistory()
        h.record(folder("/old", ago: 40 * 86_400, count: 3))
        h.record(folder("/new", ago: 60, count: 3))
        XCTAssertEqual(h.ranked().map(\.path), ["/new", "/old"])
    }

    func testPinnedLeadsWhateverElseHappened() {
        var h = GlobalHistory()
        h.record(folder("/pinned", ago: 200 * 86_400, count: 1, pinned: true))
        h.record(folder("/hot", ago: 30, count: 500))
        XCTAssertEqual(h.ranked().first?.path, "/pinned")
    }

    func testChronologicalIgnoresFrequency() {
        var h = GlobalHistory()
        h.record(folder("/often", ago: 3 * 86_400, count: 40))
        h.record(folder("/once", ago: 30 * 60, count: 1))
        XCTAssertEqual(h.chronological().map(\.path), ["/once", "/often"])
    }

    // MARK: - Filtering and searching

    func testFilterByKindAndPinned() {
        var h = GlobalHistory()
        h.record(HistoryEntry(kind: .folder, path: "/dir"))
        h.record(HistoryEntry(kind: .file, path: "/dir/file.txt"))
        h.record(HistoryEntry(kind: .command, path: "/dir", detail: "ls -la", pinned: true))
        XCTAssertEqual(h.ranked(kind: .file).map(\.path), ["/dir/file.txt"])
        XCTAssertEqual(h.ranked(pinnedOnly: true).map(\.detail), ["ls -la"])
    }

    func testAQueryOfSeveralWordsMustMatchWithAllOfThem() {
        var h = GlobalHistory()
        h.record(HistoryEntry(kind: .file, path: "/Users/mel/Projects/annual-report.txt"))
        h.record(HistoryEntry(kind: .file, path: "/Users/mel/Music/track.m4a"))
        XCTAssertEqual(h.ranked(query: "proj rep").map(\.path), ["/Users/mel/Projects/annual-report.txt"])
        XCTAssertTrue(h.ranked(query: "proj nothinglikethis").isEmpty)
    }

    func testTheQueryReordersWithinTheWeightingRatherThanReplacingIt() {
        var h = GlobalHistory()
        h.record(folder("/Users/mel/reports", ago: 30, count: 1))
        h.record(folder("/Users/mel/report-archive", ago: 30, count: 1))
        // Both match; the better (shorter, name-anchored) match leads.
        XCTAssertEqual(h.ranked(query: "reports").first?.path, "/Users/mel/reports")
    }

    // MARK: - Eviction and pruning

    func testEvictionDropsTheWorstNotTheOldest() {
        var h = GlobalHistory(capacity: 2)
        h.record(folder("/valuable", ago: 10 * 86_400, count: 100))
        h.record(folder("/filler-1", ago: 60, count: 1))
        h.record(folder("/filler-2", ago: 30, count: 1))
        XCTAssertEqual(h.entries.count, 2)
        XCTAssertTrue(h.entries.contains { $0.path == "/valuable" })
    }

    func testPinnedEntriesAreNotEvictedForBeingTooMany() {
        var h = GlobalHistory(capacity: 1)
        h.record(folder("/pin-1", ago: 500 * 86_400, pinned: true))
        h.record(folder("/pin-2", ago: 500 * 86_400, pinned: true))
        h.record(folder("/plain-1", ago: 10))
        h.record(folder("/plain-2", ago: 5))
        XCTAssertEqual(h.entries.filter(\.pinned).count, 2)
        XCTAssertEqual(h.entries.filter { !$0.pinned }.count, 1)
    }

    func testPruneKeepsPinnedAndDoesNothingForZeroDays() {
        var h = GlobalHistory()
        h.record(folder("/old", ago: 200 * 86_400))
        h.record(folder("/old-but-pinned", ago: 200 * 86_400, pinned: true))
        h.record(folder("/fresh", ago: 60))
        var untouched = h
        untouched.prune(olderThanDays: 0)
        XCTAssertEqual(untouched.entries.count, 3)
        h.prune(olderThanDays: 90)
        XCTAssertEqual(Set(h.entries.map(\.path)), ["/old-but-pinned", "/fresh"])
    }

    func testRemoveAndPin() {
        var h = GlobalHistory()
        h.record(folder("/a"))
        let id = h.entries[0].identity
        XCTAssertTrue(h.setPinned(true, identity: id))
        XCTAssertTrue(h.entries[0].pinned)
        h.remove(identity: id)
        XCTAssertTrue(h.entries.isEmpty)
        XCTAssertFalse(h.setPinned(true, identity: id))
    }

    func testRemoveAllKeepsPinnedByDefault() {
        var h = GlobalHistory()
        h.record(folder("/a", pinned: true))
        h.record(folder("/b"))
        var kept = h
        kept.removeAll()
        XCTAssertEqual(kept.entries.map(\.path), ["/a"])
        h.removeAll(keepingPinned: false)
        XCTAssertTrue(h.entries.isEmpty)
    }

    // MARK: - Codec

    func testRoundTripThroughOneIniValue() {
        var h = GlobalHistory()
        h.record(HistoryEntry(kind: .folder, path: "/Users/mel/a folder", useCount: 7, panel: .right))
        h.record(HistoryEntry(kind: .command, path: "/Users/mel", detail: "grep -rn \"x = 1\" .",
                              pinned: true))
        h.record(HistoryEntry(kind: .operation, path: "/backup", detail: "Copy 2 items",
                              payload: "copy\u{3}/a.txt\u{3}/b.txt"))
        let decoded = HistoryCodec.decode(HistoryCodec.encode(h))
        XCTAssertEqual(decoded.entries.count, 3)
        for original in h.entries {
            guard let round = decoded.entries.first(where: { $0.identity == original.identity }) else {
                return XCTFail("lost \(original.identity)")
            }
            XCTAssertEqual(round.useCount, original.useCount)
            XCTAssertEqual(round.pinned, original.pinned)
            XCTAssertEqual(round.panel, original.panel)
            XCTAssertEqual(round.payload, original.payload)
            // Seconds resolution is deliberate; the palette shows "5 minutes ago".
            XCTAssertEqual(round.lastUsed.timeIntervalSince1970,
                           original.lastUsed.timeIntervalSince1970, accuracy: 1)
        }
    }

    func testDecodeToleratesEmptyGarbageAndMissingTrailingFields() {
        XCTAssertTrue(HistoryCodec.decode("").entries.isEmpty)
        XCTAssertTrue(HistoryCodec.decode("nonsense").entries.isEmpty)
        XCTAssertTrue(HistoryCodec.decode("wrongkind\u{1}/a\u{1}\u{1}\u{1}0").entries.isEmpty)
        // A record written before useCount/pinned/panel existed: kind, path, detail, payload, time.
        let old = HistoryCodec.decode("folder\u{1}/a\u{1}\u{1}\u{1}1000000")
        XCTAssertEqual(old.entries.count, 1)
        XCTAssertEqual(old.entries[0].useCount, 1)
        XCTAssertFalse(old.entries[0].pinned)
        XCTAssertNil(old.entries[0].panel)
    }
}
