// PanelTabs.swift - Per-panel tab model (SPEC iteration I06 T01).
//
// A pure, testable model tracking the set of open tabs for a single panel and
// which one is active. Each tab remembers its own path, sort order, lock
// state and cursor position so switching tabs restores the prior view.

import Foundation

/// The persisted state of a single panel tab.
public struct PanelTabState: Sendable, Equatable {
    public var path: String
    /// "name" | "ext" | "size" | "date"
    public var sortColumn: String
    public var sortAscending: Bool
    public var locked: Bool
    /// Entry filename to restore the cursor on when this tab becomes active.
    public var cursorName: String?

    public init(
        path: String,
        sortColumn: String = "name",
        sortAscending: Bool = true,
        locked: Bool = false,
        cursorName: String? = nil
    ) {
        self.path = path
        self.sortColumn = sortColumn
        self.sortAscending = sortAscending
        self.locked = locked
        self.cursorName = cursorName
    }
}

/// The ordered collection of tabs for a panel, with one active at a time.
public struct PanelTabs: Sendable, Equatable {
    public private(set) var tabs: [PanelTabState]
    public private(set) var activeIndex: Int

    /// Starts with exactly one tab.
    public init(initial: PanelTabState) {
        self.tabs = [initial]
        self.activeIndex = 0
    }

    /// Reconstruct from a saved list. `activeIndex` is clamped into range.
    /// An empty `tabs` array is not handled here (callers must pass >= 1 tab);
    /// in that case `activeIndex` is left at 0.
    public init(tabs: [PanelTabState], activeIndex: Int) {
        self.tabs = tabs
        if tabs.isEmpty {
            self.activeIndex = 0
        } else {
            self.activeIndex = min(max(activeIndex, 0), tabs.count - 1)
        }
    }

    /// The currently active tab.
    public var active: PanelTabState {
        tabs[activeIndex]
    }

    /// The number of open tabs.
    public var count: Int {
        tabs.count
    }

    /// Mutate the active tab in place.
    public mutating func updateActive(_ transform: (inout PanelTabState) -> Void) {
        transform(&tabs[activeIndex])
    }

    /// Insert a new tab right after the active one. If `activate` is true the
    /// new tab becomes active; otherwise the current active tab remains active.
    public mutating func open(_ tab: PanelTabState, activate: Bool) {
        let insertIndex = activeIndex + 1
        tabs.insert(tab, at: insertIndex)
        if activate {
            activeIndex = insertIndex
        }
        // Insertion happens after the active tab, so when not activating the
        // current activeIndex is never shifted.
    }

    /// Close the tab at `index`. Refuses (returns false) when only one tab
    /// remains or `index` is out of range.
    @discardableResult
    public mutating func close(at index: Int) -> Bool {
        guard tabs.count > 1, tabs.indices.contains(index) else { return false }
        tabs.remove(at: index)
        if index < activeIndex {
            activeIndex -= 1
        } else if index == activeIndex {
            activeIndex = max(0, index - 1)
        }
        // index > activeIndex: activeIndex unchanged.
        return true
    }

    /// Close the active tab (same rules as `close(at:)`).
    @discardableResult
    public mutating func closeActive() -> Bool {
        close(at: activeIndex)
    }

    /// Select a tab by index. Ignored if out of range.
    public mutating func select(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeIndex = index
    }

    /// Move to the next tab, wrapping around to the first.
    public mutating func next() {
        guard !tabs.isEmpty else { return }
        activeIndex = (activeIndex + 1) % tabs.count
    }

    /// Move to the previous tab, wrapping around to the last.
    public mutating func previous() {
        guard !tabs.isEmpty else { return }
        activeIndex = (activeIndex - 1 + tabs.count) % tabs.count
    }

    /// Toggle the active tab's locked flag.
    public mutating func toggleLockActive() {
        tabs[activeIndex].locked.toggle()
    }

    /// Reorder a tab from `source` to `destination`, keeping the same tab active
    /// (its index is recomputed). No-op for out-of-range or equal indices. (F-008)
    public mutating func move(from source: Int, to destination: Int) {
        guard tabs.indices.contains(source), tabs.indices.contains(destination),
              source != destination else { return }
        let tab = tabs.remove(at: source)
        tabs.insert(tab, at: destination)
        if activeIndex == source {
            activeIndex = destination
        } else {
            // The active tab wasn't the moved one: adjust for the removal (indices
            // above source shift down) then the insertion (indices at/above dest shift up).
            var a = activeIndex
            if source < a { a -= 1 }
            if destination <= a { a += 1 }
            activeIndex = a
        }
    }
}
