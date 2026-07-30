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

    public init(relativePath: String, isDirectory: Bool,
                leftSize: Int64?, leftModified: Date?,
                rightSize: Int64?, rightModified: Date?,
                contentEqual: Bool? = nil) {
        self.relativePath = relativePath
        self.isDirectory = isDirectory
        self.leftSize = leftSize
        self.leftModified = leftModified
        self.rightSize = rightSize
        self.rightModified = rightModified
        self.contentEqual = contentEqual
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

    public init(byContent: Bool = false, ignoreDate: Bool = false, asymmetric: Bool = false,
                ignoreDaylightHour: Bool = false, caseSensitive: Bool = false, toleranceSeconds: TimeInterval = 2) {
        self.byContent = byContent
        self.ignoreDate = ignoreDate
        self.asymmetric = asymmetric
        self.ignoreDaylightHour = ignoreDaylightHour
        self.caseSensitive = caseSensitive
        self.toleranceSeconds = toleranceSeconds
    }
}

/// The classification outcome for a single `SyncItem`.
public struct SyncResult: Sendable, Equatable {
    public let action: SyncAction
    public let item: SyncItem

    public init(action: SyncAction, item: SyncItem) {
        self.action = action
        self.item = item
    }
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
            return classifyDirectory(onLeft: onLeft, onRight: onRight, options: options)
        }

        // Files.
        if onLeft && !onRight {
            // Present only on left: both modes copy left -> right.
            return .copyToRight
        }
        if !onLeft && onRight {
            // Present only on right.
            return options.asymmetric ? .deleteRight : .copyToLeft
        }

        // Present on both sides: decide equality, then a winner if unequal.
        let tolerance = effectiveTolerance(options)
        let equal = filesEqual(item, options: options, tolerance: tolerance)

        if equal {
            return .equal
        }

        if options.asymmetric {
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

    private static func classifyDirectory(onLeft: Bool, onRight: Bool, options: SyncOptions) -> SyncAction {
        if onLeft && onRight {
            return .none
        }
        if options.asymmetric {
            // Mirror mode: left-only directories need creating on right;
            // right-only directories are stray and get removed.
            return onLeft ? .copyToRight : .deleteRight
        }
        // Symmetric mode: directories are purely structural; execution
        // handles mkdir/rmdir based on the files that need moving.
        return .none
    }

    /// Effective time tolerance: widened to at least one hour when
    /// `ignoreDaylightHour` is set, to absorb FAT/DST discrepancies.
    private static func effectiveTolerance(_ options: SyncOptions) -> TimeInterval {
        options.ignoreDaylightHour ? max(3600, options.toleranceSeconds) : options.toleranceSeconds
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
