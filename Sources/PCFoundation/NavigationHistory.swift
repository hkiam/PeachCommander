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
}
