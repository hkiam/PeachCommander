// SPDX-License-Identifier: Apache-2.0
// ListerWindow.swift - File viewer (Lister, F3) — SPEC-005.
//
// Text and Hex modes use custom virtual-scrolling views backed by a FileSlice
// (mmap), so even very large files open instantly (hex scrolls any size; text
// indexes a bounded prefix). Image mode uses NSImageView.

import AppKit
import AVKit
import WebKit
import PCVFS
import PCFoundation
import PCPluginHost
import UniformTypeIdentifiers

@MainActor
final class ListerWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate,
                                    NSUserInterfaceValidations {
    /// No `web` case: Markdown and HTML left the application. Both are rendered by the Markdown
    /// lister plugin now, which reaches this window as `.plugin` like any other format plugin — see
    /// the file header.
    enum Mode { case text, hex, image, media, plugin, directory, code, xmlTree, binary }

    /// Audio/video player for `.media` mode (paused/cleared when the view changes).
    private var avPlayer: AVPlayer?

    /// File extensions the rendered (web) mode understands.
    private static let rtfExts: Set<String> = ["rtf", "rtfd"]

    private var files: [String]
    private var index: Int
    private var mode: Mode = .text
    private var slice: FileSlice?
    private var lastNeedle: [UInt8] = []
    /// The compiled pattern when the last search was a regular expression, else nil.
    ///
    /// Kept beside `lastNeedle` rather than replacing it: F3 repeats whichever kind of search was
    /// started, and the byte needle is still what the plain path and the hex mode use.
    private var lastRegex: NSRegularExpression?
    private var searchOffset: Int64 = 0
    /// Offset of the last match found (for backward search from before it).
    private var lastMatchOffset: Int64 = 0
    /// Case-insensitive byte search toggle (F-113); set from the Find dialog.
    private var searchCaseInsensitive = true
    private var searchDialog: InputDialog?
    /// Docked marks panel (bottom of the window) + its split with the content.
    private lazy var marks = DocumentMarksPanel(content: scrollView, host: self)
    /// Representation picker in the toolbar (Auto/Text/Code/Hex/Image/Rendered).
    private let reprPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    /// Retains the mark dialog while it runs modally.
    private var markDialog: MarkColorDialog?
    /// The current content view when it supports occurrence marking.
    private var markable: ViewerMarkable? { contentView as? ViewerMarkable }
    /// Files up to this size use a read-only NSTextView for text/code (native find
    /// bar, selection, marks); larger files fall back to the virtual custom views.
    private let textViewSizeLimit: Int64 = 4 * 1024 * 1024
    /// Copying the *whole* file to the clipboard stops here — the same 20 MB the rest of the app uses
    /// for exported text. A selection is never refused, however large the file it came from.
    private static let copyAllLimit: Int64 = 20 * 1024 * 1024
    /// Above this size a code file is streamed as plain text rather than
    /// syntax-highlighted in one materialized pass (F-112).
    private static let highlightSizeLimit: Int64 = 16 * 1024 * 1024
    /// Marks controller when the current text/code content is an NSTextView.
    private var textMarks: TextMarkController?
    /// The current content view when it is the read-only NSTextView.
    private var textContentView: NSTextView? { contentView as? NSTextView }

    /// Build a read-only, syntax-highlighted NSTextView for text/code content.
    private func makeTextContent(_ text: String, ext: String, language: SyntaxLanguage?) -> ViewerTextView {
        let tv = ViewerTextView()
        tv.isEditable = false
        tv.isRichText = false
        tv.font = NSFont.monospacedSystemFont(ofSize: viewerFontSize, weight: .regular)
        tv.backgroundColor = Theme.current.listBackground
        tv.textColor = Theme.current.listText
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.delegate = self   // for bracket-match highlighting on selection change
        tv.onCommandClick = { [weak self] idx in self?.goToDefinition(at: idx) }
        applyWrap(to: tv)    // F-114: honor the wrap/no-wrap toggle
        tv.string = text
        if let storage = tv.textStorage {
            if !TreeSitterHighlighter.apply(text, ext: ext, to: storage) {
                SyntaxHighlightApplier.apply(text, language: language, to: storage)
            }
        }
        return tv
    }
    /// Build a read-only rich-text NSTextView for RTF/RTFD documents (F-116),
    /// preserving their own fonts/colors on a document-white background.
    private func makeRichTextContent(path: String) -> ViewerTextView {
        let width = max(200, scrollView.contentSize.width)
        let tv = ViewerTextView(frame: NSRect(x: 0, y: 0, width: width, height: 100))
        tv.isEditable = false
        tv.isRichText = true
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.drawsBackground = true
        tv.backgroundColor = .white   // RTF assumes white "paper"; keeps embedded colors readable
        tv.autoresizingMask = [.width]
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        if let s = try? NSAttributedString(url: URL(fileURLWithPath: path), options: [:], documentAttributes: nil),
           let storage = tv.textStorage, s.length > 0 {
            storage.setAttributedString(s)
        } else {
            tv.string = String(localized: "Could not read the rich-text document.")
        }
        return tv
    }

    /// Viewer text state (F-114): word-wrap toggle + adjustable font size.
    private var wrapText = false
    private var viewerFontSize: CGFloat = 12
    /// Configurable hex line width / binary columns (F-111), cycled with +/-.
    private var hexBytesPerRow = 16
    private var binaryColumns = 64
    private static let hexWidths = [8, 16, 32]
    private static let binaryWidths = [32, 64, 128]
    private static func cycle(_ current: Int, in values: [Int], up: Bool) -> Int {
        let i = values.firstIndex(of: current) ?? 0
        let next = up ? i + 1 : i - 1
        return values[max(0, min(values.count - 1, next))]
    }

    /// Configure a text view for the current wrap mode: wrapping tracks the scroll
    /// view width; no-wrap uses an unbounded container with a horizontal scroller.
    private func applyWrap(to tv: NSTextView) {
        if wrapText {
            let w = max(50, scrollView.contentSize.width)
            tv.isHorizontallyResizable = false
            tv.textContainer?.widthTracksTextView = true
            tv.textContainer?.containerSize = NSSize(width: w, height: .greatestFiniteMagnitude)
            tv.maxSize = NSSize(width: w, height: .greatestFiniteMagnitude)
            tv.frame.size.width = w
        } else {
            tv.isHorizontallyResizable = true
            tv.textContainer?.widthTracksTextView = false
            tv.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
    }

    /// Explicit text-encoding override (nil = auto-detect).
    private var textEncoding: TextEncodingChoice?
    /// True when the text view is showing pretty-printed JSON/XML.
    private var isFormatted = false
    /// The text on screen when it is *not* the file: what the Format button produced, or an XPath
    /// result list.
    ///
    /// Search has to run over this rather than over the file. It used to run over the file either
    /// way, which was harmless while a hit was only scrolled to and approximately placed — and
    /// stopped being harmless the moment hits started being selected: the offsets point into bytes
    /// the reader is no longer looking at, so the highlight landed somewhere arbitrary, and a term
    /// the formatter introduced (or removed) was reported found (or not) against the wrong text.
    ///
    /// Held as a `String` because that is what the formatter handed over — storing it is a retain
    /// rather than a copy. The UTF-8 bytes the views index by are made once, on the first search.
    private var displayedText: String?
    private var displayedBytesCache: [UInt8]?
    /// Which formatter produced the current output, shown in the status line. Worth
    /// surfacing because the winning formatter depends on what is installed and
    /// configured — otherwise "formatted" would look inconsistent between machines.
    private var formatterUsed: String?
    /// Parsed XML tree + its outline data source, for the collapsible tree mode.
    private var xmlRoot: XMLTreeNode?
    private var xmlOutline: XMLOutlineController?
    /// 1-based source line → the anchor the *plugin* gave that heading, from `ListGetOutline`.
    ///
    /// The sidebar knows a heading by its line and the page can only be scrolled to an element, so
    /// something has to hold the mapping between them. It used to be built here, from this window's
    /// own Markdown renderer; now the plugin that rendered the page is the one that knows, and this
    /// is where its answer is kept for the next click.
    private var pluginOutlineAnchors: [Int: String] = [:]

    private let statusLabel = NSTextField(labelWithString: "")
    #if DEBUG
    /// Diagnostic: the status line plus the strings the window is showing (F-372 follow-up).
    ///
    /// Reading the *rendered* labels, because the interesting failure here was a crash — and a crash
    /// leaves no report at all, which is exactly how it announced itself.
    func automationSummary() -> String {
        var lines = ["status=\(statusLabel.stringValue)"]
        func walk(_ view: NSView) {
            // Hidden subtrees are skipped: a dump that lists a label nobody can see cannot be used to
            // check what is on screen. The marks panel keeps its "no marks" placeholder in the tree and
            // merely hides it, so without this the dump said both "Notes (1)" and "No marks".
            guard !view.isHidden else { return }
            if let field = view as? NSTextField, !field.stringValue.isEmpty {
                lines.append("label=\(field.stringValue.replacingOccurrences(of: "\n", with: " ⏎ ").prefix(200))")
            } else if let text = view as? NSTextView, !text.string.isEmpty {
                lines.append("text=\(text.string.replacingOccurrences(of: "\n", with: " ⏎ ").prefix(200))")
            }
            for sub in view.subviews { walk(sub) }
        }
        if let root = window?.contentView { walk(root) }
        if let addressable = contentView as? ListerLineAddressable {
            lines.append("lines=\(addressable.lineCount)")
        }
        // The symbol sidebar as the reader meets it: whether the toggle can be pressed at all, and what
        // the outline holds. A blank sidebar and a dead button look identical in a screenshot, and it was
        // the dead button that got reported for Swift (F-405).
        lines.append("symboltoggle=\(symbolToggle.isEnabled ? "enabled" : "disabled")")
        // The strings panel is offered in hex and nowhere else (F-489), and a disabled toggle
        // beside an empty panel looks the same in a screenshot as a scan that found nothing.
        lines.append("stringstoggle=\(stringsToggle.isEnabled ? "enabled" : "disabled")")
        lines.append("stringsvisible=\(stringsVisible)")
        for row in symbolSidebar.renderedCellStrings() { lines.append("symbolrow=\(row)") }
        // The marks panel's model, not its pixels: the notes group (F-379) is built from a plugin field,
        // and walking the view tree would only see it when the panel happens to be open and tall enough.
        for group in marksPanelGroups() {
            lines.append("marksgroup=\(group.term) count=\(group.occurrences.count)")
            for occurrence in group.occurrences {
                lines.append("  mark line=\(occurrence.line) text=\(occurrence.text.prefix(80))")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Open the docked marks panel, so a dump reads what is on screen and not only what is in the model.
    func automationShowMarks() { marks.show() }

    /// Automation: the menus this window *offers*, whatever has the keyboard.
    ///
    /// `menudump` reads `NSApp.mainMenu`, which a document window only reaches by becoming key — and
    /// in a scripted run it never does, so that probe always reported the main window's menus and
    /// could say nothing about this one's. What the window offers is decided by `documentCaps`, and
    /// that is what this reads, so a command whose flag was never set shows up as an item that is
    /// simply not there.
    func automationToolMenuDump() -> String {
        var lines: [String] = []
        for menu in toolMenus() {
            lines.append("# \(menu.title)")
            for item in menu.items {
                if item.isSeparatorItem { lines.append("  ----"); continue }
                // With the modifiers: ⌘G and ⇧⌘G are different keys, and a dump that prints only
                // "g" for both makes a pair of distinct shortcuts look like a collision.
                var key = ""
                if !item.keyEquivalent.isEmpty {
                    let mask = item.keyEquivalentModifierMask
                    key = "  key="
                        + (mask.contains(.control) ? "C+" : "")
                        + (mask.contains(.option) ? "O+" : "")
                        + (mask.contains(.shift) ? "S+" : "")
                        + (mask.contains(.command) ? "W+" : "")
                        + item.keyEquivalent
                }
                lines.append("  \(item.title)\(key)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Automation: Mark All `term`, then step `steps` times, and report where that landed.
    ///
    /// Both halves matter and only the second was new. Reporting the position rather than "it did not
    /// beep" is the point: stepping to the wrong mark and stepping to no mark at all are the same
    /// silence otherwise. The position is the caret in a text view and the topmost visible line in a
    /// virtual one, which is the same stand-in `stepMark` itself uses.
    func automationMarkStep(_ term: String, steps: Int) -> String {
        let marked = backendMarkAll(term, colorIndex: nil)
        for _ in 0..<abs(steps) { stepMark(forwards: steps >= 0) }
        var position = "-"
        if let textView = textContentView {
            let caret = textView.selectedRange()
            position = "\(caret.location)+\(caret.length)"
        } else if let addressable = contentView as? ListerLineAddressable {
            position = "line \(addressable.firstVisibleLine)"
        }
        return "term=\(term)\nmarked=\(marked)\nsteps=\(steps)\nat=\(position)\n"
    }

    /// Automation: run the viewer's own Go To with `expression` answered from the script queue, and
    /// report where it landed (the mirror of the hex editor's `automationGoto`).
    ///
    /// Reports the *selection*, not the scroll position, because that is where this went wrong: in
    /// hex, scrolling to a row of sixteen identical-looking bytes answers "somewhere on this line"
    /// and a probe that checked only the scroll offset would have called it correct.
    func automationGoto(_ expression: String) -> String {
        InputDialog.queueScriptedAnswer(expression)
        promptGoto()
        let selection = (contentView as? HexListerView)?.automationSelectionDescription ?? ""
        return "expr=\(expression)\nmode=\(mode)\n" + selection
            + "answersleft=\(InputDialog.hasScriptedAnswers ? 1 : 0)\n"
    }

    /// Automation: click a column of the hex view and report which byte it selected.
    func automationHexClick(_ kind: String, row: Int, byte index: Int) -> String {
        guard mode == .hex, let hex = contentView as? HexListerView else {
            return "ERROR: not in hex mode (mode=\(mode))\n"
        }
        return hex.automationClickColumn(kind, row: row, byte: index)
    }

    /// Automation: open the strings panel, wait for the scan, and report what it holds (F-489).
    ///
    /// The wait is the point. The scan is off the main thread by design, so a dump taken the
    /// moment the panel opens reports zero findings over a file full of them — which reads as
    /// "the feature does not work" and is the harness measuring itself. `row >= 0` then
    /// activates that row and reports where the hex view actually went, because a list that
    /// is right and a jump that is wrong look identical in the list.
    func automationStrings(selectRow row: Int) async -> String {
        guard mode == .hex else { return "ERROR: not in hex mode (mode=\(mode))\n" }
        setStringsSidebar(visible: true)
        var waited = 0
        while stringsSidebar.isScanning, waited < 200 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            waited += 1
        }
        var out = "scanwaitms=\(waited * 50)\n" + stringsSidebar.automationSummary
        if row >= 0 {
            if let hit = stringsSidebar.automationSelectRow(row) {
                out += "clicked=\(String(format: "%08llx", hit.offset)) \(hit.encoding.rawValue) \(hit.text)\n"
                out += (contentView as? HexListerView)?.automationSelectionDescription ?? "hexselection=none\n"
            } else {
                out += "clicked=none\n"
            }
        }
        return out
    }

    /// Automation: format the current file and then *draw* it, reporting how long each took (F-414).
    ///
    /// Both halves are needed. Formatting is a parse and a view construction; the freeze a reader reports
    /// happens afterwards, while the view draws — so a report that timed only the format would have said
    /// 40 ms about a window that then hung for minutes. `display()` is a synchronous draw of the whole
    /// content view, which is the same work scrolling does one screenful at a time.
    func automationFormatAndDraw() -> String {
        let startFormat = Date()
        formatStructured()
        let formatMs = Int(Date().timeIntervalSince(startFormat) * 1000)
        let view = contentView ?? scrollView.documentView
        view?.frame = NSRect(x: 0, y: 0, width: 1200, height: 800)
        let startDraw = Date()
        view?.display()
        let drawMs = Int(Date().timeIntervalSince(startDraw) * 1000)
        // `display()` draws the visible rect only, which is empty for a window that is not on screen — so
        // the line-building cost is measured directly as well. That is the work scrolling repeats.
        var lineCostMs = -1
        #if DEBUG
        if let code = view as? CodeListerView { lineCostMs = code.automationAttributedLineCost(lines: 30) }
        #endif
        return """
        view=\(view.map { String(describing: type(of: $0)) } ?? "-")
        formatter=\(formatterUsed ?? "-")
        formatted=\(isFormatted ? 1 : 0)
        format_ms=\(formatMs)
        draw_ms=\(drawMs)
        line_build_ms_30=\(lineCostMs)
        line_build=\(Self.lineBuildVerdict(lineCostMs))
        status=\(statusLabel.stringValue)
        """ + "\n"
    }

    /// Automation: pick the outline entry named `name` and report where the content ended up.
    ///
    /// The report is the *position*, not the fact that a method was called: for the rendered
    /// representation the outline used to be unavailable altogether, and once it is available a click
    /// that scrolls nowhere looks exactly like one that works (F-410). For the page this asks the DOM
    /// after the scroll; for a text view it reads the selection back.
    func automationNavigateToSymbol(_ name: String) async -> String {
        guard let sym = symbolSidebar.definition(named: name) else {
            return "symbol=\(name)\nfound=0\n"
        }
        var out = "symbol=\(name)\nfound=1\nline=\(sym.line)\n"
        if mode == .plugin, let web = contentWebView() {
            let anchor = pluginOutlineAnchors[sym.line] ?? ""
            out += "anchor=\(anchor.isEmpty ? "-" : anchor)\n"
            let before = await webScrollY(web)
            out += "scrollYBefore=\(before)\n"
            navigate(to: sym)
            // The scroll is animated/asynchronous in the page; give it a moment before reading back.
            try? await Task.sleep(nanoseconds: 600_000_000)
            let after = await webScrollY(web)
            out += "scrollYAfter=\(after)\n"
            // The verdict, not only the numbers: a gate can match a word, and "the page moved" is the
            // question — a document short enough to need no scrolling would otherwise read as a failure.
            out += "scrolled=\(after != before ? "yes" : "no")\n"
            out += "headingTop=\(await webElementTop(web, anchor: anchor))\n"
        } else {
            navigate(to: sym)
            if let tv = textContentView {
                out += "selection=\(tv.selectedRange().location)\n"
            }
        }
        return out
    }

    /// A word for the line-building cost, so a gate can match it: a substring expectation cannot compare
    /// numbers, and the number itself varies with the machine.
    ///
    /// The threshold is generous on purpose. The measurement it exists for is not a few per cent: building
    /// thirty lines of a real 2 MB JSON Lines log took 193,934 ms with the quadratic mapping and 126 ms
    /// without it, so anything under a couple of seconds means the mapping is still linear (F-414).
    private static func lineBuildVerdict(_ milliseconds: Int) -> String {
        if milliseconds < 0 { return "n/a" }
        return milliseconds < 3_000 ? "fast" : "slow"
    }

    /// The page's vertical scroll offset, or -1 when it cannot be read.
    private func webScrollY(_ web: WKWebView) async -> Int {
        await withCheckedContinuation { continuation in
            web.evaluateJavaScript("Math.round(window.scrollY)") { result, _ in
                continuation.resume(returning: (result as? NSNumber)?.intValue ?? -1)
            }
        }
    }

    /// An element's distance from the top of the viewport, or -9999 when it is not there.
    private func webElementTop(_ web: WKWebView, anchor: String) async -> Int {
        let js = """
        (function() {
          var el = document.getElementById(\(Self.jsString(anchor)));
          return el ? Math.round(el.getBoundingClientRect().top) : -9999;
        })()
        """
        return await withCheckedContinuation { continuation in
            web.evaluateJavaScript(js) { result, _ in
                continuation.resume(returning: (result as? NSNumber)?.intValue ?? -9999)
            }
        }
    }

    /// Diagnostic: run a zoom command through the same selector the menu item sends, and report the
    /// result (F-389).
    ///
    /// `enabled` is the menu's own answer via `validateUserInterfaceItem`, so a scenario can assert that
    /// the item is offered on a picture and withheld on text — the thing a screenshot of a menu shows and
    /// no other dump does. `pixel` is the colour in the middle of the content, because every level and
    /// every rect can be right while nothing is drawn at all; that is not hypothetical — it is what the
    /// quick preview did until the clip view's document view was re-installed.
    func automationZoom(_ which: String) -> String {
        let action: Selector?
        switch which {
        case "in": action = DocumentAction.zoomIn
        case "out": action = DocumentAction.zoomOut
        case "actual": action = DocumentAction.zoomActual
        case "fit": action = DocumentAction.zoomFit
        case "state": action = nil
        default: return "no such zoom command: \(which)\n"
        }
        if let action {
            guard supportsAction(action) else { return "refused=\(which)\n" + automationZoomState() }
            _ = perform(action)
        }
        return automationZoomState()
    }

    private func automationZoomState() -> String {
        let visible = scrollView.documentVisibleRect
        return """
        mode=\(mode)
        level=\(imageZoom.levelText)
        scale=\(String(format: "%.4f", imageZoom.scale))
        fitting=\(imageZoom.isFitting)
        document=\(scrollView.documentView === zoomImageView ? "image" : String(describing: scrollView.documentView.map { type(of: $0) }))
        docFrame=\(Int(zoomImageView.frame.width))x\(Int(zoomImageView.frame.height))
        visible=\(Int(visible.width))x\(Int(visible.height))
        \(ImageZoomController.drawnReport(scrollView: scrollView, image: zoomImageView.image))
        status=\(statusLabel.stringValue)
        menuZoomIn=\(validateUserInterfaceItem(NSMenuItem(title: "", action: DocumentAction.zoomIn, keyEquivalent: "")))
        menuZoomFit=\(validateUserInterfaceItem(NSMenuItem(title: "", action: DocumentAction.zoomFit, keyEquivalent: "")))
        """ + "\n"
    }

    /// Switch the representation, as the 1..6 keys do, and report how long the switch took.
    ///
    /// The timing is the point: "open a binary and switch to text" is a thing a user does and the app
    /// used to stop responding for it, so a scenario has to be able to say how long it took rather
    /// than only that a view appeared.
    /// The class of the view currently showing the content — which representation was actually chosen.
    var automationContentViewKind: String { contentView.map { String(describing: type(of: $0)) } ?? "none" }

    @discardableResult
    func automationSetMode(_ name: String) -> Double {
        let wanted: Mode?
        switch name.lowercased() {
        case "text": wanted = .text
        case "hex": wanted = .hex
        case "binary": wanted = .binary
        case "code": wanted = .code
        case "image": wanted = .image
        default: wanted = nil
        }
        guard let wanted else { return -1 }
        let t0 = DispatchTime.now().uptimeNanoseconds
        setModeManually(wanted)
        return Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
    }

    /// Put the caret at the start of a 1-based line, so a scenario can exercise the *real* "which line
    /// am I on" path rather than a shortcut around it.
    func automationSetCaret(line: Int) {
        guard let tv = textContentView else { return }
        let starts = EditorLineIndex(text: tv.string as NSString).starts
        guard starts.indices.contains(line - 1) else { return }
        tv.setSelectedRange(NSRange(location: starts[line - 1], length: 0))
    }

    /// Ask for a note about the line the caret is on, exactly as the menu item does.
    func automationNoteForCurrentLine() { docNote() }

    /// Diagnostic: the state a seeded search left behind (F-407) — what the viewer's own search holds,
    /// what the find bar shows, and where the first hit put the reader.
    ///
    /// `line` is the 1-based line of the selection, because "jumped to the first hit" is a claim about
    /// where the reader is looking, and a byte offset of 0 is also what an unsearched file reports.
    func automationSearchState() -> String {
        let term = String(bytes: lastNeedle, encoding: .utf8) ?? ""
        let board = NSPasteboard(name: .find).string(forType: .string) ?? ""
        var line = "-"
        var selected = ""
        if let tv = textContentView {
            let sel = tv.selectedRange()
            selected = (tv.string as NSString).substring(with: sel)
            line = String(EditorLineIndex(text: tv.string as NSString).line(containing: sel.location))
        }
        let focus = window?.firstResponder.map { String(describing: type(of: $0)) } ?? "none"
        return "term=\(term)\nfindboard=\(board)\nfindbar=\(scrollView.isFindBarVisible ? "open" : "closed")\n"
            + "selected=\(selected)\nline=\(line)\nbyte=\(lastMatchOffset)\nregex=\(lastRegex != nil)\n"
            + "caseInsensitive=\(searchCaseInsensitive)\nfocus=\(focus)\n"
    }

    /// Reload the file the way the Auto representation button does — the path the seed is applied from,
    /// so a scenario can prove the reader's own term survives it (F-407).
    func automationReloadContent() { loadCurrent(autoMode: true) }

    /// Type into the seeded search, as a reader correcting it would (F-407): the term they leave behind
    /// must be the one that survives, and nothing may put the seeded one back.
    func automationRetypeSearch(_ text: String) {
        lastNeedle = Array(text.utf8)
        lastRegex = nil
        searchOffset = 0
        lastMatchOffset = -1
        findNext()
        if let tv = textContentView {
            let hit = (tv.string as NSString).range(of: text, options: [.caseInsensitive])
            if hit.location != NSNotFound { tv.setSelectedRange(hit); tv.scrollRangeToVisible(hit) }
        }
    }

    /// Diagnostic: move the focus where a click would move it, then press Esc — and report whether the
    /// window closed.
    ///
    /// The key is posted to the window rather than handed to `handleKey`, because the defect was in the
    /// routing and not in the handler: a dispatch that starts at the first responder is the only kind
    /// that can reproduce "Esc works until you click something". `focus` is part of the report for the
    /// same reason — if the click did not move the focus, the check proves nothing.
    func automationEscape(focusing target: String) -> String {
        guard let window else { return "ERROR: no window\n" }
        switch target.lowercased() {
        case "text":   if let tv = textContentView { window.makeFirstResponder(tv) }
        case "filter": setSymbolSidebar(visible: true)   // opening it focuses the filter field
        case "marks":  marks.show(); focusFirstResponderKind("MarksTableView")
        case "findbar":                                  // find bar open, focus back in the text
            vmFind()
            if let tv = textContentView { window.makeFirstResponder(tv) }
        case "filtertext":                               // something typed in the filter, then Esc
            setSymbolSidebar(visible: true)
            // Typed as a key event, not assigned: what Esc has to see is a *field editor* holding text,
            // and setting `stringValue` behind its back is the one arrangement that cannot reproduce it.
            if let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                         timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                         characters: "o", charactersIgnoringModifiers: "o",
                                         isARepeat: false, keyCode: 31) {
                window.sendEvent(key)
            }
        default:       break
        }
        let responder = window.firstResponder
        // A focused NSTextField reports its *field editor*, which is a shared NSTextView and says
        // nothing about which field the reader clicked into — so name the field behind it.
        var focus = responder.map { String(describing: type(of: $0)) } ?? "none"
        if let editor = responder as? NSTextView, editor.isFieldEditor,
           let owner = editor.delegate.map({ String(describing: type(of: $0)) }) {
            focus += "(editing \(owner))"
        }
        // Both the find bar and the filter text are reported from both sides of the key, because each has
        // a local meaning for Esc that the "closed" line alone cannot distinguish from its absence: a
        // `vmFind()` that never opened the bar reads exactly like Esc having dismissed it, and a build
        // that closed the window on a typed-in filter also leaves that filter empty.
        //
        // `editorText` looks at field editors only — a focused content view is an NSTextView too, and
        // reporting the file's first forty characters as "typed" would be a lie in the shape of a fact.
        let barBefore = scrollView.isFindBarVisible
        func editorText() -> String {
            guard let editor = window.firstResponder as? NSTextView, editor.isFieldEditor else { return "" }
            return editor.string
        }
        let typedBefore = editorText()
        let esc = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                   windowNumber: window.windowNumber, context: nil,
                                   characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}",
                                   isARepeat: false, keyCode: 53)
        if let esc { window.sendEvent(esc) }
        func bar(_ open: Bool) -> String { open ? "open" : "closed" }
        return "focus=\(focus)\nfindbar=\(bar(barBefore))→\(bar(scrollView.isFindBarVisible))\n"
            + "typed=[\(typedBefore.prefix(40))]→[\(editorText().prefix(40))]\n"
            + "closed=\(window.isVisible ? "no" : "yes")\n"
    }

    /// Make the first view of the given class (by name) the first responder.
    private func focusFirstResponderKind(_ name: String) {
        guard let root = window?.contentView else { return }
        func walk(_ view: NSView) -> NSView? {
            if String(describing: type(of: view)) == name { return view }
            for sub in view.subviews { if let hit = walk(sub) { return hit } }
            return nil
        }
        if let target = walk(root) { window?.makeFirstResponder(target) }
    }
    #endif
    private let scrollView = NSScrollView()
    private var contentView: NSView?

    // Zooming the image representation (F-389). The same controller the quick preview in the sidebar
    // uses, on the viewer's own scroll view — so 100% means the same thing in both places, and the
    // ladder of stops is one ladder rather than two that drift apart.
    private let zoomImageView = NSImageView()
    private lazy var imageZoom: ImageZoomController = {
        let controller = ImageZoomController(scrollView: scrollView, imageView: zoomImageView)
        // A pinch or ⌘-scroll changes the level without going through a command, and the status line has
        // to follow it or it reports the level from before the gesture.
        controller.onScaleChange = { [weak self] _ in self?.updateStatus() }
        return controller
    }()

    // Collapsible symbol outline sidebar (classes/functions/methods via tree-sitter).
    private let symbolSidebar = SymbolSidebar()
    private var symbolWidth: NSLayoutConstraint!
    private var symbolsVisible = false
    private let symbolToggle = NSButton()

    // Collapsible strings panel — every readable run in the file, in every encoding at once
    // (F-489). Hex only: see `refreshStrings`.
    private let stringsSidebar = StringsSidebar()
    private var stringsWidth: NSLayoutConstraint!
    private var stringsVisible = false
    private let stringsToggle = NSButton()
    private var bracketRanges: [NSRange] = []
    // Collapsible minimap on the right (for text/code content).
    private var minimap: MinimapView!
    private var minimapWidth: NSLayoutConstraint!
    private var minimapVisible = false
    private let minimapToggle = NSButton()
    /// Toolbar action buttons paired with their selector, for per-representation
    /// enablement (see refreshActionEnablement).
    private var actionButtons: [(Selector, NSButton)] = []
    private weak var container: NSView?

    /// Available PLX lister plugins, consulted before the built-in modes.
    private let plugins: [PLXLister]
    /// The currently embedded plugin view, if the active mode is `.plugin`.
    private var pluginView: (lister: PLXLister, handle: PLXHandle, view: NSView)?
    /// Index into the current file's claiming plugins (F-119); reset per file.
    private var pluginChoice = 0
    /// Set when the viewer is showing a directory summary rather than a file.
    private let directoryPath: String?

    /// A search to start this viewer with, from whoever opened it (F-407); consumed once.
    private var pendingSearchSeed: ViewerSearchSeed?

    /// - Parameter searchSeed: the term the file was *found* with, when the viewer is opened from a
    ///   content search (F-407). It becomes this window's own search — prefilled and on its first hit —
    ///   and is then forgotten, so anything the reader types or clears afterwards stands.
    init(files: [String], startIndex: Int, plugins: [PLXLister] = [],
         searchSeed: ViewerSearchSeed? = nil) {
        self.files = files
        self.index = max(0, min(startIndex, files.count - 1))
        self.plugins = plugins
        self.directoryPath = nil
        self.pendingSearchSeed = searchSeed
        let window = NSWindow(contentRect: NSMakeRect(0, 0, 800, 600),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.center()
        super.init(window: window)
        window.delegate = self
        buildChrome()
        loadCurrent(autoMode: true)
    }

    /// Open the viewer on a directory, showing recursive statistics (F3 on a folder).
    init(directoryPath: String) {
        self.files = []
        self.index = 0
        self.plugins = []
        self.directoryPath = directoryPath
        let window = NSWindow(contentRect: NSMakeRect(0, 0, 640, 320),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.center()
        super.init(window: window)
        window.delegate = self
        buildChrome()
        mode = .directory
        window.title = (directoryPath as NSString).lastPathComponent
        loadDirectoryStats(directoryPath)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Reload the viewer to show a single file (used by Quick View cursor-follow).
    func setFile(_ path: String) {
        files = [path]
        index = 0
        searchOffset = 0
        loadCurrent(autoMode: true)
    }

    private func buildChrome() {
        guard let window else { return }
        let container = ListerContainerView()
        container.onKey = { [weak self] event in self?.handleKey(event) ?? false }
        container.onCancel = { [weak self] in self?.window?.close() }
        window.contentView = container
        self.container = container

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder

        // Content (top) + marks panel (bottom) share a draggable horizontal split.
        marks.onClearAll = { [weak self] in self?.backendClearAll(); self?.marks.reload() }
        let splitView = marks.splitView

        let toolbar = buildToolbar()

        let statusBar = NSView()
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        statusBar.wantsLayer = true
        statusBar.layer?.backgroundColor = Theme.current.statusBarBackground.cgColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = Fonts.monospacedDigit13
        statusLabel.textColor = Theme.current.statusBarText
        statusBar.addSubview(statusLabel)

        let sidebar = buildSymbolSidebar()
        let strings = buildStringsSidebar()

        minimap = MinimapView(textView: nil, scrollView: scrollView)
        minimap.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(toolbar)
        container.addSubview(sidebar)
        container.addSubview(splitView)
        container.addSubview(strings)
        container.addSubview(minimap)
        container.addSubview(statusBar)
        symbolWidth = sidebar.widthAnchor.constraint(equalToConstant: 0)   // start collapsed
        stringsWidth = strings.widthAnchor.constraint(equalToConstant: 0)  // start collapsed
        minimapWidth = minimap.widthAnchor.constraint(equalToConstant: 0)  // start collapsed
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: container.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 40),
            sidebar.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            sidebar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sidebar.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            symbolWidth,
            splitView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            splitView.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            splitView.trailingAnchor.constraint(equalTo: strings.leadingAnchor),
            splitView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            strings.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            strings.trailingAnchor.constraint(equalTo: minimap.leadingAnchor),
            strings.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            stringsWidth,
            minimap.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            minimap.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            minimap.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            minimapWidth,
            statusBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 22),
            statusLabel.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor, constant: 8),
            statusLabel.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor)
        ])
        container.menu = DocumentMenus.contextMenu(caps: documentCaps, target: self)
        window.makeFirstResponder(container)
    }

    /// The viewer's top button bar (mirrors the editor's chrome for a unified
    /// look & feel): a representation popup plus the common actions.
    private func buildToolbar() -> NSView {
        let bar = NSStackView()
        bar.orientation = .horizontal
        bar.spacing = 8
        bar.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        bar.translatesAutoresizingMaskIntoConstraints = false

        // No "Rendered" item: what renders a document is a plugin, and refreshPluginReprItems adds
        // each claiming plugin *by name* — which says more than "Rendered" and is the only form that
        // works when two plugins want the same file (F-119). The Document menu still offers
        // "Rendered", because a menu has no room for a per-file list.
        for (title, tag) in [(String(localized: "Auto"), 0), ("Text", 1), ("Code", 2),
                             ("Hex", 3), ("Image", 4)] {
            reprPopup.addItem(withTitle: title); reprPopup.lastItem?.tag = tag
        }
        reprPopup.target = self
        reprPopup.action = #selector(toolbarReprChanged(_:))

        // Registered so refreshActionEnablement() can re-validate them per
        // representation; NSButton does not participate in AppKit's own validation.
        func button(_ title: String, _ selector: Selector) -> NSButton {
            let b = NSButton(title: title, target: self, action: selector)
            b.bezelStyle = .rounded
            actionButtons.append((selector, b))
            return b
        }
        // Symbol-outline sidebar toggle (leading). Disabled until a file yields symbols.
        symbolToggle.bezelStyle = .rounded
        symbolToggle.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: String(localized: "Symbols"))
        symbolToggle.imagePosition = .imageLeading
        symbolToggle.title = String(localized: "Symbols")
        symbolToggle.setButtonType(.pushOnPushOff)
        symbolToggle.target = self
        symbolToggle.action = #selector(toggleSymbols)
        symbolToggle.isEnabled = false
        symbolToggle.toolTip = String(localized: "Show/hide the symbol outline")
        bar.addArrangedSubview(symbolToggle)

        // Strings panel toggle. Disabled outside the hex representation, where the question
        // it answers does not arise — in text mode the text is the strings.
        stringsToggle.bezelStyle = .rounded
        stringsToggle.image = NSImage(systemSymbolName: "text.magnifyingglass",
                                      accessibilityDescription: String(localized: "Strings"))
        stringsToggle.imagePosition = .imageLeading
        stringsToggle.title = String(localized: "Strings")
        stringsToggle.setButtonType(.pushOnPushOff)
        stringsToggle.target = self
        stringsToggle.action = #selector(toggleStrings)
        stringsToggle.isEnabled = false
        stringsToggle.toolTip = String(localized: "Show/hide the readable strings in this file")
        bar.addArrangedSubview(stringsToggle)

        bar.addArrangedSubview(NSTextField(labelWithString: String(localized: "View:")))
        bar.addArrangedSubview(reprPopup)
        bar.addArrangedSubview(button(String(localized: "Find"), DocumentAction.find))
        bar.addArrangedSubview(button(String(localized: "Format"), DocumentAction.format))
        bar.addArrangedSubview(button(String(localized: "Encoding"), DocumentAction.cycleEncoding))
        bar.addArrangedSubview(button(String(localized: "Mark All"), DocumentAction.markAll))
        bar.addArrangedSubview(button(String(localized: "Marks"), DocumentAction.toggleMarksPanel))
        bar.addArrangedSubview(button(String(localized: "Save As…"), DocumentAction.saveAs))   // F-121
        bar.addArrangedSubview(button(String(localized: "Print…"), DocumentAction.print))

        minimapToggle.bezelStyle = .rounded
        minimapToggle.image = NSImage(systemSymbolName: "map", accessibilityDescription: String(localized: "Minimap"))
        minimapToggle.imagePosition = .imageOnly
        minimapToggle.setButtonType(.pushOnPushOff)
        minimapToggle.target = self
        minimapToggle.action = #selector(toggleMinimap)
        minimapToggle.isEnabled = false
        minimapToggle.toolTip = String(localized: "Show/hide the minimap")
        bar.addArrangedSubview(minimapToggle)
        return bar
    }

    // MARK: - Minimap

    @objc private func toggleMinimap() { setMinimap(visible: !minimapVisible) }

    private func setMinimap(visible: Bool) {
        minimapVisible = visible
        minimapWidth.animator().constant = visible ? 78 : 0
        minimapToggle.state = visible ? .on : .off
        if visible { minimap.refresh() }
    }

    /// Rebind the minimap to the current text content (or blank it for non-text modes).
    private func refreshMinimap() {
        let tv = (mode == .code || mode == .text) ? textContentView : nil
        minimapToggle.isEnabled = tv != nil
        minimap.bind(textView: tv)
        if tv == nil, minimapVisible { setMinimap(visible: false) }
    }

    // MARK: - Strings panel (F-489)

    private func buildStringsSidebar() -> NSView {
        stringsSidebar.translatesAutoresizingMaskIntoConstraints = false
        stringsSidebar.onSelect = { [weak self] hit in
            guard let self, let hex = self.contentView as? HexListerView else { return }
            hex.select(byteRange: hit.range)
            self.updateStatus()
        }
        return stringsSidebar
    }

    @objc private func toggleStrings() { setStringsSidebar(visible: !stringsVisible) }

    private func setStringsSidebar(visible: Bool) {
        stringsVisible = visible
        stringsWidth.animator().constant = visible ? 340 : 0
        stringsToggle.state = visible ? .on : .off
        if visible, let file = currentFile {
            // Scanning is what costs; do it when the panel is first opened rather than for
            // every hex file somebody glances at.
            stringsSidebar.load(.file(file))
            stringsSidebar.focusFilter()
        } else {
            stringsSidebar.clear()
        }
        KeyboardLoop.rebuild(for: window)
    }

    /// Offer the panel in hex and nowhere else, and close it when the representation moves on.
    private func refreshStrings() {
        let available = (mode == .hex)
        stringsToggle.isEnabled = available
        if !available, stringsVisible {
            setStringsSidebar(visible: false)
        } else if available, stringsVisible, let file = currentFile {
            stringsSidebar.load(.file(file))     // a different file, or a re-render
        }
    }

    /// The file on screen, or nil while the window has none.
    private var currentFile: String? { files.indices.contains(index) ? files[index] : nil }

    // MARK: - Symbol outline sidebar

    private func buildSymbolSidebar() -> NSView {
        symbolSidebar.translatesAutoresizingMaskIntoConstraints = false
        symbolSidebar.onSelect = { [weak self] sym in self?.navigate(to: sym) }
        symbolSidebar.onAvailabilityChanged = { [weak self] has in
            guard let self else { return }
            self.symbolToggle.isEnabled = has
            if !has, self.symbolsVisible { self.setSymbolSidebar(visible: false) }
            self.updateBreadcrumb()
        }
        return symbolSidebar
    }

    /// Text of the current content view (bounded), for symbol extraction.
    /// Recompute the outline for the current file (background parse via SymbolSidebar).
    ///
    /// Only from the text view, which already holds the document. The other representation is the
    /// *virtual* view, used for files above 4 MiB and for binary content — and asking it for its text
    /// reads and decodes the whole file. `SymbolSidebar.load` then refuses it anyway, above four
    /// million characters or for an extension it has no grammar for, so every byte of that work was
    /// thrown away: measured, opening a 187 MB file cost 295 MB of resident memory in a view whose
    /// entire purpose is that the file need not fit in memory (F-112). The bound existed; it was
    /// applied one call too late.
    private func refreshSymbols() {
        let ext = files.indices.contains(index) ? (files[index] as NSString).pathExtension.lowercased() : ""
        if mode == .code || mode == .text, let tv = textContentView {
            symbolSidebar.load(text: tv.string, ext: ext)
        } else if mode == .plugin, let pv = pluginView {
            // A plugin-rendered page has no text view, and two ways to have an outline anyway. Its own
            // is preferred: a plugin knows the structure of the format it renders, and that is what
            // lets a format the host has never heard of have a sidebar at all. Failing that, the text
            // it hands over is outlined here — which keeps the promise F-410 made for a rendered
            // Markdown document, now that the rendering happens somewhere else.
            let rows = pv.lister.outline(of: pv.handle)
            pluginOutlineAnchors = Dictionary(rows.map { ($0.line, $0.anchor) },
                                              uniquingKeysWith: { first, _ in first })
            if !rows.isEmpty {
                symbolSidebar.load(rows: rows)
            } else if let text = pv.lister.text(of: pv.handle), !text.isEmpty {
                symbolSidebar.load(text: text, ext: ext)
            } else {
                symbolSidebar.clear()
            }
        } else {
            symbolSidebar.clear()
        }
    }

    @objc private func toggleSymbols() { setSymbolSidebar(visible: !symbolsVisible) }

    private func setSymbolSidebar(visible: Bool) {
        symbolsVisible = visible
        symbolWidth.animator().constant = visible ? 220 : 0
        symbolToggle.state = visible ? .on : .off
        if visible { symbolSidebar.focusFilter() }
    }

    // MARK: - Bracket matching (read-only text/code)

    func textViewDidChangeSelection(_ notification: Notification) {
        updateBracketHighlight()
        updateBreadcrumb()
    }

    private var symbolPathText = ""
    private func updateBreadcrumb() {
        let path = textContentView.map { symbolSidebar.enclosingPath(utf16: $0.selectedRange().location) } ?? []
        let text = path.map(\.name).joined(separator: " › ")
        if text != symbolPathText { symbolPathText = text; updateStatus() }
    }

    /// Above this many characters the caret no longer highlights matching brackets.
    ///
    /// Not a taste decision: reading `NSTextView.layoutManager` lays the *whole* document out, and for
    /// a document of this size that is seconds, on every single click. Bracket matching is a nicety;
    /// a viewer that stops responding is not. Measured at 2.0 s for a 931k-character document.
    private static let bracketMatchSizeLimit = 200_000

    private func updateBracketHighlight() {
        guard let tv = textContentView else { return }
        // The length *before* touching the layout manager, or the guard costs what it is guarding
        // against. `textStorage?.length` is the character count without laying anything out.
        guard (tv.textStorage?.length ?? 0) <= Self.bracketMatchSizeLimit else { return }
        guard let lm = tv.layoutManager else { return }
        for r in bracketRanges { lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: r) }
        bracketRanges = []
        let sel = tv.selectedRange()
        guard sel.length == 0 else { return }
        let ns = tv.string as NSString
        guard let m = BracketMatcher.match(in: ns, caret: sel.location) else { return }
        let color = NSColor.systemGray.withAlphaComponent(0.4)
        for r in [m.bracket, m.partner] {
            lm.addTemporaryAttributes([.backgroundColor: color], forCharacterRange: r)
            bracketRanges.append(r)
        }
    }

    /// Cmd+click: jump to the definition of the identifier under the click.
    private func goToDefinition(at index: Int) {
        guard let tv = textContentView else { return }
        let ns = tv.string as NSString
        guard let word = IdentifierScanner.word(in: ns, at: index),
              let sym = symbolSidebar.definition(named: word) else { NSSound.beep(); return }
        navigate(to: sym)
    }

    /// Jump the content view to a symbol's definition.
    private func navigate(to sym: SymbolNode) {
        // A plugin-rendered page: the plugin knows where its own anchors are, and the host asks it to
        // scroll rather than reaching into a view it did not build. `ListGotoAnchor` is optional, so a
        // plugin without it simply keeps the outline and loses the jump.
        if mode == .plugin, let pv = pluginView, let anchor = pluginOutlineAnchors[sym.line],
           pv.lister.gotoAnchor(anchor, in: pv.handle) {
            return
        }
        if let tv = textContentView {
            let ns = tv.string as NSString
            let loc = max(0, min(sym.utf16Location, ns.length))
            let len = max(0, min(sym.name.utf16.count, ns.length - loc))
            let range = NSRange(location: loc, length: len)
            tv.setSelectedRange(range)
            tv.scrollRangeToVisible(range)
        } else {
            (contentView as? CodeListerView)?.scroll(toLine: sym.line)
            (contentView as? TextListerView)?.scroll(toLine: sym.line)
        }
    }

    /// Scroll the rendered page to a heading's anchor.
    ///
    /// Through `evaluateJavaScript`, which the host may run even though the page itself may not:
    /// `allowsContentJavaScript` is off and the document's CSP is `default-src 'none'`, so a script
    /// *inside* a Markdown file still cannot run — the two protections that matter here are untouched.
    /// The scroll is reported back so a failure shows up in the log rather than as a click that does
    /// nothing.
    private func scrollWeb(to anchor: String, web: WKWebView) {
        let js = """
        (function() {
          var el = document.getElementById(\(Self.jsString(anchor)));
          if (!el) { return "missing"; }
          el.scrollIntoView(true);
          return "ok";
        })()
        """
        web.evaluateJavaScript(js) { result, error in
            if let error {
                PCFoundationLogger.logger.error("viewer: scrolling to \(anchor, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            } else if let outcome = result as? String, outcome != "ok" {
                PCFoundationLogger.logger.error("viewer: no element for anchor \(anchor, privacy: .public)")
            }
        }
    }

    /// The `WKWebView` inside the current content view, if there is one.
    ///
    /// A plugin returns a plain `NSView` and puts whatever it likes inside it, so "is this a rendered
    /// page" cannot be asked by casting. Walking the subtree is what lets the two automation verbs
    /// that need pixels or a scroll position — `listershot`, `listersymbol` — keep working for a
    /// format the application no longer renders itself, without this window knowing anything about a
    /// particular plugin.
    private func contentWebView() -> WKWebView? {
        func find(_ view: NSView) -> WKWebView? {
            if let web = view as? WKWebView { return web }
            for sub in view.subviews { if let web = find(sub) { return web } }
            return nil
        }
        return contentView.flatMap(find)
    }

    /// A Swift string as a JavaScript string literal.
    private static func jsString(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
                       .replacingOccurrences(of: "\"", with: "\\\"")
                       .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    @objc private func toolbarReprChanged(_ sender: NSPopUpButton) {
        let tag = sender.selectedTag()
        if tag >= 100 {                        // a specific plugin (F-119)
            pluginChoice = tag - 100
            setModeManually(.plugin)
            return
        }
        switch tag {
        case 1: vmText(); case 2: vmCode(); case 3: vmHex()
        case 4: vmImage(); default: vmAuto()
        }
    }

    /// Rebuild the View popup's per-plugin items (tag 100+n) for the current file,
    /// so all claiming plugins are selectable, not just the first (F-119).
    private func refreshPluginReprItems(path: String) {
        for item in reprPopup.itemArray where item.tag >= 100 { reprPopup.removeItem(withTitle: item.title) }
        let matches = matchingPlugins(path: path, slice: slice)
        guard matches.count > 0 else { return }
        for (i, plugin) in matches.enumerated() {
            let title = plugin.name.isEmpty ? String(localized: "Plugin \(i + 1)") : plugin.name
            reprPopup.addItem(withTitle: title)
            reprPopup.lastItem?.tag = 100 + i
        }
    }

    // MARK: - Loading

    private func loadCurrent(autoMode: Bool) {
        guard files.indices.contains(index) else { return }
        let path = files[index]
        slice = FileSlice(path: path)
        window?.title = (path as NSString).lastPathComponent
        pluginChoice = 0                       // new file → default to the first claimant (F-119)
        refreshPluginReprItems(path: path)     // list this file's plugins in the View popup
        if autoMode {
            textEncoding = nil   // re-auto-detect encoding for the new file
            // A claiming plugin wins over the built-in auto-detection.
            if pluginClaiming(path: path, slice: slice) != nil {
                mode = .plugin
            } else {
                mode = Self.autoMode(for: path, slice: slice)
                // Promote plain text to syntax-highlighted code when the extension
                // maps to a known language.
                let ext = (path as NSString).pathExtension.lowercased()
                if mode == .text, SyntaxHighlighter.language(forExtension: ext) != nil { mode = .code }
            }
        }
        rebuildContent()
        applyPendingSearchSeed()
    }

    /// All plugins whose detect string claims this file, in order (F-119).
    private func matchingPlugins(path: String, slice: FileSlice?) -> [PLXLister] {
        guard !plugins.isEmpty else { return [] }
        let ext = (path as NSString).pathExtension
        let head = slice?.bytes(at: 0, length: 4096) ?? []
        let ctx = DetectContext(ext: ext, size: slice?.count ?? 0, bytes: head)
        return plugins.filter { $0.handles(ctx) }
    }

    /// The plugin used to render `.plugin` mode: the user's chosen one among the
    /// claimants (F-119), else the first. Nil if none claim the file.
    private func pluginClaiming(path: String, slice: FileSlice?) -> PLXLister? {
        let matches = matchingPlugins(path: path, slice: slice)
        guard !matches.isEmpty else { return nil }
        return matches[min(pluginChoice, matches.count - 1)]
    }

    /// Is this file's content binary, so that it must not go into an NSTextView?
    ///
    /// The rule, the measurements behind it and why two questions are asked rather than one live in
    /// PCVFS.TextContentKind, where they can be checked without a window.
    private func hasBinaryContent(_ slice: FileSlice) -> Bool {
        decodedTextAndFidelity(slice).needsVirtualView
    }

    private static func autoMode(for path: String, slice: FileSlice?) -> Mode {
        let ext = (path as NSString).pathExtension.lowercased()
        // Markdown and HTML used to be named here and sent to a web view this window owned. They are
        // a plugin's business now, and a plugin that claims a file wins over this function anyway
        // (see loadCurrent) — so with the plugin installed they never reach it, and without it they
        // fall through to the sniff below and come up as text, which is a readable answer and not a
        // blank one.
        if !ext.isEmpty, let type = UTType(filenameExtension: ext), type.conforms(to: .image) {
            return .image
        }
        // Audio/video → AVKit player (F-117).
        if !ext.isEmpty, let type = UTType(filenameExtension: ext), type.conforms(to: .audiovisualContent) {
            return .media
        }
        // Sniff first 4 KB: mostly-text → text, else hex.
        guard let slice else { return .hex }
        let sample = slice.bytes(at: 0, length: 4096)
        if sample.isEmpty { return .text }
        return BinaryHeuristic.isProbablyBinary(sample) ? .hex : .text
    }

    private func rebuildContent() {
        guard let slice else { return }
        let path = files[index]

        // Recompute the symbol outline + minimap once the new content view is in
        // place (populate for code/text, clear for other modes), and re-validate the
        // toolbar: most actions only apply to some representations.
        defer { refreshSymbols(); refreshMinimap(); refreshStrings()
                refreshActionEnablement(); refreshAnnotations() }

        // The content view (and its marks) is about to be replaced — collapse
        // the marks panel so it doesn't show stale entries for the old view.
        marks.hide()

        // Always drop any previously embedded plugin view / media player before
        // re-rendering (a still-playing AVPlayer would keep sounding otherwise).
        teardownPlugin()
        teardownMedia()
        isFormatted = false
        formatterUsed = nil
        displayedText = nil
        displayedBytesCache = nil

        if mode == .plugin {
            if embedPlugin(for: path, slice: slice) {
                scrollView.isHidden = true
                updateStatus()
                refreshSymbols()
                return
            }
            // No plugin claimed it (or it declined) → fall back to a built-in mode.
            mode = Self.autoMode(for: path, slice: slice)
        }

        scrollView.isHidden = false
        scrollView.allowsMagnification = false   // enabled only for image mode (F-115)
        // Leaving the image behind: let go of the bitmap and stop centring the document, or a text file
        // with two lines in it would come up centred in the middle of the window (F-389).
        if mode != .image, zoomImageView.image != nil {
            imageZoom.clear()
        }
        let view: NSView
        textMarks = nil   // reset; set below only for the NSTextView text/code path
        switch mode {
        case .text:
            if Self.rtfExts.contains((path as NSString).pathExtension.lowercased()) {
                // RTF/RTFD: render the rich document (F-116).
                let tv = makeRichTextContent(path: path)
                textMarks = TextMarkController(textView: tv)
                view = tv
            } else if slice.count <= textViewSizeLimit, !hasBinaryContent(slice) {
                let tv = makeTextContent(decodedText(slice), ext: (path as NSString).pathExtension, language: nil)
                textMarks = TextMarkController(textView: tv)
                view = tv
            } else {
                // Binary content, or simply a large file: the virtual view, which indexes line starts
                // and draws only what is on screen (F-112). An NSTextView cannot be used here — see
                // `hasBinaryContent`.
                view = TextListerView(slice: slice, encoding: textEncoding?.encoding)
            }
            scrollView.documentView = view
        case .hex:
            view = HexListerView(slice: slice, bytesPerRow: hexBytesPerRow)
            scrollView.documentView = view
        case .binary:
            // Fixed-width raw-byte view (F-111): every byte as a Latin-1 glyph,
            // non-printables as '.', a newline every N columns. No highlighting.
            let tv = makeTextContent(Self.binaryString(slice, columns: binaryColumns), ext: "", language: nil)
            textMarks = TextMarkController(textView: tv)
            view = tv
            scrollView.documentView = view
        case .image:
            // Interactive zoom (F-115) with the four commands and honest levels (F-389). The image view is
            // sized to the image's **pixels** and does not resize with the window, so magnification 1 is
            // one image pixel per point — actual size. It used to be stretched to the scroll view, which
            // made magnification 1 a *fitted* image: "0 = actual size" showed something else, and a
            // photograph could not be seen at 1:1 at all. Pinch and ⌘-scroll still come from AppKit.
            view = zoomImageView
            if let image = NSImage(contentsOfFile: path) {
                imageZoom.present(image)
            } else {
                imageZoom.clear()
                zoomImageView.image = nil
                scrollView.documentView = zoomImageView
            }
        case .media:
            let player = AVPlayer(url: URL(fileURLWithPath: path))
            avPlayer = player
            let pv = AVPlayerView()
            pv.player = player
            pv.controlsStyle = .inline
            pv.videoGravity = .resizeAspect
            pv.frame = scrollView.contentView.bounds
            pv.autoresizingMask = [.width, .height]   // fill the clip view (no scroll)
            view = pv
            scrollView.documentView = pv
        case .code:
            let ext = (path as NSString).pathExtension.lowercased()
            let language = SyntaxHighlighter.language(forExtension: ext)
                ?? SyntaxHighlighter.language(forExtension: "c")!
            if slice.count <= textViewSizeLimit, !hasBinaryContent(slice) {
                let tv = makeTextContent(decodedText(slice), ext: ext, language: language)
                textMarks = TextMarkController(textView: tv)
                view = tv
            } else if slice.count <= Self.highlightSizeLimit, !hasBinaryContent(slice) {
                // Still small enough to highlight in one pass (materialized).
                view = CodeListerView(text: decodedText(slice), language: language,
                                      encoding: searchEncoding)
            } else {
                // Beyond practical highlighting: stream as plain text, uncapped (F-112).
                view = TextListerView(slice: slice, encoding: textEncoding?.encoding)
            }
            scrollView.documentView = view
        case .xmlTree:
            let root = xmlRoot ?? XMLTreeNode(name: "(empty)")
            let outline = NSOutlineView()
            outline.setAccessibilityLabel(String(localized: "XML tree"))
            let column = NSTableColumn(identifier: .init("xml"))
            column.title = "XML"
            outline.addTableColumn(column)
            outline.outlineTableColumn = column
            outline.headerView = nil
            outline.rowSizeStyle = .small
            outline.backgroundColor = Theme.current.listBackground
            let controller = XMLOutlineController(root: root)
            outline.dataSource = controller
            outline.delegate = controller
            xmlOutline = controller
            outline.reloadData()
            outline.expandItem(root)
            view = outline
            scrollView.documentView = outline
        case .plugin, .directory:
            return   // handled above / elsewhere
        }
        contentView = view
        updateStatus()
    }

    /// Load `path` into a claiming plugin and embed its view over the content area.
    /// Returns false if no plugin claims the file or the load fails.
    private func embedPlugin(for path: String, slice: FileSlice) -> Bool {
        guard let container, let lister = pluginClaiming(path: path, slice: slice) else { return false }
        var flags: PLXShowFlags = []
        if isDarkAppearance { flags.insert(.darkMode) }
        let parentPtr = Unmanaged.passUnretained(container).toOpaque()
        // What the plugin is being asked to fit into. A renderer that puts a toolbar above its
        // content is right in a window and wrong in a 200-point column, and this window is the
        // "viewer" surface — the preview panel passes its own.
        let area = marks.splitView
        let extras = ["lister.surface": "viewer",
                      "lister.width": String(Int(area.bounds.width)),
                      "lister.height": String(Int(area.bounds.height))]
        var loaded: PLXHandle?
        if let context = ListerPluginContext.shared {
            context.withServices(extras) { services in
                loaded = lister.loadEx(parent: parentPtr, file: path, showFlags: flags, services: services)
            }
        } else {
            loaded = lister.load(parent: parentPtr, file: path, showFlags: flags)
        }
        guard let handle = loaded else { return false }
        // The PLX contract: the handle is an NSView* the host embeds and later closes.
        let view = Unmanaged<NSView>.fromOpaque(handle).takeUnretainedValue()
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        // Fill the content area, not the whole window. Pinning to the container's edges put
        // the plugin's own chrome on top of the viewer's toolbar — the CSV lister's "Filter"
        // row drew over the representation popup and the Symbols button. The split view is
        // exactly the region between toolbar, sidebar, minimap and status bar, which is what
        // an embedded representation should occupy, and it is the same anchor the web view
        // uses. (Anchoring to scrollView instead would freeze the height: rebuildContent
        // hides it first, and a hidden NSSplitView arranged subview keeps its last frame.)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: area.topAnchor),
            view.leadingAnchor.constraint(equalTo: area.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: area.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: area.bottomAnchor)
        ])
        pluginView = (lister, handle, view)
        // The plugin's view *is* the content view now. Without this, `contentView` kept pointing at
        // whatever the previous representation built, so `markable`, `ViewerTextProviding` and the
        // snapshot verb all resolved against an invisible view belonging to the file before this one —
        // the same defect the rendered page had until it was fixed there, and it was still here.
        contentView = view
        textMarks = nil
        return true
    }

    /// Remove and close any embedded plugin view (balances embedPlugin's load).
    private func teardownPlugin() {
        guard let pv = pluginView else { return }
        pv.view.removeFromSuperview()
        pv.lister.close(pv.handle)
        pluginView = nil
    }

    /// Stop and release the media player (so audio doesn't keep playing after the
    /// view changes, we navigate to another file, or the window closes).
    private func teardownMedia() {
        avPlayer?.pause()
        avPlayer = nil
    }

    private var isDarkAppearance: Bool {
        (window?.effectiveAppearance ?? NSApp.effectiveAppearance)
            .bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    func windowWillClose(_ notification: Notification) {
        teardownPlugin()
        teardownMedia()
    }

    // MARK: - Directory summary (F3 on a folder)

    private func loadDirectoryStats(_ dir: String) {
        scrollView.isHidden = false
        let label = NSTextField(wrappingLabelWithString: String(localized: "Calculating…"))
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = Theme.current.listText
        // A wrapping label is not flipped, so as a documentView its origin would be the
        // bottom left and the folder summary would sit at the foot of the scroll view. Put
        // it in a top-origin container instead.
        let document = FlippedContainerView()
        document.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(label)
        // The document view goes in FIRST. The width constraint below ties the container to the scroll
        // view's clip view, and until `documentView` is assigned the two are in different view
        // hierarchies — activating it then throws `NSInvalidArgumentException` ("no common ancestor") and
        // takes the app down. Pressing F3 on a *folder* did exactly that; it stayed hidden because the
        // scenario that covers the viewer happened to have a file under the cursor, and only did not when
        // the panel's contents shifted.
        scrollView.documentView = document
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: document.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -8),
            label.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -8),
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        contentView = label
        statusLabel.stringValue = "\(String(localized: "Folder"))   \(dir)"
        Task { @MainActor in
            let stats = await DirectoryStatistics().measure(dir)
            label.stringValue = Self.statsText(stats)
            label.sizeToFit()
            let size = ByteSize(stats.totalBytes).formatted(style: .kb)
            self.statusLabel.stringValue =
                "\(String(localized: "Folder"))   \(stats.files) \(String(localized: "files")), " +
                "\(stats.folders) \(String(localized: "folders"))   \(size)   \(dir)"
        }
    }

    private static func statsText(_ s: DirectoryStats) -> String {
        let size = ByteSize(s.totalBytes).formatted(style: .kb)
        return """
        \(String(localized: "Directory")):  \(s.path)

        \(String(localized: "Name")):     \(s.name)
        \(String(localized: "Files")):    \(s.files)
        \(String(localized: "Folders")):  \(s.folders)
        \(String(localized: "Size")):     \(size)  (\(s.totalBytes) \(String(localized: "bytes")))
        """
    }

    private func updateStatus() {
        let size = slice?.count ?? 0
        let modeName: String
        switch mode {
        case .text:
            let enc = textEncoding?.displayName ?? String(localized: "auto")
            let fmt: String
            if isFormatted {
                let via = formatterUsed.map { " (\($0))" } ?? ""
                fmt = " · \(String(localized: "formatted"))\(via)"
            } else {
                fmt = ""
            }
            modeName = "\(String(localized: "Text")) · \(enc)\(fmt)"
        case .hex: modeName = "\(String(localized: "Hex")) · \(hexBytesPerRow)/line"   // F-111
        case .binary: modeName = "\(String(localized: "Binary")) · \(binaryColumns)/line"
        case .image:
            // The level belongs next to the representation: a picture at 9.3% and the same picture at
            // 100% look like two different files, and nothing else on screen says which one you have.
            modeName = "\(String(localized: "Image")) · \(imageZoom.levelText)"
        case .media: modeName = String(localized: "Media")
        case .plugin:
            let name = pluginView?.lister.name ?? ""
            modeName = name.isEmpty ? String(localized: "Plugin") : "\(String(localized: "Plugin")) · \(name)"
        case .directory:
            modeName = String(localized: "Folder")
        case .code:
            let ext = (files[index] as NSString).pathExtension.lowercased()
            let lang = SyntaxHighlighter.language(forExtension: ext)?.name ?? String(localized: "Code")
            modeName = "\(String(localized: "Code")) · \(lang)"
        case .xmlTree:
            modeName = String(localized: "XML Tree")
        }
        let sizeText = ByteSize(size).formatted(style: .kb)
        let crumb = symbolPathText.isEmpty ? "" : "   ▸ \(symbolPathText)"
        statusLabel.stringValue = "\(modeName)   \(sizeText)\(crumb)   \(files[index])"
    }

    // MARK: - Viewer function menu (#43) + copy (#44)

    /// A context menu listing the viewer's functions, so the (otherwise keyboard-only)
    /// features are discoverable. Also carries Copy (Cmd+C).

    private func setModeManually(_ newMode: Mode) {
        guard directoryPath == nil else { return }
        mode = newMode
        rebuildContent()
    }

    @objc func vmText() { setModeManually(.text) }
    /// Show the file through a plugin — "Rendered", as the popup and the menu call it.
    ///
    /// It is the same representation as before by the reader's reckoning; what changed is who draws
    /// it. Nothing happens when no plugin claims the file, which is also when the item is disabled.
    @objc func vmPlugin() { guard pluginClaiming(path: files[index], slice: slice) != nil else { return }
                            setModeManually(.plugin) }
    @objc func vmHex() { setModeManually(.hex) }
    @objc func vmImage() { setModeManually(.image) }
    @objc func vmCode() {
        let ext = files.indices.contains(index) ? (files[index] as NSString).pathExtension.lowercased() : ""
        guard SyntaxHighlighter.language(forExtension: ext) != nil else { NSSound.beep(); return }
        setModeManually(.code)
    }
    @objc func vmAuto() { loadCurrent(autoMode: true) }
    @objc func vmEncoding() { if mode == .text || mode == .code { cycleEncoding() } }
    @objc func vmFormat() { if mode == .text || mode == .code { formatStructured() } }
    @objc func vmXPath() { if mode == .text || mode == .code { promptXPath() } }
    @objc func vmXMLTree() { if mode == .text || mode == .code { showXMLTree() } }
    @objc func vmFind() {
        if let tv = textContentView { finder(tv, .showFindInterface) } else { promptSearch() }
    }
    @objc func vmFindNext() {
        if let tv = textContentView { finder(tv, .nextMatch) } else { findNext() }
    }
    /// Shift+F3. Same routing as `vmFindNext`, which the raw F3 key did *not* use: it called the byte
    /// scanner directly, and in a text view that scan has nothing to scroll — so F3 was silently dead
    /// there while ⌘G from the menu worked. Seeding the search from Find Files (F-407) made that visible,
    /// because there is now a term to continue.
    @objc func vmFindPrevious() {
        if let tv = textContentView { finder(tv, .previousMatch) } else { findPrevious() }
    }
    @objc func vmGoto() { promptGoto() }
    @objc func vmNextFile() { step(1) }
    @objc func vmPrevFile() { step(-1) }
    @objc func vmCopyAll() { copyAll() }

    @objc func vmMarkAll() { promptMarkAll() }
    @objc func vmCount() { promptCount() }
    @objc func vmClearAllMarks() { backendClearAll(); marks.reload() }

    // MARK: - Mark backend routing (NSTextView vs. custom virtual view)

    /// True when the current content supports occurrence marking.
    private var hasMarkBackend: Bool { textMarks != nil || markable != nil }
    private var backendNextColor: Int { textMarks?.nextColorIndex ?? markable?.nextMarkColorIndex ?? 0 }
    @discardableResult
    private func backendMarkAll(_ term: String, colorIndex: Int?) -> Int {
        if let tm = textMarks { return tm.markAll(of: term, colorIndex: colorIndex) }
        return markable?.markAll(of: term, colorIndex: colorIndex) ?? 0
    }
    private func backendCount(_ term: String) -> Int {
        if let tm = textMarks { return tm.count(of: term) }
        return markable?.countOccurrences(of: term) ?? 0
    }
    private func backendClearAll() {
        if let tm = textMarks { tm.clearAll() } else { markable?.clearAllMarks() }
    }

    private func finder(_ tv: NSTextView, _ action: NSTextFinder.Action) {
        let item = NSMenuItem(); item.tag = action.rawValue
        tv.performTextFinderAction(item)
    }

    // MARK: - Mark All (occurrence highlighting — viewer parity with the editor)

    /// Prompt for a term + color and highlight every occurrence in the view.
    private func promptMarkAll() {
        guard hasMarkBackend else { NSSound.beep(); return }
        let dialog = MarkColorDialog(
            title: String(localized: "Mark All"),
            prompt: String(localized: "Mark all occurrences of:"),
            term: String(bytes: lastNeedle, encoding: .utf8) ?? "",
            showsTerm: true,
            initialColorIndex: backendNextColor % TextMarkController.palette.count)
        dialog.onConfirm = { [weak self] text, colorIndex in
            guard let self, !text.isEmpty else { return }
            self.lastNeedle = Array(text.utf8)
            let n = self.backendMarkAll(text, colorIndex: colorIndex)
            self.statusLabel.stringValue = n > 0
                ? String(localized: "\(n) occurrence(s) marked") : String(localized: "Not found")
            if n == 0 { NSSound.beep() } else { self.marks.show() }
            self.marks.reload()
        }
        markDialog = dialog
        dialog.runModalDialog(over: window)
    }

    /// Prompt for a term and report its count in the status bar (no marking).
    private func promptCount() {
        guard hasMarkBackend else { NSSound.beep(); return }
        let dialog = InputDialog(title: String(localized: "Count"),
                                 prompt: String(localized: "Count occurrences of:"),
                                 initialValue: String(bytes: lastNeedle, encoding: .utf8) ?? "")
        dialog.onConfirm = { [weak self] text in
            guard let self, !text.isEmpty else { return }
            self.statusLabel.stringValue = String(localized: "\(self.backendCount(text)) occurrence(s)")
        }
        searchDialog = dialog
        dialog.runModalDialog(over: window)
    }

    /// Toggle the docked marks panel (show at default height / collapse).
    @objc func vmMarksList() {
        marks.toggle()
    }

    private func copyAll() {
        // A text field being edited comes first: the viewer's ⌘C is also the ⌘C of every dialog it
        // opens (Find, Go To), and a menu key equivalent beats the responder chain — so without this,
        // ⌘C in the Go To field copied the *file* instead of the field's selection. Only an *editable*
        // text object wins, so the read-only content view below keeps its own meaning of "copy".
        if AppMenu.forwardToEditedText(#selector(NSText.copy(_:))) { return }
        // An embedded plugin view — a rendered Markdown page among them: guarded on responds(to:),
        // so a plugin that implements the standard action gets it and one that doesn't still falls
        // through to the beep below rather than silently doing nothing.
        //
        // The viewer's Edit menu owns the ⌘C key equivalent (makeEditMenu binds it to
        // DocumentAction.copy), and a menu key equivalent is matched before the responder chain — so
        // the key never reaches the plugin's view on its own. That is why copying worked from
        // WebKit's own context menu but not from the keyboard.
        if mode == .plugin, let pv = pluginView?.view, pv.responds(to: Selector(("copy:"))) {
            NSApp.sendAction(Selector(("copy:")), to: pv, from: nil)
            return
        }
        let provider = contentView as? ViewerTextProviding
        // Prefer the mouse selection; fall back to the whole text.
        //
        // The fallback is checked against the file's size *first*. Building it is the expensive part —
        // for the virtual view "the whole text" means decoding the entire file, and this view exists
        // for files that need not fit in memory (F-112), so on a large one this was not a slow copy but
        // an allocation the size of the file. The app already has an answer for text too big to put on
        // the pasteboard; it was only ever applied after the text existed.
        let selected = provider?.selectedText
        if (selected ?? "").isEmpty, let slice, slice.count > Self.copyAllLimit {
            let alert = NSAlert()
            alert.messageText = String(localized: "Copy")
            alert.informativeText =
                String(localized: "The result is too large for the clipboard — use Save instead.")
            alert.addButton(withTitle: String(localized: "OK"))
            if let window { alert.beginSheetModal(for: window) } else { alert.runModal() }
            return
        }
        guard let text = selected ?? provider?.copyText, !text.isEmpty else {
            NSSound.beep(); return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Keys

    /// Render the file as fixed-width raw bytes (F-111 binary mode): printable
    /// ASCII/Latin-1 shown as-is, everything else as '.', wrapped at `columns`.
    private static func binaryString(_ slice: FileSlice, columns: Int) -> String {
        let n = Int(min(slice.count, 4 * 1024 * 1024))
        let bytes = slice.bytes(at: 0, length: n)
        var out = String.UnicodeScalarView()
        out.reserveCapacity(bytes.count + bytes.count / max(1, columns) + 1)
        for (i, b) in bytes.enumerated() {
            let printable = (b >= 0x20 && b <= 0x7e) || b >= 0xa0
            out.append(printable ? UnicodeScalar(b) : ".")
            if (i + 1) % columns == 0 { out.append("\n") }
        }
        return String(out)
    }

    #if DEBUG
    /// Diagnostic: the current "View" popup item titles (built-in modes + the
    /// current file's claiming plugins), for F-119 automation checks.
    func automationReprItems() -> [String] { reprPopup.itemArray.map(\.title) }

    /// Diagnostic: a PNG of whatever the viewer is currently showing.
    ///
    /// Everything else about this window can be dumped as text. A rendered page cannot: "are the
    /// code blocks coloured, and in dark mode too" is a question only a picture answers. Taken from
    /// inside the app on purpose — `screencapture` needs Screen Recording permission, which a
    /// verification run has no business asking a machine for, and without it every shot comes back
    /// black.
    ///
    /// The web view needs its own route: WebKit renders in another process, so `cacheDisplay` on it
    /// returns an empty bitmap — `takeSnapshot` is the only way to see the page. Hence the callback:
    /// that call is asynchronous and a script has to be able to wait for the file.
    func automationContentSnapshot(to path: String, then done: @escaping (String) -> Void) {
        func write(_ image: NSImage?) -> String {
            guard let image, let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { return "no image" }
            do {
                try png.write(to: URL(fileURLWithPath: path))
                return "\(Int(image.size.width))x\(Int(image.size.height))"
            } catch { return "write failed: \(error.localizedDescription)" }
        }
        // A page rendered by a plugin. WebKit draws in another process, so `cacheDisplay` on the
        // view below returns an empty bitmap and only `takeSnapshot` sees the page — and the plugin
        // hands over a plain NSView, so the web view has to be found rather than cast to.
        if let web = contentWebView() {
            web.takeSnapshot(with: nil) { image, error in
                done(image == nil ? "snapshot failed: \(error?.localizedDescription ?? "nil")"
                                  : write(image))
            }
            return
        }
        guard let view = contentView ?? window?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            done("no content view"); return
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { done("no png"); return }
        done((try? png.write(to: URL(fileURLWithPath: path))) != nil
             ? "\(Int(view.bounds.width))x\(Int(view.bounds.height))" : "write failed")
    }
    #endif

    /// Apply an initial search term and jump to the first match (F-113) — used
    /// when the viewer is launched with a search string (CLI `-ViewSearch` or the
    /// automation `search:` token). Call after the window is shown (content loaded).
    func applyInitialSearch(_ term: String) {
        let term = term.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        // Defer until the window's initial layout settles, then jump to the first
        // match. NSTextView content (small text/code files) selects + scrolls +
        // pulses the match; the custom virtual views use the byte-offset search.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            if let tv = self.textContentView {
                let ns = tv.string as NSString
                let opts: NSString.CompareOptions = self.searchCaseInsensitive ? .caseInsensitive : []
                let range = ns.range(of: term, options: opts)
                guard range.location != NSNotFound else { NSSound.beep(); return }
                tv.setSelectedRange(range)
                tv.scrollRangeToVisible(range)
                tv.showFindIndicator(for: range)
            } else {
                if self.mode == .hex, let bytes = ByteSearch.parseHex(term), !bytes.isEmpty {
                    self.lastNeedle = bytes
                } else {
                    self.lastNeedle = Array(term.utf8)
                }
                self.searchOffset = 0
                self.findNext()
            }
        }
    }

    #if DEBUG
    /// Run a search from the automation runner and report where it landed.
    ///
    /// Here because the viewer's find is a modal dialog and its result is a scroll position — "did
    /// the pattern match, and at which byte" is otherwise a question only somebody watching the
    /// window can answer, and the regex path is precisely the one whose offsets are easy to get
    /// subtly wrong.
    func automationFind(_ pattern: String, regex: Bool, caseInsensitive: Bool) -> String {
        searchCaseInsensitive = caseInsensitive
        lastRegex = nil
        if regex {
            let made = ChunkRegexSearcher.compile(pattern, caseInsensitive: caseInsensitive)
            guard let compiled = made.regex else { return "error=\(made.error ?? "unknown")\n" }
            lastRegex = compiled
        }
        lastNeedle = Array(pattern.utf8)
        searchOffset = 0
        // Cleared first: `findNext` leaves the previous hit in place when it finds nothing, so a
        // stale value would read as a match and make this check unable to fail.
        lastMatchOffset = -1
        findNext()
        let found = lastMatchOffset >= 0
        // …and whether the view *showed* it. Reporting only the offset is how a search that found
        // the right byte and highlighted nothing passed for working: in hex every row looks like
        // every other row, so "it scrolled somewhere" and "it found it" are indistinguishable
        // without this line.
        // Which view answered, and in which encoding it reads the file. Both were guesses while
        // this was being debugged, and a guess about the encoding is what a byte-to-character
        // mapping gets wrong silently.
        var shown = "contentview=\(contentView.map { String(describing: type(of: $0)) } ?? "none")\n"
            + "encoding=\(searchEncoding.rawValue)\n"
        shown += (contentView as? HexListerView)?.automationSelectionDescription ?? ""
        // In text and code the observable is the selected *text*, and it is the strongest one
        // available: a hit that is highlighted in the wrong place reports the wrong characters,
        // where an offset would still have looked right. A byte offset mapped to the wrong column
        // is precisely how this went unnoticed in the code view, whose mapping was documented as
        // "best-effort" and drifted with every multi-byte character above the match.
        if let text = (contentView as? ViewerTextProviding)?.selectedText {
            shown += "selectedtext=\(text)\n"
        }
        return "regex=\(regex)\nfound=\(found)\nmatch=\(found ? String(lastMatchOffset) : "-")\n" + shown
    }

    /// Diagnostic: force word-wrap on (for automation screenshots).
    func automationEnableWrap() { wrapText = true; rebuildContent() }
    /// Diagnostic: force binary mode (for automation screenshots).
    func automationForceBinary() { mode = .binary; rebuildContent() }
    /// Diagnostic: force hex mode at a given line width (for F-111 screenshots).
    func automationForceHex(bytesPerRow: Int) { mode = .hex; hexBytesPerRow = bytesPerRow; rebuildContent(); updateStatus() }
    #endif

    // MARK: - Zoom (F-115 interactive, F-389 the four commands)

    @objc func docZoomIn() { imageZoom.zoomIn(); updateStatus() }
    @objc func docZoomOut() { imageZoom.zoomOut(); updateStatus() }
    @objc func docZoomActual() { imageZoom.actualSize(); updateStatus() }
    @objc func docZoomFit() { imageZoom.zoomToFit(); updateStatus() }

    private func handleKey(_ event: NSEvent) -> Bool {
        // In directory-summary mode only Esc is meaningful (no file modes).
        if directoryPath != nil {
            if event.keyCode == 53 { window?.close(); return true }
            return false
        }
        // Never claim a ⌘ shortcut. Every binding below is a bare letter or function
        // key matched by keyCode alone, so without this guard each one also swallowed
        // its Command variant: ⌘A reloaded in auto mode instead of selecting all,
        // ⌘M marked occurrences instead of minimising, ⌘P stepped to the next file
        // instead of printing, ⌘E cycled the encoding, ⌘1…⌘7 switched representation.
        // Those belong to the menus and to standard editing, so let them through.
        if event.modifierFlags.contains(.command) { return false }

        let ctrl = event.modifierFlags.contains(.control)
        let shift = event.modifierFlags.contains(.shift)
        switch event.keyCode {
        case 18: mode = .text; rebuildContent(); return true       // 1
        // No digit for "rendered" any more: Markdown and HTML are a plugin, and 5 is the plugin key
        // (which cycles the claimants when several plugins want the file).
        case 20: mode = .hex; rebuildContent(); return true        // 3
        case 21: mode = .image; rebuildContent(); return true      // 4
        case 26: mode = .binary; rebuildContent(); return true     // 7 (binary / fixed-width)
        case 23 where !plugins.isEmpty:                            // 5 (plugin; repeats cycle claimants, F-119)
            let matches = matchingPlugins(path: files[index], slice: slice)
            guard !matches.isEmpty else { return true }
            if mode == .plugin { pluginChoice = (pluginChoice + 1) % matches.count }
            mode = .plugin; rebuildContent(); return true
        case 0: loadCurrent(autoMode: true); return true           // a (auto)
        case 1 where symbolToggle.isEnabled: toggleSymbols(); return true   // s (symbol outline + filter)
        case 22 where SyntaxHighlighter.language(forExtension: (files[index] as NSString).pathExtension.lowercased()) != nil:
            mode = .code; rebuildContent(); return true            // 6 (code, if a language matches)
        case 14 where mode == .text || mode == .code: cycleEncoding(); return true  // e (cycle text encoding)
        case 3 where !ctrl && (mode == .text || mode == .code): formatStructured(); return true  // f (format JSON/XML)
        case 7 where !ctrl && (mode == .text || mode == .code): promptXPath(); return true  // x (XPath query)
        case 17 where !ctrl && (mode == .text || mode == .code): showXMLTree(); return true  // t (XML tree)
        case 46 where mode == .text || mode == .code: promptMarkAll(); return true  // m (mark all occurrences)
        case 45: step(1); return true                              // n
        case 35: step(-1); return true                             // p
        case 3 where ctrl: promptSearch(); return true             // Ctrl+F
        case 98: promptSearch(); return true                       // F7 = open search (TC parity)
        case 5 where ctrl: promptGoto(); return true               // Ctrl+G (goto line/offset)
        case 99 where shift: vmFindPrevious(); return true         // Shift+F3 = previous match
        case 99: vmFindNext(); return true                         // F3 = next match
        case 126 where mode != .plugin: scrollContent(by: -lineStep); return true       // ↑
        case 125 where mode != .plugin: scrollContent(by: lineStep); return true        // ↓
        case 116 where mode != .plugin: scrollContent(by: -pageStep); return true       // PageUp
        case 121 where mode != .plugin: scrollContent(by: pageStep); return true        // PageDown
        case 115 where mode != .plugin: scrollToEdge(top: true); return true            // Home
        case 119 where mode != .plugin: scrollToEdge(top: false); return true           // End
        case 24 where mode == .image: docZoomIn(); return true            // + / =
        case 27 where mode == .image: docZoomOut(); return true           // -
        case 29 where mode == .image: docZoomActual(); return true        // 0 (actual size, 100%)
        case 3 where mode == .image: docZoomFit(); return true            // f (fit the whole picture)
        case 13 where mode == .text || mode == .code:                    // w = toggle word wrap
            wrapText.toggle(); rebuildContent(); return true
        case 24 where mode == .text || mode == .code:                    // + = larger font
            viewerFontSize = min(48, viewerFontSize + 1); rebuildContent(); return true
        case 27 where mode == .text || mode == .code:                    // - = smaller font
            viewerFontSize = max(6, viewerFontSize - 1); rebuildContent(); return true
        case 29 where mode == .text || mode == .code:                    // 0 = reset font
            viewerFontSize = 12; rebuildContent(); return true
        case 24 where mode == .hex:                                       // + = wider hex line (F-111)
            hexBytesPerRow = Self.cycle(hexBytesPerRow, in: Self.hexWidths, up: true); rebuildContent(); return true
        case 27 where mode == .hex:                                       // - = narrower hex line
            hexBytesPerRow = Self.cycle(hexBytesPerRow, in: Self.hexWidths, up: false); rebuildContent(); return true
        case 24 where mode == .binary:                                    // + = more binary columns
            binaryColumns = Self.cycle(binaryColumns, in: Self.binaryWidths, up: true); rebuildContent(); return true
        case 27 where mode == .binary:                                    // - = fewer binary columns
            binaryColumns = Self.cycle(binaryColumns, in: Self.binaryWidths, up: false); rebuildContent(); return true
        case 53: window?.close(); return true                      // Esc
        default: return false
        }
    }

    // MARK: - Scrolling (keyboard navigation in the viewer)

    private var lineStep: CGFloat { 15 * 3 }
    private var pageStep: CGFloat { max(40, scrollView.contentView.bounds.height - 24) }

    private func scrollContent(by dy: CGFloat) {
        guard let doc = scrollView.documentView else { return }
        let clip = scrollView.contentView
        let maxY = max(0, doc.frame.height - clip.bounds.height)
        var origin = clip.bounds.origin
        origin.y = max(0, min(origin.y + dy, maxY))
        clip.scroll(to: origin)
        scrollView.reflectScrolledClipView(clip)
    }

    private func scrollToEdge(top: Bool) {
        guard let doc = scrollView.documentView else { return }
        let clip = scrollView.contentView
        let maxY = max(0, doc.frame.height - clip.bounds.height)
        clip.scroll(to: NSPoint(x: 0, y: top ? 0 : maxY))
        scrollView.reflectScrolledClipView(clip)
    }

    // MARK: - Search (SPEC-005 §4)

    private func promptSearch() {
        let hexMode = (mode == .hex)
        let prompt = hexMode ? String(localized: "Search for (text, or hex like 48 65):")
                             : String(localized: "Search for:")
        let dialog = InputDialog(title: String(localized: "Find"), prompt: prompt,
                                 initialValue: String(bytes: lastNeedle, encoding: .utf8) ?? "",
                                 checkboxTitle: String(localized: "Ignore case"),
                                 checkboxOn: searchCaseInsensitive,
                                 // Not offered in hex mode: there the text is a byte sequence, and a
                                 // pattern over bytes is a different feature that nobody asked for.
                                 secondCheckboxTitle: hexMode ? nil : String(localized: "Regular expression"),
                                 secondCheckboxOn: lastRegex != nil)
        dialog.onConfirm = { [weak self, weak dialog] text in
            guard let self, !text.isEmpty else { return }
            self.searchCaseInsensitive = dialog?.isChecked ?? true
            let wantsRegex = !hexMode && (dialog?.isSecondChecked ?? false)
            self.lastRegex = nil
            if wantsRegex {
                let made = ChunkRegexSearcher.compile(text, caseInsensitive: self.searchCaseInsensitive)
                guard let regex = made.regex else {
                    // A pattern that will not compile finds nothing, which reads exactly like "the
                    // text is not in this file" — so say which it was.
                    self.presentSearchProblem(made.error ?? "")
                    return
                }
                self.lastRegex = regex
                self.lastNeedle = Array(text.utf8)   // so the dialog reopens showing the pattern
            } else if hexMode, let bytes = ByteSearch.parseHex(text), !bytes.isEmpty {
                // In hex mode, a valid hex sequence (e.g. "48 65") searches those bytes.
                self.lastNeedle = bytes
            } else {
                self.lastNeedle = Array(text.utf8)
            }
            self.searchOffset = 0
            self.findNext()
        }
        searchDialog = dialog
        dialog.runModalDialog(over: window)
    }

    // MARK: - The search that found this file (F-407)

    /// Adopt the search the file was found with, once, right after the content is on screen.
    ///
    /// Consumed on first use, which is what makes the rest of the requirement fall out by itself: F3
    /// repeats it, Ctrl+F opens showing it, and the moment the reader edits or clears the field it is
    /// theirs — nothing puts the old term back, not the next file in the window and not a change of
    /// representation.
    ///
    /// Whether the *first hit* can be shown depends on what is on screen, so this seeds the state either
    /// way and jumps only where a jump means something: an `NSTextView` (text and code up to 4 MB) is
    /// searched through its own find bar so ⌘G continues from it, a byte-scannable view is scanned, and
    /// a rendered page or a plugin view is left alone because its content is still loading — a search
    /// there would find nothing and beep at somebody who did not ask for it. Nothing beeps here at all:
    /// the term matched the *file*, and the representation on screen may legitimately not contain it —
    /// a match past the 16 MB text cap, or in a comment rather than the contents (F-373).
    private func applyPendingSearchSeed() {
        guard let seed = pendingSearchSeed else { return }
        pendingSearchSeed = nil
        searchCaseInsensitive = !seed.caseSensitive
        lastNeedle = seed.needle
        lastRegex = nil
        if seed.isRegex {
            // A pattern that will not compile here is one the file-search accepted, so it does compile;
            // if it somehow does not, the term is still seeded and the search stays literal.
            lastRegex = ChunkRegexSearcher.compile(seed.term, caseInsensitive: searchCaseInsensitive).regex
        }
        searchOffset = 0
        lastMatchOffset = -1
        if let tv = textContentView, !seed.isHex {
            seedTextViewSearch(tv, seed)
        } else if contentView is ListerScrollable {
            findNext()
        }
    }

    /// Select the first hit in a text view and hand the term to the native find bar.
    ///
    /// The bar is opened deliberately — a prefilled search nobody can see is indistinguishable from no
    /// search at all — and the keyboard goes back to the content afterwards, so the viewer's own keys
    /// (n/p, space, F3) keep working while the term stays visible and editable in the bar.
    private func seedTextViewSearch(_ tv: NSTextView, _ seed: ViewerSearchSeed) {
        let text = tv.string as NSString
        let whole = NSRange(location: 0, length: text.length)
        let hit: NSRange
        if let regex = lastRegex {
            hit = regex.firstMatch(in: tv.string, options: [], range: whole)?.range
                ?? NSRange(location: NSNotFound, length: 0)
        } else {
            hit = text.range(of: seed.term, options: seed.caseSensitive ? [] : [.caseInsensitive],
                             range: whole)
        }
        // The system find pasteboard is where a find bar takes its initial value from, and it is also
        // what makes the term the one ⌘G continues with in every text view of the app — the same
        // mechanism that carries a search between apps on macOS.
        let findBoard = NSPasteboard(name: .find)
        findBoard.clearContents()
        findBoard.setString(seed.term, forType: .string)
        // `setSearchString` takes what is *selected*, so the selection has to be the hit before it is
        // asked; with no hit it would put the empty selection in the field and undo the line above.
        if hit.location != NSNotFound {
            tv.setSelectedRange(hit)
            tv.scrollRangeToVisible(hit)
            finder(tv, .setSearchString)
        }
        finder(tv, .showFindInterface)
        if hit.location != NSNotFound { tv.showFindIndicator(for: hit) }
        // Without this the find bar keeps the keyboard and the reader's first keystroke edits the search
        // instead of scrolling the file they came here to read.
        if let window { window.makeFirstResponder(tv) }
    }

    /// Decode the file's bounded prefix to text using the active/auto encoding.
    private func decodedText(_ slice: FileSlice) -> String {
        decodedTextAndFidelity(slice).text
    }

    /// The file as text, and whether that decoding was *lossy*.
    ///
    /// Lossy means the bytes were not valid in the encoding they were taken for, so they went through
    /// `String(decoding:as: UTF8.self)`, which salvages what it can and replaces the rest. For real
    /// text this practically never happens; for binary content it always does, and the result is the
    /// expensive kind — scalars scattered across the whole of Unicode rather than one replacement
    /// character. That is a far sharper signal than counting control bytes: measured on the reported
    /// PNG, the byte heuristic put it at 5.8 % against a 5 % threshold, while uniformly distributed
    /// binary sits at 3.5 % and would pass for text.
    private func decodedTextAndFidelity(_ slice: FileSlice) -> (text: String, needsVirtualView: Bool) {
        let cap = 16 * 1024 * 1024
        let raw = slice.bytes(at: 0, length: min(cap, Int(slice.count)))
        let enc = textEncoding?.encoding ?? EncodingDetector.detect(Array(raw.prefix(64 * 1024)))
        return TextContentKind.decode(raw, encoding: enc)
    }

    /// Pretty-print the current file as JSON or XML in the text view (key `f`).
    private func formatStructured() {
        guard let slice, mode == .text || mode == .code else { return }
        let text = decodedText(slice)
        let ext = (files[index] as NSString).pathExtension.lowercased()
        let result: (text: String, formatter: String)
        do {
            result = try FormatterRegistry.shared.format(text, extension: ext)
        } catch let error as FormatError {
            // Say *why* rather than just beeping: "jq is not installed" and
            // "Not valid JSON" are very different problems for the user.
            statusLabel.stringValue = error.userMessage
            NSSound.beep()
            return
        } catch {
            NSSound.beep()
            return
        }
        // Highlight by the file's own extension, not by whichever formatter ran — a .yml
        // formatted by yq is still YAML.
        //
        // And through the same size thresholds the Code representation uses, which this path skipped: it
        // put *any* formatted text into `CodeListerView`, a view that materialises every token and draws
        // whole lines at once. That is what turned a 2 MB JSON Lines file into a frozen window — the
        // reader pressed Format and the result went into the one view with no cap on it. The line-drawing
        // cost is fixed too (UTF16OffsetTable), but a limit that exists in the path beside this one and
        // not in this one is a defect of its own.
        let view: NSView
        let formattedBytes = Int64(result.text.utf8.count)
        if let language = SyntaxHighlighter.language(forExtension: ext),
           formattedBytes <= Self.highlightSizeLimit {
            view = CodeListerView(text: result.text, language: language)
        } else {
            view = TextListerView(string: result.text)
        }
        scrollView.documentView = view
        contentView = view
        isFormatted = true
        formatterUsed = result.formatter
        setDisplayedText(result.text)
        updateStatus()
    }

    /// Show the current file as a collapsible XML tree (key `t`).
    private func showXMLTree() {
        guard let slice else { return }
        guard let root = XMLTreeParser.parse(decodedText(slice)) else {
            NSSound.beep()
            statusLabel.stringValue = String(localized: "Not valid XML")
            return
        }
        xmlRoot = root
        mode = .xmlTree
        rebuildContent()
    }

    /// Query the current file as XML with an XPath and show the matched nodes (key `x`).
    private func promptXPath() {
        guard let slice else { return }
        let xml = decodedText(slice)
        let dialog = InputDialog(title: String(localized: "XPath"),
                                 prompt: String(localized: "XPath expression:"), initialValue: "//")
        dialog.onConfirm = { [weak self] query in
            guard let self, !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            do {
                let matches = try XPathQuery.evaluate(xml: xml, query: query)
                let out = matches.isEmpty ? String(localized: "(no matches)") : matches.joined(separator: "\n")
                let view = TextListerView(string: out)
                self.scrollView.documentView = view
                self.contentView = view
                self.isFormatted = true
                self.setDisplayedText(out)
                self.statusLabel.stringValue = String(format:
                    NSLocalizedString("XPath: %@   %d match(es)", comment: ""), query, matches.count)
            } catch {
                NSSound.beep()
                self.statusLabel.stringValue = (error as? XPathQuery.QueryError) == .invalidXML
                    ? String(localized: "Not valid XML") : String(localized: "Invalid XPath")
            }
        }
        searchDialog = dialog
        dialog.runModalDialog(over: window)
    }

    /// Cycle the text encoding: auto → each listed encoding → back to auto.
    private func cycleEncoding() {
        let all = TextEncodingChoice.allCases
        switch textEncoding {
        case .none: textEncoding = all.first
        case .some(let current):
            if let i = all.firstIndex(of: current), i + 1 < all.count {
                textEncoding = all[i + 1]
            } else {
                textEncoding = nil   // wrap back to auto-detect
            }
        }
        rebuildContent()
    }

    /// Ctrl+G: jump to a line (text mode) or a byte offset (hex mode).
    private func promptGoto() {
        let isHex = (mode == .hex)
        let prompt = isHex ? String(localized: "Go to offset (0x…, decimal, or an expression like 0x1000+16):")
                           : String(localized: "Go to line (arithmetic allowed, e.g. 120+10):")
        let dialog = InputDialog(title: String(localized: "Go To"), prompt: prompt, initialValue: "")
        dialog.onConfirm = { [weak self] text in
            guard let self else { return }
            if isHex {
                if let offset = HexAddress.parse(text) {
                    // Marked, not merely scrolled to. A row is sixteen bytes and they all look
                    // alike, so scrolling alone answers "somewhere on this line" — the hex editor's
                    // Go To has always put its caret on the byte, and this is the same question.
                    (self.contentView as? HexListerView)?.select(byteRange: offset ..< (offset + 1))
                }
            // Through the same evaluator as the offset, so a line number can be arithmetic too — and
            // so "120 + 10" does not mean one thing in hex mode and nothing in text mode.
            } else if let value = HexAddress.parse(text), value > 0, let line = Int(exactly: value) {
                (self.contentView as? TextListerView)?.scroll(toLine: line)
                (self.contentView as? CodeListerView)?.scroll(toLine: line)
                self.scrollTextViewToLine(line)
            }
        }
        searchDialog = dialog
        dialog.runModalDialog(over: window)
    }

    /// Scroll the read-only NSTextView content to a 1-based line.
    // MARK: - Notes bound to a line (F-379)

    /// Lines of the current file that carry a note, from the Notes plugin's "Note lines" content field.
    ///
    /// Through the content-field mechanism rather than a new host↔plugin call: "a plugin knows something
    /// about this file" already has exactly one way of being asked, and a note bound to a line is that.
    /// A host without the Notes plugin installed simply gets an empty list and shows no group.
    private var annotatedLines: [Int] = []

    /// The line the caret is on (1-based); for the views that have no caret, the first visible one.
    ///
    /// Through `EditorLineIndex` rather than counting line breaks here: it already speaks the UTF-16
    /// offsets `selectedRange` uses, and it gets the end of the text right — a caret one past the last
    /// character is on the last line, not on a line after it.
    private func currentLineNumber() -> Int {
        if let tv = textContentView {
            let ns = tv.string as NSString
            return EditorLineIndex(text: ns).line(containing: min(tv.selectedRange().location, ns.length))
        }
        return (contentView as? ListerLineAddressable)?.firstVisibleLine ?? 1
    }

    /// Ask the Notes plugin which lines of this file are annotated, and offer them in the marks panel.
    private func refreshAnnotations() {
        guard let bridge = ListerNoteBridge.shared, files.indices.contains(index) else {
            annotatedLines = []
            wantsAnnotationPanel = false
            return
        }
        let path = files[index]
        Task { @MainActor [weak self] in
            let lines = await bridge.annotatedLines(path)
            guard let self, self.files.indices.contains(self.index), self.files[self.index] == path,
                  lines != self.annotatedLines || self.wantsAnnotationPanel else { return }
            self.annotatedLines = lines
            // Open the panel only when the user asked for a note and one is now there; otherwise a file
            // that happens to carry annotations would rearrange the window on every open.
            let asked = self.wantsAnnotationPanel
            self.wantsAnnotationPanel = false
            if asked, !lines.isEmpty {
                self.marks.show()
            } else if !self.marks.isHidden {
                self.marks.reload()
            }
        }
    }

    /// Write a note about the line the caret is on (F-379).
    @objc func docNote() {
        guard let bridge = ListerNoteBridge.shared, files.indices.contains(index) else {
            NSSound.beep()
            return
        }
        bridge.editNote("\(files[index])#L\(currentLineNumber())")
        // The note editor is its own window, not a sheet, so there is nothing to wait for here: the
        // annotation appears when the user comes back to the viewer (`windowDidBecomeKey`). Showing
        // the panel now would show it empty.
        wantsAnnotationPanel = true
    }

    /// Set when the user asked for a note, so the panel opens once the note actually exists.
    private var wantsAnnotationPanel = false

    func windowDidBecomeKey(_ notification: Notification) {
        // The note editor is a separate window; coming back here is the moment a new note can be shown.
        refreshAnnotations()
    }

    /// A fitted image stays fitted while the window is resized (F-389).
    ///
    /// Without this, "Zoom to Fit" is a one-off that the next drag of the window's corner undoes — which
    /// is the state the old code was permanently in, since it re-stretched the image on every resize and
    /// had no notion of a level at all.
    func windowDidResize(_ notification: Notification) {
        guard mode == .image else { return }
        imageZoom.viewportChanged()
        updateStatus()
    }

    /// Bring a 1-based line into view in whichever representation is showing.
    private func revealLine(_ line: Int) {
        if let addressable = contentView as? ListerLineAddressable { addressable.scroll(toLine: line) }
        else if textContentView != nil { scrollTextViewToLine(line) }
    }

    private func scrollTextViewToLine(_ line: Int) {
        guard let tv = textContentView else { return }
        let ns = tv.string as NSString
        var loc = 0, current = 1
        while current < line, loc < ns.length {
            loc = NSMaxRange(ns.lineRange(for: NSRange(location: loc, length: 0)))
            current += 1
        }
        let sel = NSRange(location: min(loc, ns.length), length: 0)
        tv.setSelectedRange(sel)
        tv.scrollRangeToVisible(sel)
    }

    private func findNext() {
        guard !lastNeedle.isEmpty else { return }
        // In plugin mode, delegate search to the plugin's own view.
        if mode == .plugin, let pv = pluginView {
            let needle = String(bytes: lastNeedle, encoding: .utf8) ?? ""
            if !needle.isEmpty, !pv.lister.searchText(in: pv.handle, needle) { NSSound.beep() }
            return
        }
        // Formatted output, or an XPath result: what is on screen is not the file, so that is what
        // gets searched. Searching the file here would report hits at offsets into bytes the reader
        // cannot see.
        if displayedText != nil {
            guard let hit = searchDisplayed(from: Int(searchOffset), forward: true) else {
                NSSound.beep()
                searchOffset = 0
                return
            }
            searchOffset = Int64(hit.offset) + 1
            lastMatchOffset = Int64(hit.offset)
            (contentView as? ListerScrollable)?
                .showMatch(byteRange: Int64(hit.offset) ..< Int64(hit.offset + hit.length))
            return
        }
        guard let slice else { return }
        let match = lastRegex.map {
            ChunkRegexSearcher.search($0, in: slice, from: searchOffset, encoding: searchEncoding)
        } ?? ChunkSearcher.search(lastNeedle, in: slice, from: searchOffset,
                                  caseInsensitive: searchCaseInsensitive)
        if let match {
            searchOffset = match + 1
            lastMatchOffset = match
            (contentView as? ListerScrollable)?.showMatch(byteRange: matchRange(at: match))
        } else {
            NSSound.beep()
            searchOffset = 0
        }
    }

    /// Adopt text that replaced the file on screen, and start its search from the top.
    ///
    /// The offset is reset because it counted bytes into the *file*: carrying it over would start
    /// the next search partway into a document it was never measured against.
    private func setDisplayedText(_ text: String) {
        displayedText = text
        displayedBytesCache = nil
        searchOffset = 0
        lastMatchOffset = -1
    }

    /// The UTF-8 bytes of what is on screen — which is what both virtual text views index by.
    private var displayedBytes: [UInt8] {
        if let cached = displayedBytesCache { return cached }
        let made = Array((displayedText ?? "").utf8)
        displayedBytesCache = made
        return made
    }

    /// Find `lastNeedle` (or `lastRegex`) in the text on screen rather than in the file.
    ///
    /// Bounded and already in memory, so there is no chunking here and no maximum match length —
    /// the two things the file searchers exist to manage. A regular expression therefore also
    /// yields a real match *length*, which the chunked path cannot report.
    private func searchDisplayed(from: Int, forward: Bool) -> (offset: Int, length: Int)? {
        guard let text = displayedText else { return nil }
        guard let regex = lastRegex else {
            let bytes = displayedBytes
            if forward {
                return ChunkSearcher.firstIndex(of: lastNeedle, in: bytes, from: from,
                                                caseInsensitive: searchCaseInsensitive)
                    .map { ($0, lastNeedle.count) }
            }
            return ChunkSearcher.lastIndex(of: lastNeedle, in: bytes, upTo: from,
                                           caseInsensitive: searchCaseInsensitive)
                .map { ($0, lastNeedle.count) }
        }
        // Compare in UTF-16, which is what NSRegularExpression reports, and convert only the match
        // that wins. Converting every candidate would be a walk of the whole document per match.
        guard let threshold = utf16Location(ofUTF8: from, in: text) else { return nil }
        let ns = text as NSString
        var chosen: NSRange?
        regex.enumerateMatches(in: text, options: [],
                               range: NSRange(location: 0, length: ns.length)) { match, _, stop in
            guard let range = match?.range, range.location != NSNotFound else { return }
            if forward {
                if range.location >= threshold { chosen = range; stop.pointee = true }
            } else if range.location < threshold {
                chosen = range                     // keep the last one before the threshold
            } else {
                stop.pointee = true
            }
        }
        guard let range = chosen, let swiftRange = Range(range, in: text) else { return nil }
        let start = text.utf8.distance(from: text.startIndex, to: swiftRange.lowerBound)
        let end = text.utf8.distance(from: text.startIndex, to: swiftRange.upperBound)
        return (start, Swift.max(1, end - start))
    }

    /// The UTF-16 offset that a UTF-8 byte offset points at, or nil if it lands mid-character.
    private func utf16Location(ofUTF8 offset: Int, in text: String) -> Int? {
        guard let byteIndex = text.utf8.index(text.utf8.startIndex, offsetBy: offset,
                                              limitedBy: text.utf8.endIndex),
              let index = byteIndex.samePosition(in: text) else { return nil }
        return text.utf16.distance(from: text.startIndex, to: index)
    }

    /// The bytes a match covers.
    ///
    /// For a literal needle that is its length. A regular expression is searched in chunks and the
    /// searcher reports only where a match began, so the range is one byte — enough to put the view
    /// on it without claiming a length nobody measured. Hex mode is unaffected either way: a regular
    /// expression is not offered there, because the term is a byte sequence.
    private func matchRange(at offset: Int64) -> Range<Int64> {
        let length = Int64(lastRegex == nil ? max(1, lastNeedle.count) : 1)
        return offset ..< (offset + length)
    }

    /// The encoding a pattern is matched against — the one the viewer is displaying, so what the
    /// expression sees is what the reader sees.
    private var searchEncoding: String.Encoding { textEncoding?.encoding ?? .utf8 }

    /// Report a pattern that will not compile, rather than letting it look like "not found".
    private func presentSearchProblem(_ reason: String) {
        let alert = NSAlert()
        alert.messageText = String(localized: "That is not a valid regular expression")
        alert.informativeText = reason
        alert.alertStyle = .warning
        if let window { alert.beginSheetModal(for: window) { _ in } } else { alert.runModal() }
    }

    /// Shift+F3: jump to the previous match (before the last one found).
    private func findPrevious() {
        guard !lastNeedle.isEmpty else { return }
        if mode == .plugin, let pv = pluginView {
            let needle = String(bytes: lastNeedle, encoding: .utf8) ?? ""
            if !needle.isEmpty, !pv.lister.searchText(in: pv.handle, needle) { NSSound.beep() }
            return
        }
        if displayedText != nil {
            // `lastMatchOffset` starts at -1, which as a bound means "before the beginning" and
            // would find nothing; from the end is what Shift+F3 means before anything was found.
            let bound = lastMatchOffset >= 0 ? Int(lastMatchOffset) : displayedBytes.count
            guard let hit = searchDisplayed(from: bound, forward: false) else {
                NSSound.beep()
                return
            }
            lastMatchOffset = Int64(hit.offset)
            searchOffset = Int64(hit.offset) + 1
            (contentView as? ListerScrollable)?
                .showMatch(byteRange: Int64(hit.offset) ..< Int64(hit.offset + hit.length))
            return
        }
        guard let slice else { return }
        let backMatch = lastRegex.map {
            ChunkRegexSearcher.searchBackwards($0, in: slice, before: lastMatchOffset,
                                               encoding: searchEncoding)
        } ?? ChunkSearcher.searchBackward(lastNeedle, in: slice, before: lastMatchOffset,
                                          caseInsensitive: searchCaseInsensitive)
        if let match = backMatch {
            lastMatchOffset = match
            searchOffset = match + 1
            (contentView as? ListerScrollable)?.showMatch(byteRange: matchRange(at: match))
        } else {
            NSSound.beep()
        }
    }

    private func step(_ delta: Int) {
        let next = index + delta
        guard files.indices.contains(next) else { return }
        index = next
        loadCurrent(autoMode: true)
    }
}

/// Container that routes key events to the controller.
private final class ListerContainerView: NSView {
    var onKey: ((NSEvent) -> Bool)?
    /// Esc that arrives as a *responder-chain* message rather than as a key event on this view.
    ///
    /// `onKey` only ever fires while this view is the first responder, which it stops being the moment
    /// the reader clicks into the text area, the symbol filter or the marks table — those views consume
    /// the keystroke and turn Esc into `cancelOperation:`, which AppKit then sends up the superview
    /// chain. This view is the window's content view, so every focusable thing in the viewer is inside
    /// it and that chain ends here: one hook covers all of them, present and future.
    var onCancel: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        if onKey?(event) == true { return }
        super.keyDown(with: event)
    }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

/// WKWebView that offers the viewer's command keys to the controller first, then
/// lets WebKit handle the rest (native arrow / space / PageUp-Down scrolling).
/// A lister content view that can scroll a byte offset into view (for search).
protocol ListerScrollable: AnyObject {
    func scroll(toByteOffset offset: Int64)
    /// Show the bytes at `range` as the current search hit.
    ///
    /// Scrolling to a match is not showing it. In the hex representation there is nothing else to
    /// go on — every row looks like every other row — so a reader was left to find the match by
    /// eye at whatever line the view happened to stop on, while the hex *editor*, which selects its
    /// hit, made the difference obvious.
    ///
    /// The three views that scroll by byte offset all implement it — hex selects the bytes, the two
    /// virtual text views select the characters those bytes decode to. The default remains scrolling
    /// alone, so a representation added later shows a match no worse than it used to rather than not
    /// compiling.
    func showMatch(byteRange range: Range<Int64>)
}

extension ListerScrollable {
    func showMatch(byteRange range: Range<Int64>) { scroll(toByteOffset: range.lowerBound) }
}

/// How the viewer reaches the note plugin (F-379).
///
/// The viewer is opened from three places and holds no reference to the main window, so the host
/// installs this once instead of every call site growing a parameter. Nothing is installed when the
/// Notes plugin is absent, and the viewer then behaves exactly as it did before: no group, no command.
@MainActor
struct ListerNoteBridge {
    /// The lines of `path` that carry a note, ascending.
    let annotatedLines: (String) async -> [Int]
    /// Open the note editor for a target key ("<path>#L<line>"), creating the note if it is new.
    let editNote: (String) -> Void

    static var shared: ListerNoteBridge?
}

/// How a lister reaches the host's services table.
///
/// A plugin lister is handed `PcHostServices` at load time so it can read which surface it is being
/// embedded in, the host's theme and the config root. Building that table needs the contribution
/// host, and neither the viewer nor the preview panel has one — both are opened from places that
/// hold no reference to the main window. So the host installs this once, exactly as
/// `ListerNoteBridge` does, and a host that installs nothing loads plugins the old way: through
/// `ListLoad`, with no context, which is what every plugin written before this expects anyway.
@MainActor
struct ListerPluginContext {
    /// Run `body` with a table whose context also answers `extras` (the `lister.*` keys). The
    /// pointer is valid for the duration of `body` and not after it.
    let withServices: (_ extras: [String: String], _ body: (UnsafeRawPointer?) -> Void) -> Void

    static var shared: ListerPluginContext?
}

/// A content view addressable by line number — what a note bound to a line needs (F-379).
///
/// Separate from `ListerScrollable` because the hex view scrolls too and has rows, not lines: asking it
/// for line 40 would silently mean something else.
protocol ListerLineAddressable: AnyObject {
    func scroll(toLine line: Int)
    /// The topmost visible line, 1-based — the nearest thing to a caret in a view that only scrolls.
    var firstVisibleLine: Int { get }
    /// How many lines the view believes it has. Reported in the automation dump: a view that has
    /// mis-counted them renders and scrolls perfectly, it is simply looking at the wrong file shape.
    var lineCount: Int { get }
}

/// A content view whose full text can be copied to the clipboard.
protocol ViewerTextProviding: AnyObject {
    var copyText: String { get }
    /// The currently mouse-selected text, or nil when nothing is selected.
    var selectedText: String? { get }
}

extension ViewerTextProviding {
    var selectedText: String? { nil }
}

/// Read-only NSTextView used for the viewer's text/code modes under the size
/// threshold — gives the native find bar, selection, copy and accessibility, and
/// shares the editor's mark/highlight path. (Large files fall back to the
/// virtual TextListerView/CodeListerView.)
final class ViewerTextView: NSTextView, ViewerTextProviding {
    /// What a screen reader announces for the viewer's content. An NSTextView with no label is read as
    /// "text area", which says nothing about which file is in it (I19 T06).
    override func accessibilityLabel() -> String? {
        super.accessibilityLabel() ?? String(localized: "File contents")
    }

    /// Cmd+click on an identifier → go to definition (character index).
    var onCommandClick: ((Int) -> Void)?
    var copyText: String { string }
    var selectedText: String? {
        let r = selectedRange()
        guard r.length > 0, NSMaxRange(r) <= (string as NSString).length else { return nil }
        return (string as NSString).substring(with: r)
    }
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), let onCommandClick {
            let p = convert(event.locationInWindow, from: nil)
            onCommandClick(characterIndexForInsertion(at: p))
            return
        }
        super.mouseDown(with: event)
    }

    /// Esc must keep closing the viewer once the reader has clicked into the text.
    ///
    /// This is where it stopped: NSTextView maps Esc to `complete:` (word completion), so the key was
    /// consumed by a feature a read-only viewer does not have, and the container above never saw it.
    /// A visible find bar is the one thing Esc does mean locally — dismiss that first, as every other
    /// Mac text view does, and only pass the key on when there is nothing left to cancel here.
    override func cancelOperation(_ sender: Any?) {
        if let scroll = enclosingScrollView, scroll.isFindBarVisible {
            scroll.isFindBarVisible = false
            window?.makeFirstResponder(self)
            return
        }
        nextResponder?.tryToPerform(#selector(NSResponder.cancelOperation(_:)), with: sender)
    }
}

/// Virtual-scrolling text view (CoreText), backed by a bounded prefix of the file.
final class TextListerView: NSView, ListerScrollable, ListerLineAddressable, ViewerTextProviding, ViewerMarkable {
    private let lineHeight: CGFloat = 15
    private let font = TextListerView.monoFont
    private let charW: CGFloat
    /// Backing store: an in-memory byte array (small/formatted content) or a
    /// memory-mapped file streamed on demand (huge files, F-112).
    private enum Backing {
        case memory([UInt8])
        case mapped(FileSlice)
        var count: Int64 {
            switch self {
            case .memory(let b): return Int64(b.count)
            case .mapped(let s): return s.count
            }
        }
        /// Bytes in the half-open range [start, end).
        func bytes(_ start: Int64, _ end: Int64) -> [UInt8] {
            guard end > start, start >= 0 else { return [] }
            switch self {
            case .memory(let b):
                let lo = Int(start), hi = min(Int(end), b.count)
                return lo < hi ? Array(b[lo..<hi]) : []
            case .mapped(let s):
                return s.bytes(at: start, length: Int(end - start))
            }
        }
    }
    private let backing: Backing
    /// Byte offset of each displayable line's start.
    private let lineStarts: [Int64]
    /// Byte offset just past the last displayable line (== file size unless the
    /// scan stopped at `maxLines`).
    private let contentEnd: Int64
    /// True when the file exceeded `maxLines` and was clipped (F-112).
    let isTruncated: Bool
    private let encoding: String.Encoding

    private static let monoFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private static let charWidth = ("0" as NSString).size(withAttributes: [.font: monoFont]).width
    /// Cap on indexed/displayed lines so the view's frame height stays within
    /// AppKit's usable coordinate range (~16.7M pt) for pathological files (F-112).
    private static let maxLines = 1_048_576

    // Mouse text selection as (line, column) character positions.
    private var selStart: (line: Int, col: Int)?
    private var selEnd: (line: Int, col: Int)?
    // "Mark All" occurrence highlights (display-only, session-only).
    var viewerMarks: [ViewerMark] = []
    var nextMarkColorIndex = 0
    var nextMarkGroupID = 0
    func lineTextForMark(_ i: Int) -> String { lineString(i) }
    var lineCountForMarks: Int { lineStarts.count }
    func requestMarkRedraw() { needsDisplay = true }
    func scrollMarkLineToVisible(_ line: Int) { scroll(toLine: line + 1) }

    var copyText: String {
        let all = backing.bytes(0, contentEnd)
        return String(bytes: all, encoding: encoding) ?? String(decoding: all, as: UTF8.self)
    }

    init(bytes: [UInt8], encoding: String.Encoding? = nil) {
        // The byte-order mark is dropped from the content, not just detected: this view decodes per line
        // from the bytes, so a kept BOM appears as an invisible character at the start of line 1 — and
        // "column 1" then means the second character (F-376).
        let bytes = EncodingDetector.withoutBOM(bytes)
        self.backing = .memory(bytes)
        self.encoding = encoding ?? EncodingDetector.detect(Array(bytes.prefix(64 * 1024)))
        self.lineStarts = LineIndexer.lineStarts(in: bytes).map(Int64.init)
        self.contentEnd = Int64(bytes.count)
        self.isTruncated = false
        self.charW = Self.charWidth
        super.init(frame: .zero)
        setFrameSize(NSSize(width: 2000, height: CGFloat(max(1, lineStarts.count)) * lineHeight))
    }

    /// Stream a file directly from its memory map — no size cap beyond `maxLines`
    /// (F-112). Line text is decoded on demand from the mapping in `lineString`.
    init(slice: FileSlice, encoding: String.Encoding? = nil) {
        self.backing = .mapped(slice)
        self.encoding = encoding ?? EncodingDetector.detect(slice.bytes(at: 0, length: 64 * 1024))
        let index = slice.withUnsafeBytes { LineIndexer.lineStartOffsets(in: $0, maxLines: Self.maxLines) }
        self.lineStarts = index.starts
        self.contentEnd = index.contentEnd
        self.isTruncated = index.truncated
        self.charW = Self.charWidth
        super.init(frame: .zero)
        setFrameSize(NSSize(width: 2000, height: CGFloat(max(1, lineStarts.count)) * lineHeight))
    }

    override var acceptsFirstResponder: Bool { true }

    /// Decoded text of line `i` without the trailing CR/LF, read on demand.
    private func lineString(_ i: Int) -> String {
        guard i >= 0, i < lineStarts.count else { return "" }
        let start = lineStarts[i]
        let end = (i + 1 < lineStarts.count) ? lineStarts[i + 1] : contentEnd
        var slice = backing.bytes(start, end)
        while let last = slice.last, last == 0x0A || last == 0x0D { slice.removeLast() }
        return String(bytes: slice, encoding: encoding) ?? String(decoding: slice, as: UTF8.self)
    }

    private func position(at p: NSPoint) -> (line: Int, col: Int) {
        let line = max(0, min(Int(p.y / lineHeight), max(0, lineStarts.count - 1)))
        let count = lineString(line).count
        let col = max(0, min(Int((p.x - 4) / charW + 0.5), count))
        return (line, col)
    }

    private func ordered() -> (start: (line: Int, col: Int), end: (line: Int, col: Int))? {
        guard let a = selStart, let b = selEnd else { return nil }
        if a.line < b.line || (a.line == b.line && a.col <= b.col) { return (a, b) }
        return (b, a)
    }

    override func mouseDown(with event: NSEvent) {
        let p = position(at: convert(event.locationInWindow, from: nil))
        selStart = p; selEnd = p
        needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        selEnd = position(at: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    var selectedText: String? {
        guard let sel = ordered(), sel.start != sel.end else { return nil }
        if sel.start.line == sel.end.line {
            let chars = Array(lineString(sel.start.line))
            let lo = min(sel.start.col, chars.count), hi = min(sel.end.col, chars.count)
            return String(chars[lo..<hi])
        }
        var parts: [String] = []
        for line in sel.start.line...sel.end.line {
            let chars = Array(lineString(line))
            let lo = line == sel.start.line ? min(sel.start.col, chars.count) : 0
            let hi = line == sel.end.line ? min(sel.end.col, chars.count) : chars.count
            parts.append(String(chars[lo..<hi]))
        }
        return parts.joined(separator: "\n")
    }

    /// Back the view directly with a string (used for formatted JSON/XML output).
    convenience init(string: String) {
        self.init(bytes: Array(string.utf8), encoding: .utf8)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        Theme.current.listBackground.setFill()
        dirtyRect.fill()
        guard !lineStarts.isEmpty else { return }
        let first = max(0, Int(dirtyRect.minY / lineHeight))
        let last = min(lineStarts.count - 1, Int(dirtyRect.maxY / lineHeight))
        guard first <= last else { return }
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Theme.current.listText]
        drawViewerMarks(first: first, last: last, charW: charW, lineHeight: lineHeight)
        let sel = ordered()
        for i in first...last {
            let text = lineString(i)
            let y = CGFloat(i) * lineHeight
            // Selection highlight for this line.
            if let sel, i >= sel.start.line, i <= sel.end.line {
                let count = text.count
                let lo = i == sel.start.line ? min(sel.start.col, count) : 0
                let hi = i == sel.end.line ? min(sel.end.col, count) : count
                if hi > lo {
                    NSColor.selectedTextBackgroundColor.setFill()
                    NSRect(x: 4 + CGFloat(lo) * charW, y: y, width: CGFloat(hi - lo) * charW, height: lineHeight).fill()
                }
            }
            NSAttributedString(string: text, attributes: attrs).draw(at: NSPoint(x: 4, y: y))
        }
    }

    func scroll(toByteOffset offset: Int64) {
        let line = LineIndexer.line(containing: offset, in: lineStarts)
        scrollToVisible(NSRect(x: 0, y: CGFloat(line) * lineHeight, width: 1, height: lineHeight * 3))
    }

    /// Select the bytes a search matched, and bring them into view.
    ///
    /// The column has to be counted in *characters*, not bytes: this view's selection is a
    /// (line, column) pair over the decoded line, so a match after an umlaut would otherwise be
    /// highlighted a character to the right of itself, and further right the deeper into the line
    /// it sits. The bytes from the line start up to the match are decoded and counted, which is
    /// exact for every encoding this view indexes lines in.
    func showMatch(byteRange range: Range<Int64>) {
        guard !lineStarts.isEmpty else { return }
        let start = position(ofByte: range.lowerBound)
        // At least one character, so a zero-length match is still visible as a caret.
        let end = position(ofByte: Swift.max(range.lowerBound + 1, range.upperBound))
        selStart = start
        selEnd = end
        scroll(toByteOffset: range.lowerBound)
        needsDisplay = true
    }

    /// Where a byte offset falls, as the line holding it and the character column within it.
    private func position(ofByte offset: Int64) -> (line: Int, col: Int) {
        let line = LineIndexer.line(containing: offset, in: lineStarts)
        let lead = backing.bytes(lineStarts[line], Swift.min(offset, contentEnd))
        let decoded = String(bytes: lead, encoding: encoding) ?? String(decoding: lead, as: UTF8.self)
        return (line, decoded.count)
    }

    /// Scroll a 1-based line number into view (clamped to the indexed prefix).
    func scroll(toLine line: Int) {
        guard !lineStarts.isEmpty else { return }
        let idx = max(0, min(line - 1, lineStarts.count - 1))
        scrollToVisible(NSRect(x: 0, y: CGFloat(idx) * lineHeight, width: 1, height: lineHeight * 3))
    }

    var firstVisibleLine: Int {
        guard lineHeight > 0, !lineStarts.isEmpty else { return 1 }
        return min(Int(visibleRect.minY / lineHeight) + 1, lineStarts.count)
    }

    var lineCount: Int { lineStarts.count }
}

/// Virtual-scrolling hex view — renders only visible rows from the FileSlice.
final class HexListerView: NSView, ListerScrollable, ViewerTextProviding {
    private let rowHeight: CGFloat = 15
    private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private let cellW: CGFloat
    private let slice: FileSlice
    private let rowCount: Int
    private let bytesPerRow: Int   // configurable line width (F-111)
    // Drag byte-selection (inclusive byte offsets).
    private var selAnchor: Int64?
    private var selEnd: Int64?

    init(slice: FileSlice, bytesPerRow: Int = 16) {
        self.slice = slice
        self.bytesPerRow = max(1, bytesPerRow)
        self.rowCount = Int((slice.count + Int64(self.bytesPerRow) - 1) / Int64(self.bytesPerRow))
        self.cellW = ("0" as NSString).size(withAttributes: [.font: font]).width
        super.init(frame: .zero)
        let height = CGFloat(max(1, rowCount)) * rowHeight
        // Width scales with the line: offset(10) + hex columns(3 each) + gap(2) + ASCII.
        let cols = CGFloat(10 + self.bytesPerRow * 3 + 2 + self.bytesPerRow)
        setFrameSize(NSSize(width: max(680, cols * cellW + 8), height: height))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    /// Current inclusive selection [lo, hi], or nil.
    private var selection: (lo: Int64, hi: Int64)? {
        guard let a = selAnchor, let b = selEnd else { return nil }
        return (Swift.min(a, b), Swift.max(a, b))
    }

    /// Where the row starting at `offset` puts its columns. One description, shared with the
    /// formatter that draws the row — see `HexFormatter.RowLayout`.
    private func layout(forOffset offset: Int64) -> HexFormatter.RowLayout {
        HexFormatter.layout(offset: offset, bytesPerRow: bytesPerRow)
    }

    /// Left edge of the character at `column`, in the row's own coordinates.
    private func x(ofColumn column: Int) -> CGFloat { 4 + CGFloat(column) * cellW }

    private func hexOriginX(forOffset offset: Int64) -> CGFloat {
        x(ofColumn: layout(forOffset: offset).hexColumn)
    }

    /// The byte under `point`, in the hex columns or in the ASCII gutter.
    ///
    /// Both, because the gutter is where a reader looks when they are after text rather than
    /// bytes — it was the hex columns only, so the half of the row people actually read could not
    /// be selected. The hex editor had answered for both all along, which is what made the
    /// difference visible.
    private func byteIndex(at point: NSPoint) -> Int64? {
        let row = Int(point.y / rowHeight)
        guard row >= 0, row < rowCount else { return nil }
        let offset = Int64(row) * Int64(bytesPerRow)
        let rowLayout = layout(forOffset: offset)
        let asciiX = x(ofColumn: rowLayout.asciiColumn)
        let col: Int
        if point.x >= asciiX {
            col = Int((point.x - asciiX) / cellW)
        } else {
            // A pair is two characters wide with one of space after it, so a third of the run
            // belongs to the byte on its left — which is what the eye reads it as.
            col = Int((point.x - hexOriginX(forOffset: offset)) / (cellW * 3))
        }
        guard col >= 0, col < bytesPerRow else { return nil }
        let idx = offset + Int64(col)
        return idx < slice.count ? idx : nil
    }

    override func draw(_ dirtyRect: NSRect) {
        Theme.current.listBackground.setFill()
        dirtyRect.fill()
        guard rowCount > 0 else { return }
        let first = max(0, Int(dirtyRect.minY / rowHeight))
        let last = min(rowCount - 1, Int(dirtyRect.maxY / rowHeight))
        guard first <= last else { return }
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Theme.current.listText]
        let sel = selection
        for row in first...last {
            let offset = Int64(row) * Int64(bytesPerRow)
            // Highlight any selected byte cells in this row.
            if let sel {
                let rowLayout = layout(forOffset: offset)
                let originX = x(ofColumn: rowLayout.hexColumn)
                let asciiX = x(ofColumn: rowLayout.asciiColumn)
                for col in 0..<bytesPerRow {
                    let idx = offset + Int64(col)
                    if idx >= sel.lo, idx <= sel.hi, idx < slice.count {
                        NSColor.systemBlue.withAlphaComponent(0.30).setFill()
                        NSRect(x: originX + CGFloat(col * 3) * cellW - 1, y: CGFloat(row) * rowHeight,
                               width: cellW * 2 + 2, height: rowHeight).fill()
                        // The gutter too: a selection dragged there was drawn nowhere, which reads
                        // as the drag not having worked.
                        NSRect(x: asciiX + CGFloat(col) * cellW, y: CGFloat(row) * rowHeight,
                               width: cellW, height: rowHeight).fill()
                    }
                }
            }
            let rowBytes = slice.bytes(at: offset, length: bytesPerRow)
            let text = HexFormatter.row(bytes: rowBytes, offset: offset, bytesPerRow: bytesPerRow)
            NSAttributedString(string: text, attributes: attrs).draw(at: NSPoint(x: 4, y: CGFloat(row) * rowHeight))
        }
    }

    func scroll(toByteOffset offset: Int64) {
        let row = Int(offset / Int64(bytesPerRow))
        scrollToVisible(NSRect(x: 0, y: CGFloat(row) * rowHeight, width: 1, height: rowHeight * 3))
    }

    /// The current search hit, shown the way the strings panel shows a row: selected, not merely
    /// scrolled to.
    func showMatch(byteRange range: Range<Int64>) { select(byteRange: range) }

    /// Highlight `range` (half-open) and bring it into view — what the strings panel does
    /// when a row is chosen (F-489), and what a search hit does now too. The same selection the
    /// mouse makes, so "Copy selection as…" in the context menu then works on what was found.
    func select(byteRange range: Range<Int64>) {
        guard !range.isEmpty, range.lowerBound < slice.count else { return }
        selAnchor = range.lowerBound
        selEnd = Swift.min(range.upperBound, slice.count) - 1
        scroll(toByteOffset: range.lowerBound)
        needsDisplay = true
    }

    #if DEBUG
    /// Diagnostic: click the centre of a rendered column and report which byte that selected.
    ///
    /// A round trip, and that is the point. The point clicked is computed from
    /// `HexFormatter.RowLayout` — the formatter's own description of the row it draws — and mapped
    /// back to a byte by the view. If the two ever disagree the reported byte is wrong, which is the
    /// defect this exists for: the gutter half of every row could not be selected at all, and
    /// nothing on screen said so, because a row that is drawn correctly looks correct however the
    /// pointer is mapped. Goes through the real `mouseDown`, not around it.
    func automationClickColumn(_ kind: String, row: Int, byte index: Int) -> String {
        let offset = Int64(row) * Int64(bytesPerRow)
        let rowLayout = layout(forOffset: offset)
        let column = kind == "ascii" ? rowLayout.asciiColumn(forByte: index)
                                     : rowLayout.hexColumn(forByte: index)
        let point = NSPoint(x: x(ofColumn: column) + cellW / 2,
                            y: (CGFloat(row) + 0.5) * rowHeight)
        guard let event = NSEvent.mouseEvent(with: .leftMouseDown, location: convert(point, to: nil),
                                             modifierFlags: [], timestamp: 0,
                                             windowNumber: window?.windowNumber ?? 0, context: nil,
                                             eventNumber: 0, clickCount: 1, pressure: 1) else {
            return "clicked=noevent\n"
        }
        mouseDown(with: event)
        return "clickedcolumn=\(kind)/\(index)\n" + automationSelectionDescription
    }

    /// Diagnostic: the byte range currently highlighted, for the strings-panel scenarios.
    var automationSelectionDescription: String {
        guard let sel = selection else { return "hexselection=none\n" }
        return String(format: "hexselection=%08llx-%08llx\n", sel.lo, sel.hi)
    }
    #endif

    // MARK: - Mouse selection

    override func mouseDown(with event: NSEvent) {
        let idx = byteIndex(at: convert(event.locationInWindow, from: nil))
        selAnchor = idx
        selEnd = idx
        needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        if let idx = byteIndex(at: convert(event.locationInWindow, from: nil)) { selEnd = idx; needsDisplay = true }
    }

    // MARK: - Copy (⌘C)

    /// The selection as spaced hex — the same thing ⌘C produces in the hex *editor*.
    ///
    /// Conforming at all is the point. `canCopyText` asks whether the content view is a
    /// `ViewerTextProviding`, and this one was not, so ⌘C was greyed out in the hex representation
    /// while the context menu offered four ways to copy the same selection. Selecting bytes and
    /// finding the obvious key does nothing is a poor way to learn that the menu is the only route
    /// — and it got worse once the gutter became selectable and search hits started being selected,
    /// since both produce a selection whose natural next step is ⌘C.
    var selectedText: String? {
        guard let bytes = selectedBytes(), !bytes.isEmpty else { return nil }
        return ByteFormatter.format(bytes, as: .hex)
    }

    /// The whole file as a hex dump, for ⌘C with nothing selected.
    ///
    /// Only ever reached below the viewer's copy-everything limit, which the caller checks against
    /// the *file* size before asking for this — worth knowing here because a dump is about five
    /// times the bytes it describes, so that limit is generous in this representation and stingy in
    /// none of the others.
    var copyText: String {
        (0..<rowCount).map { row -> String in
            let offset = Int64(row) * Int64(bytesPerRow)
            return HexFormatter.row(bytes: slice.bytes(at: offset, length: bytesPerRow),
                                    offset: offset, bytesPerRow: bytesPerRow)
        }.joined(separator: "\n")
    }

    private func selectedBytes() -> [UInt8]? {
        guard let sel = selection else { return nil }
        return slice.bytes(at: sel.lo, length: Int(sel.hi - sel.lo + 1))
    }

    // MARK: - Copy (selection if any, else the row under the pointer)

    override func menu(for event: NSEvent) -> NSMenu? {
        let p = convert(event.locationInWindow, from: nil)
        let row = Int(p.y / rowHeight)
        guard row >= 0, row < rowCount else { return nil }
        let menu = NSMenu()

        if let sel = selection, let selBytes = selectedBytes(), !selBytes.isEmpty {
            for format in ByteFormat.allCases {
                let item = NSMenuItem(title: String(format: NSLocalizedString("Copy selection as %@", comment: ""), format.label),
                                      action: #selector(copyString(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = ByteFormatter.format(selBytes, as: format)
                menu.addItem(item)
            }
            let rangeItem = NSMenuItem(title: String(format: NSLocalizedString("Copy range (0x%llX–0x%llX)", comment: ""), sel.lo, sel.hi),
                                       action: #selector(copyString(_:)), keyEquivalent: "")
            rangeItem.target = self
            rangeItem.representedObject = String(format: "0x%llX-0x%llX", sel.lo, sel.hi)
            menu.addItem(rangeItem)
            menu.addItem(.separator())
        }

        let offset = Int64(row) * Int64(bytesPerRow)
        let rowBytes = slice.bytes(at: offset, length: bytesPerRow)
        for format in ByteFormat.allCases {
            let item = NSMenuItem(title: String(format: NSLocalizedString("Copy row as %@", comment: ""), format.label),
                                  action: #selector(copyString(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ByteFormatter.format(rowBytes, as: format)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let offItem = NSMenuItem(title: String(format: NSLocalizedString("Copy offset (0x%llX)", comment: ""), offset),
                                 action: #selector(copyString(_:)), keyEquivalent: "")
        offItem.target = self
        offItem.representedObject = String(format: "0x%llX", offset)
        menu.addItem(offItem)
        return menu
    }

    @objc private func copyString(_ sender: NSMenuItem) {
        guard let s = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}

/// Data source / delegate for the collapsible XML tree outline.
final class XMLOutlineController: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private let root: XMLTreeNode
    init(root: XMLTreeNode) { self.root = root }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? XMLTreeNode)?.children.count ?? 1   // nil → the single root
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let node = item as? XMLTreeNode else { return root }
        return node.children[index]
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !((item as? XMLTreeNode)?.children.isEmpty ?? true)
    }
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let field = (outlineView.makeView(withIdentifier: id, owner: self) as? NSTextField) ?? {
            let f = NSTextField(labelWithString: "")
            f.identifier = id
            f.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            f.isBordered = false
            f.drawsBackground = false
            return f
        }()
        field.stringValue = (item as? XMLTreeNode)?.label ?? ""
        field.textColor = Theme.current.listText
        return field
    }
}

/// Text view that colours source code using SyntaxHighlighter tokens.
final class CodeListerView: NSView, ListerScrollable, ListerLineAddressable, ViewerTextProviding, ViewerMarkable {
    private let lineHeight: CGFloat = 15
    private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private let charW: CGFloat
    private let chars: [Character]
    private let lineRanges: [Range<Int>]     // per-line character ranges (newline excluded)
    /// Byte offset of each line's start, in `encoding`.
    ///
    /// This view is built from *decoded text* and so has no idea, on its own, where a byte offset
    /// falls — which is why `scroll(toByteOffset:)` used to say "best-effort: treat the search byte
    /// offset as a character offset". That holds for pure ASCII and drifts everywhere else, further
    /// with every umlaut and every CRLF above the target, and a *selection* built on a drifting
    /// offset is worse than no selection: it points confidently at the wrong characters. Costs one
    /// pass over the text at construction, next to the syntax pass already made there.
    private let lineByteStarts: [Int64]
    private let encoding: String.Encoding
    private let tokens: [SyntaxToken]
    private var selStart: (line: Int, col: Int)?
    private var selEnd: (line: Int, col: Int)?
    // "Mark All" occurrence highlights (display-only, session-only).
    var viewerMarks: [ViewerMark] = []
    var nextMarkColorIndex = 0
    var nextMarkGroupID = 0
    func lineTextForMark(_ i: Int) -> String {
        guard lineRanges.indices.contains(i) else { return "" }
        return String(chars[lineRanges[i]])
    }
    var lineCountForMarks: Int { lineRanges.count }
    func requestMarkRedraw() { needsDisplay = true }
    func scrollMarkLineToVisible(_ line: Int) { scroll(toLine: line + 1) }

    var copyText: String { String(chars) }

    /// - Parameter encoding: what the file's bytes were decoded from, so a search hit's byte offset
    ///   can be mapped back to a character. Formatted content is a Swift string of this view's own
    ///   making and is UTF-8 by construction.
    init(text: String, language: SyntaxLanguage, encoding: String.Encoding = .utf8) {
        self.encoding = encoding
        self.chars = Array(text)
        self.tokens = SyntaxHighlighter.tokens(text, language: language)
        self.charW = ("0" as NSString).size(withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)]).width
        var ranges: [Range<Int>] = []
        var start = 0
        // `isNewline`, not `== "\n"`: `chars` is an array of *Characters*, and in Swift a CRLF is one
        // Character equal to neither "\r" nor "\n". A file with Windows line endings therefore produced
        // a single range — the whole file rendered as one line, with go-to-line, the marks panel and the
        // per-line notes all pointing at nothing. Measured: 4 ranges for LF, 1 for the same text as CRLF.
        for (i, ch) in chars.enumerated() where ch.isNewline { ranges.append(start..<i); start = i + 1 }
        ranges.append(start..<chars.count)
        self.lineRanges = ranges
        // The line's own characters plus the newline that ended it. `chars[range.upperBound]` is
        // that newline — one Character, which for CRLF is two bytes, which is exactly the case the
        // range-building above exists for.
        var byteStarts: [Int64] = []
        byteStarts.reserveCapacity(ranges.count)
        var byteOffset: Int64 = 0
        for range in ranges {
            byteStarts.append(byteOffset)
            byteOffset += Self.byteCount(String(chars[range]), in: encoding)
            if range.upperBound < chars.count {
                byteOffset += Self.byteCount(String(chars[range.upperBound]), in: encoding)
            }
        }
        self.lineByteStarts = byteStarts
        super.init(frame: .zero)
        setFrameSize(NSSize(width: 2000, height: CGFloat(max(1, ranges.count)) * lineHeight))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    private func position(at p: NSPoint) -> (line: Int, col: Int) {
        let line = max(0, min(Int(p.y / lineHeight), max(0, lineRanges.count - 1)))
        let count = lineRanges[line].count
        let col = max(0, min(Int((p.x - 4) / charW + 0.5), count))
        return (line, col)
    }
    private func ordered() -> (start: (line: Int, col: Int), end: (line: Int, col: Int))? {
        guard let a = selStart, let b = selEnd else { return nil }
        if a.line < b.line || (a.line == b.line && a.col <= b.col) { return (a, b) }
        return (b, a)
    }
    override func mouseDown(with event: NSEvent) {
        let p = position(at: convert(event.locationInWindow, from: nil)); selStart = p; selEnd = p; needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        selEnd = position(at: convert(event.locationInWindow, from: nil)); needsDisplay = true
    }
    var selectedText: String? {
        guard let sel = ordered(), sel.start != sel.end else { return nil }
        var parts: [String] = []
        for line in sel.start.line...sel.end.line {
            let lr = lineRanges[line]
            let lineChars = Array(chars[lr])
            let lo = line == sel.start.line ? min(sel.start.col, lineChars.count) : 0
            let hi = line == sel.end.line ? min(sel.end.col, lineChars.count) : lineChars.count
            parts.append(String(lineChars[lo..<hi]))
        }
        return parts.joined(separator: "\n")
    }

    override func draw(_ dirtyRect: NSRect) {
        Theme.current.listBackground.setFill()
        dirtyRect.fill()
        guard !lineRanges.isEmpty else { return }
        let first = max(0, Int(dirtyRect.minY / lineHeight))
        let last = min(lineRanges.count - 1, Int(dirtyRect.maxY / lineHeight))
        guard first <= last else { return }
        drawViewerMarks(first: first, last: last, charW: charW, lineHeight: lineHeight)
        let sel = ordered()
        for i in first...last {
            if let sel, i >= sel.start.line, i <= sel.end.line {
                let count = lineRanges[i].count
                let lo = i == sel.start.line ? min(sel.start.col, count) : 0
                let hi = i == sel.end.line ? min(sel.end.col, count) : count
                if hi > lo {
                    NSColor.selectedTextBackgroundColor.setFill()
                    NSRect(x: 4 + CGFloat(lo) * charW, y: CGFloat(i) * lineHeight,
                           width: CGFloat(hi - lo) * charW, height: lineHeight).fill()
                }
            }
            attributedLine(lineRanges[i]).draw(at: NSPoint(x: 4, y: CGFloat(i) * lineHeight))
        }
    }

    private func attributedLine(_ lr: Range<Int>) -> NSAttributedString {
        let lineChars = Array(chars[lr])
        let attr = NSMutableAttributedString(string: String(lineChars),
            attributes: [.font: font, .foregroundColor: Theme.current.listText])
        // One pass for the whole line, not one copy of the line's prefix per token. This is drawing code,
        // called for every visible line on every scroll, and it used to ask
        // `String(lineChars[0..<lo]).utf16.count` — quadratic in the line's length. On a 2 MB JSON Lines
        // file (thirty records of ~68,000 characters, thousands of tokens each) that is about 10^8
        // character copies per drawn line on the main thread: the viewer froze for as long as the reader
        // kept scrolling, which is exactly how it was found.
        let offsets = UTF16OffsetTable(lineChars)
        var k = firstTokenIndex(endingAfter: lr.lowerBound)
        while k < tokens.count, tokens[k].range.lowerBound < lr.upperBound {
            let t = tokens[k]; k += 1
            let lo = max(t.range.lowerBound, lr.lowerBound) - lr.lowerBound
            let hi = min(t.range.upperBound, lr.upperBound) - lr.lowerBound
            guard lo < hi, lo >= 0, hi <= lineChars.count else { continue }
            let range = offsets.range(lo, hi)
            if range.length > 0 {
                attr.addAttribute(.foregroundColor, value: SyntaxTheme.color(t.kind), range: range)
            }
        }
        return attr
    }

    #if DEBUG
    /// Diagnostic: build the attributed string for the first `lines` lines and report the milliseconds.
    ///
    /// This *is* the drawing cost: `draw(_:)` calls `attributedLine` once per visible line, so a screenful
    /// of a file with very long lines costs what this measures. Timed here rather than through `display()`,
    /// which draws only the visible rect and therefore reports 0 ms for a window that is not on screen —
    /// a measurement that would have looked like a fix (F-414).
    func automationAttributedLineCost(lines: Int) -> Int {
        let start = Date()
        for i in 0..<min(lines, lineRanges.count) { _ = attributedLine(lineRanges[i]) }
        return Int(Date().timeIntervalSince(start) * 1000)
    }
    #endif

    /// First token whose range ends after `pos` (binary search; tokens are ordered).
    private func firstTokenIndex(endingAfter pos: Int) -> Int {
        var lo = 0, hi = tokens.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if tokens[mid].range.upperBound <= pos { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    func scroll(toByteOffset offset: Int64) {
        let line = LineIndexer.line(containing: offset, in: lineByteStarts)
        scrollToVisible(NSRect(x: 0, y: CGFloat(line) * lineHeight, width: 1, height: lineHeight * 3))
    }

    /// Select the bytes a search matched, and bring them into view.
    func showMatch(byteRange range: Range<Int64>) {
        guard !lineByteStarts.isEmpty else { return }
        selStart = position(ofByte: range.lowerBound)
        // At least one character, so a zero-length match is still visible as a caret.
        selEnd = position(ofByte: Swift.max(range.lowerBound + 1, range.upperBound))
        scroll(toByteOffset: range.lowerBound)
        needsDisplay = true
    }

    /// Where a byte offset falls, as the line holding it and the character column within it.
    private func position(ofByte offset: Int64) -> (line: Int, col: Int) {
        let line = LineIndexer.line(containing: offset, in: lineByteStarts)
        guard lineRanges.indices.contains(line) else { return (line, 0) }
        var remaining = offset - lineByteStarts[line]
        var col = 0
        for character in chars[lineRanges[line]] {
            let size = Self.byteCount(String(character), in: encoding)
            if remaining < size { break }
            remaining -= size
            col += 1
        }
        return (line, col)
    }

    /// How many bytes `text` occupies in `encoding`, falling back to UTF-8 for anything it cannot
    /// be expressed in — the same fallback the line decoding uses, so the two agree.
    private static func byteCount(_ text: String, in encoding: String.Encoding) -> Int64 {
        Int64(text.data(using: encoding)?.count ?? text.utf8.count)
    }

    func scroll(toLine line: Int) {
        guard !lineRanges.isEmpty else { return }
        let idx = max(0, min(line - 1, lineRanges.count - 1))
        scrollToVisible(NSRect(x: 0, y: CGFloat(idx) * lineHeight, width: 1, height: lineHeight * 3))
    }

    var firstVisibleLine: Int {
        guard lineHeight > 0, !lineRanges.isEmpty else { return 1 }
        return min(Int(visibleRect.minY / lineHeight) + 1, lineRanges.count)
    }

    var lineCount: Int { lineRanges.count }
}

// MARK: - Contextual menu-bar menu (TODOS #189)

extension ListerWindowController: WindowContextMenuProviding {
    /// The viewer's capabilities: read-only, all representations, encoding,
    /// format, XML tree, XPath, go-to, marks, multi-file navigation.
    fileprivate var documentCaps: DocumentMenuCaps {
        var c = DocumentMenuCaps()
        c.reprText = true; c.reprCode = true; c.reprHex = true
        c.reprImage = true; c.reprAuto = true
        // Offered only when a plugin actually claims this file: the representation exists because a
        // plugin provides it, and a menu item that can do nothing is worse than no menu item.
        c.reprRendered = files.indices.contains(index)
            && pluginClaiming(path: files[index], slice: slice) != nil
        c.encoding = true; c.format = true; c.xmlTree = true; c.xpath = true
        c.goto = true
        // Shift+F3 has always worked here — `docFindPrev` is implemented and the key handler
        // calls it — but the flag was never set, so the menu did not say so and the command
        // was reachable only by knowing it existed.
        c.findPrev = true
        c.marks = true
        c.markNav = true
        c.saveAs = true; c.printable = true   // F-121
        c.zoom = true                          // F-389 (enabled per representation below)
        c.multiFile = files.count > 1
        // Only offered when the Notes plugin is installed: a menu item that can do nothing is worse
        // than no menu item.
        c.note = ListerNoteBridge.shared != nil
        return c
    }

    // MARK: - Action availability per representation
    //
    // documentCaps above describes what this *window kind* can offer, so the menus
    // are built once. What a given action can do depends on the representation
    // currently on screen, and the two are not the same thing: rendered Markdown has
    // no text storage, no mark backend and nothing byte-addressable to scroll.
    //
    // Previously the actions just returned early — `if mode == .text || mode == .code`
    // — while their buttons and menu items stayed enabled. Clicking Format, Encoding,
    // Mark All or Marks on a rendered Markdown file therefore did nothing at all, with
    // no hint that it could not work. Everything now answers through this one
    // predicate: validateUserInterfaceItem drives the menus, refreshActionEnablement
    // drives the toolbar buttons (plain NSButtons do not validate themselves).

    /// Text transformations need real text storage in a text/code representation.
    private var canTransformText: Bool { mode == .text || mode == .code }
    /// Lowercased extension of the file on screen.
    private var currentExtension: String {
        files.indices.contains(index) ? (files[index] as NSString).pathExtension.lowercased() : ""
    }
    /// Occurrence marking needs one of the two mark backends.
    private var canMark: Bool { hasMarkBackend }
    /// Copy takes the whole text of the displayed view, or forwards the standard
    /// `copy:` action to a view that implements it (WebKit's rendered page, a plugin
    /// view that supports copying).
    private var canCopyText: Bool {
        if contentView is ViewerTextProviding { return true }
        if mode == .plugin, let pv = pluginView?.view { return pv.responds(to: Selector(("copy:"))) }
        return false
    }
    /// Search has four backends: the native find bar in a text view, WebKit's own find
    /// on a rendered page, the plugin's search, or a byte-offset scan — the last one
    /// needs a view that can be scrolled to an offset.
    private var canSearch: Bool {
        textContentView != nil || mode == .plugin || contentView is ListerScrollable
    }
    /// Go To addresses a line or a byte offset. The rendered page has neither, so it
    /// stays unavailable there even though searching works.
    private var canGoTo: Bool {
        textContentView != nil || contentView is ListerScrollable
    }

    /// Whether `selector` can do anything in the representation on screen.
    fileprivate func supportsAction(_ selector: Selector) -> Bool {
        switch selector {
        case DocumentAction.format:
            // Text representation *and* something that can format this extension: the set of
            // formats is open-ended now (built-ins, installed tools, plugins, user config),
            // so the registry is the only thing that knows.
            return canTransformText && FormatterRegistry.shared.canFormat(extension: currentExtension)
        case DocumentAction.xmlTree, DocumentAction.xpath, DocumentAction.cycleEncoding:
            return canTransformText
        case DocumentAction.zoomIn, DocumentAction.zoomOut,
             DocumentAction.zoomActual, DocumentAction.zoomFit:
            // Only where there is a picture. In a text representation ⌘+ would otherwise be a menu item
            // that looks available and changes nothing — the font size is the bare +/- keys (F-389).
            return mode == .image && imageZoom.hasImage
        case DocumentAction.markAll, DocumentAction.count,
             DocumentAction.clearAllMarks, DocumentAction.toggleMarksPanel:
            return canMark
        case DocumentAction.copy:
            return canCopyText
        case DocumentAction.find, DocumentAction.findNext, DocumentAction.findPrev:
            return canSearch
        case DocumentAction.goToLocation:
            return canGoTo
        case DocumentAction.nextFile, DocumentAction.prevFile:
            return files.count > 1
        case DocumentAction.note:
            // Needs a line to bind to, so the same representations that can be addressed by line —
            // in a hex dump "line 40" would mean a different place than the one on screen.
            return ListerNoteBridge.shared != nil
                && (textContentView != nil || contentView is ListerLineAddressable)
        default:
            return true   // Save As, Print, representation switching, reload…
        }
    }

    /// Re-validate the toolbar buttons. NSButton has no validation of its own, so this
    /// runs after every content rebuild (see rebuildContent's defer).
    private func refreshActionEnablement() {
        for (selector, button) in actionButtons {
            button.isEnabled = supportsAction(selector)
        }
    }

    /// Menu items and other validated controls route through the same predicate, so the
    /// Tools menu and the context menu grey out exactly what the toolbar does.
    func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        guard let action = item.action else { return true }
        return supportsAction(action)
    }

    // Read-only content: Copy (whole text or the current selection).
    func makeEditMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Edit"))
        AppMenu.editItem(menu, String(localized: "Copy"), action: DocumentAction.copy, target: self, key: "c")
        // target: nil routes selectAll: through the responder chain, so WebKit selects
        // the rendered page and an NSTextView selects its text — each doing the right
        // thing natively. AppKit also greys the item out for the custom lister views,
        // which do not implement it. Listed explicitly so ⌘A is discoverable, and so it
        // is a menu key equivalent rather than something the key handler has to know.
        AppMenu.editItem(menu, String(localized: "Select All"), action: Selector(("selectAll:")),
                         target: nil, key: "a")
        // Cut and Paste exist for the *dialogs* this window opens — a viewer has nothing to paste into,
        // and both items grey themselves out accordingly when no field is being edited.
        AppMenu.appendTextClipboardItems(to: menu)
        return menu
    }

    func toolMenus() -> [NSMenu] {
        DocumentMenus.toolMenus(caps: documentCaps, editMenu: makeEditMenu(), target: self)
    }
}

// MARK: - Unified document actions (shared menu taxonomy)

extension ListerWindowController {
    @objc func docReprText() { vmText() }
    @objc func docReprCode() { vmCode() }
    @objc func docReprHex() { vmHex() }
    @objc func docReprImage() { vmImage() }
    @objc func docReprRendered() { vmPlugin() }
    @objc func docReprAuto() { vmAuto() }
    @objc func docCycleEncoding() { vmEncoding() }
    @objc func docFormat() { vmFormat() }
    @objc func docXMLTree() { vmXMLTree() }
    @objc func docXPath() { vmXPath() }
    @objc func docFind() { vmFind() }
    @objc func docFindNext() { vmFindNext() }
    @objc func docGoto() { vmGoto() }
    /// Next / Previous Mark (F-121 parity): step through the highlights Mark All made.
    ///
    /// Two backends, because marks have two: the NSTextView path keeps them as character ranges and
    /// the virtual views as (line, column) pairs. The editor has had this since it had marks; the
    /// viewer could make them and then only reach them by clicking rows in the panel.
    @objc func docNextMark() { stepMark(forwards: true) }
    @objc func docPrevMark() { stepMark(forwards: false) }

    private func stepMark(forwards: Bool) {
        if let marks = textMarks, let textView = textContentView {
            let caret = textView.selectedRange().location
            guard let range = forwards ? marks.nextMark(after: caret)
                                       : marks.previousMark(before: caret) else {
                NSSound.beep(); return
            }
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
            return
        }
        // A view that only scrolls has no caret, so the topmost visible line stands in for one —
        // the same thing `firstVisibleLine` exists for elsewhere.
        guard let markable, let addressable = contentView as? ListerLineAddressable else {
            NSSound.beep(); return
        }
        let sorted = markable.sortedViewerMarks
        let here = addressable.firstVisibleLine - 1          // firstVisibleLine is 1-based
        let target = forwards ? sorted.first(where: { $0.line > here })
                              : sorted.last(where: { $0.line < here })
        guard let target else { NSSound.beep(); return }
        markable.scrollMarkLineToVisible(target.line)
    }

    @objc func docMarkAll() { vmMarkAll() }
    @objc func docCount() { vmCount() }
    @objc func docToggleMarksPanel() { vmMarksList() }
    @objc func docClearAllMarks() { vmClearAllMarks() }
    @objc func docNextFile() { vmNextFile() }
    @objc func docPrevFile() { vmPrevFile() }
    @objc func docCopy() { vmCopyAll() }
    @objc func docReload() { loadCurrent(autoMode: false) }
    @objc func docSaveAs() { saveAs() }
    @objc func docPrint() { printDocument() }

    /// Save As… (F-121): for a transformable text/code representation, write the
    /// currently displayed text; otherwise export a faithful copy of the file.
    private func saveAs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (files[index] as NSString).lastPathComponent
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window ?? NSApp.keyWindow ?? NSWindow()) { [weak self] resp in
            guard let self, resp == .OK, let url = panel.url else { return }
            do {
                if (self.mode == .text || self.mode == .code), let text = self.textContentView?.string {
                    try text.data(using: .utf8)?.write(to: url)
                } else {
                    let src = URL(fileURLWithPath: self.files[self.index])
                    if url.path != src.path {
                        try? FileManager.default.removeItem(at: url)
                        try FileManager.default.copyItem(at: src, to: url)
                    }
                }
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    /// Print… (F-121): print the current content view (text, hex dump, image, …).
    private func printDocument() {
        guard let view = contentView else { NSSound.beep(); return }
        let info = NSPrintInfo.shared
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        let op = NSPrintOperation(view: view, printInfo: info)
        op.jobTitle = (files[index] as NSString).lastPathComponent
        op.runModal(for: window ?? NSApp.keyWindow ?? NSWindow(), delegate: nil, didRun: nil, contextInfo: nil)
    }
}

// MARK: - Docked marks panel (host + split constraints)

extension ListerWindowController: MarksPanelHost {
    func marksPanelGroups() -> [MarksGroupVM] {
        let backend = textMarks?.panelGroups() ?? markable?.panelGroups() ?? []
        guard !annotatedLines.isEmpty else { return backend }
        // Annotations first: they were written on purpose and outlive the session, unlike a search's
        // marks. Group id -1 keeps them out of the backend's numbering.
        // One index for the whole group: building it per occurrence would rescan the document once per
        // note, which is the sort of thing nobody notices until a 50 MB log has forty of them.
        let snippets = lineSnippets(for: annotatedLines)
        let notes = MarksGroupVM(id: Self.notesGroupID, term: String(localized: "Notes"),
                                 color: .systemYellow,
                                 occurrences: zip(annotatedLines, snippets).map {
                                     MarksOccurrenceVM(line: $0, text: $1)
                                 })
        return [notes] + backend
    }

    /// Group id for the annotations, outside the backend's range.
    private static let notesGroupID = -1

    /// A little of each annotated line, so the list reads as text rather than as numbers.
    ///
    /// Only the text representations can answer this; for the others the notes still appear, with their
    /// line numbers and no preview, which is better than hiding them.
    private func lineSnippets(for lines: [Int]) -> [String] {
        if let tv = textContentView {
            let ns = tv.string as NSString
            let starts = EditorLineIndex(text: ns).starts
            return lines.map { line in
                guard starts.indices.contains(line - 1) else { return "" }
                let range = ns.lineRange(for: NSRange(location: starts[line - 1], length: 0))
                return ns.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        // The virtual view can hand over one line at a time — it is how the marks panel already reads
        // them. Asking it for `copyText` instead would decode the entire file to show a handful of
        // snippets, which for the files this view exists for is the whole file in memory.
        guard let view = contentView as? ViewerMarkable else { return lines.map { _ in "" } }
        return lines.map { line in
            guard line >= 1, line <= view.lineCountForMarks else { return "" }
            return view.lineTextForMark(line - 1).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func marksPanelReveal(groupID: Int, occurrenceIndex: Int) {
        if groupID == Self.notesGroupID {
            guard annotatedLines.indices.contains(occurrenceIndex) else { return }
            revealLine(annotatedLines[occurrenceIndex])
            return
        }
        if let tm = textMarks { tm.reveal(groupID: groupID, occurrenceIndex: occurrenceIndex) }
        else { markable?.reveal(groupID: groupID, occurrenceIndex: occurrenceIndex) }
    }
    func marksPanelRemoveOccurrence(groupID: Int, occurrenceIndex: Int) {
        // A note is not a search hit: it was written on purpose, and the panel's close button must not
        // be a way to lose it by accident. Removing it happens in the note editor.
        if groupID == Self.notesGroupID { NSSound.beep(); return }
        if let tm = textMarks { tm.removeOccurrence(groupID: groupID, at: occurrenceIndex) }
        else { markable?.removeOccurrence(groupID: groupID, at: occurrenceIndex) }
    }
    func marksPanelRemoveGroup(groupID: Int) {
        if groupID == Self.notesGroupID { annotatedLines = []; marks.reload(); return }
        if let tm = textMarks { tm.removeGroup(groupID) } else { markable?.removeGroup(groupID) }
    }
    func marksPanelClearAll() { backendClearAll() }
}
