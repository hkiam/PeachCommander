// SPDX-License-Identifier: Apache-2.0
// FindFilesHistory.swift - What the Find Files dialog's two search fields remember (F-406).
//
// Two lists, not one: a name mask and a content term are different kinds of thing, and a dropdown that
// offered `*.log` next to `TODO(` would make both fields worse. Each is a `RecentLines`, so the
// promote-on-reuse rule and the file permissions are the same ones the editor's filter history uses.
//
// Separate files rather than two sections of one, for the same reason `RecentLines` is not INI: a search
// term is arbitrary text, and a format with no delimiters to escape cannot be corrupted by one.

import Foundation

/// The Find Files dialog's per-field histories, most recent first.
public struct FindFilesHistory: Sendable {
    /// "Search for:" — name masks, e.g. `*.swift`.
    public let names: RecentLines
    /// "Find text:" — content terms, including hex strings when hex mode was on.
    public let texts: RecentLines

    public init(configRoot: URL, limit: Int = RecentLines.defaultLimit) {
        self.names = RecentLines(url: configRoot.appendingPathComponent("find-names.txt"), limit: limit)
        self.texts = RecentLines(url: configRoot.appendingPathComponent("find-texts.txt"), limit: limit)
    }

    /// Forget both lists. One call, because the dialog offers one "clear" and a half-cleared history
    /// would be a puzzle rather than a state anybody asked for.
    public func clear() {
        names.clear()
        texts.clear()
    }
}
