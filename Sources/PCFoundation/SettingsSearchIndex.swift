// SPDX-License-Identifier: Apache-2.0
// SettingsSearchIndex.swift - Finding a setting by name, across all the pages it could be on (F-408).
//
// Sixteen pages, and the answer to "where is the option for X" was to remember which one. This is the
// part of the answer that has no views in it: a list of what each page offers, and a ranking over it —
// so the ordering can be checked without a window, which is where a search field is normally wrong in a
// way nobody can reproduce.
//
// Matching is *substring*, not the subsequence matching `FuzzyMatch` does for the history palette
// (F-402), and that is a deliberate difference between two searches in one app. A path is typed as an
// abbreviation — "adr" for `dev-report` — and the candidates are hundreds of long strings where scattered
// letters are still a useful signal. A settings label is read, not abbreviated, and the first version
// here did use `FuzzyMatch`: measured in the running app, "hidden" returned "Eine Dateisuche im
// Betrachter fortsetzen" and four more results whose only claim was containing h, i, d, d, e, n in that
// order. Substring matching returns the option or nothing, which is what "search by name" means.
//
// What the score adds is *where* a match landed: a hit at the start of a word beats one inside one, the
// control's own name beats the page title, and both beat the explanatory note underneath — otherwise a
// paragraph mentioning "colour" outranks the colour setting itself.

import Foundation

/// One searchable setting: what it is called, which page it lives on, and the words that should also
/// find it without being shown.
public struct SettingsSearchEntry: Equatable, Sendable {
    /// The control's own label, as the page shows it ("Keep a backup copy (.bak) …").
    public let name: String
    /// The page it lives on ("Edit/View") — shown beside the name and searchable itself.
    public let page: String
    /// Findable but not shown: the note under the control, a popup's item titles, the words of the
    /// action it calls (so an English term still finds a translated label).
    public let keywords: [String]
    /// Opaque handle back to whatever the caller wants to do with this entry. The index never
    /// interprets it, which is what keeps AppKit out of here.
    public let ref: Int

    public init(name: String, page: String, keywords: [String] = [], ref: Int) {
        self.name = name
        self.page = page
        self.keywords = keywords
        self.ref = ref
    }
}

/// A searchable list of settings, ranked by how well each one matches.
public struct SettingsSearchIndex: Sendable {
    /// How many results a search returns. A list this length is scannable; past it the user is better
    /// served by typing a second word, which narrows rather than reorders.
    public static let defaultLimit = 25

    public let entries: [SettingsSearchEntry]

    public init(_ entries: [SettingsSearchEntry] = []) {
        self.entries = entries
    }

    public var isEmpty: Bool { entries.isEmpty }

    /// The entries matching `query`, best first. An empty (or whitespace) query matches nothing: the
    /// caller shows the pages themselves in that state, not all hundred settings at once.
    ///
    /// Every word of the query must appear *somewhere* in the entry — name, page or keywords — so
    /// "hidden display" finds the hidden-files option on the Display page while "hidden zip" finds
    /// nothing. Case and diacritics are ignored, because "grosse" has to find "Größe".
    public func search(_ query: String, limit: Int = SettingsSearchIndex.defaultLimit) -> [SettingsSearchEntry] {
        let words = Self.fold(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return [] }
        var scored: [(entry: SettingsSearchEntry, score: Int, index: Int)] = []
        for (index, entry) in entries.enumerated() {
            var total = 0
            for word in words {
                guard let best = Self.score(word, in: entry) else { total = -1; break }
                total += best
            }
            guard total >= 0 else { continue }
            scored.append((entry, total, index))
        }
        // Index as the tie-break, because Swift's sort is not stable and two settings with the same
        // score would otherwise change places between keystrokes — a list that reorders under the
        // cursor is worse than one that is slightly mis-ranked.
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }
        return scored.prefix(limit).map(\.entry)
    }

    /// The best score for one query word against one entry, or nil when the word is nowhere in it.
    ///
    /// The weights are ratios rather than measurements: a hit in the name is worth about three in a note
    /// and the page title sits between them, which is enough to put the setting called "Colors" above
    /// every setting whose note mentions colours, and to let a page name gather its own settings without
    /// burying a control actually called that.
    private static func score(_ word: String, in entry: SettingsSearchEntry) -> Int? {
        var best: Int?
        func consider(_ field: String, weight: Int) {
            guard let value = hit(word, field) else { return }
            let weighted = value * weight
            if best == nil || weighted > best! { best = weighted }
        }
        consider(entry.name, weight: 3)
        consider(entry.page, weight: 2)
        for keyword in entry.keywords { consider(keyword, weight: 1) }
        return best
    }

    /// How good a substring hit is: at the start of the field, at the start of a word, or inside one —
    /// and the earlier and the shorter, the better.
    ///
    /// Shorter wins because the short label is nearly always the setting itself: "Colors" against the
    /// sentence explaining what the colours apply to.
    private static func hit(_ word: String, _ field: String) -> Int? {
        let folded = fold(field)
        guard let range = folded.range(of: word) else { return nil }
        let offset = folded.distance(from: folded.startIndex, to: range.lowerBound)
        var score = 100
        if offset == 0 {
            score += 60
        } else {
            let before = folded[folded.index(before: range.lowerBound)]
            // A word boundary is anything that is not part of a word: a space, a bracket, a dash, a dot.
            if !before.isLetter && !before.isNumber { score += 40 }
        }
        score -= min(40, offset)                       // earlier in the string is better
        score -= min(30, folded.count / 8)             // a short label beats a paragraph
        return score
    }

    /// Case- and diacritic-insensitive, so a query typed in a hurry still matches.
    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
