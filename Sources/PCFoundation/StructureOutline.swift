// SPDX-License-Identifier: Apache-2.0
// StructureOutline.swift - An outline for JSON, YAML and XML (F-368).
//
// The editor's symbol sidebar is driven by tree-sitter tag queries, and for exactly the three formats an
// administrator edits most it shows nothing: JSON's grammar is vendored but has `tagsResource: nil`
// (there are no "definitions" in JSON), and YAML and XML have no grammar at all. So a 900-line
// docker-compose.yml or a plist gets a blank sidebar, an empty breadcrumb and no way to jump to a key.
//
// This produces the same `SymbolNode` tree the tree-sitter path produces, so the sidebar, its filter
// field, the breadcrumb in the status line and go-to-definition all work unchanged.
//
// Deliberately a scanner, not a parser:
//
//   * `JSONSerialization` and `XMLDocument` both parse these formats perfectly and both throw the
//     positions away. An outline whose entries cannot be jumped to is decoration, so offsets are what
//     this is for, and that means walking the text.
//   * It also means a *broken* document still gets an outline down to the point where it breaks, which
//     is when a structure view is most useful. A parser gives nothing at all for a missing brace.
//
// YAML is scanned by indentation rather than parsed. That is what every editor's outline does, and it is
// honest about its limits: block scalars are skipped, flow mappings on one line are one entry, and
// anchors/aliases are shown as written.

import Foundation

public enum StructureOutline {
    /// Extensions this can outline. JSON and XML families plus YAML.
    private static let json: Set<String> = ["json", "jsonc", "geojson", "webmanifest", "jsonl", "ndjson"]
    private static let yaml: Set<String> = ["yaml", "yml"]
    private static let xml: Set<String> = ["xml", "svg", "plist", "xsd", "xsl", "xslt", "storyboard",
                                          "xib", "rss", "atom", "pom", "xhtml", "resx", "csproj",
                                          "vcxproj", "nuspec", "wsdl"]

    /// How many nodes are produced at most. A 200 MB JSON array would otherwise build an outline nobody
    /// can use out of memory nobody has; the sidebar shows what fits and the file still opens.
    public static let nodeLimit = 5_000

    public static func supports(ext: String) -> Bool {
        let e = ext.lowercased()
        return json.contains(e) || yaml.contains(e) || xml.contains(e)
    }

    /// Build the outline for `text`, or an empty array when the extension is not one of ours.
    public static func parse(_ text: String, ext: String) -> [SymbolNode] {
        let e = ext.lowercased()
        if json.contains(e) { return parseJSON(text) }
        if yaml.contains(e) { return parseYAML(text) }
        if xml.contains(e) { return parseXML(text) }
        return []
    }

    // MARK: - JSON

    /// Object keys and container array elements, with their offsets.
    ///
    /// Array *scalars* get no node on purpose: a list of ten thousand numbers would bury the structure
    /// it is part of. An array of objects does get one entry per element, because that is the shape
    /// people navigate — `[0]`, `[1]`, each with the object's own keys beneath it.
    static func parseJSON(_ text: String) -> [SymbolNode] {
        var scanner = Scanner(text)
        var roots: [SymbolNode] = []
        var count = 0
        // Reaching the node limit ends the parse; it must not unwind into the middle of the document.
        // It used to: `value` returned nil, the loops above it broke out without consuming their
        // container, and the array loop then found a `}` in element position — a character
        // `skipScalar` refuses to move past — and spun there forever. On a background thread, in every
        // file with more than 5000 nodes. Found by validating this repo's own tree-sitter grammars.
        var stopped = false

        func value(name: String, startOffset: Int, line: Int) -> SymbolNode? {
            scanner.skipWhitespaceAndComments()
            guard count < nodeLimit else { stopped = true; return nil }
            let kind: String
            switch scanner.peek() {
            case "{": kind = "object"
            case "[": kind = "array"
            default: kind = "value"
            }
            let node = SymbolNode(name: name, kind: kind, line: line,
                                  utf16Location: startOffset, start: startOffset, end: startOffset,
                                  pathComponent: StructurePath.jsonStep(for: name))
            count += 1
            switch kind {
            case "object": node.children = members(of: node)
            case "array": node.children = elements(of: node)
            default: scanner.skipScalar()
            }
            node.end = scanner.offset
            return node
        }

        /// The `"key": value` pairs of the object the scanner is sitting on.
        func members(of parent: SymbolNode) -> [SymbolNode] {
            var out: [SymbolNode] = []
            scanner.advance()                                   // past '{'
            while !stopped {
                scanner.skipWhitespaceAndComments()
                guard let c = scanner.peek() else { break }
                if c == "}" { scanner.advance(); break }
                if c == "," { scanner.advance(); continue }
                guard c == "\"" else { scanner.advance(); continue }   // malformed: step over it
                let keyOffset = scanner.offset
                let keyLine = scanner.line
                guard let key = scanner.readString() else { break }
                scanner.skipWhitespaceAndComments()
                if scanner.peek() == ":" { scanner.advance() }
                if let child = value(name: key, startOffset: keyOffset, line: keyLine) {
                    out.append(child)
                } else {
                    break
                }
            }
            return out
        }

        /// Array elements — only the ones that are containers themselves.
        func elements(of parent: SymbolNode) -> [SymbolNode] {
            var out: [SymbolNode] = []
            var index = 0
            scanner.advance()                                   // past '['
            while !stopped {
                scanner.skipWhitespaceAndComments()
                guard let c = scanner.peek() else { break }
                if c == "]" { scanner.advance(); break }
                if c == "," { scanner.advance(); continue }
                let elementOffset = scanner.offset
                let elementLine = scanner.line
                if c == "{" || c == "[" {
                    if let child = value(name: "[\(index)]", startOffset: elementOffset,
                                        line: elementLine) {
                        out.append(child)
                    } else {
                        break
                    }
                } else {
                    scanner.skipScalar()
                }
                index += 1
                // `skipScalar` stops *before* `,`, `}` and `]`, so a stray `}` inside an array leaves the
                // scanner exactly where it was and this loop would never end. Malformed input is the
                // normal case for this parser, so non-progress has to be a stop condition, not a bug.
                if scanner.offset == elementOffset { scanner.advance() }
            }
            return out
        }

        // A file may hold several documents (.jsonl / .ndjson), so keep going until the text runs out.
        while !stopped {
            scanner.skipWhitespaceAndComments()
            guard scanner.peek() != nil, count < nodeLimit else { break }
            let offset = scanner.offset
            let line = scanner.line
            guard let root = value(name: rootName(for: roots.count), startOffset: offset, line: line) else {
                break
            }
            roots.append(root)
            if scanner.offset == offset { break }               // no progress: stop rather than spin
        }
        // A single root adds a level without adding information; show its members directly.
        if roots.count == 1, !roots[0].children.isEmpty { return roots[0].children }
        return roots
    }

    private static func rootName(for index: Int) -> String {
        index == 0 ? "(root)" : "(document \(index + 1))"
    }

    // MARK: - YAML

    /// Keys and list items by indentation.
    ///
    /// Column, not syntax: a line's indentation decides its parent, which is what makes this work on a
    /// file that is still being typed. Block scalars (`|`, `>`) are skipped wholesale, because their
    /// contents are text and any `key:` inside them is not a key.
    static func parseYAML(_ text: String) -> [SymbolNode] {
        var roots: [SymbolNode] = []
        var stack: [(indent: Int, node: SymbolNode)] = []
        // The first document exists without a `---` of its own, so the separator that follows it opens
        // document *two*. A file that *starts* with `---` is the exception: there the separator opens the
        // first document and gets no node, which is why this depends on whether anything was emitted yet.
        var documentIndex = 1
        var count = 0
        var listIndex: [Int: Int] = [:]          // per indentation, the running item number
        var blockScalarIndent: Int?

        var offset = 0
        for (number, rawLine) in text.components(separatedBy: "\n").enumerated() {
            defer { offset += rawLine.utf16.count + 1 }
            let line = number + 1
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            let indent = rawLine.prefix { $0 == " " }.count

            // Inside a block scalar everything more indented than its key belongs to the text.
            if let blockIndent = blockScalarIndent {
                if trimmed.isEmpty || indent > blockIndent { continue }
                blockScalarIndent = nil
            }
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix("---") {
                stack.removeAll()
                listIndex.removeAll()
                guard count > 0 else { continue }         // a leading separator opens document one
                documentIndex += 1
                if count < nodeLimit {
                    let node = SymbolNode(name: "(document \(documentIndex))", kind: "object", line: line,
                                          utf16Location: offset, start: offset, end: offset)
                    roots.append(node); count += 1
                    stack = [(-1, node)]
                }
                continue
            }
            guard count < nodeLimit else { break }

            var name: String?
            var kind = "value"
            var itemIndent = indent
            var nameOffset = offset + indent
            var step: String?                        // this line as a yq/jq path step
            var childStep: String?                   // what the lines nested under it inherit

            if trimmed.hasPrefix("- ") || trimmed == "-" {
                // A list item. `- key: value` is both an item and a mapping, and the useful label is the
                // key — an outline full of "[0]", "[1]" says nothing about what is in the list.
                let rest = String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                let index = listIndex[indent, default: 0]
                listIndex[indent] = index + 1
                if let colon = mappingColon(in: rest), !rest.hasPrefix("#") {
                    let key = String(rest[rest.startIndex..<colon])
                    name = "[\(index)] \(key)"
                    nameOffset = offset + indent + 2
                    // One line is both the list element and its first key, so the path is both steps —
                    // but the keys nested beneath it are siblings of that key inside the same mapping, so
                    // they inherit only the index. Without this, `run:` under `- name: build` came out as
                    // `.steps[0].name.run`, a path to something that does not exist.
                    step = "[\(index)]" + (StructurePath.jsonStep(for: key) ?? "")
                    childStep = "[\(index)]"
                } else {
                    name = "[\(index)]" + (rest.isEmpty ? "" : " " + rest.prefix(40))
                    step = "[\(index)]"
                }
                kind = "array"
                itemIndent = indent
            } else if let colon = mappingColon(in: trimmed) {
                let key = String(trimmed[trimmed.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
                guard !key.isEmpty, !key.contains(" #") else { continue }
                let after = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                name = key
                step = StructurePath.jsonStep(for: key)
                kind = after.isEmpty ? "object" : "value"
                if after.hasPrefix("|") || after.hasPrefix(">") { blockScalarIndent = indent }
            }
            guard let label = name else { continue }

            // The parent is the nearest entry indented less than this one.
            while let top = stack.last, top.indent >= itemIndent {
                top.node.end = offset
                stack.removeLast()
            }
            let node = SymbolNode(name: label, kind: kind, line: line,
                                  utf16Location: nameOffset, start: offset, end: offset,
                                  pathComponent: step, childPathComponent: childStep)
            count += 1
            if let parent = stack.last {
                parent.node.children.append(node)
            } else {
                roots.append(node)
            }
            stack.append((itemIndent, node))
            // Deeper list indices restart under a new parent.
            listIndex = listIndex.filter { $0.key <= itemIndent }
        }
        let end = text.utf16.count
        for entry in stack { entry.node.end = end }
        return roots
    }

    /// The colon that makes a YAML line a `key: value` mapping, or nil if there is none.
    ///
    /// A colon separates a key from a value only when a space or the end of the line follows it, and never
    /// inside quotes. Taking the first colon instead labelled the port list of a compose file `[0] "80`:
    /// `- "80:80"` is a single scalar, not a mapping.
    static func mappingColon(in s: String) -> String.Index? {
        var quote: Character?
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if let q = quote {
                if c == q { quote = nil }
            } else if c == "\"" || c == "'" {
                quote = c
            } else if c == ":" {
                let next = s.index(after: i)
                if next == s.endIndex || s[next] == " " { return i }
            }
            i = s.index(after: i)
        }
        return nil
    }

    // MARK: - XML

    /// Elements, labelled with their `id`, `name` or `key` attribute when they have one.
    ///
    /// A scanner over `<`…`>` rather than XMLDocument, for the offsets — and because a document with one
    /// unclosed tag still outlines down to that tag, which is exactly when somebody is looking.
    static func parseXML(_ text: String) -> [SymbolNode] {
        var scanner = Scanner(text)
        var roots: [SymbolNode] = []
        var stack: [SymbolNode] = []
        var count = 0

        while let c = scanner.peek() {
            guard count < nodeLimit else { break }
            guard c == "<" else { scanner.advance(); continue }
            let tagStart = scanner.offset
            let tagLine = scanner.line
            scanner.advance()
            switch scanner.peek() {
            case "?", "!":
                scanner.skipUntil(">")                     // declaration, comment, doctype, CDATA
                continue
            case "/":
                scanner.skipUntil(">")
                if let node = stack.popLast() { node.end = scanner.offset }
                continue
            default: break
            }
            guard let name = scanner.readTagName(), !name.isEmpty else { continue }
            let attributes = scanner.readAttributes()
            let selfClosing = scanner.lastTagWasSelfClosing
            let label = Self.label(tag: name, attributes: attributes)
            let node = SymbolNode(name: label, kind: selfClosing ? "value" : "object", line: tagLine,
                                  utf16Location: tagStart + 1, start: tagStart, end: scanner.offset,
                                  pathComponent: StructurePath.xmlStep(tag: name, attributes: attributes))
            count += 1
            if let parent = stack.last {
                parent.children.append(node)
            } else {
                roots.append(node)
            }
            if !selfClosing { stack.append(node) }
        }
        let end = text.utf16.count
        for node in stack { node.end = end }
        // One root element carries no information by itself; its children are the structure.
        if roots.count == 1, !roots[0].children.isEmpty { return roots[0].children }
        return roots
    }

    /// `server` alone says little in a file of twenty servers; `server #web-1` says which.
    private static func label(tag: String, attributes: [(String, String)]) -> String {
        for wanted in ["id", "name", "key", "class"] {
            if let value = attributes.first(where: { $0.0.lowercased() == wanted })?.1, !value.isEmpty {
                return "\(tag) #\(value.prefix(40))"
            }
        }
        return tag
    }

    // MARK: - A UTF-16 scanner that tracks lines

    /// Positions are UTF-16 offsets because that is what `NSTextView` selects with.
    struct Scanner {
        private let units: [UInt16]
        private(set) var offset = 0
        private(set) var line = 1
        /// Set by `readAttributes` when the tag ended with `/>`.
        private(set) var lastTagWasSelfClosing = false

        init(_ text: String) { units = Array(text.utf16) }

        func peek() -> Character? {
            guard offset < units.count, let scalar = Unicode.Scalar(units[offset]) else { return nil }
            return Character(scalar)
        }

        mutating func advance() {
            guard offset < units.count else { return }
            if units[offset] == 0x0A { line += 1 }
            offset += 1
        }

        mutating func skipWhitespaceAndComments() {
            while let c = peek() {
                if c == " " || c == "\t" || c == "\n" || c == "\r" { advance() }
                else if c == "/", offset + 1 < units.count, units[offset + 1] == UInt16(UInt8(ascii: "/")) {
                    skipUntil("\n")                                  // a // comment in .jsonc
                } else if c == "/", offset + 1 < units.count, units[offset + 1] == UInt16(UInt8(ascii: "*")) {
                    advance(); advance()
                    while offset < units.count {
                        if units[offset] == UInt16(UInt8(ascii: "*")), offset + 1 < units.count,
                           units[offset + 1] == UInt16(UInt8(ascii: "/")) { advance(); advance(); break }
                        advance()
                    }
                } else { return }
            }
        }

        mutating func skipUntil(_ terminator: Character) {
            while let c = peek() {
                advance()
                if c == terminator { return }
            }
        }

        /// Read a JSON string, returning its contents with escapes left as written.
        mutating func readString() -> String? {
            guard peek() == "\"" else { return nil }
            advance()
            var out = String.UnicodeScalarView()
            while offset < units.count {
                let unit = units[offset]
                if unit == UInt16(UInt8(ascii: "\\")) {
                    advance()
                    if offset < units.count, let scalar = Unicode.Scalar(units[offset]) {
                        out.append("\\"); out.append(scalar)
                    }
                    advance()
                    continue
                }
                if unit == UInt16(UInt8(ascii: "\"")) { advance(); return String(out) }
                if let scalar = Unicode.Scalar(unit) { out.append(scalar) }
                advance()
            }
            return String(out)                                   // unterminated: take what there is
        }

        /// Step over a scalar value — up to the next comma, closing bracket or end.
        mutating func skipScalar() {
            if peek() == "\"" { _ = readString(); return }
            while let c = peek() {
                if c == "," || c == "}" || c == "]" { return }
                advance()
            }
        }

        mutating func readTagName() -> String? {
            var out = ""
            while let c = peek() {
                if c.isLetter || c.isNumber || c == "_" || c == "-" || c == ":" || c == "." {
                    out.append(c); advance()
                } else { break }
            }
            return out.isEmpty ? nil : out
        }

        /// Read `name="value"` pairs up to the end of the tag.
        mutating func readAttributes() -> [(String, String)] {
            var out: [(String, String)] = []
            lastTagWasSelfClosing = false
            while let c = peek() {
                if c == ">" { advance(); return out }
                if c == "/" {
                    lastTagWasSelfClosing = true
                    advance()
                    continue
                }
                if c == " " || c == "\t" || c == "\n" || c == "\r" { advance(); continue }
                guard let name = readTagName() else { advance(); continue }
                skipSpaces()
                guard peek() == "=" else { out.append((name, "")); continue }
                advance()
                skipSpaces()
                let quote = peek()
                if quote == "\"" || quote == "'" {
                    advance()
                    var value = ""
                    while let v = peek(), v != quote { value.append(v); advance() }
                    advance()
                    out.append((name, value))
                } else {
                    var value = ""
                    while let v = peek(), v != ">", v != " ", v != "/" { value.append(v); advance() }
                    out.append((name, value))
                }
            }
            return out
        }

        private mutating func skipSpaces() {
            while let c = peek(), c == " " || c == "\t" { advance() }
        }
    }
}
