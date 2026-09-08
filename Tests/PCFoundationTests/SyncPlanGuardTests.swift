// SPDX-License-Identifier: Apache-2.0
// SyncPlanGuardTests.swift - Refusing a synchronisation plan whose deletions cannot be justified.
//
// The case each of these is built around: there is no undo for a delete anywhere in this app, so a
// deletion the comparison cannot stand behind must not be offered at all.

import XCTest
@testable import PCFoundation

final class SyncPlanGuardTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func reliable(entries: Int = 5, filtered: Set<String> = [],
                          incomplete: Set<String> = []) -> SyncSideScope {
        SyncSideScope(rootEnumerable: true, rootObservedNonEmpty: entries > 0,
                      entriesFound: entries, entriesVisited: entries,
                      filtered: filtered, incompleteDirs: incomplete)
    }

    private func unreadable() -> SyncSideScope {
        SyncSideScope(rootEnumerable: false, rootObservedNonEmpty: true, entriesFound: 0,
                      entriesVisited: 0, filtered: [], incompleteDirs: [])
    }

    private func delete(_ rel: String, right: Bool = true) -> SyncResult {
        SyncResult(action: right ? .deleteRight : .deleteLeft,
                   item: SyncItem(relativePath: rel, isDirectory: false,
                                  leftSize: right ? nil : 1, leftModified: right ? nil : t0,
                                  rightSize: right ? 1 : nil, rightModified: right ? t0 : nil))
    }

    private func copyRow(_ rel: String) -> SyncResult {
        SyncResult(action: .copyToRight,
                   item: SyncItem(relativePath: rel, isDirectory: false,
                                  leftSize: 1, leftModified: t0, rightSize: nil, rightModified: nil))
    }

    // MARK: - A deletion needs the opposite side to stand behind it

    /// The live defect this guard exists for: mirror mode with a left root that cannot be read
    /// classifies every file on the right as "delete it". The plan must be refused, and the reason
    /// has to name the side so the reader knows which path field to look at.
    func test_deletionsAreRefusedWhenTheOppositeRootCouldNotBeRead() {
        let plan = (1...20).map { delete("f\($0).txt") }
        let refusals = SyncPlanGuard.refusals(plan: plan, leftScope: unreadable(),
                                              rightScope: reliable(entries: 20),
                                              roots: .distinct)
        XCTAssertTrue(refusals.contains { $0.subject == "(the left side)" },
                      "a plan that deletes on the strength of an unreadable side was allowed")
        XCTAssertTrue(refusals.contains { $0.reason.contains("could not be read at all") },
                      "the reason did not say what was wrong: \(refusals.map(\.reason))")
    }

    /// And the other direction, so the two sides are not confused. `.deleteLeft` rests on the
    /// *right* walk.
    func test_theSideThatHasToStandBehindADeletionIsTheOppositeOne() {
        let plan = (1...20).map { delete("f\($0).txt", right: false) }
        let refusals = SyncPlanGuard.refusals(plan: plan, leftScope: reliable(entries: 20),
                                              rightScope: unreadable(), roots: .distinct)
        XCTAssertTrue(refusals.contains { $0.subject == "(the right side)" })
        // With the roles swapped the same plan is fine.
        let ok = SyncPlanGuard.refusals(plan: plan, leftScope: unreadable(),
                                        rightScope: reliable(entries: 20), roots: .distinct)
        XCTAssertFalse(ok.contains { $0.subject == "(the right side)" },
                       "the guard asked the wrong side")
    }

    /// A folder the filter cut the descent off at cannot prove anything about what was under it —
    /// so a deletion for a path beneath it is refused, while one elsewhere is not.
    func test_aDeletionUnderAHeldBackFolderIsRefusedAndOneElsewhereIsNot() {
        let scope = reliable(entries: 40, filtered: ["build"])
        let under = SyncPlanGuard.refusals(plan: [delete("build/app.o")], leftScope: scope,
                                           rightScope: reliable(), roots: .distinct)
        XCTAssertEqual(under.count, 1)
        XCTAssertTrue(under[0].reason.contains("did not look at"), under[0].reason)

        let elsewhere = SyncPlanGuard.refusals(plan: [delete("notes.txt")], leftScope: scope,
                                               rightScope: reliable(), roots: .distinct)
        XCTAssertEqual(elsewhere, [], "a deletion the walk can stand behind was refused")
    }

    /// Thousands of unprovable deletions are one refusal with a number, not thousands of sentences.
    func test_manyUnprovableDeletionsAreOneRefusalWithACount() {
        let plan = (1...500).map { delete("f\($0).txt") }
        let refusals = SyncPlanGuard.refusals(plan: plan, leftScope: unreadable(),
                                              rightScope: reliable(entries: 500), roots: .distinct)
        XCTAssertLessThanOrEqual(refusals.count, 2, "one refusal per path: \(refusals.count)")
        XCTAssertTrue(refusals.contains { $0.reason.contains("500 deletion(s)") },
                      refusals.map(\.reason).joined(separator: " | "))
    }

    /// An ordinary run is not refused. This is the test that keeps the guard from being a nuisance:
    /// a plan of copies and a couple of well-founded deletions goes through untouched.
    func test_anOrdinaryPlanIsNotRefused() {
        let plan = (1...30).map { copyRow("c\($0).txt") } + [delete("gone.txt")]
        XCTAssertEqual(SyncPlanGuard.refusals(plan: plan, leftScope: reliable(entries: 31),
                                              rightScope: reliable(entries: 31),
                                              roots: .distinct), [])
    }

    /// A plan with no deletions at all is never refused for a deletion reason, even when a side is
    /// unreadable — a copy from a side that could be read is not endangered by the other one.
    func test_aPlanWithoutDeletionsIsNotJudgedOnTheScopes() {
        let plan = (1...5).map { copyRow("c\($0).txt") }
        XCTAssertEqual(SyncPlanGuard.refusals(plan: plan, leftScope: reliable(),
                                              rightScope: unreadable(), roots: .distinct), [])
    }

    // MARK: - The roots

    func test_thePlanIsRefusedWhenBothSidesAreTheSameFolder() {
        let refusals = SyncPlanGuard.refusals(plan: [copyRow("a.txt")], leftScope: reliable(),
                                              rightScope: reliable(), roots: .same)
        XCTAssertEqual(refusals.map(\.reason), ["both sides are the same folder"])
    }

    func test_thePlanIsRefusedWhenOneSideIsInsideTheOther() {
        let refusals = SyncPlanGuard.refusals(plan: [copyRow("a.txt")], leftScope: reliable(),
                                              rightScope: reliable(), roots: .nested)
        XCTAssertEqual(refusals.map(\.reason), ["one side is inside the other"])
    }

    // MARK: - The volume

    /// Measured against the entries the *previous run* knew, not against the plan's own length: a
    /// run that also copies a thousand files would otherwise dilute the share until the guard
    /// stopped firing. Both calls here have the same 200 deletions.
    func test_theShareIsMeasuredAgainstTheKnownEntriesAndNotThePlanLength() {
        let deletions = (1...200).map { delete("d\($0).txt") }
        let copies = (1...1000).map { copyRow("c\($0).txt") }
        let scope = reliable(entries: 1200)

        // Against the plan's own 1200 rows, 200 deletions are 17 % and pass.
        XCTAssertEqual(SyncPlanGuard.refusals(plan: deletions + copies, leftScope: scope,
                                              rightScope: scope, roots: .distinct), [])
        // Against the 250 entries the last run actually knew, they are 80 % and do not.
        let refusals = SyncPlanGuard.refusals(plan: deletions + copies, leftScope: scope,
                                              rightScope: scope, roots: .distinct,
                                              knownEntries: 250)
        XCTAssertTrue(refusals.contains { $0.reason.contains("200 of 250") },
                      refusals.map(\.reason).joined(separator: " | "))
    }

    /// The floor, which is what keeps this from firing on every run of a small pair. Two deletions
    /// out of three entries is 67 % and must go through, or the warning becomes one people click
    /// past without reading.
    func test_aSmallPairBelowTheFloorIsNotRefused() {
        let plan = [delete("a.txt"), delete("b.txt")]
        XCTAssertEqual(SyncPlanGuard.refusals(plan: plan, leftScope: reliable(entries: 3),
                                              rightScope: reliable(entries: 3),
                                              roots: .distinct, knownEntries: 3), [])
    }

    /// And above the floor the share decides. Eleven of twelve is over both.
    func test_aboveTheFloorSheerVolumeIsRefused() {
        let plan = (1...11).map { delete("d\($0).txt") }
        let refusals = SyncPlanGuard.refusals(plan: plan, leftScope: reliable(entries: 12),
                                              rightScope: reliable(entries: 12),
                                              roots: .distinct, knownEntries: 12)
        XCTAssertTrue(refusals.contains { $0.reason.contains("11 of 12") },
                      refusals.map(\.reason).joined(separator: " | "))
    }

    /// Every reason at once, the way `RenameBatchPlan` reports: a caller that fixes the first
    /// complaint should not have to run again to discover the second.
    func test_everyReasonIsReportedAtOnce() {
        let plan = (1...20).map { delete("d\($0).txt") }
        let refusals = SyncPlanGuard.refusals(plan: plan, leftScope: unreadable(),
                                              rightScope: reliable(entries: 20),
                                              roots: .nested, knownEntries: 20)
        XCTAssertGreaterThanOrEqual(refusals.count, 3,
                                    "only \(refusals.count): \(refusals.map(\.reason))")
        XCTAssertTrue(refusals.contains { $0.reason.contains("inside the other") })
        XCTAssertTrue(refusals.contains { $0.reason.contains("could not be read") })
        XCTAssertTrue(refusals.contains { $0.reason.contains("20 of 20") })
    }

    /// A side that was read but came back empty over a folder that is not empty has its own reason,
    /// because it points somewhere different: not at the path, at a permission part-way down.
    func test_aSideThatFoundNothingInANonEmptyFolderSaysSo() {
        let odd = SyncSideScope(rootEnumerable: true, rootObservedNonEmpty: true, entriesFound: 0,
                                entriesVisited: 0, filtered: [], incompleteDirs: [])
        let refusals = SyncPlanGuard.refusals(plan: [delete("a.txt")], leftScope: odd,
                                              rightScope: reliable(), roots: .distinct)
        XCTAssertTrue(refusals.contains { $0.reason.contains("although it is not empty") },
                      refusals.map(\.reason).joined(separator: " | "))
    }

    /// A caller that has no scopes at all — a `SyncScanOutcome` built without them — gets every
    /// deletion refused rather than every deletion allowed.
    func test_anUnknownScopeRefusesRatherThanAllows() {
        let refusals = SyncPlanGuard.refusals(plan: [delete("a.txt")], leftScope: .unknown,
                                              rightScope: .unknown, roots: .distinct)
        XCTAssertFalse(refusals.isEmpty, "no scope was read as a good scope")
    }
}
