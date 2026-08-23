// SPDX-License-Identifier: Apache-2.0
// PlanRowsTests.swift - Striking a row out of a gated plan (F-450).
//
// The dangerous one is `rename_batch`. Its two lists are positional, so filtering them separately shifts
// every pair after the gap onto the wrong name — and the batch still applies cleanly, renaming the wrong
// files. That failure leaves no error behind, which is why it is the first thing pinned here.

import XCTest
@testable import PCAutomation

final class PlanRowsTests: XCTestCase {

    private func data(_ o: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: o)
    }
    private func object(_ d: Data?) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: d ?? Data())) as? [String: Any] ?? [:]
    }

    // MARK: - Which plans have rows at all

    func testABatchRenameOffersOneRowPerPair() {
        let rows = PlanRows.of(tool: "rename_batch",
                               arguments: data(["old_names": ["a", "b"], "new_names": ["x", "y"]]))
        XCTAssertEqual(rows.map(\.id), ["a", "b"])
        XCTAssertEqual(rows.first?.text, "a → x")
    }

    func testANoOpPairIsNotARowToStrikeOut() {
        // It is not going to happen anyway; offering it as a choice would be noise.
        let rows = PlanRows.of(tool: "rename_batch",
                               arguments: data(["old_names": ["a", "same"], "new_names": ["x", "same"]]))
        XCTAssertEqual(rows.map(\.id), ["a"])
    }

    func testASingleItemActionHasNoRows() {
        // Striking out the only row is cancelling, and the plan already has a Cancel.
        XCTAssertTrue(PlanRows.of(tool: "move", arguments: data(["sources": ["/a"], "destination": "/d"])).isEmpty)
        XCTAssertTrue(PlanRows.of(tool: "move_to_trash", arguments: data(["paths": ["/a"]])).isEmpty)
    }

    func testAnIndivisibleActionHasNoRows() {
        XCTAssertTrue(PlanRows.of(tool: "write_file", arguments: data(["path": "/a", "content": "x"])).isEmpty)
        XCTAssertTrue(PlanRows.of(tool: "make_directory", arguments: data(["path": "/a"])).isEmpty)
    }

    func testMultipleSourcesBecomeRowsNamedByTheirLeaf() {
        let rows = PlanRows.of(tool: "move_to_trash",
                               arguments: data(["paths": ["/tmp/one.txt", "/tmp/two.txt"]]))
        XCTAssertEqual(rows.map(\.id), ["/tmp/one.txt", "/tmp/two.txt"])
        XCTAssertEqual(rows.map(\.text), ["one.txt", "two.txt"])
    }

    // MARK: - Striking rows out

    func testARejectedPairTakesItsNewNameWithIt() {
        // The defect this exists to prevent: filter the two lists separately and "c" is renamed to "y".
        let filtered = PlanRows.arguments(
            tool: "rename_batch",
            arguments: data(["old_names": ["a", "b", "c"], "new_names": ["x", "y", "z"]]),
            rejecting: ["b"])
        let o = object(filtered ?? nil)
        XCTAssertEqual(o["old_names"] as? [String], ["a", "c"])
        XCTAssertEqual(o["new_names"] as? [String], ["x", "z"])
    }

    func testRejectingEveryRowIsACancellation() {
        // nil, not an empty list: a move with no sources would run and report success for nothing.
        let filtered = PlanRows.arguments(
            tool: "rename_batch",
            arguments: data(["old_names": ["a"], "new_names": ["x"]]), rejecting: ["a"])
        XCTAssertNil(filtered ?? nil)
        let trash = PlanRows.arguments(tool: "move_to_trash",
                                       arguments: data(["paths": ["/a", "/b"]]), rejecting: ["/a", "/b"])
        XCTAssertNil(trash ?? nil)
    }

    func testRejectingNothingLeavesTheArgumentsUntouched() {
        let original = data(["paths": ["/a", "/b"]])
        let filtered = PlanRows.arguments(tool: "move_to_trash", arguments: original, rejecting: [])
        XCTAssertEqual(filtered ?? nil, original)
    }

    func testSourcesAndPathsAreFilteredByValue() {
        let moved = PlanRows.arguments(tool: "move",
                                       arguments: data(["sources": ["/a", "/b", "/c"],
                                                        "destination": "/d"]),
                                       rejecting: ["/b"])
        let o = object(moved ?? nil)
        XCTAssertEqual(o["sources"] as? [String], ["/a", "/c"])
        // Everything else survives: a filtered move still needs somewhere to go.
        XCTAssertEqual(o["destination"] as? String, "/d")
    }

    func testAnUnknownIdRejectsNothing() {
        // A stale row id — a plan re-rendered after the arguments changed — must not silently empty the
        // action.
        let filtered = PlanRows.arguments(tool: "move_to_trash",
                                          arguments: data(["paths": ["/a", "/b"]]),
                                          rejecting: ["/gone"])
        XCTAssertEqual(object(filtered ?? nil)["paths"] as? [String], ["/a", "/b"])
    }

    func testAToolWithoutRowsIgnoresRejections() {
        let original = data(["path": "/a", "content": "x"])
        let filtered = PlanRows.arguments(tool: "write_file", arguments: original, rejecting: ["/a"])
        XCTAssertEqual(filtered ?? nil, original)
    }

    func testMismatchedListsAreLeftAloneRatherThanGuessedAt()  {
        // RenameBatchPlan refuses these before they can be proposed; if one ever reaches here, pairing
        // them up would be an invention.
        let original = data(["old_names": ["a", "b"], "new_names": ["x"]])
        XCTAssertTrue(PlanRows.of(tool: "rename_batch", arguments: original).isEmpty)
        XCTAssertEqual(PlanRows.arguments(tool: "rename_batch", arguments: original,
                                          rejecting: ["a"]) ?? nil, original)
    }
}
