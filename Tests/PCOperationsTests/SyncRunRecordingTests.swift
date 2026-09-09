// SPDX-License-Identifier: Apache-2.0
// SyncRunRecordingTests.swift - The report, translated without losing anything.
//
// One invariant carries most of the weight: exactly one record row per outcome. The executor already
// guarantees one outcome per planned row, and that guarantee is worth nothing if the layer that
// writes it down folds cases together — which is precisely what the *state* record's shim does, and
// why it is not used here.

import XCTest
@testable import PCOperations
import PCFoundation

final class SyncRunRecordingTests: XCTestCase {

    private let left = SyncSide.localDir("/left")
    private let right = SyncSide.localDir("/right")

    private func item(_ path: String, isDirectory: Bool = false) -> SyncItem {
        SyncItem(relativePath: path, isDirectory: isDirectory,
                 leftSize: 3, leftModified: Date(timeIntervalSince1970: 1),
                 rightSize: nil, rightModified: nil)
    }

    private func outcome(_ path: String, _ action: SyncAction,
                         _ status: SyncStatus) -> SyncItemOutcome {
        SyncItemOutcome(relativePath: path, action: action, status: status)
    }

    /// One row per outcome, whatever the outcome was — including the four that the state record's
    /// shim collapses into "nothing happened". Those four are most of what a person opens this
    /// record to read.
    func test_everyOutcomeBecomesExactlyOneRow() {
        let statuses: [SyncStatus] = [
            .copied(CopiedDestination(size: 3, modified: Date(timeIntervalSince1970: 2),
                                      existed: false)),
            .deleted(toTrash: true, trashedPath: "/Users/x/.Trash/b.txt"),
            .refused(reason: "kept: it holds something this comparison did not include"),
            .failed(message: "Permission denied"),
            .notAttempted(reason: "staged for the archive rewrite"),
            .noOp(reason: "a folder is implicit in its members' paths inside an archive"),
        ]
        let outcomes = statuses.enumerated().map {
            outcome("f\($0.offset).txt", .copyToRight, $0.element)
        }
        let plan = outcomes.map { SyncResult(action: $0.action, item: item($0.relativePath)) }
        let report = SyncRunReport(outcomes: outcomes, stopped: false)

        let (header, rows) = SyncRunRecording.record(
            report: report, plan: plan, scanned: plan.map(\.item),
            left: left, right: right, options: SyncOptions(),
            fileMask: "*.*", withSubdirs: true, ignoreHidden: false)

        XCTAssertEqual(rows.count, outcomes.count)
        XCTAssertEqual(rows.map(\.relativePath), outcomes.map(\.relativePath),
                       "the rows are not in the order the run carried them out")
        XCTAssertEqual(rows.map(\.outcome), ["copied", "deleted", "refused", "failed",
                                             "notAttempted", "noOp"])
        // The counts describe the same set: everything is in exactly one bucket.
        XCTAssertEqual(header.planned, 6)
        XCTAssertEqual(header.copied + header.deleted + header.refused + header.failed
                        + header.notAttempted + header.noOp, header.planned,
                       "the header's counts do not account for every row")
        XCTAssertEqual(header.problems, 3)
    }

    /// A refusal and a failure keep their words. Diagnostic only — the field's own comment says
    /// nothing may branch on it, because a failure's text is `localizedDescription`.
    func test_aRefusalAndAFailureKeepTheirReason() {
        let outcomes = [outcome("a.txt", .deleteRight, .refused(reason: "kept: something")),
                        outcome("b.txt", .copyToRight, .failed(message: "Permission denied"))]
        let plan = outcomes.map { SyncResult(action: $0.action, item: item($0.relativePath)) }
        let (_, rows) = SyncRunRecording.record(
            report: SyncRunReport(outcomes: outcomes, stopped: false), plan: plan,
            scanned: plan.map(\.item), left: left, right: right, options: SyncOptions(),
            fileMask: "", withSubdirs: true, ignoreHidden: false)
        XCTAssertEqual(rows[0].reason, "kept: something")
        XCTAssertEqual(rows[1].reason, "Permission denied")
    }

    /// `created` is the write's answer, inverted from `existed`, and it is **nil** where the write
    /// could not answer — an archive, a server, a folder. Nil rather than false, because false is a
    /// claim and this is the absence of one; a later undo trusts this field to decide whether
    /// removing a file would take back something that was never there.
    func test_createdComesFromTheWriteAndIsAbsentWhenTheWriteCouldNotSay() {
        let outcomes = [
            outcome("fresh.txt", .copyToRight, .copied(CopiedDestination(size: 1, existed: false))),
            outcome("over.txt", .copyToRight, .copied(CopiedDestination(size: 1, existed: true))),
            outcome("dunno.txt", .copyToRight, .copied(CopiedDestination(size: 1))),
        ]
        let plan = outcomes.map { SyncResult(action: $0.action, item: item($0.relativePath)) }
        let (header, rows) = SyncRunRecording.record(
            report: SyncRunReport(outcomes: outcomes, stopped: false), plan: plan,
            scanned: plan.map(\.item), left: left, right: right, options: SyncOptions(),
            fileMask: "", withSubdirs: true, ignoreHidden: false)

        XCTAssertEqual(rows.map(\.created), [true, false, nil])
        XCTAssertEqual(header.copied, 3)
        XCTAssertEqual(header.created, 1)
        XCTAssertEqual(header.overwritten, 1)
        // …and they are allowed not to add up to `copied`, which is the honest arithmetic here.
        XCTAssertEqual(header.created + header.overwritten, 2)
    }

    /// The basis is carried, not derived. A propagated deletion reuses the ordinary delete action on
    /// purpose, so a record that read the basis off the action would call the app's own decision the
    /// other folder's.
    ///
    /// **Both rows use the same action on the same side**, and that is the whole design of this
    /// test. Written first with `deleteLeft` for the carried-over row and `deleteRight` for the
    /// mirror's, it passed with the basis inferred from the action — measured — because that fixture
    /// happened to make the wrong rule produce the right answer. Two rows that differ only in their
    /// basis cannot be told apart by anything but the basis.
    func test_theBasisIsCarriedRatherThanInferredFromTheAction() {
        let outcomes = [outcome("carried.txt", .deleteRight, .deleted(toTrash: true,
                                                                      trashedPath: "/t/carried.txt")),
                        outcome("mirrored.txt", .deleteRight, .deleted(toTrash: true,
                                                                       trashedPath: "/t/m.txt")),
                        outcome("asked.txt", .deleteRight, .deleted(toTrash: true,
                                                                    trashedPath: "/t/a.txt"))]
        let plan = [SyncResult(action: .deleteRight, item: item("carried.txt"),
                               basis: .propagatedDeletion),
                    SyncResult(action: .deleteRight, item: item("mirrored.txt")),
                    SyncResult(action: .deleteRight, item: item("asked.txt"),
                               basis: .stateConflict)]
        let (_, rows) = SyncRunRecording.record(
            report: SyncRunReport(outcomes: outcomes, stopped: false), plan: plan,
            scanned: plan.map(\.item), left: left, right: right, options: SyncOptions(),
            fileMask: "", withSubdirs: true, ignoreHidden: false)

        XCTAssertEqual(rows.map(\.basis),
                       ["propagatedDeletion", "comparison", "stateConflict"],
                       "three identical actions produced one basis, so it was inferred")
    }

    /// Both absolute paths, and the right way round for each direction. A record that named the
    /// source where the destination belongs would send a later reveal — or a later undo — at the
    /// file the user still has.
    func test_theAbsolutePathsAreRightInBothDirections() {
        let outcomes = [outcome("a/one.txt", .copyToRight, .copied(CopiedDestination(size: 1))),
                        outcome("b/two.txt", .copyToLeft, .copied(CopiedDestination(size: 1))),
                        outcome("c/three.txt", .deleteRight, .deleted(toTrash: false,
                                                                      trashedPath: nil))]
        let plan = outcomes.map { SyncResult(action: $0.action, item: item($0.relativePath)) }
        let (_, rows) = SyncRunRecording.record(
            report: SyncRunReport(outcomes: outcomes, stopped: false), plan: plan,
            scanned: plan.map(\.item), left: left, right: right, options: SyncOptions(),
            fileMask: "", withSubdirs: true, ignoreHidden: false)

        XCTAssertEqual(rows[0].sourcePath, "/left/a/one.txt")
        XCTAssertEqual(rows[0].destinationPath, "/right/a/one.txt")
        XCTAssertEqual(rows[1].sourcePath, "/right/b/two.txt")
        XCTAssertEqual(rows[1].destinationPath, "/left/b/two.txt")
        // A deletion has no source: the whole point of the row is that the file is not on the other
        // side any more.
        XCTAssertNil(rows[2].sourcePath)
        XCTAssertEqual(rows[2].destinationPath, "/right/c/three.txt")
        XCTAssertEqual(rows.map(\.destinationSide), ["localDir", "localDir", "localDir"])
    }

    /// Every path in a record is inside the root the same record names.
    ///
    /// Found by running the real thing, not by a unit test: the header standardised the roots while
    /// the rows appended to the raw side paths, so a run under `/private/tmp/…` recorded
    /// `left=/tmp/…` against `dest=/private/tmp/…`. Both name the same folder and neither is wrong
    /// alone — but no row is then lexically inside its own recorded root, and a containment check
    /// would refuse every item of every run under a symlinked prefix. An offer to act on this record
    /// can rest on nothing but its own consistency.
    ///
    /// The directories are **really created**, and that is not decoration. Written first against
    /// invented paths, this test passed with the defect put back — measured — because
    /// `NSString.standardizingPath` rewrites `/private/tmp/x` to `/tmp/x` only for a path that
    /// exists. An invented prefix standardises to itself, so both spellings agreed and there was
    /// nothing to catch.
    func test_everyPathIsInsideTheRootTheRecordNames() throws {
        let fm = FileManager.default
        let base = URL(fileURLWithPath: "/private/tmp")
            .appendingPathComponent("pc-runrec-\(UUID().uuidString)")
        let leftDir = base.appendingPathComponent("l")
        let rightDir = base.appendingPathComponent("r")
        for dir in [leftDir, rightDir] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        defer { try? fm.removeItem(at: base) }
        XCTAssertNotEqual((leftDir.path as NSString).standardizingPath, leftDir.path,
                          "this machine does not rewrite /private/tmp, so the fixture proves nothing")

        let outcomes = [outcome("a/one.txt", .copyToRight, .copied(CopiedDestination(size: 1))),
                        outcome("b/two.txt", .copyToLeft, .copied(CopiedDestination(size: 1))),
                        outcome("c/three.txt", .deleteRight, .deleted(toTrash: true,
                                                                      trashedPath: "/t/x"))]
        let plan = outcomes.map { SyncResult(action: $0.action, item: item($0.relativePath)) }
        let (header, rows) = SyncRunRecording.record(
            report: SyncRunReport(outcomes: outcomes, stopped: false), plan: plan,
            scanned: plan.map(\.item), left: .localDir(leftDir.path),
            right: .localDir(rightDir.path), options: SyncOptions(),
            fileMask: "", withSubdirs: true, ignoreHidden: false)

        for row in rows {
            for path in [row.sourcePath, row.destinationPath].compactMap({ $0 }) {
                XCTAssertTrue(path.hasPrefix(header.leftRoot + "/")
                                || path.hasPrefix(header.rightRoot + "/"),
                              "\(path) is inside neither \(header.leftRoot) nor \(header.rightRoot)")
            }
        }
        // And still the right root for the right direction.
        XCTAssertEqual(rows[0].destinationPath, header.rightRoot + "/a/one.txt")
        XCTAssertEqual(rows[1].destinationPath, header.leftRoot + "/b/two.txt")
    }

    /// A zip or a server destination is named as such, so a reader is not offered a path on this
    /// machine that is not one — and the run says once, in the header, that nothing in it can be
    /// taken back.
    func test_anArchiveOrServerRunSaysNothingCanBeTakenBack() {
        let outcomes = [outcome("a.txt", .copyToRight, .notAttempted(reason: "staged"))]
        let plan = [SyncResult(action: .copyToRight, item: item("a.txt"))]
        func header(_ right: SyncSide) -> SyncRunHeader {
            SyncRunRecording.record(report: SyncRunReport(outcomes: outcomes, stopped: false),
                                    plan: plan, scanned: plan.map(\.item), left: left, right: right,
                                    options: SyncOptions(), fileMask: "", withSubdirs: true,
                                    ignoreHidden: false).header
        }
        XCTAssertTrue(header(.zip("/a.zip")).undoUnavailable?.contains("archive") ?? false)
        XCTAssertNil(header(right).undoUnavailable, "a local run was declared un-undoable")

        let (_, rows) = SyncRunRecording.record(
            report: SyncRunReport(outcomes: outcomes, stopped: false), plan: plan,
            scanned: plan.map(\.item), left: left, right: .zip("/a.zip"),
            options: SyncOptions(), fileMask: "", withSubdirs: true, ignoreHidden: false)
        XCTAssertEqual(rows[0].destinationSide, "zip")
    }

    /// The mode as a word, from `SyncOptions.mode` and not from the raw flags — including the
    /// malformed `asymmetric && twoWay`, which that property deliberately reads as the one mode that
    /// never deletes.
    func test_theModeIsTakenFromTheResolvedOptions() {
        func mode(asymmetric: Bool, twoWay: Bool) -> String {
            var options = SyncOptions()
            options.asymmetric = asymmetric
            options.twoWay = twoWay
            return SyncRunRecording.record(report: SyncRunReport(outcomes: [], stopped: false),
                                           plan: [], scanned: [], left: left, right: right,
                                           options: options, fileMask: "", withSubdirs: true,
                                           ignoreHidden: false).header.mode
        }
        XCTAssertEqual(mode(asymmetric: false, twoWay: false), "symmetric")
        XCTAssertEqual(mode(asymmetric: true, twoWay: false), "mirror")
        XCTAssertEqual(mode(asymmetric: false, twoWay: true), "twoWay")
        XCTAssertEqual(mode(asymmetric: true, twoWay: true), "symmetric")
    }

    /// A cancelled run says so in its header, rather than leaving a reader to notice that the counts
    /// are smaller than they should be.
    func test_aStoppedRunSaysSo() {
        let (header, _) = SyncRunRecording.record(
            report: SyncRunReport(outcomes: [], stopped: true), plan: [], scanned: [],
            left: left, right: right, options: SyncOptions(), fileMask: "", withSubdirs: true,
            ignoreHidden: false)
        XCTAssertTrue(header.stopped)
    }
}
