// SPDX-License-Identifier: Apache-2.0
// StructureTransforms.swift - Whole-document transformations for JSON, YAML and XML (F-370).
//
// The Format button already pretty-prints these formats. What is missing is everything else an
// administrator does to a config file before it goes anywhere:
//
//   * minify — a JSON body for a curl command, or a request that has to fit on one line
//   * sort keys — so two exports of the same settings diff to nothing
//   * escape / unescape as a JSON string — the daily chore when a certificate, a script or a whole JSON
//     document has to be *inside* a JSON field, and doing it by hand is how a `\\n` becomes a newline
//   * JSON → YAML — reading a machine-generated payload, or moving a snippet into a compose file
//
// Each one is a parse-and-re-emit through the platform's own parser, so invalid input fails cleanly
// instead of being mangled: `JSONSerialization` for JSON, and nothing at all where a parser is missing —
// YAML → JSON is deliberately absent, see `unsupportedDirection`.
//
// Comments are the reason these are separate from the formatter and from each other. A JSON round trip
// through `JSONSerialization` discards nothing (JSON has no comments), while the same round trip through
// a YAML library would throw away every comment in the file — which is why the YAML formatter is a
// whitespace tidy and why there is no YAML → JSON here.

import Foundation

public enum StructureTransforms {

    public enum Transform: String, CaseIterable, Sendable {
        case minify
        case sortKeys
        case escapeAsJSONString
        case unescapeJSONString
        case jsonToYAML
    }

    public enum TransformError: Error, Equatable {
        /// The document did not parse; carries the parser's own message.
        case invalid(String)
        /// The transform does not apply to this format.
        case notApplicable
        /// The value cannot be represented in the target format.
        case cannotRepresent(String)
    }

    /// Which transforms make sense for a file extension.
    ///
    /// Escaping works on *any* text — a certificate, a shell script, a log line — so it is offered
    /// everywhere; the rest need JSON.
    public static func available(forExtension ext: String) -> [Transform] {
        let e = ext.lowercased()
        let json = ["json", "jsonc", "geojson", "webmanifest", "jsonl", "ndjson"].contains(e)
        if json { return Transform.allCases }
        return [.escapeAsJSONString, .unescapeJSONString]
    }

    public static func apply(_ transform: Transform, to text: String, ext: String) throws -> String {
        switch transform {
        case .minify: return try minifyJSON(text)
        case .sortKeys: return try sortJSONKeys(text)
        case .escapeAsJSONString: return escapeAsJSONString(text)
        case .unescapeJSONString: return try unescapeJSONString(text)
        case .jsonToYAML: return try jsonToYAML(text)
        }
    }

    // MARK: - JSON

    /// The document with every avoidable byte removed. Key order is preserved.
    ///
    /// Not `JSONSerialization.data(withJSONObject:)`: that loses key order (a dictionary has none) and
    /// rewrites numbers, so `1.0` comes back as `1` and a 20-digit id as `1.2345678901234567e+19`. A
    /// config file must survive a round trip unchanged, so this walks the text and drops the whitespace
    /// between tokens, and hands the *result* to the platform's parser to confirm it is valid JSON.
    public static func minifyJSON(_ text: String) throws -> String {
        var out = String()
        out.reserveCapacity(text.count)
        var inString = false
        var escaped = false
        var iterator = text.makeIterator()
        var pending: Character?
        while let c = pending ?? iterator.next() {
            pending = nil
            if inString {
                out.append(c)
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inString = false }
                continue
            }
            switch c {
            case "\"":
                inString = true
                out.append(c)
            case " ", "\t", "\n", "\r":
                continue                                  // between tokens: not needed
            case "/":
                // A comment in .jsonc. Dropped along with the whitespace, since minified output is for
                // a machine — and keeping it would need the newline that ends it.
                guard let next = iterator.next() else { out.append(c); continue }
                if next == "/" {
                    while let d = iterator.next(), d != "\n" {}
                } else if next == "*" {
                    var previous: Character = " "
                    while let d = iterator.next() {
                        if previous == "*" && d == "/" { break }
                        previous = d
                    }
                } else {
                    out.append(c)
                    pending = next
                }
            default:
                out.append(c)
            }
        }
        // Validated *afterwards*, on the result: comments are legal in `.jsonc` and unknown to
        // JSONSerialization, so checking the input first rejected every file this transform is for. What
        // matters is that what comes out is valid JSON. The position in the message therefore refers to
        // the minified text — Validate Document is the command that puts the caret on a problem.
        try validateJSON(out)
        return out
    }

    /// The document re-emitted with every object's keys in order, and indented.
    ///
    /// Here the round trip through `JSONSerialization` is the point — sorting *is* a reordering — and the
    /// numeric rewriting it does is the price. `.withoutEscapingSlashes` keeps URLs readable.
    public static func sortJSONKeys(_ text: String) throws -> String {
        try validateJSON(text)
        guard let value = try? JSONSerialization.jsonObject(with: Data(text.utf8),
                                                           options: [.fragmentsAllowed]),
              let data = try? JSONSerialization.data(withJSONObject: value,
                                                     options: [.prettyPrinted, .sortedKeys,
                                                               .withoutEscapingSlashes,
                                                               .fragmentsAllowed]),
              let out = String(data: data, encoding: .utf8) else {
            throw TransformError.cannotRepresent("JSONSerialization")
        }
        return out
    }

    private static func validateJSON(_ text: String) throws {
        do {
            _ = try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
        } catch let error as NSError {
            throw TransformError.invalid((error.userInfo[NSDebugDescriptionErrorKey] as? String)
                                         ?? error.localizedDescription)
        }
    }

    // MARK: - Escaping

    /// The text as a JSON string *including* its quotes, ready to paste into a JSON field.
    ///
    /// Produced by `JSONSerialization` rather than by replacing characters: control characters, U+2028 and
    /// lone surrogates all have rules, and a hand-rolled escaper gets one of them wrong.
    public static func escapeAsJSONString(_ text: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: text,
                                                 options: [.fragmentsAllowed]),
           let out = String(data: data, encoding: .utf8) {
            return out
        }
        // Unreachable for a Swift String, which is always valid Unicode — but a fallback beats a crash.
        return "\"" + text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n") + "\""
    }

    /// The other direction: a JSON string literal turned back into the text it stands for.
    ///
    /// The quotes are optional, because the text on the clipboard usually comes from *inside* a document
    /// and arrives without them.
    public static func unescapeJSONString(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let quoted = trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2
            ? trimmed
            : "\"" + trimmed.replacingOccurrences(of: "\"", with: "\\\"") + "\""
        do {
            let value = try JSONSerialization.jsonObject(with: Data(quoted.utf8),
                                                         options: [.fragmentsAllowed])
            guard let string = value as? String else { throw TransformError.notApplicable }
            return string
        } catch let error as NSError {
            throw TransformError.invalid((error.userInfo[NSDebugDescriptionErrorKey] as? String)
                                         ?? error.localizedDescription)
        }
    }

    // MARK: - JSON → YAML

    /// A JSON document as block-style YAML.
    ///
    /// One direction only. The reverse needs a YAML parser, and there is none on the system: writing one
    /// would mean anchors, aliases, tags, block scalars and five ways to spell `true`, and getting any of
    /// them wrong turns a config file into a different config file. `unsupportedDirection` says so.
    public static func jsonToYAML(_ text: String) throws -> String {
        try validateJSON(text)
        guard let value = try? JSONSerialization.jsonObject(
            with: Data(text.utf8), options: [.fragmentsAllowed, .mutableContainers]) else {
            throw TransformError.cannotRepresent("JSONSerialization")
        }
        var out = ""
        emitYAML(value, indent: 0, into: &out, atLineStart: true)
        return out
    }

    /// Why there is no YAML → JSON, for the UI to say out loud.
    public static let unsupportedDirection = "YAML → JSON"

    private static func emitYAML(_ value: Any, indent: Int, into out: inout String,
                                 atLineStart: Bool) {
        let pad = String(repeating: " ", count: indent)
        switch value {
        case let dict as [String: Any]:
            if dict.isEmpty { out += (atLineStart ? pad : " ") + "{}\n"; return }
            if !atLineStart { out += "\n" }
            for key in dict.keys.sorted() {
                out += pad + yamlKey(key) + ":"
                emitYAML(dict[key]!, indent: indent + 2, into: &out, atLineStart: false)
            }
        case let array as [Any]:
            if array.isEmpty { out += (atLineStart ? pad : " ") + "[]\n"; return }
            if !atLineStart { out += "\n" }
            for element in array {
                out += pad + "-"
                emitYAML(element, indent: indent + 2, into: &out, atLineStart: false)
            }
        default:
            out += (atLineStart ? pad : " ") + yamlScalar(value) + "\n"
        }
    }

    /// A key, quoted when it would otherwise not read back as the same key.
    private static func yamlKey(_ key: String) -> String {
        let plain = !key.isEmpty
            && key.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "." }
        return plain ? key : escapeAsJSONString(key)
    }

    /// A scalar in YAML. Strings that YAML would read as something else — `true`, `12`, `~`, `null`, a
    /// date — are quoted, because "the version is the string 1.10" is exactly the distinction that gets
    /// lost when a JSON payload is copied into a compose file.
    private static func yamlScalar(_ value: Any) -> String {
        switch value {
        case is NSNull: return "null"
        case let b as Bool: return b ? "true" : "false"
        case let n as NSNumber:
            // NSNumber does not remember whether it was written 1 or 1.0; CFNumber's type does.
            if CFNumberIsFloatType(n) { return "\(n.doubleValue)" }
            return "\(n.int64Value)"
        case let s as String:
            let ambiguous = ["true", "false", "yes", "no", "on", "off", "null", "~", "y", "n"]
            let looksNumeric = Double(s) != nil
            let looksSpecial = ambiguous.contains(s.lowercased()) || looksNumeric || s.isEmpty
            let needsQuotes = looksSpecial
                || s.contains(": ") || s.hasSuffix(":") || s.contains(" #")
                || s.contains("\n") || s.hasPrefix("#") || s.hasPrefix("-") || s.hasPrefix("*")
                || s.hasPrefix("&") || s.hasPrefix("!") || s.hasPrefix("[") || s.hasPrefix("{")
                || s.hasPrefix("'") || s.hasPrefix("\"") || s.hasPrefix(" ") || s.hasSuffix(" ")
            return needsQuotes ? escapeAsJSONString(s) : s
        default:
            return escapeAsJSONString("\(value)")
        }
    }
}
