// SPDX-License-Identifier: Apache-2.0
// FTPListing.swift - Parsers for FTP directory listings (SPEC-011 §3).
//
// FTP has no standard listing format, so a client must cope with several:
//   * MLSD  — the modern machine-readable format (RFC 3659), preferred.
//   * UNIX  — `ls -l` style output (the most common LIST format).
//   * DOS   — Windows/IIS style output.
// These parsers are pure functions over raw text lines so they can be verified
// with golden fixtures captured from real servers, independently of any socket.

import Foundation

/// One entry parsed from a remote directory listing.
public struct RemoteFileEntry: Equatable, Sendable {
    public var name: String
    public var size: Int64
    public var isDirectory: Bool
    public var isSymlink: Bool
    public var symlinkTarget: String?
    /// Modification time, in UTC where the format encodes it, else the server's
    /// local time interpreted as UTC (FTP listings rarely carry a zone).
    public var modified: Date?
    /// UNIX permission string (e.g. "rwxr-xr-x") when available.
    public var permissions: String?
    public var owner: String?
    public var group: String?

    public init(name: String, size: Int64 = 0, isDirectory: Bool = false,
                isSymlink: Bool = false, symlinkTarget: String? = nil,
                modified: Date? = nil, permissions: String? = nil,
                owner: String? = nil, group: String? = nil) {
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.isSymlink = isSymlink
        self.symlinkTarget = symlinkTarget
        self.modified = modified
        self.permissions = permissions
        self.owner = owner
        self.group = group
    }
}

public enum FTPListParser {
    /// Which LIST dialect a block of lines looks like.
    public enum Format: Equatable { case mlsd, unix, dos, unknown }

    private static var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private static let months: [String: Int] = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
        "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12
    ]

    // MARK: - Entry point

    /// Parse a full listing, auto-detecting the format. `"."` and `".."` entries
    /// are dropped. `referenceDate` is used to infer the year of UNIX entries that
    /// only carry a time (pass a fixed date in tests for determinism).
    public static func parse(_ text: String, referenceDate: Date = Date()) -> [RemoteFileEntry] {
        // Normalize line endings first: Swift treats "\r\n" as a single Character
        // (grapheme cluster), so splitting on '\n'/'\r' alone would miss CRLF.
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
                             .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        return parse(lines: lines, referenceDate: referenceDate)
    }

    public static func parse(lines: [String], referenceDate: Date = Date()) -> [RemoteFileEntry] {
        switch detectFormat(lines) {
        case .mlsd: return lines.compactMap { parseMLSD($0) }
        case .dos: return lines.compactMap { parseDOS($0, referenceDate: referenceDate) }
        case .unix, .unknown: return lines.compactMap { parseUnix($0, referenceDate: referenceDate) }
        }
    }

    /// Heuristically detect the listing dialect from a sample of lines.
    public static func detectFormat(_ lines: [String]) -> Format {
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.contains(";") && line.lowercased().contains("type=") {
                return .mlsd
            }
            if line.range(of: #"^\d{2}-\d{2}-\d{2}\s"#, options: .regularExpression) != nil {
                return .dos
            }
            if let f = line.first, "dl-bcps".contains(f), line.count > 10 {
                return .unix
            }
        }
        return .unknown
    }

    // MARK: - MLSD (RFC 3659)

    /// Parse a single MLSD line: `fact=value;fact=value; name`.
    public static func parseMLSD(_ line: String) -> RemoteFileEntry? {
        guard let spaceIdx = line.firstIndex(of: " ") else { return nil }
        let factPart = line[line.startIndex..<spaceIdx]
        let name = String(line[line.index(after: spaceIdx)...])
        guard !name.isEmpty else { return nil }

        var facts: [String: String] = [:]
        for token in factPart.split(separator: ";") {
            let kv = token.split(separator: "=", maxSplits: 1)
            if kv.count == 2 { facts[kv[0].lowercased()] = String(kv[1]) }
        }

        let type = facts["type"]?.lowercased() ?? ""
        if type == "cdir" || type == "pdir" { return nil }   // "." and ".."
        if name == "." || name == ".." { return nil }

        var entry = RemoteFileEntry(name: name)
        entry.isDirectory = (type == "dir")
        entry.isSymlink = type.hasPrefix("os.unix=slink") || type == "link"
        if let s = facts["size"] ?? facts["sizd"], let v = Int64(s) { entry.size = v }
        if let m = facts["modify"] { entry.modified = parseMLSDTimestamp(m) }
        if let perm = facts["unix.mode"] { entry.permissions = perm }
        if let owner = facts["unix.owner"] ?? facts["unix.ownername"] { entry.owner = owner }
        if let group = facts["unix.group"] ?? facts["unix.groupname"] { entry.group = group }
        return entry
    }

    /// MLSD `modify` fact: `YYYYMMDDHHMMSS` (optionally `.fff`), interpreted as UTC.
    static func parseMLSDTimestamp(_ s: String) -> Date? {
        let digits = s.prefix(while: { $0.isNumber })
        guard digits.count >= 14 else { return nil }
        let chars = Array(digits)
        func num(_ lo: Int, _ len: Int) -> Int? { Int(String(chars[lo..<lo + len])) }
        guard let y = num(0, 4), let mo = num(4, 2), let d = num(6, 2),
              let h = num(8, 2), let mi = num(10, 2), let se = num(12, 2) else { return nil }
        var comps = DateComponents()
        comps.year = y; comps.month = mo; comps.day = d
        comps.hour = h; comps.minute = mi; comps.second = se
        return utcCalendar.date(from: comps)
    }

    // MARK: - UNIX (`ls -l`)

    /// Parse a single UNIX `ls -l` style line.
    public static func parseUnix(_ line: String, referenceDate: Date = Date()) -> RemoteFileEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first, "dl-bcps".contains(first) else { return nil }
        // total NN header lines
        if trimmed.hasPrefix("total ") { return nil }

        let fields = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        // perms links owner group size month day time/year name...
        guard fields.count >= 8 else { return nil }
        let perms = fields[0]
        guard perms.count >= 10 else { return nil }

        // Locate the date triplet (month day time/year). The month is an English
        // abbreviation; scan for it so odd owner/group columns don't misalign.
        var dateIdx = -1
        for i in 3..<min(fields.count - 1, 8) where months[fields[i].lowercased()] != nil {
            dateIdx = i; break
        }
        guard dateIdx >= 4, dateIdx + 2 < fields.count else { return nil }

        let sizeStr = fields[dateIdx - 1]
        let size = Int64(sizeStr) ?? 0
        let owner = dateIdx - 3 >= 1 ? fields[2] : nil
        let group = dateIdx - 1 >= 3 ? fields[3] : nil

        let month = fields[dateIdx]
        let day = fields[dateIdx + 1]
        let timeOrYear = fields[dateIdx + 2]
        let nameFields = fields[(dateIdx + 3)...]
        var name = nameFields.joined(separator: " ")
        guard !name.isEmpty, name != ".", name != ".." else { return nil }

        var entry = RemoteFileEntry(name: name)
        entry.permissions = String(perms.dropFirst())
        entry.owner = owner
        entry.group = group
        entry.size = size

        switch first {
        case "d": entry.isDirectory = true
        case "l":
            entry.isSymlink = true
            if let r = name.range(of: " -> ") {
                entry.symlinkTarget = String(name[r.upperBound...])
                name = String(name[..<r.lowerBound])
                entry.name = name
            }
        default: break
        }
        entry.modified = parseUnixDate(month: month, day: day, timeOrYear: timeOrYear, referenceDate: referenceDate)
        return entry
    }

    /// UNIX listing date: `Mon DD HH:MM` (recent, year inferred) or `Mon DD YYYY`.
    static func parseUnixDate(month: String, day: String, timeOrYear: String, referenceDate: Date) -> Date? {
        guard let mo = months[month.lowercased()], let d = Int(day) else { return nil }
        var comps = DateComponents()
        comps.month = mo; comps.day = d
        if timeOrYear.contains(":") {
            let hm = timeOrYear.split(separator: ":")
            guard hm.count == 2, let h = Int(hm[0]), let mi = Int(hm[1]) else { return nil }
            comps.hour = h; comps.minute = mi
            // No year in the listing: use the reference year, but if that lands in
            // the future (more than a day ahead) it must be last year (ls behaviour).
            let refYear = utcCalendar.component(.year, from: referenceDate)
            comps.year = refYear
            if let candidate = utcCalendar.date(from: comps),
               candidate.timeIntervalSince(referenceDate) > 86_400 {
                comps.year = refYear - 1
            }
        } else if let y = Int(timeOrYear) {
            comps.year = y
        } else {
            return nil
        }
        return utcCalendar.date(from: comps)
    }

    // MARK: - DOS / Windows (IIS)

    /// Parse a single DOS/IIS style line:
    /// `MM-DD-YY  HH:MM(AM|PM)  <DIR>|size  name`.
    public static func parseDOS(_ line: String, referenceDate: Date = Date()) -> RemoteFileEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let fields = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard fields.count >= 4 else { return nil }
        guard fields[0].range(of: #"^\d{2}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { return nil }

        let dateStr = fields[0]
        let timeStr = fields[1]
        let sizeOrDir = fields[2]
        var name = fields[(3...)].joined(separator: " ")
        guard !name.isEmpty, name != ".", name != ".." else { return nil }

        var entry = RemoteFileEntry(name: name)
        if sizeOrDir.uppercased() == "<DIR>" {
            entry.isDirectory = true
        } else {
            entry.size = Int64(sizeOrDir.replacingOccurrences(of: ",", with: "")) ?? 0
        }
        _ = name
        entry.modified = parseDOSDate(dateStr, timeStr)
        return entry
    }

    static func parseDOSDate(_ dateStr: String, _ timeStr: String) -> Date? {
        let dParts = dateStr.split(separator: "-")
        guard dParts.count == 3, let mo = Int(dParts[0]), let d = Int(dParts[1]), let yy = Int(dParts[2]) else { return nil }
        let year = yy < 70 ? 2000 + yy : 1900 + yy

        var t = timeStr.uppercased()
        var pm = false
        if t.hasSuffix("PM") { pm = true; t.removeLast(2) }
        else if t.hasSuffix("AM") { t.removeLast(2) }
        let tParts = t.split(separator: ":")
        guard tParts.count == 2, var h = Int(tParts[0]), let mi = Int(tParts[1]) else { return nil }
        if pm && h != 12 { h += 12 }
        if !pm && h == 12 { h = 0 }

        var comps = DateComponents()
        comps.year = year; comps.month = mo; comps.day = d; comps.hour = h; comps.minute = mi
        return utcCalendar.date(from: comps)
    }
}
