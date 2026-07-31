// SPDX-License-Identifier: Apache-2.0
// StructuredTextFormatter.swift - Pretty-print JSON and XML for the viewer (TODOS #20/#21).
//
// Pure formatting over Foundation (JSONSerialization / XMLDocument): returns a
// re-indented string, or nil when the input is not valid JSON/XML. The viewer's
// "format" action tries these so JSON/XML files can be read structured.

import Foundation

public enum StructuredTextFormatter {
    /// Pretty-print `text` as JSON (sorted keys), or nil if it is not valid JSON.
    public static func json(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let pretty = try? JSONSerialization.data(withJSONObject: object,
                                                       options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }
        return String(data: pretty, encoding: .utf8)
    }

    /// Pretty-print `text` as XML, or nil if it is not well-formed XML.
    public static func xml(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let doc = try? XMLDocument(data: data, options: []) else { return nil }
        return String(data: doc.xmlData(options: [.nodePrettyPrint]), encoding: .utf8)
    }

    /// Tidy YAML whitespace, or nil when there is nothing to change.
    ///
    /// **Deliberately a tidy, not a re-indent.** JSON and XML above go through real
    /// parsers (JSONSerialization / XMLDocument), so they can be rebuilt from the parsed
    /// tree and invalid input safely yields nil. Foundation has no YAML parser, and in
    /// YAML *indentation is structure* — a re-indent without a parser can silently change
    /// what a document means, and the viewer's formatted output can be written back out
    /// via Save As. So this only performs changes that cannot alter meaning:
    ///
    /// - leading tabs become spaces (a tab in YAML indentation is illegal, so this fixes
    ///   a file rather than reinterpreting one)
    /// - trailing whitespace is removed
    /// - runs of blank lines collapse to one
    /// - the text ends with exactly one newline
    ///
    /// All of it is skipped inside block scalars (`|`, `>` and their variants), where
    /// leading and trailing whitespace is *content* — trimming there would corrupt data.
    /// Comments survive, which a parse-and-re-emit round trip would not manage.
    public static func yaml(_ text: String) -> String? {
        var out: [String] = []
        var blankRun = 0
        /// Indentation of the line that opened the current block scalar, or nil.
        var blockScalarParentIndent: Int?

        for line in text.components(separatedBy: "\n") {
            let indent = line.prefix { $0 == " " || $0 == "\t" }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Inside a block scalar: copy verbatim until a non-blank line is indented
            // back to (or past) the opening line's level.
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
            // because it is legal there (a tab separating key from value is in fact
            // invalid YAML too) but because tabs are legal *content* inside quoted and
            // block scalars, and telling the two apart needs a parser. Converting the one
            // case we can identify is a repair; converting the rest could corrupt data.
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
    /// Errs towards *yes* on purpose. Wrongly assuming a block scalar only means a few
    /// lines are left untidied; wrongly missing one means trimming whitespace that is
    /// actually content, which corrupts the file.
    private static func opensBlockScalar(_ trimmed: String) -> Bool {
        let code = stripTrailingComment(trimmed).trimmingCharacters(in: .whitespaces)
        guard let indicator = code.split(separator: " ").last.map(String.init),
              let first = indicator.first, first == "|" || first == ">" else { return false }
        // The rest may only be chomping (+/-) and an explicit indentation digit.
        return indicator.dropFirst().allSatisfy { $0 == "+" || $0 == "-" || $0.isNumber }
    }

    /// Drop a trailing `# …` comment, ignoring `#` inside quotes. A YAML comment starts at
    /// a `#` that follows whitespace, which is why `key: value#notacomment` is left alone.
    private static func stripTrailingComment(_ line: String) -> String {
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

    /// Try to format `text` as XML (when `preferXML`) then JSON, or JSON then XML.
    /// Returns the formatted string and which kind matched, or nil if neither parses.
    public static func autoFormat(_ text: String, preferXML: Bool) -> (text: String, kind: String)? {
        let json = { self.json(text).map { ($0, "JSON") } }
        let xml = { self.xml(text).map { ($0, "XML") } }
        if preferXML { return xml() ?? json() }
        return json() ?? xml()
    }

    /// Format according to the file's extension: YAML is tidied, `.xml`-ish files prefer
    /// the XML parser, everything else tries JSON first.
    ///
    /// YAML is selected by extension rather than by sniffing, because almost any text is
    /// "valid YAML" — trying it as a fallback would tidy plain text files that the user
    /// only wanted checked for JSON.
    public static func autoFormat(_ text: String, extension ext: String) -> (text: String, kind: String)? {
        switch ext.lowercased() {
        case "yml", "yaml":
            return yaml(text).map { ($0, "YAML") }
        default:
            return autoFormat(text, preferXML: ext.lowercased() == "xml")
        }
    }
}
