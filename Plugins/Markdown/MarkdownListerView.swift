// SPDX-License-Identifier: Apache-2.0
// MarkdownListerView.swift — the view this plugin hands the host, for Markdown and for HTML.
//
// One class for two formats because the host asks one question ("show me this file") and the answer
// differs only in how the page is produced:
//
//   * Markdown is rendered here into a self-contained HTML document with an embedded stylesheet and
//     its own Content-Security-Policy, and shown with scripts ALLOWED — the rendering engines are
//     scripts (see MarkdownWebView for why that is two configurations and not a flag).
//   * HTML is somebody else's document and is loaded as it is, with scripts REFUSED, decoded the way
//     the core did it: straight from the file when it declares a charset so relative CSS and images
//     resolve, and through the detected encoding when it does not.
//
// What the surrounding viewer needs from a content view — an outline, a way to scroll to one of its
// entries, the text for Find and Copy — is answered here and exposed through the PLX entry points in
// markdown_lister.swift. Before this, a plugin could only be asked "does the needle occur", so a
// plugin-rendered format lost the symbol sidebar and Copy All; that is the gap the additive ABI
// closes and the reason this view keeps its source around.

import AppKit
import PCFoundation
import PCVFS
import WebKit

@MainActor
final class MarkdownListerView: NSView {

    /// Which of the two documents this is — decided once, from the extension, and never re-asked.
    enum Kind {
        case markdown
        case html

        /// The extensions this plugin claims. Kept here rather than in the manifest alone because
        /// `ListGetDetectString` and the load path have to agree about them, and two lists agree
        /// only until somebody edits one.
        static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn", "mdwn"]
        static let htmlExtensions: Set<String> = ["html", "htm", "xhtml"]

        static func forExtension(_ ext: String) -> Kind? {
            let lower = ext.lowercased()
            if markdownExtensions.contains(lower) { return .markdown }
            if htmlExtensions.contains(lower) { return .html }
            return nil
        }
    }

    /// How much of a file is read. The core rendered at most 8 MiB of Markdown and 16 MiB of HTML;
    /// carried over rather than re-chosen, because those numbers were picked against real files and
    /// the viewer exists for documents that need not fit in memory.
    private static let markdownCap = 8 * 1024 * 1024
    private static let htmlCap = 16 * 1024 * 1024

    private let web: MarkdownWebContentView
    private let kind: Kind
    private(set) var path: String
    /// The Markdown source behind the rendered page (empty for HTML).
    ///
    /// Kept because the page is a web view: the outline is built from the source — headings and their
    /// nesting — while navigating goes to an element in the page. Without both halves the symbol
    /// sidebar had nothing to show for a document in its normal, rendered form.
    private(set) var source = ""
    /// 1-based source line of a heading → the `id` its element carries.
    private var anchors: [Int: String] = [:]

    /// A view for `path`, or nil when this plugin does not handle the file — which is how `ListLoad`
    /// says "not mine" and sends the host back to its own viewer.
    ///
    /// A factory rather than a failable initialiser, and that is not a matter of taste: an `NSView`
    /// subclass that returns nil *before* `super.init` leaves an allocated Objective-C object that was
    /// never initialised, and AppKit messages it later — the failure reads
    /// `-[NSView _setIgnoreFocusEngine:]: unrecognized selector`, from a stack that names none of this
    /// code. Deciding first and constructing second means there is never a half-built view at all.
    static func make(path: String, surface: String) -> MarkdownListerView? {
        guard let kind = Kind.forExtension((path as NSString).pathExtension),
              FileManager.default.isReadableFile(atPath: path) else { return nil }
        return MarkdownListerView(kind: kind, path: path, surface: surface)
    }

    private init(kind: Kind, path: String, surface: String) {
        self.kind = kind
        self.path = path
        self.web = makeMarkdownWebView(policy: kind == .markdown ? .ownDocument : .foreignDocument)
        super.init(frame: NSRect(x: 0, y: 0, width: 700, height: 500))
        // The surface is read but not yet acted on: a narrower chrome for the preview column is the
        // next step, and recording it now is what makes the plumbing testable before there is
        // anything to show. See ListLoadEx in plx.h for the key.
        self.embeddedSurface = surface
        web.translatesAutoresizingMaskIntoConstraints = false
        addSubview(web)
        NSLayoutConstraint.activate([
            web.topAnchor.constraint(equalTo: topAnchor),
            web.leadingAnchor.constraint(equalTo: leadingAnchor),
            web.trailingAnchor.constraint(equalTo: trailingAnchor),
            web.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        load()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Which host surface this view was embedded in ("viewer", "preview", "quickview" or "").
    private(set) var embeddedSurface = ""

    // MARK: - Loading

    /// Read the file and put it on screen.
    ///
    /// Cannot decline: `init` and `reload(path:)` have already established that this is a file of ours
    /// and that it can be read. A file that vanishes between those two moments shows as empty, which
    /// is the truth about it.
    private func load() {
        let url = URL(fileURLWithPath: path)
        let base = url.deletingLastPathComponent()
        guard let handle = FileHandle(forReadingAtPath: path) else { return }
        defer { try? handle.close() }
        let cap = kind == .markdown ? Self.markdownCap : Self.htmlCap
        let raw = handle.readData(ofLength: cap)

        switch kind {
        case .markdown:
            let bytes = [UInt8](raw)
            let encoding = EncodingDetector.detect(Array(bytes.prefix(64 * 1024)))
            let text = String(bytes: bytes, encoding: encoding) ?? String(decoding: bytes, as: UTF8.self)
            let rendered = MarkdownRenderer.document(from: text, title: url.lastPathComponent)
            source = text
            anchors = rendered.anchors
            loadWithoutNetwork(web) { [weak self] in
                self?.web.loadHTMLString(rendered.html, baseURL: base)
            }
        case .html:
            source = ""
            anchors = [:]
            let bytes = [UInt8](raw)
            loadWithoutNetwork(web) { [weak self] in
                guard let self else { return }
                if Self.declaresCharset(bytes) {
                    // WebKit knows the encoding — load the file itself, so relative CSS, images and
                    // links resolve against the folder it sits in.
                    self.web.loadFileURL(url, allowingReadAccessTo: base)
                } else {
                    // No charset declared: decode with the detected encoding and hand WebKit UTF-8,
                    // so non-ASCII text is not garbled. Such files are typically self-contained, so
                    // losing sibling-file access is the cheaper of the two losses.
                    let encoding = EncodingDetector.detect(Array(bytes.prefix(64 * 1024)))
                    let text = String(bytes: bytes, encoding: encoding)
                        ?? String(decoding: bytes, as: UTF8.self)
                    if let data = text.data(using: .utf8) {
                        self.web.load(data, mimeType: "text/html",
                                      characterEncodingName: "UTF-8", baseURL: base)
                    } else {
                        self.web.loadFileURL(url, allowingReadAccessTo: base)
                    }
                }
            }
        }
    }

    /// Show a different file in this same view — the host's viewer cycling and the preview panel
    /// following the cursor. False when the new file is not one this view can take, which sends the
    /// caller back to a fresh `ListLoad`.
    ///
    /// The *same kind*, not merely one this plugin handles: the two kinds differ in whether their web
    /// view may run scripts, and that is fixed when the view is created. Handing an .html document to
    /// a view built for Markdown would run its scripts.
    func reload(path newPath: String) -> Bool {
        guard Kind.forExtension((newPath as NSString).pathExtension) == kind,
              FileManager.default.isReadableFile(atPath: newPath) else { return false }
        path = newPath
        load()
        return true
    }

    /// Re-read the file that is already shown (the viewer's reload).
    func reloadInPlace() { load() }

    /// Whether an HTML document declares its encoding via a BOM or a `charset` in the first few KB,
    /// so WebKit will decode it correctly on its own.
    private static func declaresCharset(_ bytes: [UInt8]) -> Bool {
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { return true }
        if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]) { return true }
        return String(decoding: bytes.prefix(4096), as: UTF8.self).lowercased().contains("charset")
    }

    // MARK: - What the viewer asks for

    /// The document's structure, as `(depth, line, anchor, title)` rows for `ListGetOutline`.
    ///
    /// Built from the *source* through the host's own outline parser, so a rendered document and its
    /// source produce the same outline instead of two that disagree — and each row carries the
    /// element id the render pass gave that heading, which is what `gotoAnchor` needs.
    ///
    /// Empty for HTML, which is what the core also offered there: the sidebar was only ever filled
    /// for Markdown in the rendered representation.
    func outlineRows() -> [(depth: Int, line: Int, anchor: String, title: String)] {
        guard kind == .markdown, !source.isEmpty else { return [] }
        var rows: [(depth: Int, line: Int, anchor: String, title: String)] = []
        func walk(_ nodes: [SymbolNode], depth: Int) {
            for node in nodes {
                rows.append((depth: depth, line: node.line,
                             anchor: anchors[node.line] ?? "", title: node.name))
                walk(node.children, depth: depth + 1)
            }
        }
        walk(DeclarationOutline.parse(source, ext: "md"), depth: 0)
        // A heading the render pass gave no id to cannot be navigated to, and a row that cannot be
        // clicked is worse than no row: it looks like the feature is broken rather than absent.
        return rows.filter { !$0.anchor.isEmpty }
    }

    /// Scroll to an element id from `outlineRows`.
    ///
    /// Injected from the host side rather than by the page, so it works under both policies — the
    /// `allowsContentJavaScript` switch governs scripts the *document* brings, not this call. That is
    /// how the core's Copy already reached a page with scripts disabled.
    func gotoAnchor(_ anchor: String) -> Bool {
        guard !anchor.isEmpty, anchors.values.contains(anchor) else { return false }
        let escaped = anchor.replacingOccurrences(of: "\\", with: "\\\\")
                            .replacingOccurrences(of: "'", with: "\\'")
        web.evaluateJavaScript(
            "document.getElementById('\(escaped)')?.scrollIntoView({block:'start'})",
            in: nil, in: .defaultClient) { _ in }
        return true
    }

    /// The plain text of the document, for the find bar, Copy All, Mark All and Print.
    ///
    /// The Markdown *source* rather than the rendered text: it is what the reader would search for,
    /// it is what the outline is built from, and it is already in memory. For HTML there is no
    /// second form to offer, so the file's own text is it.
    var documentText: String {
        if kind == .markdown { return source }
        guard let handle = FileHandle(forReadingAtPath: path) else { return "" }
        defer { try? handle.close() }
        let bytes = [UInt8](handle.readData(ofLength: Self.htmlCap))
        let encoding = EncodingDetector.detect(Array(bytes.prefix(64 * 1024)))
        return String(bytes: bytes, encoding: encoding) ?? String(decoding: bytes, as: UTF8.self)
    }

    /// Find `needle` and highlight it. The answer is taken from the text rather than from WebKit,
    /// because `WKWebView.find` is asynchronous and `ListSearchText` has to answer now: the
    /// highlight lands a moment later, the return value is right immediately.
    func find(_ needle: String, matchCase: Bool) -> Bool {
        guard !needle.isEmpty else { return false }
        let config = WKFindConfiguration()
        config.caseSensitive = matchCase
        config.wraps = true
        web.find(needle, configuration: config) { _ in }
        let haystack = documentText
        return matchCase
            ? haystack.contains(needle)
            : haystack.range(of: needle, options: .caseInsensitive) != nil
    }

    /// Copy, which the host reaches through `responds(to: copy:)` on this view.
    ///
    /// The selection when there is one, handed to WebKit so the clipboard keeps the rich flavours its
    /// own context menu provides; otherwise the whole rendered text as plain text, which is all the
    /// other representations offer anyway.
    /// Not an `override`: `copy:` is a message AppKit routes through the responder chain rather than
    /// a method `NSResponder` declares — which is exactly why the host has to ask `responds(to:)`
    /// before sending one. (`selectAll:` below *is* declared, hence the difference.)
    @objc func copy(_ sender: Any?) {
        web.evaluateJavaScript("window.getSelection().toString()", in: nil, in: .defaultClient) { result in
            let selection = ((try? result.get()) as? String) ?? ""
            if !selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                NSApp.sendAction(#selector(NSText.copy(_:)), to: self.web, from: nil)
                return
            }
            self.web.evaluateJavaScript("document.body.innerText", in: nil, in: .defaultClient) { textResult in
                guard let text = (try? textResult.get()) as? String,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    NSSound.beep(); return
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        }
    }

    @objc override func selectAll(_ sender: Any?) {
        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: web, from: nil)
    }

    /// The web view, so `listershot` can take a picture of the page.
    ///
    /// WebKit renders in another process, so `cacheDisplay` on this view returns an empty bitmap and
    /// only `takeSnapshot` sees the page. The host finds this by walking the subtree for a
    /// `WKWebView`, so nothing plugin-specific has to leak into the automation verb.
    var contentWebView: WKWebView { web }
}
