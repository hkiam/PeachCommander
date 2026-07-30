// SPDX-License-Identifier: Apache-2.0
// logformats.swift — pluggable log-line formats + auto-detection.
//
// A LogFormat describes how to split a physical line into (timestamp, level,
// message). Two kinds are supported: `regex` (a pattern with named capture groups
// time/level/msg) and `csv` (a delimiter + column indices). Built-in formats cover
// log4j/SLF4J, log4net and CSV; users add custom regex formats in Settings, so the
// set is extensible. FormatEngine caches compiled regexes, parses a line against a
// format, and auto-detects the best format from a sample of lines. When no format
// matches a line the caller falls back to the heuristic LogLineParser.

import Foundation

struct LogFormat: Codable, Equatable {
    enum Kind: String, Codable { case regex, csv }
    var id: String
    var name: String
    var kind: Kind
    var pattern: String          // regex source (kind == .regex)
    var delimiter: String        // field separator (kind == .csv)
    var timeColumn: Int          // CSV column indices (kind == .csv)
    var levelColumn: Int
    var messageColumn: Int
    var builtin: Bool

    init(id: String, name: String, kind: Kind, pattern: String = "", delimiter: String = ",",
         timeColumn: Int = 0, levelColumn: Int = 1, messageColumn: Int = 2, builtin: Bool = false) {
        self.id = id; self.name = name; self.kind = kind; self.pattern = pattern
        self.delimiter = delimiter; self.timeColumn = timeColumn
        self.levelColumn = levelColumn; self.messageColumn = messageColumn; self.builtin = builtin
    }

    static let builtins: [LogFormat] = [
        // Level may appear right after the timestamp, after a [thread], or after
        // arbitrary context (Atlassian/Jira put request context before the level),
        // so `.*?` spans anything between the timestamp and the first level token.
        LogFormat(id: "builtin.log4j", name: "log4j / SLF4J / Jira", kind: .regex,
                  pattern: #"^(?<time>\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:[+-]\d{2}:?\d{2})?)\s+.*?\b(?<level>TRACE|DEBUG|INFO|WARN|WARNING|ERROR|FATAL|SEVERE)\b\s*(?<msg>.*)$"#,
                  builtin: true),
        LogFormat(id: "builtin.log4net", name: "log4net", kind: .regex,
                  pattern: #"^(?<time>\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:[+-]\d{2}:?\d{2})?)\s+\[[^\]]*\]\s+(?<level>TRACE|DEBUG|INFO|WARN|ERROR|FATAL)\s+(?<msg>.*)$"#,
                  builtin: true),
        LogFormat(id: "builtin.csv", name: "CSV (time, level, message)", kind: .csv,
                  delimiter: ",", timeColumn: 0, levelColumn: 1, messageColumn: 2, builtin: true),
    ]
}

struct FormatMatch {
    let timestamp: String?
    let level: LogLevel
    let message: String
}

final class FormatEngine {
    private var regexCache: [String: NSRegularExpression] = [:]

    private func regex(_ pattern: String) -> NSRegularExpression? {
        if let re = regexCache[pattern] { return re }
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        regexCache[pattern] = re
        return re
    }

    private func mapLevel(_ token: String) -> LogLevel {
        LogLineParser.levelMap[token.trimmingCharacters(in: .whitespaces).uppercased()] ?? .unknown
    }

    /// Parse `line` with `format`. Returns nil if the line does not fit the format
    /// (the caller then falls back to the heuristic parser).
    func match(_ line: String, format: LogFormat) -> FormatMatch? {
        switch format.kind {
        case .regex:
            guard let re = regex(format.pattern) else { return nil }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let m = re.firstMatch(in: line, range: range) else { return nil }
            func group(_ name: String) -> String? {
                let r = m.range(withName: name)
                guard r.location != NSNotFound, let rr = Range(r, in: line) else { return nil }
                return String(line[rr])
            }
            let level = group("level").map(mapLevel) ?? .unknown
            let msg = group("msg") ?? line
            return FormatMatch(timestamp: group("time"), level: level, message: msg)
        case .csv:
            let cols = Self.splitCSV(line, delimiter: format.delimiter)
            let maxIdx = max(format.timeColumn, format.levelColumn, format.messageColumn)
            guard cols.count > maxIdx else { return nil }
            let levelToken = cols[format.levelColumn]
            let level = mapLevel(levelToken)
            // A CSV line only counts as a match when its level column is a real level;
            // otherwise arbitrary comma-separated text would masquerade as a log.
            guard level != .unknown else { return nil }
            return FormatMatch(timestamp: cols[format.timeColumn], level: level, message: cols[format.messageColumn])
        }
    }

    /// Detect the best-fitting format from `sample` lines. Returns nil when no
    /// format matches a confident fraction (falls back to heuristic parsing).
    func detect(sample: [String], formats: [LogFormat]) -> LogFormat? {
        // Score only over lines that look like entry starts; continuation lines
        // (stack traces, wrapped text) must not count against a format.
        var lines = sample.filter { LogLineParser.startsWithTimestamp($0) }
        if lines.count < 3 {   // fall back to non-empty lines (e.g. CSV without leading timestamps)
            lines = sample.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
        guard lines.count >= 3 else { return nil }
        var best: (format: LogFormat, score: Double)?
        for format in formats {
            let matched = lines.reduce(0) { $0 + (match($1, format: format) != nil ? 1 : 0) }
            let score = Double(matched) / Double(lines.count)
            if score >= 0.5, best == nil || score > best!.score {
                best = (format, score)
            }
        }
        return best?.format
    }

    /// Minimal quote-aware CSV split (handles "…,…" quoted fields and "" escapes).
    static func splitCSV(_ line: String, delimiter: String) -> [String] {
        let delim = delimiter.first ?? ","
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { inQuotes = false }
                } else { field.append(c) }
            } else if c == "\"" {
                inQuotes = true
            } else if c == delim {
                fields.append(field); field = ""
            } else {
                field.append(c)
            }
            i += 1
        }
        fields.append(field)
        return fields.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
