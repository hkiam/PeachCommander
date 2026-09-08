// SPDX-License-Identifier: Apache-2.0
// SyncPlanGuard.swift - Saying no to a synchronisation plan before it is offered.
//
// The result grid shows every row and the user confirms the run, and for a copy that is enough: the
// worst a wrong row does is move a file that did not need moving. A *delete* row is different. There
// is no undo for a delete anywhere in this app — the operation-undo stack is fed by copy, move,
// rename and mkdir, and nothing else — so for a local side the only recovery is the Trash by hand in
// the Finder, and for a server or an archive there is none.
//
// So a plan whose deletions cannot be justified must not be *proposed*. That is the principle
// `DefaultAutomationCore.refusalBeforeAsking` writes down for the automation surface — a gated action
// that cannot work must not be offered — and the shape is `RenameBatchPlan`'s: refuse the whole thing
// and give every reason at once, rather than one refusal at a time as the run discovers them.
//
// A warning would not do. The synchronise confirmation's informative text is already the counts line
// plus the permanent-deletion sentence; a third clause in it is a sentence nobody reads.
//
// Everything here is pure. The two facts that need the filesystem — whether the roots are the same
// or nested, and what each walk was able to see — are established by the caller and passed in.

import Foundation

public enum SyncPlanGuard {

    /// One reason the plan was refused. `Error` so it can be the failure half of a `Result`; it is a
    /// description, not a thrown thing.
    public struct Refusal: Equatable, Sendable, Error {
        /// What the refusal is about — a path, a side, or `"(the plan)"` for the whole thing.
        public let subject: String
        public let reason: String
        public init(subject: String, reason: String) {
            self.subject = subject
            self.reason = reason
        }
    }

    /// How much deletion is too much to carry out without being asked again.
    ///
    /// Two parts, because either alone is useless. A share on its own fires on every ordinary run of
    /// a small pair — two deletions out of three entries is 67 % — and a warning that always fires is
    /// one that gets clicked through. A count on its own says nothing about a tree of ten thousand
    /// files, where fifty deletions are unremarkable and five thousand are a catastrophe.
    /// `ImplicitWorkBudget` is the precedent for a limit with more than one term.
    public struct Limits: Equatable, Sendable {
        /// The share of the known entries above which a plan is refused.
        public var deletionShare: Double
        /// Below this many deletions nothing is refused, whatever the share.
        public var deletionFloor: Int

        public init(deletionShare: Double, deletionFloor: Int) {
            self.deletionShare = deletionShare
            self.deletionFloor = deletionFloor
        }

        /// Half the known entries, and never for fewer than ten.
        ///
        /// Both numbers are judgements, not measurements, and they are here rather than spread over
        /// the call sites so there is one place to argue about them. Half is chosen because a
        /// legitimate mirror run that removes more than half of a tree is rare and worth a second
        /// look, while a tenth would fire on ordinary housekeeping.
        public static let standard = Limits(deletionShare: 0.5, deletionFloor: 10)
    }

    /// How the two roots relate on disk. Established by the caller, which has to stat them.
    public enum RootRelation: Sendable, Equatable {
        case distinct
        /// The same directory, by device and inode — not merely the same string.
        case same
        /// One contains the other.
        case nested
    }

    /// Everything wrong with this plan.
    ///
    /// - Parameters:
    ///   - plan: The rows that would actually run — already filtered by the include ticks. Passing
    ///     everything the comparison produced would refuse a copy-only run because of delete rows
    ///     the user had already unticked.
    ///   - knownEntries: How many paths the previous run recorded, when there is a state record.
    ///     The share is measured against *that*, not against the plan's own length: a run that also
    ///     copies a thousand files would otherwise dilute the share until the guard stopped firing.
    ///     Nil falls back to the plan's length, which is what today's stateless mirror has.
    public static func refusals(plan: [SyncResult],
                                leftScope: SyncSideScope,
                                rightScope: SyncSideScope,
                                roots: RootRelation,
                                knownEntries: Int? = nil,
                                limits: Limits = .standard) -> [Refusal] {
        var out: [Refusal] = []

        // The roots first: these refuse the plan whatever is in it, and a plan against a folder and
        // itself is not a comparison at all. `CopyEngine` refuses the same shape for a single copy
        // (`OperationError.sameFile`); the sync path had no equivalent.
        switch roots {
        case .same:
            out.append(Refusal(subject: "(the plan)",
                               reason: "both sides are the same folder"))
        case .nested:
            out.append(Refusal(subject: "(the plan)",
                               reason: "one side is inside the other"))
        case .distinct:
            break
        }

        let deletions = plan.filter { $0.action == .deleteRight || $0.action == .deleteLeft }
        guard !deletions.isEmpty else { return out }

        // Every deletion needs the *opposite* side to have proved the path is gone. `.deleteRight`
        // exists because the path is absent on the left, so it is the left walk that has to stand
        // behind it — and absence is only evidence if that walk ran and would have found it.
        //
        // Counted into one refusal rather than one per path: a wiped root produces a deletion for
        // every file on the other side, and ten thousand identical sentences are not a better
        // explanation than one with a number in it.
        var unprovenRight = 0, unprovenLeft = 0
        for row in deletions {
            let rel = row.item.relativePath
            if row.action == .deleteRight, !leftScope.provesAbsence(of: rel) { unprovenRight += 1 }
            if row.action == .deleteLeft, !rightScope.provesAbsence(of: rel) { unprovenLeft += 1 }
        }
        if unprovenRight > 0 {
            out.append(Refusal(subject: "(the left side)", reason: reason(for: leftScope,
                                                                         deletions: unprovenRight,
                                                                         deleteSide: "right")))
        }
        if unprovenLeft > 0 {
            out.append(Refusal(subject: "(the right side)", reason: reason(for: rightScope,
                                                                          deletions: unprovenLeft,
                                                                          deleteSide: "left")))
        }

        // And the volume, which is the net for everything the checks above cannot see — a state
        // record that belongs to a different pair, a volume remounted with different contents, a
        // subtree the enumerator skipped without saying so.
        let denominator = knownEntries ?? plan.count
        if deletions.count > limits.deletionFloor, denominator > 0,
           Double(deletions.count) / Double(denominator) > limits.deletionShare {
            let percent = Int((Double(deletions.count) / Double(denominator) * 100).rounded())
            out.append(Refusal(subject: "(the plan)",
                               reason: "\(deletions.count) of \(denominator) known entries would be "
                               + "deleted — \(percent)%"))
        }
        return out
    }

    /// Why a side cannot stand behind a deletion — the specific reason where there is one, because
    /// "something was wrong" does not tell anybody which path field to look at.
    private static func reason(for scope: SyncSideScope, deletions: Int, deleteSide: String) -> String {
        let what = "\(deletions) deletion(s) on the \(deleteSide)"
        if !scope.rootEnumerable {
            return "\(what) rest on this side, and it could not be read at all — check the path"
        }
        if scope.entriesVisited == 0, scope.rootObservedNonEmpty {
            return "\(what) rest on this side, and the comparison found nothing in it although it is "
                + "not empty"
        }
        return "\(what) rest on paths this side did not look at — a folder was held back or not "
            + "descended into"
    }
}
