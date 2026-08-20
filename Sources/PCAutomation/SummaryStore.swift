// SPDX-License-Identifier: Apache-2.0
// SummaryStore.swift — the assistant's file summaries, kept for the panel to show.
//
// `summarize_file` reads a whole file in slices and folds the slice summaries into one. That
// costs a generation per few kilobytes, so the result is worth keeping: asked twice, the
// assistant answers from the first run, and — the point of this file — the panel can show a
// column of what the assistant already knows about the files in a folder.
//
// A plain JSON map under the config root, keyed by path + size + modification time, so an
// edited file loses its stale summary instead of showing it. Capped, because a folder walk
// with the column switched on would otherwise grow it without end.

import Foundation

public struct SummaryStore: Sendable {
    public let url: URL
    public let cap: Int

    public init(url: URL, cap: Int = 1000) {
        self.url = url
        self.cap = cap
    }

    private struct Record: Codable {
        var path: String
        var summary: String
        var at: Double
    }

    /// The summary stored for a fingerprint (`path|size|modified`), if any.
    public func summary(for fingerprint: String) -> String? {
        load()[fingerprint]?.summary
    }

    /// The summary for a file, looked up by what the file is now. Used by the panel column,
    /// which knows a path, a size and a date but not the fingerprint string.
    public static func fingerprint(path: String, size: Int64, modified: Double) -> String {
        "\(path)|\(size)|\(modified)"
    }

    public func save(_ summary: String, for fingerprint: String, path: String) {
        var records = load()
        records[fingerprint] = Record(path: path, summary: summary,
                                      at: Date().timeIntervalSince1970)
        if records.count > cap {
            // Oldest out. A summary is a convenience, and the newest are the ones in view.
            for key in records.sorted(by: { $0.value.at < $1.value.at })
                .prefix(records.count - cap).map(\.key) {
                records[key] = nil
            }
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try? encoder.encode(records).write(to: url, options: .atomic)
    }

    private func load() -> [String: Record] {
        (try? Data(contentsOf: url)).flatMap {
            try? JSONDecoder().decode([String: Record].self, from: $0)
        } ?? [:]
    }
}
