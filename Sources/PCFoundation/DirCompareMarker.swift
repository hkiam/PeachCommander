// DirCompareMarker - "Compare Directories" panel-marking model
// A pure, deterministic implementation of Total Commander's cm_CompareDirs
// semantics: given the contents of two panels, decide which files should be
// marked (selected) in each panel so that copying the marked files across
// would make the two directories equal.

import Foundation

/// A single file-system entry as seen by `DirCompareMarker`.
///
/// Only the leaf name, kind, size and modification time matter for
/// comparison -- callers are expected to supply the immediate children of
/// the two directories being compared (no recursion is performed here).
public struct DirCompareEntry: Sendable, Equatable {
    /// The leaf name of the entry (no path components).
    public let name: String
    /// Whether the entry is a directory. Directories are never marked and
    /// never matched against the other side; they exist purely so callers
    /// can pass a panel's full listing without pre-filtering it.
    public let isDirectory: Bool
    /// The entry's size in bytes. Ignored for directories.
    public let size: Int64
    /// The entry's modification time.
    public let modified: Date

    public init(name: String, isDirectory: Bool, size: Int64, modified: Date) {
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modified = modified
    }
}

/// The outcome of a `DirCompareMarker.compare` call: the set of leaf names
/// to mark (select) in each panel.
public struct DirCompareResult: Sendable, Equatable {
    /// Names to select in the left panel, exactly as they appear there.
    public let leftMarks: Set<String>
    /// Names to select in the right panel, exactly as they appear there.
    public let rightMarks: Set<String>

    public init(leftMarks: Set<String>, rightMarks: Set<String>) {
        self.leftMarks = leftMarks
        self.rightMarks = rightMarks
    }
}

/// Computes Total-Commander-style "Compare Directories" selections.
///
/// `cm_CompareDirs` marks, in each panel, the files that would need to be
/// copied to the other panel to make the two directories equal: files that
/// exist only on one side, plus same-named files that are newer on one
/// side than the other. Directories are never considered. When two
/// same-named files have equal modification times (within `toleranceSeconds`)
/// but different sizes, neither side is "newer", so both are marked to flag
/// the discrepancy; when both time and size match, neither is marked.
public enum DirCompareMarker {

    /// Compute which files to mark in each panel (TC cm_CompareDirs semantics).
    ///
    /// - Parameters:
    ///   - left: The left panel's entries (files and directories).
    ///   - right: The right panel's entries (files and directories).
    ///   - caseSensitive: Whether names match case-sensitively. When `false`
    ///     (the macOS default), names are matched by lowercased value, but
    ///     the returned marks always use the name as it appears in that
    ///     entry's own panel.
    ///   - toleranceSeconds: Modification times within this many seconds of
    ///     each other are treated as equal, to absorb FAT's 2-second
    ///     granularity and DST shifts. Defaults to 2.
    /// - Returns: The names to select in each panel.
    public static func compare(left: [DirCompareEntry],
                               right: [DirCompareEntry],
                               caseSensitive: Bool = false,
                               toleranceSeconds: TimeInterval = 2) -> DirCompareResult {
        // Only files participate; directories are never matched or marked.
        // Sort by name first so that, in the rare case of duplicate
        // case-insensitive keys on one side, matching is deterministic.
        let leftFiles = left.filter { !$0.isDirectory }.sorted { $0.name < $1.name }
        let rightFiles = right.filter { !$0.isDirectory }.sorted { $0.name < $1.name }

        func key(_ name: String) -> String {
            caseSensitive ? name : name.lowercased()
        }

        // Map each matching key to the first entry seen on that side.
        var rightByKey: [String: DirCompareEntry] = [:]
        for entry in rightFiles where rightByKey[key(entry.name)] == nil {
            rightByKey[key(entry.name)] = entry
        }
        var leftByKey: [String: DirCompareEntry] = [:]
        for entry in leftFiles where leftByKey[key(entry.name)] == nil {
            leftByKey[key(entry.name)] = entry
        }

        var leftMarks: Set<String> = []
        var rightMarks: Set<String> = []

        for entry in leftFiles {
            guard let match = rightByKey[key(entry.name)] else {
                // Only-left file: it needs to be copied to the right side.
                leftMarks.insert(entry.name)
                continue
            }

            let delta = entry.modified.timeIntervalSince(match.modified)
            if abs(delta) <= toleranceSeconds {
                // Same time (within tolerance): differ only if sizes differ,
                // in which case neither side is "newer" so mark both.
                if entry.size != match.size {
                    leftMarks.insert(entry.name)
                    rightMarks.insert(match.name)
                }
            } else if delta > 0 {
                // Left is newer than right.
                leftMarks.insert(entry.name)
            }
            // else: right is newer -- handled from the right-side pass below.
        }

        for entry in rightFiles {
            guard let match = leftByKey[key(entry.name)] else {
                // Only-right file: it needs to be copied to the left side.
                rightMarks.insert(entry.name)
                continue
            }

            let delta = entry.modified.timeIntervalSince(match.modified)
            if abs(delta) <= toleranceSeconds {
                if entry.size != match.size {
                    leftMarks.insert(match.name)
                    rightMarks.insert(entry.name)
                }
            } else if delta > 0 {
                // Right is newer than left.
                rightMarks.insert(entry.name)
            }
        }

        return DirCompareResult(leftMarks: leftMarks, rightMarks: rightMarks)
    }
}
