// SPDX-License-Identifier: Apache-2.0
// INIDocument.swift - Comment- and order-preserving INI document model
//
// Parses classic INI text (`[Section]`, `key=value`, `;` comments, blank lines)
// into an ordered token list so that unrelated content survives a save
// byte-for-byte. This matters because TC-style users hand-edit these files.

import Foundation

/// An ordered, comment-preserving representation of an INI document.
///
/// The document is stored as an ordered list of ``Line`` tokens. Parsing
/// never fails: any input that doesn't look like a recognized construct is
/// kept verbatim as a comment/blank line so nothing is ever silently dropped.
public struct INIDocument: Equatable, Sendable {

    /// A single line of the document, in original order.
    enum Line: Equatable, Sendable {
        /// A `[Section]` header. `rawName` preserves the exact text inside the brackets.
        case sectionHeader(rawName: String)
        /// A `key=value` pair. `rawKey`/`rawValue` preserve surrounding text (values are
        /// trimmed of surrounding whitespace, but original casing is preserved).
        ///
        /// `original` is the line exactly as it was read, and is written back unchanged as long as the
        /// value has not been set. Without it the serializer rebuilt every line as `key=value`, so the
        /// first time the app saved anything it reformatted the *whole* file — `Appearance = dark`
        /// became `Appearance=dark` on lines nobody had touched. This file is documented as one people
        /// edit by hand (F-275), and a diff nobody asked for is exactly what that promise rules out.
        case keyValue(section: String, rawKey: String, rawValue: String, original: String? = nil)
        /// A comment line (starts with `;` or `#`), stored including its marker.
        case comment(String)
        /// A blank (whitespace-only) line.
        case blank
    }

    /// The line ending the document was read with, so serializing keeps it (F-375).
    ///
    /// The editor promises that a line operation "never changes the terminator on its own: sorting a CRLF
    /// file leaves it CRLF" — and the Format button runs this serializer on files the user owns. Joining
    /// with "\n" regardless rewrote every line of a Windows-style INI, which is a diff nobody asked for.
    /// A sweep over 350 real `.ini`/`.cfg`/`.properties` files on this machine found 34 of them CRLF.
    public private(set) var lineEnding: String = "\n"

    /// Ordered tokens making up the document.
    var lines: [Line]

    /// Create an empty document.
    public init() {
        self.lines = []
    }

    /// Parse INI text into an ordered token list. Sections, key=value pairs,
    /// comments and blank lines are all preserved verbatim where possible.
    public init(parsing text: String) {
        var parsedLines: [Line] = []
        var currentSection = ""

        // Split on *newlines*, not on the character "\n": in Swift "\r\n" is a single Character, so
        // `split(separator: "\n")` does not split a CRLF file at all. It produced one giant broken line
        // — `[S]\r\na` as a key — so a Windows-style INI was never parsed correctly, and the Format
        // button turned one into nonsense. `isNewline` treats CRLF as the one line break it is.
        //
        // The same trap caught `LineEndings.lineCount` once ("1 line(s)" for a four-line CRLF file), and
        // it caught the differential probe that was meant to find this: the probe split the original text
        // the same wrong way, so it compared garbage against garbage and reported no findings.
        let rawLines = text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })

        for (index, substring) in rawLines.enumerated() {
            // Guard against a final empty element produced by a trailing "\n".
            if index == rawLines.count - 1 && substring.isEmpty {
                continue
            }

            // Normalize a trailing \r (CRLF input) but keep everything else as-is.
            var line = String(substring)
            if line.hasSuffix("\r") {
                line.removeLast()
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                parsedLines.append(.blank)
                continue
            }

            if trimmed.hasPrefix(";") || trimmed.hasPrefix("#") {
                parsedLines.append(.comment(line))
                continue
            }

            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                let name = String(trimmed.dropFirst().dropLast())
                currentSection = name
                parsedLines.append(.sectionHeader(rawName: name))
                continue
            }

            if let equalsIndex = line.firstIndex(of: "=") {
                let key = String(line[line.startIndex..<equalsIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)
                parsedLines.append(.keyValue(section: currentSection, rawKey: key,
                                             rawValue: value, original: line))
                continue
            }

            // Doesn't look like anything recognized; preserve it verbatim so
            // nothing is lost on round-trip.
            parsedLines.append(.comment(line))
        }

        self.lines = parsedLines
        // The dominant terminator, not the first: a file that is CRLF apart from one stray LF is a CRLF
        // file, and rewriting all of it because of the stray one is the behaviour being fixed here.
        let crlf = text.components(separatedBy: "\r\n").count - 1
        let lf = text.components(separatedBy: "\n").count - 1 - crlf
        let cr = text.components(separatedBy: "\r").count - 1 - crlf
        if crlf >= max(lf, cr), crlf > 0 { lineEnding = "\r\n" }
        else if cr > lf, cr > 0 { lineEnding = "\r" }
        else { lineEnding = "\n" }
    }

    /// Value for `key` in `section` (case-insensitive section+key match), or nil.
    public func value(section: String, key: String) -> String? {
        let targetSection = section.lowercased()
        let targetKey = key.lowercased()
        for line in lines {
            if case .keyValue(let lineSection, let rawKey, let rawValue, _) = line,
               lineSection.lowercased() == targetSection,
               rawKey.lowercased() == targetKey {
                return rawValue
            }
        }
        return nil
    }

    /// Set/insert a value, preserving existing comments and overall ordering;
    /// creates the section/key if absent.
    public mutating func set(_ value: String, section: String, key: String) {
        let targetSection = section.lowercased()
        let targetKey = key.lowercased()

        // 1) Try to rewrite an existing key in place.
        for index in lines.indices {
            if case .keyValue(let lineSection, let rawKey, _, let original) = lines[index],
               lineSection.lowercased() == targetSection,
               rawKey.lowercased() == targetKey {
                // Only the value part of the line is replaced, so `Appearance = dark` stays spaced the
                // way its author wrote it and only the word after the `=` changes.
                let rewritten = original.flatMap { line -> String? in
                    guard let equals = line.firstIndex(of: "=") else { return nil }
                    let head = line[line.startIndex...equals]        // key, spaces and the `=`
                    let tail = line[line.index(after: equals)...]
                    let leading = tail.prefix { $0 == " " || $0 == "\t" }
                    return String(head) + String(leading) + value
                }
                lines[index] = .keyValue(section: lineSection, rawKey: rawKey,
                                         rawValue: value, original: rewritten)
                return
            }
        }

        // 2) Find the section header (case-insensitively) to know where to insert.
        var sectionHeaderIndex: Int?
        var sectionRawName: String?
        for index in lines.indices {
            if case .sectionHeader(let rawName) = lines[index], rawName.lowercased() == targetSection {
                sectionHeaderIndex = index
                sectionRawName = rawName
                break
            }
        }

        if let headerIndex = sectionHeaderIndex, let rawName = sectionRawName {
            // Insert after the last existing key=value line belonging to this section,
            // or right after the header if the section has no keys yet.
            var insertAt = headerIndex + 1
            var index = headerIndex + 1
            while index < lines.count {
                if case .sectionHeader = lines[index] {
                    break
                }
                if case .keyValue(let lineSection, _, _, _) = lines[index], lineSection.lowercased() == targetSection {
                    insertAt = index + 1
                }
                index += 1
            }
            lines.insert(.keyValue(section: rawName, rawKey: key, rawValue: value), at: insertAt)
            return
        }

        // 3) Section doesn't exist: append a new section header + pair at the end.
        if !lines.isEmpty {
            if case .blank = lines[lines.count - 1] {
                // keep as-is
            } else {
                lines.append(.blank)
            }
        }
        lines.append(.sectionHeader(rawName: section))
        lines.append(.keyValue(section: section, rawKey: key, rawValue: value))
    }

    /// Remove a key (no-op if absent).
    public mutating func remove(section: String, key: String) {
        let targetSection = section.lowercased()
        let targetKey = key.lowercased()
        lines.removeAll { line in
            if case .keyValue(let lineSection, let rawKey, _, _) = line,
               lineSection.lowercased() == targetSection,
               rawKey.lowercased() == targetKey {
                return true
            }
            return false
        }
    }

    /// All section names, in first-appearance order.
    public func sections() -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for line in lines {
            if case .sectionHeader(let rawName) = line {
                let lower = rawName.lowercased()
                if !seen.contains(lower) {
                    seen.insert(lower)
                    result.append(rawName)
                }
            }
        }
        return result
    }

    /// All keys within `section`, in first-appearance order.
    public func keys(inSection section: String) -> [String] {
        let targetSection = section.lowercased()
        var seen = Set<String>()
        var result: [String] = []
        for line in lines {
            if case .keyValue(let lineSection, let rawKey, _, _) = line, lineSection.lowercased() == targetSection {
                let lower = rawKey.lowercased()
                if !seen.contains(lower) {
                    seen.insert(lower)
                    result.append(rawKey)
                }
            }
        }
        return result
    }

    /// Serialize back to text. Comments, blank lines and the ordering of
    /// untouched lines are preserved, including the file's line terminator (F-375). The result always
    /// ends with a single trailing newline (this is the one normalization applied on round-trip:
    /// input lacking a final newline gains one on serialization).
    /// The document as text.
    ///
    /// `normalizing: false` (the default) writes every untouched line back exactly as it was read —
    /// what saving a configuration file must do, because these files are edited by hand and a save that
    /// reformats lines nobody touched is a diff nobody asked for (F-275).
    ///
    /// `normalizing: true` rebuilds each pair as `key=value`, which is what the *Format* command is for:
    /// there the user has asked for the file to be tidied, and preserving the input would make the
    /// command do nothing at all.
    public func serialized(normalizing: Bool = false) -> String {
        var pieces: [String] = []
        pieces.reserveCapacity(lines.count)
        for line in lines {
            switch line {
            case .sectionHeader(let rawName):
                pieces.append("[\(rawName)]")
            case .keyValue(_, let rawKey, let rawValue, let original):
                pieces.append(normalizing ? "\(rawKey)=\(rawValue)" : (original ?? "\(rawKey)=\(rawValue)"))
            case .comment(let text):
                pieces.append(text)
            case .blank:
                pieces.append("")
            }
        }
        if pieces.isEmpty {
            return ""
        }
        return pieces.joined(separator: lineEnding) + lineEnding
    }
}
