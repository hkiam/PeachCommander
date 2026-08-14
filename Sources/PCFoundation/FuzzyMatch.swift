// SPDX-License-Identifier: Apache-2.0
// FuzzyMatch.swift - Subsequence matching with a score, for the history palette's search (F-402).
//
// The palette has to answer while the user is still typing, so this is a single greedy left-to-right
// pass rather than an optimal alignment: for the strings involved (a path, a command line) the greedy
// match and the best match agree, and the cost of being wrong is a slightly different order, not a
// missing result.
//
// What the score encodes is what makes a fuzzy list feel right or useless:
//
//   * a run of consecutive characters is worth far more than the same characters scattered,
//   * a character at the start of a word — after `/`, `-`, `_`, `.`, a space, or at a capital in
//     camelCase — is worth more than one in the middle, which is what makes "adr" find
//     `Application Support/dev-report` rather than the first path containing an a, a d and an r,
//   * matching inside the *last* path component beats matching in the directories above it, because
//     that is what the user is usually remembering, and
//   * skipped characters cost a little, so a short candidate beats a long one containing the same match.
//
// Case-insensitive throughout: a query is typed in a hurry.

import Foundation

public enum FuzzyMatch {

    /// Score `pattern` against `candidate`, or nil when it is not a subsequence at all.
    ///
    /// A pattern of several whitespace-separated words must match with all of them, each anywhere in the
    /// candidate — "proj rep" finds `~/Projects/annual-report.txt`. Word order is not significant, so the
    /// user does not have to remember which part of the path came first.
    public static func score(_ pattern: String, in candidate: String) -> Int? {
        let words = pattern.split(whereSeparator: { $0.isWhitespace })
        guard !words.isEmpty else { return 0 }
        var total = 0
        for word in words {
            guard let s = scoreOne(Array(word.lowercased()), in: candidate) else { return nil }
            total += s
        }
        return total
    }

    /// True when every word of `pattern` is a subsequence of `candidate` (no scoring).
    public static func matches(_ pattern: String, in candidate: String) -> Bool {
        score(pattern, in: candidate) != nil
    }

    /// Two passes, and the reason is a defect this had on its first run in the real app.
    ///
    /// A single greedy left-to-right pass over a whole path spends the pattern's first characters on
    /// whatever happens to appear early — in `/private/tmp/…/PeachCommander/…/report.txt` the `r` and `e`
    /// of "report" were found in "p**r**ivat**e**", and the clean run in the file's own name was never
    /// reached. Searching for "report" then put `report.txt` *third*, behind two folders that merely
    /// contained those letters somewhere. Measured, not reasoned about.
    ///
    /// So the last path component is scored on its own as well, and the better of the two wins. There is
    /// deliberately no *flat* bonus for having matched the name: one was tried and it made "adr" in
    /// `/xxaxxdxxrxx` beat `/Application Support/dev-report`, which is the opposite of the point. The
    /// credit a name match deserves it already earns — the per-character in-name credit and the
    /// consecutive-run bonus below — and the second pass only stops the first one from wasting the
    /// pattern before it gets there.
    private static func scoreOne(_ needle: [Character], in candidate: String) -> Int? {
        guard !needle.isEmpty else { return 0 }
        let chars = Array(candidate)
        let nameStart = (chars.lastIndex(of: "/").map { $0 + 1 }) ?? 0

        let whole = greedy(needle, chars, from: 0, nameStart: nameStart)
        // Only worth trying when there is a name to try: for a command line the two are the same pass.
        let name = nameStart > 0 ? greedy(needle, chars, from: nameStart, nameStart: nameStart) : nil
        switch (whole, name) {
        case (nil, nil):        return nil
        case (let w?, nil):     return w
        case (nil, let n?):     return n
        case (let w?, let n?):  return max(w, n)
        }
    }

    private static func greedy(_ needle: [Character], _ chars: [Character], from start: Int,
                               nameStart: Int) -> Int? {
        var score = 0
        var ni = 0
        var previousMatch: Int?
        var i = start
        while i < chars.count, ni < needle.count {
            if Character(chars[i].lowercased()) == needle[ni] {
                score += 1
                if let previous = previousMatch, previous == i - 1 {
                    score += 12                       // consecutive: the strongest signal there is
                } else if isWordStart(chars, i) {
                    score += 8
                }
                if i >= nameStart { score += 4 }
                previousMatch = i
                ni += 1
            } else if previousMatch != nil {
                score -= 1                            // a gap inside the match, mildly discouraged
            }
            i += 1
        }
        guard ni == needle.count else { return nil }
        // Prefer the shorter candidate when two contain the same match.
        return score - chars.count / 32
    }

    private static func isWordStart(_ chars: [Character], _ i: Int) -> Bool {
        guard i > 0 else { return true }
        let previous = chars[i - 1]
        if previous == "/" || previous == "-" || previous == "_" || previous == "." || previous == " " {
            return true
        }
        // camelCase: a capital after a lowercase letter starts a word.
        return chars[i].isUppercase && previous.isLowercase
    }
}
