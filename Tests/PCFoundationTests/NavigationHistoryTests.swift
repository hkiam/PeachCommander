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
}
