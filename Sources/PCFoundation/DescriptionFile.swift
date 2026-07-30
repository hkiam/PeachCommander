// SPDX-License-Identifier: Apache-2.0
// DescriptionFile.swift - descript.ion comment file (SPEC-016 §7).
//
// Total Commander stores per-file comments in a "descript.ion" file in each
// directory: one line per file, "<name> <comment>", with the name wrapped in
// double quotes when it contains spaces. This is the pure parse/generate layer;
// reading/writing the actual file goes through the VFS (CommentStore).

import Foundation

public struct DescriptionFile: Equatable, Sendable {
    /// filename → comment (never stores empty comments).
    public private(set) var comments: [String: String]

    public init() { comments = [:] }

    public init(parsing text: String) {
        var map: [String: String] = [:]
        for rawLine in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = String(rawLine)
            guard let (name, comment) = Self.parseLine(line), !comment.isEmpty else { continue }
            map[name] = comment
        }
        comments = map
    }

    public func comment(for name: String) -> String? { comments[name] }

    public mutating func setComment(_ comment: String?, for name: String) {
        let trimmed = comment?.trimmingCharacters(in: .whitespaces) ?? ""
        if trimmed.isEmpty { comments[name] = nil } else { comments[name] = trimmed }
    }

    /// Serialize to descript.ion text (names sorted; spaces → quoted name).
    public func serialized() -> String {
        var lines: [String] = []
        for name in comments.keys.sorted() {
            guard let comment = comments[name] else { continue }
            let key = name.contains(" ") ? "\"\(name)\"" : name
            lines.append("\(key) \(comment)")
        }
        return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
    }

    public var isEmpty: Bool { comments.isEmpty }

    // MARK: - Line parsing

    /// Parse a single line into (name, comment). Handles a quoted name with spaces.
    static func parseLine(_ line: String) -> (name: String, comment: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("\"") {
            // "name with spaces" comment
            let afterQuote = trimmed.index(after: trimmed.startIndex)
            guard let closing = trimmed[afterQuote...].firstIndex(of: "\"") else { return nil }
            let name = String(trimmed[afterQuote..<closing])
            let comment = String(trimmed[trimmed.index(after: closing)...]).trimmingCharacters(in: .whitespaces)
            return (name, comment)
        } else {
            guard let sep = trimmed.firstIndex(of: " ") else { return (trimmed, "") }
            let name = String(trimmed[trimmed.startIndex..<sep])
            let comment = String(trimmed[trimmed.index(after: sep)...]).trimmingCharacters(in: .whitespaces)
            return (name, comment)
        }
    }
}
