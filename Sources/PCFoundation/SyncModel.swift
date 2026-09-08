// SPDX-License-Identifier: Apache-2.0
// SyncModel - "Synchronize Directories" classification model
// A pure, deterministic decision function: given already-walked metadata for
// matching relative paths on a left and right tree, decide the sync action
// for each item. The actual filesystem walk (producing `SyncItem`s) and the
// execution of the resulting actions (copy/delete on disk) live elsewhere;
// this file performs no I/O whatsoever.

import Foundation

/// The action to take for a single item when synchronizing two directory
/// trees.
public enum SyncAction: Sendable, Equatable {
    /// Copy the item from left to right (create or overwrite on right).
    case copyToRight
    /// Copy the item from right to left (create or overwrite on left).
    case copyToLeft
    /// The item is identical on both sides; nothing to do.
    case equal
    /// The items differ but neither side is a clear winner (same time,
    /// different size/content).
    case conflict
    /// Remove the item on the right (asymmetric mirror mode, right-only item).
    case deleteRight
    /// Remove the item on the left.
    case deleteLeft
    /// No action: excluded item, or a directory placeholder that needs no
    /// action of its own (structural; mkdir/rmdir is handled by execution
    /// based on the files that do need moving).
    case none
}

/// A single matched relative path as seen on both the left and right trees,
/// with whatever metadata the caller's directory walk already collected.
///
/// Absence on one side is represented by `nil` size/modified pair on that
/// side -- callers should not synthesize a `SyncItem` for a path that is
/// absent on *both* sides.
public struct SyncItem: Sendable, Equatable {
    /// POSIX-style relative path (from the roots being compared), using "/"
    /// separators regardless of platform.
    public let relativePath: String
    /// Whether this entry is a directory.
    public let isDirectory: Bool
    /// Size in bytes on the left, or `nil` if absent on the left.
    public let leftSize: Int64?
    /// Modification date on the left, or `nil` if absent on the left.
    public let leftModified: Date?
    /// Size in bytes on the right, or `nil` if absent on the right.
    public let rightSize: Int64?
    /// Modification date on the right, or `nil` if absent on the right.
    public let rightModified: Date?
    /// When comparing by content, the caller precomputes byte-for-byte
    /// equality for items present on both sides. `nil` means "not compared
    /// by content" -- classification falls back to size + date in that case.
    public let contentEqual: Bool?
    /// For a directory: something inside it was left out of this comparison.
    ///
    /// Set by the scanner for a folder holding an entry the mask, "ignore hidden" or the filter held
    /// back — and for one whose inside was never looked at at all, which is what "without subdirs"
    /// means. It exists for one decision: a mirror must not delete such a folder, because deleting a
    /// folder is recursive and would take the held-back entries with it. The executor refuses that
    /// as a last line of defence and reports it; this is what keeps an ordinary `node_modules/`
    /// exclusion from producing that report on every single run.
    public let hasHeldBackContent: Bool

    public init(relativePath: String, isDirectory: Bool,
                leftSize: Int64?, leftModified: Date?,
                rightSize: Int64?, rightModified: Date?,
                contentEqual: Bool? = nil,
                hasHeldBackContent: Bool = false) {
        self.relativePath = relativePath
        self.isDirectory = isDirectory
        self.leftSize = leftSize
        self.leftModified = leftModified
        self.rightSize = rightSize
        self.rightModified = rightModified
        self.contentEqual = contentEqual
        self.hasHeldBackContent = hasHeldBackContent
    }
}

/// Options controlling how `SyncModel.classify` compares matched items.
public struct SyncOptions: Sendable, Equatable, Codable {
    /// Use `SyncItem.contentEqual` instead of size+date when both sides are
    /// present and byte comparison was performed by the caller.
    public var byContent: Bool
    /// (Content mode only) ignore timestamps entirely; equality is decided
    /// by content alone.
    public var ignoreDate: Bool
    /// Right is treated as a one-way backup mirror of left: right-only
    /// items are deleted, and any difference (regardless of which side is
    /// newer) is resolved by copying left onto right.
    public var asymmetric: Bool
    /// Treat modification times within 3600 seconds (+/- one hour, to
    /// absorb FAT/DST discrepancies) as equal, in addition to
    /// `toleranceSeconds`.
    public var ignoreDaylightHour: Bool
    /// Whether path/name matching is case-sensitive. Matching itself is
    /// performed by the caller before building `SyncItem`s; this flag is
    /// kept here purely for completeness/round-tripping of user settings.
    public var caseSensitive: Bool
    /// Base granularity tolerance for time comparisons, in seconds.
    /// Defaults to 2, absorbing FAT's 2-second timestamp resolution.
    public var toleranceSeconds: TimeInterval
    /// Compare against a record of the last run, so that a one-sided file can be told apart as
    /// **new here** or **deleted there** — and a deletion carried across.
    ///
    /// A second flag beside `asymmetric` rather than the two of them replaced by an enum, and that
    /// is not laziness: `SyncPreset` decodes field by field precisely so a preset written by an
    /// older build still loads, and an enum arriving as an absent key would have to default to
    /// something. Two booleans have one combination that means nothing, and `mode` below settles it
    /// in one place instead of leaving it to whichever branch reads them first.
    public var twoWay: Bool

    public init(byContent: Bool = false, ignoreDate: Bool = false, asymmetric: Bool = false,
                ignoreDaylightHour: Bool = false, caseSensitive: Bool = false,
                toleranceSeconds: TimeInterval = 2, twoWay: Bool = false) {
        self.byContent = byContent
        self.ignoreDate = ignoreDate
        self.asymmetric = asymmetric
        self.ignoreDaylightHour = ignoreDaylightHour
        self.caseSensitive = caseSensitive
        self.toleranceSeconds = toleranceSeconds
        self.twoWay = twoWay
    }

    /// Which of the three modes this actually is.
    ///
    /// The one place the two flags are resolved. `asymmetric && twoWay` is not a mode — it can only
    /// arrive from a hand-edited preset or a future version, and the window keeps the two switches
    /// exclusive — so it reads as **symmetric**: the one of the three that never deletes anything.
    /// A malformed input has to fall towards the harmless reading, not towards whichever deletion
    /// happens to be checked first.
    public var mode: Mode {
        if asymmetric && twoWay { return .symmetric }
        if twoWay { return .twoWay }
        if asymmetric { return .mirror }
        return .symmetric
    }

    public enum Mode: Sendable, Equatable {
        /// Differences are copied to whichever side is older. Never deletes.
        case symmetric
        /// The right side is made a copy of the left. Deletes on the right only.
        case mirror
        /// Both sides are kept the same, using a record of the last run. Can delete on either.
        case twoWay
    }

    /// Decode field by field, every one optional, falling back to this type's own defaults.
    ///
    /// Written out rather than synthesized for the reason `SearchTemplate.init(from:)` records: the
    /// synthesized version does *not* fall back to a property's default, it throws on a missing key.
    /// These options are saved to disk inside a `SyncPreset` and outlive the build that wrote them,
    /// and `SyncPresetStore.load` answers `[]` for anything it cannot decode — so adding one option
    /// here would have made every previously saved preset fail to load, and the next save would then
    /// have overwritten the file. All of the user's presets, gone, with nothing said.
    ///
    /// The nested case is the one that matters and is easy to miss: a tolerant decoder on
    /// `SyncPreset` alone does not help, because `decodeIfPresent(SyncOptions.self, …)` throws when
    /// the object *is* there and is missing a key.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SyncOptions()
        byContent = try c.decodeIfPresent(Bool.self, forKey: .byContent) ?? d.byContent
        ignoreDate = try c.decodeIfPresent(Bool.self, forKey: .ignoreDate) ?? d.ignoreDate
        asymmetric = try c.decodeIfPresent(Bool.self, forKey: .asymmetric) ?? d.asymmetric
        ignoreDaylightHour = try c.decodeIfPresent(Bool.self, forKey: .ignoreDaylightHour) ?? d.ignoreDaylightHour
        caseSensitive = try c.decodeIfPresent(Bool.self, forKey: .caseSensitive) ?? d.caseSensitive
        toleranceSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .toleranceSeconds) ?? d.toleranceSeconds
        twoWay = try c.decodeIfPresent(Bool.self, forKey: .twoWay) ?? d.twoWay
    }
}

/// The classification outcome for a single `SyncItem`.
/// Why a row says what it says.
///
/// Deliberately **not** a new `SyncAction` case, and the reason is which way each choice fails. A new
/// case would be missed by omission in every switch that already exists: `SyncExecutor.deletesPermanently`
/// would answer `false` for it, so the permanent-deletion warning would not cover a propagated
/// delete on a server; the executor's creates/copies/deletes partition would skip it silently, so
/// the delete would never run and produce no outcome at all; and `deletedKeys` would not contain it,
/// so the folder guard would refuse a delete it should allow. Reusing `.deleteRight`/`.deleteLeft`
/// means the executor changes not at all, and both existing safety layers cover the new rows for
/// free.
///
/// The distinction belongs here rather than on `SyncItem`, which carries the scanner's facts about
/// the filesystem; "this deletion is a propagation" is a fact about the *decision*.
///
/// One rule to hold to: **nothing may infer "propagated" from the action value.** A mirror delete and
/// a propagated delete are the same `SyncAction`, and only this says which is which.
public enum SyncBasis: Sendable, Equatable {
    /// Decided from the two sides as they are now — every row the two existing modes produce.
    case comparison
    /// The path was deleted on the *other* side since the last run, so it goes here too.
    case propagatedDeletion
    /// The record and the two sides cannot be reconciled without asking: changed on one side and
    /// deleted on the other, changed on both, a file where a folder was — or an absence this run
    /// could not prove.
    case stateConflict
}

public struct SyncResult: Sendable, Equatable {
    public let action: SyncAction
    public let item: SyncItem
    public let basis: SyncBasis

    public init(action: SyncAction, item: SyncItem, basis: SyncBasis = .comparison) {
        self.action = action
        self.item = item
        self.basis = basis
    }
}

/// Which direction of change the compared result list shows (F-192 follow-up).
///
/// "Direction" is the side a row *changes*, not the side it reads from: a copy to the right and a
/// delete on the right both land on the right, so both belong to `.toRight`. Rows that change
/// neither side — the identical ones and the conflicts — are what a direction filter is asking to be
/// rid of, so neither survives one.
public enum SyncDirectionFilter: Sendable, CaseIterable {
    /// Every row the comparison produced.
    case all
    /// Only rows whose change lands on the right.
    case toRight
    /// Only rows whose change lands on the left.
    case toLeft
}

/// Computes Total-Commander-style "Synchronize Directories" actions.
///
/// This is the pure decision function only: it takes already-walked
/// metadata for matching relative paths on a left and right tree and
/// decides, per item, what should happen. It performs no filesystem I/O --
/// the walk that produces `SyncItem`s and the execution of the resulting
/// `SyncAction`s are the caller's responsibility.
public enum SyncModel {

    /// Classify each item's sync action according to `options`.
    ///
    /// - Parameters:
    ///   - items: The matched items to classify, one per relative path.
    ///     Order is preserved in the result.
    ///   - options: Comparison and mirroring options.
    /// - Returns: One `SyncResult` per input item, in the same order.
    public static func classify(_ items: [SyncItem], options: SyncOptions) -> [SyncResult] {
        items.map { SyncResult(action: classify($0, options: options), item: $0) }
    }

    // MARK: - Per-item classification

    private static func classify(_ item: SyncItem, options: SyncOptions) -> SyncAction {
        let onLeft = item.leftSize != nil
        let onRight = item.rightSize != nil

        if item.isDirectory {
            return classifyDirectory(onLeft: onLeft, onRight: onRight, options: options,
                                     hasHeldBackContent: item.hasHeldBackContent)
        }

        // Files.
        if onLeft && !onRight {
            // Present only on left: both modes copy left -> right.
            return .copyToRight
        }
        if !onLeft && onRight {
            // Present only on right.
            return options.mode == .mirror ? .deleteRight : .copyToLeft
        }

        // Present on both sides: decide equality, then a winner if unequal.
        let tolerance = effectiveTolerance(options)
        let equal = filesEqual(item, options: options, tolerance: tolerance)

        if equal {
            return .equal
        }

        // `mode`, not the flag: two flags have one combination that means nothing, and reading the
        // raw `asymmetric` here let that combination delete — measured, it produced `.deleteRight`
        // for a mode that is defined as the one which deletes nothing.
        if options.mode == .mirror {
            // Mirror mode: any difference means left wins, unconditionally.
            return .copyToRight
        }

        // Symmetric mode: newer side wins; a tie with a real difference is
        // a conflict (same time, different size/content).
        let leftDate = item.leftModified ?? .distantPast
        let rightDate = item.rightModified ?? .distantPast
        let delta = leftDate.timeIntervalSince(rightDate)
        if delta > tolerance {
            return .copyToRight
        } else if delta < -tolerance {
            return .copyToLeft
        } else {
            return .conflict
        }
    }

    private static func classifyDirectory(onLeft: Bool, onRight: Bool, options: SyncOptions,
                                          hasHeldBackContent: Bool = false) -> SyncAction {
        if onLeft && onRight {
            // Present on both sides: nothing to do about the folder itself.
            return .none
        }
        if options.mode == .mirror {
            // Mirror mode: left-only directories need creating on right;
            // right-only directories are stray and get removed.
            //
            // Except one that still holds something this comparison left out. Removing a folder is
            // recursive, so that removal would take the held-back entries with it — the mirror would
            // delete what it had declined to look at. Only the delete is withdrawn: a left-only
            // folder is still created on the right, which creates a folder and takes nothing away.
            if !onLeft, hasHeldBackContent { return .none }
            return onLeft ? .copyToRight : .deleteRight
        }
        // Symmetric mode: a folder that exists on one side only is copied, like a file.
        //
        // This used to be `.none`, on the reasoning that folders are structural and get created on
        // the way by the files that need moving. True — except for a folder with nothing in it,
        // which has no files to be created by, and so was silently never synchronized at all. An
        // empty folder is content: it is how people reserve a name, and losing it is a difference
        // the two trees keep for ever.
        return onLeft ? .copyToRight : .copyToLeft
    }

    /// Effective time tolerance: widened to at least one hour when
    /// `ignoreDaylightHour` is set, to absorb FAT/DST discrepancies.
    private static func effectiveTolerance(_ options: SyncOptions) -> TimeInterval {
        options.ignoreDaylightHour ? max(3600, options.toleranceSeconds) : options.toleranceSeconds
    }

    /// The rows a direction filter and the "hide identical" switch leave visible, as indices into
    /// the list they were given.
    ///
    /// Takes the *actions* rather than the results because the sync window lets a row's direction be
    /// reversed by hand: the filter has to follow what a row says now, not what the scan first
    /// decided about it. Indices rather than a filtered copy for the same reason — the window keeps
    /// one row of state (included, direction) per compared item, and a filtered copy would leave it
    /// with two lists to keep in step.
    public static func visibleRows(actions: [SyncAction],
                                   direction: SyncDirectionFilter,
                                   hideEqual: Bool) -> [Int] {
        actions.indices.filter { i in
            let action = actions[i]
            if hideEqual, action == .equal { return false }
            switch direction {
            case .all:     return true
            case .toRight: return action == .copyToRight || action == .deleteRight
            case .toLeft:  return action == .copyToLeft || action == .deleteLeft
            }
        }
    }

    /// Whether a both-present file counts as "equal", per the active
    /// comparison mode.
    private static func filesEqual(_ item: SyncItem, options: SyncOptions, tolerance: TimeInterval) -> Bool {
        let leftDate = item.leftModified ?? .distantPast
        let rightDate = item.rightModified ?? .distantPast
        let timesEqual = abs(leftDate.timeIntervalSince(rightDate)) <= tolerance

        if options.byContent, let contentEqual = item.contentEqual {
            // Content mode: equal iff the bytes match and (dates are
            // ignored entirely, or the timestamps also agree). A content
            // match with diverging timestamps (and !ignoreDate) is *not*
            // equal -- it falls through to the newer-wins/conflict logic.
            return contentEqual && (options.ignoreDate || timesEqual)
        }

        // Size + date mode (also the fallback when byContent is set but no
        // contentEqual was supplied by the caller).
        let sizesEqual = item.leftSize == item.rightSize
        return sizesEqual && timesEqual
    }
}
