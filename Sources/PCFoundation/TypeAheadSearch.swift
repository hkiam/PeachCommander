// SPDX-License-Identifier: Apache-2.0
// TypeAheadSearch.swift - Cursor "type to jump" matching in a panel (TODOS #64).
//
// Given the visible names, a typed query and a start index, find the next name that
// begins with the query (case- and diacritic-insensitive), wrapping around. Pure and
// unit-testable; the panel keeps the typed buffer + timeout and moves the cursor.

import Foundation

public enum TypeAheadSearch {
    /// Index of the next name that has `query` as a prefix, scanning forward from
    /// `from` (wrapping unless `wrap` is false). Nil if nothing matches.
    public static func match(names: [String], query: String, from: Int, wrap: Bool = true) -> Int? {
        guard !query.isEmpty, !names.isEmpty else { return nil }
        let count = names.count
        let start = min(max(0, from), count)
        for offset in 0..<count {
            let i = wrap ? (start + offset) % count : start + offset
            if !wrap && i >= count { break }
            if names[i].range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil {
                return i
            }
        }
        return nil
    }

    /// Every index whose name starts with `query`, in list order.
    ///
    /// The jump only ever needed "the next one"; showing the typed prefix needs "the second of five"
    /// as well, and a user who can see that count knows whether to keep typing or to step on. Same
    /// prefix rule as `match`, so the two can never disagree about what counts as a hit.
    public static func matches(names: [String], query: String) -> [Int] {
        guard !query.isEmpty else { return [] }
        return names.indices.filter {
            names[$0].range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil
        }
    }

    /// Where `index` sits among the matches for `query`, 1-based, or nil when it is not one of them.
    public static func position(of index: Int, names: [String], query: String) -> Int? {
        matches(names: names, query: query).firstIndex(of: index).map { $0 + 1 }
    }
}
