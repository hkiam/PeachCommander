// SPDX-License-Identifier: Apache-2.0
// WorkspaceJournal.swift - What was done in this workspace (F-499).
//
// Answers one question: *"what did I actually do while cleaning up the backups?"* — as a list, in
// order, with what each thing acted on and how it ended.
//
// ## Why this is not a filter over the global history
//
// `GlobalHistory` is right there and a `workspace` field would have been cheap. It is still the wrong
// structure, for three reasons that are about what it *is* rather than about taste:
//
//   1. **It de-duplicates by identity.** `record(_:)` finds an entry with the same identity and bumps
//      `useCount` instead of appending, so copying the same three files into the same folder twice
//      produces one row saying "used 2 times". A journal's entire value is the sequence and the
//      completeness of it; a structure whose defining behaviour is collapsing repeats cannot answer
//      "what did I do".
//   2. **It evicts by score, not by age.** Past 500 entries the *worst* unpinned ones are dropped —
//      and the 500 are shared by every workspace, so one busy afternoon sorting photos would evict
//      last week's backup work. A record that silently loses the middle of an afternoon is not a
//      record of anything.
//   3. **Retention has to be per workspace.** A journal must die exactly when its workspace is
//      deleted. In a shared, score-evicted list that is a filtering pass and a class of orphan bug;
//      with a file per workspace it is `rm`.
//
// Frecency is the right model for "where do I usually go" and a log is the right model for "what
// happened here". They are different questions, and the help page says so in one sentence.

import Foundation

public struct JournalEntry: Codable, Sendable, Equatable {

    public enum Kind: String, Codable, Sendable, CaseIterable {
        case navigation, operation, command, stash, scope
    }

    /// How it ended. `refused` has no counterpart in the global history at all, and is the entry that
    /// makes this worth opening: it is the only record that a scope stopped something.
    public enum Outcome: Codable, Sendable, Equatable {
        case done
        case failed(String)
        case refused(String)
    }

    public let kind: Kind
    public let at: Date
    /// What a person reads: "Copy 3 items", "cd ~/Archive/2019", "git status".
    public let label: String
    /// Where it happened.
    public let directory: String
    /// `HistoryOperation`'s encoding — deliberately the same, so "repeat" costs nothing new. Empty
    /// when there is nothing to repeat.
    public let payload: String
    public let outcome: Outcome

    public init(kind: Kind, at: Date = Date(), label: String, directory: String,
                payload: String = "", outcome: Outcome = .done) {
        self.kind = kind
        self.at = at
        self.label = label
        self.directory = directory
        self.payload = payload
        self.outcome = outcome
    }

    /// Did something go wrong or get stopped? The "Problems" filter is exactly this.
    public var isProblem: Bool {
        if case .done = outcome { return false }
        return true
    }

    public var reason: String? {
        switch outcome {
        case .done: return nil
        case .failed(let r), .refused(let r): return r
        }
    }
}

public struct WorkspaceJournal: Codable, Sendable, Equatable {

    /// Oldest first. Append-only apart from pruning.
    public private(set) var entries: [JournalEntry]

    /// Kept deliberately large. This is a record of what happened to somebody's files, and the cost of
    /// an entry is about a hundred bytes.
    public let capacity: Int

    public init(entries: [JournalEntry] = [], capacity: Int = 1000) {
        self.entries = entries
        self.capacity = max(1, capacity)
    }

    public var isEmpty: Bool { entries.isEmpty }
    public var count: Int { entries.count }

    /// Append, with one narrow coalescing rule and no others.
    ///
    /// **Two *consecutive* navigations to the same directory are one.** That is the only case where a
    /// second entry carries no information — walking into a folder and back out lands you where a
    /// single line already says you are. Everything else appends, including a repeated copy: it was
    /// two copies, and a journal that said "2×" would be answering a different question.
    public mutating func append(_ entry: JournalEntry) {
        if entry.kind == .navigation, let last = entries.last,
           last.kind == .navigation, last.directory == entry.directory, !last.isProblem {
            return
        }
        entries.append(entry)
        if entries.count > capacity { entries.removeFirst(entries.count - capacity) }
    }

    /// Drop entries older than `days`. **`days == 0` keeps everything**, which is the default and is
    /// deliberately different from the history's ninety days: a history is a convenience and may
    /// forget; a record of what was done to somebody's files should not forget by itself.
    public mutating func prune(olderThanDays days: Int, now: Date = Date()) {
        guard days > 0 else { return }
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        entries.removeAll { $0.at < cutoff }
    }

    public mutating func remove(at index: Int) {
        guard entries.indices.contains(index) else { return }
        entries.remove(at: index)
    }

    public mutating func removeAll() { entries.removeAll() }

    /// Newest first, filtered. The three filters are independent so the window can combine them.
    public func filtered(kind: JournalEntry.Kind? = nil,
                         problemsOnly: Bool = false,
                         query: String = "") -> [JournalEntry] {
        let needle = query.lowercased()
        return entries.reversed().filter { entry in
            if let kind, entry.kind != kind { return false }
            if problemsOnly, !entry.isProblem { return false }
            guard !needle.isEmpty else { return true }
            return entry.label.lowercased().contains(needle)
                || entry.directory.lowercased().contains(needle)
        }
    }

    /// Grouped by day, newest day first — how the window reads.
    public func grouped(calendar: Calendar = .current) -> [(day: Date, entries: [JournalEntry])] {
        var order: [Date] = []
        var byDay: [Date: [JournalEntry]] = [:]
        for entry in entries.reversed() {
            let day = calendar.startOfDay(for: entry.at)
            if byDay[day] == nil { order.append(day) }
            byDay[day, default: []].append(entry)
        }
        return order.map { (day: $0, entries: byDay[$0] ?? []) }
    }
}
