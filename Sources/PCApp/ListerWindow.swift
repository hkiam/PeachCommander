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
    enum Mode { case text, hex, image, media, web, plugin, directory, code, xmlTree, binary }

    /// Audio/video player for `.media` mode (paused/cleared when the view changes).
    private var avPlayer: AVPlayer?

    /// File extensions the rendered (web) mode understands.
    private static let markdownExts: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn", "mdwn"]
    private static let htmlExts: Set<String> = ["html", "htm", "xhtml"]
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
    /// Which formatter produced the current output, shown in the status line. Worth
    /// surfacing because the winning formatter depends on what is installed and
    /// configured — otherwise "formatted" would look inconsistent between machines.
    private var formatterUsed: String?
    /// Parsed XML tree + its outline data source, for the collapsible tree mode.
    private var xmlRoot: XMLTreeNode?
    private var xmlOutline: XMLOutlineController?

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
    private var bracketRanges: [NSRange] = []
    // Collapsible minimap on the right (for text/code content).
    private var minimap: MinimapView!
    private var minimapWidth: NSLayoutConstraint!
    private var minimapVisible = false
    private let minimapToggle = NSButton()
    /// Toolbar action buttons paired with their selector, for per-representation
    /// enablement (see refreshActionEnablement).
    private var actionButtons: [(Selector, NSButton)] = []
    private var webView: ListerWebView?
    private weak var container: NSView?

    /// Available PLX lister plugins, consulted before the built-in modes.
    private let plugins: [PLXLister]
    /// The currently embedded plugin view, if the active mode is `.plugin`.
    private var pluginView: (lister: PLXLister, handle: PLXHandle, view: NSView)?
    /// Index into the current file's claiming plugins (F-119); reset per file.
    private var pluginChoice = 0
    /// Set when the viewer is showing a directory summary rather than a file.
    private let directoryPath: String?

    init(files: [String], startIndex: Int, plugins: [PLXLister] = []) {
        self.files = files
        self.index = max(0, min(startIndex, files.count - 1))
        self.plugins = plugins
        self.directoryPath = nil
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

        minimap = MinimapView(textView: nil, scrollView: scrollView)
        minimap.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(toolbar)
        container.addSubview(sidebar)
        container.addSubview(splitView)
        container.addSubview(minimap)
        container.addSubview(statusBar)
        symbolWidth = sidebar.widthAnchor.constraint(equalToConstant: 0)   // start collapsed
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
            splitView.trailingAnchor.constraint(equalTo: minimap.leadingAnchor),
            splitView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
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

        for (title, tag) in [(String(localized: "Auto"), 0), ("Text", 1), ("Code", 2),
                             ("Hex", 3), ("Image", 4), (String(localized: "Rendered"), 5)] {
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

    @objc private func toolbarReprChanged(_ sender: NSPopUpButton) {
        let tag = sender.selectedTag()
        if tag >= 100 {                        // a specific plugin (F-119)
            pluginChoice = tag - 100
            setModeManually(.plugin)
            return
        }
        switch tag {
        case 1: vmText(); case 2: vmCode(); case 3: vmHex()
        case 4: vmImage(); case 5: vmWeb(); default: vmAuto()
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
        if markdownExts.contains(ext) || htmlExts.contains(ext) {
            return .web
        }
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
        defer { refreshSymbols(); refreshMinimap(); refreshActionEnablement(); refreshAnnotations() }

        // The content view (and its marks) is about to be replaced — collapse
        // the marks panel so it doesn't show stale entries for the old view.
        marks.hide()

        // Always drop any previously embedded plugin view / media player before
        // re-rendering (a still-playing AVPlayer would keep sounding otherwise).
        teardownPlugin()
        teardownMedia()
        isFormatted = false
        formatterUsed = nil

        if mode == .plugin {
            if embedPlugin(for: path, slice: slice) {
                webView?.isHidden = true
                scrollView.isHidden = true
                updateStatus()
                return
            }
            // No plugin claimed it (or it declined) → fall back to a built-in mode.
            mode = Self.autoMode(for: path, slice: slice)
        }

        if mode == .web {
            showWeb(for: path, slice: slice)
            updateStatus()
            return
        }

        // Non-web modes use the scroll view; hide any web view.
        webView?.isHidden = true
        scrollView.isHidden = false
        scrollView.allowsMagnification = false   // enabled only for image mode (F-115)
        // Leaving the image behind: let go of the bitmap and stop centring the document, or a text file
        // with two lines in it would come up centred in the middle of the window (F-389).
        if mode != .image, zoomImageView.image != nil {
            imageZoom.clear()
        }
        if let container, window?.firstResponder === webView { window?.makeFirstResponder(container) }
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
                view = CodeListerView(text: decodedText(slice), language: language)
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
        case .web, .plugin, .directory:
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
        guard let handle = lister.load(parent: parentPtr, file: path, showFlags: flags) else { return false }
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
        let area = marks.splitView
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: area.topAnchor),
            view.leadingAnchor.constraint(equalTo: area.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: area.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: area.bottomAnchor)
        ])
        pluginView = (lister, handle, view)
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
        webView?.isHidden = true
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

    /// Render Markdown or HTML into a (lazily created) WKWebView layered over the
    /// scroll-view area. JavaScript is disabled, and network loads are blocked, so a
    /// previewed page cannot run active content or phone home; local sibling
    /// resources still load.
    ///
    /// The second half used to be a claim rather than a fact. Disabling JavaScript stops scripts, not
    /// `<img src="http://…">` — measured with a local server as the witness, and the request went out.
    /// So a page previewed here reports back that it was opened, and from where. The generated Markdown
    /// document carries a Content-Security-Policy for this, but an HTML file the user opens is not ours
    /// to add a header to, and that path loads the file directly; the content rule list below covers
    /// both, since it is applied to the web view rather than to the document.
    private func showWeb(for path: String, slice: FileSlice) {
        let web = ensureWebView()
        scrollView.isHidden = true
        web.isHidden = false
        // The rendered page *is* the content view now. Without this, contentView kept
        // pointing at whatever the previous representation built: `markable` and
        // `ViewerTextProviding` still resolved against that invisible view, so Mark
        // All and Copy silently operated on the previously viewed file, and Print
        // printed it. A WKWebView conforms to none of those protocols, so assigning it
        // makes every capability below answer truthfully.
        contentView = web
        textMarks = nil
        // Focus the web view so arrows / space / PageUp-Down scroll the page natively.
        DispatchQueue.main.async { [weak self] in self?.window?.makeFirstResponder(web) }

        let url = URL(fileURLWithPath: path)
        let dir = url.deletingLastPathComponent()
        let ext = (path as NSString).pathExtension.lowercased()

        loadWithoutNetwork(web) {
            if Self.htmlExts.contains(ext) {
                let cap = 16 * 1024 * 1024
                let raw = slice.bytes(at: 0, length: min(cap, Int(slice.count)))
                if Self.declaresCharset(raw) {
                    // Charset is known to WebKit — load the file directly so relative
                    // CSS/images/links resolve and the declared encoding is honored.
                    web.loadFileURL(url, allowingReadAccessTo: dir)
                } else {
                    // No charset declared: decode with the detected encoding and hand
                    // WebKit UTF-8 data so non-ASCII text is not garbled. (Such files
                    // are typically self-contained, so losing sibling-file access is OK.)
                    let enc = EncodingDetector.detect(Array(raw.prefix(64 * 1024)))
                    let text = String(bytes: raw, encoding: enc) ?? String(decoding: raw, as: UTF8.self)
                    if let data = text.data(using: .utf8) {
                        web.load(data, mimeType: "text/html", characterEncodingName: "UTF-8", baseURL: dir)
                    } else {
                        web.loadFileURL(url, allowingReadAccessTo: dir)
                    }
                }
            } else {
                // Treat as Markdown: decode a bounded prefix and render to HTML.
                let cap = 8 * 1024 * 1024
                let data = slice.bytes(at: 0, length: min(cap, Int(slice.count)))
                let enc = EncodingDetector.detect(Array(data.prefix(64 * 1024)))
                let text = String(bytes: data, encoding: enc) ?? String(decoding: data, as: UTF8.self)
                let html = MarkdownRenderer.htmlDocument(from: text, title: url.lastPathComponent)
                web.loadHTMLString(html, baseURL: dir)
            }
        }
    }

    /// Whether an HTML document declares its encoding via a BOM or a `charset`
    /// in the first few KB (so WebKit will decode it correctly on its own).
    private static func declaresCharset(_ bytes: [UInt8]) -> Bool {
        // UTF-8 / UTF-16 byte-order marks.
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { return true }
        if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]) { return true }
        let head = bytes.prefix(4096)
        let ascii = String(decoding: head, as: UTF8.self).lowercased()
        return ascii.contains("charset")
    }

    /// Every network scheme, blocked, whatever document the preview is showing.
    ///
    /// One rule per scheme on purpose: WebKit's filter engine rejects `^(https?|wss?)://` with
    /// "Disjunctions are not supported yet", and a rule list that does not compile fails *open* — the
    /// page would load and the block would exist only in the source. That was measured, not guessed,
    /// which is why it is written the long way.
    private static let noNetworkRules = """
    [{"trigger":{"url-filter":"^http://"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^https://"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^ws://"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^wss://"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^ftp://"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^ftps://"},"action":{"type":"block"}}]
    """
    private static var noNetworkList: WKContentRuleList?

    /// Install the block on `web`, then load. `file:` and `data:` are untouched, so a document's
    /// sibling image still appears — checked both ways.
    ///
    /// The load runs *in* the completion rather than beside it. Compiling is asynchronous, so loading
    /// alongside it would leave the very first preview after launch unprotected — once, quietly, and
    /// never in a way a later test would notice.
    private func loadWithoutNetwork(_ web: WKWebView, _ load: @escaping () -> Void) {
        func install(_ list: WKContentRuleList?) {
            web.configuration.userContentController.removeAllContentRuleLists()
            if let list { web.configuration.userContentController.add(list) }
            load()
        }
        if let list = Self.noNetworkList { install(list); return }
        guard let store = WKContentRuleListStore.default() else {
            NSLog("[lister] no content rule list store — the preview is not blocked from the network")
            load(); return
        }
        store.compileContentRuleList(forIdentifier: "pc-viewer-no-network",
                                     encodedContentRuleList: Self.noNetworkRules) { list, error in
            if let error {
                NSLog("[lister] preview network block failed to compile: \(error.localizedDescription)")
            }
            Self.noNetworkList = list
            install(list)
        }
    }

    private func ensureWebView() -> ListerWebView {
        if let web = webView { return web }
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let web = ListerWebView(frame: .zero, configuration: config)
        // Route the viewer's command keys (mode switch, Esc, n/p, find) to the
        // controller; other keys (arrows/space/page) fall through to WebKit's
        // native scrolling.
        web.onKey = { [weak self] event in self?.handleKey(event) ?? false }
        web.translatesAutoresizingMaskIntoConstraints = false
        if let container {
            container.addSubview(web)
            // Pin to the split view, NOT to scrollView: showWeb() hides the scroll
            // view, and a hidden arranged subview of an NSSplitView stops being laid
            // out — its frame froze at whatever it was when last visible, so a web
            // view anchored to it kept the old size when the window grew and left
            // blank areas to the right and below.
            let area = marks.splitView
            NSLayoutConstraint.activate([
                web.topAnchor.constraint(equalTo: area.topAnchor),
                web.leadingAnchor.constraint(equalTo: area.leadingAnchor),
                web.trailingAnchor.constraint(equalTo: area.trailingAnchor),
                web.bottomAnchor.constraint(equalTo: area.bottomAnchor)
            ])
        }
        webView = web
        return web
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
        case .web:
            let ext = (files[index] as NSString).pathExtension.lowercased()
            modeName = Self.htmlExts.contains(ext) ? String(localized: "HTML") : String(localized: "Markdown")
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
    @objc func vmWeb() { setModeManually(.web) }
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

    /// Copy the full text of the current text/code view to the clipboard.
    /// Copy from the rendered page, matching what the other representations do: the
    /// selection if there is one, otherwise everything.
    ///
    /// The queries run in an **isolated** content world, so the page's own JavaScript
    /// stays disabled (`allowsContentJavaScript = false` — a previewed page must not run
    /// active content) while the host can still read what is rendered.
    private func copyFromWeb(_ web: ListerWebView) {
        web.evaluateJavaScript("window.getSelection().toString()", in: nil, in: .defaultClient) { result in
            let selection = ((try? result.get()) as? String) ?? ""
            if !selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Hand it to WebKit rather than setting the string ourselves, so the
                // clipboard keeps the rich flavours its own context menu provides.
                NSApp.sendAction(Selector(("copy:")), to: web, from: nil)
                return
            }
            // Nothing selected → the whole rendered text, as plain text (which is all the
            // other representations offer anyway).
            web.evaluateJavaScript("document.body.innerText", in: nil, in: .defaultClient) { textResult in
                guard let text = (try? textResult.get()) as? String,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    NSSound.beep(); return
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        }
    }

    private func copyAll() {
        // A text field being edited comes first: the viewer's ⌘C is also the ⌘C of every dialog it
        // opens (Find, Go To), and a menu key equivalent beats the responder chain — so without this,
        // ⌘C in the Go To field copied the *file* instead of the field's selection. Only an *editable*
        // text object wins, so the read-only content view below keeps its own meaning of "copy".
        if AppMenu.forwardToEditedText(#selector(NSText.copy(_:))) { return }
        // Rendered pages: hand the standard editing action to WebKit, which copies the
        // selection exactly as its own context menu does.
        //
        // The viewer's Edit menu owns the ⌘C key equivalent (makeEditMenu binds it to
        // DocumentAction.copy), and a menu key equivalent is matched before the
        // responder chain — so the key never reached the web view. That is why copying
        // worked from WebKit's own context menu but not from the keyboard.
        if mode == .web, let web = webView, !web.isHidden {
            copyFromWeb(web)
            return
        }
        // Same situation for an embedded plugin view: guarded on responds(to:), so a
        // plugin that implements the standard action gets it and one that doesn't still
        // falls through to the beep below rather than silently doing nothing.
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
        return "regex=\(regex)\nfound=\(found)\nmatch=\(found ? String(lastMatchOffset) : "-")\n"
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
        case 19: mode = .web; rebuildContent(); return true        // 2 (rendered: Markdown/HTML)
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
        case 99 where shift: findPrevious(); return true           // Shift+F3 = previous match
        case 99: findNext(); return true                           // F3 = next match
        case 126 where mode != .web: scrollContent(by: -lineStep); return true       // ↑
        case 125 where mode != .web: scrollContent(by: lineStep); return true        // ↓
        case 116 where mode != .web: scrollContent(by: -pageStep); return true       // PageUp
        case 121 where mode != .web: scrollContent(by: pageStep); return true        // PageDown
        case 115 where mode != .web: scrollToEdge(top: true); return true            // Home
        case 119 where mode != .web: scrollToEdge(top: false); return true           // End
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
        let view: NSView
        if let language = SyntaxHighlighter.language(forExtension: ext) {
            view = CodeListerView(text: result.text, language: language)
        } else {
            view = TextListerView(string: result.text)
        }
        scrollView.documentView = view
        contentView = view
        isFormatted = true
        formatterUsed = result.formatter
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
                    (self.contentView as? HexListerView)?.scroll(toByteOffset: offset)
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

    /// Search the rendered page through WebKit's own find, which highlights the match
    /// and scrolls to it. Byte-offset search is useless here: the rendered DOM has no
    /// relationship to the file's byte positions, and a WKWebView is not
    /// ListerScrollable — so the generic path below found offsets it could never show.
    private func findInWeb(backwards: Bool) {
        guard let web = webView, !web.isHidden else { return }
        let needle = String(bytes: lastNeedle, encoding: .utf8) ?? ""
        guard !needle.isEmpty else { return }
        let config = WKFindConfiguration()
        config.backwards = backwards
        config.caseSensitive = !searchCaseInsensitive
        config.wraps = true
        web.find(needle, configuration: config) { result in
            if !result.matchFound { NSSound.beep() }
        }
    }

    private func findNext() {
        guard !lastNeedle.isEmpty else { return }
        // In plugin mode, delegate search to the plugin's own view.
        if mode == .plugin, let pv = pluginView {
            let needle = String(bytes: lastNeedle, encoding: .utf8) ?? ""
            if !needle.isEmpty, !pv.lister.searchText(in: pv.handle, needle) { NSSound.beep() }
            return
        }
        if mode == .web { findInWeb(backwards: false); return }
        guard let slice else { return }
        let match = lastRegex.map {
            ChunkRegexSearcher.search($0, in: slice, from: searchOffset, encoding: searchEncoding)
        } ?? ChunkSearcher.search(lastNeedle, in: slice, from: searchOffset,
                                  caseInsensitive: searchCaseInsensitive)
        if let match {
            searchOffset = match + 1
            lastMatchOffset = match
            (contentView as? ListerScrollable)?.scroll(toByteOffset: match)
        } else {
            NSSound.beep()
            searchOffset = 0
        }
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
        if mode == .web { findInWeb(backwards: true); return }
        guard let slice else { return }
        let backMatch = lastRegex.map {
            ChunkRegexSearcher.searchBackwards($0, in: slice, before: lastMatchOffset,
                                               encoding: searchEncoding)
        } ?? ChunkSearcher.searchBackward(lastNeedle, in: slice, before: lastMatchOffset,
                                          caseInsensitive: searchCaseInsensitive)
        if let match = backMatch {
            lastMatchOffset = match
            searchOffset = match + 1
            (contentView as? ListerScrollable)?.scroll(toByteOffset: match)
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
final class ListerWebView: WKWebView {
    var onKey: ((NSEvent) -> Bool)?
    override func keyDown(with event: NSEvent) {
        if onKey?(event) == true { return }
        super.keyDown(with: event)
    }
}

/// A lister content view that can scroll a byte offset into view (for search).
protocol ListerScrollable: AnyObject {
    func scroll(toByteOffset offset: Int64)
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
        // Largest line whose start <= offset (within the indexed content).
        var line = 0
        var lo = 0, hi = lineStarts.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if lineStarts[mid] <= offset { line = mid; lo = mid + 1 } else { hi = mid - 1 }
        }
        scrollToVisible(NSRect(x: 0, y: CGFloat(line) * lineHeight, width: 1, height: lineHeight * 3))
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
final class HexListerView: NSView, ListerScrollable {
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

    private func hexOriginX(forOffset offset: Int64) -> CGFloat {
        4 + CGFloat(Swift.max(8, String(offset, radix: 16).count) + 2) * cellW
    }

    private func byteIndex(at point: NSPoint) -> Int64? {
        let row = Int(point.y / rowHeight)
        guard row >= 0, row < rowCount else { return nil }
        let offset = Int64(row) * Int64(bytesPerRow)
        let col = Int((point.x - hexOriginX(forOffset: offset)) / (cellW * 3))
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
                let originX = hexOriginX(forOffset: offset)
                for col in 0..<bytesPerRow {
                    let idx = offset + Int64(col)
                    if idx >= sel.lo, idx <= sel.hi, idx < slice.count {
                        NSColor.systemBlue.withAlphaComponent(0.30).setFill()
                        NSRect(x: originX + CGFloat(col * 3) * cellW - 1, y: CGFloat(row) * rowHeight,
                               width: cellW * 2 + 2, height: rowHeight).fill()
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

    init(text: String, language: SyntaxLanguage) {
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
        var k = firstTokenIndex(endingAfter: lr.lowerBound)
        while k < tokens.count, tokens[k].range.lowerBound < lr.upperBound {
            let t = tokens[k]; k += 1
            let lo = max(t.range.lowerBound, lr.lowerBound) - lr.lowerBound
            let hi = min(t.range.upperBound, lr.upperBound) - lr.lowerBound
            guard lo < hi, lo >= 0, hi <= lineChars.count else { continue }
            let startU = String(lineChars[0..<lo]).utf16.count
            let lenU = String(lineChars[lo..<hi]).utf16.count
            if lenU > 0 {
                attr.addAttribute(.foregroundColor, value: SyntaxTheme.color(t.kind),
                                  range: NSRange(location: startU, length: lenU))
            }
        }
        return attr
    }

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
        // Best-effort: treat the search byte offset as a character offset to find the line.
        let target = Int(offset)
        var line = 0
        var lo = 0, hi = lineRanges.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if lineRanges[mid].lowerBound <= target { line = mid; lo = mid + 1 } else { hi = mid - 1 }
        }
        scrollToVisible(NSRect(x: 0, y: CGFloat(line) * lineHeight, width: 1, height: lineHeight * 3))
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
        c.reprImage = true; c.reprRendered = true; c.reprAuto = true
        c.encoding = true; c.format = true; c.xmlTree = true; c.xpath = true
        c.goto = true
        c.marks = true
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
        if contentView is ViewerTextProviding || mode == .web { return true }
        if mode == .plugin, let pv = pluginView?.view { return pv.responds(to: Selector(("copy:"))) }
        return false
    }
    /// Search has four backends: the native find bar in a text view, WebKit's own find
    /// on a rendered page, the plugin's search, or a byte-offset scan — the last one
    /// needs a view that can be scrolled to an offset.
    private var canSearch: Bool {
        textContentView != nil || mode == .web || mode == .plugin || contentView is ListerScrollable
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
    @objc func docReprRendered() { vmWeb() }
    @objc func docReprAuto() { vmAuto() }
    @objc func docCycleEncoding() { vmEncoding() }
    @objc func docFormat() { vmFormat() }
    @objc func docXMLTree() { vmXMLTree() }
    @objc func docXPath() { vmXPath() }
    @objc func docFind() { vmFind() }
    @objc func docFindNext() { vmFindNext() }
    @objc func docGoto() { vmGoto() }
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
