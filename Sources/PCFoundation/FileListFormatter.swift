// SPDX-License-Identifier: Apache-2.0
// FileListFormatter.swift - Render a directory listing as text (SPEC-016 §9).
//
// Shared by "Copy File Details", "Export File List", and "Print File List" so the
// three produce identical output. Pure and deterministic (dates via an injectable
// format), hence golden-testable.

import Foundation

public struct FileListRow: Equatable, Sendable {
    public var name: String
    public var ext: String
    public var size: Int64          // -1 for "unknown" (e.g. directories)
    public var modified: Date
    public init(name: String, ext: String, size: Int64, modified: Date) {
        self.name = name
        self.ext = ext
        self.size = size
        self.modified = modified
    }
}

public enum FileListFormat: Sendable {
    case tsv      // tab-separated columns (Name/Ext/Size/Modified)
    case csv      // RFC 4180-style comma-separated
    case plain    // names only, one per line
}

public enum FileListFormatter {
    public static func format(_ rows: [FileListRow], as format: FileListFormat,
                              header: Bool = true, dateFormat: String = "yyyy-MM-dd HH:mm:ss") -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        df.dateFormat = dateFormat

        func sizeString(_ s: Int64) -> String { s >= 0 ? "\(s)" : "" }

        switch format {
        case .plain:
            return rows.map(\.name).joined(separator: "\n") + (rows.isEmpty ? "" : "\n")

        case .tsv:
            var lines: [String] = []
            if header { lines.append("Name\tExt\tSize\tModified") }
            for r in rows {
                lines.append("\(tsvEscape(r.name))\t\(tsvEscape(r.ext))\t\(sizeString(r.size))"
                             + "\t\(df.string(from: r.modified))")
            }
            return lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")

        case .csv:
            var lines: [String] = []
            if header { lines.append("Name,Ext,Size,Modified") }
            for r in rows {
                let cells = [r.name, r.ext, sizeString(r.size), df.string(from: r.modified)].map(csvQuote)
                lines.append(cells.joined(separator: ","))
            }
            return lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
        }
    }

    /// Quote a CSV field per RFC 4180 when it contains a comma, quote, or line break.
    ///
    /// `isNewline`, not a comparison against "\n" and "\r": in Swift a CRLF is one Character equal to
    /// neither, so a file named `a<CR><LF>b.txt` — legal on macOS — went through unquoted and split the
    /// row in two. Six files produced eight lines.
    static func csvQuote(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// A TSV field with the two characters that define the format escaped out of it.
    ///
    /// Tab-separated values have no quoting mechanism at all — a tab *is* the column separator and a
    /// newline *is* the row separator, so a file name containing either simply breaks the table. This is
    /// what "Copy file details" puts on the clipboard for pasting into a spreadsheet, where a shifted
    /// column is not obviously wrong, it is just wrong. Escaped rather than replaced, so the original
    /// name is still readable and recoverable.
    static func tsvEscape(_ field: String) -> String {
        var out = ""
        out.reserveCapacity(field.count)
        for character in field {
            switch character {
            case "\t": out += "\\t"
            case "\\": out += "\\\\"          // so an escape can be told from a literal backslash
            default:
                if character.isNewline { out += "\\n" } else { out.append(character) }
            }
        }
        return out
    }
}
