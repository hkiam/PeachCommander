// SPDX-License-Identifier: Apache-2.0
// DescriptionFile.swift - descript.ion comment file (SPEC-016 §7).
//
// Total Commander stores per-file comments in a "descript.ion" file in each directory: one line per file,
// "<name> <comment>", with the name wrapped in double quotes when it contains spaces. This is the pure
// parse/generate layer; reading/writing the actual file goes through the VFS (CommentStore).
//
// Multi-line comments (F-374)
// ---------------------------
// The original 4DOS format has no way to store a line break. Total Commander asked the 4DOS authors for
// an official extension code and got 0xC2, so a comment containing line breaks is written as:
//
//     name.txt first line\nsecond line<0x04><0xC2>
//
// — the line break as a literal backslash-n, and the two marker bytes at the *end of the line*. The
// marker is what makes the difference: without it, a `\n` in a comment is two characters somebody typed
// and must be shown as such. Reading `\n` as a line break unconditionally would rewrite other people's
// comments, and this parser used to do neither — it kept the marker bytes as part of the comment text,
// so a TC multi-line comment came out with a control character glued to its end.
//
// The format cannot distinguish a real line break from a literal `\n` inside a *multi-line* comment, and
// neither can Total Commander. That is a property of the format, not a choice made here.

import Foundation

public struct DescriptionFile: Equatable, Sendable {
    /// filename → comment (never stores empty comments).
    public private(set) var comments: [String: String]

    public init() { comments = [:] }

    public init(parsing text: String) {
        var map: [String: String] = [:]
        for rawLine in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = String(rawLine)
            guard let (name, comment) = Self.parseLine(line), !comment.isEmpty else { continue }
            map[name] = comment
        }
        comments = map
    }

    /// The bytes Total Commander appends to a line whose comment contains line breaks: 0x04 introduces a
    /// 4DOS extension, 0xC2 is the code registered for "this comment uses \\n for line breaks".
    static let multiLineMarker = "\u{04}\u{C2}"

    public func comment(for name: String) -> String? { comments[name] }

    public mutating func setComment(_ comment: String?, for name: String) {
        let trimmed = comment?.trimmingCharacters(in: .whitespaces) ?? ""
        if trimmed.isEmpty { comments[name] = nil } else { comments[name] = trimmed }
    }

    /// Serialize to descript.ion text (names sorted; spaces → quoted name).
    public func serialized() -> String {
        var lines: [String] = []
        for name in comments.keys.sorted() {
            guard let comment = comments[name] else { continue }
            let key = name.contains(" ") ? "\"\(name)\"" : name
            // A comment with line breaks is written the way Total Commander writes it, so TC (and
            // anything else that knows the extension) reads it back whole.
            if comment.contains("\n") {
                let escaped = comment.replacingOccurrences(of: "\n", with: "\\n")
                lines.append("\(key) \(escaped)\(Self.multiLineMarker)")
            } else {
                lines.append("\(key) \(comment)")
            }
        }
        return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
    }

    public var isEmpty: Bool { comments.isEmpty }

    // MARK: - Line parsing

    /// Parse a single line into (name, comment). Handles a quoted name with spaces and TC's multi-line
    /// extension.
    static func parseLine(_ line: String) -> (name: String, comment: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("\"") {
            // "name with spaces" comment
            let afterQuote = trimmed.index(after: trimmed.startIndex)
            guard let closing = trimmed[afterQuote...].firstIndex(of: "\"") else { return nil }
            let name = String(trimmed[afterQuote..<closing])
            let comment = String(trimmed[trimmed.index(after: closing)...]).trimmingCharacters(in: .whitespaces)
            return (name, decodeComment(comment))
        } else {
            guard let sep = trimmed.firstIndex(of: " ") else {
                return (trimmed.hasSuffix(multiLineMarker)
                        ? String(trimmed.dropLast(multiLineMarker.count)) : trimmed, "")
            }
            let name = String(trimmed[trimmed.startIndex..<sep])
            let comment = String(trimmed[trimmed.index(after: sep)...]).trimmingCharacters(in: .whitespaces)
            return (name, decodeComment(comment))
        }
    }

    // MARK: - Encoding

    /// How a `descript.ion` file was encoded, so it can be written back the same way (F-374).
    ///
    /// Total Commander writes UTF-16 with a BOM when a comment needs characters the local codepage
    /// cannot hold, and UTF-8 (with or without a BOM) otherwise. Reading everything as UTF-8 turned a
    /// UTF-16 file into replacement characters, and writing it back destroyed every comment in the
    /// directory — including the ones nobody had touched.
    public enum Encoding: Equatable, Sendable {
        case utf8
        case utf8BOM
        case utf16LE
        case utf16BE

        /// The BOM to write, if any.
        var bom: [UInt8] {
            switch self {
            case .utf8: return []
            case .utf8BOM: return [0xEF, 0xBB, 0xBF]
            case .utf16LE: return [0xFF, 0xFE]
            case .utf16BE: return [0xFE, 0xFF]
            }
        }
    }

    /// Detect the encoding of a `descript.ion` file from its first bytes.
    ///
    /// By BOM only, deliberately. Guessing UTF-16 from a pattern of interleaved zero bytes would be
    /// wrong for a file that legitimately starts with an ASCII name and holds one — and the files this
    /// has to read are written by tools that do emit a BOM.
    public static func detectEncoding(_ data: Data) -> Encoding {
        if data.count >= 3, data[0] == 0xEF, data[1] == 0xBB, data[2] == 0xBF { return .utf8BOM }
        if data.count >= 2, data[0] == 0xFF, data[1] == 0xFE { return .utf16LE }
        if data.count >= 2, data[0] == 0xFE, data[1] == 0xFF { return .utf16BE }
        return .utf8
    }

    /// Decode a `descript.ion` file's bytes, honouring its BOM.
    public static func decode(_ data: Data) -> (text: String, encoding: Encoding) {
        let encoding = detectEncoding(data)
        let body = data.dropFirst(encoding.bom.count)
        switch encoding {
        case .utf8, .utf8BOM:
            return (String(decoding: body, as: UTF8.self), encoding)
        case .utf16LE:
            return (String(data: Data(body), encoding: .utf16LittleEndian) ?? "", encoding)
        case .utf16BE:
            return (String(data: Data(body), encoding: .utf16BigEndian) ?? "", encoding)
        }
    }

    /// Encode text for writing, in the encoding the file already had.
    ///
    /// The same encoding rather than always UTF-8: rewriting a UTF-16 file as UTF-8 would leave every
    /// other tool that reads it — including Total Commander on the same volume — looking at bytes it does
    /// not expect. A UTF-8 file that needs characters beyond ASCII stays UTF-8, which every reader of this
    /// format has handled since 4DOS was current.
    public static func encode(_ text: String, as encoding: Encoding) -> Data {
        var out = Data(encoding.bom)
        switch encoding {
        case .utf8, .utf8BOM:
            out.append(Data(text.utf8))
        case .utf16LE:
            out.append(text.data(using: .utf16LittleEndian) ?? Data())
        case .utf16BE:
            out.append(text.data(using: .utf16BigEndian) ?? Data())
        }
        return out
    }

    /// Turn the stored comment text into what the user wrote.
    ///
    /// Only a line ending in the extension marker has its `\\n` read as line breaks. Everything else is
    /// somebody's literal text — a Windows path in a comment ("C:\\new\\file") would otherwise sprout
    /// line breaks it never had.
    private static func decodeComment(_ raw: String) -> String {
        guard raw.hasSuffix(multiLineMarker) else { return raw }
        return String(raw.dropLast(multiLineMarker.count))
            .replacingOccurrences(of: "\\n", with: "\n")
    }
}
