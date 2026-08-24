// SPDX-License-Identifier: Apache-2.0
// MarkdownDocument.swift - Markdown -> HTML for the Markdown lister plugin.
//
// Was Sources/PCFoundation/MarkdownRenderer.swift until the whole subject left the
// core: rendering a document format is not something the application has to know
// how to do, and inside a plugin this can use JavaScript, link a parser the app
// does not have, and ship engines with it. The file moved rather than being
// rewritten, and its tests moved with it — they assert the *output* HTML, which is
// what makes them a safety net for the parser swap that follows.
//
// It covers the common constructs found in real-world Markdown: ATX headings,
// fenced code (coloured when the fence names a language), blockquotes,
// ordered/unordered lists, thematic breaks, GFM pipe tables, paragraphs, and the
// usual inline spans (code, images, links, bold, italic, strikethrough, hard line
// breaks). Indented code blocks are NOT among them — the header used to claim they
// were.
//
// Output is a self-contained HTML document with embedded, theme-aware CSS so it
// renders cleanly in a WKWebView without any network access.

import Foundation
// SyntaxHighlighter and its token kinds: the plugin links the host's framework rather than
// carrying a second lexer, which is also what keeps a fence coloured the same way the editor
// colours the same language.
import PCFoundation

public enum MarkdownRenderer {
    /// What the rendered document is allowed to load.
    ///
    /// A Markdown file is content from somewhere else, and `![](http://…/x.png?who=…)` is a read
    /// receipt: previewing the file tells that server when it was opened, and from which address. The
    /// viewer's own comment claimed this could not happen because JavaScript is disabled — measured, and
    /// wrong: an image element needs no JavaScript, and the request went out.
    ///
    /// `img-src file: data:` keeps the case that is actually wanted — a document referring to a picture
    /// beside it, which resolves against the base URL the viewer passes. Measured too, both halves: with
    /// this policy the sibling image still loads (naturalWidth 1) and the remote one does not (0).
    /// `style-src 'unsafe-inline'` is for the stylesheet below, which is part of this document.
    public static let contentSecurityPolicy =
        "default-src 'none'; img-src file: data:; style-src 'unsafe-inline'; font-src file: data:"

    /// A rendered document plus the anchors its headings were given.
    ///
    /// The anchors exist so a caller can navigate the *rendered* page: the viewer's symbol outline
    /// knows a heading by the source line it is on, and the page can only be scrolled to an element.
    /// They are produced by the render pass itself rather than by a second scan of the source, because
    /// two scans that disagree about what counts as a heading (a `#` inside a fenced code block, say)
    /// would send the reader to the wrong place.
    public struct Rendered: Sendable, Equatable {
        public let html: String
        /// 1-based source line of a heading → the `id` its element carries.
        public let anchors: [Int: String]
    }

    /// Convert Markdown to a complete, styled HTML document.
    public static func htmlDocument(from markdown: String, title: String = "") -> String {
        document(from: markdown, title: title).html
    }

    /// As `htmlDocument`, and also the heading anchors, for a caller that navigates the page.
    public static func document(from markdown: String, title: String = "") -> Rendered {
        let rendered = render(markdown)
        let body = rendered.html
        let safeTitle = escape(title)
        let html = """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="\(contentSecurityPolicy)">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(safeTitle)</title>
        <style>\(css)</style>
        </head><body><article class="markdown-body">
        \(body)
        </article></body></html>
        """
        return Rendered(html: html, anchors: rendered.anchors)
    }

    /// Convert Markdown to the inner HTML (no document wrapper). Exposed for tests.
    public static func bodyHTML(from markdown: String) -> String {
        render(markdown).html
    }

    /// The inner HTML plus its heading anchors.
    public static func render(_ markdown: String) -> Rendered {
        // Normalize line endings and expand tabs used for indentation.
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
                                 .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var out: [String] = []
        var i = 0
        var anchors: [Int: String] = [:]
        var usedAnchors = Set<String>()

        func flushParagraph(_ buf: inout [String]) {
            guard !buf.isEmpty else { return }
            let joined = buf.joined(separator: "\n")
            out.append("<p>\(inline(joined))</p>")
            buf.removeAll()
        }

        var para: [String] = []
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Blank line: paragraph break.
            if trimmed.isEmpty {
                flushParagraph(&para)
                i += 1
                continue
            }

            // Fenced code block ``` or ~~~.
            if let fence = fenceMarker(trimmed) {
                flushParagraph(&para)
                let info = fenceInfo(trimmed, marker: fence)
                var code: [String] = []
                i += 1
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if l.hasPrefix(fence) { i += 1; break }
                    code.append(lines[i])
                    i += 1
                }
                out.append(codeBlock(code.joined(separator: "\n"), info: info))
                continue
            }

            // ATX heading: #..###### followed by space.
            if let (level, text) = atxHeading(trimmed) {
                flushParagraph(&para)
                let id = uniqueAnchor(for: text, used: &usedAnchors)
                anchors[i + 1] = id
                out.append("<h\(level) id=\"\(escape(id))\">\(inline(text))</h\(level)>")
                i += 1
                continue
            }

            // Thematic break.
            if isThematicBreak(trimmed) {
                flushParagraph(&para)
                out.append("<hr>")
                i += 1
                continue
            }

            // Blockquote.
            if trimmed.hasPrefix(">") {
                flushParagraph(&para)
                var quote: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    guard l.hasPrefix(">") else { break }
                    var content = String(l.dropFirst())
                    if content.hasPrefix(" ") { content.removeFirst() }
                    quote.append(content)
                    i += 1
                }
                out.append("<blockquote>\(bodyHTML(from: quote.joined(separator: "\n")))</blockquote>")
                continue
            }

            // GFM pipe table: header row + delimiter row.
            if line.contains("|"), i + 1 < lines.count, isTableDelimiter(lines[i + 1]) {
                flushParagraph(&para)
                let (html, consumed) = parseTable(lines, from: i)
                out.append(html)
                i += consumed
                continue
            }

            // Lists (unordered / ordered).
            if listItem(line) != nil {
                flushParagraph(&para)
                let (html, consumed) = parseList(lines, from: i)
                out.append(html)
                i += consumed
                continue
            }

            // Underlined (setext) heading: `Title` over a run of `=` (level 1) or `-` (level 2).
            //
            // Last of the block rules on purpose: a table's delimiter row and a list item that happens to
            // be followed by dashes are decided above. Without this, `Title` + `---` rendered as a
            // paragraph followed by a horizontal rule — it *looked* like a heading and was none, so the
            // outline (which has always read this form) offered an entry the page had no anchor for. The
            // one-line rule and the line the heading is reported on are DeclarationOutline.parseMarkdown's,
            // so the two agree about what a heading is and where it starts.
            if i + 1 < lines.count {
                let under = lines[i + 1].trimmingCharacters(in: .whitespaces)
                if under.count >= 2,
                   under.allSatisfy({ $0 == "=" }) || under.allSatisfy({ $0 == "-" }) {
                    flushParagraph(&para)
                    let level = under.first == "=" ? 1 : 2
                    let id = uniqueAnchor(for: trimmed, used: &usedAnchors)
                    anchors[i + 1] = id
                    out.append("<h\(level) id=\"\(escape(id))\">\(inline(trimmed))</h\(level)>")
                    i += 2
                    continue
                }
            }

            // Otherwise: paragraph text.
            para.append(trimmed)
            i += 1
        }
        flushParagraph(&para)
        return Rendered(html: out.joined(separator: "\n"), anchors: anchors)
    }

    /// A heading's element id: its text reduced to letters, digits, `-` and `_`, lowercased, with a
    /// numeric suffix when a document repeats a heading (two "Notes" sections are two anchors).
    ///
    /// Unicode letters are kept rather than transliterated — the id is only ever looked up by this app,
    /// and "prüfung" is a perfectly good element id, while dropping the umlaut would collide two
    /// different headings sooner.
    static func uniqueAnchor(for text: String, used: inout Set<String>) -> String {
        var slug = ""
        var lastWasDash = false
        for character in text.lowercased() {
            if character.isLetter || character.isNumber {
                slug.append(character); lastWasDash = false
            } else if character == "_" {
                slug.append(character); lastWasDash = false
            } else if character == "-" {
                // Runs of dashes collapse, whether they came from punctuation or were written as dashes:
                // "A -- B" and "A - B" are one id, not "a---b" and "a-b".
                if !slug.isEmpty && !lastWasDash { slug.append("-"); lastWasDash = true }
            } else if !slug.isEmpty && !lastWasDash {
                slug.append("-"); lastWasDash = true
            }
        }
        while slug.hasSuffix("-") { slug.removeLast() }
        var base = slug.isEmpty ? "section" : slug
        if used.contains(base) {
            var n = 2
            while used.contains("\(base)-\(n)") { n += 1 }
            base = "\(base)-\(n)"
        }
        used.insert(base)
        return base
    }

    // MARK: - Block helpers

    private static func fenceMarker(_ trimmed: String) -> String? {
        if trimmed.hasPrefix("```") { return "```" }
        if trimmed.hasPrefix("~~~") { return "~~~" }
        return nil
    }

    /// The language word of a fence's info string, lowercased — `swift` from ```` ```swift ````,
    /// and from ```` ```swift title="A.swift" ```` too. Empty when the fence names nothing.
    ///
    /// The whole opening line used to be skipped, so every code block in every rendered `.md`
    /// arrived as an unmarked `<pre><code>`: no `class="language-…"` for anything reading the
    /// page, and nothing for the stylesheet to colour.
    static func fenceInfo(_ trimmed: String, marker: String) -> String {
        guard let fenceChar = marker.first else { return "" }
        let rest = trimmed.drop(while: { $0 == fenceChar })   // ```` and longer are fences too
        // `{.python}` (Pandoc) and `swift,linenos` name a language as much as a bare word does.
        return rest.trimmingCharacters(in: .whitespaces)
                   .drop(while: { $0 == "{" || $0 == "." })
                   .prefix(while: { !$0.isWhitespace && $0 != "," && $0 != "}" && $0 != "=" })
                   .lowercased()
    }

    /// Names Markdown authors write on a fence that are not the file extension the lexer is
    /// keyed by. The ones that already *are* an extension — `swift`, `json`, `go`, `rs`, `java`,
    /// `bash`, `yaml`, `css`, `sql`, `lua` — need no entry and deliberately have none.
    static let fenceLanguageAliases: [String: String] = [
        "python": "py", "python3": "py",
        "javascript": "js", "node": "js", "typescript": "ts",
        "shell": "sh", "console": "sh", "terminal": "sh", "shell-session": "sh",
        "c++": "cpp", "objective-c": "m", "objectivec": "m", "objc": "m",
        "c#": "cs", "csharp": "cs",
        "rust": "rs", "golang": "go", "ruby": "rb", "kotlin": "kt",
        "perl": "pl", "haskell": "hs", "elixir": "ex", "powershell": "ps1",
    ]

    /// The lexer for a fence's language word, or nil — which is the answer for `mermaid`, `text`
    /// and everything else this app has no lexer for, and means an uncoloured block rather than
    /// a failure.
    static func fenceLanguage(_ info: String) -> SyntaxLanguage? {
        guard !info.isEmpty else { return nil }
        if let language = SyntaxHighlighter.language(forExtension: info) { return language }
        guard let ext = fenceLanguageAliases[info] else { return nil }
        return SyntaxHighlighter.language(forExtension: ext)
    }

    /// A fence rendered as `<pre><code>`, carrying the GFM `language-…` class and, where there is
    /// a lexer for it, `<span class="tok-…">` around comments, strings, numbers and keywords.
    ///
    /// Classes and an embedded stylesheet, never a `style=` attribute and never a script: the
    /// document's `default-src 'none'` policy is the point and is not relaxed for colour.
    private static func codeBlock(_ code: String, info: String) -> String {
        let attr = isLanguageToken(info) ? " class=\"language-\(info)\"" : ""
        guard let language = fenceLanguage(info) else {
            return "<pre><code\(attr)>\(escape(code))</code></pre>"
        }
        return "<pre><code\(attr)>\(highlighted(code, language: language))</code></pre>"
    }

    /// Whether an info string is plausibly a language name, and so safe to put in a class
    /// attribute. `escape` would make anything else harmless, but `class="language-&quot;&gt;"`
    /// is noise in the page rather than information in it.
    static func isLanguageToken(_ info: String) -> Bool {
        !info.isEmpty && info.allSatisfy {
            $0.isLetter || $0.isNumber || "+#-_.".contains($0)
        }
    }

    /// `code`, HTML-escaped, with the lexer's spans wrapped in `<span class="tok-…">`.
    private static func highlighted(_ code: String, language: SyntaxLanguage) -> String {
        let chars = Array(code)
        var out = ""
        var cursor = 0
        for token in SyntaxHighlighter.tokens(code, language: language) {
            // The lexer is single-pass, so its ranges arrive in order and cannot overlap. Clamped
            // anyway: this is the one place that turns those offsets into string indices, and a
            // wrong range should cost colour, not a crash in a file viewer.
            let lower = min(max(token.range.lowerBound, cursor), chars.count)
            let upper = min(max(token.range.upperBound, lower), chars.count)
            if lower > cursor { out += escape(String(chars[cursor..<lower])) }
            out += "<span class=\"tok-\(token.kind.rawValue)\">"
                 + escape(String(chars[lower..<upper])) + "</span>"
            cursor = upper
        }
        if cursor < chars.count { out += escape(String(chars[cursor...])) }
        return out
    }

    private static func atxHeading(_ trimmed: String) -> (Int, String)? {
        var level = 0
        for ch in trimmed { if ch == "#" { level += 1 } else { break } }
        guard level >= 1, level <= 6 else { return nil }
        let rest = trimmed.dropFirst(level)
        guard rest.first == " " || rest.isEmpty else { return nil }
        var text = rest.trimmingCharacters(in: .whitespaces)
        // Strip optional trailing #'s.
        while text.hasSuffix("#") { text.removeLast() }
        return (level, text.trimmingCharacters(in: .whitespaces))
    }

    private static func isThematicBreak(_ trimmed: String) -> Bool {
        let stripped = trimmed.replacingOccurrences(of: " ", with: "")
        guard stripped.count >= 3 else { return false }
        return stripped.allSatisfy { $0 == "-" } || stripped.allSatisfy { $0 == "*" } || stripped.allSatisfy { $0 == "_" }
    }

    /// Returns (marker-kind, item content) if the line begins a list item.
    private static func listItem(_ line: String) -> (ordered: Bool, content: String, indent: Int)? {
        let indent = line.prefix { $0 == " " }.count
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Unordered: - * + followed by space.
        if let first = trimmed.first, "-*+".contains(first) {
            let after = trimmed.dropFirst()
            if after.first == " " {
                return (false, String(after.dropFirst()).trimmingCharacters(in: .whitespaces), indent)
            }
        }
        // Ordered: digits then '.' or ')' then space.
        var digits = ""
        for ch in trimmed { if ch.isNumber { digits.append(ch) } else { break } }
        if !digits.isEmpty {
            let after = trimmed.dropFirst(digits.count)
            if let sep = after.first, sep == "." || sep == ")" {
                let rest = after.dropFirst()
                if rest.first == " " {
                    return (true, String(rest.dropFirst()).trimmingCharacters(in: .whitespaces), indent)
                }
            }
        }
        return nil
    }

    private static func parseList(_ lines: [String], from start: Int) -> (String, Int) {
        guard let firstItem = listItem(lines[start]) else { return ("", 1) }
        let ordered = firstItem.ordered
        var items: [String] = []
        var i = start
        while i < lines.count, let item = listItem(lines[i]), item.ordered == ordered {
            items.append(inline(item.content))
            i += 1
        }
        let tag = ordered ? "ol" : "ul"
        let body = items.map { "<li>\($0)</li>" }.joined(separator: "\n")
        return ("<\(tag)>\n\(body)\n</\(tag)>", i - start)
    }

    private static func isTableDelimiter(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("-"), trimmed.contains("|") || trimmed.hasPrefix(":") || trimmed.hasPrefix("-") else { return false }
        let cells = splitRow(trimmed)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            guard !c.isEmpty else { return false }
            return c.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func parseTable(_ lines: [String], from start: Int) -> (String, Int) {
        let header = splitRow(lines[start])
        let aligns = splitRow(lines[start + 1]).map { cell -> String in
            let c = cell.trimmingCharacters(in: .whitespaces)
            let left = c.hasPrefix(":"), right = c.hasSuffix(":")
            if left && right { return "center" }
            if right { return "right" }
            if left { return "left" }
            return ""
        }
        func styled(_ tag: String, _ cell: String, _ idx: Int) -> String {
            let align = idx < aligns.count ? aligns[idx] : ""
            let attr = align.isEmpty ? "" : " style=\"text-align:\(align)\""
            return "<\(tag)\(attr)>\(inline(cell.trimmingCharacters(in: .whitespaces)))</\(tag)>"
        }
        var rows: [String] = []
        rows.append("<tr>" + header.enumerated().map { styled("th", $1, $0) }.joined() + "</tr>")
        var i = start + 2
        while i < lines.count, lines[i].contains("|"), !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
            let cells = splitRow(lines[i])
            rows.append("<tr>" + cells.enumerated().map { styled("td", $1, $0) }.joined() + "</tr>")
            i += 1
        }
        return ("<table>\n\(rows.joined(separator: "\n"))\n</table>", i - start)
    }

    private static func splitRow(_ line: String) -> [String] {
        var s = line.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("|") { s.removeFirst() }
        if s.hasSuffix("|") { s.removeLast() }
        // Split on unescaped pipes.
        var cells: [String] = []
        var cur = ""
        var escaped = false
        for ch in s {
            if escaped { cur.append(ch); escaped = false; continue }
            if ch == "\\" { escaped = true; cur.append(ch); continue }
            if ch == "|" { cells.append(cur); cur = "" } else { cur.append(ch) }
        }
        cells.append(cur)
        return cells
    }

    // MARK: - Inline

    /// Apply inline formatting to already-block-split text. HTML-escapes first,
    /// so raw `<`,`>`,`&` in the source render literally.
    static func inline(_ text: String) -> String {
        // Protect code spans first: extract `...` runs, escape their content, and
        // substitute placeholders so later passes don't touch them.
        var placeholders: [String] = []
        var working = ""
        var idx = text.startIndex
        while idx < text.endIndex {
            if text[idx] == "`" {
                // Find matching closing backtick run of equal length.
                var tickCount = 0
                var j = idx
                while j < text.endIndex, text[j] == "`" { tickCount += 1; j = text.index(after: j) }
                let fence = String(repeating: "`", count: tickCount)
                if let closeRange = text.range(of: fence, range: j..<text.endIndex) {
                    let code = String(text[j..<closeRange.lowerBound])
                    let token = "\u{0}CODE\(placeholders.count)\u{0}"
                    placeholders.append("<code>\(escape(code))</code>")
                    working += token
                    idx = closeRange.upperBound
                    continue
                }
            }
            working.append(text[idx])
            idx = text.index(after: idx)
        }

        var s = escape(working)
        s = applyRegex(s, #"!\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)"#) { m in
            "<img alt=\"\(m[1])\" src=\"\(m[2])\">"
        }
        s = applyRegex(s, #"\[([^\]]+)\]\(([^)\s]+)(?:\s+"[^"]*")?\)"#) { m in
            "<a href=\"\(m[2])\">\(m[1])</a>"
        }
        // Autolinks <http://...> already escaped to &lt;...&gt;; handle bare URLs.
        s = applyRegex(s, #"(^|[\s(])((?:https?://|www\.)[^\s<)]+)"#) { m in
            let url = m[2].hasPrefix("www.") ? "http://\(m[2])" : m[2]
            return "\(m[1])<a href=\"\(url)\">\(m[2])</a>"
        }
        s = applyRegex(s, #"\*\*([^*]+)\*\*"#) { "<strong>\($0[1])</strong>" }
        s = applyRegex(s, #"__([^_]+)__"#) { "<strong>\($0[1])</strong>" }
        s = applyRegex(s, #"(?<![\w*])\*([^*\n]+)\*(?![\w*])"#) { "<em>\($0[1])</em>" }
        s = applyRegex(s, #"(?<![\w_])_([^_\n]+)_(?![\w_])"#) { "<em>\($0[1])</em>" }
        s = applyRegex(s, #"~~([^~]+)~~"#) { "<del>\($0[1])</del>" }
        // Hard line break: two+ trailing spaces before newline, or backslash newline.
        s = s.replacingOccurrences(of: "  \n", with: "<br>\n")
        s = s.replacingOccurrences(of: "\\\n", with: "<br>\n")
        s = s.replacingOccurrences(of: "\n", with: " ")

        for (n, html) in placeholders.enumerated() {
            s = s.replacingOccurrences(of: "\u{0}CODE\(n)\u{0}", with: html)
        }
        return s
    }

    private static func applyRegex(_ input: String, _ pattern: String, _ transform: ([String]) -> String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return input }
        let ns = input as NSString
        var result = ""
        var last = 0
        for match in re.matches(in: input, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            var groups: [String] = []
            for g in 0..<match.numberOfRanges {
                let r = match.range(at: g)
                groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
            }
            result += transform(groups)
            last = match.range.location + match.range.length
        }
        result += ns.substring(from: last)
        return result
    }

    static func escape(_ text: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: "&", with: "&amp;")
        s = s.replacingOccurrences(of: "<", with: "&lt;")
        s = s.replacingOccurrences(of: ">", with: "&gt;")
        s = s.replacingOccurrences(of: "\"", with: "&quot;")
        return s
    }

    // MARK: - Stylesheet (GitHub-like, theme-aware)

    private static let css = """
    :root { color-scheme: light dark; }
    body { margin: 0; padding: 28px 40px; -webkit-text-size-adjust: 100%; background: #ffffff; }
    .markdown-body {
      font: 15px/1.6 -apple-system, "SF Pro Text", "Helvetica Neue", Arial, sans-serif;
      color: #1f2328; max-width: 900px; margin: 0 auto; word-wrap: break-word;
    }
    .markdown-body h1, .markdown-body h2 { border-bottom: 1px solid #d0d7de; padding-bottom: .3em; }
    .markdown-body h1 { font-size: 2em; } .markdown-body h2 { font-size: 1.5em; }
    .markdown-body h3 { font-size: 1.25em; } .markdown-body h4 { font-size: 1em; }
    .markdown-body h1,.markdown-body h2,.markdown-body h3,.markdown-body h4,.markdown-body h5,.markdown-body h6 {
      margin: 1.4em 0 .6em; font-weight: 600; line-height: 1.25;
    }
    .markdown-body p { margin: 0 0 1em; }
    .markdown-body a { color: #0969da; text-decoration: none; } .markdown-body a:hover { text-decoration: underline; }
    .markdown-body code {
      font: .88em ui-monospace, "SF Mono", Menlo, Consolas, monospace;
      background: rgba(129,139,152,.16); padding: .2em .4em; border-radius: 6px;
    }
    .markdown-body pre {
      background: #f6f8fa; padding: 14px 16px; border-radius: 8px; overflow: auto; line-height: 1.45;
    }
    .markdown-body pre code { background: none; padding: 0; font-size: .875em; }
    /* The four kinds SyntaxHighlighter emits, in GitHub's own palette to match the rest of this
       stylesheet. Not the app's theme colours: those live in PCApp as NSColor, and PCFoundation
       does not import AppKit — so a rendered page follows light/dark, like the page it is. */
    .markdown-body .tok-comment { color: #6e7781; font-style: italic; }
    .markdown-body .tok-string  { color: #0a3069; }
    .markdown-body .tok-number  { color: #0550ae; }
    .markdown-body .tok-keyword { color: #cf222e; }
    .markdown-body blockquote {
      margin: 0 0 1em; padding: 0 1em; color: #656d76; border-left: .25em solid #d0d7de;
    }
    .markdown-body ul, .markdown-body ol { margin: 0 0 1em; padding-left: 2em; }
    .markdown-body li { margin: .2em 0; }
    .markdown-body table { border-collapse: collapse; margin: 0 0 1em; display: block; overflow: auto; }
    .markdown-body th, .markdown-body td { border: 1px solid #d0d7de; padding: 6px 13px; }
    .markdown-body th { background: rgba(129,139,152,.12); font-weight: 600; }
    .markdown-body tr:nth-child(2n) td { background: rgba(129,139,152,.06); }
    .markdown-body hr { height: 1px; background: #d0d7de; border: 0; margin: 1.6em 0; }
    .markdown-body img { max-width: 100%; }
    /* Where a ```mermaid block was. The SVG is scaled down to fit and never up: a two-box diagram
       stretched across 900 points looks like a mistake. */
    .markdown-body .pc-diagram { margin: 0 0 1em; text-align: center; }
    .markdown-body .pc-diagram svg { max-width: 100%; height: auto; }
    /* A diagram that will not parse says so where it was, with its source below the message — a
       silently missing figure is what gets reported as "the viewer lost my text". */
    .markdown-body .pc-diagram-error {
      background: rgba(207,34,46,.08); border-left: .25em solid #cf222e; color: #82071e;
    }
    @media (prefers-color-scheme: dark) {
      body { background: #0d1117; }
      .markdown-body { color: #e6edf3; }
      .markdown-body h1, .markdown-body h2 { border-bottom-color: #30363d; }
      .markdown-body a { color: #4493f8; }
      .markdown-body pre { background: #161b22; }
      .markdown-body .tok-comment { color: #8b949e; }
      .markdown-body .tok-string  { color: #a5d6ff; }
      .markdown-body .tok-number  { color: #79c0ff; }
      .markdown-body .tok-keyword { color: #ff7b72; }
      .markdown-body blockquote { color: #9198a1; border-left-color: #30363d; }
      .markdown-body th, .markdown-body td { border-color: #30363d; }
      .markdown-body hr { background: #30363d; }
      .markdown-body .pc-diagram-error {
        background: rgba(248,81,73,.12); border-left-color: #f85149; color: #ffa198;
      }
    }
    """
}
