// SPDX-License-Identifier: Apache-2.0
// RecentLines.swift - A most-recently-used list of one-line strings, on disk (F-406).
//
// Extracted from `TextPipeHistory`, which had all of this for the editor's filter commands and was the
// second place to want it: a Find Files dialog whose "Search for" and "Find text" fields forget every
// term at close is the same complaint as an editor that forgets a `jq` expression. One implementation,
// so the promote-on-reuse rule and the file's permissions cannot drift apart between them.
//
// A plain newline-delimited file rather than a section in the INI: what the user types here contains
// `=`, `#`, `;`, `[` and quotes — every character an INI parser assigns a meaning to. One entry per line
// needs no escaping at all, which is also why every shell stores its history this way. The one thing
// that cannot be stored is an entry containing a newline, and `remember` refuses those rather than
// writing a line that would read back as two.

import Foundation

/// The recently used entries of one field, most recent first.
public struct RecentLines: Sendable {
    /// How many entries are kept. Enough to hold a working session's worth; short enough that the
    /// dropdown stays a list a person can scan.
    public static let defaultLimit = 20

    private let url: URL
    private let limit: Int

    public init(url: URL, limit: Int = RecentLines.defaultLimit) {
        self.url = url
        self.limit = max(1, limit)
    }

    /// The stored entries, most recent first. Missing file, unreadable file and blank lines all read as
    /// "no history" — a history is a convenience and must never be an error.
    public func load() -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Put `entry` at the front, removing an earlier identical one so re-using a term promotes it
    /// instead of duplicating it.
    public func remember(_ entry: String) {
        let entry = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entry.isEmpty, !entry.contains("\n") else { return }
        var entries = load().filter { $0 != entry }
        entries.insert(entry, at: 0)
        let text = entries.prefix(limit).joined(separator: "\n") + "\n"
        // 0600: what somebody searches for is as telling as the files it finds — a name, a bucket, a
        // token they went looking for. It is theirs, and nobody else's business.
        try? text.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// Forget everything. The file goes rather than being emptied: an empty file left behind still says
    /// what it was for, and "cleared" should leave nothing to read.
    public func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
