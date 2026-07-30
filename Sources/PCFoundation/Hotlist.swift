// Hotlist.swift - Directory hotlist model (SPEC-003 §7, I06-T03).
//
// A flat, ordered list of title→path bookmarks persisted in hotlist.ini under a
// single [Hotlist] section (Count + Entry{i}Title / Entry{i}Path). Submenus are
// expressed in the title with a backslash ("Work\ProjectA"); a title of "-" is a
// separator — the menu builder (F-061) turns those into nested NSMenus.

import Foundation

public struct HotlistEntry: Sendable, Equatable {
    public let title: String
    public let path: String
    public init(title: String, path: String) {
        self.title = title
        self.path = path
    }
}

public struct Hotlist: Sendable, Equatable {
    public private(set) var entries: [HotlistEntry]

    public init(entries: [HotlistEntry] = []) {
        self.entries = entries
    }

    /// Load from an INI document's `[Hotlist]` section.
    public init(ini: INIDocument) {
        let count = Int(ini.value(section: "Hotlist", key: "Count") ?? "") ?? 0
        var result: [HotlistEntry] = []
        for i in 0..<max(0, count) {
            let path = ini.value(section: "Hotlist", key: "Entry\(i)Path") ?? ""
            let title = ini.value(section: "Hotlist", key: "Entry\(i)Title") ?? (path as NSString).lastPathComponent
            // Keep separators (title "-", no path); skip only truly empty rows.
            guard !path.isEmpty || title == "-" else { continue }
            result.append(HotlistEntry(title: title, path: path))
        }
        self.entries = result
    }

    /// Write into an INI document's `[Hotlist]` section (replacing prior entries).
    public func write(to ini: inout INIDocument) {
        // Remove stale entries beyond the new count.
        let previous = Int(ini.value(section: "Hotlist", key: "Count") ?? "") ?? 0
        ini.set(String(entries.count), section: "Hotlist", key: "Count")
        for (i, entry) in entries.enumerated() {
            ini.set(entry.title, section: "Hotlist", key: "Entry\(i)Title")
            ini.set(entry.path, section: "Hotlist", key: "Entry\(i)Path")
        }
        if previous > entries.count {
            for i in entries.count..<previous {
                ini.remove(section: "Hotlist", key: "Entry\(i)Title")
                ini.remove(section: "Hotlist", key: "Entry\(i)Path")
            }
        }
    }

    public mutating func add(title: String, path: String) {
        entries.append(HotlistEntry(title: title, path: path))
    }

    public mutating func remove(at index: Int) {
        guard entries.indices.contains(index) else { return }
        entries.remove(at: index)
    }

    /// Whether a path is already bookmarked.
    public func contains(path: String) -> Bool {
        entries.contains { $0.path == path }
    }

    // MARK: - Editing (F-061 manager)

    /// Replace the whole list (used by the manager dialog when saving).
    public mutating func setEntries(_ newEntries: [HotlistEntry]) {
        entries = newEntries
    }

    /// Reorder an entry, keeping the list otherwise intact.
    public mutating func move(from source: Int, to destination: Int) {
        guard entries.indices.contains(source), entries.indices.contains(destination),
              source != destination else { return }
        let e = entries.remove(at: source)
        entries.insert(e, at: destination)
    }

    /// Change an entry's title (a "Folder\Item" title nests it under submenus;
    /// a title of "-" is a separator).
    public mutating func setTitle(_ title: String, at index: Int) {
        guard entries.indices.contains(index) else { return }
        entries[index] = HotlistEntry(title: title, path: entries[index].path)
    }

    /// Change an entry's path.
    public mutating func setPath(_ path: String, at index: Int) {
        guard entries.indices.contains(index) else { return }
        entries[index] = HotlistEntry(title: entries[index].title, path: path)
    }
}
