// SPDX-License-Identifier: Apache-2.0
// SyncRunRecording.swift - The executor's report, in the terms a record is written in.
//
// Pure, and in this module rather than in the window, for two reasons that pull the same way. No
// test bundle imports `PCApp`, so anything decided in the window is untestable — the scar is written
// down at the top of `SyncEngine.swift`, where the code deciding what to copy once had no tests at
// all because it lived in the window. And the two DEBUG harness verbs that drive `SyncExecutor`
// directly can be given a record later with one line each, which they could not if the translation
// needed a window.
//
// No I/O here on purpose, including no `stat`: the roots' inodes are passed in. A function that
// reaches for the filesystem while translating a finished run would be answering a question about
// *now* in a record about *then*.
//
// What it must not do is take `SyncItemOutcomeSummary`, the shim the state record uses. That type
// folds `refused`, `failed`, `notAttempted` and `noOp` into one "nothing happened" case, which is
// right for a record of what the two sides look like and exactly wrong for a record of what a run
// did — those four are most of what somebody opens this to read.

import Foundation
import PCFoundation

public enum SyncRunRecording {

    /// Translate one finished run.
    ///
    /// - Parameters:
    ///   - plan: The rows that were carried out, with their `basis` — which is why `currentPlan()`
    ///     has to keep it. A propagated deletion reuses `.deleteLeft`/`.deleteRight`, so the action
    ///     value cannot say where the decision came from.
    ///   - scanned: What the comparison saw, for each row's kind. Indexed once: the window's state
    ///     writer looks this up with `items.first { … }` per outcome, which is quadratic, and doing
    ///     the same here would extend that cost to every mode.
    ///   - filterSummary: The filter in words, for a reader. Not for a decision — see
    ///     `SyncRunHeader.filterSummary`.
    public static func record(report: SyncRunReport,
                              plan: [SyncResult],
                              scanned: [SyncItem],
                              left: SyncSide, right: SyncSide,
                              options: SyncOptions,
                              fileMask: String, withSubdirs: Bool, ignoreHidden: Bool,
                              filterSummary: String? = nil,
                              leftRootInode: UInt64? = nil, rightRootInode: UInt64? = nil,
                              runAt: Date = Date()) -> (header: SyncRunHeader, items: [SyncRunItem]) {

        let basisOf = Dictionary(plan.map { ($0.item.relativePath, $0.basis) },
                                 uniquingKeysWith: { a, _ in a })
        let kindOf = Dictionary(scanned.map { ($0.relativePath, $0.isDirectory) },
                               uniquingKeysWith: { a, _ in a })

        var items: [SyncRunItem] = []
        items.reserveCapacity(report.outcomes.count)
        var copied = 0, created = 0, overwritten = 0, deleted = 0
        var refused = 0, failed = 0, notAttempted = 0, noOp = 0

        for outcome in report.outcomes {
            let rel = outcome.relativePath
            let (source, destination) = sides(for: outcome.action, left: left, right: right)
            var item = SyncRunItem(relativePath: rel,
                                   action: name(of: outcome.action),
                                   basis: name(of: basisOf[rel] ?? .comparison),
                                   outcome: "",
                                   sourcePath: source.map { path($0, rel) },
                                   destinationPath: destination.map { path($0, rel) },
                                   destinationSide: destination.map(kind(of:)),
                                   isDirectory: kindOf[rel])

            switch outcome.status {
            case .copied(let landed):
                item.outcome = SyncRunItem.Outcome.copied
                item.created = landed.existed.map { !$0 }
                item.destinationSize = landed.size
                item.destinationModifiedUnix = landed.modified?.timeIntervalSince1970
                copied += 1
                // Neither counter moves when the write could not say — an archive, a server, a
                // folder. Left to add up to less than `copied` rather than guessed at, since the
                // guess would be the scan's answer and that is the one that is wrong.
                if let existed = landed.existed { existed ? (overwritten += 1) : (created += 1) }
            case .deleted(let toTrash, let trashedPath):
                item.outcome = SyncRunItem.Outcome.deleted
                item.toTrash = toTrash
                item.trashedPath = trashedPath
                deleted += 1
            case .refused(let reason):
                item.outcome = SyncRunItem.Outcome.refused
                item.reason = reason
                refused += 1
            case .failed(let message):
                item.outcome = SyncRunItem.Outcome.failed
                item.reason = message
                failed += 1
            case .notAttempted(let reason):
                item.outcome = SyncRunItem.Outcome.notAttempted
                item.reason = reason
                notAttempted += 1
            case .noOp(let reason):
                item.outcome = SyncRunItem.Outcome.noOp
                item.reason = reason
                noOp += 1
            }
            items.append(item)
        }

        let header = SyncRunHeader(
            runAt: runAt.timeIntervalSince1970,
            leftRoot: standardised(left.path), rightRoot: standardised(right.path),
            leftRootInode: leftRootInode, rightRootInode: rightRootInode,
            mode: name(of: options.mode), fileMask: fileMask, withSubdirs: withSubdirs,
            ignoreHidden: ignoreHidden, filterSummary: filterSummary, stopped: report.stopped,
            planned: report.outcomes.count, copied: copied, created: created,
            overwritten: overwritten, deleted: deleted, refused: refused, failed: failed,
            notAttempted: notAttempted, noOp: noOp,
            undoUnavailable: unavailableReason(left: left, right: right))
        return (header, items)
    }

    /// Why nothing in this run can be put back, when the sides alone settle it.
    ///
    /// In `AuditInverse.unavailableReason`'s voice, and stated once at the run rather than repeated
    /// on every row: an archive was rewritten whole and re-stamped in the process, so a second
    /// rewrite would not restore it, and a server has no Trash, so nothing there was kept at all.
    static func unavailableReason(left: SyncSide, right: SyncSide) -> String? {
        if left.isZip || right.isZip {
            return "an archive is rewritten whole, and the rewrite re-stamps every entry in it"
        }
        if left.isRemote || right.isRemote {
            return "a server has no Trash, so what was deleted there was not kept"
        }
        return nil
    }

    /// Which side a row reads from and which it changes. A copy reads from one and writes the other;
    /// a deletion only changes one, and has no source at all — the whole point of the row is that
    /// the file is not on the other side any more.
    private static func sides(for action: SyncAction, left: SyncSide,
                              right: SyncSide) -> (SyncSide?, SyncSide?) {
        switch action {
        case .copyToRight: return (left, right)
        case .copyToLeft: return (right, left)
        case .deleteRight: return (nil, right)
        case .deleteLeft: return (nil, left)
        case .equal, .conflict, .none: return (nil, nil)
        }
    }

    private static func path(_ side: SyncSide, _ rel: String) -> String {
        (side.path as NSString).appendingPathComponent(rel)
    }

    private static func kind(of side: SyncSide) -> String {
        if side.isZip { return "zip" }
        if side.isRemote { return "remote" }
        return "localDir"
    }

    private static func standardised(_ path: String) -> String {
        (path as NSString).standardizingPath.precomposedStringWithCanonicalMapping
    }

    private static func name(of action: SyncAction) -> String {
        switch action {
        case .copyToRight: return "copyToRight"
        case .copyToLeft: return "copyToLeft"
        case .deleteRight: return "deleteRight"
        case .deleteLeft: return "deleteLeft"
        case .equal: return "equal"
        case .conflict: return "conflict"
        case .none: return "none"
        }
    }

    private static func name(of basis: SyncBasis) -> String {
        switch basis {
        case .comparison: return "comparison"
        case .propagatedDeletion: return "propagatedDeletion"
        case .stateConflict: return "stateConflict"
        }
    }

    private static func name(of mode: SyncOptions.Mode) -> String {
        switch mode {
        case .symmetric: return "symmetric"
        case .mirror: return "mirror"
        case .twoWay: return "twoWay"
        }
    }
}
