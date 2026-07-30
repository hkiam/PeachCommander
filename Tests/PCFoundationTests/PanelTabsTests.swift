import XCTest
@testable import PCFoundation

final class PanelTabsTests: XCTestCase {
    private func tab(_ path: String, locked: Bool = false, cursorName: String? = nil) -> PanelTabState {
        PanelTabState(path: path, locked: locked, cursorName: cursorName)
    }

    // MARK: - Init

    func testInitialSingleTab() {
        let initial = tab("/a")
        let tabs = PanelTabs(initial: initial)
        XCTAssertEqual(tabs.count, 1)
        XCTAssertEqual(tabs.activeIndex, 0)
        XCTAssertEqual(tabs.active, initial)
    }

    func testInitFromSavedListWithinRange() {
        let tabs = PanelTabs(tabs: [tab("/a"), tab("/b"), tab("/c")], activeIndex: 1)
        XCTAssertEqual(tabs.activeIndex, 1)
        XCTAssertEqual(tabs.active.path, "/b")
    }

    func testInitFromSavedListClampsHigh() {
        let tabs = PanelTabs(tabs: [tab("/a"), tab("/b")], activeIndex: 99)
        XCTAssertEqual(tabs.activeIndex, 1)
        XCTAssertEqual(tabs.active.path, "/b")
    }

    func testInitFromSavedListClampsLow() {
        let tabs = PanelTabs(tabs: [tab("/a"), tab("/b")], activeIndex: -5)
        XCTAssertEqual(tabs.activeIndex, 0)
        XCTAssertEqual(tabs.active.path, "/a")
    }

    // MARK: - move (F-008)

    func testMoveActiveTabFollowsToDestination() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b"), tab("/c"), tab("/d")], activeIndex: 2)  // active = /c
        tabs.move(from: 2, to: 0)
        XCTAssertEqual(tabs.tabs.map(\.path), ["/c", "/a", "/b", "/d"])
        XCTAssertEqual(tabs.active.path, "/c")
        XCTAssertEqual(tabs.activeIndex, 0)
    }

    func testMoveOtherTabKeepsActiveTabActive_forward() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b"), tab("/c"), tab("/d")], activeIndex: 2)  // active = /c
        tabs.move(from: 0, to: 3)   // A to the end
        XCTAssertEqual(tabs.tabs.map(\.path), ["/b", "/c", "/d", "/a"])
        XCTAssertEqual(tabs.active.path, "/c")
    }

    func testMoveOtherTabKeepsActiveTabActive_backward() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b"), tab("/c"), tab("/d")], activeIndex: 1)  // active = /b
        tabs.move(from: 3, to: 0)   // D to the front
        XCTAssertEqual(tabs.tabs.map(\.path), ["/d", "/a", "/b", "/c"])
        XCTAssertEqual(tabs.active.path, "/b")
    }

    func testMoveNoOpForEqualOrOutOfRange() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b")], activeIndex: 0)
        tabs.move(from: 0, to: 0)
        tabs.move(from: 5, to: 0)
        tabs.move(from: 0, to: 9)
        XCTAssertEqual(tabs.tabs.map(\.path), ["/a", "/b"])
        XCTAssertEqual(tabs.activeIndex, 0)
    }

    // MARK: - open

    func testOpenActivateTrueInsertsAfterActiveAndActivates() {
        var tabs = PanelTabs(initial: tab("/a"))
        tabs.open(tab("/b"), activate: true)
        XCTAssertEqual(tabs.tabs.map(\.path), ["/a", "/b"])
        XCTAssertEqual(tabs.activeIndex, 1)
        XCTAssertEqual(tabs.active.path, "/b")
    }

    func testOpenActivateFalseKeepsCurrentActive() {
        var tabs = PanelTabs(initial: tab("/a"))
        tabs.open(tab("/b"), activate: false)
        XCTAssertEqual(tabs.tabs.map(\.path), ["/a", "/b"])
        XCTAssertEqual(tabs.activeIndex, 0)
        XCTAssertEqual(tabs.active.path, "/a")
    }

    func testOpenInsertsRightAfterActiveNotAtEnd() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b"), tab("/c")], activeIndex: 0)
        tabs.open(tab("/new"), activate: false)
        XCTAssertEqual(tabs.tabs.map(\.path), ["/a", "/new", "/b", "/c"])
        XCTAssertEqual(tabs.activeIndex, 0)
    }

    func testOpenActivateTrueFromMiddle() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b"), tab("/c")], activeIndex: 1)
        tabs.open(tab("/new"), activate: true)
        XCTAssertEqual(tabs.tabs.map(\.path), ["/a", "/b", "/new", "/c"])
        XCTAssertEqual(tabs.activeIndex, 2)
        XCTAssertEqual(tabs.active.path, "/new")
    }

    // MARK: - close(at:)

    func testCloseRefusesWhenOnlyOneTabRemains() {
        var tabs = PanelTabs(initial: tab("/a"))
        let result = tabs.close(at: 0)
        XCTAssertFalse(result)
        XCTAssertEqual(tabs.count, 1)
        XCTAssertEqual(tabs.active.path, "/a")
    }

    func testCloseOutOfRangeReturnsFalse() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b")], activeIndex: 0)
        XCTAssertFalse(tabs.close(at: 5))
        XCTAssertFalse(tabs.close(at: -1))
        XCTAssertEqual(tabs.count, 2)
    }

    func testCloseTabBeforeActiveDecrementsActiveIndex() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b"), tab("/c")], activeIndex: 2)
        let result = tabs.close(at: 0)
        XCTAssertTrue(result)
        XCTAssertEqual(tabs.tabs.map(\.path), ["/b", "/c"])
        XCTAssertEqual(tabs.activeIndex, 1)
        XCTAssertEqual(tabs.active.path, "/c")
    }

    func testCloseTabAfterActiveKeepsActiveIndex() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b"), tab("/c")], activeIndex: 0)
        let result = tabs.close(at: 2)
        XCTAssertTrue(result)
        XCTAssertEqual(tabs.tabs.map(\.path), ["/a", "/b"])
        XCTAssertEqual(tabs.activeIndex, 0)
        XCTAssertEqual(tabs.active.path, "/a")
    }

    func testCloseActiveMiddleTabSelectsPrevious() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b"), tab("/c")], activeIndex: 1)
        let result = tabs.close(at: 1)
        XCTAssertTrue(result)
        XCTAssertEqual(tabs.tabs.map(\.path), ["/a", "/c"])
        XCTAssertEqual(tabs.activeIndex, 0)
        XCTAssertEqual(tabs.active.path, "/a")
    }

    func testCloseActiveLastTabSelectsPrevious() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b"), tab("/c")], activeIndex: 2)
        let result = tabs.close(at: 2)
        XCTAssertTrue(result)
        XCTAssertEqual(tabs.tabs.map(\.path), ["/a", "/b"])
        XCTAssertEqual(tabs.activeIndex, 1)
        XCTAssertEqual(tabs.active.path, "/b")
    }

    func testCloseActiveFirstTabSelectsNewFirst() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b"), tab("/c")], activeIndex: 0)
        let result = tabs.close(at: 0)
        XCTAssertTrue(result)
        XCTAssertEqual(tabs.tabs.map(\.path), ["/b", "/c"])
        XCTAssertEqual(tabs.activeIndex, 0)
        XCTAssertEqual(tabs.active.path, "/b")
    }

    // MARK: - closeActive

    func testCloseActiveConvenienceMatchesCloseAt() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b"), tab("/c")], activeIndex: 1)
        let result = tabs.closeActive()
        XCTAssertTrue(result)
        XCTAssertEqual(tabs.tabs.map(\.path), ["/a", "/c"])
        XCTAssertEqual(tabs.activeIndex, 0)
    }

    func testCloseActiveRefusesWithSingleTab() {
        var tabs = PanelTabs(initial: tab("/a"))
        XCTAssertFalse(tabs.closeActive())
        XCTAssertEqual(tabs.count, 1)
    }

    // MARK: - select

    func testSelectValidIndex() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b"), tab("/c")], activeIndex: 0)
        tabs.select(2)
        XCTAssertEqual(tabs.activeIndex, 2)
        XCTAssertEqual(tabs.active.path, "/c")
    }

    func testSelectOutOfRangeIsIgnored() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b")], activeIndex: 0)
        tabs.select(99)
        XCTAssertEqual(tabs.activeIndex, 0)
        tabs.select(-1)
        XCTAssertEqual(tabs.activeIndex, 0)
    }

    // MARK: - next / previous

    func testNextCyclesForwardAndWraps() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b"), tab("/c")], activeIndex: 0)
        tabs.next()
        XCTAssertEqual(tabs.activeIndex, 1)
        tabs.next()
        XCTAssertEqual(tabs.activeIndex, 2)
        tabs.next()
        XCTAssertEqual(tabs.activeIndex, 0)
    }

    func testPreviousCyclesBackwardAndWraps() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b"), tab("/c")], activeIndex: 0)
        tabs.previous()
        XCTAssertEqual(tabs.activeIndex, 2)
        tabs.previous()
        XCTAssertEqual(tabs.activeIndex, 1)
        tabs.previous()
        XCTAssertEqual(tabs.activeIndex, 0)
    }

    func testNextWithSingleTabStaysPut() {
        var tabs = PanelTabs(initial: tab("/a"))
        tabs.next()
        XCTAssertEqual(tabs.activeIndex, 0)
    }

    // MARK: - updateActive

    func testUpdateActiveMutatesOnlyActiveTab() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b")], activeIndex: 1)
        tabs.updateActive { $0.path = "/b-renamed"; $0.sortAscending = false }
        XCTAssertEqual(tabs.tabs[0].path, "/a")
        XCTAssertEqual(tabs.tabs[1].path, "/b-renamed")
        XCTAssertFalse(tabs.active.sortAscending)
    }

    func testUpdateActiveCanSetCursorName() {
        var tabs = PanelTabs(initial: tab("/a"))
        tabs.updateActive { $0.cursorName = "file.txt" }
        XCTAssertEqual(tabs.active.cursorName, "file.txt")
    }

    // MARK: - toggleLockActive

    func testToggleLockActiveFlipsFlag() {
        var tabs = PanelTabs(initial: tab("/a", locked: false))
        tabs.toggleLockActive()
        XCTAssertTrue(tabs.active.locked)
        tabs.toggleLockActive()
        XCTAssertFalse(tabs.active.locked)
    }

    func testToggleLockActiveOnlyAffectsActiveTab() {
        var tabs = PanelTabs(tabs: [tab("/a"), tab("/b")], activeIndex: 0)
        tabs.toggleLockActive()
        XCTAssertTrue(tabs.tabs[0].locked)
        XCTAssertFalse(tabs.tabs[1].locked)
    }

    // MARK: - Equatable

    func testPanelTabsEquality() {
        let a = PanelTabs(tabs: [tab("/a"), tab("/b")], activeIndex: 1)
        let b = PanelTabs(tabs: [tab("/a"), tab("/b")], activeIndex: 1)
        let c = PanelTabs(tabs: [tab("/a"), tab("/b")], activeIndex: 0)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
