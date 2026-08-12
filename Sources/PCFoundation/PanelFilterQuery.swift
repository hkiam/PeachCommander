// SPDX-License-Identifier: Apache-2.0
// PanelFilterQuery.swift — what the quick filter's text means (F-397).
//
// The filter used to be one substring against the name. On a plugin mount that is the least of what
// a row says: in the process list the name is "kernel_task (0)" while the question is usually about
// the user, the state or the command line. Matching every column instead (F-395) answered those, and
// created a new problem — "1" matches half the PIDs, and "root" matches any command line that has
// "/root/" in it. A filter you cannot aim is a filter you stop trusting.
//
// So a term may name the column it applies to: "user:root", "state:R", "command:node". Terms are
// separated by spaces and ALL must match, which is what makes "user:root state:R" — the actual
// question, "what is root running right now" — expressible at all.
//
// Text without a "field:" prefix keeps working exactly as before, spaces included: "Google Chrome"
// is one substring and not two terms. That rule is what keeps the change invisible to anyone who
// never learns the syntax, and it is why the split happens only when a field term is present.
//
// Parsing lives here, apart from the panel, because it is the part with rules worth testing: which
// text is a field term, which field names exist, what an unknown field does (nothing special — it
// stays a plain substring, so a colon in a file name is not silently swallowed).

import Foundation

public struct PanelFilterQuery: Sendable, Equatable {
    /// One condition: a substring, optionally aimed at a single column.
    public struct Term: Sendable, Equatable {
        /// The column this term applies to (a field id like "taskman.user"), or nil for "anywhere".
        public let fieldID: String?
        /// The text to look for, lowercased.
        public let needle: String
        /// Wildcards were used, so the value must match the pattern rather than contain the text.
        public let isMask: Bool

        public init(fieldID: String?, needle: String, isMask: Bool) {
            self.fieldID = fieldID
            self.needle = needle
            self.isMask = isMask
        }

        public func matches(_ value: String) -> Bool {
            if isMask { return WildcardMask(needle.hasSuffix("*") ? needle : needle + "*").matches(value) }
            return value.lowercased().contains(needle)
        }
    }

    public let terms: [Term]
    /// True when at least one term names a column — the only case in which the text was split.
    public let isScoped: Bool

    public var isEmpty: Bool { terms.isEmpty }

    /// Parse `text` against the field ids the panel currently has.
    ///
    /// `fieldIDs` are full ids ("taskman.user", "name"); a term may name either the leaf ("user") or
    /// the whole id, case-insensitively. Anything else before a colon is not a field, so "12:30" and
    /// "Notes: draft" stay ordinary substrings.
    public static func parse(_ text: String, fieldIDs: [String]) -> PanelFilterQuery {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return PanelFilterQuery(terms: [], isScoped: false) }

        // leaf/full id → full id, lowercased on both sides so "User:" finds "taskman.user".
        var byName: [String: String] = [:]
        for id in fieldIDs {
            byName[id.lowercased()] = id
            if let leaf = id.split(separator: ".").last { byName[leaf.lowercased()] = id }
        }

        func fieldTerm(_ token: String) -> Term? {
            guard let colon = token.firstIndex(of: ":") else { return nil }
            let name = String(token[token.startIndex..<colon]).lowercased()
            guard let id = byName[name] else { return nil }
            let value = String(token[token.index(after: colon)...])
            guard !value.isEmpty else { return nil }   // "user:" alone filters nothing; treat as text
            return Term(fieldID: id, needle: value.lowercased(),
                        isMask: value.contains("*") || value.contains("?"))
        }

        let tokens = trimmed.split(separator: " ").map(String.init)
        let scoped = tokens.compactMap(fieldTerm)
        guard !scoped.isEmpty else {
            // No field named: the whole text is one substring, spaces and colons included.
            return PanelFilterQuery(
                terms: [Term(fieldID: nil, needle: trimmed.lowercased(),
                             isMask: trimmed.contains("*") || trimmed.contains("?"))],
                isScoped: false)
        }
        // Leftovers become free-text terms, so "root node" next to "state:R" still narrows.
        let free = tokens.filter { fieldTerm($0) == nil }
            .map { Term(fieldID: nil, needle: $0.lowercased(),
                        isMask: $0.contains("*") || $0.contains("?")) }
        return PanelFilterQuery(terms: scoped + free, isScoped: true)
    }

    public init(terms: [Term], isScoped: Bool) {
        self.terms = terms
        self.isScoped = isScoped
    }

    /// Does a row match? `value` resolves one field id; `anywhere` is asked for unaimed terms and
    /// answers with everything the row shows (name included).
    public func matches(value: (String) -> String?, anywhere: () -> [String]) -> Bool {
        var cachedAnywhere: [String]?
        for term in terms {
            if let id = term.fieldID {
                guard term.matches(value(id) ?? "") else { return false }
            } else {
                let all = cachedAnywhere ?? anywhere()
                cachedAnywhere = all
                guard all.contains(where: { term.matches($0) }) else { return false }
            }
        }
        return true
    }
}
