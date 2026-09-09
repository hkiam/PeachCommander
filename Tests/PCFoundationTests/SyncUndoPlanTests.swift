// SPDX-License-Identifier: Apache-2.0
// SyncUndoPlanTests.swift - Every refusal, named.
//
// A put-back is the safe direction — the worst a wrong guard does is leave a file the user wanted
// gone — with one exception that is not safe at all: putting something back **over** whatever is at
// that path now would be a deletion dressed as a recovery. That one has its own test and its own
// negative control.
//
// The probe is injected, so the whole matrix runs without a temporary file. `SyncPlanGuard` takes
// its scopes as values for the same reason.

import XCTest
import PCFoundation

final class SyncUndoPlanTests: XCTestCase {

    private let leftRoot = "/left"
    private let rightRoot = "/right"

    private func header(version: Int = SyncRunHeader.currentVersion,
                        itemsListed: Bool = true,
                        itemsOmittedReason: String? = nil,
                        undoUnavailable: String? = nil,
                        leftInode: UInt64? = 11, rightInode: UInt64? = 22) -> SyncRunHeader {
        SyncRunHeader(version: version, runAt: 1_700_000_000,
                      leftRoot: leftRoot, rightRoot: rightRoot,
                      leftRootInode: leftInode, rightRootInode: rightInode,
                      mode: "mirror", itemsListed: itemsListed,
                      itemsOmittedReason: itemsOmittedReason,
                      undoUnavailable: undoUnavailable)
    }

    private func deletion(_ path: String, side: String = "localDir", toTrash: Bool = true,
                          trashedPath: String? = nil, destination: String? = nil,
                          undoneAt: Double? = nil) -> SyncRunItem {
        SyncRunItem(relativePath: path, action: "deleteRight", basis: "comparison",
                    outcome: SyncRunItem.Outcome.deleted,
                    destinationPath: destination ?? "/right/" + path,
                    destinationSide: side, toTrash: toTrash,
                    trashedPath: trashedPath ?? "/Users/x/.Trash/" + (path as NSString).lastPathComponent,
                    undoneAt: undoneAt)
    }

    /// A world where the roots are there and the Trash holds what the record says it holds. Anything
    /// not named is absent, which is what makes each test's own fixture the only thing in play.
    private func world(_ present: [String: SyncUndoFacts] = [:]) -> (String) -> SyncUndoFacts {
        var facts: [String: SyncUndoFacts] = [
            leftRoot: SyncUndoFacts(exists: true, isDirectory: true, inode: 11),
            rightRoot: SyncUndoFacts(exists: true, isDirectory: true, inode: 22),
        ]
        for (path, f) in present { facts[path] = f }
        return { facts[$0] ?? .absent }
    }

    private func inTrash(_ name: String) -> (String, SyncUndoFacts) {
        ("/Users/x/.Trash/" + name, SyncUndoFacts(exists: true, size: 5, modifiedUnix: 1, inode: 99))
    }

    // MARK: - The happy path

    func test_aTrashedDeletionIsPutBackWhereItCameFrom() {
        let (trashPath, facts) = inTrash("gone.txt")
        let (steps, refusals) = SyncUndoPlan.plan(header: header(),
                                                  items: [deletion("gone.txt")],
                                                  probe: world([trashPath: facts]))
        XCTAssertTrue(refusals.isEmpty, "\(refusals)")
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps[0].from, trashPath)
        XCTAssertEqual(steps[0].to, "/right/gone.txt")
        XCTAssertEqual(steps[0].relativePath, "gone.txt")
    }

    /// A copy, a refusal and a failure produce neither a step nor a refusal. Nothing was taken away,
    /// so nothing is owed back — and reporting them would mean a page of "this was a copy" after
    /// every ordinary run.
    func test_rowsThatDeletedNothingAreSilent() {
        let rows = [
            SyncRunItem(relativePath: "a.txt", action: "copyToRight", basis: "comparison",
                        outcome: SyncRunItem.Outcome.copied, destinationPath: "/right/a.txt",
                        destinationSide: "localDir", created: true),
            SyncRunItem(relativePath: "b", action: "deleteRight", basis: "comparison",
                        outcome: SyncRunItem.Outcome.refused, reason: "kept: something"),
            SyncRunItem(relativePath: "c.txt", action: "deleteRight", basis: "comparison",
                        outcome: SyncRunItem.Outcome.failed, reason: "Permission denied"),
        ]
        let (steps, refusals) = SyncUndoPlan.plan(header: header(), items: rows, probe: world())
        XCTAssertTrue(steps.isEmpty)
        XCTAssertTrue(refusals.isEmpty, "\(refusals)")
    }

    // MARK: - Refusals about the whole run

    func test_aNewerRecordIsRefusedWhole() {
        let (steps, refusals) = SyncUndoPlan.plan(header: header(version: 99),
                                                  items: [deletion("gone.txt")], probe: world())
        XCTAssertTrue(steps.isEmpty)
        XCTAssertEqual(refusals.map(\.subject), [SyncUndoPlan.Refusal.wholeRun])
        XCTAssertTrue(refusals[0].reason.contains("newer version"), refusals[0].reason)
    }

    /// A run whose rows were left out is **still usable**, and this is the assertion that had it
    /// backwards. Above the item cap the store drops the plain copies and keeps every deletion —
    /// and a copy is never put back anyway — so refusing the whole record took away an offer that
    /// was there. `itemsListed` says the record is incomplete; it does not say it is useless.
    func test_aRunWhoseCopiesWereNotKeptCanStillPutItsDeletionsBack() {
        let (trashPath, facts) = inTrash("gone.txt")
        let (steps, refusals) = SyncUndoPlan.plan(
            header: header(itemsListed: false,
                           itemsOmittedReason: "this run had 30000 items"),
            items: [deletion("gone.txt")], probe: world([trashPath: facts]))
        XCTAssertEqual(steps.map(\.relativePath), ["gone.txt"])
        XCTAssertTrue(refusals.isEmpty, "\(refusals)")
        XCTAssertTrue(SyncUndoPlan.hasCandidates(header: header(itemsListed: false,
                                                                itemsOmittedReason: "…"),
                                                 items: [deletion("gone.txt")]))
    }

    /// The header can already know: an archive was rewritten whole, a server kept nothing.
    func test_aRunTheRecordAlreadyCallsUnrecoverableIsRefusedWhole() {
        let (steps, refusals) = SyncUndoPlan.plan(
            header: header(undoUnavailable: "a server has no Trash"),
            items: [deletion("gone.txt")], probe: world())
        XCTAssertTrue(steps.isEmpty)
        XCTAssertEqual(refusals.count, 1)
    }

    /// The folder is not there any anymore. An absolute path in a file is only safe to act on while
    /// the folder it names is still there.
    func test_aMissingRootIsRefusedWhole() {
        let probe: (String) -> SyncUndoFacts = { path in
            path == "/right" ? SyncUndoFacts(exists: true, isDirectory: true, inode: 22) : .absent
        }
        let (steps, refusals) = SyncUndoPlan.plan(header: header(),
                                                  items: [deletion("gone.txt")], probe: probe)
        XCTAssertTrue(steps.isEmpty)
        XCTAssertTrue(refusals.contains { $0.reason.contains("left folder") }, "\(refusals)")
    }

    /// …and the folder that *is* there is a different one. `/Volumes/Backup` can be a different disk
    /// next week, which is what the recorded inode is for.
    func test_aRootWhoseInodeChangedIsRefusedWhole() {
        let (steps, refusals) = SyncUndoPlan.plan(
            header: header(),
            items: [deletion("gone.txt")],
            probe: world([rightRoot: SyncUndoFacts(exists: true, isDirectory: true, inode: 777)]))
        XCTAssertTrue(steps.isEmpty)
        XCTAssertTrue(refusals.contains { $0.reason.contains("not the one this run wrote to") },
                      "\(refusals)")
    }

    /// A record from before the inodes were written has none, and that must not refuse the run —
    /// every optional in this format is additive, and an absent field is not a mismatch.
    func test_aRecordWithoutRootInodesIsStillUsable() {
        let (trashPath, facts) = inTrash("gone.txt")
        let (steps, refusals) = SyncUndoPlan.plan(
            header: header(leftInode: nil, rightInode: nil),
            items: [deletion("gone.txt")], probe: world([trashPath: facts]))
        XCTAssertEqual(steps.count, 1)
        XCTAssertTrue(refusals.isEmpty, "\(refusals)")
    }

    // MARK: - Refusals about one item

    /// The one refusal whose failure would destroy something. Whatever is at that path now was not
    /// put there by this run.
    func test_anOccupiedOriginalPathIsRefusedAndNotOverwritten() {
        let (trashPath, facts) = inTrash("gone.txt")
        let (steps, refusals) = SyncUndoPlan.plan(
            header: header(), items: [deletion("gone.txt")],
            probe: world([trashPath: facts,
                          "/right/gone.txt": SyncUndoFacts(exists: true, size: 1, inode: 500)]))
        XCTAssertTrue(steps.isEmpty, "it would have written over the file that is there")
        XCTAssertEqual(refusals.map(\.subject), ["gone.txt"])
        XCTAssertTrue(refusals[0].reason.contains("at that path again"), refusals[0].reason)
    }

    func test_anItemNoLongerInTheTrashIsRefused() {
        let (steps, refusals) = SyncUndoPlan.plan(header: header(),
                                                  items: [deletion("gone.txt")], probe: world())
        XCTAssertTrue(steps.isEmpty)
        XCTAssertTrue(refusals[0].reason.contains("no longer in the Trash"), refusals[0].reason)
    }

    func test_aPermanentRemovalIsRefused() {
        let (trashPath, facts) = inTrash("gone.txt")
        let (steps, refusals) = SyncUndoPlan.plan(
            header: header(), items: [deletion("gone.txt", toTrash: false)],
            probe: world([trashPath: facts]))
        XCTAssertTrue(steps.isEmpty)
        XCTAssertTrue(refusals[0].reason.contains("permanently"), refusals[0].reason)
    }

    func test_aDeletionWithNoRecordedTrashPathIsRefused() {
        var row = deletion("gone.txt")
        row.trashedPath = nil
        let (steps, refusals) = SyncUndoPlan.plan(header: header(), items: [row], probe: world())
        XCTAssertTrue(steps.isEmpty)
        XCTAssertTrue(refusals[0].reason.contains("where this went"), refusals[0].reason)
    }

    /// A zip and a server side, each named. Said per item rather than per run, because a run can
    /// have one local side and one that is not.
    func test_anArchiveOrServerSideIsRefusedPerItem() {
        for side in ["zip", "remote"] {
            let (trashPath, facts) = inTrash("gone.txt")
            let (steps, refusals) = SyncUndoPlan.plan(
                header: header(), items: [deletion("gone.txt", side: side)],
                probe: world([trashPath: facts]))
            XCTAssertTrue(steps.isEmpty, side)
            XCTAssertTrue(refusals[0].reason.contains(side), "\(side): \(refusals[0].reason)")
        }
    }

    /// Already put back. `markUndone` is what writes this, and it is what stops a second attempt
    /// from moving a file the run never deleted.
    func test_anItemAlreadyPutBackIsRefused() {
        let (trashPath, facts) = inTrash("gone.txt")
        var row = deletion("gone.txt", undoneAt: 1_700_000_500)
        row.undoUnavailable = "already put back"
        let (steps, refusals) = SyncUndoPlan.plan(header: header(), items: [row],
                                                  probe: world([trashPath: facts]))
        XCTAssertTrue(steps.isEmpty)
        XCTAssertEqual(refusals[0].reason, "already put back")
    }

    /// A recorded origin outside both roots is refused. The record is self-consistent about its own
    /// paths, so this is a check against a hand-edited or foreign file rather than a formality.
    func test_anOriginOutsideBothRootsIsRefused() {
        let (trashPath, facts) = inTrash("gone.txt")
        let (steps, refusals) = SyncUndoPlan.plan(
            header: header(),
            items: [deletion("gone.txt", destination: "/somewhere/else/gone.txt")],
            probe: world([trashPath: facts]))
        XCTAssertTrue(steps.isEmpty)
        XCTAssertTrue(refusals[0].reason.contains("outside both folders"), refusals[0].reason)
    }

    // MARK: - The cheap predicate

    /// `hasCandidates` and `plan` must agree about what the *record* rules out, and this is the test
    /// that keeps them agreeing. The predicate exists so that arming a button costs no `lstat` at
    /// all — a twenty-thousand-row run would otherwise have meant twenty thousand of them, on the
    /// main thread, every time a selection changed — and a predicate that drifts from the guard is
    /// how a button that can never do anything comes about.
    func test_theCheapPredicateAgreesWithThePlanOnEveryRecordOnlyRefusal() {
        let ruledOut: [SyncRunItem] = [
            deletion("permanent.txt", toTrash: false),
            deletion("zipped.txt", side: "zip"),
            deletion("served.txt", side: "remote"),
            deletion("done.txt", undoneAt: 1_700_000_500),
            {
                var row = deletion("nowhere.txt")
                row.trashedPath = nil
                return row
            }(),
            SyncRunItem(relativePath: "copy.txt", action: "copyToRight", basis: "comparison",
                        outcome: SyncRunItem.Outcome.copied, destinationPath: "/right/copy.txt",
                        destinationSide: "localDir", created: true),
        ]
        for row in ruledOut {
            XCTAssertFalse(SyncUndoPlan.hasCandidates(header: header(), items: [row]),
                           "\(row.relativePath) was offered although the record rules it out")
            // …and the full guard produces no step for it either, whatever the disk says.
            let (steps, _) = SyncUndoPlan.plan(
                header: header(), items: [row],
                probe: world([inTrash("nowhere.txt").0: inTrash("nowhere.txt").1,
                              inTrash("permanent.txt").0: inTrash("permanent.txt").1,
                              inTrash("zipped.txt").0: inTrash("zipped.txt").1,
                              inTrash("served.txt").0: inTrash("served.txt").1,
                              inTrash("done.txt").0: inTrash("done.txt").1,
                              inTrash("copy.txt").0: inTrash("copy.txt").1]))
            XCTAssertTrue(steps.isEmpty, "\(row.relativePath) produced a step")
        }
        // The one that is allowed by the record — and note what this proves and does not: the
        // predicate says yes here **without** the file being in the Trash, which is exactly its
        // weakness and the reason a press still asks the disk.
        XCTAssertTrue(SyncUndoPlan.hasCandidates(header: header(),
                                                 items: [deletion("gone.txt")]))
        let (steps, refusals) = SyncUndoPlan.plan(header: header(),
                                                  items: [deletion("gone.txt")], probe: world())
        XCTAssertTrue(steps.isEmpty, "the disk had no such file, so there is nothing to do")
        XCTAssertEqual(refusals.count, 1)
    }

    /// A whole-run refusal turns the predicate off too, without looking at a single row.
    func test_theCheapPredicateHonoursTheWholeRunRefusals() {
        let rows = [deletion("gone.txt")]
        XCTAssertFalse(SyncUndoPlan.hasCandidates(header: header(version: 99), items: rows))
        XCTAssertFalse(SyncUndoPlan.hasCandidates(
            header: header(undoUnavailable: "a server has no Trash"), items: rows))
        // But a missing root does **not**: that needs the filesystem, so the predicate cannot know
        // it and the press is where it is found. Stated so the difference stays deliberate.
        XCTAssertTrue(SyncUndoPlan.hasCandidates(header: header(), items: rows))
    }

    // MARK: - Ordering

    /// Shallowest first. Deletions ran deepest-first, so a child cannot land before its folder is
    /// back — `moveItem` does not create the parent, and the runner only creates one as a fallback.
    func test_stepsAreOrderedShallowestFirst() {
        let paths = ["a/b/c/deep.txt", "a", "a/b/mid.txt", "a/b"]
        var facts: [String: SyncUndoFacts] = [:]
        var rows: [SyncRunItem] = []
        for path in paths {
            let name = (path as NSString).lastPathComponent
            facts["/Users/x/.Trash/" + name] = SyncUndoFacts(exists: true, size: 1, inode: 1)
            rows.append(deletion(path))
        }
        let (steps, refusals) = SyncUndoPlan.plan(header: header(), items: rows,
                                                  probe: world(facts))
        XCTAssertTrue(refusals.isEmpty, "\(refusals)")
        let depths = steps.map { $0.relativePath.components(separatedBy: "/").count }
        XCTAssertEqual(depths, depths.sorted(),
                       "a child is put back before its folder: \(steps.map(\.relativePath))")
    }

    /// Every reason at once, `SyncPlanGuard`'s rule: one refusal at a time as the run discovers them
    /// means a dialog per problem.
    func test_everyItemReasonIsGivenAtOnce() {
        let (trashPath, facts) = inTrash("ok.txt")
        let rows = [deletion("ok.txt"),
                    deletion("permanent.txt", toTrash: false),
                    deletion("zipped.txt", side: "zip"),
                    deletion("emptied.txt")]
        let (steps, refusals) = SyncUndoPlan.plan(header: header(), items: rows,
                                                  probe: world([trashPath: facts]))
        XCTAssertEqual(steps.map(\.relativePath), ["ok.txt"])
        XCTAssertEqual(Set(refusals.map(\.subject)),
                       ["permanent.txt", "zipped.txt", "emptied.txt"])
    }
}
