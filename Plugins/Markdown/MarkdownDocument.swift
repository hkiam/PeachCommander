// SPDX-License-Identifier: Apache-2.0
// MarkdownDocument.swift — Markdown -> HTML for the Markdown lister plugin.
//
// Was Sources/PCFoundation/MarkdownRenderer.swift, a hand-written parser, until the whole subject
// left the core. Inside a plugin it can link what the application will not, so the parsing is
// `swift-markdown` (Apache-2.0 with Runtime Library Exception) over cmark-gfm, compiled straight into
// the bundle by Tools/build-markdown-plugin.sh. What that buys, none of which the hand-written parser
// could do: nested lists, task lists, loose and tight list items, reference links, and GFM tables
// with alignment — parsed by the implementation the format's own specification is tested against
// rather than by a set of regular expressions.
//
// What did NOT change is everything around the parse, and that is deliberate: the same GitHub-like
// stylesheet, the same Content-Security-Policy, the same element ids keyed by source line so the
// viewer's outline can scroll the page, the same fence-language colouring through
// SyntaxHighlighter, and the same escaping. The tests moved here with the file and assert the
// *output HTML*, so they carried across the swap unchanged except where the parser legitimately does
// better — which is the point of having pinned the output rather than the parse.
//
// One rule is load-bearing and easy to lose: **raw HTML in the document is escaped, never emitted.**
// cmark hands it over as `HTMLBlock` and `InlineHTML`, and a real Markdown renderer would pass it
// through. This one must not: the page it produces runs JavaScript (the diagram and formula engines
// need to), so passing a document's own `<script>` through would hand a file the ability to run code
// in the viewer. See `visitHTMLBlock` and `visitInlineHTML`.

import Foundation
// SyntaxHighlighter and its token kinds: the plugin links the host's framework rather than carrying a
// second lexer, which is also what keeps a fence coloured the same way the editor colours the same
// language.
import PCFoundation
// The parser. In the plugin build there is no `Markdown` module: swift-markdown's sources are
// compiled into the plugin's own module, so its types are already in scope. The test bundle takes it
// as a SwiftPM product instead, where the module does exist. Conditional for exactly that reason —
// the same arrangement Plugins/SDK/PluginTheme.swift uses for CContrib, and what lets one file
// compile unchanged in both places.
#if canImport(Markdown)
import Markdown
#endif

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
    ///
    /// No `script-src`, although the page runs two engines: they are injected as `WKUserScript`
    /// through WebKit's own channel rather than authored by the page, and the page's policy governs
    /// the page. `blob:` is in `img-src` because Mermaid draws through one.
    public static let contentSecurityPolicy =
        "default-src 'none'; img-src file: data: blob:; style-src 'unsafe-inline'; font-src file: data:"

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
        var emitter = HTMLEmitter()
        // Line endings normalised before the parse rather than after: cmark counts source lines, and
        // the anchors are keyed by them, so a CRLF document would otherwise get anchors the outline
        // cannot match. (A CRLF is one Swift `Character`, which is how six other defects in this
        // repository started.)
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
                                 .replacingOccurrences(of: "\r", with: "\n")
        emitter.visit(Document(parsing: normalized))
        return Rendered(html: emitter.out, anchors: emitter.anchors)
    }

    /// A fence rendered as `<pre><code>`, carrying the GFM `language-…` class and, where there is
    /// a lexer for it, `<span class="tok-…">` around comments, strings, numbers and keywords.
    ///
    /// Classes and an embedded stylesheet, never a `style=` attribute and never a script: the
    /// document's `default-src 'none'` policy is the point and is not relaxed for colour.
    static func codeBlock(_ code: String, info: String) -> String {
        let attr = isLanguageToken(info) ? " class=\"language-\(info)\"" : ""
        guard let language = fenceLanguage(info) else {
            return "<pre><code\(attr)>\(escape(code))</code></pre>"
        }
        return "<pre><code\(attr)>\(highlighted(code, language: language))</code></pre>"
    }

    /// The language word of a fence's info string, lowercased — `swift` from ```` ```swift ````, and
    /// from ```` ```swift title="A.swift" ```` too. Empty when the fence names nothing.
    ///
    /// The parser hands over the whole info string; this reduces it to the word that names a
    /// language. The hand-written renderer skipped the opening line entirely, so every code block in
    /// every rendered `.md` arrived as an unmarked `<pre><code>` (F-461).
    static func fenceInfo(_ infoString: String) -> String {
        // `{.python}` (Pandoc) and `swift,linenos` name a language as much as a bare word does.
        infoString.trimmingCharacters(in: .whitespaces)
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
    /* A task item shows its box instead of a bullet, and the box sits on the text's line rather
       than above it — both of which the first picture of this got wrong. */
    .markdown-body li.task { list-style-type: none; margin-left: -1.2em; }
    .markdown-body li.task > input[type="checkbox"] {
      margin: 0 .4em 0 0; vertical-align: -0.05em;
    }
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
