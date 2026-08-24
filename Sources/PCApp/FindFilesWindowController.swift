// SPDX-License-Identifier: Apache-2.0
// FindFilesWindowController.swift - "Find Files" dialog (Alt+F7)
//
// A dumb, non-modal view: it collects a query from the user and reports it
// via `onStart`, then displays results as they are streamed in via
// `addResult`/`setStatus`/`searchFinished`. It performs no searching itself.

import AppKit
import PCFoundation
import PCVFS

/// Non-modal "Find Files" dialog window controller.
@MainActor
public final class FindFilesWindowController: NSWindowController {
    private let logger = PCFoundationLogger.logger

    /// Fired when the user presses Start with the assembled search template plus
    /// the per-run scope options (start directory, selection-only, Spotlight).
    public var onStart: ((_ template: SearchTemplate, _ startDirectory: String,
                          _ inSelectionOnly: Bool, _ useSpotlight: Bool, _ searchArchives: Bool,
                          _ notContaining: Bool, _ contentPredicate: ContentFieldPredicate?,
                          _ searchPluginText: Bool,
                          _ searchComments: Bool) -> Void)?
    /// Fired when the user presses Cancel/Stop during a running search.
    public var onCancel: (() -> Void)?
    /// Fired by "Feed to Listbox" with the current result paths.
    public var onFeedToListbox: (([String]) -> Void)?
    /// Fired by "View" (F3) with the selected result path (nil if none selected).
    public var onView: ((String) -> Void)?

    /// One result row: the path plus (for content searches) the first matching
    /// line number and a short preview of that line.
    private struct ResultRow { let path: String; let line: Int?; let preview: String? }
    /// Current result rows, backing the table view's data source.
    private var results: [ResultRow] = []
    /// True while a search is in progress (Start acts as Stop).
    private var isSearching = false

    /// "Search for:" and "Find text:" are combo boxes rather than plain fields because each carries its
    /// own history (F-406) — a dropdown of what was searched for before, most recent first. `NSComboBox`
    /// *is* an `NSTextField`, so everything else in this file reads and writes them unchanged.
    private let nameMaskField = NSComboBox()
    private let startDirField = NSTextField()
    // Content-field predicate (F-157): "<field> <op> <value>", e.g. fileinfo.width > 1000.
    private let contentFieldCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let contentFieldPopup = NSPopUpButton()
    private let contentOpPopup = NSPopUpButton()
    private let contentValueField = NSTextField()
    /// Available content fields (qualified id → display title), set by the owner.
    private var contentFields: [(id: String, title: String)] = []
    // Attribute filters (F-152): tri-state Any / Yes / No.
    private let hiddenAttrPopup = NSPopUpButton()
    private let readOnlyAttrPopup = NSPopUpButton()
    private let findTextField = NSComboBox()
    private let caseSensitiveCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let regexCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let wholeWordCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let hexCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let encodingCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let notContainingCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let includeDirsCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let emptyDirsCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let searchArchivesCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    /// Search what a plugin makes of a file instead of the file's own bytes (F-351).
    ///
    /// Shown only when a loaded plugin actually offers full text, because a checkbox that can never
    /// change an outcome is worse than an absent one — see `setHasPluginText`.
    private let pluginTextCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    /// Also look for the find text in a file's comment (F-373).
    private let commentsCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let inSelectionCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let spotlightCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let sizeMinField = NSTextField()
    private let sizeMaxField = NSTextField()
    private let dateAfterCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let dateAfterPicker = NSDatePicker()
    private let dateBeforeCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let dateBeforePicker = NSDatePicker()
    private let recentDaysField = NSTextField()   // "modified within last N days" (F-152)
    private let templatePopup = NSPopUpButton()
    private let maxDepthPopup = NSPopUpButton()
    /// The tabbed options area (F-150).
    private let optionsTabView = NSTabView()

    /// Saved-template persistence + current list (populates the template popup).
    private var templateStore: SearchTemplateStore?
    private var templates: [SearchTemplate] = []
    /// What the two search fields remember (F-406); nil when the owner passed no config root, which is
    /// how the dialog behaves in tests: everything works, nothing is written.
    private var history: FindFilesHistory?
    private let clearHistoryButton = NSButton()
    private let statusLabel = NSTextField(labelWithString: "")
    private let tableView = NSTableView()   // results; labelled in `build` (I19 T06)
    private let startStopButton = NSButton()
    private let viewButton = NSButton()
    private let feedButton = NSButton()
    private let detailsButton = NSButton()
    private let closeButton = NSButton()

    private static let resultColumnIdentifier = NSUserInterfaceItemIdentifier("path")
    private static let resultCellIdentifier = NSUserInterfaceItemIdentifier("pathCell")

    /// Creates the dialog, prefilling the search directory. `templatesURL` enables
    /// the saved-template picker (Find dialog persists templates as JSON there);
    /// `configRoot` enables the two search fields' histories (F-406).
    public init(startDirectory: String, templatesURL: URL? = nil, configRoot: URL? = nil) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 670),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Find Files")
        window.center()
        super.init(window: window)
        if let templatesURL {
            let store = SearchTemplateStore(url: templatesURL)
            templateStore = store
            templates = store.load()
        }
        if let configRoot { history = FindFilesHistory(configRoot: configRoot) }
        setupDialog(startDirectory: startDirectory)
        reloadTemplatePopup()
        reloadHistories()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Show the window (non-modal), centered, key.
    public func showWindow() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Select an options tab by index (0=General … 3=Load/Save). Used by automation.
    public func selectTab(_ index: Int) {
        guard index >= 0, index < optionsTabView.numberOfTabViewItems else { return }
        optionsTabView.selectTabViewItem(at: index)
    }

    #if DEBUG
    /// Set the name mask and trigger a search (automation; verifies the tabbed
    /// refactor kept the controls wired). Returns nothing; results stream in.
    public func automationStart(mask: String) {
        nameMaskField.stringValue = mask
        handleStartStop()
    }

    /// Run a content search with "also search file comments" on, and report what came back (F-373).
    ///
    /// Driving the real controls — the find-text field, the option, Start — because the question is
    /// whether the option reaches the engine at all. It did not on the first attempt: the flag was set and
    /// the local fast path ignored the provider, exactly as the plugin-text option once did.
    public func automationSearchComments(mask: String, text: String, directory: String) {
        nameMaskField.stringValue = mask
        findTextField.stringValue = text
        commentsCheckbox.state = .on
        startDirField.stringValue = directory
        updateOptionAvailability()
        handleStartStop()
    }

    /// Run a search with both fields set, so the content term is recorded too (F-406).
    public func automationStart(mask: String, text: String) {
        nameMaskField.stringValue = mask
        findTextField.stringValue = text
        updateOptionAvailability()
        handleStartStop()
    }

    /// Type into "Find text" the way a person does — through the field editor, so the change
    /// notification that drives the options is the real one (F-407). Assigning `stringValue` posts
    /// nothing, and a scenario built on that would pass while the dialog sat there with dead options.
    public func automationTypeFindText(_ text: String) {
        guard let window else { return }
        window.makeFirstResponder(findTextField)
        guard let editor = window.firstResponder as? NSTextView, editor.isFieldEditor else { return }
        editor.selectAll(nil)
        if text.isEmpty { editor.deleteBackward(nil) } else { editor.insertText(text, replacementRange: editor.selectedRange()) }
    }

    /// Diagnostic: what the content term is, and which options it made available (F-407).
    ///
    /// `contentTerm` comes from the assembled template rather than the field, because the question the
    /// checkbox used to answer is now "does this search carry a content term at all".
    public func automationOptionsDump() -> String {
        let template = currentTemplate(name: "")
        func state(_ b: NSButton) -> String { b.isEnabled ? "on" : "off" }
        // The label column is measured from the longest label (see `alignRowLabels`), and truncation is a
        // width comparison rather than something a screenshot of one language could show: 90 pt fits
        // "Search for:" and cuts the Hungarian "Szöveg keresése:" in half.
        // Only the labels of the tab on screen: a page that is not the visible one is laid out at
        // whatever width it last had — measured, the Advanced tab's label sat at 91 pt while asking for
        // 114 — which says nothing about truncation in the dialog the reader is looking at.
        let page = optionsTabView.selectedTabViewItem?.view
        let shown = rowLabels.filter { label in page.map(label.isDescendant(of:)) ?? false }
        let fits = shown.allSatisfy { $0.frame.width + 0.5 >= $0.fittingSize.width }
        let measured = shown.map { "\($0.stringValue)=\(Int($0.frame.width))/\(Int($0.fittingSize.width))" }
        return "labelColumn=\(Int(shown.map(\.frame.width).max() ?? 0))\nlabelsFit=\(fits)\n"
            + "labels=\(measured.joined(separator: " "))\n"
            + "typed=[\(findTextField.stringValue)]\nfieldEnabled=\(findTextField.isEnabled)\n"
            + "case=\(state(caseSensitiveCheckbox))\nregex=\(state(regexCheckbox))\n"
            + "hex=\(state(hexCheckbox))\nwholeWord=\(state(wholeWordCheckbox))\n"
            + "notContaining=\(state(notContainingCheckbox))\ncomments=\(state(commentsCheckbox))\n"
            + "contentTerm=\(template.contentText ?? template.hexContent ?? "-")\n"
    }

    /// Point a scripted search at a directory (automation).
    public func automationSetDirectory(_ path: String) {
        startDirField.stringValue = path
    }

    /// "View" on the first result, exactly as the button does — the path a hit takes into the viewer,
    /// including the search it should arrive with (F-407).
    public func automationViewFirstResult() {
        guard let first = results.first else { return }
        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        onView?(first.path)
    }

    /// Diagnostic: what each field's dropdown offers, in order — the only way to see a history that is
    /// otherwise a list AppKit draws in a popped-up window.
    public func automationHistoryDump() -> String {
        "names=" + nameMaskField.objectValues.map { "\($0)" }.joined(separator: ",") + "\n"
        + "texts=" + findTextField.objectValues.map { "\($0)" }.joined(separator: ",") + "\n"
    }

    /// Clear the histories without the confirmation alert — a modal would stall the whole script.
    public func automationClearHistory() {
        performClearHistory()
    }

    /// Diagnostic: the result rows as shown, one per line, with the preview column.
    ///
    /// The full path, not just the last component, for archive hits: `secret.txt` alone
    /// cannot say whether the walk went inside `backup.tar.gz` — which is the whole
    /// question a scenario about searching archives is asking.
    public func automationResults() -> String {
        "count=\(results.count)\n" + results.map { row in
            "\(row.path)|line=\(row.line.map(String.init) ?? "-")|\(row.preview ?? "")"
        }.joined(separator: "\n") + "\n"
    }

    /// Diagnostic: the status line, which is where a run says what it could not look
    /// inside (F-463). A scenario has to be able to read it, or "it reported the skip"
    /// stays an assumption.
    public func automationStatus() -> String { statusLabel.stringValue }

    /// Diagnostic: how many places the last run declined to look, as a number.
    ///
    /// Beside the status line rather than parsed out of it: that line is translated into
    /// nineteen languages, so a check written against its words would pass or fail on the
    /// guest machine's locale rather than on the behaviour.
    public func automationSkippedCount() -> Int { skippedCount }

    /// Send every result to the panel, the way the button does (F-463).
    public func automationFeedToListbox() { onFeedToListbox?(results.map(\.path)) }

    /// Open the first result in the viewer, the way F3 does (F-463).
    public func automationViewResult(at index: Int) {
        guard results.indices.contains(index) else { return }
        onView?(results[index].path)
    }

    /// Run a search that descends into archives (F-153/F-463).
    public func automationSearchArchives(mask: String, text: String, directory: String) {
        nameMaskField.stringValue = mask
        findTextField.stringValue = text
        searchArchivesCheckbox.state = .on
        startDirField.stringValue = directory
        updateOptionAvailability()
        handleStartStop()
    }
    #endif

    /// Append a streamed result row (call on the main actor). For content searches,
    /// `matchLine`/`matchPreview` show where the text was found.
    public func addResult(_ path: String, matchLine: Int? = nil, matchPreview: String? = nil) {
        results.append(ResultRow(path: path, line: matchLine, preview: matchPreview))
        tableView.insertRows(at: IndexSet(integer: results.count - 1), withAnimation: [])
    }

    /// Clear the results list (called at the start of a new search).
    public func clearResults() {
        results.removeAll()
        tableView.reloadData()
        setNotices([])
    }

    /// How many archives the last run could not look inside (F-463), for diagnostics.
    public var skippedCount = 0

    /// Which archives, and why — shown by the Details… button.
    ///
    /// A count in the status line says a search was incomplete; it does not say *which*
    /// file to go and look at yourself, which is the only thing a person can act on.
    private var notices: [(path: String, message: String)] = []

    /// Hand the dialog what the last run declined to look inside.
    public func setNotices(_ entries: [(path: String, message: String)]) {
        notices = entries
        skippedCount = entries.count
        detailsButton.isHidden = entries.isEmpty
    }

    @objc private func handleDetails() {
        ErrorLogWindowController.present(
            over: window,
            summary: String(localized: "These archives were not searched, or not searched in full:"),
            entries: notices)
    }

    /// Update the status line (e.g. "42 found — searching…" / "Done: 42 found").
    public func setStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    /// Mark the search finished (re-enables Start, relabels the Start/Stop button).
    public func searchFinished() {
        isSearching = false
        startStopButton.title = String(localized: "Start")
    }

    // MARK: - Layout

    private func setupDialog(startDirectory: String) {
        guard let window else { return }
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        // --- Configure every control (titles / fonts / actions / tooltips) ---
        nameMaskField.stringValue = "*.*"
        nameMaskField.font = Fonts.system13
        startDirField.stringValue = startDirectory
        startDirField.font = Fonts.system13
        startDirField.toolTip = String(localized: "One or more folders, separated by “;”, are each searched (F-150).")

        // No checkbox in front of the content term (F-407): the field decides. Something in it is
        // searched for, an empty one is not — which is what the tick box said anyway, one click later,
        // and it could disagree with the field it gated ("case sensitive" greyed out with a term sitting
        // right there). The text is not lost by turning the search off either: it is in the field's own
        // history now, so clearing it is undoable in a way unticking a box never made it.
        findTextField.font = Fonts.system13
        preferWidth(findTextField, atLeast: 280)
        // The options below the field follow what is typed, so they cannot lag behind it.
        findTextField.delegate = self

        // The two history dropdowns (F-406). No inline completion: a search field that finishes the
        // word for you turns "*.s" into last week's "*.swift" the moment you stop typing, and the term
        // that actually ran would then be one nobody typed.
        for (combo, label) in [(nameMaskField, String(localized: "Search for:")),
                               (findTextField, String(localized: "Find text:"))] {
            combo.usesDataSource = false
            combo.completes = false
            // 20 remembered entries in a 5-row list is four scrolls to reach the oldest.
            combo.numberOfVisibleItems = 10
            // A combo box announces itself as an unlabelled one: the row's own label is a separate view
            // and AppKit does not connect the two (I19 T06).
            combo.setAccessibilityLabel(label)
        }

        caseSensitiveCheckbox.title = String(localized: "Case sensitive"); caseSensitiveCheckbox.font = Fonts.system13
        regexCheckbox.title = String(localized: "Regular expression"); regexCheckbox.font = Fonts.system13
        regexCheckbox.toolTip = String(localized: "Treat the name mask and search text as regular expressions (ICU)")
        wholeWordCheckbox.title = String(localized: "Whole word"); wholeWordCheckbox.font = Fonts.system13
        wholeWordCheckbox.toolTip = String(localized: "Match the search text only at word boundaries (plain-text mode)")

        inSelectionCheckbox.title = String(localized: "Search in selected items only")
        inSelectionCheckbox.font = Fonts.system13
        inSelectionCheckbox.toolTip = String(localized: "Limit the search to the items currently selected in the active panel")
        spotlightCheckbox.title = String(localized: "Use Spotlight (fast, indexed local folders)")
        spotlightCheckbox.font = Fonts.system13
        spotlightCheckbox.target = self; spotlightCheckbox.action = #selector(optionsChanged)
        spotlightCheckbox.toolTip = String(localized: "Query the Spotlight index instead of scanning. Local folders only; ignores regex, depth and selection scope.")
        includeDirsCheckbox.title = String(localized: "Include folders in results")
        includeDirsCheckbox.font = Fonts.system13
        includeDirsCheckbox.toolTip = String(localized: "Also list folders whose name matches, not only files")
        emptyDirsCheckbox.title = String(localized: "Empty folders only")
        emptyDirsCheckbox.font = Fonts.system13
        emptyDirsCheckbox.toolTip = String(localized: "List folders that contain nothing at all — including invisible entries, so a folder holding only a .DS_Store or a .git does not count as empty. Files are not listed.")
        emptyDirsCheckbox.target = self
        emptyDirsCheckbox.action = #selector(optionsChanged)
        // No format list, in either string. It was "zip, jar, war" while the panel could
        // already open tar, 7z and whatever a plugin added — and any list written here is
        // wrong again the next time a plugin ships, in nineteen languages at once.
        searchArchivesCheckbox.title = String(localized: "Search inside archives")
        searchArchivesCheckbox.font = Fonts.system13
        searchArchivesCheckbox.toolTip = String(localized: "Open archives found during the search and search their contents too — the same formats you can open with Enter. Slower. Archives that could not be opened are reported when the search finishes.")
        pluginTextCheckbox.title = String(localized: "Search text provided by plugins (e.g. decompiled source)")
        pluginTextCheckbox.font = Fonts.system13
        pluginTextCheckbox.toolTip = String(localized: "For files a plugin can turn into text — a .class as decompiled Java — search that text instead of the file's bytes. Slower: producing the text can mean running a decompiler.")
        pluginTextCheckbox.isHidden = true
        commentsCheckbox.title = String(localized: "Also search file comments")
        commentsCheckbox.font = Fonts.system13
        commentsCheckbox.toolTip = String(localized: "Look for the text in each file's comment as well as in its contents: the comment from Ctrl+Z, or the Finder comment when there is none. A plugin's note is a content field — filter on it under Plugins.")
        commentsCheckbox.setAccessibilityLabel(String(localized: "Also search file comments"))

        hexCheckbox.title = String(localized: "Hex content search")
        hexCheckbox.font = Fonts.system13
        hexCheckbox.target = self; hexCheckbox.action = #selector(optionsChanged)
        hexCheckbox.toolTip = String(localized: "Interpret the search text as hex bytes (e.g. “48 65 6C”).")
        encodingCheckbox.title = String(localized: "Encoding-aware")
        encodingCheckbox.font = Fonts.system13
        encodingCheckbox.toolTip = String(localized: "Detect each file’s text encoding before matching (UTF-8 / UTF-16 / Latin-1).")
        notContainingCheckbox.title = String(localized: "Not containing")
        notContainingCheckbox.font = Fonts.system13
        notContainingCheckbox.toolTip = String(localized: "Match files that do NOT contain the search text/bytes.")

        // Size range.
        let sizeLabel = NSTextField(labelWithString: String(localized: "Size:")); sizeLabel.font = Fonts.system13
        let toLabel = NSTextField(labelWithString: String(localized: "to")); toLabel.font = Fonts.system13
        sizeMinField.placeholderString = String(localized: "min (e.g. 10K)")
        sizeMaxField.placeholderString = String(localized: "max (e.g. 5M)")
        for f in [sizeMinField, sizeMaxField] {
            f.font = Fonts.system13
            preferWidth(f, exactly: 130)
        }
        let sizeRow = hStack([sizeLabel, sizeMinField, toLabel, sizeMaxField], spacing: 8)

        // Modified-date range (each side gated by its checkbox).
        dateAfterCheckbox.title = String(localized: "Modified after:"); dateAfterCheckbox.font = Fonts.system13
        dateAfterCheckbox.action = #selector(toggleDateAfter); dateAfterCheckbox.target = self
        dateBeforeCheckbox.title = String(localized: "before:"); dateBeforeCheckbox.font = Fonts.system13
        dateBeforeCheckbox.action = #selector(toggleDateBefore); dateBeforeCheckbox.target = self
        for p in [dateAfterPicker, dateBeforePicker] {
            p.datePickerStyle = .textFieldAndStepper
            p.datePickerElements = .yearMonthDay
            p.dateValue = Date()
            p.isEnabled = false
        }
        recentDaysField.placeholderString = String(localized: "N")
        recentDaysField.alignment = .right
        preferWidth(recentDaysField, exactly: 44)
        let recentLabel = NSTextField(labelWithString: String(localized: "or within last")); recentLabel.font = Fonts.system13
        let daysLabel = NSTextField(labelWithString: String(localized: "days")); daysLabel.font = Fonts.system13
        let dateRow = hStack([dateAfterCheckbox, dateAfterPicker, dateBeforeCheckbox, dateBeforePicker,
                              recentLabel, recentDaysField, daysLabel], spacing: 8)

        // Content-field predicate (F-157): search by a plugin-provided field.
        contentFieldCheckbox.title = String(localized: "Field:")
        contentFieldCheckbox.font = Fonts.system13
        contentFieldCheckbox.target = self; contentFieldCheckbox.action = #selector(optionsChanged)
        contentFieldCheckbox.toolTip = String(localized: "Also require a content-plugin field to satisfy a condition (e.g. image width > 1000).")
        for op in ContentOperator.allCases { contentOpPopup.addItem(withTitle: op.rawValue) }
        contentValueField.placeholderString = String(localized: "value")
        contentValueField.font = Fonts.system13
        preferWidth(contentValueField, exactly: 120)
        preferWidth(contentFieldPopup, atLeast: 140)
        let contentFieldRow = hStack([contentFieldCheckbox, contentFieldPopup, contentOpPopup, contentValueField], spacing: 8)

        // Attribute filters (F-152): tri-state Any / Yes / No per attribute.
        let attrItems = [String(localized: "Any"), String(localized: "Yes"), String(localized: "No")]
        for p in [hiddenAttrPopup, readOnlyAttrPopup] { p.addItems(withTitles: attrItems) }
        let attrLabel = NSTextField(labelWithString: String(localized: "Attributes:")); attrLabel.font = Fonts.system13
        let hiddenLabel = NSTextField(labelWithString: String(localized: "Hidden:")); hiddenLabel.font = Fonts.system13
        let roLabel = NSTextField(labelWithString: String(localized: "Read-only:")); roLabel.font = Fonts.system13
        let attrRow = hStack([attrLabel, hiddenLabel, hiddenAttrPopup, roLabel, readOnlyAttrPopup], spacing: 8)

        maxDepthPopup.addItems(withTitles: [String(localized: "All"), "1", "2", "3", "5", "10"])

        // Saved-template picker + save button (Load / Save tab).
        let tmplLabel = NSTextField(labelWithString: String(localized: "Template:")); tmplLabel.font = Fonts.system13
        templatePopup.action = #selector(applySelectedTemplate); templatePopup.target = self
        preferWidth(templatePopup, atLeast: 200)
        let saveTemplateButton = NSButton(title: String(localized: "Save as Template…"),
                                          target: self, action: #selector(saveTemplate))
        saveTemplateButton.bezelStyle = .rounded
        let tmplRow = hStack([tmplLabel, templatePopup, saveTemplateButton], spacing: 8)

        // Emptying the two field histories (F-406). Here rather than beside the fields themselves: it is
        // housekeeping, it is done rarely, and this tab is already where the dialog's stored things are
        // managed — while a button under "Search for" would be one more control between the user and
        // starting a search.
        clearHistoryButton.title = String(localized: "Clear History…")
        clearHistoryButton.bezelStyle = .rounded
        clearHistoryButton.target = self
        clearHistoryButton.action = #selector(clearHistory)
        clearHistoryButton.toolTip = String(localized: "Forget the entries remembered by the “Search for” and “Find text” fields.")

        // --- Tabbed options area (F-150): General / Advanced / Plugins / Load & Save ---
        let tabView = optionsTabView
        tabView.translatesAutoresizingMaskIntoConstraints = false
        // Otherwise a screen reader announces only "tab group" here (I19 T06).
        tabView.setAccessibilityLabel(String(localized: "Search options"))
        tabView.addTabViewItem(makeTab(String(localized: "General"), rows: [
            labeledField(String(localized: "Search for:"), nameMaskField),
            labeledField(String(localized: "Search in:"), startDirField),
            labeledField(String(localized: "Find text:"), findTextField),
            hStack([caseSensitiveCheckbox, regexCheckbox, wholeWordCheckbox], spacing: 20),
            hStack([hexCheckbox, encodingCheckbox, notContainingCheckbox], spacing: 20),
            inSelectionCheckbox,
            spotlightCheckbox,
            hStack([includeDirsCheckbox, searchArchivesCheckbox], spacing: 20),
            emptyDirsCheckbox,
            pluginTextCheckbox,
            commentsCheckbox,
        ]))
        tabView.addTabViewItem(makeTab(String(localized: "Advanced"), rows: [
            sizeRow, dateRow, attrRow,
            labeledField(String(localized: "Max depth:"), maxDepthPopup, controlMinWidth: 100),
        ]))
        tabView.addTabViewItem(makeTab(String(localized: "Plugins"), rows: [
            hintLabel(String(localized: "Require a content-plugin field to satisfy a condition (e.g. image width > 1000).")),
            contentFieldRow,
        ]))
        tabView.addTabViewItem(makeTab(String(localized: "Load / Save"), rows: [
            hintLabel(String(localized: "Load a saved search, or save the current settings as a reusable template.")),
            tmplRow,
            hintLabel(String(localized: "“Search for” and “Find text” each offer the last 20 entries you searched with, most recently used first.")),
            clearHistoryButton,
        ]))
        content.addSubview(tabView)

        statusLabel.font = Fonts.system13
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(statusLabel)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let column = NSTableColumn(identifier: Self.resultColumnIdentifier)
        column.title = String(localized: "Path")
        column.width = 580
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = Metrics.rowHeight
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.dataSource = self
        tableView.delegate = self
        // Otherwise the results are announced as an unnamed table (I19 T06).
        tableView.setAccessibilityLabel(String(localized: "Search results"))
        tableView.target = self
        tableView.doubleAction = #selector(handleDoubleClick)
        scrollView.documentView = tableView
        content.addSubview(scrollView)

        let buttons = NSStackView()
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.orientation = .horizontal
        buttons.spacing = 10

        startStopButton.title = String(localized: "Start")
        startStopButton.bezelStyle = .rounded
        startStopButton.keyEquivalent = "\r"
        startStopButton.action = #selector(handleStartStop)
        startStopButton.target = self

        viewButton.title = String(localized: "View")
        viewButton.bezelStyle = .rounded
        viewButton.action = #selector(handleView)
        viewButton.target = self

        feedButton.title = String(localized: "Feed to Listbox")
        feedButton.bezelStyle = .rounded
        feedButton.action = #selector(handleFeed)
        feedButton.target = self

        // Hidden unless the last run had something to report. A button that is always
        // there but usually does nothing is a button people stop reading, and the whole
        // point of the count beside it is that it means something when it appears.
        detailsButton.title = String(localized: "Details…")
        detailsButton.bezelStyle = .rounded
        detailsButton.action = #selector(handleDetails)
        detailsButton.target = self
        detailsButton.isHidden = true

        closeButton.title = String(localized: "Close")
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\u{1B}"
        closeButton.action = #selector(handleClose)
        closeButton.target = self

        buttons.addView(startStopButton, in: .trailing)
        buttons.addView(viewButton, in: .trailing)
        buttons.addView(feedButton, in: .trailing)
        buttons.addView(detailsButton, in: .trailing)
        buttons.addView(closeButton, in: .trailing)
        content.addSubview(buttons)

        // A floor from the tallest tab's own fitting height, plus what NSTabView spends on its tab
        // strip and border. Nothing here is a chosen number: the stacks report what they need.
        // Measured, not chosen: the General tab's stack reports 250 pt and the others less, and 34 is
        // what NSTabView spends on its strip and border.
        let tallest = tabStacks.map(\.fittingSize.height).max() ?? 300
        let tabHeightConstraint = tabView.heightAnchor.constraint(
            greaterThanOrEqualToConstant: tallest + 34)
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            tabView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            // At least tall enough for the tallest tab, never exactly that. 250 was already short
            // before the plugin-text row went in — "Done: n found" overlapped the last row — and
            // pinning it to a measured 320 only moved the problem: with a bottom constraint added the
            // stack's own minimum spacings no longer fit, and AppKit reported the whole set on every
            // layout pass. A lower bound lets the tab grow with its content and leaves the arithmetic
            // to the layout engine, which is better at it than a constant chosen by eye.
            tabHeightConstraint,

            statusLabel.topAnchor.constraint(equalTo: tabView.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -12),
            // A floor for the results. Deriving the tab's height from its content made the tab taller
            // than the constant it replaced, and with nothing holding the list open it collapsed to
            // nothing: "Done: 2 found" with no way to see the two. The window grows instead — it is
            // resizable, and Auto Layout raises its minimum size to fit.
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),

            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])
        alignRowLabels()
        updateOptionAvailability()
    }

    /// One width for every "label: control" row, measured from the longest label rather than chosen.
    ///
    /// 90 pt was enough for "Search for:" in English and is not enough for "Szöveg keresése:" — and a
    /// truncated label in a dialog whose whole subject is text is the kind of thing only a Hungarian user
    /// would ever report. The labels report what they need; the widest one sets the column, so the rows
    /// stay aligned in all nineteen languages.
    private func alignRowLabels() {
        let widest = rowLabels.map(\.fittingSize.width).max() ?? 90
        for label in rowLabels { preferWidth(label, exactly: max(90, widest.rounded(.up))) }
    }

    /// A horizontal stack row of leading-aligned controls.
    private func hStack(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .horizontal
        s.alignment = .centerY
        s.spacing = spacing
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }

    /// A "label: control" row: a right-aligned label plus the control. The label's width is settled once
    /// all of them exist, by `alignRowLabels`.
    private func labeledField(_ title: String, _ control: NSView, controlMinWidth: CGFloat = 300) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = Fonts.system13
        label.alignment = .right
        rowLabels.append(label)
        preferWidth(control, atLeast: controlMinWidth)
        return hStack([label, control], spacing: 8)
    }

    /// The labels of the "label: control" rows, so their column can be measured (see `alignRowLabels`).
    private var rowLabels: [NSTextField] = []

    /// A dimmed, wrapping explanatory label used at the top of a sparse tab.
    private func hintLabel(_ text: String) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: text)
        l.font = NSFont.systemFont(ofSize: 11)
        l.textColor = .secondaryLabelColor
        l.widthAnchor.constraint(lessThanOrEqualToConstant: 560).isActive = true
        return l
    }

    /// Build a tab page: a top-anchored vertical stack of `rows` inside a container.
    /// The stacks inside the tabs, so the tab view's minimum height can be *measured* rather than
    /// guessed. Two guesses in a row got it wrong: 250 clipped the content silently, and 320 turned
    /// that into a reported conflict on every layout pass once the tab gained a bottom bound.
    private var tabStacks: [NSStackView] = []

    private func makeTab(_ title: String, rows: [NSView]) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: title)
        item.label = title
        let page = NSView()
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(stack)
        let stackBottom = stack.bottomAnchor.constraint(lessThanOrEqualTo: page.bottomAnchor)
        stackBottom.priority = .init(999)
        // Same reasoning one dimension over: a page that is not the visible tab has no width either,
        // and the rows inside carry the stack's own minimum spacings, which cannot be lowered from
        // out here. Pinning the leading edge as a rule made those minimums the reported conflict.
        let stackLeading = stack.leadingAnchor.constraint(equalTo: page.leadingAnchor)
        stackLeading.priority = .init(999)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: page.topAnchor),
            stackLeading,
            stack.trailingAnchor.constraint(lessThanOrEqualTo: page.trailingAnchor),
            // An advisory bound, not a rule. Without it a tab whose rows outgrow its height drew over
            // whatever was below and nothing reported it; required, it became the loudest conflict in
            // the app, because a tab page that is not the visible one has height *zero* until it is
            // shown, and no stack fits in nothing. Measured: the visible page was 380 pt with a stack
            // needing 250, while the three hidden ones were 0 pt with stacks needing 154 and 76 —
            // there was never a shortage of room, only a constraint applied to pages that had no size
            // yet. Same shape as the preview panel's `width == 0`.
            //
            // At 999 it yields on a zero-height page and still shapes the layout everywhere else.
            // Real overflow is caught by the regression harness's screenshots, which is where a human
            // would notice it anyway.
            stackBottom,
        ])
        tabStacks.append(stack)
        item.view = page
        return item
    }

    /// Maps the max-depth popup's selected title to a depth value ("All" -> 0).
    private func depthValue() -> Int {
        guard let title = maxDepthPopup.titleOfSelectedItem, let depth = Int(title) else { return 0 }
        return depth
    }

    // MARK: - Actions

    @objc private func optionsChanged() { updateOptionAvailability() }

    /// Is there a content term to search for? The field alone decides (F-407).
    private var hasContentTerm: Bool {
        !findTextField.stringValue.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Enable only the option combinations that make sense together:
    /// - content sub-options (hex / whole-word / encoding-aware) need "Find text";
    /// - hex is an exact byte match, so it disables regex / whole-word / encoding;
    /// - Spotlight does its own name+content lookup, so it disables everything it
    ///   ignores (regex, depth, selection, size/date/archives, and the content
    ///   refinements).
    private func updateOptionAvailability() {
        let spotlight = spotlightCheckbox.state == .on
        // Looking for empty folders is a different question: there are no files, so nothing about
        // their *content* applies. Everything below reads `findText`, so disabling the content
        // search at the source disables all of it — text can stay in the field from a previous
        // search without any of it quietly taking effect.
        let emptyDirs = emptyDirsCheckbox.state == .on
        let findText = hasContentTerm && !emptyDirs
        let hex = hexCheckbox.state == .on && findText && !spotlight

        findTextField.isEnabled = !emptyDirs
        hexCheckbox.isEnabled = findText && !spotlight
        wholeWordCheckbox.isEnabled = findText && !hex && !spotlight
        encodingCheckbox.isEnabled = findText && !hex && !spotlight
        // "Not containing" works with text or hex; only needs a content term + no Spotlight.
        notContainingCheckbox.isEnabled = findText && !spotlight
        regexCheckbox.isEnabled = !hex && !spotlight
        caseSensitiveCheckbox.isEnabled = !hex && !spotlight
        maxDepthPopup.isEnabled = !spotlight
        inSelectionCheckbox.isEnabled = !spotlight
        emptyDirsCheckbox.isEnabled = !spotlight
        includeDirsCheckbox.isEnabled = !spotlight && !emptyDirs
        searchArchivesCheckbox.isEnabled = !spotlight && !emptyDirs
        // Spotlight answers from its own index and never opens the file, so no plugin can contribute
        // to it; and with no content term there is no text to search for.
        pluginTextCheckbox.isEnabled = !spotlight && findText
        // A comment search needs text to look for, and Spotlight answers a different question entirely.
        commentsCheckbox.isEnabled = !spotlight && findText && hexCheckbox.state != .on
        sizeMinField.isEnabled = !spotlight && !emptyDirs
        sizeMaxField.isEnabled = !spotlight && !emptyDirs
        dateAfterCheckbox.isEnabled = !spotlight
        dateBeforeCheckbox.isEnabled = !spotlight
        dateAfterPicker.isEnabled = !spotlight && dateAfterCheckbox.state == .on
        dateBeforePicker.isEnabled = !spotlight && dateBeforeCheckbox.state == .on
    }

    /// Activate a width the layout should honour *if it can*.
    ///
    /// Every width in this dialog is a preference about how wide a control looks, not a fact about the
    /// world — and during setup the page it sits in has no width at all, so as required rules they
    /// cannot hold and AppKit reports the row. At 999 the rows still get the shape they ask for and a
    /// zero-width page costs nothing. Measured: this and the tab pages' bottom bound together took the
    /// dialog from 37 reported conflicts to 12.
    private func preferWidth(_ view: NSView, exactly: CGFloat? = nil, atLeast: CGFloat? = nil) {
        for constraint in [exactly.map { view.widthAnchor.constraint(equalToConstant: $0) },
                           atLeast.map { view.widthAnchor.constraint(greaterThanOrEqualToConstant: $0) }]
        .compactMap({ $0 }) {
            constraint.priority = .init(999)
            constraint.isActive = true
        }
    }

    @objc private func handleStartStop() {
        if isSearching {
            onCancel?()
            return
        }
        isSearching = true
        startStopButton.title = String(localized: "Stop")
        rememberSearchTerms()
        onStart?(currentTemplate(name: ""), startDirField.stringValue,
                 inSelectionCheckbox.state == .on, spotlightCheckbox.state == .on,
                 searchArchivesCheckbox.state == .on, notContainingCheckbox.state == .on,
                 currentContentPredicate(),
                 pluginTextCheckbox.state == .on && !pluginTextCheckbox.isHidden,
                 commentsCheckbox.state == .on)
    }

    // MARK: - Field histories (F-406)

    /// Record what this search looked for, so the next one can pick it from the dropdown.
    ///
    /// On Start rather than on every keystroke: a history of half-typed masks would push out the terms
    /// that were actually used, and it is the search that ran that the user wants back. The content term
    /// is only recorded when it took part in the search — in an empty-folder search the field's
    /// leftover text searched for nothing.
    private func rememberSearchTerms() {
        guard let history else { return }
        history.names.remember(nameMaskField.stringValue)
        if emptyDirsCheckbox.state != .on {
            history.texts.remember(findTextField.stringValue)
        }
        reloadHistories()
    }

    /// Refill both dropdowns from disk, leaving what is typed in the fields alone.
    private func reloadHistories() {
        for (combo, entries) in [(nameMaskField, history?.names), (findTextField, history?.texts)] {
            combo.removeAllItems()
            combo.addItems(withObjectValues: entries?.load() ?? [])
        }
    }

    /// The Clear History button: confirmed, because the list is gone for good afterwards.
    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Forget the remembered search entries?")
        alert.informativeText = String(localized: "The “Search for” and “Find text” fields will offer nothing until you search again. Saved templates are not affected.")
        alert.addButton(withTitle: String(localized: "Clear"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        performClearHistory()
    }

    /// The half of Clear History that touches no modal, so automation can drive it (see `clearHistory`).
    private func performClearHistory() {
        history?.clear()
        reloadHistories()
        setStatus(String(localized: "Search history cleared."))
    }

    /// Reveal the plugin-text option, when some loaded plugin can actually produce text.
    ///
    /// Hidden rather than disabled when nothing can: with no such plugin the option has no meaning at
    /// all, and an always-grey checkbox reads as a broken feature rather than an inapplicable one.
    public func setHasPluginText(_ available: Bool) {
        pluginTextCheckbox.isHidden = !available
    }

    /// Populate the content-field popup (qualified id → title). Empty disables the row.
    public func setContentFields(_ fields: [(id: String, title: String)]) {
        contentFields = fields
        contentFieldPopup.removeAllItems()
        for f in fields { contentFieldPopup.addItem(withTitle: f.title) }
        let available = !fields.isEmpty
        contentFieldCheckbox.isEnabled = available
        for c in [contentFieldPopup, contentOpPopup] { c.isEnabled = available }
        contentValueField.isEnabled = available
    }

    /// The content-field predicate the user configured, or nil when unchecked /
    /// unavailable / value empty (F-157).
    private func currentContentPredicate() -> ContentFieldPredicate? {
        guard contentFieldCheckbox.state == .on,
              contentFieldPopup.indexOfSelectedItem >= 0,
              contentFieldPopup.indexOfSelectedItem < contentFields.count else { return nil }
        let value = contentValueField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        let field = contentFields[contentFieldPopup.indexOfSelectedItem].id
        let op = ContentOperator(rawValue: contentOpPopup.titleOfSelectedItem ?? "=") ?? .equals
        return ContentFieldPredicate(qualifiedID: field, op: op, value: value)
    }

    @objc private func toggleDateAfter() { updateOptionAvailability() }
    @objc private func toggleDateBefore() { updateOptionAvailability() }

    // MARK: - Templates

    /// Assemble a SearchTemplate from the current control values. Hex mode reroutes
    /// the find text into `hexContent`; otherwise it is `contentText`.
    private func currentTemplate(name: String) -> SearchTemplate {
        let mask = nameMaskField.stringValue.isEmpty ? "*.*" : nameMaskField.stringValue
        let text = findTextField.stringValue
        // The dialog greys the content search out for an empty-folder search; the template must
        // agree, or a saved search would carry a term the engine ignores.
        let hasText = hasContentTerm && emptyDirsCheckbox.state != .on
        let isHex = hexCheckbox.state == .on
        var template = SearchTemplate(
            name: name,
            nameMask: mask,
            contentText: (hasText && !isHex) ? text : nil,
            caseSensitive: caseSensitiveCheckbox.state == .on,
            useRegex: regexCheckbox.state == .on,
            wholeWord: wholeWordCheckbox.state == .on,
            hexContent: (hasText && isHex) ? text : nil,
            minSize: ByteSize.parse(sizeMinField.stringValue),
            maxSize: ByteSize.parse(sizeMaxField.stringValue),
            modifiedAfter: Self.effectiveAfter(recentDays: Int(recentDaysField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0,
                                               absolute: dateAfterCheckbox.state == .on ? dateAfterPicker.dateValue : nil),
            modifiedBefore: dateBeforeCheckbox.state == .on ? dateBeforePicker.dateValue : nil,
            includeDirectories: includeDirsCheckbox.state == .on,
            contentEncodingAware: encodingCheckbox.state == .on,
            maxDepth: depthValue(),
            requireHidden: Self.triState(hiddenAttrPopup),
            requireReadOnly: Self.triState(readOnlyAttrPopup),
            emptyDirectoriesOnly: emptyDirsCheckbox.state == .on)
        // Set after construction rather than added to the 17-argument memberwise
        // initialiser, which every caller would then have to be taught about.
        template.searchArchives = searchArchivesCheckbox.state == .on
        return template
    }

    /// Map an Any/Yes/No popup to nil / true / false (F-152).
    private static func triState(_ popup: NSPopUpButton) -> Bool? {
        switch popup.indexOfSelectedItem { case 1: return true; case 2: return false; default: return nil }
    }

    /// Reverse of `triState`: set the popup from nil / true / false.
    private static func setTriState(_ popup: NSPopUpButton, _ value: Bool?) {
        popup.selectItem(at: value == nil ? 0 : (value == true ? 1 : 2))
    }

    /// Relative "within last N days" wins over the absolute after-date when set.
    private static func effectiveAfter(recentDays: Int, absolute: Date?) -> Date? {
        recentDays > 0 ? Date().addingTimeInterval(-Double(recentDays) * 86400) : absolute
    }

    /// Populate all controls from a saved template.
    private func applyTemplate(_ t: SearchTemplate) {
        nameMaskField.stringValue = t.nameMask
        let isHex = t.hexContent != nil
        hexCheckbox.state = isHex ? .on : .off
        let text = isHex ? (t.hexContent ?? "") : (t.contentText ?? "")
        findTextField.stringValue = text
        caseSensitiveCheckbox.state = t.caseSensitive ? .on : .off
        regexCheckbox.state = t.useRegex ? .on : .off
        wholeWordCheckbox.state = t.wholeWord ? .on : .off
        encodingCheckbox.state = t.contentEncodingAware ? .on : .off
        includeDirsCheckbox.state = t.includeDirectories ? .on : .off
        emptyDirsCheckbox.state = t.emptyDirectoriesOnly ? .on : .off
        searchArchivesCheckbox.state = t.searchArchives ? .on : .off
        sizeMinField.stringValue = t.minSize.map { ByteSize($0).formatted(style: .kb) } ?? ""
        sizeMaxField.stringValue = t.maxSize.map { ByteSize($0).formatted(style: .kb) } ?? ""
        dateAfterCheckbox.state = t.modifiedAfter != nil ? .on : .off
        dateAfterPicker.isEnabled = t.modifiedAfter != nil
        if let a = t.modifiedAfter { dateAfterPicker.dateValue = a }
        dateBeforeCheckbox.state = t.modifiedBefore != nil ? .on : .off
        dateBeforePicker.isEnabled = t.modifiedBefore != nil
        if let b = t.modifiedBefore { dateBeforePicker.dateValue = b }
        selectDepth(t.maxDepth)
        Self.setTriState(hiddenAttrPopup, t.requireHidden)
        Self.setTriState(readOnlyAttrPopup, t.requireReadOnly)
        updateOptionAvailability()
    }

    /// Rebuild the template popup: a leading "(no template)" item + saved names.
    private func reloadTemplatePopup() {
        templatePopup.removeAllItems()
        templatePopup.addItem(withTitle: String(localized: "(no template)"))
        templatePopup.isEnabled = templateStore != nil
        for t in templates { templatePopup.addItem(withTitle: t.name) }
    }

    @objc private func applySelectedTemplate() {
        let idx = templatePopup.indexOfSelectedItem - 1   // 0 == "(no template)"
        guard idx >= 0, idx < templates.count else { return }
        applyTemplate(templates[idx])
    }

    @objc private func saveTemplate() {
        guard let store = templateStore else { return }
        let dialog = InputDialog(title: String(localized: "Save as Template"),
                                 prompt: String(localized: "Template name:"), initialValue: "")
        dialog.onConfirm = { [weak self] name in
            guard let self else { return }
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            self.templates = store.upsert(self.currentTemplate(name: trimmed))
            self.reloadTemplatePopup()
            self.templatePopup.selectItem(withTitle: trimmed)
        }
        dialog.runModalDialog()
    }

    /// Select the max-depth popup title matching `depth` (0 → "All", else the number
    /// if listed, otherwise "All").
    private func selectDepth(_ depth: Int) {
        let title = depth == 0 ? String(localized: "All") : String(depth)
        if maxDepthPopup.itemTitles.contains(title) { maxDepthPopup.selectItem(withTitle: title) }
        else { maxDepthPopup.selectItem(withTitle: String(localized: "All")) }
    }

    @objc private func handleView() {
        let row = tableView.selectedRow
        guard row >= 0, row < results.count else { return }
        onView?(results[row].path)
    }

    @objc private func handleDoubleClick() {
        let row = tableView.clickedRow
        guard row >= 0, row < results.count else { return }
        onView?(results[row].path)
    }

    @objc private func handleFeed() {
        onFeedToListbox?(results.map(\.path))
    }

    @objc private func handleClose() {
        window?.close()
    }
}

// MARK: - The content term drives the options (F-407)

extension FindFilesWindowController: NSComboBoxDelegate {
    /// Typing in "Find text" is what turns the content options on and off now that no checkbox does —
    /// without this they would stay grey with a term sitting right above them.
    public func controlTextDidChange(_ obj: Notification) {
        updateOptionAvailability()
    }

    /// Picking an entry from the history dropdown is not typing, and AppKit posts this *before* the
    /// field's value is the new one — hence the hop through the main queue.
    public func comboBoxSelectionDidChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.updateOptionAvailability() }
    }
}

// MARK: - NSTableViewDataSource / NSTableViewDelegate

extension FindFilesWindowController: NSTableViewDataSource, NSTableViewDelegate {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        results.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: Self.resultCellIdentifier, owner: self) as? FindResultCellView
            ?? FindResultCellView(identifier: Self.resultCellIdentifier)
        let r = results[row]
        // Line 0 means "not in the file's text at all" — a comment match (F-373). Printing "L0" there
        // invites the reader to look for line zero, which no file has.
        let linePrefix = r.line.flatMap { $0 > 0 ? String(format: String(localized: "L%lld  "), $0) : nil } ?? ""
        cell.configure(path: r.path, preview: r.preview.map { linePrefix + $0 })
        return cell
    }

    /// Taller rows for content hits (two lines: path + match preview).
    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        results[row].preview != nil ? Metrics.rowHeight * 2 + 2 : Metrics.rowHeight
    }
}

/// Result row cell: the path on one (middle-truncated) line, plus — for content
/// hits — a dimmed monospaced match-preview line below. Two separate labels so a
/// long path can never crowd out the preview.
private final class FindResultCellView: NSView {
    private let pathLabel = NSTextField(labelWithString: "")
    private let previewLabel = NSTextField(labelWithString: "")

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        for (label, font, color, mode) in [
            (pathLabel, Fonts.system13, NSColor.labelColor, NSLineBreakMode.byTruncatingMiddle),
            (previewLabel, NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
             NSColor.secondaryLabelColor, NSLineBreakMode.byTruncatingTail),
        ] {
            label.font = font
            label.textColor = color
            label.lineBreakMode = mode
            label.maximumNumberOfLines = 1
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: leadingAnchor),
                label.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }
        // Path sits at the top; preview directly under it (shown only when set).
        NSLayoutConstraint.activate([
            pathLabel.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            previewLabel.topAnchor.constraint(equalTo: pathLabel.bottomAnchor, constant: 1),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(path: String, preview: String?) {
        pathLabel.stringValue = path
        pathLabel.toolTip = path
        previewLabel.stringValue = preview ?? ""
        previewLabel.isHidden = (preview == nil)
    }
}
