// SPDX-License-Identifier: Apache-2.0
// TextPipeHistory.swift - Remember the filter commands the user typed (F-356).
//
// The editor's other histories (the command line, the selection mask) live in memory and are gone at
// quit. That is tolerable for a glob; it is not for `jq -r '.items[] | .name'`, which takes a minute to
// get right and is wanted again next week. So this one is on disk.
//
// A plain newline-delimited file rather than a section in the INI: a command line contains `=`, `#`,
// `;` and quotes — every character an INI parser assigns a meaning to. One command per line needs no
// escaping at all, which is also why every shell stores its history this way.

import Foundation

/// The recently used editor filter commands, most recent first.
public struct TextPipeHistory: Sendable {
    /// How many commands are kept. Enough to hold a working session's worth; short enough that the
    /// dropdown stays a list a person can scan.
    public static let limit = 20

    private let url: URL

    public init(configRoot: URL) {
        self.url = configRoot.appendingPathComponent("editor-filters.txt")
    }

    /// The stored commands, most recent first. Missing file, unreadable file and blank lines all read
    /// as "no history" — a history is a convenience and must never be an error.
    public func load() -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Put `command` at the front, removing an earlier identical entry so re-running a command
    /// promotes it instead of duplicating it.
    public func remember(_ command: String) {
        let entry = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entry.isEmpty, !entry.contains("\n") else { return }
        var entries = load().filter { $0 != entry }
        entries.insert(entry, at: 0)
        let text = entries.prefix(Self.limit).joined(separator: "\n") + "\n"
        // 0600: a command line can carry a host name, a bucket, a token in an argument. It is the
        // user's own shell history, and nobody else's business.
        try? text.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// Commands offered before the user has a history of their own.
    ///
    /// Chosen to answer "what is this box for" in one glance, from the two audiences' daily tools: a
    /// log, a JSON blob, a column-aligned table, a certificate.
    public static let suggestions = [
        "sort", "sort -u", "sort | uniq -c | sort -rn", "jq .", "column -t",
        "grep -v '^#'", "base64 -d", "tr -d '\\r'", "sed 's/  */ /g'"
    ]
}
