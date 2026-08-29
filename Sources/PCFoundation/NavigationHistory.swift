// SPDX-License-Identifier: Apache-2.0
// NavigationHistory.swift - Per-panel back/forward path history (SPEC-003 §7).
//
// A bounded ring (default 50) with a current index. Pushing a new path truncates
// any forward history and de-duplicates consecutive identical entries.

import Foundation

public struct NavigationHistory: Sendable, Equatable {
    public private(set) var entries: [String] = []
    public private(set) var index: Int = -1
    public let capacity: Int

    public init(capacity: Int = 50) {
        self.capacity = max(1, capacity)
    }

    /// Rebuild from a persisted list (session restore). Keeps the last `capacity`
    /// entries and clamps the index into range.
    public init(entries: [String], index: Int, capacity: Int = 50) {
        self.capacity = max(1, capacity)
        self.entries = Array(entries.suffix(self.capacity))
        self.index = self.entries.isEmpty ? -1 : min(max(0, index), self.entries.count - 1)
    }

    /// The path at the current position, or nil when empty.
    public var current: String? {
        guard index >= 0 && index < entries.count else { return nil }
        return entries[index]
    }

    public var canGoBack: Bool { index > 0 }
    public var canGoForward: Bool { index >= 0 && index < entries.count - 1 }

    /// Record a navigation to `path`. Consecutive duplicates are ignored; any
    /// forward history beyond the current position is discarded.
    public mutating func push(_ path: String) {
        if current == path { return }
        if index < entries.count - 1 {
            entries.removeSubrange((index + 1)...)
        }
        entries.append(path)
        while entries.count > capacity {
            entries.removeFirst()
        }
        index = entries.count - 1
    }

    /// Move back one step and return the new current path (nil if not possible).
    public mutating func back() -> String? {
        guard canGoBack else { return nil }
        index -= 1
        return current
    }

    /// Move forward one step and return the new current path (nil if not possible).
    public mutating func forward() -> String? {
        guard canGoForward else { return nil }
        index += 1
        return current
    }

    /// Jump directly to a history entry by index (for the Alt+Down history list).
    public mutating func go(to newIndex: Int) -> String? {
        guard newIndex >= 0, newIndex < entries.count else { return nil }
        index = newIndex
        return current
    }

    // MARK: - When the navigation a move handed out did not happen (F-445)

    // `back()`, `forward()` and `go(to:)` move the position and hand back a path, and the caller then
    // tries to load it. That load can fail — a folder deleted, a disk ejected, a share gone — and for
    // as long as nothing put the position back, the history pointed one step away from the panel and
    // the next press counted from *there*. Two ways back out, because the two reasons a load does not
    // happen are not the same thing.

    /// Put the position back, keeping every entry.
    ///
    /// For a load that was superseded rather than refused: nothing is wrong with the entry, the user
    /// simply navigated again while it was arriving.
    public mutating func restorePosition(to previousIndex: Int) {
        index = entries.isEmpty ? -1 : min(max(0, previousIndex), entries.count - 1)
    }

    /// Put the position back *and* forget the entry that could not be opened.
    ///
    /// Dropping it is the difference between a history that heals and one with a wall in it: an entry
    /// that cannot be listed stops every further press in its direction, because each one arrives at
    /// the same dead path and goes no further. It is removed rather than skipped over, so one press
    /// stays one attempt — walking through a whole unmounted share in a single keystroke would put a
    /// message on screen for each of its entries.
    ///
    /// Removing the entry the panel is *showing* is not this method's business — `go(to:)` can be
    /// handed the position it is already at — so that case only restores.
    public mutating func dropEntry(at deadIndex: Int, restoringPositionTo previousIndex: Int) {
        guard entries.indices.contains(deadIndex), deadIndex != previousIndex else {
            restorePosition(to: previousIndex)
            return
        }
        entries.remove(at: deadIndex)
        // Everything after the removed entry shifts down one; the position we are returning to only
        // moves with it when it sat behind the hole.
        restorePosition(to: deadIndex < previousIndex ? previousIndex - 1 : previousIndex)
    }

    /// Whether the position is still exactly where a move left it.
    ///
    /// The caller's guard before undoing anything: a superseded load means a *newer* navigation is
    /// running, and if that one has already recorded itself, its position is the right one — putting
    /// ours back would take the panel's own entry out from under it. Which of the two lands first is
    /// not ordered, so it is asked rather than assumed.
    public func isStill(at position: Int, showing path: String) -> Bool {
        index == position && current == path
    }
}
