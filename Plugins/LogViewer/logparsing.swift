// logparsing.swift — log level/timestamp detection + filtering (self-contained
// copy for the external Log Viewer plugin; mirrors the former core LogParsing).

import Foundation

enum LogLevel: String, CaseIterable {
    case error, warning, info, debug, trace, unknown
}

struct LogLine: Equatable {
    let raw: String
    let level: LogLevel
    let timestamp: String?
}

enum LogLineParser {
    static let levelMap: [String: LogLevel] = [
        "ERROR": .error, "ERR": .error, "FATAL": .error, "CRIT": .error,
        "CRITICAL": .error, "SEVERE": .error, "PANIC": .error,
        "WARN": .warning, "WARNING": .warning,
        "INFO": .info, "NOTICE": .info,
        "DEBUG": .debug, "DBG": .debug,
        "TRACE": .trace, "VERBOSE": .trace,
    ]
    private static let levelTokenScanLimit = 6

    static func parse(_ line: String) -> LogLine {
        LogLine(raw: line, level: level(in: line), timestamp: firstTimestamp(in: line))
    }

    static func level(in line: String) -> LogLevel {
        let tokens = line.uppercased().split { !$0.isLetter }.prefix(levelTokenScanLimit)
        for token in tokens {
            if let level = levelMap[String(token)] { return level }
        }
        return .unknown
    }

    private static let timestampPatterns: [NSRegularExpression] = {
        [
            #"\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2})?"#,
            #"[A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}"#,
            #"\d{2}:\d{2}:\d{2}(?:[.,]\d+)?"#,
        ].compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private static let monthAbbrevs: Set<String> =
        ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

    /// Fast, allocation-light check whether a line *begins* with a timestamp, i.e.
    /// whether it starts a new log entry rather than continuing one (stack traces,
    /// wrapped text). Used for multi-line entry grouping without full parsing.
    ///
    /// Recognises the common entry-start shapes across formats:
    ///   ISO `YYYY-MM-DD`, slashed `YYYY/MM/DD`, day-first `DD.MM.YYYY` / `DD/MM/YYYY`,
    ///   leading `HH:MM:SS`, and syslog `Mon [D]D HH:MM:SS` — after an optional
    ///   leading `[` (bracketed timestamps).
    static func startsWithTimestamp<S: StringProtocol>(_ line: S) -> Bool {
        let b = Array(line.utf8.prefix(48))
        func d(_ i: Int) -> Bool { i < b.count && b[i] >= 0x30 && b[i] <= 0x39 }
        func ch(_ i: Int, _ c: UInt8) -> Bool { i < b.count && b[i] == c }
        var i = 0
        while i < b.count, b[i] == 0x20 || b[i] == 0x09 { i += 1 }   // skip leading space/tab
        if ch(i, 0x5B) { i += 1 }                                     // optional leading '['

        // YYYY-MM-DD or YYYY/MM/DD
        if d(i), d(i+1), d(i+2), d(i+3), (ch(i+4, 0x2D) || ch(i+4, 0x2F)),
           d(i+5), d(i+6), (ch(i+7, 0x2D) || ch(i+7, 0x2F)), d(i+8), d(i+9) { return true }
        // DD.MM.YYYY / DD/MM/YYYY / MM/DD/YYYY (day- or month-first, 4-digit year)
        if d(i), d(i+1), (ch(i+2, 0x2E) || ch(i+2, 0x2F)),
           d(i+3), d(i+4), (ch(i+5, 0x2E) || ch(i+5, 0x2F)), d(i+6), d(i+7), d(i+8), d(i+9) { return true }
        // Leading HH:MM:SS
        if d(i), d(i+1), ch(i+2, 0x3A), d(i+3), d(i+4), ch(i+5, 0x3A), d(i+6), d(i+7) { return true }
        // Syslog: Mon [D]D HH:MM:SS — require a real month abbrev + a time to avoid
        // matching prose like "Foo 12 bar".
        if isMonthAbbrev(b, i) {
            var j = i + 3
            while j < b.count, b[j] == 0x20 { j += 1 }
            guard d(j) else { return false }
            j += 1; if d(j) { j += 1 }                               // 1–2 digit day
            while j < b.count, b[j] == 0x20 { j += 1 }
            if d(j), d(j+1), ch(j+2, 0x3A), d(j+3), d(j+4), ch(j+5, 0x3A), d(j+6), d(j+7) { return true }
        }
        return false
    }

    private static func isMonthAbbrev(_ b: [UInt8], _ i: Int) -> Bool {
        guard i + 2 < b.count else { return false }
        func up(_ x: UInt8) -> UInt8 { (x >= 0x61 && x <= 0x7A) ? x - 0x20 : x }
        guard up(b[i]) >= 0x41, up(b[i]) <= 0x5A else { return false }   // must be a letter
        let s = String(bytes: [up(b[i]), up(b[i+1]), up(b[i+2])], encoding: .ascii) ?? ""
        return monthAbbrevs.contains(s)
    }

    static func firstTimestamp(in line: String) -> String? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        for pattern in timestampPatterns {
            if let match = pattern.firstMatch(in: line, range: range), let r = Range(match.range, in: line) {
                return String(line[r])
            }
        }
        return nil
    }

    /// Group parsed lines into entries: a line starts a new entry when it has a
    /// timestamp or a recognised level; otherwise it continues the current entry.
    static func group(_ lines: [LogLine]) -> [LogEntry] {
        var entries: [LogEntry] = []
        var level: LogLevel = .unknown
        var timestamp: String?
        var buffer: [LogLine] = []
        func flush() { if !buffer.isEmpty { entries.append(LogEntry(level: level, timestamp: timestamp, lines: buffer)) } }
        for line in lines {
            let startsNew = line.timestamp != nil || line.level != .unknown
            if buffer.isEmpty || startsNew {
                flush()
                level = line.level; timestamp = line.timestamp; buffer = [line]
            } else {
                buffer.append(line)
            }
        }
        flush()
        return entries
    }
}

struct LogEntry: Equatable {
    let level: LogLevel
    let timestamp: String?
    let lines: [LogLine]
}

struct LogFilter {
    var levels: Set<LogLevel>
    var text: String
    var isRegex: Bool

    init(levels: Set<LogLevel> = [], text: String = "", isRegex: Bool = false) {
        self.levels = levels; self.text = text; self.isRegex = isRegex
    }

    var isEmpty: Bool { levels.isEmpty && text.isEmpty }

    func matches(_ entry: LogEntry) -> Bool {
        if !levels.isEmpty, !levels.contains(entry.level) { return false }
        let needle = text.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return true }
        return entry.lines.contains { textMatches($0.raw) }
    }

    /// Per physical-line variant used by the mmap/lazy-index viewer model.
    func matches(line: LogLine) -> Bool {
        if !levels.isEmpty, !levels.contains(line.level) { return false }
        return textMatches(line.raw)
    }

    /// Public text-only match (level handled separately by the entry-based filter).
    func matchesText(_ raw: String) -> Bool { textMatches(raw) }

    private func textMatches(_ raw: String) -> Bool {
        let needle = text.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return true }
        if isRegex {
            guard let re = try? NSRegularExpression(pattern: needle, options: [.caseInsensitive]) else { return false }
            return re.firstMatch(in: raw, range: NSRange(raw.startIndex..<raw.endIndex, in: raw)) != nil
        }
        return raw.range(of: needle, options: .caseInsensitive) != nil
    }

    func apply(entries: [LogEntry]) -> [LogEntry] {
        isEmpty ? entries : entries.filter(matches)
    }
}
