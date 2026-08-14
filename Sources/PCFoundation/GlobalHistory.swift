// SPDX-License-Identifier: Apache-2.0
// GlobalHistory.swift - The model behind the global history palette (F-402).
//
// One bounded, weighted list of the places and things the user has been in: folders visited, files
// opened, file operations carried out, shell commands run. Not a per-panel back/forward stack — that is
// `NavigationHistory`, which answers "where was I a moment ago" and is deliberately linear. This
// answers "where have I been at all, and what did I do", which is a different question and needs
// frequency as well as recency: the folder visited forty times last week beats the one visited once
// this morning, and that ordering is the whole reason a history is faster than typing a path.
//
// Pure and IO-free: the store that owns the file is `HistoryStore`, the recording lives in the app.
// Everything here — the weighting, the de-duplication, the eviction and the round-trip through one INI
// value — is unit-testable without a window or a disk.

import Foundation

/// What a history entry is. The palette's filters are exactly these plus "all" and "pinned".
public enum HistoryKind: String, Sendable, CaseIterable {
    case folder
    case file
    case operation
    case command
}

/// Which panel an entry happened in. Empty for things that belong to no panel (a shell command).
public enum HistoryPanelSide: String, Sendable, Equatable {
    case left
    case right
}

public struct HistoryEntry: Sendable, Equatable {
    public let kind: HistoryKind
    /// Folder/file: the item itself. Operation: the directory it acted on. Command: the working directory.
    public let path: String
    /// Operation: what it was ("Copy 3 items"). Command: the command line. Otherwise empty.
    public let detail: String
    /// Everything needed to run an operation again, encoded by the caller; empty when there is nothing
    /// to repeat. Deliberately opaque here — the model must not learn what a copy is.
    public let payload: String
    public var lastUsed: Date
    public var useCount: Int
    public var pinned: Bool
    public var panel: HistoryPanelSide?

    public init(kind: HistoryKind, path: String, detail: String = "", payload: String = "",
                lastUsed: Date = Date(), useCount: Int = 1, pinned: Bool = false,
                panel: HistoryPanelSide? = nil) {
        self.kind = kind
        self.path = path
        self.detail = detail
        self.payload = payload
        self.lastUsed = lastUsed
        self.useCount = useCount
        self.pinned = pinned
        self.panel = panel
    }

    /// What makes two records the same thing, so a second visit counts rather than piling up.
    ///
    /// Per kind, because "the same" differs: a folder is its path; a shell command is its line, wherever
    /// it was run (that is what a shell history means by "the same command"); an operation is its label,
    /// its target and what it acted on, since two copies to one folder from different sources are two
    /// different things to repeat.
    public var identity: String {
        switch kind {
        case .folder, .file:
            return "\(kind.rawValue)\u{1}\(path)"
        case .command:
            return "\(kind.rawValue)\u{1}\(detail)"
        case .operation:
            return "\(kind.rawValue)\u{1}\(path)\u{1}\(detail)\u{1}\(payload)"
        }
    }

    /// The text the palette searches and shows. A file is matched on its whole path, so both "the folder
    /// I remember" and "the name I remember" find it.
    public var searchText: String {
        switch kind {
        case .folder, .file: return path
        case .command: return detail
        case .operation: return detail.isEmpty ? path : "\(detail) \(path)"
        }
    }

    /// Frecency: how recently *and* how often. Frequency alone buries this morning's work under last
    /// month's; recency alone makes the list a log, which is what the palette is meant to replace.
    ///
    /// Pinned entries are lifted above everything rather than merely boosted — a user who pinned a
    /// folder is saying "always near the top", and a boost large enough to mean that is indistinguishable
    /// from a constant.
    public func score(now: Date = Date()) -> Double {
        let age = now.timeIntervalSince(lastUsed)
        let recency: Double
        switch age {
        case ..<3_600:      recency = 8      // this hour
        case ..<86_400:     recency = 4      // today
        case ..<604_800:    recency = 2      // this week
        case ..<2_592_000:  recency = 1      // this month
        default:            recency = 0.5
        }
        return (Double(useCount) + 1) * recency + (pinned ? 1_000_000 : 0)
    }
}

public struct GlobalHistory: Sendable, Equatable {
    /// Newest first is *not* guaranteed; ask `ranked` or `chronological` for an order.
    public private(set) var entries: [HistoryEntry] = []

    /// How many unpinned entries are kept. Pinned ones are never evicted for being too many — a list
    /// the user curated is not overflow.
    public let capacity: Int

    public init(capacity: Int = 500, entries: [HistoryEntry] = []) {
        self.capacity = max(1, capacity)
        self.entries = entries
        evict()
    }

    /// How close together two records of the same thing count as one use.
    ///
    /// Not a nicety: one *user* action can legitimately arrive here twice. Opening a folder from the
    /// palette is a use of that entry, and the navigation it causes then reports the same folder again a
    /// moment later — through `loadPath`, which is asynchronous, so no "do not record while I do this"
    /// flag around the call can cover it. A refresh that reloads the same directory is the same shape.
    /// Counting those twice would quietly inflate exactly the number the ranking is built on.
    public static let coalesceWindow: TimeInterval = 2

    /// Record a use. An entry that is already known keeps its count and gains one, so the weighting
    /// survives; everything else about it (the panel it happened in, its payload) is refreshed, because
    /// the newest use is the truthful one. Two records of the same thing within ``coalesceWindow`` are
    /// one use — the timestamp moves, the count does not.
    public mutating func record(_ entry: HistoryEntry) {
        if let i = entries.firstIndex(where: { $0.identity == entry.identity }) {
            var existing = entries[i]
            let sameMoment = entry.lastUsed.timeIntervalSince(existing.lastUsed) < Self.coalesceWindow
            existing.lastUsed = max(existing.lastUsed, entry.lastUsed)
            if !sameMoment { existing.useCount += 1 }
            existing.panel = entry.panel ?? existing.panel
            entries[i] = existing
        } else {
            entries.append(entry)
        }
        evict()
    }

    public mutating func remove(identity: String) {
        entries.removeAll { $0.identity == identity }
    }

    /// Pin or unpin. Returns false if the entry is gone (the palette can then just refresh).
    @discardableResult
    public mutating func setPinned(_ pinned: Bool, identity: String) -> Bool {
        guard let i = entries.firstIndex(where: { $0.identity == identity }) else { return false }
        entries[i].pinned = pinned
        return true
    }

    public mutating func removeAll(keepingPinned: Bool = true) {
        entries = keepingPinned ? entries.filter(\.pinned) : []
    }

    /// Drop entries older than `days` (0 = keep forever). Pinned entries stay.
    ///
    /// Run on load rather than on a timer: a history nobody opened does not need tidying, and a rule
    /// applied at read time cannot delete something between two launches for no observable reason.
    public mutating func prune(olderThanDays days: Int, now: Date = Date()) {
        guard days > 0 else { return }
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        entries.removeAll { !$0.pinned && $0.lastUsed < cutoff }
    }

    /// Ranked by frecency, optionally filtered by kind and by a fuzzy query.
    ///
    /// A query of several words must match with *all* of them (`FuzzyMatch`), which is how "proj rep"
    /// finds `~/Projects/annual-report.txt` — and the match score is added to the frecency, so a better
    /// match wins among entries of similar standing rather than replacing the weighting entirely.
    public func ranked(kind: HistoryKind? = nil, pinnedOnly: Bool = false,
                       query: String = "", now: Date = Date()) -> [HistoryEntry] {
        var scored: [(HistoryEntry, Double)] = []
        for entry in entries {
            if let kind, entry.kind != kind { continue }
            if pinnedOnly, !entry.pinned { continue }
            var value = entry.score(now: now)
            if !query.isEmpty {
                guard let match = FuzzyMatch.score(query, in: entry.searchText) else { continue }
                value += Double(match)
            }
            scored.append((entry, value))
        }
        return scored.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            if $0.0.lastUsed != $1.0.lastUsed { return $0.0.lastUsed > $1.0.lastUsed }
            return $0.0.identity < $1.0.identity
        }.map(\.0)
    }

    /// Most recent first, ignoring frequency — the chronological half of the palette's "combined" view.
    public func chronological(kind: HistoryKind? = nil) -> [HistoryEntry] {
        entries.filter { kind == nil || $0.kind == kind }.sorted { $0.lastUsed > $1.lastUsed }
    }

    /// Evict the *worst* unpinned entries, not simply the oldest: a folder used forty times should not
    /// be lost because a hundred one-off visits happened after it.
    private mutating func evict() {
        let unpinned = entries.filter { !$0.pinned }
        guard unpinned.count > capacity else { return }
        let now = Date()
        let doomed = Set(unpinned.sorted { $0.score(now: now) < $1.score(now: now) }
            .prefix(unpinned.count - capacity).map(\.identity))
        entries.removeAll { doomed.contains($0.identity) }
    }
}

// MARK: - Persistence

/// One INI value holds the whole list, in the shape `WorkspaceCodec` established: control characters
/// between fields and records, because they cannot occur in a path, a label or a command line. 500
/// entries as 4000 individual INI keys would be the alternative, and every save would walk them all.
public enum HistoryCodec {
    private static let unit = "\u{1}"      // between fields of one entry
    private static let record = "\u{2}"    // between entries

    public static func encode(_ history: GlobalHistory) -> String {
        history.entries.map { e in
            [e.kind.rawValue, e.path, e.detail, e.payload,
             String(Int64(e.lastUsed.timeIntervalSince1970)), String(e.useCount),
             e.pinned ? "1" : "0", e.panel?.rawValue ?? ""].joined(separator: unit)
        }.joined(separator: record)
    }

    /// Inverse of `encode`. A record whose kind is unknown or whose path *and* detail are both empty is
    /// skipped; trailing fields are optional, so a file written before one of them existed still loads.
    public static func decode(_ string: String, capacity: Int = 500) -> GlobalHistory {
        guard !string.isEmpty else { return GlobalHistory(capacity: capacity) }
        let entries: [HistoryEntry] = string.components(separatedBy: record).compactMap { line in
            let f = line.components(separatedBy: unit)
            guard f.count >= 5, let kind = HistoryKind(rawValue: f[0]) else { return nil }
            guard !f[1].isEmpty || !f[2].isEmpty else { return nil }
            let time = Double(f[4]) ?? 0
            return HistoryEntry(kind: kind, path: f[1], detail: f[2], payload: f[3],
                                lastUsed: Date(timeIntervalSince1970: time),
                                useCount: f.count > 5 ? max(1, Int(f[5]) ?? 1) : 1,
                                pinned: f.count > 6 && f[6] == "1",
                                panel: f.count > 7 ? HistoryPanelSide(rawValue: f[7]) : nil)
        }
        return GlobalHistory(capacity: capacity, entries: entries)
    }
}
