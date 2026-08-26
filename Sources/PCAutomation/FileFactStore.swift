// SPDX-License-Identifier: Apache-2.0
// FileFactStore.swift — the short facts the assistant works out about a file, kept for reuse.
//
// A summary is a paragraph; these are the three words a file manager can actually put in a
// column and in a file name: what kind of thing it is, what it is about, and the date it
// concerns. They cost a generation each to produce, so they are kept — and, unlike a summary,
// they are short enough to be useful as a rename token.
//
// That is the point of storing them at all. The multi-rename mask resolves `[=provider.field]`
// from any content-field provider, so once these are on disk a mask like
// `[=ai_column.ai_topic]-[Y]-[M].[E]` renames by what the files ARE, using the app's existing
// rename engine and dialog rather than anything new.
//
// Same shape and same fingerprint as `SummaryStore`, deliberately: a content field is asked for
// a value per row while the panel draws, so it can only ever read a cache — and it must key that
// cache exactly as the writer did. The two used to disagree on the fingerprint and the column
// stayed empty for every file, which is why the format lives in one place now.

import Foundation

/// What the assistant worked out about one file. Every field may be empty: a model that does not
/// know a document's date should say nothing rather than invent one.
public struct AIFileFacts: Codable, Sendable, Equatable {
    /// The category it belongs to, from a set the assistant chose over the whole selection.
    public var kind: String
    /// Two or three words naming what it is about, lower case — filename-shaped.
    public var topic: String
    /// The date the document concerns, `YYYY-MM-DD`, or empty.
    public var date: String

    public init(kind: String = "", topic: String = "", date: String = "") {
        self.kind = kind
        self.topic = topic
        self.date = date
    }

    public var isEmpty: Bool { kind.isEmpty && topic.isEmpty && date.isEmpty }
}

public struct FileFactStore: Sendable {
    public let url: URL
    public let cap: Int

    public init(url: URL, cap: Int = 2000) {
        self.url = url
        self.cap = cap
    }

    private struct Record: Codable {
        var path: String
        var facts: AIFileFacts
        var at: Double
    }

    /// The facts stored for a fingerprint (`path|size|modified`), if any.
    public func facts(for fingerprint: String) -> AIFileFacts? {
        load()[fingerprint]?.facts
    }

    /// The same fingerprint `SummaryStore` uses, so both caches age out of date together and a
    /// reader comparing them is comparing the same file.
    public static func fingerprint(path: String, size: Int64, modified: Double) -> String {
        SummaryStore.fingerprint(path: path, size: size, modified: modified)
    }

    /// The fingerprint for a file on disk, or nil when it cannot be stat'd.
    ///
    /// Here rather than at each call site: the writer, the panel column and the rename mask all
    /// have to agree on this string, and the last time two of them worked it out separately they
    /// disagreed on both the epoch and the rounding, so the column was empty for every file.
    public static func fingerprint(forFileAt path: String) -> String? {
        guard let a = try? FileManager.default.attributesOfItem(atPath: path) else { return nil }
        return fingerprint(path: path,
                           size: (a[.size] as? NSNumber)?.int64Value ?? 0,
                           modified: (a[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate ?? 0)
    }

    public func save(_ facts: AIFileFacts, for fingerprint: String, path: String) {
        guard !facts.isEmpty else { return }
        var records = load()
        records[fingerprint] = Record(path: path, facts: facts,
                                      at: Date().timeIntervalSince1970)
        if records.count > cap {
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
