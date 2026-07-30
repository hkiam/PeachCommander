// SPDX-License-Identifier: Apache-2.0
// MemoryStore.swift — a tiny long-term memory for the assistant (KI-04).
//
// The chat's sessions persist a conversation; this is cross-session knowledge the
// agent can deliberately save and look up ("remember" / "recall" tools). A flat JSON
// list under the config root — deliberately simple; a SQLite/vector store is a later
// upgrade. Substring recall, most-recent-first, capped so it can't grow unbounded.

import Foundation

public struct MemoryStore: Sendable {
    public let url: URL
    public let cap: Int
    public init(url: URL, cap: Int = 500) { self.url = url; self.cap = cap }

    private struct Note: Codable { var text: String; var at: Double }

    /// Save a note (deduped against an identical most-recent entry).
    public func add(_ text: String, at: Double) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var notes = load()
        if notes.last?.text == t { return }
        notes.append(Note(text: t, at: at))
        if notes.count > cap { notes.removeFirst(notes.count - cap) }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(notes).write(to: url, options: .atomic)
    }

    /// Notes matching `query` (case-insensitive substring; empty = all), newest first.
    public func recall(_ query: String, limit: Int) -> [String] {
        let q = query.lowercased()
        let matched = q.isEmpty ? load() : load().filter { $0.text.lowercased().contains(q) }
        return Array(matched.suffix(max(1, limit)).reversed().map(\.text))
    }

    private func load() -> [Note] {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([Note].self, from: $0) } ?? []
    }
}
