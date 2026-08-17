// SPDX-License-Identifier: Apache-2.0
// TextPipeHistory.swift - Remember the filter commands the user typed (F-356).
//
// The editor's other histories (the command line, the selection mask) live in memory and are gone at
// quit. That is tolerable for a glob; it is not for `jq -r '.items[] | .name'`, which takes a minute to
// get right and is wanted again next week. So this one is on disk.
//
// The list itself is a `RecentLines` (F-406), which is where the file format, the promote-on-reuse rule
// and the 0600 permissions now live — the Find dialog's two fields wanted exactly the same thing.

import Foundation

/// The recently used editor filter commands, most recent first.
public struct TextPipeHistory: Sendable {
    /// How many commands are kept.
    public static let limit = RecentLines.defaultLimit

    private let entries: RecentLines

    public init(configRoot: URL) {
        self.entries = RecentLines(url: configRoot.appendingPathComponent("editor-filters.txt"),
                                   limit: Self.limit)
    }

    /// The stored commands, most recent first; empty when there is no history to read.
    public func load() -> [String] { entries.load() }

    /// Put `command` at the front, removing an earlier identical entry so re-running a command
    /// promotes it instead of duplicating it.
    public func remember(_ command: String) { entries.remember(command) }

    /// Commands offered before the user has a history of their own.
    ///
    /// Chosen to answer "what is this box for" in one glance, from the two audiences' daily tools: a
    /// log, a JSON blob, a column-aligned table, a certificate.
    public static let suggestions = [
        "sort", "sort -u", "sort | uniq -c | sort -rn", "jq .", "column -t",
        "grep -v '^#'", "base64 -d", "tr -d '\\r'", "sed 's/  */ /g'"
    ]
}
