// SPDX-License-Identifier: Apache-2.0
// EditorWindowController.swift - Built-in text/code editor (TODOS #25).
//
// An NSTextView-based editor: selection, undo, copy/paste and the system find bar
// come for free. Adds syntax highlighting (SyntaxHighlighter) applied to the text
// storage, extensible formatting (FormatterRegistry), an encoding picker, and
// save-with-.bak-backup. Bound to F4 (cm_Edit) in place of the external editor.

import AppKit
import PCFoundation
import PCVFS

final class EditorWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate {
    var onClose: (() -> Void)?
    /// Fired after a successful local save. Used to upload the edited file back to
    /// its origin when it was downloaded from a writable network filesystem (F-214).
    var onSaved: (() -> Void)?

    let path: String
    let textView = EditorCodeTextView()
    private lazy var markController = TextMarkController(textView: textView)
    private lazy var marks = DocumentMarksPanel(content: scrollView, host: self)
    private var markDialog: MarkColorDialog?
    private var gotoDialog: InputDialog?
    /// The pattern search in force, so Find Next can step through its matches. Nil until one is
    /// used, which is what hands ⌘G back to the native find bar.
    private var regexSearch: NSRegularExpression?
    private var regexPattern = ""
    private var regexReplacement = ""
    private var regexCaseInsensitive = false
    /// The selection the search was scoped to, or nil for the whole document. Captured when the
    /// search starts: stepping through matches moves the selection, so reading it later would
    /// shrink the scope to the last match found.
    private var regexScope: NSRange?
    private var regexDialog: EditorRegexFindDialog?
    /// Held while the filter prompt is up (a modal window controller must outlive `runModal`).
    private var filterDialog: EditorFilterDialog?
    /// Neon incremental tree-sitter highlighter (nil for non-tree-sitter files,
    /// which use the debounced one-shot lexer path instead).
    private var neon: NeonEditorHighlighter?
    private let scrollView = NSScrollView()
    private let encodingPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    /// Line-ending picker: shows what the file uses, and converts when changed (F-358).
    private let endingPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    /// Line operations: sort, deduplicate, filter, trim (F-359).
    private let linesMenu = NSPopUpButton(frame: .zero, pullsDown: true)
    private var linesDialog: InputDialog?
    private let statusLabel = NSTextField(labelWithString: "")

    private var encoding: TextEncodingChoice = .utf8
    /// Whether this file can be written, determined at load (F-357).
    private var writability: FileWritability = .writable
    /// Which line terminators the document contains (F-358).
    private var lineEndingSurvey = LineEndingSurvey(lf: 0, crlf: 0, cr: 0)
    private var language: SyntaxLanguage?
    private var isDirty = false
    private var didBackup = false
    private var highlightWork: DispatchWorkItem?

    // Collapsible symbol outline sidebar (classes/functions/methods via tree-sitter).
    let symbolSidebar = SymbolSidebar()
    private var symbolWidth: NSLayoutConstraint!
    private var symbolsVisible = false
    private let symbolToggle = NSButton()
    private var symbolWork: DispatchWorkItem?
    private var bracketRanges: [NSRange] = []
    private var symbolPathText = ""
    // Collapsible minimap (scaled overview) on the right.
    private var minimap: MinimapView!
    private var minimapWidth: NSLayoutConstraint!
    private var minimapVisible = false
    private let minimapToggle = NSButton()
    private let gutterToggle = NSButton()
    private var lineNumbers: LineNumberRuler?
    /// Collapsed regions (F-371). Created with the text view, because it installs itself as the layout
    /// manager's delegate.
    lazy var folding = EditorFolding(textView: textView)
    private var minimapWork: DispatchWorkItem?

    init(path: String) {
        self.path = path
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        super.init(window: window)
        window.delegate = self
        language = SyntaxHighlighter.language(forExtension: (path as NSString).pathExtension)
        buildUI()
        loadFile()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showWindow() {
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(textView)
    }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.spacing = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = NSButton(title: String(localized: "Save"), target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "s"
        saveButton.keyEquivalentModifierMask = .command
        // "Format" without naming formats: what is supported now depends on the built-ins,
        // the command-line tools installed, plugins and the user's formatters.ini.
        let formatButton = NSButton(title: String(localized: "Format"), target: self, action: #selector(format))
        formatButton.bezelStyle = .rounded
        let ext = (path as NSString).pathExtension.lowercased()
        formatButton.isEnabled = FormatterRegistry.shared.canFormat(extension: ext)
        formatButton.toolTip = formatButton.isEnabled
            ? String(localized: "Format this file")
            : String(localized: "No formatter available for this file type")
        let bracketButton = NSButton(title: "{ }", target: self, action: #selector(docJumpBracket))
        bracketButton.bezelStyle = .rounded
        bracketButton.keyEquivalent = "\\"
        bracketButton.keyEquivalentModifierMask = .command
        bracketButton.toolTip = String(localized: "Jump to matching bracket (⌘\\)")
        let filterButton = NSButton(title: String(localized: "Filter…"), target: self,
                                    action: #selector(promptFilterCommand))
        filterButton.bezelStyle = .rounded
        filterButton.keyEquivalent = "\\"
        filterButton.keyEquivalentModifierMask = [.command, .shift]
        filterButton.toolTip = String(localized: "Send the selection through a shell command (⇧⌘\\)")
        let findButton = NSButton(title: String(localized: "Find/Replace"), target: nil,
                                  action: #selector(NSTextView.performTextFinderAction(_:)))
        findButton.bezelStyle = .rounded
        findButton.tag = NSTextFinder.Action.showReplaceInterface.rawValue

        for choice in TextEncodingChoice.allCases { encodingPopup.addItem(withTitle: choice.displayName) }
        encodingPopup.target = self
        encodingPopup.action = #selector(encodingChanged)

        symbolToggle.bezelStyle = .rounded
        symbolToggle.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: String(localized: "Symbols"))
        symbolToggle.imagePosition = .imageLeading
        symbolToggle.title = String(localized: "Symbols")
        symbolToggle.setButtonType(.pushOnPushOff)
        symbolToggle.target = self
        symbolToggle.action = #selector(toggleSymbols)
        symbolToggle.isEnabled = false
        symbolToggle.keyEquivalent = "O"
        symbolToggle.keyEquivalentModifierMask = [.command, .shift]
        symbolToggle.toolTip = String(localized: "Show/hide the symbol outline (⇧⌘O)")

        minimapToggle.bezelStyle = .rounded
        minimapToggle.image = NSImage(systemSymbolName: "map", accessibilityDescription: String(localized: "Minimap"))
        minimapToggle.imagePosition = .imageOnly
        minimapToggle.setButtonType(.pushOnPushOff)
        minimapToggle.target = self
        minimapToggle.action = #selector(toggleMinimap)
        minimapToggle.toolTip = String(localized: "Show/hide the minimap")

        toolbar.addArrangedSubview(symbolToggle)
        toolbar.addArrangedSubview(saveButton)
        toolbar.addArrangedSubview(formatButton)
        toolbar.addArrangedSubview(bracketButton)
        toolbar.addArrangedSubview(filterButton)
        toolbar.addArrangedSubview(findButton)
        toolbar.addArrangedSubview(NSTextField(labelWithString: String(localized: "Encoding:")))
        toolbar.addArrangedSubview(encodingPopup)
        // Line endings are invisible until they break a script, so they get a control of their own
        // rather than a line in a dialog (F-358). Next to the encoding picker: same kind of question.
        for ending in LineEnding.allCases { endingPopup.addItem(withTitle: ending.displayName) }
        endingPopup.target = self
        endingPopup.action = #selector(lineEndingChanged)
        endingPopup.toolTip = String(localized: "Line endings — pick one to convert the whole file")
        endingPopup.setAccessibilityLabel(String(localized: "Line endings"))
        toolbar.addArrangedSubview(endingPopup)
        buildLinesMenu()
        toolbar.addArrangedSubview(linesMenu)
        gutterToggle.bezelStyle = .rounded
        gutterToggle.image = NSImage(systemSymbolName: "list.number",
                                     accessibilityDescription: String(localized: "Line numbers"))
        gutterToggle.imagePosition = .imageOnly
        gutterToggle.setButtonType(.pushOnPushOff)
        gutterToggle.state = .on          // on by default: the absence was the complaint
        gutterToggle.target = self
        gutterToggle.action = #selector(toggleLineNumbers)
        gutterToggle.toolTip = String(localized: "Show/hide line numbers")
        toolbar.addArrangedSubview(gutterToggle)
        toolbar.addArrangedSubview(minimapToggle)
        content.addSubview(toolbar)

        textView.isEditable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.onCommandClick = { [weak self] idx in self?.goToDefinition(at: idx) }
        textView.delegate = self
        // No soft-wrap: allow horizontal scrolling for code.
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        // The gutter. AppKit scrolls and repaints a ruler in step with the text view, which a
        // hand-built column of labels would have to be kept in sync with by hand.
        //
        // The order matters and is not interchangeable: `hasVerticalRuler` must be true *before* the
        // ruler is assigned, and the client view set afterwards. Assigning first left the ruler sized
        // to the whole content area — it painted its own opaque background over the text, so the file
        // looked empty while the numbers counted its lines correctly.
        scrollView.hasVerticalRuler = true
        let ruler = LineNumberRuler(textView: textView, scrollView: scrollView)
        lineNumbers = ruler
        ruler.isOffsetFolded = { [weak self] offset in self?.folding.isHidden(offset: offset) ?? false }
        folding.onChange = { [weak self] in
            guard let self else { return }
            self.lineNumbers?.needsDisplay = true
            self.textView.needsDisplay = true
            self.minimap?.refresh()
        }
        scrollView.verticalRulerView = ruler
        ruler.clientView = textView
        scrollView.rulersVisible = true
        scrollView.documentView = textView
        // Keep the text clear of the gutter ourselves — see `onThicknessChanged`.
        ruler.onThicknessChanged = { [weak self] thickness in self?.insetTextForGutter(thickness) }
        insetTextForGutter(ruler.ruleThickness)

        // Editor (top) + marks panel (bottom) share a draggable horizontal split.
        marks.onClearAll = { [weak self] in self?.markController.clearAll(); self?.marks.reload() }
        let splitView = marks.splitView
        let sidebar = buildSymbolSidebar()
        minimap = MinimapView(textView: textView, scrollView: scrollView)
        minimap.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(sidebar)
        content.addSubview(splitView)
        content.addSubview(minimap)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        content.addSubview(statusLabel)

        symbolWidth = sidebar.widthAnchor.constraint(equalToConstant: 0)   // start collapsed
        minimapWidth = minimap.widthAnchor.constraint(equalToConstant: 0)  // start collapsed
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: content.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 40),
            sidebar.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            sidebar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sidebar.bottomAnchor.constraint(equalTo: splitView.bottomAnchor),
            symbolWidth,
            splitView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            splitView.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            splitView.trailingAnchor.constraint(equalTo: minimap.leadingAnchor),
            minimap.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            minimap.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            minimap.bottomAnchor.constraint(equalTo: splitView.bottomAnchor),
            minimapWidth,
            statusLabel.topAnchor.constraint(equalTo: splitView.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            statusLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -6)
        ])
    }

    // MARK: - Symbol outline sidebar

    private func buildSymbolSidebar() -> NSView {
        symbolSidebar.translatesAutoresizingMaskIntoConstraints = false
        symbolSidebar.onSelect = { [weak self] sym in self?.navigate(to: sym) }
        symbolSidebar.onAvailabilityChanged = { [weak self] has in
            guard let self else { return }
            self.symbolToggle.isEnabled = has
            if !has, self.symbolsVisible { self.setSymbolSidebar(visible: false) }
            self.updateBreadcrumb()   // tree just (re)loaded — refresh the path
        }
        return symbolSidebar
    }

    /// Recompute the outline for the current text (background parse via SymbolSidebar).
    private func refreshSymbols() {
        symbolSidebar.load(text: textView.string, ext: (path as NSString).pathExtension.lowercased())
    }

    /// Debounced outline refresh after edits.
    private func scheduleSymbolRefresh() {
        let ext = (path as NSString).pathExtension.lowercased()
        guard SymbolOutline.supports(ext: ext) || StructureOutline.supports(ext: ext) else { return }
        symbolWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refreshSymbols() }
        symbolWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    @objc private func toggleSymbols() { setSymbolSidebar(visible: !symbolsVisible) }

    #if DEBUG
    /// Diagnostic: make the symbol sidebar visible (call at open, before the parse).
    func automationShowSidebar() { setSymbolSidebar(visible: true) }
    /// Diagnostic: read the strings currently rendered into the sidebar rows (call
    /// after the parse has settled; no forced reload, so it captures the live state).
    func automationRenderedSymbols() -> [String] { symbolSidebar.renderedCellStrings() }

    /// Diagnostic: how many line fragments the layout manager actually produced — i.e. how many lines are
    /// on screen (F-371). Folded lines produce none, so this is the measure a fold has to move; reading
    /// the folded ranges back would prove the bookkeeping and nothing about the screen.
    func automationVisibleLineCount() -> Int {
        guard let manager = textView.layoutManager, let container = textView.textContainer else { return 0 }
        manager.ensureLayout(for: container)
        var count = 0
        var index = 0
        while index < manager.numberOfGlyphs {
            var effective = NSRange()
            _ = manager.lineFragmentRect(forGlyphAt: index, effectiveRange: &effective)
            count += 1
            index = max(NSMaxRange(effective), index + 1)
        }
        return count
    }

    /// Diagnostic: the status line as rendered, so the breadcrumb is checked as text and not only
    /// looked at. It described the last key in the file while the caret sat on line 1.
    func automationStatusLine() -> String { statusLabel.stringValue }

    /// Diagnostic: move the caret and report the breadcrumb that follows from it.
    func automationBreadcrumb(at offset: Int) -> String {
        textView.setSelectedRange(NSRange(location: offset, length: 0))
        return symbolPathText
    }

    /// Diagnostic: put the filter prompt on screen, so its layout can be photographed and its
    /// Auto Layout conflicts counted (F-356). A sheet over a visible window, so it does not block.
    func automationShowFilterDialog() { promptFilterCommand() }

    /// Diagnostic: apply the built-in line operations in order and report the result (F-359).
    ///
    /// One pass over the real menu path, so the tag→operation mapping, the line-wise range and the
    /// terminator preservation are all exercised where they actually run.
    func automationLineOperations() -> String {
        var report = ""
        for (index, entry) in Self.lineOperations.enumerated() {
            guard let entry, !entry.needsPrompt else { continue }
            runLineOperation(entry.operation, named: entry.title)
            report += "[\(index)] \(entry.title): \(statusLabel.stringValue)\n"
        }
        runLineOperation(.filter(needle: "keep", keep: true, caseSensitive: false), named: "filter")
        let survey = LineEndings.survey(textView.string)
        return report + "endings=\(survey.displayName)\nundo=\(textView.undoManager?.canUndo == true)\n"
            + "--- text ---\n" + textView.string.replacingOccurrences(of: "\r", with: "<CR>")
    }

    /// Diagnostic: type `text` at the start of the document and save it the way Cmd+S does (F-387).
    ///
    /// Reports what ended up on disk *and* whether a `.bak` was left beside it. The backup is a file the
    /// editor creates behind the user's back, so the only honest check is looking in the folder afterwards
    /// — the flag that governs it says nothing about what a save actually did.
    func automationSaveAfterTyping(_ text: String) -> String {
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.insertText(text, replacementRange: NSRange(location: 0, length: 0))
        save()
        let onDisk = (try? String(contentsOfFile: path, encoding: .utf8)) ?? "<unreadable>"
        return "dirty=\(isDirty)\nbak=\(FileManager.default.fileExists(atPath: path + ".bak"))\n"
            + "--- text ---\n" + onDisk
    }

    /// Diagnostic: run `command` over the whole document, then report what the editor now shows.
    ///
    /// Reads the text view back *and* leaves the window on screen: the text view is the thing that
    /// held a whole document and rendered none of it once, so the string alone is not evidence.
    func automationFilter(_ command: String) async -> String {
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        let outcome = await EditorTextFilter.apply(
            command: command, to: textView,
            workingDirectory: (path as NSString).deletingLastPathComponent)
        if case .replaced = outcome { afterProgrammaticEdit() }
        let status: String
        switch outcome {
        case .replaced(let lines): status = "replaced lines=\(lines)"
        case .unchanged: status = "unchanged"
        case .failed(let message): status = "failed: \(message)"
        }
        return "outcome=\(status)\nundo=\(textView.undoManager?.canUndo == true)\n"
            + "gutter=\(lineNumbers?.ruleThickness ?? 0)\nstatus=\(statusLabel.stringValue)\n"
            + "--- text ---\n\(textView.string)"
    }
    #endif

    private func setSymbolSidebar(visible: Bool) {
        symbolsVisible = visible
        symbolWidth.animator().constant = visible ? 220 : 0
        symbolToggle.state = visible ? .on : .off
        if visible { symbolSidebar.focusFilter() }
    }

    // MARK: - Minimap

    @objc private func toggleMinimap() { setMinimap(visible: !minimapVisible) }

    private func setMinimap(visible: Bool) {
        minimapVisible = visible
        minimapWidth.animator().constant = visible ? 78 : 0
        minimapToggle.state = visible ? .on : .off
        if visible { minimap.refresh() }
    }

    private func scheduleMinimapRefresh() {
        guard minimapVisible else { return }
        minimapWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.minimap.refresh() }
        minimapWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    /// Cmd+click: jump to the definition of the identifier under the click.
    private func goToDefinition(at index: Int) {
        let ns = textView.string as NSString
        guard let word = IdentifierScanner.word(in: ns, at: index),
              let sym = symbolSidebar.definition(named: word) else { NSSound.beep(); return }
        navigate(to: sym)
    }

    /// Jump the editor to a symbol's definition and select its name.
    private func navigate(to sym: SymbolNode) {
        let ns = textView.string as NSString
        let loc = max(0, min(sym.utf16Location, ns.length))
        let len = max(0, min(sym.name.utf16.count, ns.length - loc))
        let range = NSRange(location: loc, length: len)
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        textView.window?.makeFirstResponder(textView)
    }

    // MARK: - Load / save

    private func loadFile() {
        // Ask at load, not at save (F-357). Finding out after ten minutes of editing that the file
        // cannot be written is the part that wastes the ten minutes.
        writability = FileWritabilityCheck.check(path: path)
        let data = (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()
        // Through `EncodingDetector.decode`, which strips the byte-order mark: `String(data:encoding:)`
        // keeps it for UTF-16, so a UTF-16 file used to open with an invisible U+FEFF as its first
        // character — the caret's column was off by one on line 1, and saving wrote the marker into the
        // content on top of the new one.
        let decoded = EncodingDetector.decode(data)
        encoding = TextEncodingChoice.from(decoded.encoding) ?? .utf8
        encodingPopup.selectItem(withTitle: encoding.displayName)
        textView.string = decoded.text
        // Assigning the string leaves the caret behind the text, which the view does not scroll to: the
        // document showed line 1 while the breadcrumb described the very last key in the file.
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        refreshLineNumbers()
        refreshLineEndings()
        isDirty = false
        refreshHighlight()
        refreshSymbols()
        minimap?.refresh()
        updateTitleAndStatus()
    }

    // MARK: - Mark all (Notepad++-style, session-only, item 17)

    @objc func menuMarkAll() {
        let sel = textView.selectedRange()
        guard sel.length > 0 else {
            window?.subtitle = String(localized: "Select some text first, then Mark All.")
            return
        }
        let term = (textView.string as NSString).substring(with: sel)
        let dialog = MarkColorDialog(
            title: String(localized: "Mark All"),
            prompt: String(localized: "Mark all occurrences of “\(term)” in:"),
            term: term, showsTerm: false,
            initialColorIndex: markController.nextColorIndex % TextMarkController.palette.count)
        dialog.onConfirm = { [weak self] _, colorIndex in
            guard let self else { return }
            let count = self.markController.markAll(of: term, colorIndex: colorIndex)
            if count > 0 { self.marks.show() }
            self.marks.reload()
            self.window?.subtitle = String(localized: "\(count) occurrence(s) of “\(term)” marked")
        }
        markDialog = dialog
        dialog.runModalDialog(over: window)
    }

    @objc func menuClearMarks() {
        markController.clearAll()
        marks.reload()
        window?.subtitle = ""
    }

    /// Count occurrences of the selection without marking (Notepad++-style).
    @objc func menuCount() {
        let sel = textView.selectedRange()
        guard sel.length > 0 else { window?.subtitle = String(localized: "Select some text first, then Count."); return }
        let term = (textView.string as NSString).substring(with: sel)
        window?.subtitle = String(localized: "\(markController.count(of: term)) occurrence(s) of “\(term)”")
    }

    /// Toggle the docked marks panel (show at default height / collapse).
    @objc func menuMarksList() { marks.toggle() }

    @objc func menuNextMark() {
        guard let r = markController.nextMark(after: textView.selectedRange().location) else { NSSound.beep(); return }
        textView.setSelectedRange(r)
        textView.scrollRangeToVisible(r)
    }

    @objc func menuPrevMark() {
        guard let r = markController.previousMark(before: textView.selectedRange().location) else { NSSound.beep(); return }
        textView.setSelectedRange(r)
        textView.scrollRangeToVisible(r)
    }

    @objc private func save() {
        let text = textView.string
        guard let data = text.data(using: encoding.encoding) ?? text.data(using: .utf8) else {
            NSSound.beep(); return
        }
        // A read-only volume or a SIP-protected file cannot be saved with authorization either, so the
        // prompt is suppressed for those (F-357). `.writable` is the normal case and keeps the offer:
        // a file may also have become root-owned since it was opened.
        let mayAsk = writability.isWritable || writability.administratorMayHelp
        if DocumentFile.writeWithBackup(data, toPath: path, didBackup: &didBackup,
                                        mayAskForAuthorization: mayAsk) {
            isDirty = false
            // The obstacle may be gone: an administrator save leaves a file we still cannot write, but
            // a chmod in another window means the lock should disappear from the title.
            writability = FileWritabilityCheck.check(path: path)
            updateTitleAndStatus()
            onSaved?()
        }
    }

    @objc private func toggleLineNumbers() {
        let visible = gutterToggle.state == .on
        scrollView.rulersVisible = visible
        insetTextForGutter(visible ? (lineNumbers?.ruleThickness ?? 0) : 0)
    }

    /// Leave `gutter` points free on the left so no glyph is hidden behind the line numbers.
    ///
    /// `textContainerInset` pads both sides, which costs a right margin of the same width. That is a
    /// fair price for text that is never clipped, and the alternative — moving the text view's frame —
    /// fights the scroll view for the same job.
    private func insetTextForGutter(_ gutter: CGFloat) {
        textView.textContainerInset = NSSize(width: gutter + 6, height: 6)
        textView.needsDisplay = true
        lineNumbers?.needsDisplay = true
    }

    /// Re-scan the line starts after the text was replaced in code.
    ///
    /// `NSText.didChangeNotification` covers typing; setting `textView.string` — reload from disk,
    /// format, a line operation — does not post it, and the gutter would keep the old line count.
    private func refreshLineNumbers() { lineNumbers?.refresh() }

    // MARK: - Line operations (F-359)

    /// The line-tools menu: the shell filter, the built-in line operations, and line-ending
    /// conversion — one builder, used for the toolbar pull-down and for the window's menu bar.
    ///
    /// Built twice rather than shared: an NSMenu belongs to one owner, and a pull-down additionally
    /// needs a first item that is its title and is never chosen.
    private func makeLineToolsMenu(forPullDown: Bool) -> NSMenu {
        let menu = NSMenu(title: String(localized: "Lines"))
        if forPullDown { menu.addItem(NSMenuItem(title: String(localized: "Lines"), action: nil,
                                                 keyEquivalent: "")) }
        let filter = NSMenuItem(title: String(localized: "Filter Through Command…"),
                                action: #selector(promptFilterCommand), keyEquivalent: "\\")
        filter.keyEquivalentModifierMask = [.command, .shift]
        filter.target = self
        menu.addItem(filter)
        menu.addItem(.separator())
        for (index, entry) in Self.lineOperations.enumerated() {
            guard let entry else { menu.addItem(.separator()); continue }
            let item = NSMenuItem(title: entry.title, action: #selector(lineOperationChosen(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.tag = index
            menu.addItem(item)
        }
        menu.addItem(.separator())
        for ending in LineEnding.allCases {
            let item = NSMenuItem(title: String(format: String(localized: "Convert to %@"),
                                                ending.displayName),
                                  action: #selector(convertLineEndings(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ending.displayName
            menu.addItem(item)
        }
        return menu
    }

    /// Build the toolbar pull-down. A pull-down rather than a row of buttons: these are one family,
    /// used occasionally, and seven more buttons would crowd out the controls used constantly.
    private func buildLinesMenu() {
        linesMenu.pullsDown = true
        linesMenu.bezelStyle = .rounded
        linesMenu.menu = makeLineToolsMenu(forPullDown: true)
        linesMenu.setAccessibilityLabel(String(localized: "Line operations"))
        linesMenu.toolTip = String(localized: "Sort, deduplicate, filter or trim the selected lines")
    }

    /// The operations, in menu order. `nil` is a separator; `needsPrompt` asks for the text to match
    /// first. A menu item's tag is its index here, so the two cannot drift apart.
    private static let lineOperations: [(title: String, operation: LineOperation,
                                        needsPrompt: Bool)?] = [
        (String(localized: "Sort A→Z"), .sort(ascending: true), false),
        (String(localized: "Sort Z→A"), .sort(ascending: false), false),
        (String(localized: "Reverse"), .reverse, false),
        nil,
        (String(localized: "Remove Duplicate Lines"), .unique, false),
        (String(localized: "Remove Blank Lines"), .removeBlankLines, false),
        (String(localized: "Trim Trailing Whitespace"), .trimTrailingWhitespace, false),
        nil,
        (String(localized: "Keep Only Lines Containing…"),
         .filter(needle: "", keep: true, caseSensitive: false), true),
        (String(localized: "Remove Lines Containing…"),
         .filter(needle: "", keep: false, caseSensitive: false), true)
    ]

    @objc private func lineOperationChosen(_ sender: NSMenuItem) {
        guard Self.lineOperations.indices.contains(sender.tag),
              let entry = Self.lineOperations[sender.tag] else { return }
        guard entry.needsPrompt else { return runLineOperation(entry.operation, named: entry.title) }
        // The two filtering entries need the text to match; asked for here rather than in the operation,
        // which stays pure and testable.
        guard case .filter(_, let keep, _) = entry.operation else { return }
        let dialog = InputDialog(
            title: entry.title,
            prompt: keep ? String(localized: "Keep only lines containing:")
                         : String(localized: "Remove lines containing:"),
            initialValue: "", okTitle: String(localized: "Apply"),
            checkboxTitle: String(localized: "Match case"))
        dialog.onConfirm = { [weak self, weak dialog] needle in
            guard let self, !needle.isEmpty else { return }
            self.runLineOperation(.filter(needle: needle, keep: keep,
                                          caseSensitive: dialog?.isChecked == true),
                                  named: entry.title)
        }
        linesDialog = dialog
        dialog.runModalDialog(over: window)
    }

    private func runLineOperation(_ operation: LineOperation, named name: String) {
        switch EditorLineOperations.apply(operation, to: textView, actionName: name) {
        case .failed(let message):
            statusLabel.stringValue = message
            NSSound.beep()
        case .unchanged:
            statusLabel.stringValue = String(format: String(localized: "%@ — nothing to change"), name)
        case .replaced(let lines):
            afterProgrammaticEdit()
            statusLabel.stringValue = String(format: String(localized: "%1$@ — %2$d line(s)"),
                                             name, lines)
        }
    }

    // MARK: - Line endings (F-358)

    /// Convert the whole document to the terminator the user picked.
    ///
    /// One undoable step, and no-op when the file already uses it — a picker that reports the current
    /// state must not mark the file dirty just for being read.
    @objc private func lineEndingChanged() {
        guard let title = endingPopup.titleOfSelectedItem,
              let ending = LineEnding.allCases.first(where: { $0.displayName == title }) else { return }
        let converted = LineEndings.convert(textView.string, to: ending)
        guard converted != textView.string else { refreshLineEndings(); return }
        let whole = NSRange(location: 0, length: (textView.string as NSString).length)
        let caret = textView.selectedRange()
        EditorTextFilter.replace(whole, with: converted, in: textView,
                                 actionName: String(localized: "Convert Line Endings"))
        // Keep the caret roughly where it was: replacing everything otherwise sends the view to the
        // top, which after a conversion looks as though the file was reloaded.
        let length = (textView.string as NSString).length
        textView.setSelectedRange(NSRange(location: min(caret.location, length), length: 0))
        afterProgrammaticEdit()
        statusLabel.stringValue = String(format: String(localized: "Converted to %@"), ending.displayName)
    }

    /// Convert from the menu bar, where the choice arrives as the item rather than the popup.
    @objc private func convertLineEndings(_ sender: NSMenuItem) {
        guard let title = sender.representedObject as? String else { return }
        endingPopup.selectItem(withTitle: title)
        lineEndingChanged()
    }

    /// Show what the document currently uses, without converting anything.
    private func refreshLineEndings() {
        let survey = LineEndings.survey(textView.string)
        lineEndingSurvey = survey
        endingPopup.selectItem(withTitle: survey.dominant.displayName)
    }

    @objc private func encodingChanged() {
        if let choice = TextEncodingChoice.allCases.first(where: { $0.displayName == encodingPopup.titleOfSelectedItem }) {
            encoding = choice
            updateTitleAndStatus()
        }
    }

    @objc private func format() {
        let ext = (path as NSString).pathExtension.lowercased()
        let result: (text: String, formatter: String)
        do {
            result = try FormatterRegistry.shared.format(textView.string, extension: ext)
        } catch let error as FormatError {
            // The editor writes to disk, so saying why matters even more here than in the
            // viewer — "Already formatted" must not look like a failed edit.
            statusLabel.stringValue = error.userMessage
            NSSound.beep(); return
        } catch {
            NSSound.beep(); return
        }
        // Through `shouldChangeText`, not `textView.string = …`: assigning the string clears the undo
        // stack, so ⌘Z after a reformat did nothing and the original was unrecoverable.
        let whole = NSRange(location: 0, length: (textView.string as NSString).length)
        EditorTextFilter.replace(whole, with: result.text, in: textView,
                                 actionName: String(localized: "Format"))
        afterProgrammaticEdit()
    }

    // MARK: - Filter through a shell command (F-356)

    /// Ask for a command line and pipe the selection through it.
    ///
    /// The selection, or the whole document when there is none — see `EditorTextFilter.apply`.
    @objc func promptFilterCommand() {
        let selected = textView.selectedRange().length
        let scope = selected > 0
            ? String(format: String(localized: "Applies to the selection (%d characters)."), selected)
            : String(localized: "Nothing is selected — applies to the whole document.")
        let history = TextPipeHistory(configRoot: ConfigPaths.resolve().root)
        let dialog = EditorFilterDialog(entries: history.load(), scope: scope)
        dialog.onConfirm = { [weak self] command in
            guard let self else { return }
            // Remembered before running: a command that failed because of a typo in *its* arguments is
            // the one the user wants back in the field to correct.
            history.remember(command)
            // The pipe runs off-main; say so, because a `find`-shaped command takes a moment and an
            // unchanged window would look like nothing happened.
            self.statusLabel.stringValue = String(format: String(localized: "Running %@ …"), command)
            Task { @MainActor in
                let outcome = await EditorTextFilter.apply(
                    command: command, to: self.textView,
                    workingDirectory: (self.path as NSString).deletingLastPathComponent)
                switch outcome {
                case .failed(let message):
                    self.statusLabel.stringValue = message
                    NSSound.beep()
                case .unchanged:
                    self.statusLabel.stringValue = String(localized: "The command changed nothing.")
                case .replaced(let lines):
                    self.afterProgrammaticEdit()
                    self.statusLabel.stringValue = String(
                        format: String(localized: "%1$@ — %2$d line(s)"), command, lines)
                }
            }
        }
        filterDialog = dialog
        dialog.runModalDialog(over: window)
    }

    /// Bring everything that watches the text back in step after a wholesale, in-code edit.
    ///
    /// `NSText.didChangeNotification` covers typing; a programmatic replacement drives these by hand.
    func afterProgrammaticEdit() {
        refreshLineNumbers()
        refreshLineEndings()
        isDirty = true
        refreshHighlight()
        refreshSymbols()
        minimap?.refresh()
        updateTitleAndStatus()
    }

    /// Redraw the gutter and the minimap after a fold changed. Named separately from
    /// `afterProgrammaticEdit` because folding changes no text: re-highlighting or reparsing would be
    /// wasted work on every keystroke of ⌥⌘←.
    func refreshHighlightAfterFold() {
        lineNumbers?.needsDisplay = true
        textView.needsDisplay = true
        minimap?.refresh()
    }

    // MARK: - Highlighting

    func textViewDidChangeSelection(_ notification: Notification) {
        // A caret inside hidden text would let the user edit what they cannot see, so reaching into a
        // fold opens it.
        if folding.revealIfNeeded(selection: textView.selectedRange()) { lineNumbers?.needsDisplay = true }
        updateBracketHighlight()
        updateBreadcrumb()
    }

    /// Show the definition path enclosing the caret in the status line.
    private func updateBreadcrumb() {
        let path = symbolSidebar.enclosingPath(utf16: textView.selectedRange().location)
        let text = path.map(\.name).joined(separator: " › ")
        if text != symbolPathText { symbolPathText = text; updateTitleAndStatus() }
    }

    /// Highlight the bracket next to the caret and its partner (display-only).
    private func updateBracketHighlight() {
        guard let lm = textView.layoutManager else { return }
        for r in bracketRanges { lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: r) }
        bracketRanges = []
        let sel = textView.selectedRange()
        guard sel.length == 0 else { return }
        let ns = textView.string as NSString
        guard let m = BracketMatcher.match(in: ns, caret: sel.location) else { return }
        let color = NSColor.systemGray.withAlphaComponent(0.4)
        for r in [m.bracket, m.partner] {
            lm.addTemporaryAttributes([.backgroundColor: color], forCharacterRange: r)
            bracketRanges.append(r)
        }
    }

    /// Move the caret to the bracket matching the one next to it.
    @objc func docJumpBracket() {
        let ns = textView.string as NSString
        guard let m = BracketMatcher.match(in: ns, caret: textView.selectedRange().location) else { NSSound.beep(); return }
        let target = NSRange(location: m.partner.location, length: 0)
        textView.setSelectedRange(target)
        textView.scrollRangeToVisible(target)
    }

    func textDidChange(_ notification: Notification) {
        isDirty = true
        // Every fold is dropped on an edit: a fold is a pair of character offsets, and inserting text
        // moves them, so a surviving fold hides the wrong lines. See EditorFolding.
        folding.textChanged()
        updateTitleAndStatus()
        // Neon re-highlights incrementally on its own; only the lexer path needs
        // the debounced full re-run.
        if neon == nil { scheduleRehighlight() }
        scheduleSymbolRefresh()   // keep the outline in sync with edits (debounced)
        scheduleMinimapRefresh()
    }

    /// Full re-highlight after the text was replaced wholesale (load / reformat).
    private func refreshHighlight() {
        if neon == nil, TreeSitterHighlighter.canHighlight(ext: (path as NSString).pathExtension) {
            neon = NeonEditorHighlighter(textView: textView, ext: (path as NSString).pathExtension)
        }
        if let neon {
            neon.invalidateAll()
            markController.reapply()
        } else {
            rehighlight()
        }
    }

    private func scheduleRehighlight() {
        guard language != nil else { return }
        highlightWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.rehighlight() }
        highlightWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func rehighlight() {
        guard let storage = textView.textStorage else { return }
        // Non-tree-sitter languages: the built-in lexer (tree-sitter files are
        // driven by Neon via refreshHighlight()).
        SyntaxHighlightApplier.apply(textView.string, language: language, to: storage)
        markController.reapply()   // keep session marks visible after re-highlight
    }

    private func updateTitleAndStatus() {
        let name = (path as NSString).lastPathComponent
        // The lock in the title travels with the window: it is still there in the Window menu, in
        // Mission Control and in a screenshot of a session from yesterday.
        let lock = writability.isWritable ? "" : "🔒 "
        window?.title = (isDirty ? "• " : "") + lock + name
        let langName = language?.name
            ?? TreeSitterLanguages.displayName(forExtension: (path as NSString).pathExtension)
            ?? String(localized: "Plain")
        let crumb = symbolPathText.isEmpty ? "" : "   ▸ \(symbolPathText)"
        let readOnly = writabilityNote.isEmpty ? "" : "   —   \(writabilityNote)"
        // Only when there is something to say: a one-line file has no terminator to report.
        let endings = lineEndingSurvey.isEmpty ? "" : "   \(lineEndingSurvey.displayName)"
        statusLabel.stringValue = "\(langName)   \(encoding.displayName)\(endings)\(isDirty ? "   —   \(String(localized: "modified"))" : "")\(readOnly)\(crumb)"
    }

    /// What the status line says about writing this file, and what the user can do about it.
    ///
    /// Each case has a different answer, so each gets its own sentence rather than one "read-only":
    /// chmod is the user's own business, authorization is macOS's, and a read-only volume ends the
    /// matter. See `FileWritability`.
    private var writabilityNote: String {
        switch writability {
        case .writable:
            return ""
        case .readOnlyVolume:
            return String(localized: "read-only volume — this file cannot be saved here")
        case .ownedByAnotherUser(let owner):
            return String(format: String(localized: "owned by %@ — saving will ask for authorization"),
                          owner)
        case .permissionsDeny:
            return String(localized: "read-only — its permissions deny writing")
        case .immutable:
            return String(localized: "locked — the immutable flag is set")
        case .systemProtected:
            return String(localized: "protected by the system — not writable even with authorization")
        }
    }

    // MARK: - Close

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard isDirty else { return true }
        switch DocumentFile.confirmClose(name: (path as NSString).lastPathComponent) {
        case .save: save(); return !isDirty
        case .discard: return true
        case .cancel: return false
        }
    }

    func windowWillClose(_ notification: Notification) {
        highlightWork?.cancel()
        symbolWork?.cancel()
        minimapWork?.cancel()
        onClose?()
    }
}

// MARK: - Contextual menu-bar menu (TODOS #189)

@MainActor
extension EditorWindowController: WindowContextMenuProviding {
    /// The editor's document capabilities: editable text with encoding, JSON/XML
    /// formatting, full find/replace, go-to-line and marks.
    private var documentCaps: DocumentMenuCaps {
        var c = DocumentMenuCaps()
        c.editable = true
        c.encoding = true
        c.format = true
        c.findPrev = true
        c.replace = true
        c.regexFind = true
        c.goto = true
        c.marks = true
        c.markNav = true
        return c
    }

    // Native undo/cut/copy/paste/select-all via the responder chain.
    func makeEditMenu() -> NSMenu { AppMenu.standardEditMenu() }

    func toolMenus() -> [NSMenu] {
        // The line tools get a menu of their own rather than a cap in DocumentMenus: they are the
        // editor's alone, and the tag-to-operation mapping belongs next to the list it indexes.
        DocumentMenus.toolMenus(caps: documentCaps, editMenu: makeEditMenu(), target: self)
            + [makeLineToolsMenu(forPullDown: false)]
            // Only for JSON, YAML and XML: for a Swift file these commands are meaningless, and a menu
            // full of items that beep is worse than no menu.
            + (hasNavigableStructure ? [makeStructureMenu(forPullDown: false)] : [])
    }
}

// MARK: - Unified document actions (shared menu taxonomy)

@MainActor
extension EditorWindowController {
    @objc func docSave() { save() }
    @objc func docReload() { reloadFromDisk() }
    @objc func docCycleEncoding() {
        let all = TextEncodingChoice.allCases
        guard let i = all.firstIndex(of: encoding) else { return }
        encoding = all[(i + 1) % all.count]
        encodingPopup.selectItem(withTitle: encoding.displayName)
        // Re-decode the file bytes under the new encoding (only meaningful if
        // unmodified; otherwise just record the save encoding).
        if !isDirty { loadFile() } else { updateTitleAndStatus() }
    }
    @objc func docFormat() { format() }
    @objc func docFind() { finder(.showFindInterface) }
    /// Find Next steps through the *pattern's* matches once one has been used, and otherwise hands
    /// the key back to the native bar. So ⌘G keeps meaning "the next one" whichever kind of search
    /// was started, which is the only way the two can live side by side without surprising anyone.
    @objc func docFindNext() { regexSearch == nil ? finder(.nextMatch) : stepRegex(forwards: true) }
    @objc func docFindPrev() { regexSearch == nil ? finder(.previousMatch) : stepRegex(forwards: false) }
    @objc func docReplace() { finder(.showReplaceInterface) }
    @objc func docFindRegex() { promptRegexFind(replacing: false) }
    @objc func docReplaceRegex() { promptRegexFind(replacing: true) }
    @objc func docGoto() { promptGotoLine() }
    @objc func docMarkAll() { menuMarkAll() }
    @objc func docCount() { menuCount() }
    @objc func docNextMark() { menuNextMark() }
    @objc func docPrevMark() { menuPrevMark() }
    @objc func docToggleMarksPanel() { menuMarksList() }
    @objc func docClearAllMarks() { menuClearMarks() }

    private func finder(_ action: NSTextFinder.Action) {
        let item = NSMenuItem()
        item.tag = action.rawValue
        textView.performTextFinderAction(item)
    }

    private func reloadFromDisk() {
        if isDirty {
            let alert = NSAlert()
            alert.messageText = String(localized: "Discard changes and reload from disk?")
            alert.addButton(withTitle: String(localized: "Reload"))
            alert.addButton(withTitle: String(localized: "Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        loadFile()
    }

    #if DEBUG
    /// Drive the pattern search from the automation runner: find, step, or replace all.
    ///
    /// Here because the result of a search is a selection and the result of a replace is the
    /// document's text — neither of which anything outside the window can read, and the parts most
    /// easily got subtly wrong (a scope that leaks past the selection, a `$1` that refers to the
    /// wrong match) are exactly the parts a human would not notice at a glance.
    func automationRegex(pattern: String, replacement: String?, caseInsensitive: Bool,
                         inSelection: Bool, replaceAll: Bool) -> String {
        let made = RegexTextSearch.compile(pattern, caseInsensitive: caseInsensitive)
        guard let regex = made.regex else { return "error=\(made.error ?? "unknown")\n" }
        regexPattern = pattern
        regexCaseInsensitive = caseInsensitive
        regexSearch = regex
        regexScope = inSelection ? textView.selectedRange() : nil
        if replaceAll, let template = replacement {
            replaceAllRegex(regex, template: template)
            return "replaced=true\ntext=\(textView.string)\n"
        }
        stepRegex(forwards: true, startingAt: regexScope?.location ?? textView.selectedRange().location)
        let sel = textView.selectedRange()
        return "match=\(sel.location)\nlength=\(sel.length)\n"
            + "selected=\((textView.string as NSString).substring(with: sel))\n"
    }

    /// Step the pattern search on, as ⌘G does.
    func automationRegexStep(forwards: Bool) -> String {
        stepRegex(forwards: forwards)
        let sel = textView.selectedRange()
        return "match=\(sel.location)\nselected=\((textView.string as NSString).substring(with: sel))\n"
    }
    #endif

    // MARK: - Regular-expression find & replace (F-151)

    /// Ask for a pattern, then either jump to the first match or rewrite every one of them.
    private func promptRegexFind(replacing: Bool) {
        let selection = textView.selectedRange()
        let dialog = EditorRegexFindDialog(
            pattern: regexPattern, replacement: regexReplacement,
            caseInsensitive: regexCaseInsensitive,
            // A read-only document is offered the search half only, rather than a Replace All that
            // fails when pressed.
            showsReplace: replacing && textView.isEditable,
            hasSelection: selection.length > 0)
        dialog.onConfirm = { [weak self] request in
            guard let self else { return }
            self.regexPattern = request.pattern
            self.regexReplacement = request.replacement ?? self.regexReplacement
            self.regexCaseInsensitive = request.caseInsensitive
            let made = RegexTextSearch.compile(request.pattern, caseInsensitive: request.caseInsensitive)
            guard let regex = made.regex else { return }   // the dialog already refused it
            self.regexSearch = regex
            self.regexScope = request.inSelection ? selection : nil
            if request.replaceAll, let template = request.replacement {
                self.replaceAllRegex(regex, template: template)
            } else {
                // From the caret, not one past it: `advance` exists to step off a match you are
                // already sitting on, and using it to *start* skips a match that begins exactly
                // where the cursor is — which is the first one in the file when nothing is selected.
                self.stepRegex(forwards: true,
                               startingAt: self.regexScope?.location ?? selection.location)
            }
        }
        regexDialog = dialog          // held: a sheet does not retain its window controller
        dialog.present(over: window)
    }

    /// Move the selection to the next (or previous) match of the pattern in force.
    private func stepRegex(forwards: Bool, startingAt: Int? = nil) {
        guard let regex = regexSearch else { return }
        let text = textView.string
        let selection = textView.selectedRange()
        let scope = clampedRegexScope(in: text)
        let hit = forwards
            ? RegexTextSearch.next(regex, in: text,
                                   from: startingAt ?? RegexTextSearch.advance(past: selection),
                                   scope: scope)
            : RegexTextSearch.previous(regex, in: text, before: selection.location, scope: scope)
        guard let hit else {
            window?.subtitle = String(localized: "No match for that pattern")
            NSSound.beep()
            return
        }
        textView.setSelectedRange(hit)
        textView.scrollRangeToVisible(hit)
        textView.showFindIndicator(for: hit)
        let total = RegexTextSearch.all(regex, in: text, scope: scope).count
        window?.subtitle = String(localized: "\(total) match(es) for “\(regexPattern)”")
    }

    /// Rewrite every match in one undoable step, and say how many.
    private func replaceAllRegex(_ regex: NSRegularExpression, template: String) {
        let text = textView.string
        let scope = clampedRegexScope(in: text) ?? NSRange(location: 0, length: (text as NSString).length)
        let out = RegexTextSearch.replaceAll(regex, in: text, template: template, scope: scope)
        guard out.count > 0 else {
            window?.subtitle = String(localized: "No match for that pattern")
            NSSound.beep()
            return
        }
        // Through the same primitive the line operations use, so it is a single undo step with a
        // name in the Edit menu rather than an unattributed change.
        guard EditorTextFilter.replace(scope, with: out.text, in: textView,
                                       actionName: String(localized: "Replace All")) else {
            window?.subtitle = String(localized: "This document is not editable")
            return
        }
        let replaced = NSRange(location: scope.location, length: (out.text as NSString).length)
        textView.setSelectedRange(replaced)
        textView.scrollRangeToVisible(replaced)
        // The scope moved with the replacement; keeping the old one would scope the next Replace All
        // to a range that no longer describes the same text.
        regexScope = regexScope == nil ? nil : replaced
        window?.subtitle = String(localized: "Replaced \(out.count) match(es)")
    }

    /// The search scope, clipped to the document as it is now — it may have shrunk under an edit.
    private func clampedRegexScope(in text: String) -> NSRange? {
        guard let scope = regexScope else { return nil }
        let length = (text as NSString).length
        let location = min(max(0, scope.location), length)
        return NSRange(location: location, length: min(scope.length, length - location))
    }

    private func promptGotoLine() {
        let dialog = InputDialog(title: String(localized: "Go To"),
                                 prompt: String(localized: "Go to line (arithmetic allowed, e.g. 120+10):"),
                                 initialValue: "")
        dialog.onConfirm = { [weak self] text in
            // Through the offset evaluator (F-400), so "120 + 10" means the same here as in the viewer.
            guard let self, let value = HexAddress.parse(text), value > 0,
                  let line = Int(exactly: value) else { return }
            let ns = self.textView.string as NSString
            var loc = 0, current = 1
            while current < line, loc < ns.length {
                loc = NSMaxRange(ns.lineRange(for: NSRange(location: loc, length: 0)))
                current += 1
            }
            let sel = NSRange(location: min(loc, ns.length), length: 0)
            self.textView.setSelectedRange(sel)
            self.textView.scrollRangeToVisible(sel)
            self.textView.window?.makeFirstResponder(self.textView)
        }
        gotoDialog = dialog
        dialog.runModalDialog(over: window)
    }
}

// MARK: - Docked marks panel (host + split constraints)

/// Editor text view that reports Cmd+click (for go-to-definition).
final class EditorCodeTextView: NSTextView {
    /// Announced instead of a nameless text area (I19 T06).
    override func accessibilityLabel() -> String? {
        super.accessibilityLabel() ?? String(localized: "File contents")
    }

    var onCommandClick: ((Int) -> Void)?
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), let onCommandClick {
            let p = convert(event.locationInWindow, from: nil)
            onCommandClick(characterIndexForInsertion(at: p))
            return
        }
        super.mouseDown(with: event)
    }
}

extension EditorWindowController: MarksPanelHost {
    func marksPanelGroups() -> [MarksGroupVM] { markController.panelGroups() }
    func marksPanelReveal(groupID: Int, occurrenceIndex: Int) {
        markController.reveal(groupID: groupID, occurrenceIndex: occurrenceIndex)
    }
    func marksPanelRemoveOccurrence(groupID: Int, occurrenceIndex: Int) {
        markController.removeOccurrence(groupID: groupID, at: occurrenceIndex)
    }
    func marksPanelRemoveGroup(groupID: Int) { markController.removeGroup(groupID) }
    func marksPanelClearAll() { markController.clearAll() }
}
