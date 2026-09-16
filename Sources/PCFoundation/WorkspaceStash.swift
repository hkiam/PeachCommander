// SPDX-License-Identifier: Apache-2.0
// WorkspaceStash.swift - A workspace's collecting basket (F-499).
//
// The answer to the thing that actually happens while tidying up: you are three folders deep in the
// backups, you find something that belongs to an entirely different job, and there is nowhere to put
// it. A selection cannot help — it ends at the folder — so today the choice is to break off what you
// were doing or to remember the file and hope.
//
// A stash is a list of file references that belongs to a workspace, survives navigation, restarts and
// everything else, and is filled over hours: drag a file onto another workspace's chip and it lands
// there; press ⌃⌘A and the selection lands here. Then one operation on the lot.
//
// **Paths, not security-scoped bookmarks.** A bookmark silently follows a file to a new name and a new
// folder, which for most features is the point and for this one is exactly wrong: a basket that
// quietly re-aims at a renamed file is a basket you cannot trust with a delete. A stash points at a
// path; when the path stops resolving it says so and waits.
//
// **Nothing is ever removed automatically.** A file missing because a volume is not mounted has to
// come back when it is, so a stale entry is shown struck through rather than pruned. Guessing that it
// is gone for good is the one decision this type is not entitled to make.

import Foundation

/// One file in a workspace's basket.
public struct StashItem: Codable, Sendable, Equatable {
    /// Absolute, exactly as it was when added. **Never rewritten.**
    public let path: String
    public let addedAt: Date
    /// Optional, the user's own note about why this is here.
    public var note: String

    public init(path: String, addedAt: Date = Date(), note: String = "") {
        self.path = path
        self.addedAt = addedAt
        self.note = note
    }

    /// The leaf name, for display.
    public var name: String { (path as NSString).lastPathComponent }
    /// The folder it came from, for the second column — two files called `report.pdf` from different
    /// folders are the normal case here, not the exception.
    public var folder: String { (path as NSString).deletingLastPathComponent }

    private enum CodingKeys: String, CodingKey { case path, addedAt, note }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(path, forKey: .path)
        try c.encode(addedAt, forKey: .addedAt)
        if !note.isEmpty { try c.encode(note, forKey: .note) }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(path: try c.decode(String.self, forKey: .path),
                  addedAt: try c.decodeIfPresent(Date.self, forKey: .addedAt) ?? Date(),
                  note: try c.decodeIfPresent(String.self, forKey: .note) ?? "")
    }
}

/// The basket itself: an ordered list with the path as identity.
public struct WorkspaceStash: Codable, Sendable, Equatable {
    public private(set) var items: [StashItem]

    public init(items: [StashItem] = []) { self.items = items }

    public var isEmpty: Bool { items.isEmpty }
    public var count: Int { items.count }

    /// Add paths, skipping ones already here.
    ///
    /// Insertion order, not sorted: the order things were found in is information, and a basket that
    /// reshuffles itself when you add to it is one you have to re-read every time.
    ///
    /// Returns how many were added and how many were already in, because "3 added, 1 already there"
    /// is a different thing to tell somebody than "3 added" — the second leaves them wondering where
    /// the fourth went.
    @discardableResult
    public mutating func add(_ paths: [String], at date: Date = Date()) -> (added: Int, duplicates: Int) {
        var added = 0, duplicates = 0
        var known = Set(items.map(\.path))
        for path in paths {
            guard !path.isEmpty else { continue }
            if known.contains(path) { duplicates += 1; continue }
            items.append(StashItem(path: path, addedAt: date))
            known.insert(path)
            added += 1
        }
        return (added, duplicates)
    }

    public mutating func remove(paths: Set<String>) {
        items.removeAll { paths.contains($0.path) }
    }

    public mutating func removeAll() { items.removeAll() }

    public mutating func setNote(_ note: String, for path: String) {
        guard let i = items.firstIndex(where: { $0.path == path }) else { return }
        items[i].note = note
    }

    /// Split into what is still there and what is not.
    ///
    /// The existence test is supplied by the caller so the whole of this type stays testable without
    /// touching a disk — and so the app can decide what "exists" means for a path inside an archive
    /// or on a mount later on, without this type learning about either.
    public func partition(by exists: (String) -> Bool) -> (live: [StashItem], stale: [StashItem]) {
        var live: [StashItem] = [], stale: [StashItem] = []
        for item in items { exists(item.path) ? live.append(item) : stale.append(item) }
        return (live, stale)
    }
}
