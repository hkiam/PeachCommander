// EditorWindowController.swift - Built-in text/code editor (TODOS #25).
//
// An NSTextView-based editor: selection, undo, copy/paste and the system find bar
// come for free. Adds syntax highlighting (SyntaxHighlighter) applied to the text
// storage, JSON/XML formatting (StructuredTextFormatter), an encoding picker, and
// save-with-.bak-backup. Bound to F4 (cm_Edit) in place of the external editor.

import AppKit
import PCFoundation
import PCVFS

final class EditorWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate {
    var onClose: (() -> Void)?
    /// Fired after a successful local save. Used to upload the edited file back to
    /// its origin when it was downloaded from a writable network filesystem (F-214).
    var onSaved: (() -> Void)?

    private let path: String
    private let textView = EditorCodeTextView()
    private lazy var markController = TextMarkController(textView: textView)
    private lazy var marks = DocumentMarksPanel(content: scrollView, host: self)
    private var markDialog: MarkColorDialog?
    private var gotoDialog: InputDialog?
    /// Neon incremental tree-sitter highlighter (nil for non-tree-sitter files,
    /// which use the debounced one-shot lexer path instead).
    private var neon: NeonEditorHighlighter?
    private let scrollView = NSScrollView()
    private let encodingPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let statusLabel = NSTextField(labelWithString: "")

    private var encoding: TextEncodingChoice = .utf8
    private var language: SyntaxLanguage?
    private var isDirty = false
    private var didBackup = false
    private var highlightWork: DispatchWorkItem?

    // Collapsible symbol outline sidebar (classes/functions/methods via tree-sitter).
    private let symbolSidebar = SymbolSidebar()
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
        let formatButton = NSButton(title: String(localized: "Format JSON/XML"), target: self, action: #selector(format))
        formatButton.bezelStyle = .rounded
        let bracketButton = NSButton(title: "{ }", target: self, action: #selector(docJumpBracket))
        bracketButton.bezelStyle = .rounded
        bracketButton.keyEquivalent = "\\"
        bracketButton.keyEquivalentModifierMask = .command
        bracketButton.toolTip = String(localized: "Jump to matching bracket (⌘\\)")
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
        toolbar.addArrangedSubview(findButton)
        toolbar.addArrangedSubview(NSTextField(labelWithString: String(localized: "Encoding:")))
        toolbar.addArrangedSubview(encodingPopup)
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

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

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
        guard SymbolOutline.supports(ext: (path as NSString).pathExtension.lowercased()) else { return }
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
        let data = (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()
        let detected = EncodingDetector.detect(Array(data.prefix(64 * 1024)))
        encoding = TextEncodingChoice.from(detected) ?? .utf8
        encodingPopup.selectItem(withTitle: encoding.displayName)
        textView.string = String(data: data, encoding: encoding.encoding) ?? String(decoding: data, as: UTF8.self)
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
        if DocumentFile.writeWithBackup(data, toPath: path, didBackup: &didBackup) {
            isDirty = false
            updateTitleAndStatus()
            onSaved?()
        }
    }

    @objc private func encodingChanged() {
        if let choice = TextEncodingChoice.allCases.first(where: { $0.displayName == encodingPopup.titleOfSelectedItem }) {
            encoding = choice
            updateTitleAndStatus()
        }
    }

    @objc private func format() {
        let ext = (path as NSString).pathExtension.lowercased()
        guard let result = StructuredTextFormatter.autoFormat(textView.string, preferXML: ext == "xml") else {
            NSSound.beep(); return
        }
        textView.string = result.text
        isDirty = true
        refreshHighlight()
        refreshSymbols()
        minimap?.refresh()
        updateTitleAndStatus()
    }

    // MARK: - Highlighting

    func textViewDidChangeSelection(_ notification: Notification) {
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
        window?.title = (isDirty ? "• " : "") + name
        let langName = language?.name
            ?? TreeSitterLanguages.displayName(forExtension: (path as NSString).pathExtension)
            ?? String(localized: "Plain")
        let crumb = symbolPathText.isEmpty ? "" : "   ▸ \(symbolPathText)"
        statusLabel.stringValue = "\(langName)   \(encoding.displayName)\(isDirty ? "   —   \(String(localized: "modified"))" : "")\(crumb)"
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
        c.goto = true
        c.marks = true
        c.markNav = true
        return c
    }

    // Native undo/cut/copy/paste/select-all via the responder chain.
    func makeEditMenu() -> NSMenu { AppMenu.standardEditMenu() }

    func toolMenus() -> [NSMenu] {
        DocumentMenus.toolMenus(caps: documentCaps, editMenu: makeEditMenu(), target: self)
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
    @objc func docFindNext() { finder(.nextMatch) }
    @objc func docFindPrev() { finder(.previousMatch) }
    @objc func docReplace() { finder(.showReplaceInterface) }
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

    private func promptGotoLine() {
        let dialog = InputDialog(title: String(localized: "Go To"),
                                 prompt: String(localized: "Go to line:"), initialValue: "")
        dialog.onConfirm = { [weak self] text in
            guard let self, let line = Int(text.trimmingCharacters(in: .whitespaces)), line > 0 else { return }
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
