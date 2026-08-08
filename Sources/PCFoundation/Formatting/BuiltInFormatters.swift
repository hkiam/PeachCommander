// SPDX-License-Identifier: Apache-2.0
// BuiltInFormatters.swift - Formatters that need nothing installed.
//
// Each one is backed by a real parser the platform already ships, so invalid input fails
// cleanly instead of being mangled: JSONSerialization, and libxml2 via XMLDocument (both
// for XML and, with .documentTidyHTML, for HTML). The INI formatter reuses the project's
// own INIDocument. Nothing here rewrites text by pattern matching.

import Foundation

/// JSON via JSONSerialization. Keys are sorted, which makes diffs stable — the previous
/// behaviour, kept deliberately.
public struct JSONFormatter: TextFormatter {
    public let name = "JSON"
    public let supportedExtensions = ["json", "jsonc", "geojson", "webmanifest"]
    public init() {}

    public func format(_ text: String) throws -> String {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let pretty = try? JSONSerialization.data(withJSONObject: object,
                                                       options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: pretty, encoding: .utf8) else {
            throw FormatError.invalidInput("JSON")
        }
        guard result != text else { throw FormatError.unchanged }
        return result
    }
}

/// XML via XMLDocument, which is libxml2 underneath.
public struct XMLFormatter: TextFormatter {
    public let name = "XML"
    public let supportedExtensions = [
        "xml", "svg", "plist", "xsd", "xsl", "xslt", "storyboard", "xib", "rss", "atom", "pom"
    ]
    public init() {}

    public func format(_ text: String) throws -> String {
        guard let data = text.data(using: .utf8),
              let doc = try? XMLDocument(data: data, options: []),
              let result = String(data: doc.xmlData(options: [.nodePrettyPrint]), encoding: .utf8) else {
            throw FormatError.invalidInput("XML")
        }
        guard result != text else { throw FormatError.unchanged }
        return result
    }
}

/// HTML via libxml2's HTML parser (`.documentTidyHTML`), which is lenient about the
/// tag soup real pages contain — an XML parse would simply reject most of it.
public struct HTMLFormatter: TextFormatter {
    public let name = "HTML"
    public let supportedExtensions = ["html", "htm", "xhtml"]
    public init() {}

    public func format(_ text: String) throws -> String {
        guard let data = text.data(using: .utf8),
              let doc = try? XMLDocument(data: data, options: [.documentTidyHTML]),
              let result = String(data: doc.xmlData(options: [.nodePrettyPrint]), encoding: .utf8) else {
            throw FormatError.invalidInput("HTML")
        }
        guard result != text else { throw FormatError.unchanged }
        return result
    }
}

/// INI/conf via the project's own INIDocument, so the app formats these files exactly the
/// way it writes its own configuration. Parse-and-serialise is the canonical form.
public struct INIFormatter: TextFormatter {
    public let name = "INI"
    public let supportedExtensions = ["ini", "conf", "cfg", "properties"]
    public init() {}

    public func format(_ text: String) throws -> String {
        // Normalizing on purpose: this is the Format command, so the point is to tidy `key = value`
        // into `key=value`. Saving a configuration file uses the default, which leaves untouched lines
        // exactly as their author wrote them.
        let result = INIDocument(parsing: text).serialized(normalizing: true)
        guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FormatError.invalidInput("INI")
        }
        guard result != text else { throw FormatError.unchanged }
        return result
    }
}

/// YAML whitespace tidy — the conservative fallback used when no external YAML tool is
/// installed.
///
/// Not a re-indent, and that is the point: YAML indentation *is* structure, so rewriting it
/// without a parser can silently change what a document means, and formatted output can be
/// written back to disk. Everything here is skipped inside block scalars, where whitespace
/// is content. See YAMLTidy for the transformation list.
///
/// For real structural formatting, install `yq` or `prettier` — ExternalToolFormatter takes
/// precedence over this one and both preserve comments, which a parse-and-re-emit round trip
/// through a YAML library would not.
public struct YAMLTidyFormatter: TextFormatter {
    public let name = "YAML"
    public let supportedExtensions = ["yml", "yaml"]
    public init() {}

    public func format(_ text: String) throws -> String {
        guard let result = YAMLTidy.tidy(text) else { throw FormatError.unchanged }
        return result
    }
}
