// SPDX-License-Identifier: Apache-2.0
// SyncSideScope.swift - What one side of a comparison was actually able to look at.
//
// Lives here rather than with the scanner that fills it in, for the same reason `SyncItem` and
// `SyncOptions` do: it is a pure statement of fact with no I/O in it, and the layer that has to
// *reason* about it — the plan guard beside `SyncModel` — must not depend on PCOperations.

import Foundation

/// What one side's walk managed to look at.
///
/// This exists for one question, and it is the question a mirror gets wrong: *may a deletion be
/// derived from this path being absent on this side?* Absence on its own is not evidence. The walk
/// may never have started — `FileManager.enumerator(atPath:)` answers nil for a path that is not
/// there, cannot be read, or sits on a volume that is not mounted, and the scanner used to turn that
/// into an empty result with no error and no mark. In mirror mode that empty result classifies every
/// file on the other side as "delete it", pre-ticked, one confirmation away. Measured on a
/// mistyped path.
///
/// A root check alone is not enough either: the path-based enumerator has no error handler, so an
/// unreadable *subtree* is silently missing from an otherwise fine walk. Hence `incompleteDirs` —
/// which the walk already tracked for the folder-delete guard — is part of the answer too.
public struct SyncSideScope: Sendable, Equatable {
    /// The walk could be started at all.
    public let rootEnumerable: Bool
    /// A plain directory listing found something in the root, independently of the walk. Set only
    /// where that can be asked cheaply; it catches the case where the walk starts and yields
    /// nothing while the folder is plainly not empty.
    public let rootObservedNonEmpty: Bool
    public let entriesFound: Int
    /// How many entries the walk was handed, before any rule dropped one.
    ///
    /// Separate from `entriesFound` because a mask that excludes everything is a perfectly good
    /// answer — it keeps nothing and is still trustworthy — while an enumerator that yields nothing
    /// over a folder that is plainly not empty is not. Measured against `entriesFound` the first
    /// case reads as a failure, which would refuse deletions a mirror is right to make.
    public let entriesVisited: Int
    /// Paths the filter held back.
    public let filtered: Set<String>
    /// Folders whose inside was not fully seen, by any rule.
    public let incompleteDirs: Set<String>

    public init(rootEnumerable: Bool, rootObservedNonEmpty: Bool, entriesFound: Int,
                entriesVisited: Int, filtered: Set<String>, incompleteDirs: Set<String>) {
        self.rootEnumerable = rootEnumerable
        self.rootObservedNonEmpty = rootObservedNonEmpty
        self.entriesFound = entriesFound
        self.entriesVisited = entriesVisited
        self.filtered = filtered
        self.incompleteDirs = incompleteDirs
    }

    /// What a caller that was handed no scope at all has to assume: nothing was established. Every
    /// question below answers "no", so a default-constructed outcome can never justify a deletion.
    public static let unknown = SyncSideScope(rootEnumerable: false, rootObservedNonEmpty: false,
                                             entriesFound: 0, entriesVisited: 0,
                                             filtered: [], incompleteDirs: [])

    /// Was this side's walk trustworthy as a whole?
    ///
    /// False when it could not start, and false when it found nothing although the root plainly held
    /// something — which is the shape a permission failure part-way takes.
    public var isReliable: Bool {
        rootEnumerable && !(entriesVisited == 0 && rootObservedNonEmpty)
    }

    /// Does this side's walk *prove* that `rel` is not there?
    ///
    /// Positive evidence, deliberately, rather than "the filter looked the same as last time". The
    /// filter cannot answer this: `SyncFilter.modifiedWithinDays` is stored relative and resolved at
    /// scan time, so the same filter text covers a different set on every run, and `keepsPair` drops
    /// a pair before a `SyncItem` exists — so there is no way to ask whether a file that is gone
    /// *would* have been in scope. What can be answered is the other way round: the walk ran, it did
    /// not hold this path back, and no folder above it was left half-seen.
    public func provesAbsence(of rel: String) -> Bool {
        guard isReliable, !filtered.contains(rel) else { return false }
        var prefix = ""
        for part in rel.split(separator: "/", omittingEmptySubsequences: true).dropLast() {
            prefix = prefix.isEmpty ? String(part) : prefix + "/" + part
            // Both sets, and the second one is the one that is easy to forget: a folder the filter
            // cut the descent off at lands in `filtered`, not in `incompleteDirs` — the walk never
            // recorded it, so it never marked itself incomplete. Everything under such a folder was
            // never looked at. Measured: with only `incompleteDirs` consulted, an excluded
            // `build/` proved that `build/one.o` was gone.
            if incompleteDirs.contains(prefix) || filtered.contains(prefix) { return false }
        }
        return true
    }
}
