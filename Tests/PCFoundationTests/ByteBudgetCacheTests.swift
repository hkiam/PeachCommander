// SPDX-License-Identifier: Apache-2.0
// ByteBudgetCacheTests.swift - The eviction the thumbnail cache leans on (F-479 follow-up).
//
// This exists because the cache it backs lives in PCApp, which has no unit-test bundle. A cache
// whose eviction nobody checks is a cache that quietly holds everything or quietly holds nothing —
// and both look like "it works" from the outside.

import XCTest
@testable import PCFoundation

final class ByteBudgetCacheTests: XCTestCase {

    func testAStoredValueComesBack() {
        let cache = ByteBudgetCache<String>(maxBytes: 1000)
        cache.store("a", bytes: 10, for: "k")
        XCTAssertEqual(cache.value(for: "k"), "a")
        XCTAssertEqual(cache.report.count, 1)
        XCTAssertEqual(cache.report.bytes, 10)
    }

    func testWhatIsNotThereIsNil() {
        XCTAssertNil(ByteBudgetCache<String>(maxBytes: 1000).value(for: "nope"))
    }

    func testReplacingAKeyDoesNotDoubleCountItsBytes() {
        // The accounting error that makes a budget drift upward until it evicts everything — this
        // session already paid for it once, in `MemberStage`.
        let cache = ByteBudgetCache<String>(maxBytes: 1000)
        cache.store("first", bytes: 100, for: "k")
        cache.store("second", bytes: 40, for: "k")
        XCTAssertEqual(cache.value(for: "k"), "second")
        XCTAssertEqual(cache.report.count, 1)
        XCTAssertEqual(cache.report.bytes, 40)
    }

    func testTheLeastRecentlyUsedGoesFirst() {
        let cache = ByteBudgetCache<String>(maxBytes: 100)
        cache.store("a", bytes: 40, for: "a")
        cache.store("b", bytes: 40, for: "b")
        _ = cache.value(for: "a")          // touching "a" makes "b" the oldest
        cache.store("c", bytes: 40, for: "c")
        XCTAssertNil(cache.value(for: "b"), "the untouched one should have gone")
        XCTAssertEqual(cache.value(for: "a"), "a")
        XCTAssertEqual(cache.value(for: "c"), "c")
    }

    func testEvictionStopsAsSoonAsTheBudgetHolds() {
        let cache = ByteBudgetCache<String>(maxBytes: 100)
        for i in 0..<4 { cache.store("v\(i)", bytes: 30, for: "k\(i)") }
        // 120 bytes stored, 100 allowed: exactly one eviction, not a clear-out.
        XCTAssertEqual(cache.report.count, 3)
        XCTAssertEqual(cache.report.bytes, 90)
        XCTAssertNil(cache.value(for: "k0"))
    }

    func testAValueBiggerThanTheWholeBudgetIsStillHandedBackOnce() {
        // The lesson from `MemberStage`: a budget may not undo the work it was just asked for.
        // Storing and immediately dropping would throw away a thumbnail that had already been
        // generated, every single time, and the caller would never see it.
        let cache = ByteBudgetCache<String>(maxBytes: 100)
        cache.store("huge", bytes: 5000, for: "big")
        XCTAssertEqual(cache.value(for: "big"), "huge")
        XCTAssertEqual(cache.report.bytes, 5000, "over budget on purpose, and reported honestly")
    }

    func testAnOversizedValueIsCleanedUpByTheNextStore() {
        let cache = ByteBudgetCache<String>(maxBytes: 100)
        cache.store("huge", bytes: 5000, for: "big")
        cache.store("small", bytes: 10, for: "small")
        XCTAssertNil(cache.value(for: "big"), "the next store is what reclaims it")
        XCTAssertEqual(cache.value(for: "small"), "small")
        XCTAssertEqual(cache.report.bytes, 10)
    }

    func testRemovingOneAdjustsTheTotal() {
        let cache = ByteBudgetCache<String>(maxBytes: 1000)
        cache.store("a", bytes: 30, for: "a")
        cache.store("b", bytes: 70, for: "b")
        cache.remove("a")
        XCTAssertEqual(cache.report.count, 1)
        XCTAssertEqual(cache.report.bytes, 70)
        cache.remove("a")   // twice must not go negative
        XCTAssertEqual(cache.report.bytes, 70)
    }

    func testRemoveAllIsEmptyAndCostsNothing() {
        let cache = ByteBudgetCache<String>(maxBytes: 1000)
        for i in 0..<5 { cache.store("v", bytes: 10, for: "k\(i)") }
        cache.removeAll()
        XCTAssertEqual(cache.report.count, 0)
        XCTAssertEqual(cache.report.bytes, 0)
    }

    func testAZeroCostValueIsHeldWithoutBreakingTheBudget() {
        // An image whose pixel count could not be determined reports 0; it must not become a hole
        // in the accounting or an infinite eviction loop.
        let cache = ByteBudgetCache<String>(maxBytes: 10)
        cache.store("a", bytes: 0, for: "a")
        cache.store("b", bytes: 0, for: "b")
        XCTAssertEqual(cache.report.count, 2)
        XCTAssertEqual(cache.report.bytes, 0)
    }

    func testANegativeCostIsTreatedAsNothing() {
        let cache = ByteBudgetCache<String>(maxBytes: 10)
        cache.store("a", bytes: -50, for: "a")
        XCTAssertEqual(cache.report.bytes, 0, "a negative cost would credit the budget")
    }
}
