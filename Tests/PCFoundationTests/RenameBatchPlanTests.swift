// SPDX-License-Identifier: Apache-2.0
// RenameBatchPlanTests.swift - Refusing a whole batch of renames rather than half doing it (F-447).
//
// This is the gate a language model's proposal has to pass, and the failures it exists for are the ones
// that look fine row by row: two files aimed at one name, a name already taken by a file that is
// staying, two lists that do not line up. Each of those, applied, leaves a folder somebody has to
// untangle by hand — and which files got renamed depends on the order, which nobody chose.

import XCTest
@testable import PCFoundation

final class RenameBatchPlanTests: XCTestCase {

    private func pairs(_ items: [(String, String)]) -> [RenameBatchPlan.Pair] {
        items.map { RenameBatchPlan.Pair(old: $0.0, new: $0.1) }
    }

    // MARK: - Pairing two lists

    func testListsOfDifferentLengthsAreRefusedRatherThanTruncated() {
        // Truncating would rename some files and not others, which is the worst of both answers.
        guard case .failure(let problem) = RenameBatchPlan.pair(old: ["a", "b", "c"], new: ["x", "y"])
        else { return XCTFail("mismatched lists should not pair") }
        XCTAssertTrue(problem.reason.contains("3"), problem.reason)
        XCTAssertTrue(problem.reason.contains("2"), problem.reason)
    }

    func testAnEmptyBatchIsRefused() {
        guard case .failure = RenameBatchPlan.pair(old: [], new: []) else {
            return XCTFail("an empty batch is not a rename")
        }
    }

    func testMatchingListsPairInOrder() {
        guard case .success(let p) = RenameBatchPlan.pair(old: ["a", "b"], new: ["x", "y"]) else {
            return XCTFail("should pair")
        }
        XCTAssertEqual(p, pairs([("a", "x"), ("b", "y")]))
    }

    // MARK: - What makes a batch unusable

    func testACleanBatchHasNoProblems() {
        let p = pairs([("a.txt", "1.txt"), ("b.txt", "2.txt")])
        XCTAssertEqual(RenameBatchPlan.problems(in: p, existing: ["a.txt", "b.txt"]), [])
    }

    func testTwoFilesOntoOneNameIsRefused() {
        // Whichever ran second would fail, and which one that is depends on the order.
        let p = pairs([("a.txt", "same.txt"), ("b.txt", "same.txt")])
        let problems = RenameBatchPlan.problems(in: p, existing: ["a.txt", "b.txt"])
        XCTAssertEqual(problems.count, 1)
        XCTAssertEqual(problems.first?.name, "b.txt")
        XCTAssertTrue(problems.first!.reason.contains("a.txt"), problems.first!.reason)
    }

    func testANameTakenByAFileThatIsStayingIsRefused() {
        let p = pairs([("a.txt", "keep.txt")])
        let problems = RenameBatchPlan.problems(in: p, existing: ["a.txt", "keep.txt"])
        XCTAssertEqual(problems.count, 1)
        XCTAssertTrue(problems.first!.reason.contains("already exists"), problems.first!.reason)
    }

    func testASwapIsAllowed() {
        // Both names are taken, and both are being renamed away — the engine stages through temporary
        // names, so this works and must not be refused.
        let p = pairs([("a.txt", "b.txt"), ("b.txt", "a.txt")])
        XCTAssertEqual(RenameBatchPlan.problems(in: p, existing: ["a.txt", "b.txt"]), [])
    }

    func testARotationIsAllowed() {
        let p = pairs([("a", "b"), ("b", "c"), ("c", "a")])
        XCTAssertEqual(RenameBatchPlan.problems(in: p, existing: ["a", "b", "c"]), [])
    }

    func testAMissingSourceIsRefused() {
        let problems = RenameBatchPlan.problems(in: pairs([("gone.txt", "x.txt")]), existing: ["a.txt"])
        XCTAssertEqual(problems.count, 1)
        XCTAssertTrue(problems.first!.reason.contains("no such file"), problems.first!.reason)
    }

    func testUnusableNewNamesAreRefusedWithTheReason() {
        let cases: [(String, String)] = [("a.txt", ""), ("b.txt", "."), ("c.txt", "sub/x.txt")]
        let problems = RenameBatchPlan.problems(in: pairs(cases),
                                                existing: ["a.txt", "b.txt", "c.txt"])
        XCTAssertEqual(problems.count, 3)
        XCTAssertTrue(problems.contains { $0.reason.contains("empty") }, "\(problems)")
        XCTAssertTrue(problems.contains { $0.reason.contains("reserved") }, "\(problems)")
        XCTAssertTrue(problems.contains { $0.reason.contains("path separator") }, "\(problems)")
    }

    func testEveryReasonIsReportedAtOnceNotJustTheFirst() {
        // A model's mistake is usually systematic, so one message per row is what lets it be fixed in
        // one more turn instead of ten.
        let p = pairs([("gone.txt", ""), ("also-gone.txt", "..")])
        XCTAssertEqual(RenameBatchPlan.problems(in: p, existing: ["a.txt"]).count, 4)
    }

    func testABatchOfNoOpsSaysSoRatherThanReportingSuccess() {
        let p = pairs([("a.txt", "a.txt")])
        let problems = RenameBatchPlan.problems(in: p, existing: ["a.txt"])
        XCTAssertEqual(problems.count, 1)
        XCTAssertTrue(problems.first!.reason.contains("already"), problems.first!.reason)
    }

    func testAnUnknownFolderSkipsTheChecksThatNeedItButKeepsTheNameChecks() {
        // Empty `existing` means "could not list the folder". Guessing either way would be worse than
        // checking what can be checked.
        let p = pairs([("a.txt", ""), ("b.txt", "fine.txt")])
        let problems = RenameBatchPlan.problems(in: p, existing: [])
        XCTAssertEqual(problems.count, 1)
        XCTAssertTrue(problems.first!.reason.contains("empty"), problems.first!.reason)
    }

    // MARK: - The table the user agrees to

    func testTheTableShowsThePairingAndSkipsNoOps() {
        let text = RenameBatchPlan.table(pairs([("a.txt", "1.txt"), ("keep.txt", "keep.txt")]))
        XCTAssertTrue(text.contains("a.txt"), text)
        XCTAssertTrue(text.contains("1.txt"), text)
        XCTAssertFalse(text.contains("keep.txt"), text)
        XCTAssertTrue(text.contains("1 file"), text)
    }

    func testALongTableIsCappedAndSaysHowMuchItDropped() {
        // A confirmation nobody reads is not a confirmation; the dropped rows are stated rather than
        // silently missing.
        let many = (1...50).map { ("old\($0)", "new\($0)") }
        let text = RenameBatchPlan.table(pairs(many), limit: 10)
        XCTAssertTrue(text.contains("50 file(s)"), text)
        XCTAssertTrue(text.contains("and 40 more"), text)
        XCTAssertFalse(text.contains("old50"), text)
    }
}
