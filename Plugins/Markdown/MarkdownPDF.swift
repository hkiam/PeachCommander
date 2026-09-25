// SPDX-License-Identifier: Apache-2.0
// MarkdownPDF.swift — "Export to PDF" for the two formats this plugin already renders.
//
// The plugin owns the only renderer the application has for .md and .html, so it is also the only
// place that can answer "give me that document as a PDF". Anything else — QuickLook, a shell out to
// pandoc, AppKit's HTML reader — would be a *second* rendering of the same file, and the reader
// would get a PDF that does not look like what F3 showed them.
//
// So the page is produced exactly as the viewer produces it: a `MarkdownListerView`, with the same
// two web-view policies (our generated page may run Mermaid and KaTeX, a foreign .html file may run
// nothing), the same network block, the same encoding detection and the same size cap. The view is
// put in an off-screen window because WebKit lays out in a window or not at all, and then captured a
// page at a time with `createPDF` and stitched onto real sheets.
//
// **`WKWebView.printOperation` is not used, and that is measured rather than a preference.** Asking
// WebKit to paginate never returns on this platform: `op.run()` writes repeated pages until it is
// killed — a gigabyte in ninety seconds, first in a standalone harness and then in the application
// itself, with the print view's own frame reported as 0x0. `createPDF` renders a rectangle of the
// document and returns, so the pagination is done here instead: the document is measured, the page
// breaks are put at block boundaries the page itself reports, and the slices are composed onto A4 or
// Letter with Core Graphics.
//
// Three details are deliberate and easy to lose:
//
//   * **The page is forced light.** The stylesheet follows `prefers-color-scheme`, which is right on
//     screen and wrong on paper: nobody wants a PDF with a #0d1117 background, least of all their
//     printer.
//   * **Diagrams are waited for.** Mermaid resolves a promise per diagram, so `didFinish` means the
//     document is there and the figures are not. Capturing at that moment produces a PDF with holes
//     where the diagrams were — and it does it silently, which is how it would have shipped.
//   * **Pages break at blocks, not at a fixed height.** Cutting every 770 points puts a break
//     through the middle of a line of text, half the glyphs on one page and half on the next; the
//     page reports where its paragraphs, list items and table rows end, and the cut goes there.
//
// Nothing here touches the C ABI; markdown_lister.swift adapts `PcRunCommand` to `Callbacks` below.
// That keeps this file compilable in the test bundle, which has no bridging header.

import AppKit
import WebKit

@MainActor
enum MarkdownPDF {

    /// What the export still needs from the host once the command that started it has returned.
    ///
    /// Closures rather than the services table itself: an export outlives `PcRunCommand` (the
    /// document has to load first), and the pointer the host passes is a pointer to *its* stack. The
    /// host's own token is long-lived — `ContributionRegistry` keeps one bridge per host for exactly
    /// this — so copying the callbacks out is safe where keeping the pointer is not.
    struct Callbacks {
        var presentInfo: (_ title: String, _ message: String) -> Void = { _, _ in }
        /// Reveal a path in the active panel; the host's `openPath`.
        var reveal: (_ path: String) -> Void = { _ in }
    }

    /// One file's answer, collected so the message at the end can tell the whole truth about a
    /// selection rather than only about its last file.
    enum Outcome {
        case written(source: String, pdf: String)
        case failed(source: String, reason: String)
    }

    /// Why one file did not become a PDF.
    ///
    /// Named cases rather than one message, because the four are four different things for the
    /// reader to do about it, and a single "could not be rendered" for all of them sends somebody
    /// to the diagram settings when the real answer is that the folder is read-only.
    enum Failure {
        case notLocal
        case declined
        case couldNotRender
        case couldNotWrite
        case tooLong

        var reason: String {
            switch self {
            case .notLocal: return L("not a file on the local disk")
            case .declined: return L("too large, or not a document this plugin renders")
            case .couldNotRender: return L("the page could not be rendered")
            case .couldNotWrite: return L("the folder could not be written to")
            case .tooLong: return L("too long to lay out as a PDF")
            }
        }
    }

    /// The surface name this view is created under, for the same reason the viewer passes one.
    private static let surface = "pdf"

    // MARK: - What can be exported, and where it goes

    /// The paths in `paths` whose extension this plugin claims, once each, in the order given.
    ///
    /// A selection in a file manager is whatever the reader happened to have marked, so filtering
    /// here rather than refusing the command is what makes "select the folder and export the four
    /// READMEs in it" work.
    static func claimed(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.filter {
            MarkdownListerView.Kind.forExtension(($0 as NSString).pathExtension) != nil
                && seen.insert($0).inserted
        }
    }

    /// Of those, the ones that are a readable file on the disk.
    ///
    /// The others are documents inside an archive or on a mounted drive: the path is a VFS path
    /// with nothing behind it here, so neither the document can be read nor a PDF put beside it.
    /// The manifest's `when` keeps the command off those panels, and this is the second half of the
    /// same answer — for the routes that do not go through a menu, such as a keyboard shortcut.
    static func exportable(_ paths: [String]) -> [String] {
        claimed(paths).filter { path in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                && !isDirectory.boolValue
        }
    }

    /// Where `path`'s PDF is written: beside the document, under its own name.
    ///
    /// Beside it rather than through a save panel because that is what a file manager is for — the
    /// reader is already standing in the folder they mean. With `overwrite` off an existing PDF is
    /// kept and the new one is numbered, so a second export never quietly destroys the first.
    static func destination(for path: String, overwrite: Bool) -> URL {
        let source = URL(fileURLWithPath: path)
        let folder = source.deletingLastPathComponent()
        let stem = source.deletingPathExtension().lastPathComponent
        let first = folder.appendingPathComponent(stem + ".pdf")
        if overwrite || !FileManager.default.fileExists(atPath: first.path) { return first }
        for n in 2...999 {
            let candidate = folder.appendingPathComponent("\(stem) \(n).pdf")
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        // A folder holding 999 exports of one document does not need a third rule.
        return first
    }

    /// Where to cut the document, top to bottom.
    ///
    /// A cut is taken at the last block boundary that still fits on the page; if a single block is
    /// taller than a page — a long code fence, a wide diagram — there is no boundary to use and the
    /// page is filled to the brim, which is what any other renderer does with it too.
    ///
    /// Takes the column it is cutting (`width`, `pageHeight`) rather than paper and margins: when
    /// the document is wider than the sheet the whole capture is scaled down, and then a "page" is
    /// taller in document space than the sheet is in points. Fully parameterised and `static` so it
    /// can be exercised without a web view: this is where a page of somebody's document goes
    /// missing, and it is the half of the export a test can reach.
    static func slices(top: Double, bottom: Double, breaks: [Double],
                       width: Double, pageHeight: Double, limit: Int) -> [CGRect] {
        var out: [CGRect] = []
        var start = top
        while start < bottom - 1, out.count < limit {
            let nominal = start + pageHeight
            if nominal >= bottom {
                out.append(CGRect(x: 0, y: start, width: width, height: bottom - start))
                break
            }
            // Only a boundary that leaves a page worth having: a cut a few points below the top
            // would produce a page with one line on it and push everything else down.
            let usable = breaks.last { $0 <= nominal && $0 > start + pageHeight * 0.2 }
            let end = usable ?? nominal
            out.append(CGRect(x: 0, y: start, width: width, height: end - start))
            start = end
        }
        return out
    }

    // MARK: - Running an export

    /// The export in flight, which is also what keeps its window and web view alive.
    private static var page: Page?
    /// True between the first file being started and the last one being reported.
    private static var running = false

    /// Export every document in `paths`, then say what happened.
    ///
    /// Asynchronous although `PcRunCommand` is not: the command returns at once and the work
    /// continues on the main actor. A synchronous export would have to spin a nested run loop while
    /// WebKit loads, which is the shape that turns "the PDF is taking a moment" into "the
    /// application has stopped drawing".
    static func export(paths: [String], configRoot: String, host: Callbacks) {
        let options = MarkdownOptions.read(configRoot: configRoot)
        let wanted = claimed(paths)
        guard !wanted.isEmpty else {
            host.presentInfo(L("Export to PDF"), L("No Markdown or HTML document is selected."))
            return
        }
        guard !running else {
            host.presentInfo(L("Export to PDF"), L("An export is already running."))
            return
        }
        // A document this plugin claims but cannot reach carries its own reason into the report,
        // rather than disappearing out of the selection and leaving "nothing is selected" to be
        // said about a file the reader can plainly see.
        let files = exportable(wanted)
        let unreachable = wanted.filter { !files.contains($0) }
            .map { Outcome.failed(source: $0, reason: Failure.notLocal.reason) }
        running = true
        step(files, outcomes: unreachable, options: options, configRoot: configRoot, host: host)
    }

    /// One file, then the rest. Recursive rather than a loop because each file has to be loaded
    /// before it can be printed, and loading is asynchronous.
    private static func step(_ remaining: [String], outcomes: [Outcome],
                             options: MarkdownOptions, configRoot: String, host: Callbacks) {
        guard let path = remaining.first else {
            running = false
            page = nil
            report(outcomes, options: options, host: host)
            return
        }
        let rest = Array(remaining.dropFirst())
        func next(_ outcome: Outcome) {
            step(rest, outcomes: outcomes + [outcome], options: options,
                 configRoot: configRoot, host: host)
        }
        // `make` is the viewer's own gate: not one of ours, unreadable, or past the size limit the
        // reader set. Declining here means the PDF and the F3 view agree about which files exist.
        guard let view = MarkdownListerView.make(path: path, surface: surface, configRoot: configRoot)
        else {
            next(.failed(source: path, reason: Failure.declined.reason))
            return
        }
        let destination = destination(for: path, overwrite: options.pdfOverwrite)
        let current = Page(view: view, paper: options.pdfPaper)
        page = current
        current.write(to: destination) { failure in
            page = nil
            next(failure.map { .failed(source: path, reason: $0.reason) }
                 ?? .written(source: path, pdf: destination.path))
        }
    }

    /// Say what happened, once, for the whole selection — and as quietly as the truth allows.
    ///
    /// The host's `presentInfo` is a modal alert, so an export that always ended in one would cost a
    /// click every time it worked. Going to the file is the report when everything did: the panel
    /// reloads and the PDF is in it. An alert is kept for the cases where there is something the
    /// reader would not otherwise find out — a file that failed, or a run with the reveal switched
    /// off, which then has no other sign that anything happened at all.
    private static func report(_ outcomes: [Outcome], options: MarkdownOptions, host: Callbacks) {
        var written: [String] = []
        var failures: [String] = []
        for outcome in outcomes {
            switch outcome {
            case .written(_, let pdf): written.append(pdf)
            case .failed(let source, let reason):
                failures.append("\((source as NSString).lastPathComponent) — \(reason)")
            }
        }
        if options.pdfReveal, let last = written.last { host.reveal(last) }
        guard !failures.isEmpty || !options.pdfReveal else { return }

        var lines: [String] = []
        if written.count == 1 {
            lines.append(String(format: L("Exported %@."),
                                (written[0] as NSString).lastPathComponent))
        } else if written.count > 1 {
            lines.append(String(format: L("Exported %lld documents."), Int64(written.count)))
        }
        lines.append(contentsOf: failures)
        host.presentInfo(L("Export to PDF"), lines.joined(separator: "\n"))
    }
}

// MARK: - One document, off screen, onto paper

/// Loads one document in an off-screen window and prints it to a file.
///
/// A class because it has to be a `WKNavigationDelegate` and to outlive the call that made it; it is
/// held by `MarkdownPDF.page` for exactly as long as its completion has not run.
@MainActor
private final class Page: NSObject, WKNavigationDelegate {
    private let view: MarkdownListerView
    private let window: NSWindow
    private let paper: MarkdownPaper
    private var destination = URL(fileURLWithPath: "/dev/null")
    /// nil means it worked; a `Failure` says what went wrong.
    private var completion: ((MarkdownPDF.Failure?) -> Void)?
    /// Fires if the current phase stalls, so one stuck file cannot hold up the rest of a selection
    /// for ever. Re-armed per phase — see `arm(_:)`.
    private var watchdog: DispatchWorkItem?
    /// When to stop waiting for Mermaid and print what there is. A diagram that never resolves must
    /// not cost the reader the other twenty pages.
    private var diagramDeadline = Date.distantPast
    /// How much the capture is shrunk to fit the sheet's width. 1 when the document fits.
    private var scale = 1.0

    /// The margin on every side, in points. Three quarters of an inch — the page's own padding is
    /// dropped for the capture (see `pc-paged`), so this is the whole of it, and half an inch of
    /// white around a full-width column of text reads as a web page rather than a document.
    private static let margin: CGFloat = 54
    /// How tall the off-screen window is. The layout the printer paginates is the one the window
    /// produced, and a short window makes Mermaid draw its diagrams for a short page.
    private static let layoutHeight: CGFloat = 1400
    /// How long a document may take to load before the export gives up on it.
    private static let loadTimeout: TimeInterval = 60
    /// How long the diagrams may take after the document itself is there.
    private static let diagramTimeout: TimeInterval = 15
    /// How long measuring, capturing every page and composing may take, after the diagrams.
    private static let captureTimeout: TimeInterval = 120

    init(view: MarkdownListerView, paper: MarkdownPaper) {
        self.view = view
        self.paper = paper
        let frame = NSRect(x: 0, y: 0, width: paper.size.width - Self.margin * 2,
                           height: Self.layoutHeight)
        window = NSWindow(contentRect: frame, styleMask: [.borderless],
                          backing: .buffered, defer: false)
        super.init()
        window.isReleasedWhenClosed = false
        // Light, whatever the reader's Mac is set to: the stylesheet follows `prefers-color-scheme`,
        // which is the right answer on screen and the wrong one on paper.
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = view
        // Ordered in, because WebKit does not lay out a view that is in no window — and far enough
        // off screen that nothing flashes. A borderless window is not constrained onto a display.
        window.setFrameOrigin(NSPoint(x: -30000, y: -30000))
        window.orderBack(nil)
        view.contentWebView.navigationDelegate = self
    }

    /// Render and write. `done(nil)` means the PDF is there; anything else says why it is not.
    ///
    /// The load itself was started by the view's own initialiser, so all this has to arrange is the
    /// case where it never finishes.
    func write(to url: URL, done: @escaping (MarkdownPDF.Failure?) -> Void) {
        destination = url
        completion = done
        arm(Self.loadTimeout)
    }

    /// Give the phase that is starting its own deadline, replacing the previous one.
    ///
    /// Per phase rather than one for the whole export: a single 60-second budget armed at the start
    /// also has to cover the diagram wait, the measurement, one capture per page and the compose —
    /// so a long or diagram-heavy document that was progressing perfectly well would be abandoned
    /// part-way and reported as a document that could not be rendered.
    private func arm(_ seconds: TimeInterval) {
        watchdog?.cancel()
        let watchdog = DispatchWorkItem { [weak self] in self?.report(.couldNotRender) }
        self.watchdog = watchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: watchdog)
    }

    // MARK: - Waiting for the page

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        diagramDeadline = Date().addingTimeInterval(Self.diagramTimeout)
        // The document is here; what follows is the diagram wait, the measurement and one capture
        // per page, and that is a different budget from loading a file.
        arm(Self.diagramTimeout + Self.captureTimeout)
        waitForDiagrams()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        report(.couldNotRender)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        report(.couldNotRender)
    }

    /// True once every `div.pc-diagram` has been filled with its SVG.
    ///
    /// The holder is created empty and its `innerHTML` set when Mermaid's promise resolves (see
    /// MarkdownEngines), so "has a child element" is exactly the question. A document with no
    /// diagrams answers true on the first ask, which is the common case and costs one round trip.
    /// KaTeX needs no wait at all: it typesets synchronously at document end.
    private static let diagramsReady = """
    (function () {
      var holders = document.querySelectorAll('.pc-diagram');
      for (var i = 0; i < holders.length; i++) {
        if (!holders[i].firstElementChild) { return false; }
      }
      return true;
    })();
    """

    private func waitForDiagrams() {
        guard completion != nil else { return }
        view.contentWebView.evaluateJavaScript(Self.diagramsReady, in: nil, in: .defaultClient) { [self] result in
            // A page that will not answer is a page with nothing to wait for: a foreign .html
            // document is the ordinary case here, not a failure.
            let ready = ((try? result.get()) as? Bool) ?? true
            if ready || Date() >= diagramDeadline {
                capture()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.waitForDiagrams() }
            }
        }
    }

    // MARK: - Onto paper

    /// The height of a document and the places it may be cut, from the page itself.
    ///
    /// The cuts are the bottom edges of the blocks a reader thinks in — paragraphs, headings, list
    /// items, table rows, figures. Slicing at a fixed page height without them puts a page break
    /// through the middle of a line of text, half the glyphs on one page and half on the next, which
    /// is the single most visible way a generated PDF can be wrong.
    private static let measureDocument = """
    (function () {
      // The page rules the capture is laid out under; see MarkdownDocument's stylesheet. Added
      // first, so the measurement below is of the document as it will be captured and not of the
      // one that was on screen a moment ago.
      document.body.classList.add('pc-paged');
      var root = document.querySelector('.markdown-body') || document.body;
      var breaks = [];
      function walk(el, depth) {
        for (var i = 0; i < el.children.length; i++) {
          var child = el.children[i];
          var rect = child.getBoundingClientRect();
          // NOT below a heading: a cut there leaves the heading alone at the foot of a page with
          // its section starting on the next one, which is the one page break a reader notices.
          if (!/^H[1-6]$/.test(child.tagName)) {
            breaks.push(Math.round(rect.bottom + window.scrollY));
          }
          // One level into the containers whose rows are themselves units a reader reads.
          if (depth < 3 && /^(UL|OL|LI|TABLE|TBODY|THEAD|BLOCKQUOTE|DIV|SECTION|ARTICLE|MAIN)$/
                            .test(child.tagName)) {
            walk(child, depth + 1);
          }
        }
      }
      walk(root, 0);
      // The body's top AND bottom edge, in the same absolute space as the breaks above. Both, and
      // that is the whole point of this line: `pc-paged` takes the padding off the body, which is
      // what had been holding the first heading's top margin in — without it that margin collapses
      // out through the body and the body's border box starts some 40 points down the document.
      // Measuring only `.height` then produced a range of [0, height] for content that actually
      // lives at [40, 40 + height]: a first page that opened with a band of white and a last page
      // with its final two lines cut off, in every document that starts with a heading. Neither is
      // visible in a page-one screenshot, and the second one is not visible at all.
      var rect = document.body.getBoundingClientRect();
      var top = Math.max(0, Math.floor(rect.top + window.scrollY));
      var bottom = Math.ceil(Math.max(rect.bottom + window.scrollY,
                                      top + document.body.scrollHeight));
      // How wide the layout actually came out. The view is the width of the text column, so this is
      // the column width unless something refused to fit in it — a table whose columns cannot be
      // squeezed any further, a diagram with a fixed width, a code line with no break in it. Such a
      // box hangs out to the right of the body, where the capture rectangle used to end: the last
      // two columns of an eight-column table were simply absent from the PDF, with nothing said.
      var width = Math.ceil(Math.max(document.body.scrollWidth,
                                     document.documentElement.scrollWidth, rect.width));
      return JSON.stringify({ top: top, bottom: bottom, width: width, breaks: breaks });
    })();
    """

    /// A document of more pages than this is not something this command was asked for, and a runaway
    /// stylesheet that reports a height of a million points must not turn into a million captures.
    private static let pageCap = 500

    private func capture() {
        guard completion != nil else { return }
        view.contentWebView.evaluateJavaScript(Self.measureDocument, in: nil, in: .defaultClient) { [self] result in
            guard let json = (try? result.get()) as? String,
                  let data = json.data(using: .utf8),
                  let measured = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let top = (measured["top"] as? NSNumber)?.doubleValue,
                  let bottom = (measured["bottom"] as? NSNumber)?.doubleValue,
                  bottom > top + 1
            else { report(.couldNotRender); return }
            let breaks = (measured["breaks"] as? [NSNumber] ?? []).map { $0.doubleValue }.sorted()
            // Shrink to fit, the way a browser's own print dialogue does: anything that would not
            // fit the text column is captured at its real width and the whole sheet is scaled, so a
            // wide table costs the document 13% of its type size instead of costing it two columns.
            // `scale` is 1 for every document that fits, which is nearly all of them.
            let printableWidth = paper.size.width - Self.margin * 2
            let printableHeight = paper.size.height - Self.margin * 2
            let measuredWidth = (measured["width"] as? NSNumber)?.doubleValue ?? printableWidth
            let contentWidth = max(printableWidth, measuredWidth)
            scale = printableWidth / contentWidth
            let pages = MarkdownPDF.slices(top: top, bottom: bottom, breaks: breaks,
                                           width: contentWidth,
                                           pageHeight: printableHeight / scale,
                                           limit: Self.pageCap + 1)
            // Refused rather than truncated. Writing the first 500 pages of a longer document and
            // calling it a success is the same defect as the clipped last line above, only bigger:
            // the reader gets a file that looks finished and is not.
            guard pages.count <= Self.pageCap else { report(.tooLong); return }
            render(pages, captured: [])
        }
    }

    /// Capture each slice as its own one-page PDF, in order.
    ///
    /// `createPDF` rather than `NSPrintOperation`: the print path asks WebKit to paginate, and on
    /// this platform it does not come back — measured, in a harness and in the application, writing
    /// a gigabyte of repeated pages before it was killed. `createPDF` renders a rectangle of the
    /// document and returns, which leaves the pagination here, where the page breaks can at least be
    /// put somewhere a reader would put them.
    private func render(_ slices: [CGRect], captured: [Data]) {
        guard completion != nil else { return }
        guard captured.count < slices.count else { compose(captured); return }
        let configuration = WKPDFConfiguration()
        configuration.rect = slices[captured.count]
        view.contentWebView.createPDF(configuration: configuration) { [self] result in
            guard let data = try? result.get() else { report(.couldNotRender); return }
            render(slices, captured: captured + [data])
        }
    }

    /// Lay the captured slices onto real pages, each at the top of its own sheet inside the margin.
    private func compose(_ pages: [Data]) {
        guard !pages.isEmpty else { report(.couldNotRender); return }
        var media = CGRect(origin: .zero, size: paper.size)
        // A folder that cannot be written to is the one failure here that is not about rendering,
        // and it is the likeliest: a document on a read-only volume, or in a folder the reader does
        // not own. Reported as itself, so nobody goes looking at the engine settings for it.
        guard let context = CGContext(destination as CFURL, mediaBox: &media, nil) else {
            report(.couldNotWrite); return
        }
        for data in pages {
            guard let provider = CGDataProvider(data: data as CFData),
                  let document = CGPDFDocument(provider), let page = document.page(at: 1) else { continue }
            let box = page.getBoxRect(.mediaBox)
            context.beginPDFPage(nil)
            // Paper, edge to edge. The captured slice brings the document's own white with it, but
            // only where the document is — the margin band around it stayed transparent, so the
            // sheet was white in the middle and see-through at the edges. Invisible in Preview,
            // which draws its own white behind a page, and visible the moment the PDF is placed on
            // anything else.
            context.saveGState()
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(media)
            context.restoreGState()
            context.saveGState()
            // PDF space has its origin at the bottom left, and a slice shorter than a full page
            // belongs at the TOP of the sheet — not floating in the middle of it. The height it
            // occupies there is its own height AFTER the shrink-to-fit scale.
            context.translateBy(x: Self.margin, y: media.height - Self.margin - box.height * scale)
            context.scaleBy(x: scale, y: scale)
            context.drawPDFPage(page)
            context.restoreGState()
            context.endPDFPage()
        }
        context.closePDF()
        report(FileManager.default.fileExists(atPath: destination.path) ? nil : .couldNotWrite)
    }

    /// Answer once, then let go of the window. Idempotent: a watchdog and a real answer can race.
    private func report(_ failure: MarkdownPDF.Failure?) {
        guard let done = completion else { return }
        completion = nil
        watchdog?.cancel()
        watchdog = nil
        view.contentWebView.navigationDelegate = nil
        window.orderOut(nil)
        window.contentView = nil
        done(failure)
    }
}
