// SPDX-License-Identifier: Apache-2.0
// MarkdownHTML.swift — the walk from swift-markdown's tree to the HTML the viewer shows.
//
// Split from MarkdownDocument.swift, which keeps everything that is *not* the parse: the stylesheet,
// the Content-Security-Policy, the anchor scheme and the fence colouring. This file is only the
// mapping, node by node, and it is written so each decision can be argued with:
//
//   * Raw HTML is escaped, never emitted. A real Markdown renderer passes it through; this one may
//     not, because the page runs the diagram and formula engines and a document's own `<script>`
//     would then run too. It is the one rule here whose loss would be a security defect rather than
//     a cosmetic one.
//   * Blocks are joined by a newline, and headings carry an id keyed by their *source line*, because
//     that is what the viewer's outline knows a heading by.
//   * A tight list's items emit without `<p>`, which is how a tight list reads. cmark knows
//     tightness; swift-markdown does not expose it, so `isLoose` reconstructs it from the tree and
//     the source ranges — and says that it is an approximation.

import Foundation
// The parser. In the plugin build there is no `Markdown` module: swift-markdown's sources are
// compiled into the plugin's own module, so its types are already in scope. The test bundle takes it
// as a SwiftPM product instead, where the module does exist. Conditional for exactly that reason —
// the same arrangement Plugins/SDK/PluginTheme.swift uses for CContrib, and what lets one file
// compile unchanged in both places.
#if canImport(Markdown)
import Markdown
#endif

/// Walks a parsed document and builds its HTML.
///
/// A `MarkupWalker` rather than a `MarkupVisitor` returning strings: the output is one buffer with a
/// stack discipline (see `capture`), which keeps the append order obvious and costs no intermediate
/// arrays per node.
struct HTMLEmitter: MarkupWalker {
    /// The HTML built so far, at the current nesting level.
    private(set) var out = ""
    /// 1-based source line of a heading → the `id` its element carries.
    private(set) var anchors: [Int: String] = [:]
    /// Ids already handed out, so a document repeating a heading gets two anchors and not one.
    private var usedAnchors = Set<String>()
    /// Inside an item of a *tight* list, where a paragraph takes no `<p>` — see `isLoose`.
    private var inTightItem = false

    // MARK: - Buffer discipline

    /// Append a block, separated from the previous one by a newline.
    ///
    /// The separator goes *before* rather than after, so the result never ends in one — the tests
    /// compare whole strings, and a trailing newline is the kind of difference that makes a
    /// correct renderer look broken.
    private mutating func block(_ html: String) {
        if !out.isEmpty { out += "\n" }
        out += html
    }

    /// Render `markup`'s children into a string of their own.
    ///
    /// Swaps the buffer rather than slicing it: an index into a growing Swift string is not cheap,
    /// and this runs once per container node.
    private mutating func capture(_ markup: Markup) -> String {
        let saved = out
        let savedTight = inTightItem
        out = ""
        descendInto(markup)
        let captured = out
        out = saved
        inTightItem = savedTight
        return captured
    }

    // MARK: - Anything not named below

    /// Descend, so a node this file has no opinion about still contributes its children.
    ///
    /// The alternative — dropping it — is how a renderer silently loses text when the parser learns a
    /// new node type.
    mutating func defaultVisit(_ markup: Markup) {
        descendInto(markup)
    }

    // MARK: - Blocks

    mutating func visitHeading(_ heading: Heading) {
        let content = capture(heading)
        let id = MarkdownRenderer.uniqueAnchor(for: heading.plainText, used: &usedAnchors)
        // The line the heading *starts* on, which for the underlined (setext) form is the title and
        // not the run of `=` beneath it — the same line DeclarationOutline.parseMarkdown reports, so
        // the outline and the page agree about where a heading is.
        if let line = heading.range?.lowerBound.line { anchors[line] = id }
        block("<h\(heading.level) id=\"\(MarkdownRenderer.escape(id))\">\(content)</h\(heading.level)>")
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        let content = capture(paragraph)
        block(inTightItem ? content : "<p>\(content)</p>")
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        // cmark keeps the trailing newline of the last line; the viewer's `<pre>` would show it as a
        // blank line at the bottom of every block.
        var code = codeBlock.code
        if code.hasSuffix("\n") { code.removeLast() }
        block(MarkdownRenderer.codeBlock(code, info: MarkdownRenderer.fenceInfo(codeBlock.language ?? "")))
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        block("<blockquote>\(capture(blockQuote))</blockquote>")
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        block("<hr>")
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        block("<ul>\n\(items(of: unorderedList.listItems))\n</ul>")
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        // `1.` is the overwhelming case and needs no attribute; a list starting at 7 says so.
        let start = orderedList.startIndex == 1 ? "" : " start=\"\(orderedList.startIndex)\""
        block("<ol\(start)>\n\(items(of: orderedList.listItems))\n</ol>")
    }

    private mutating func items<S: Sequence>(of listItems: S) -> String where S.Element == ListItem {
        let items = Array(listItems)
        let tight = !isLoose(items)
        return items.map { item in
            inTightItem = tight
            let content = capture(item)
            inTightItem = false
            // A task item is marked so the stylesheet can drop its bullet: a box *and* a bullet is
            // what the first picture of this showed, and one of the two is redundant.
            let attributes = item.checkbox == nil ? "" : " class=\"task\""
            return "<li\(attributes)>\(checkbox(of: item))\(content)</li>"
        }.joined(separator: "\n")
    }

    /// Whether a list is *loose* — its items separated by blank lines, so each one keeps its `<p>`
    /// and the reader sees the spacing the author asked for.
    ///
    /// CommonMark makes tightness a property of the list rather than of an item, and cmark knows it;
    /// swift-markdown does not expose it, so this is reconstructed from what the tree does carry:
    ///
    ///   * an item holding two paragraphs was written with a blank line inside it, and
    ///   * an item whose own range reaches past its last child swallowed a trailing blank line.
    ///
    /// The second rule is the one that had to be measured rather than reasoned about. The gap
    /// *between* consecutive items does not distinguish the cases: for both `- one\n\n- two` and
    /// `- one\n  - nested\n- two` the first item spans lines 1–2 and the second starts on line 3.
    /// What differs is what the first item contains — one paragraph on line 1, or a paragraph and a
    /// sublist covering both lines. So the question is asked inwards, not sideways.
    ///
    /// An approximation, and named as one: cmark's own answer is not on the tree. It gets the cases a
    /// reader notices right — nesting stays tight, a blank line between items goes loose.
    private func isLoose(_ items: [ListItem]) -> Bool {
        for (index, item) in items.enumerated() {
            if item.children.filter({ $0 is Paragraph }).count > 1 { return true }
            // The *last* item is exempt from the trailing-blank-line test: a blank line after the
            // list separates it from whatever follows and belongs to the document, but cmark counts
            // it inside the final item's range all the same. Without this exemption every list with
            // anything after it came out loose — which is what the first picture of a task list
            // showed, the box on one line and its text on the next, and what no unit test caught
            // because the fixtures ended with the list.
            guard index < items.count - 1,
                  let itemEnd = item.range?.upperBound.line,
                  let childEnd = item.children.compactMap({ $0.range?.upperBound.line }).max()
            else { continue }
            if itemEnd > childEnd { return true }
        }
        return false
    }

    /// A task-list item's box, disabled because the viewer is read-only.
    ///
    /// An `<input>` needs no resource, so it costs the policy nothing — which a rendered image of a
    /// tick would not.
    private func checkbox(of item: ListItem) -> String {
        switch item.checkbox {
        case .checked: return "<input type=\"checkbox\" checked disabled> "
        case .unchecked: return "<input type=\"checkbox\" disabled> "
        case nil: return ""
        }
    }

    mutating func visitTable(_ table: Table) {
        var rows: [String] = []
        let alignments = table.columnAlignments
        // `Head` and `Row` are separate types with the same shape, so the cells come in as a
        // sequence rather than through a common protocol.
        func cells<S: Sequence>(_ cells: S, tag: String) -> String where S.Element == Table.Cell {
            cells.enumerated().map { index, cell in
                var attributes = ""
                if index < alignments.count, let alignment = alignments[index] {
                    attributes += " style=\"text-align:\(name(of: alignment))\""
                }
                // GFM lets a cell span columns; dropping the attribute would silently redraw the
                // table with the wrong shape.
                if cell.colspan > 1 { attributes += " colspan=\"\(cell.colspan)\"" }
                if cell.rowspan > 1 { attributes += " rowspan=\"\(cell.rowspan)\"" }
                return "<\(tag)\(attributes)>\(capture(cell))</\(tag)>"
            }.joined()
        }
        rows.append("<tr>" + cells(table.head.cells, tag: "th") + "</tr>")
        for row in table.body.rows {
            rows.append("<tr>" + cells(row.cells, tag: "td") + "</tr>")
        }
        block("<table>\n\(rows.joined(separator: "\n"))\n</table>")
    }

    private func name(of alignment: Table.ColumnAlignment) -> String {
        switch alignment {
        case .left: return "left"
        case .right: return "right"
        case .center: return "center"
        }
    }

    /// A block of raw HTML in the source, shown as the text it is.
    ///
    /// **Not** passed through, and this is the rule the file header calls load-bearing: the page runs
    /// the diagram and formula engines, so a `<script>` emitted here would run. Rendering it as a
    /// paragraph of escaped text is also what the hand-written parser did, which is why the escaping
    /// test carried across the swap unchanged.
    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        var raw = html.rawHTML
        while raw.hasSuffix("\n") { raw.removeLast() }
        block("<p>\(MarkdownRenderer.escape(raw))</p>")
    }

    // MARK: - Inlines

    mutating func visitText(_ text: Text) {
        out += linkify(MarkdownRenderer.escape(text.string))
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        // Escaped and *not* linkified: `http://x` in backticks is a piece of text about a URL.
        out += "<code>\(MarkdownRenderer.escape(inlineCode.code))</code>"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        out += MarkdownRenderer.escape(inlineHTML.rawHTML)   // see visitHTMLBlock
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        out += "<em>\(capture(emphasis))</em>"
    }

    mutating func visitStrong(_ strong: Strong) {
        out += "<strong>\(capture(strong))</strong>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        out += "<del>\(capture(strikethrough))</del>"
    }

    mutating func visitLink(_ link: Link) {
        let href = MarkdownRenderer.escape(link.destination ?? "")
        out += "<a href=\"\(href)\">\(capture(link))</a>"
    }

    mutating func visitImage(_ image: Image) {
        // The alt text is the image's own children as plain text — which is what a reader gets when
        // the file is not there, and what the policy leaves them with for a remote one.
        let alt = MarkdownRenderer.escape(image.plainText)
        let src = MarkdownRenderer.escape(image.source ?? "")
        out += "<img alt=\"\(alt)\" src=\"\(src)\">"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        // A single newline in the source is a space in the output, as in CommonMark and as the
        // hand-written renderer had it.
        out += " "
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        out += "<br>\n"
    }

    // MARK: - Bare URLs

    /// Turn a bare `http://…` or `www.…` in *text* into a link.
    ///
    /// cmark's autolink extension is not among the three swift-markdown enables (table, strikethrough
    /// and tasklist), so without this a plain URL in a paragraph would stop being clickable — a
    /// feature the hand-written renderer had, and its loss would be a regression rather than a
    /// difference. Applied only to text nodes, so a URL inside `<code>` is left alone.
    private func linkify(_ escaped: String) -> String {
        guard escaped.contains("http") || escaped.contains("www.") else { return escaped }
        guard let regex = try? NSRegularExpression(
            pattern: #"(^|[\s(])((?:https?://|www\.)[^\s<)]+)"#, options: [.anchorsMatchLines])
        else { return escaped }
        let ns = escaped as NSString
        var result = ""
        var last = 0
        for match in regex.matches(in: escaped, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            let lead = ns.substring(with: match.range(at: 1))
            let url = ns.substring(with: match.range(at: 2))
            let href = url.hasPrefix("www.") ? "http://\(url)" : url
            result += "\(lead)<a href=\"\(href)\">\(url)</a>"
            last = match.range.location + match.range.length
        }
        result += ns.substring(from: last)
        return result
    }
}
