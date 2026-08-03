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
                          _ searchPluginText: Bool) -> Void)?
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

    private let nameMaskField = NSTextField()
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
    private let findTextCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let findTextField = NSTextField()
    private let caseSensitiveCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let regexCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let wholeWordCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let hexCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let encodingCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let notContainingCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let includeDirsCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let searchArchivesCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    /// Search what a plugin makes of a file instead of the file's own bytes (F-351).
    ///
    /// Shown only when a loaded plugin actually offers full text, because a checkbox that can never
    /// change an outcome is worse than an absent one — see `setHasPluginText`.
    private let pluginTextCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
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
    private let statusLabel = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let startStopButton = NSButton()
    private let viewButton = NSButton()
    private let feedButton = NSButton()
    private let closeButton = NSButton()

    private static let resultColumnIdentifier = NSUserInterfaceItemIdentifier("path")
    private static let resultCellIdentifier = NSUserInterfaceItemIdentifier("pathCell")

    /// Creates the dialog, prefilling the search directory. `templatesURL` enables
    /// the saved-template picker (Find dialog persists templates as JSON there).
    public init(startDirectory: String, templatesURL: URL? = nil) {
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
        setupDialog(startDirectory: startDirectory)
        reloadTemplatePopup()
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

        findTextCheckbox.title = String(localized: "Find text:")
        findTextCheckbox.font = Fonts.system13
        findTextCheckbox.target = self; findTextCheckbox.action = #selector(toggleFindText)
        findTextField.isEnabled = false
        findTextField.font = Fonts.system13
        findTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true

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
        searchArchivesCheckbox.title = String(localized: "Search inside archives (zip, jar, war, …)")
        searchArchivesCheckbox.font = Fonts.system13
        searchArchivesCheckbox.toolTip = String(localized: "Open zip-family archives (zip/jar/war/apk/…) and search their contents too")
        pluginTextCheckbox.title = String(localized: "Search text provided by plugins (e.g. decompiled source)")
        pluginTextCheckbox.font = Fonts.system13
        pluginTextCheckbox.toolTip = String(localized: "For files a plugin can turn into text — a .class as decompiled Java — search that text instead of the file's bytes. Slower: producing the text can mean running a decompiler.")
        pluginTextCheckbox.isHidden = true

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
            f.widthAnchor.constraint(equalToConstant: 130).isActive = true
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
        recentDaysField.widthAnchor.constraint(equalToConstant: 44).isActive = true
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
        contentValueField.widthAnchor.constraint(equalToConstant: 120).isActive = true
        contentFieldPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
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
        templatePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        let saveTemplateButton = NSButton(title: String(localized: "Save as Template…"),
                                          target: self, action: #selector(saveTemplate))
        saveTemplateButton.bezelStyle = .rounded
        let tmplRow = hStack([tmplLabel, templatePopup, saveTemplateButton], spacing: 8)

        // --- Tabbed options area (F-150): General / Advanced / Plugins / Load & Save ---
        let tabView = optionsTabView
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.addTabViewItem(makeTab(String(localized: "General"), rows: [
            labeledField(String(localized: "Search for:"), nameMaskField),
            labeledField(String(localized: "Search in:"), startDirField),
            hStack([findTextCheckbox, findTextField], spacing: 8),
            hStack([caseSensitiveCheckbox, regexCheckbox, wholeWordCheckbox], spacing: 20),
            hStack([hexCheckbox, encodingCheckbox, notContainingCheckbox], spacing: 20),
            inSelectionCheckbox,
            spotlightCheckbox,
            hStack([includeDirsCheckbox, searchArchivesCheckbox], spacing: 20),
            pluginTextCheckbox,
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

        closeButton.title = String(localized: "Close")
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\u{1B}"
        closeButton.action = #selector(handleClose)
        closeButton.target = self

        buttons.addView(startStopButton, in: .trailing)
        buttons.addView(viewButton, in: .trailing)
        buttons.addView(feedButton, in: .trailing)
        buttons.addView(closeButton, in: .trailing)
        content.addSubview(buttons)

        // A floor from the tallest tab's own fitting height, plus what NSTabView spends on its tab
        // strip and border. Nothing here is a chosen number: the stacks report what they need.
        let tallest = tabStacks.map(\.fittingSize.height).max() ?? 300
        // NSTabView exposes the inset as contentRect, not as a function — 34 is the observed value for
        // the top strip plus border and is used as the floor either way.
        let chrome = tabView.frame.height - tabView.contentRect.height
        let tabHeightConstraint = tabView.heightAnchor.constraint(
            greaterThanOrEqualToConstant: tallest + max(34, chrome))
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

            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])
        updateOptionAvailability()
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

    /// A "label: control" row: a right-aligned fixed-width label plus the control.
    private func labeledField(_ title: String, _ control: NSView, controlMinWidth: CGFloat = 300) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = Fonts.system13
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 90).isActive = true
        control.widthAnchor.constraint(greaterThanOrEqualToConstant: controlMinWidth).isActive = true
        return hStack([label, control], spacing: 8)
    }

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
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: page.topAnchor),
            stack.leadingAnchor.constraint(equalTo: page.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: page.trailingAnchor),
            // The bound that was missing: without it a tab whose rows outgrow the fixed height draws
            // over whatever is below and nothing reports it. Now it shows up as a layout conflict.
            stack.bottomAnchor.constraint(lessThanOrEqualTo: page.bottomAnchor),
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

    @objc private func toggleFindText() { updateOptionAvailability() }
    @objc private func optionsChanged() { updateOptionAvailability() }

    /// Enable only the option combinations that make sense together:
    /// - content sub-options (hex / whole-word / encoding-aware) need "Find text";
    /// - hex is an exact byte match, so it disables regex / whole-word / encoding;
    /// - Spotlight does its own name+content lookup, so it disables everything it
    ///   ignores (regex, depth, selection, size/date/archives, and the content
    ///   refinements).
    private func updateOptionAvailability() {
        let findText = findTextCheckbox.state == .on
        let spotlight = spotlightCheckbox.state == .on
        let hex = hexCheckbox.state == .on && findText && !spotlight

        findTextField.isEnabled = findText
        hexCheckbox.isEnabled = findText && !spotlight
        wholeWordCheckbox.isEnabled = findText && !hex && !spotlight
        encodingCheckbox.isEnabled = findText && !hex && !spotlight
        // "Not containing" works with text or hex; only needs a content term + no Spotlight.
        notContainingCheckbox.isEnabled = findText && !spotlight
        regexCheckbox.isEnabled = !hex && !spotlight
        caseSensitiveCheckbox.isEnabled = !hex && !spotlight
        maxDepthPopup.isEnabled = !spotlight
        inSelectionCheckbox.isEnabled = !spotlight
        includeDirsCheckbox.isEnabled = !spotlight
        searchArchivesCheckbox.isEnabled = !spotlight
        // Spotlight answers from its own index and never opens the file, so no plugin can contribute
        // to it; and with no content term there is no text to search for.
        pluginTextCheckbox.isEnabled = !spotlight && findText
        sizeMinField.isEnabled = !spotlight
        sizeMaxField.isEnabled = !spotlight
        dateAfterCheckbox.isEnabled = !spotlight
        dateBeforeCheckbox.isEnabled = !spotlight
        dateAfterPicker.isEnabled = !spotlight && dateAfterCheckbox.state == .on
        dateBeforePicker.isEnabled = !spotlight && dateBeforeCheckbox.state == .on
    }

    @objc private func handleStartStop() {
        if isSearching {
            onCancel?()
            return
        }
        isSearching = true
        startStopButton.title = String(localized: "Stop")
        onStart?(currentTemplate(name: ""), startDirField.stringValue,
                 inSelectionCheckbox.state == .on, spotlightCheckbox.state == .on,
                 searchArchivesCheckbox.state == .on, notContainingCheckbox.state == .on,
                 currentContentPredicate(),
                 pluginTextCheckbox.state == .on && !pluginTextCheckbox.isHidden)
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
        let hasText = findTextCheckbox.state == .on && !text.isEmpty
        let isHex = hexCheckbox.state == .on
        return SearchTemplate(
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
            requireReadOnly: Self.triState(readOnlyAttrPopup))
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
        findTextCheckbox.state = text.isEmpty ? .off : .on
        findTextField.isEnabled = !text.isEmpty
        caseSensitiveCheckbox.state = t.caseSensitive ? .on : .off
        regexCheckbox.state = t.useRegex ? .on : .off
        wholeWordCheckbox.state = t.wholeWord ? .on : .off
        encodingCheckbox.state = t.contentEncodingAware ? .on : .off
        includeDirsCheckbox.state = t.includeDirectories ? .on : .off
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

// MARK: - NSTableViewDataSource / NSTableViewDelegate

extension FindFilesWindowController: NSTableViewDataSource, NSTableViewDelegate {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        results.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: Self.resultCellIdentifier, owner: self) as? FindResultCellView
            ?? FindResultCellView(identifier: Self.resultCellIdentifier)
        let r = results[row]
        let linePrefix = r.line.map { String(format: String(localized: "L%lld  "), $0) } ?? ""
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
