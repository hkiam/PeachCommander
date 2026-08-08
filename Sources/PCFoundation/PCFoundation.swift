// SPDX-License-Identifier: Apache-2.0
// PCFoundation - Core utilities for Peach Commander
// This module contains shared utilities: logging, ByteSize formatter,
// path helpers, WildcardMask matcher, etc.

import Foundation
import os

/// Logging wrapper using os.Logger
public enum PCFoundationLogger {
    private static let subsystem = "com.peachcommander"
    public static let logger = Logger(subsystem: subsystem, category: "PCFoundation")

    /// Log an info message
    public static func info(_ message: String) {
        logger.info("\(message)")
    }

    /// Log a debug message
    public static func debug(_ message: String) {
        logger.debug("\(message)")
    }

    /// Log an error message
    public static func error(_ message: String) {
        logger.error("\(message)")
    }
}

/// Formats byte counts into human-readable strings
public struct ByteSize {
    public enum Style {
        case bytes          // 1,234 bytes
        case kb             // 1.2 KB
        case mb             // 1.23 MB
        case bytesWithSep   // 1,234,567 bytes
    }

    public let bytes: Int64

    public init(_ bytes: Int64) {
        self.bytes = bytes
    }

    /// One fractional digit in the given locale's notation.
    ///
    /// `String(format: "%.1f")` writes a decimal *point* whatever the language, and this app shows the
    /// result in the same status bar as `SelectionSummaryFormatter`, which is locale-aware — so a German
    /// user read "4096.0 GB" next to "2,0 M", two separators in one line.
    private static func decimal(_ value: Double, digits: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(digits)f", value)
    }

    /// Format the byte count with the given style.
    public func formatted(style: Style = .bytes, locale: Locale = .current) -> String {
        func d(_ v: Double, _ digits: Int) -> String { Self.decimal(v, digits: digits, locale: locale) }
        switch style {
        case .bytes:
            return "\(bytes) bytes"
        case .kb:
            let value = Double(bytes) / 1024.0
            if value < 10 {
                return "\(d(value, 1)) KB"
            } else if value < 1024 {
                return "\(d(value, 0)) KB"
            } else {
                return Self(Int64(bytes)).formattedLarge(from: value / 1024.0, unitIndex: 2, locale: locale)
            }
        case .mb:
            let value = Double(bytes) / (1024.0 * 1024.0)
            if value < 10 {
                return "\(d(value, 1)) MB"
            } else if value < 1024 {
                return "\(d(value, 0)) MB"
            } else {
                return Self(Int64(bytes)).formattedLarge(from: value / 1024.0, unitIndex: 3, locale: locale)
            }
        case .bytesWithSep:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            return "\(formatter.string(from: NSNumber(value: bytes)) ?? "") bytes"
        }
    }

    /// Units above the style's own, so a large volume does not read as four digits of gigabytes.
    ///
    /// A 4 TB disk's free space showed as "4096.0 GB" and a 16 TB one as "16384.0 GB", because the
    /// ladder stopped at G. It now carries on to T and P — measured on the sizes disks actually come in.
    private func formattedLarge(from value: Double, unitIndex: Int, locale: Locale) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var v = value
        var index = unitIndex
        while v >= 1024, index + 1 < units.count { v /= 1024; index += 1 }
        return "\(Self.decimal(v, digits: 1, locale: locale)) \(units[index])"
    }

    /// Parse a human byte size like "700", "10K", "1.5M", "2G", "500MB" (binary
    /// units, 1K = 1024). Returns nil on malformed input.
    public static func parse(_ text: String) -> Int64? {
        var s = text.trimmingCharacters(in: .whitespaces).uppercased()
        guard !s.isEmpty else { return nil }
        if s.hasSuffix("B") { s.removeLast() }                 // "MB" → "M", "B" → ""
        var multiplier: Double = 1
        if let last = s.last, "KMGT".contains(last) {
            switch last {
            case "K": multiplier = 1024
            case "M": multiplier = 1024 * 1024
            case "G": multiplier = 1024 * 1024 * 1024
            case "T": multiplier = pow(1024, 4)
            default: break
            }
            s.removeLast()
        }
        s = s.trimmingCharacters(in: .whitespaces)
        // A comma is a decimal separator in most of the languages this app ships in, and these fields
        // are filled *by* `formatted` when a search template is loaded — so what is written out has to
        // read back in. Accepting both is strictly more forgiving than accepting one.
        s = s.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(s), value >= 0 else { return nil }
        let bytes = value * multiplier
        guard bytes.isFinite, bytes <= Double(Int64.max) else { return nil }
        return Int64(bytes)
    }
}

/// Path utilities
public enum PathUtils {
    /// Get the parent directory path
    public static func parent(_ path: String) -> String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }

    /// Get the filename from a path
    public static func filename(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    /// Get the file extension from a filename
    public static func fileExtension(from filename: String) -> String {
        URL(fileURLWithPath: filename).pathExtension
    }

    /// Check if a path is hidden (starts with .)
    public static func isHidden(_ path: String) -> Bool {
        filename(path).hasPrefix(".")
    }

    /// Normalize a path string to Unicode NFC (precomposed) form. macOS/APFS
    /// preserves whatever form a name was created in but compares case-/form-
    /// insensitively; NFC is the right canonical form for display and for
    /// comparing names that differ only in composition (e.g. "é" as U+00E9 vs
    /// "e"+U+0301). (Previously this wrongly *folded diacritics*, turning "café"
    /// into "cafe" — that is not normalization and lost information.)
    public static func normalized(_ path: String) -> String {
        path.precomposedStringWithCanonicalMapping
    }

    /// NFD (decomposed) form — the form the HFS+/legacy APIs historically used.
    public static func decomposed(_ path: String) -> String {
        path.decomposedStringWithCanonicalMapping
    }

    /// Whether two names are canonically equivalent ignoring NFC/NFD composition.
    public static func nameEquivalent(_ a: String, _ b: String) -> Bool {
        a.precomposedStringWithCanonicalMapping == b.precomposedStringWithCanonicalMapping
    }

    // MARK: - Colon/slash mapping (macOS Finder convention, F-100)
    //
    // At the POSIX layer "/" is the path separator and cannot appear in a filename
    // component, while ":" is a legal byte. The Finder/user convention is the
    // reverse of classic Mac: a POSIX ":" is shown to the user as "/", and a name
    // the user types with "/" is stored on disk with ":". These map a single
    // filename component between the two (never whole paths).

    /// The user-facing display name for a POSIX filename component: ":" shown as "/".
    public static func displayName(fromPOSIX name: String) -> String {
        name.replacingOccurrences(of: ":", with: "/")
    }

    /// The on-disk POSIX filename for a user-typed display name: "/" stored as ":".
    public static func posixName(fromDisplay name: String) -> String {
        name.replacingOccurrences(of: "/", with: ":")
    }
}

/// Wildcard pattern matcher supporting TC-style masks like "*.c;*.h|*.bak"
public struct WildcardMask {
    private let patterns: [String]
    private let excludePatterns: [String]

    /// Initialize with a mask string (TC format)
    /// - Parameter mask: e.g., "*.c;*.h|*.bak" where | separates include/exclude
    public init(_ mask: String) {
        let parts = mask.split(separator: "|")

        if parts.count == 2 {
            // Include | Exclude format
            self.patterns = parts[0].split(separator: ";").map { String($0) }
            self.excludePatterns = parts[1].split(separator: ";").map { String($0) }
        } else {
            // Only include patterns
            self.patterns = mask.split(separator: ";").map { String($0) }
            self.excludePatterns = []
        }
    }

    /// Check if a filename matches the mask
    public func matches(_ filename: String) -> Bool {
        let matchesInclude = patterns.contains { pattern in
            filenameMatch(filename, pattern: pattern)
        }

        let matchesExclude = excludePatterns.contains { pattern in
            filenameMatch(filename, pattern: pattern)
        }

        return matchesInclude && !matchesExclude
    }

    private func filenameMatch(_ filename: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: Self.regexPattern(for: pattern),
                                                   options: [.caseInsensitive]) else {
            return filename == pattern
        }
        let range = NSRange(location: 0, length: filename.utf16.count)
        return regex.firstMatch(in: filename, options: [], range: range) != nil
    }

    /// Translate a TC-style mask into an anchored regular expression.
    ///
    /// `*` and `?` are the only two characters with a meaning; **everything else is literal**. The
    /// previous version escaped the dot and left the rest alone, so every other regex metacharacter kept
    /// its regex meaning — and file names are full of them. A mask of `Bericht (2026).pdf` did not match
    /// the file of that name and *did* match `Bericht 2026.pdf`: not "finds nothing", but selects the
    /// wrong file. `a+b.txt`, `[Entwurf].doc`, `Preis $5.txt` and `a{2}.log` were all wrong the same way
    /// — eight of twelve realistic cases when this was measured.
    ///
    /// Internal rather than private so the translation can be tested directly; what a mask *means* is
    /// worth pinning independently of whether a particular file matches.
    static func regexPattern(for mask: String) -> String {
        var out = "^"
        var literal = ""
        func flush() {
            if !literal.isEmpty {
                out += NSRegularExpression.escapedPattern(for: literal)
                literal = ""
            }
        }
        for character in mask {
            switch character {
            case "*": flush(); out += ".*"
            case "?": flush(); out += "."
            default: literal.append(character)
            }
        }
        flush()
        return out + "$"
    }
}

/// Locale-aware string comparison for sorting (F-026). With `natural` (the TC
/// "logical order" default) it uses `localizedStandardCompare` — numeric-aware
/// (file2 < file10), case-insensitive and locale-collated (ä sorts as expected);
/// without it, a plain locale-aware case-insensitive comparison (no number runs).
public func naturalCompare(_ a: String, _ b: String, natural: Bool = true) -> ComparisonResult {
    natural ? (a as NSString).localizedStandardCompare(b)
            : (a as NSString).localizedCaseInsensitiveCompare(b)
}
