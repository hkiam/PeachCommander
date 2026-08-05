// SPDX-License-Identifier: Apache-2.0
// StructureValidator.swift - Check a JSON, YAML or XML document and say *where* it is wrong (F-369).
//
// The editor can already format these files, and a formatter that fails is in fact a validator with a
// useless report: "the document could not be formatted" leaves the user to find the missing comma. What
// is needed is a position, so the caret can be put on it.
//
// The three formats get what they deserve:
//
//   * JSON — parsed by `JSONSerialization`, whose error carries a *byte* index. Converted here to the
//     UTF-16 offset a text view selects with, which is not the same number as soon as the file contains
//     one non-ASCII character; getting that wrong puts the caret near the problem and is worse than
//     useless, because it looks right.
//   * XML — parsed by `XMLParser` (libxml2), which reports line and column. `XMLDocument` gives a
//     tidier message and no position at all, so the position wins.
//   * YAML — there is no YAML parser on the system, and adding a dependency to validate a file is a
//     poor trade. So this checks the mistakes that actually happen and that are *decidable* without a
//     parser: a tab used for indentation (YAML forbids it outright), a duplicate key in one mapping
//     (last one silently wins), an unterminated quote, and indentation that matches no open level. It
//     says so in the result: `.checked` is not `.valid`, and the UI must not claim otherwise.
//
// Duplicate keys are reported for JSON too, where `JSONSerialization` accepts them silently — a
// duplicated key in a config file is a bug in every case, and no parser will tell you.

import Foundation

public enum StructureValidator {

    /// What a check can say. `.checked` means "no problem found by a check that is not a full parse".
    ///
    /// A *reason*, never a sentence: PCFoundation has no user-facing text (CONVENTIONS.md), and the
    /// strings it would produce are not in the app's String Catalog — `Tools/extract-strings.sh` reads
    /// PCApp's module only, so every message written here would have stayed English in all 18 languages.
    /// `StructureProblemText` in PCApp turns these into words.
    public enum Outcome: Equatable {
        case valid(parser: String)               // parsed, by the named parser
        case checked                             // structurally checked only, not parsed
        case problem(Problem)
        case unsupported
    }

    public struct Problem: Equatable {
        /// UTF-16 offset to put the caret on, clamped to the document.
        public let utf16Location: Int
        public let line: Int                     // 1-based, for the message
        public let reason: Reason
        public init(utf16Location: Int, line: Int, reason: Reason) {
            self.utf16Location = utf16Location; self.line = line; self.reason = reason
        }
    }

    public enum Reason: Equatable {
        /// What the platform's own parser said. Already localized by the system, and quoted as it is.
        case parser(String)
        /// …and the same for a format where comments are legal but the parser does not know that.
        case parserMayBeAboutComments(String)
        case duplicateKey(key: String, firstLine: Int)
        case trailingComma
        case tabIndentation
        /// Indented deeper than a line that already has a value.
        case indentedUnderValue
        /// Indented to a column that matches no open level; carries the columns that are open.
        case indentationMismatch(indent: Int, open: [Int])
        case unterminatedQuote
        case notWellFormedXML
    }

    public static func supports(ext: String) -> Bool { StructureOutline.supports(ext: ext) }

    public static func validate(_ text: String, ext: String) -> Outcome {
        let e = ext.lowercased()
        if ["json", "jsonc", "geojson", "webmanifest", "jsonl", "ndjson"].contains(e) {
            return validateJSON(text, allowComments: e == "jsonc")
        }
        if ["yaml", "yml"].contains(e) { return validateYAML(text) }
        if StructureOutline.supports(ext: e) { return validateXML(text) }
        return .unsupported
    }

    // MARK: - JSON

    static func validateJSON(_ text: String, allowComments: Bool) -> Outcome {
        let data = Data(text.utf8)
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch let error as NSError {
            let byteIndex = error.userInfo["NSJSONSerializationErrorIndex"] as? Int ?? 0
            let location = utf16Offset(forUTF8Byte: byteIndex, in: text)
            let message = (error.userInfo[NSDebugDescriptionErrorKey] as? String)
                ?? error.localizedDescription
            // .jsonc legitimately has comments and JSONSerialization does not know that, so a failure
            // there may be about a comment rather than about the document — a different sentence.
            let reason: Reason = allowComments ? .parserMayBeAboutComments(message) : .parser(message)
            return .problem(Problem(utf16Location: location, line: line(at: location, in: text),
                                    reason: reason))
        }
        // A trailing comma is *not* an error to JSONSerialization and is an error to almost everything
        // else — Python, Go, jq, and every JSON schema tool. Reporting it here is the difference between
        // finding out now and finding out in a deployment pipeline. `.jsonc` allows it by design.
        if !allowComments, let comma = firstTrailingComma(text) { return .problem(comma) }
        if let duplicate = firstDuplicateJSONKey(text) { return .problem(duplicate) }
        return .valid(parser: "JSONSerialization")
    }

    /// The comma directly before a `}` or `]`, if there is one.
    ///
    /// Scanned over the text rather than derived from the parsed value, because by then it is gone.
    /// Strings are skipped so a comma inside `"a,"` is not mistaken for structure.
    static func firstTrailingComma(_ text: String) -> Problem? {
        let c = Array(text)
        var i = 0
        var lastComma: Int?
        var sawSomethingSince = false
        while i < c.count {
            let ch = c[i]
            if ch == "\"" {                                    // a string: find its end, escapes and all
                var j = i + 1
                while j < c.count {
                    if c[j] == "\\" { j += 2; continue }
                    if c[j] == "\"" { break }
                    j += 1
                }
                i = min(j + 1, c.count)
                sawSomethingSince = true
                continue
            }
            if ch == "," {
                lastComma = i
                sawSomethingSince = false
            } else if ch == "}" || ch == "]" {
                if let comma = lastComma, !sawSomethingSince {
                    let location = utf16Offset(forUTF8Byte: String(c[0..<comma]).utf8.count, in: text)
                    return Problem(utf16Location: location, line: line(at: location, in: text),
                                   reason: .trailingComma)
                }
                lastComma = nil
                sawSomethingSince = false
            } else if !ch.isWhitespace {
                sawSomethingSince = true
            }
            i += 1
        }
        return nil
    }

    /// The first key that appears twice in the same object. Scanner-based, so it works on the text rather
    /// than on the parsed value — where the duplicate is already gone.
    private static func firstDuplicateJSONKey(_ text: String) -> Problem? {
        let roots = StructureOutline.parseJSON(text)
        return firstDuplicate(in: roots, text: text)
    }

    private static func firstDuplicate(in nodes: [SymbolNode], text: String) -> Problem? {
        var seen: [String: Int] = [:]
        for node in nodes {
            // Array elements are "[0]", "[1]" — different by construction, and not keys.
            if !node.name.hasPrefix("["), let firstLine = seen[node.name] {
                return Problem(utf16Location: node.utf16Location, line: node.line,
                               reason: .duplicateKey(key: node.name, firstLine: firstLine))
            }
            seen[node.name] = node.line
            if let inner = firstDuplicate(in: node.children, text: text) { return inner }
        }
        return nil
    }

    // MARK: - XML

    static func validateXML(_ text: String) -> Outcome {
        guard let data = text.data(using: .utf8) else { return .unsupported }
        let parser = XMLParser(data: data)
        let collector = ErrorCollector()
        parser.delegate = collector
        if parser.parse(), collector.error == nil { return .valid(parser: "XMLParser") }
        let line = collector.line ?? parser.lineNumber
        let column = collector.column ?? parser.columnNumber
        let location = utf16Offset(line: line, column: column, in: text)
        let message = collector.error?.localizedDescription ?? parser.parserError?.localizedDescription
        return .problem(Problem(utf16Location: location, line: line,
                                reason: message.map(Reason.parser) ?? .notWellFormedXML))
    }

    /// `XMLParser` reports the error to its delegate and then forgets the position, so it is kept here.
    private final class ErrorCollector: NSObject, XMLParserDelegate {
        var error: Error?
        var line: Int?
        var column: Int?
        func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
            guard error == nil else { return }       // the first one is the one to jump to
            error = parseError; line = parser.lineNumber; column = parser.columnNumber
        }
        func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
            self.parser(parser, parseErrorOccurred: validationError)
        }
    }

    // MARK: - YAML

    static func validateYAML(_ text: String) -> Outcome {
        // One frame per indentation level open at the current line, each with the keys seen in *that*
        // mapping. A stack rather than a dictionary keyed by indentation: `a:\n  x: 1\nb:\n  x: 2` has two
        // mappings at indentation 2, and treating them as one made the second `x` a duplicate.
        struct Frame { let indent: Int; var keys: [String: Int] }
        var stack: [Frame] = [Frame(indent: 0, keys: [:])]
        var offset = 0
        var lineNumber = 0
        var blockScalarIndent: Int?
        // A plain or quoted scalar may run over several lines, and a flow collection may too. Each of
        // those cases produces lines that are indented deeper than a line which already has a value —
        // legal YAML that an earlier version of this check rejected in four of this repository's own
        // files. Continuation is therefore tracked, not guessed.
        var continuationIndent: Int?                 // a plain scalar continued on deeper lines
        var openQuote: (character: Character, line: Int, location: Int)?
        var flowDepth = 0
        var previousOpensBlock = true
        var previousIndent = -1

        for rawLine in text.components(separatedBy: "\n") {
            lineNumber += 1
            defer { offset += rawLine.utf16.count + 1 }
            let indent = rawLine.prefix { $0 == " " }.count
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            // A quoted scalar that ran past the end of its line: everything up to the closing quote is
            // that scalar's text, wherever it ends.
            if let open = openQuote {
                // An *unescaped* quote closes it. `<li class=\\"license\\">` inside a double-quoted scalar
                // contains two quotes and closes nothing — taking any quote as the end put this check
                // back into the middle of a 200-line licence text and it reported keys in prose.
                if closesQuotedScalar(trimmed, quote: open.character) { openQuote = nil }
                continue
            }
            if let block = blockScalarIndent {
                if trimmed.isEmpty || indent > block { continue }
                blockScalarIndent = nil
            }
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if flowDepth > 0 {
                flowDepth += flowBalance(of: trimmed)          // still inside `[ … ]` or `{ … }`
                continue
            }

            // A tab in the indentation is not a style question: YAML forbids tabs for indentation, and
            // the error a real parser gives for it points somewhere else entirely.
            if let tab = rawLine.prefix(while: { $0 == " " || $0 == "\t" }).firstIndex(of: "\t") {
                let column = rawLine.distance(from: rawLine.startIndex, to: tab)
                return .problem(Problem(utf16Location: offset + column, line: lineNumber,
                                        reason: .tabIndentation))
            }
            if trimmed.hasPrefix("---") || trimmed.hasPrefix("...") {
                stack = [Frame(indent: 0, keys: [:])]
                previousOpensBlock = true
                previousIndent = -1
                continuationIndent = nil
                continue
            }

            let isItem = trimmed.hasPrefix("- ") || trimmed == "-"
            let mapping = isItem ? String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                                 : trimmed
            let colon = StructureOutline.mappingColon(in: mapping)

            // Deeper than a line that already had a value. A plain scalar legitimately continues that
            // way — `alt: some long text` and `  more text` on the next line is one value — but a
            // continuation cannot contain `key: value`, because a plain scalar may not contain ": ".
            // So the presence of a mapping is what separates a continuation from the one-space slip.
            if let continuation = continuationIndent, indent > continuation {
                guard colon != nil, !isItem else { continue }
                return .problem(Problem(utf16Location: offset, line: lineNumber,
                                        reason: .indentedUnderValue))
            }
            continuationIndent = nil

            if let quote = unterminatedQuote(in: trimmed) {
                // Not an error yet: a quoted scalar may run over several lines. Remembered, and reported
                // at the end of the document if it never closes.
                let index = trimmed.index(trimmed.startIndex, offsetBy: quote)
                openQuote = (trimmed[index], lineNumber, offset + indent + quote)
            }

            if indent > previousIndent {
                stack.append(Frame(indent: indent, keys: [:]))
                // `- scope:` puts its mapping at the column *after* the dash, and the item's other keys
                // line up there, not with the dash. Without that level, every `- key:` block followed by
                // a sibling key looked misindented — which is how Homebrew's own _config.yml is written.
                if isItem, contentIndent(of: rawLine, indent: indent) > indent {
                    stack.append(Frame(indent: contentIndent(of: rawLine, indent: indent), keys: [:]))
                }
            } else if indent < previousIndent {
                // Coming back out: the indentation must be a level that is still open, or it lines up
                // with nothing — the classic one-space slip, which a real parser reports several lines
                // later as "mapping values are not allowed here", if at all.
                while let top = stack.last, top.indent > indent { stack.removeLast() }
                guard stack.last?.indent == indent else {
                    return .problem(Problem(utf16Location: offset, line: lineNumber,
                                            reason: .indentationMismatch(indent: indent,
                                                                         open: stack.map(\.indent))))
                }
            }
            if isItem {
                let content = contentIndent(of: rawLine, indent: indent)
                if content > indent, stack.last?.indent != content {
                    stack.append(Frame(indent: content, keys: [:]))
                }
                previousIndent = content - 1        // the item's keys are deeper than the dash
            } else {
                previousIndent = indent
            }
            previousOpensBlock = isItem
            flowDepth = max(0, flowBalance(of: trimmed))

            // A duplicate key in one mapping: accepted by some parsers, rejected by others, and always a
            // bug — the second value silently replaces the first. `- key: value` carries a key too.
            if let colon {
                let key = String(mapping[mapping.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
                let after = String(mapping[mapping.index(after: colon)...])
                    .trimmingCharacters(in: .whitespaces)
                if !isItem, !key.isEmpty, let first = stack.last?.keys[key] {
                    return .problem(Problem(utf16Location: offset + indent, line: lineNumber,
                                            reason: .duplicateKey(key: key, firstLine: first)))
                }
                if !isItem, !key.isEmpty { stack[stack.count - 1].keys[key] = lineNumber }
                // `key:` with nothing after it opens a mapping, and so does `key: &anchor` — an anchor or
                // a tag is not the value. Anything else *is* a value, and deeper lines below it can only
                // be that scalar continuing.
                let value = withoutAnchorOrTag(after)
                previousOpensBlock = value.isEmpty || isItem
                if value.hasPrefix("|") || value.hasPrefix(">") {
                    blockScalarIndent = indent
                    previousOpensBlock = false
                } else if !value.isEmpty, !isItem, openQuote == nil, flowDepth == 0 {
                    // Only a plain mapping value can continue on deeper lines. Under `- uses: checkout`
                    // the deeper lines are the *item's* remaining keys (`with:`), which is how a GitHub
                    // workflow is written — treating them as scalar text rejected every one of them.
                    continuationIndent = indent
                }
            }
        }
        if let open = openQuote {
            return .problem(Problem(utf16Location: open.location, line: open.line,
                                    reason: .unterminatedQuote))
        }
        return .checked
    }

    /// The column where a list item's own content begins: `- scope:` at indentation 2 has its mapping at
    /// column 4, and the item's remaining keys line up there.
    static func contentIndent(of rawLine: String, indent: Int) -> Int {
        let afterDash = rawLine.dropFirst(indent + 1)
        return indent + 1 + afterDash.prefix { $0 == " " }.count
    }

    /// Whether a line closes a quoted scalar opened on an earlier line — the first quote that is not
    /// escaped (`\\"` in a double-quoted scalar, `''` in a single-quoted one).
    static func closesQuotedScalar(_ line: String, quote: Character) -> Bool {
        let c = Array(line)
        var i = 0
        while i < c.count {
            if c[i] == quote {
                if quote == "'", i + 1 < c.count, c[i + 1] == "'" { i += 2; continue }
                if quote == "\"", i > 0, c[i - 1] == "\\" { i += 1; continue }
                return true
            }
            i += 1
        }
        return false
    }

    /// The column of a quote that opens a quoted scalar and is never closed on this line.
    ///
    /// Only *at the start of a scalar*: after `: `, after `- `, inside a flow collection, or at the start
    /// of the line (a quoted key). An apostrophe in the middle of a plain scalar — "the plugin's settings
    /// window" — is an ordinary character, and treating it as a quote made this fire on four of this
    /// repository's own, perfectly valid YAML files.
    static func unterminatedQuote(in line: String) -> Int? {
        let c = Array(line)
        var i = 0
        var atScalarStart = true                      // the line begins with a key, which may be quoted
        while i < c.count {
            let ch = c[i]
            if atScalarStart, ch == "\"" || ch == "'" {
                guard let close = closingQuote(c, from: i) else { return i }
                i = close + 1
                atScalarStart = false
                continue
            }
            if ch == "#", i == 0 || c[i - 1] == " " { return nil }              // a trailing comment
            if ch == " " { i += 1; continue }                                  // spaces keep the position
            if ch == ":", i + 1 >= c.count || c[i + 1] == " " { atScalarStart = true; i += 1; continue }
            if ch == "-", i == 0, i + 1 < c.count, c[i + 1] == " " { atScalarStart = true; i += 1; continue }
            if ch == "[" || ch == "{" || ch == "," { atScalarStart = true; i += 1; continue }
            atScalarStart = false
            i += 1
        }
        return nil
    }

    /// The index of the quote closing the one at `open`, honouring `''` and `\"` escapes.
    private static func closingQuote(_ c: [Character], from open: Int) -> Int? {
        let quote = c[open]
        var i = open + 1
        while i < c.count {
            if c[i] == quote {
                if quote == "'", i + 1 < c.count, c[i + 1] == "'" { i += 2; continue }     // '' is one '
                if quote == "\"", c[i - 1] == "\\" { i += 1; continue }
                return i
            }
            i += 1
        }
        return nil
    }

    /// `[` and `{` minus `]` and `}` on a line, ignoring quoted spans and a trailing comment.
    static func flowBalance(of line: String) -> Int {
        let c = Array(line)
        var depth = 0
        var i = 0
        while i < c.count {
            switch c[i] {
            case "\"", "'":
                i = (closingQuote(c, from: i) ?? c.count - 1) + 1
                continue
            case "#" where i == 0 || c[i - 1] == " ":
                return depth
            case "[", "{": depth += 1
            case "]", "}": depth -= 1
            default: break
            }
            i += 1
        }
        return depth
    }

    /// A value with a leading anchor (`&name`) and/or tag (`!tag`) removed, so `key: &main` is seen for
    /// what it is: a key with no value yet, which a nested block belongs to.
    static func withoutAnchorOrTag(_ value: String) -> String {
        var rest = value
        for _ in 0..<2 {
            guard rest.hasPrefix("&") || rest.hasPrefix("!") else { break }
            let token = rest.prefix { !$0.isWhitespace }
            rest = String(rest.dropFirst(token.count)).trimmingCharacters(in: .whitespaces)
        }
        return rest
    }

    // MARK: - Offsets

    /// A UTF-8 byte index (what `JSONSerialization` reports) as the UTF-16 offset a text view selects
    /// with. The two agree only for ASCII; one umlaut earlier in the file and they part company.
    static func utf16Offset(forUTF8Byte byteIndex: Int, in text: String) -> Int {
        let bytes = Array(text.utf8)
        guard byteIndex > 0 else { return 0 }
        let clamped = min(byteIndex, bytes.count)
        // A byte index can land inside a multi-byte character; back up to a boundary so the prefix
        // decodes at all.
        // Back up while the byte *at* the boundary is a continuation byte: `end` must be where a
        // character starts. Looking at `end - 1` instead left a lead byte as the last byte of the
        // prefix, which decodes to a replacement character and counted one UTF-16 unit too many.
        var end = clamped
        while end > 0, end < bytes.count, bytes[end] & 0b1100_0000 == 0b1000_0000 { end -= 1 }
        let prefix = String(decoding: bytes[0..<end], as: UTF8.self)
        return prefix.utf16.count
    }

    /// A 1-based line and column (what `XMLParser` reports) as a UTF-16 offset.
    static func utf16Offset(line: Int, column: Int, in text: String) -> Int {
        var offset = 0
        var current = 1
        for l in text.components(separatedBy: "\n") {
            if current == line {
                return offset + min(max(column - 1, 0), l.utf16.count)
            }
            offset += l.utf16.count + 1
            current += 1
        }
        return min(offset, text.utf16.count)
    }

    /// The 1-based line a UTF-16 offset falls on.
    static func line(at location: Int, in text: String) -> Int {
        var offset = 0
        var line = 1
        for l in text.components(separatedBy: "\n") {
            let next = offset + l.utf16.count + 1
            if location < next { return line }
            offset = next
            line += 1
        }
        return max(line - 1, 1)
    }
}
