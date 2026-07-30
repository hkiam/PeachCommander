// SelectionState.swift - Selection state machine for Peach Commander
//
// Implements the TC-compatible selection model:
// - Cursor (focused row) and selection (marked set) are independent
// - `..` can carry the cursor but never be selected
// - Selection history for undo (Num/)
// - Operation-completion unmark hook

import Foundation
import PCFoundation

/// A single entry that can be listed, focused by the cursor, and marked for selection.
///
/// The `..` pseudo-entry is never represented by a `SelectableEntry` - it only
/// exists as cursor position `-1`.
public struct SelectableEntry: Sendable, Equatable {
    /// Absolute path to the entry. Unique key within a `SelectionState`.
    public let path: String

    /// File size in bytes, or `-1` if unknown (e.g. a directory whose size
    /// has not been calculated yet).
    public let size: Int64

    /// Whether this entry is a directory.
    public let isDirectory: Bool

    public init(path: String, size: Int64, isDirectory: Bool) {
        self.path = path
        self.size = size
        self.isDirectory = isDirectory
    }
}

/// Selection state machine - manages cursor and marked set independently
public actor SelectionState {
    private let logger = PCFoundationLogger.logger

    /// Current cursor position (-1 for `..`, 0-based index into `entries` otherwise)
    private var cursorIndex: Int = 0

    /// Ordered list of selectable entries (the `..` pseudo-entry is never included)
    private var entries: [SelectableEntry] = []

    /// Set of marked entry paths
    private var markedPaths: Set<String> = []

    /// Selection history stack for undo (Num/)
    private var historyStack: [Set<String>] = []

    /// Maximum history depth
    private let maxHistoryDepth: Int = 50

    /// Initialize with empty selection
    public init() {
        logger.info("SelectionState initialized")
    }

    // MARK: - Entries Management

    /// Set the ordered list of selectable entries (`..` is never part of this list).
    ///
    /// Marks are retained only for paths still present in the new list (the
    /// intersection of the old marked set with the new entry paths). The
    /// cursor is clamped into `[-1, entries.count - 1]`.
    public func setEntries(_ entries: [SelectableEntry]) {
        let newPaths = Set(entries.map { $0.path })
        markedPaths = markedPaths.intersection(newPaths)
        self.entries = entries
        if entries.isEmpty {
            cursorIndex = -1
        } else {
            cursorIndex = max(-1, min(cursorIndex, entries.count - 1))
        }
    }

    // MARK: - Cursor Management

    /// Get the current cursor index
    public func getCursorIndex() -> Int {
        cursorIndex
    }

    /// Set the cursor index (returns false if out of range)
    public func setCursorIndex(_ index: Int) -> Bool {
        guard index >= -1 && index < entries.count else {
            return false
        }
        cursorIndex = index
        return true
    }

    /// Move cursor up (can reach `..` at -1)
    public func moveCursorUp() {
        if cursorIndex > -1 {
            cursorIndex -= 1
        }
    }

    /// Move cursor down (stops at the last entry)
    public func moveCursorDown() {
        if cursorIndex < entries.count - 1 {
            cursorIndex += 1
        }
    }

    /// Move cursor to top (first entry after `..`, or `..` itself when empty)
    public func moveCursorTop() {
        cursorIndex = entries.isEmpty ? -1 : 0
    }

    /// Move cursor to bottom (last entry, or `..` when empty)
    public func moveCursorBottom() {
        cursorIndex = entries.count - 1
    }

    /// Move cursor to a specific position, clamped into `[-1, entries.count - 1]`
    public func moveCursorTo(_ index: Int) {
        cursorIndex = max(-1, min(index, entries.count - 1))
    }

    /// Check if cursor is on `..`
    public func isCursorOnRoot() -> Bool {
        cursorIndex == -1
    }

    /// Get the cursor path (entries[cursorIndex].path), or nil when on `..`
    /// or when the cursor is otherwise out of bounds.
    public func getCursorPath() -> String? {
        guard cursorIndex >= 0 && cursorIndex < entries.count else { return nil }
        return entries[cursorIndex].path
    }

    // MARK: - Selection Management

    /// Check if a path is selected
    public func isSelected(_ path: String) -> Bool {
        markedPaths.contains(path)
    }

    /// Get the set of selected paths
    public func getSelectedPaths() -> Set<String> {
        markedPaths
    }

    /// Get the list of selected paths, in entry order
    public func getSelectedPathList() -> [String] {
        entries.compactMap { markedPaths.contains($0.path) ? $0.path : nil }
    }

    /// Select a path (returns true if selection changed). `..` can never be selected.
    public func select(_ path: String) -> Bool {
        guard path != ".." else { return false }
        let changed = markedPaths.insert(path).inserted
        if changed {
            logger.debug("Selected: \(path)")
        }
        return changed
    }

    /// Unselect a path (returns true if selection changed)
    public func unselect(_ path: String) -> Bool {
        let changed = markedPaths.remove(path) != nil
        if changed {
            logger.debug("Unselected: \(path)")
        }
        return changed
    }

    /// Toggle selection of a path (returns true if selection changed). `..` can never be selected.
    public func toggleSelection(_ path: String) -> Bool {
        guard path != ".." else { return false }
        if markedPaths.contains(path) {
            return unselect(path)
        } else {
            return select(path)
        }
    }

    /// Select all entries, directories included (TC cm_SelectAll). Returns true if selection changed.
    public func selectAll() -> Bool {
        let oldCount = markedPaths.count
        for entry in entries {
            markedPaths.insert(entry.path)
        }
        return markedPaths.count != oldCount
    }

    /// Clear all selection (returns true if selection changed)
    public func clearSelection() -> Bool {
        let oldCount = markedPaths.count
        markedPaths.removeAll()
        return oldCount > 0
    }

    /// Invert selection (TC Num*): every stored entry toggles membership in the
    /// marked set. Pass `includingDirectories: false` to leave directories'
    /// marks untouched. Returns true if selection changed.
    public func invertSelection(includingDirectories: Bool = true) -> Bool {
        var changed = false
        for entry in entries {
            if !includingDirectories && entry.isDirectory { continue }
            if markedPaths.contains(entry.path) {
                markedPaths.remove(entry.path)
            } else {
                markedPaths.insert(entry.path)
            }
            changed = true
        }
        return changed
    }

    // MARK: - Selection History (Num/ undo)

    /// Save current selection to history
    public func saveSelectionToHistory() {
        let snapshot = Set(markedPaths)
        historyStack.append(snapshot)
        if historyStack.count > maxHistoryDepth {
            historyStack.removeFirst()
        }
        logger.debug("Selection saved to history (depth: \(self.historyStack.count))")
    }

    /// Restore previous selection from history (returns true if restored)
    public func restoreSelectionFromHistory() -> Bool {
        guard let previous = historyStack.popLast() else {
            return false
        }
        markedPaths = previous
        logger.debug("Selection restored from history")
        return true
    }

    /// Clear selection history
    public func clearHistory() {
        historyStack.removeAll()
    }

    // MARK: - Selection by Criteria

    /// Select entries matching a wildcard mask (matched against the entry's
    /// filename, i.e. the last path component). Uses the stored entry list.
    /// Returns the number of entries newly marked.
    public func selectByMask(_ mask: String, includeDirectories: Bool) -> Int {
        let wildcard = WildcardMask(mask)
        var count = 0
        for entry in entries {
            if !includeDirectories && entry.isDirectory { continue }
            let filename = URL(fileURLWithPath: entry.path).lastPathComponent
            if wildcard.matches(filename) && !markedPaths.contains(entry.path) {
                markedPaths.insert(entry.path)
                count += 1
            }
        }
        logger.debug("Selected \(count) entries by mask: \(mask)")
        return count
    }

    /// Unselect entries matching a wildcard mask. Uses the stored entry list.
    /// Returns the number of entries newly unmarked.
    public func unselectByMask(_ mask: String, includeDirectories: Bool) -> Int {
        let wildcard = WildcardMask(mask)
        var count = 0
        for entry in entries {
            if !includeDirectories && entry.isDirectory { continue }
            let filename = URL(fileURLWithPath: entry.path).lastPathComponent
            if wildcard.matches(filename) && markedPaths.contains(entry.path) {
                markedPaths.remove(entry.path)
                count += 1
            }
        }
        logger.debug("Unselected \(count) entries by mask: \(mask)")
        return count
    }

    /// Select files (directories are never matched) sharing the cursor entry's
    /// extension (empty extension matches files with no extension). No-op
    /// (returns 0) when the cursor is on `..` or on a directory.
    /// Returns the number of entries newly marked.
    public func selectSameExtension() -> Int {
        guard cursorIndex >= 0 && cursorIndex < entries.count else { return 0 }
        let cursorEntry = entries[cursorIndex]
        guard !cursorEntry.isDirectory else { return 0 }
        let ext = URL(fileURLWithPath: cursorEntry.path).pathExtension.lowercased()
        var count = 0
        for entry in entries {
            guard !entry.isDirectory else { continue }
            let entryExt = URL(fileURLWithPath: entry.path).pathExtension.lowercased()
            if entryExt == ext && !markedPaths.contains(entry.path) {
                markedPaths.insert(entry.path)
                count += 1
            }
        }
        logger.debug("Selected \(count) entries with same extension: \(ext)")
        return count
    }

    // MARK: - Statistics

    /// Get selection statistics: number marked and total entry count.
    public func getStatistics() -> (selected: Int, total: Int) {
        (markedPaths.count, entries.count)
    }

    /// Sum of sizes of marked entries whose size is known (>= 0).
    public func getSelectedSize() -> Int64 {
        entries.reduce(Int64(0)) { sum, entry in
            guard markedPaths.contains(entry.path), entry.size >= 0 else { return sum }
            return sum + entry.size
        }
    }

    /// Sum of sizes of all entries whose size is known (>= 0).
    public func getTotalSize() -> Int64 {
        entries.reduce(Int64(0)) { sum, entry in
            guard entry.size >= 0 else { return sum }
            return sum + entry.size
        }
    }

    // MARK: - Operation Completion

    /// Remove the given successfully-processed paths from the marked set.
    /// Used by file operations after completion; callers should only pass
    /// paths that succeeded, so failed items remain marked.
    public func unmarkCompleted(_ paths: [String]) {
        for path in paths {
            markedPaths.remove(path)
        }
    }
}
