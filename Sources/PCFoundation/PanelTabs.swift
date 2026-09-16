// SPDX-License-Identifier: Apache-2.0
// PanelTabs.swift - Per-panel tab model (SPEC iteration I06 T01).
//
// A pure, testable model tracking the set of open tabs for a single panel and
// which one is active. Each tab remembers its own path, sort order, lock
// state and cursor position so switching tabs restores the prior view.
//
// It is also the shape a workspace is stored and handed around in, which is why the `Codable`
// conformance below is written out rather than synthesised. Two properties matter for a file people
// can open, edit and send to somebody else:
//
//   * **Short, stable keys.** `sort`, not `sortColumn`. They are the file format now; renaming a
//     Swift property must not rewrite everybody's stored workspaces.
//   * **Defaults are not written.** An ordinary tab is `{"path": "/Users/me"}` and nothing else, so a
//     workspace file stays readable at a glance instead of being five-sixths noise. The decoder
//     supplies the same defaults the initializer does, so a tab written before a field existed reads
//     back as a tab without it — the rule `WorkspaceCodec` already had, kept across the move to JSON.

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
    /// The drive-bar volume this tab is showing when that is a mounted plugin drive (its
    /// "pfxmount:<id>" sentinel), else nil.
    ///
    /// Without it a tab on such a drive is remembered as its `path`, which is the mount's own "/" —
    /// so leaving the tab or restarting the app brought back the startup disk's root and called it
    /// the same tab. The volume is what the tab is on; the path only says where inside it.
    public var driveVolume: String?

    /// Marked entry NAMES relative to `path`, not full paths.
    ///
    /// Names rather than paths for three reasons, and the third is the one that decides it: they are
    /// shorter, they are readable in a file somebody opens, and a workspace handed to a colleague
    /// whose folder is mounted somewhere else still marks the right files. Restored by intersecting
    /// with what is actually in the directory, which is also what makes a file deleted in the
    /// meantime disappear from the selection instead of resurrecting as a phantom.
    ///
    /// Only the active tab of a panel can have live marks — `SelectionState.setEntries` intersects
    /// the marked set with the new directory on every load, so switching tabs already destroys the
    /// previous tab's marks. Storing them per tab is therefore honest about what is kept, not a
    /// promise the panel cannot hold.
    public var marked: [String]?

    /// The quick filter that was showing (`PanelListView.filterText`), nil when there was none.
    public var filterText: String?

    public init(
        path: String,
        sortColumn: String = "name",
        sortAscending: Bool = true,
        locked: Bool = false,
        cursorName: String? = nil,
        driveVolume: String? = nil,
        marked: [String]? = nil,
        filterText: String? = nil
    ) {
        self.path = path
        self.sortColumn = sortColumn
        self.sortAscending = sortAscending
        self.locked = locked
        self.cursorName = cursorName
        self.driveVolume = driveVolume
        self.marked = marked
        self.filterText = filterText
    }
}

// MARK: - Codable

extension PanelTabState: Codable {
    private enum CodingKeys: String, CodingKey {
        case path, sort, asc, locked, cursor, drive, marked, filter
    }

    /// Defaults are omitted. See the note at the top of this file.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(path, forKey: .path)
        if sortColumn != "name" { try c.encode(sortColumn, forKey: .sort) }
        if !sortAscending { try c.encode(false, forKey: .asc) }
        if locked { try c.encode(true, forKey: .locked) }
        try c.encodeIfPresent(cursorName, forKey: .cursor)
        try c.encodeIfPresent(driveVolume, forKey: .drive)
        // An empty list is not a list: it would say "nothing is marked here" in a file where the
        // absence of the key says the same thing more quietly.
        if let marked, !marked.isEmpty { try c.encode(marked, forKey: .marked) }
        if let filterText, !filterText.isEmpty { try c.encode(filterText, forKey: .filter) }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            path: try c.decode(String.self, forKey: .path),
            sortColumn: try c.decodeIfPresent(String.self, forKey: .sort) ?? "name",
            sortAscending: try c.decodeIfPresent(Bool.self, forKey: .asc) ?? true,
            locked: try c.decodeIfPresent(Bool.self, forKey: .locked) ?? false,
            cursorName: try c.decodeIfPresent(String.self, forKey: .cursor),
            driveVolume: try c.decodeIfPresent(String.self, forKey: .drive),
            marked: try c.decodeIfPresent([String].self, forKey: .marked),
            filterText: try c.decodeIfPresent(String.self, forKey: .filter)
        )
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
