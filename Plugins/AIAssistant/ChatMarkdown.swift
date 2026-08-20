// SPDX-License-Identifier: Apache-2.0
// ChatMarkdown.swift — render the assistant's answers as formatted text.
//
// The model writes Markdown: it is asked for tables, it lists steps, it quotes code and
// file names. The chat used to put that on screen verbatim, so the "Make a table" action —
// which uses guided generation precisely so the table is always well-formed — arrived as
// rows of pipe characters. Everything here exists to close that gap: a table becomes a
// table (NSTextTable), a fenced block becomes a code block, a list becomes a list, and a
// path becomes something clickable.
//
// Deliberately a small subset, hand-written rather than NSAttributedString(markdown:):
// that initialiser does not produce tables or code blocks, and this way the paths keep
// running through PathDetector, which is what makes them navigable.
//
// TextKit 1 is required — NSTextTable has no TextKit 2 equivalent. The chat's text view is
// built with an explicit layout manager for that reason.

import AppKit
import PCAutomation

/// The colours a rendered answer needs, taken from the host theme.
struct ChatMarkdownStyle {
    let text: NSColor
    let secondary: NSColor
    let accent: NSColor
    let border: NSColor
    let codeBackground: NSColor
    let bodySize: CGFloat

    init(theme: PluginTheme, bodySize: CGFloat = 13) {
        text = theme.text
        secondary = theme.secondaryText
        accent = theme.accent
        border = theme.separator
        // A wash of the text colour rather than a fixed grey, so it sits on either ground.
        codeBackground = theme.text.withAlphaComponent(theme.isDark ? 0.10 : 0.06)
        self.bodySize = bodySize
    }

    var body: NSFont { .systemFont(ofSize: bodySize) }
    var bold: NSFont { .boldSystemFont(ofSize: bodySize) }
    var italic: NSFont {
        NSFontManager.shared.convert(.systemFont(ofSize: bodySize), toHaveTrait: .italicFontMask)
    }
    var mono: NSFont { .monospacedSystemFont(ofSize: bodySize - 1, weight: .regular) }
    func heading(_ level: Int) -> NSFont {
        .boldSystemFont(ofSize: bodySize + max(0, CGFloat(4 - level)) * 1.5 + 1)
    }
}

enum ChatMarkdown {

    /// Render `markdown` as an attributed string, with file paths linked (`pcfile://`).
    static func render(_ markdown: String, style: ChatMarkdownStyle) -> NSAttributedString {
        let out = NSMutableAttributedString()
        var lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var paragraph: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            out.append(inline(paragraph.joined(separator: " "), style: style, indent: 0))
            out.append(NSAttributedString(string: "\n"))
            paragraph = []
        }

        while !lines.isEmpty {
            let line = lines.removeFirst()
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code: everything up to the closing fence, verbatim.
            if trimmed.hasPrefix("```") {
                flushParagraph()
                var code: [String] = []
                while let next = lines.first {
                    lines.removeFirst()
                    if next.trimmingCharacters(in: .whitespaces).hasPrefix("```") { break }
                    code.append(next)
                }
                out.append(codeBlock(code.joined(separator: "\n"), style: style))
                continue
            }

            // A table: a header row, a separator row of dashes, then body rows.
            if isTableRow(trimmed), let separator = lines.first,
               isTableSeparator(separator.trimmingCharacters(in: .whitespaces)) {
                flushParagraph()
                lines.removeFirst()                       // the |---|---| line
                var rows = [cells(of: trimmed)]
                while let next = lines.first, isTableRow(next.trimmingCharacters(in: .whitespaces)) {
                    lines.removeFirst()
                    rows.append(cells(of: next.trimmingCharacters(in: .whitespaces)))
                }
                out.append(table(rows, style: style))
                continue
            }

            if trimmed.isEmpty { flushParagraph(); continue }

            if trimmed == "---" || trimmed == "***" {
                flushParagraph()
                out.append(rule(style: style))
                continue
            }

            if let level = headingLevel(trimmed) {
                flushParagraph()
                let content = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                let heading = NSMutableAttributedString(attributedString: inline(content, style: style, indent: 0))
                heading.addAttribute(.font, value: style.heading(level),
                                     range: NSRange(location: 0, length: heading.length))
                let spaced = NSMutableParagraphStyle()
                spaced.paragraphSpacingBefore = 6
                spaced.paragraphSpacing = 2
                heading.addAttribute(.paragraphStyle, value: spaced,
                                     range: NSRange(location: 0, length: heading.length))
                out.append(heading)
                out.append(NSAttributedString(string: "\n"))
                continue
            }

            if let item = listItem(trimmed) {
                flushParagraph()
                out.append(bullet(item.marker, item.content, style: style))
                continue
            }

            paragraph.append(trimmed)
        }
        flushParagraph()

        // Trailing newline noise makes the gap between messages uneven.
        while out.string.hasSuffix("\n") { out.deleteCharacters(in: NSRange(location: out.length - 1, length: 1)) }
        return out
    }

    // MARK: - Blocks

    private static func headingLevel(_ line: String) -> Int? {
        var level = 0
        for c in line { if c == "#" { level += 1 } else { break } }
        guard level > 0, level <= 4, line.dropFirst(level).hasPrefix(" ") else { return nil }
        return level
    }

    private static func listItem(_ line: String) -> (marker: String, content: String)? {
        for prefix in ["- ", "* ", "• ", "+ "] where line.hasPrefix(prefix) {
            return ("•", String(line.dropFirst(prefix.count)))
        }
        // "1. " / "12) " — keep the author's number, it may carry order that matters.
        let digits = line.prefix { $0.isNumber }
        if !digits.isEmpty, digits.count <= 3 {
            let rest = line.dropFirst(digits.count)
            if rest.hasPrefix(". ") || rest.hasPrefix(") ") {
                return (String(digits) + ".", String(rest.dropFirst(2)))
            }
        }
        return nil
    }

    private static func bullet(_ marker: String, _ content: String,
                               style: ChatMarkdownStyle) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.headIndent = 18
        paragraph.firstLineHeadIndent = 4
        paragraph.paragraphSpacing = 1
        paragraph.tabStops = [NSTextTab(textAlignment: .left, location: 18)]
        let out = NSMutableAttributedString(
            string: marker + "\t",
            attributes: [.font: style.body, .foregroundColor: style.secondary,
                         .paragraphStyle: paragraph])
        let body = NSMutableAttributedString(attributedString: inline(content, style: style, indent: 18))
        body.addAttribute(.paragraphStyle, value: paragraph,
                          range: NSRange(location: 0, length: body.length))
        out.append(body)
        out.append(NSAttributedString(string: "\n"))
        return out
    }

    private static func codeBlock(_ code: String, style: ChatMarkdownStyle) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.firstLineHeadIndent = 8
        paragraph.headIndent = 8
        paragraph.paragraphSpacingBefore = 4
        paragraph.paragraphSpacing = 4
        paragraph.lineBreakMode = .byCharWrapping
        return NSAttributedString(string: code + "\n", attributes: [
            .font: style.mono,
            .foregroundColor: style.text,
            .backgroundColor: style.codeBackground,
            .paragraphStyle: paragraph,
        ])
    }

    private static func rule(style: ChatMarkdownStyle) -> NSAttributedString {
        NSAttributedString(string: "\u{00A0}\n", attributes: [
            .font: NSFont.systemFont(ofSize: 2),
            .backgroundColor: style.border,
            .paragraphStyle: {
                let p = NSMutableParagraphStyle()
                p.paragraphSpacingBefore = 6
                p.paragraphSpacing = 6
                return p
            }(),
        ])
    }

    // MARK: - Tables

    static func isTableRow(_ line: String) -> Bool {
        line.hasPrefix("|") && line.dropFirst().contains("|")
    }

    static func isTableSeparator(_ line: String) -> Bool {
        guard isTableRow(line) else { return false }
        let inner = cells(of: line)
        guard !inner.isEmpty else { return false }
        return inner.allSatisfy { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            return !c.isEmpty && c.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    static func cells(of row: String) -> [String] {
        var body = row
        if body.hasPrefix("|") { body.removeFirst() }
        if body.hasSuffix("|") { body.removeLast() }
        return body.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// A real table: bordered cells laid out by TextKit, so the columns line up and the
    /// whole thing can still be selected and copied as text.
    private static func table(_ rows: [[String]], style: ChatMarkdownStyle) -> NSAttributedString {
        let columns = rows.map(\.count).max() ?? 0
        guard columns > 0 else { return NSAttributedString(string: "") }
        let table = NSTextTable()
        table.numberOfColumns = columns
        table.layoutAlgorithm = .automaticLayoutAlgorithm
        table.collapsesBorders = true
        table.hidesEmptyCells = false

        let out = NSMutableAttributedString()
        for (r, row) in rows.enumerated() {
            for c in 0..<columns {
                let block = NSTextTableBlock(table: table, startingRow: r, rowSpan: 1,
                                             startingColumn: c, columnSpan: 1)
                block.setBorderColor(style.border)
                block.setWidth(1, type: .absoluteValueType, for: .border)
                block.setWidth(5, type: .absoluteValueType, for: .padding)
                let paragraph = NSMutableParagraphStyle()
                paragraph.textBlocks = [block]
                let content = c < row.count ? row[c] : ""
                let cell = NSMutableAttributedString(attributedString:
                    inline(content, style: style, indent: 0))
                if r == 0 {
                    cell.addAttribute(.font, value: style.bold,
                                      range: NSRange(location: 0, length: cell.length))
                }
                cell.addAttribute(.paragraphStyle, value: paragraph,
                                  range: NSRange(location: 0, length: cell.length))
                out.append(cell)
                out.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: paragraph,
                                                                         .font: style.body]))
            }
        }
        out.append(NSAttributedString(string: "\n", attributes: [.font: style.body]))
        return out
    }

    // MARK: - Inline

    /// `**bold**`, `*italic*`, `` `code` `` and linked file paths.
    static func inline(_ text: String, style: ChatMarkdownStyle, indent: CGFloat) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 3
        if indent > 0 { paragraph.headIndent = indent }

        let out = NSMutableAttributedString()
        var run = ""
        var index = text.startIndex

        func flush() {
            guard !run.isEmpty else { return }
            out.append(NSAttributedString(string: run, attributes: [
                .font: style.body, .foregroundColor: style.text, .paragraphStyle: paragraph]))
            run = ""
        }

        while index < text.endIndex {
            let rest = text[index...]
            if rest.hasPrefix("**"), let end = closing(of: "**", in: rest.dropFirst(2)) {
                flush()
                out.append(NSAttributedString(string: String(rest.dropFirst(2).prefix(upTo: end)), attributes: [
                    .font: style.bold, .foregroundColor: style.text, .paragraphStyle: paragraph]))
                index = text.index(end, offsetBy: 2)
                continue
            }
            if rest.hasPrefix("`"), let end = closing(of: "`", in: rest.dropFirst(1)) {
                flush()
                out.append(NSAttributedString(string: String(rest.dropFirst(1).prefix(upTo: end)), attributes: [
                    .font: style.mono, .foregroundColor: style.text,
                    .backgroundColor: style.codeBackground, .paragraphStyle: paragraph]))
                index = text.index(end, offsetBy: 1)
                continue
            }
            if rest.hasPrefix("*"), !rest.hasPrefix("**"), let end = closing(of: "*", in: rest.dropFirst(1)) {
                flush()
                out.append(NSAttributedString(string: String(rest.dropFirst(1).prefix(upTo: end)), attributes: [
                    .font: style.italic, .foregroundColor: style.text, .paragraphStyle: paragraph]))
                index = text.index(end, offsetBy: 1)
                continue
            }
            run.append(text[index])
            index = text.index(after: index)
        }
        flush()
        linkPaths(in: out, style: style)
        return out
    }

    private static func closing(of marker: String, in text: Substring) -> String.Index? {
        text.range(of: marker)?.lowerBound
    }

    /// Turn detected file paths into `pcfile://` links, styled so they read as file chips.
    static func linkPaths(in string: NSMutableAttributedString, style: ChatMarkdownStyle) {
        for match in PathDetector.detect(in: string.string) {
            guard match.range.location + match.range.length <= string.length,
                  let encoded = match.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "pcfile://" + encoded) else { continue }
            string.addAttributes([
                .link: url,
                .foregroundColor: style.accent,
                .font: style.mono,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ], range: match.range)
        }
    }
}
