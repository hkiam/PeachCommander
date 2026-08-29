// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class NavigationHistoryTests: XCTestCase {
    func testEmpty() {
        let h = NavigationHistory()
        XCTAssertNil(h.current)
        XCTAssertFalse(h.canGoBack)
        XCTAssertFalse(h.canGoForward)
    }

    func testPushAndCurrent() {
        var h = NavigationHistory()
        h.push("/a")
        XCTAssertEqual(h.current, "/a")
        h.push("/b")
        XCTAssertEqual(h.current, "/b")
        XCTAssertTrue(h.canGoBack)
        XCTAssertFalse(h.canGoForward)
    }

    func testConsecutiveDuplicateIgnored() {
        var h = NavigationHistory()
        h.push("/a")
        h.push("/a")
        XCTAssertEqual(h.entries, ["/a"])
    }

    func testBackForward() {
        var h = NavigationHistory()
        h.push("/a"); h.push("/b"); h.push("/c")
        XCTAssertEqual(h.back(), "/b")
        XCTAssertEqual(h.back(), "/a")
        XCTAssertNil(h.back())
        XCTAssertEqual(h.forward(), "/b")
        XCTAssertEqual(h.forward(), "/c")
        XCTAssertNil(h.forward())
    }

    func testPushTruncatesForward() {
        var h = NavigationHistory()
        h.push("/a"); h.push("/b"); h.push("/c")
        _ = h.back() // at /b
        h.push("/d")
        XCTAssertEqual(h.entries, ["/a", "/b", "/d"])
        XCTAssertEqual(h.current, "/d")
        XCTAssertFalse(h.canGoForward)
    }

    func testCapacityTrim() {
        var h = NavigationHistory(capacity: 3)
        h.push("/1"); h.push("/2"); h.push("/3"); h.push("/4")
        XCTAssertEqual(h.entries, ["/2", "/3", "/4"])
        XCTAssertEqual(h.current, "/4")
        XCTAssertEqual(h.back(), "/3")
    }

    func testGoToIndex() {
        var h = NavigationHistory()
        h.push("/a"); h.push("/b"); h.push("/c")
        XCTAssertEqual(h.go(to: 0), "/a")
        XCTAssertTrue(h.canGoForward)
        XCTAssertEqual(h.go(to: 5), nil)   // out of range → no change
        XCTAssertEqual(h.current, "/a")
    }

    func testRestoreFromEntries() {
        let h = NavigationHistory(entries: ["/x", "/y", "/z"], index: 1)
        XCTAssertEqual(h.entries, ["/x", "/y", "/z"])
        XCTAssertEqual(h.current, "/y")
        // Clamping + empty
        XCTAssertEqual(NavigationHistory(entries: ["/x"], index: 9).current, "/x")
        XCTAssertEqual(NavigationHistory(entries: [], index: 0).index, -1)
    }

    // MARK: - A move whose navigation did not happen (F-445)

    /// A superseded load: the position goes back and the entry stays, because there is nothing wrong
    /// with it — the user simply navigated again while it was arriving.
    func testASupersededMovePutsThePositionBackAndKeepsEveryEntry() {
        var h = NavigationHistory()
        h.push("/a"); h.push("/b"); h.push("/c")
        let origin = h.index
        XCTAssertEqual(h.back(), "/b")
        h.restorePosition(to: origin)
        XCTAssertEqual(h.entries, ["/a", "/b", "/c"])
        XCTAssertEqual(h.current, "/c")
    }

    /// A refused load going back: the position goes back *and* the dead entry is gone, so the next
    /// press reaches the one before it instead of the same wall.
    func testGoingBackIntoAFolderThatCannotBeOpenedDropsItAndLeavesTheWayPast() {
        var h = NavigationHistory()
        h.push("/a"); h.push("/gone"); h.push("/c")
        let origin = h.index                     // at /c
        XCTAssertEqual(h.back(), "/gone")
        h.dropEntry(at: h.index, restoringPositionTo: origin)
        XCTAssertEqual(h.entries, ["/a", "/c"])
        XCTAssertEqual(h.current, "/c")          // the panel never moved
        // And the wall is gone: the next press reaches what was behind the dead entry.
        XCTAssertEqual(h.back(), "/a")
    }

    /// Forward, where the hole is *after* the position — the restored index must not shift.
    func testGoingForwardIntoAFolderThatCannotBeOpenedLeavesThePositionWhereItWas() {
        var h = NavigationHistory()
        h.push("/a"); h.push("/b"); h.push("/gone")
        _ = h.go(to: 0)
        let origin = h.index                     // at /a
        XCTAssertEqual(h.forward(), "/b")
        h.dropEntry(at: h.index, restoringPositionTo: origin)
        XCTAssertEqual(h.entries, ["/a", "/gone"])
        XCTAssertEqual(h.current, "/a")
    }

    /// `go(to:)` can be handed the position it is already at. That entry is the one the panel is
    /// *showing*, so a failure there must not remove it — the alternative is a history with no entry
    /// for where the panel actually is.
    func testAFailureAtThePositionItIsAlreadyAtRemovesNothing() {
        var h = NavigationHistory()
        h.push("/a"); h.push("/b")
        let origin = h.index
        XCTAssertEqual(h.go(to: origin), "/b")
        h.dropEntry(at: h.index, restoringPositionTo: origin)
        XCTAssertEqual(h.entries, ["/a", "/b"])
        XCTAssertEqual(h.current, "/b")
    }

    /// Dropping the last entry that is not the current one still leaves a usable history rather than
    /// an index pointing past the end.
    func testDroppingDownToASingleEntryLeavesTheIndexInRange() {
        var h = NavigationHistory()
        h.push("/gone"); h.push("/c")
        let origin = h.index
        XCTAssertEqual(h.back(), "/gone")
        h.dropEntry(at: h.index, restoringPositionTo: origin)
        XCTAssertEqual(h.entries, ["/c"])
        XCTAssertEqual(h.index, 0)
        XCTAssertEqual(h.current, "/c")
        XCTAssertFalse(h.canGoBack)
        XCTAssertFalse(h.canGoForward)
    }

    /// Out-of-range is answered rather than trapped: the position is restored and nothing removed.
    func testDroppingAnIndexThatIsNotThereOnlyRestores() {
        var h = NavigationHistory()
        h.push("/a"); h.push("/b")
        h.dropEntry(at: 9, restoringPositionTo: 0)
        XCTAssertEqual(h.entries, ["/a", "/b"])
        XCTAssertEqual(h.current, "/a")
    }

    /// The guard the caller asks before undoing anything. A newer navigation that has already
    /// recorded itself must not have its position taken away by a older move's recovery.
    func testTheStillThereGuardAnswersForBothTheUntouchedAndTheMovedOnCase() {
        var h = NavigationHistory()
        h.push("/a"); h.push("/b")
        XCTAssertEqual(h.back(), "/a")
        XCTAssertTrue(h.isStill(at: 0, showing: "/a"))
        // A newer navigation lands and records itself; the older move must now keep its hands off.
        h.push("/z")
        XCTAssertFalse(h.isStill(at: 0, showing: "/a"))
    }
}
