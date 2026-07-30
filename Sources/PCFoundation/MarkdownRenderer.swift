// MarkdownRenderer.swift - Minimal CommonMark-ish Markdown -> HTML converter.
//
// Used by the F3 lister to render .md files. Covers the common constructs found
// in real-world Markdown: ATX headings, fenced/indented code, blockquotes,
// ordered/unordered lists, thematic breaks, GFM pipe tables, paragraphs, and the
// usual inline spans (code, images, links, bold, italic, strikethrough, hard
// line breaks). It is intentionally small and dependency-free; it is not a full
// CommonMark implementation but handles the vast majority of documents well.
//
// Output is a self-contained HTML document with embedded, theme-aware CSS so it
// renders cleanly in a WKWebView without any network access.

import Foundation

public enum MarkdownRenderer {
    /// Convert Markdown to a complete, styled HTML document.
    public static func htmlDocument(from markdown: String, title: String = "") -> String {
        let body = bodyHTML(from: markdown)
        let safeTitle = escape(title)
        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(safeTitle)</title>
        <style>\(css)</style>
        </head><body><article class="markdown-body">
        \(body)
        </article></body></html>
        """
    }

    /// Convert Markdown to the inner HTML (no document wrapper). Exposed for tests.
    public static func bodyHTML(from markdown: String) -> String {
        // Normalize line endings and expand tabs used for indentation.
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
                                 .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var out: [String] = []
        var i = 0

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
                var code: [String] = []
                i += 1
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if l.hasPrefix(fence) { i += 1; break }
                    code.append(lines[i])
                    i += 1
                }
                out.append("<pre><code>\(escape(code.joined(separator: "\n")))</code></pre>")
                continue
            }

            // ATX heading: #..###### followed by space.
            if let (level, text) = atxHeading(trimmed) {
                flushParagraph(&para)
                out.append("<h\(level)>\(inline(text))</h\(level)>")
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

            // Otherwise: paragraph text.
            para.append(trimmed)
            i += 1
        }
        flushParagraph(&para)
        return out.joined(separator: "\n")
    }

    // MARK: - Block helpers

    private static func fenceMarker(_ trimmed: String) -> String? {
        if trimmed.hasPrefix("```") { return "```" }
        if trimmed.hasPrefix("~~~") { return "~~~" }
        return nil
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
    @media (prefers-color-scheme: dark) {
      body { background: #0d1117; }
      .markdown-body { color: #e6edf3; }
      .markdown-body h1, .markdown-body h2 { border-bottom-color: #30363d; }
      .markdown-body a { color: #4493f8; }
      .markdown-body pre { background: #161b22; }
      .markdown-body blockquote { color: #9198a1; border-left-color: #30363d; }
      .markdown-body th, .markdown-body td { border-color: #30363d; }
      .markdown-body hr { background: #30363d; }
    }
    """
}
