// SPDX-License-Identifier: Apache-2.0
// PluginCSV.swift - Reading a delimited text file into a table, for the CSVLister plugin.
//
// Split out of csv_lister.swift so the part with the decisions in it — which character is the
// delimiter, and whether the first line names the columns or *is* data — can be unit-tested without
// building a plugin bundle and dlopening it. Pure, no AppKit; compiled into the plugin (see
// Tools/build-csvlister-plugin.sh) and into PCFoundationTests, the way PluginDecompiler.swift is.
//
// The header question is the one that was wrong: the first line was *always* taken as the column
// titles, so a file that starts straight into data lost its first record — it became the table's
// header and could not be filtered, sorted or found again. There is no marker in the format that
// answers it, so this guesses, says which way it guessed, and the view lets the reader override it.

import Foundation

public enum PluginCSV {

    /// Whether the first line names the columns. `auto` asks `looksLikeHeader`.
    public enum HeaderMode: String, Sendable {
        case auto, header, noHeader
    }

    /// A parsed table: column titles, data rows, and how the header question was settled.
    public struct Table: Sendable, Equatable {
        /// Column titles — from the first line, or "Column 1…n" when there is no header row.
        public let header: [String]
        /// The data rows. With no header row the first line is one of them.
        public let rows: [[String]]
        /// Whether the first line was consumed as the header.
        public let usedHeader: Bool
        /// The delimiter that was detected.
        public let delimiter: Character
    }

    /// Split `csv` into a table. Lines split on \n (\r trimmed), empty lines dropped; the delimiter is
    /// auto-detected; optional surrounding double quotes are stripped.
    public static func parse(_ csv: String, headerMode: HeaderMode = .auto) -> Table {
        let lines = csv.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else {
            return Table(header: [], rows: [], usedHeader: false, delimiter: ",")
        }
        let delimiter = detectDelimiter(lines)
        let records = lines.map { fields($0, delimiter: delimiter) }

        let useHeader: Bool
        switch headerMode {
        case .header:   useHeader = true
        case .noHeader: useHeader = false
        case .auto:     useHeader = looksLikeHeader(records)
        }

        if useHeader {
            return Table(header: records[0], rows: Array(records.dropFirst()),
                         usedHeader: true, delimiter: delimiter)
        }
        let width = records.map(\.count).max() ?? 0
        return Table(header: (0..<width).map { "Column \($0 + 1)" }, rows: records,
                     usedHeader: false, delimiter: delimiter)
    }

    /// One line's fields, with surrounding double quotes stripped.
    public static func fields(_ line: String, delimiter: Character) -> [String] {
        line.split(separator: delimiter, omittingEmptySubsequences: false).map {
            var s = String($0)
            if s.hasSuffix("\r") { s.removeLast() }
            if s.hasPrefix("\""), s.hasSuffix("\""), s.count >= 2 { s = String(s.dropFirst().dropLast()) }
            return s
        }
    }

    /// Pick the delimiter whose per-line occurrence count is most consistent (and > 0)
    /// across a sample of lines, favouring more columns to break ties.
    public static func detectDelimiter(_ lines: [String]) -> Character {
        let candidates: [Character] = [",", ";", "\t", "|", ":"]
        let sample = Array(lines.prefix(20))
        var best: Character = ","
        var bestScore = 0.0
        for d in candidates {
            let counts = sample.map { line in line.reduce(0) { $1 == d ? $0 + 1 : $0 } }
            let sorted = counts.sorted()
            let modal = sorted[sorted.count / 2]
            guard modal > 0 else { continue }
            let consistent = Double(counts.filter { $0 == modal }.count) / Double(counts.count)
            let score = consistent * Double(modal)
            if score > bestScore { bestScore = score; best = d }
        }
        return best
    }

    /// Guess whether `records[0]` names the columns.
    ///
    /// Four rules, in order, each of them a thing a header row does not do — deliberately plain, because
    /// a guess a reader cannot predict is worse than one they can correct:
    ///
    /// 1. a file with a single line has no data rows, so treating that line as titles would show an empty
    ///    table — the worse of the two guesses;
    /// 2. a header names every column, so an empty cell in the first line means data;
    /// 3. titles are distinct, so a repeated value in the first line means data;
    /// 4. titles are words, so a first line in which any cell is a number means data.
    ///
    /// Everything else is a header, which is the common case and what the format is usually written with.
    /// Note what is *not* used: comparing the first line's types against the columns below it. It reads
    /// like the better rule and fails on the file this exists for — a table of strings only, where header
    /// and data look exactly alike.
    public static func looksLikeHeader(_ records: [[String]]) -> Bool {
        guard let first = records.first else { return false }
        guard records.count >= 2 else { return false }
        guard !first.isEmpty else { return false }
        if first.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }) { return false }
        if Set(first.map { $0.lowercased() }).count != first.count { return false }
        if first.contains(where: isNumeric) { return false }
        return true
    }

    /// Whether a cell is a plain number — the test a heading has to fail.
    ///
    /// Written out rather than `Double(cell) != nil`, which accepts "nan", "inf", "0x1p3" and "1e5": a
    /// column headed `NaN` is not a number anybody wrote as a heading, and `Inf` is a real place name.
    static func isNumeric(_ cell: String) -> Bool {
        let s = cell.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "")   // thousands separators
            .replacingOccurrences(of: "'", with: "")
        guard !s.isEmpty else { return false }
        var body = Substring(s)
        if body.first == "+" || body.first == "-" { body = body.dropFirst() }
        guard !body.isEmpty, body.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," }) else { return false }
        return body.contains(where: \.isNumber)
    }
}
