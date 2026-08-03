// SPDX-License-Identifier: Apache-2.0
// LineOperations.swift - Sort, deduplicate, reverse, filter and trim lines (F-359).
//
// The same handful of edits an administrator makes to a list of hosts, a log excerpt or an exported CSV,
// and a developer to a list of imports: put it in order, throw out the repeats, keep only what matches,
// take off the trailing spaces that make a diff noisy. All of them are one shell command away — and the
// editor now has a shell filter (F-356) — but that is the wrong answer for the two most common ones:
// `sort` is a keystroke's worth of work, and the reason to have `column -t` in a dropdown is not a reason
// to make sorting a paragraph of typing.
//
// Two properties are worth stating, because getting either wrong is silent and ugly:
//
//   * the file's line terminator survives. Sorting a CRLF file must not quietly turn it into LF, which
//     is exactly what a naive `split(separator: "\n")` + `joined("\n")` does.
//   * whether the text ended with a terminator survives. Adding one appends a line to the file; dropping
//     one makes `wc -l` disagree with every other tool and upsets POSIX-minded ones.

import Foundation

public enum LineOperation: Sendable, Equatable {
    /// Alphabetical, case-insensitive, and numbers compared by value so `file10` follows `file9`.
    /// That is `sort -V`-like rather than `sort`-like on purpose: it is what a person means by "sort".
    case sort(ascending: Bool)
    /// Remove later repeats, keeping the first occurrence and the order.
    case unique
    case reverse
    /// Keep — or drop — the lines containing `needle`.
    case filter(needle: String, keep: Bool, caseSensitive: Bool)
    /// Trailing spaces and tabs off every line. The terminator is not touched.
    case trimTrailingWhitespace
    /// Drop lines that are empty or contain only whitespace.
    case removeBlankLines
}

public enum LineOperations {

    /// Apply `operation` to `text`, preserving its line terminator and whether it ended with one.
    public static func apply(_ operation: LineOperation, to text: String) -> String {
        guard !text.isEmpty else { return text }
        let survey = LineEndings.survey(text)
        let ending = survey.isEmpty ? LineEnding.lf : survey.dominant
        // Mixed input is normalised first, so lines split the same way regardless of which terminator
        // each one happened to use. The dominant one is then written back everywhere — the alternative,
        // remembering each line's own terminator, would preserve exactly the mess the user is fixing.
        let normalised = LineEndings.convert(text, to: .lf)
        let endsWithNewline = normalised.hasSuffix("\n")
        var lines = normalised.components(separatedBy: "\n")
        // `components` gives a trailing empty element for a text that ends with a terminator; that
        // element is not a line, and sorting it into the middle would insert a blank line.
        if endsWithNewline { lines.removeLast() }

        switch operation {
        case .sort(let ascending):
            lines.sort { compare($0, $1) == (ascending ? .orderedAscending : .orderedDescending) }
        case .unique:
            var seen = Set<String>()
            lines = lines.filter { seen.insert($0).inserted }
        case .reverse:
            lines.reverse()
        case .filter(let needle, let keep, let caseSensitive):
            guard !needle.isEmpty else { break }
            lines = lines.filter { line in
                let contains = caseSensitive
                    ? line.contains(needle)
                    : line.range(of: needle, options: .caseInsensitive) != nil
                return contains == keep
            }
        case .trimTrailingWhitespace:
            lines = lines.map(trimTrailing)
        case .removeBlankLines:
            // Whitespace-only counts as blank: a line of spaces is invisible and is what "blank" means
            // to the person looking at the file.
            lines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }

        let joined = lines.joined(separator: ending.characters)
        return joined + (endsWithNewline ? ending.characters : "")
    }

    /// Numeric-aware, case-insensitive, and locale-aware for everything else — `.numeric` alone still
    /// sorts `Ä` after `Z`, which is wrong in half the languages this app is translated into.
    private static func compare(_ a: String, _ b: String) -> ComparisonResult {
        a.compare(b, options: [.numeric, .caseInsensitive, .diacriticInsensitive], range: nil,
                  locale: Locale.current)
    }

    /// Spaces and tabs off the end. Deliberately not `trimmingCharacters(in: .whitespaces)`, which
    /// would also take the leading indentation — the opposite of what a code file wants.
    private static func trimTrailing(_ line: String) -> String {
        var end = line.endIndex
        while end > line.startIndex {
            let previous = line.index(before: end)
            guard line[previous] == " " || line[previous] == "\t" else { break }
            end = previous
        }
        return String(line[line.startIndex..<end])
    }
}
