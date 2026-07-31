// SPDX-License-Identifier: Apache-2.0
// YAMLTidy.swift - Whitespace-only YAML cleanup, safe without a YAML parser.
//
// Foundation has no YAML parser, and in YAML indentation *is* structure: rewriting it
// without parsing can silently change what a document means, and the viewer's formatted
// output can be written to disk via Save As. So this performs only changes that cannot
// alter meaning, and skips block scalars entirely, where whitespace is content.
//
// When `yq` or `prettier` is installed, ExternalToolFormatter handles YAML instead and does
// a real structural format — while still keeping comments, which a parse-and-re-emit round
// trip through a YAML library would drop.

import Foundation

public enum YAMLTidy {
    /// Tidy `text`, or nil when there is nothing to change.
    ///
    /// - leading tabs become spaces (a tab in YAML indentation is illegal, so this repairs
    ///   a file rather than reinterpreting one)
    /// - trailing whitespace is removed
    /// - runs of blank lines collapse to one
    /// - the text ends with exactly one newline
    public static func tidy(_ text: String) -> String? {
        var out: [String] = []
        var blankRun = 0
        /// Indentation of the line that opened the current block scalar, or nil.
        var blockScalarParentIndent: Int?

        for line in text.components(separatedBy: "\n") {
            let indent = line.prefix { $0 == " " || $0 == "\t" }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Inside a block scalar: copy verbatim until a non-blank line is indented back
            // to (or past) the opening line's level.
            if let parent = blockScalarParentIndent {
                if trimmed.isEmpty || indent > parent {
                    out.append(line)
                    continue
                }
                blockScalarParentIndent = nil   // block ended; fall through and tidy this line
            }

            if trimmed.isEmpty {
                blankRun += 1
                if blankRun == 1 { out.append("") }
                continue
            }
            blankRun = 0

            // Tabs only in the *indentation* run. A tab anywhere else is left alone — not
            // because it is legal there (a tab separating key from value is invalid YAML
            // too) but because tabs are legal *content* inside quoted and block scalars, and
            // telling the two apart needs a parser. Converting the one case we can identify
            // is a repair; converting the rest could corrupt data.
            let leading = String(line.prefix(indent)).replacingOccurrences(of: "\t", with: "  ")
            out.append(leading + String(line.dropFirst(indent)).replacingOccurrences(
                of: "[ \t]+$", with: "", options: .regularExpression))

            if opensBlockScalar(trimmed) { blockScalarParentIndent = indent }
        }

        while out.last?.isEmpty == true { out.removeLast() }
        let result = out.joined(separator: "\n") + "\n"
        return result == text ? nil : result
    }

    /// Whether a (whitespace-trimmed) line ends in a block-scalar indicator, so the lines
    /// that follow are literal content: `key: |`, `- >-`, `key: |2+`, `key: | # note`.
    ///
    /// Errs towards *yes* on purpose. Wrongly assuming a block scalar only means a few lines
    /// are left untidied; wrongly missing one means trimming whitespace that is actually
    /// content, which corrupts the file.
    static func opensBlockScalar(_ trimmed: String) -> Bool {
        let code = stripTrailingComment(trimmed).trimmingCharacters(in: .whitespaces)
        guard let indicator = code.split(separator: " ").last.map(String.init),
              let first = indicator.first, first == "|" || first == ">" else { return false }
        // The rest may only be chomping (+/-) and an explicit indentation digit.
        return indicator.dropFirst().allSatisfy { $0 == "+" || $0 == "-" || $0.isNumber }
    }

    /// Drop a trailing `# …` comment, ignoring `#` inside quotes. A YAML comment starts at a
    /// `#` that follows whitespace, which is why `key: value#notacomment` is left alone.
    static func stripTrailingComment(_ line: String) -> String {
        var inSingle = false, inDouble = false, previousWasSpace = true
        for (offset, char) in line.enumerated() {
            switch char {
            case "'" where !inDouble: inSingle.toggle()
            case "\"" where !inSingle: inDouble.toggle()
            case "#" where !inSingle && !inDouble && previousWasSpace:
                return String(line.prefix(offset))
            default: break
            }
            previousWasSpace = (char == " " || char == "\t")
        }
        return line
    }
}
