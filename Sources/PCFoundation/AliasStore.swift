// SPDX-License-Identifier: Apache-2.0
// AliasStore.swift - Command-line aliases (F-256).
//
// User-defined shortcuts for the panel command line, read from `aliases.ini`
// (`name = expansion` per line; `;`/`#` comments and `[section]` headers ignored).
// When a command line is run, its FIRST token is replaced by the alias expansion
// (remaining arguments are appended) — so `gs -s` with `gs = git status` runs
// `git status -s`, and `dl` with `dl = cd ~/Downloads` changes directory. The
// expansion may itself be an internal `cm_`/`em_` command.

import Foundation

public struct AliasStore: Sendable {
    private let map: [String: String]

    public init(parsing text: String) {
        var m: [String: String] = [:]
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix(";") || line.hasPrefix("#") || line.hasPrefix("[") { continue }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let name = line[..<eq].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if !name.isEmpty, !value.isEmpty { m[name] = value }
        }
        map = m
    }

    public var isEmpty: Bool { map.isEmpty }

    /// The raw expansion registered for `name`, or nil.
    public func expansion(for name: String) -> String? { map[name] }

    /// Expand `line` if its first whitespace-separated token is a known alias;
    /// otherwise return it unchanged. Only the leading token is substituted.
    public func expand(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return line }
        if let space = trimmed.firstIndex(of: " ") {
            let head = String(trimmed[..<space])
            let rest = trimmed[trimmed.index(after: space)...].trimmingCharacters(in: .whitespaces)
            guard let exp = map[head] else { return line }
            return rest.isEmpty ? exp : exp + " " + rest
        }
        return map[trimmed] ?? line
    }
}
