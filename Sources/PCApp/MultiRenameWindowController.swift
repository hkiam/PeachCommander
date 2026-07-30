// SPDX-License-Identifier: Apache-2.0
// MultiRenameWindowController.swift - Multi-Rename dialog (Ctrl+M)
//
// A dumb view: reports control values via callbacks and draws whatever
// preview it is handed through `setPreview(_:)`. It never computes renamed
// file names itself.

import AppKit
import PCFoundation

/// Multi-Rename dialog window controller.
@MainActor
public final class MultiRenameWindowController: NSWindowController {
    /// Plain values read from the controls (the orchestrator maps these to a RenameSpec).
    public struct SpecValues: Sendable, Codable {
        public var nameMask: String
        public var extMask: String
        public var search: String
        public var replace: String
        public var useRegex: Bool
        public var caseSensitive: Bool
        public var repeatReplace: Bool
        public var caseModeIndex: Int
        public var counterStart: Int
        public var counterStep: Int
        public var counterDigits: Int
    }

    /// Fired (debounced ~150 ms) whenever any control changes, for live preview.
    public var onSpecChanged: ((SpecValues) -> Void)?
    /// Fired when Start is pressed.
    public var onStart: ((SpecValues) -> Void)?
    /// Fired when Undo is pressed.
    public var onUndo: (() -> Void)?
    public var onClose: (() -> Void)?

    private static let oldColumnID = NSUserInterfaceItemIdentifier("old")
    private static let newColumnID = NSUserInterfaceItemIdentifier("new")

    private let oldNames: [String]
    private var previewRows: [(old: String, new: String, ok: Bool)]

    private let nameMaskField = NSTextField()
    private let extMaskField = NSTextField()
    private let searchField = NSTextField()
    private let replaceField = NSTextField()
    private let regexCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let caseSensitiveCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let repeatCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let casePopup = NSPopUpButton()
    private let counterStartField = NSTextField()
    private let counterStepField = NSTextField()
    private let counterDigitsField = NSTextField()

    private let tableView = NSTableView()
    private let startButton = NSButton()
    private let undoButton = NSButton()
    private let closeButton = NSButton()
    private let presetPopup = NSPopUpButton()
    private let savePresetButton = NSButton()

    /// Saved-preset persistence + current list (F-176).
    private var presetStore: RenamePresetStore?
    private var presets: [RenamePreset] = []

    /// Bumped on every change; a pending debounce only fires if the token still matches.
    private var pendingSpecChangeToken = 0

    /// Seeds the preview with the old names (new name empty) until the first computed preview arrives.
    public init(oldNames: [String], presetsURL: URL? = nil) {
        self.oldNames = oldNames
        self.previewRows = oldNames.map { (old: $0, new: "", ok: true) }
        let window = NSWindow(
            contentRect: NSMakeRect(0, 0, 700, 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Multi-Rename")
        window.center()
        super.init(window: window)
        if let presetsURL {
            let store = RenamePresetStore(url: presetsURL)
            presetStore = store
            presets = store.load()
        }
        setupUI(in: window)
        reloadPresetPopup()
        scheduleSpecChanged()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Update the preview grid: rows aligned to the old names; ok=false → red row.
    public func setPreview(_ rows: [(old: String, new: String, ok: Bool)]) {
        previewRows = rows
        tableView.reloadData()
    }

    /// Enable the Undo button after a successful run.
    public func enableUndo(_ enabled: Bool) {
        undoButton.isEnabled = enabled
    }

    public func showWindow() {
        showWindow(nil)
    }

    // MARK: - Layout

    private func setupUI(in window: NSWindow) {
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        // A vertical stack (form / preview / buttons) stretched to full width; the
        // stack view manages translatesAutoresizingMaskIntoConstraints for its children.
        let outer = NSStackView(views: [buildFormStack(), buildPreviewScrollView(), buildButtonRow()])
        outer.orientation = .vertical
        outer.alignment = .width
        outer.spacing = 12
        outer.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(outer)

        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            outer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            outer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            outer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])
    }

    /// A form row: a fixed-width label followed by one or more trailing controls.
    private func labeledRow(_ label: String, _ trailing: [NSView]) -> NSStackView {
        let labelField = NSTextField(labelWithString: label)
        labelField.font = Fonts.system13
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: 110).isActive = true
        let stack = NSStackView(views: [labelField] + trailing)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        return stack
    }

    private func buildFormStack() -> NSStackView {
        for field in [nameMaskField, extMaskField, searchField, replaceField] {
            field.font = Fonts.monospacedDigit13
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 260).isActive = true
            field.delegate = self
        }
        nameMaskField.stringValue = "[N]"
        extMaskField.stringValue = "[E]"
        casePopup.addItems(withTitles: [
            String(localized: "unchanged"), String(localized: "lowercase"), String(localized: "UPPERCASE"),
            String(localized: "First letter"), String(localized: "Every Word")
        ])
        casePopup.target = self
        casePopup.action = #selector(controlChanged(_:))

        let stack = NSStackView(views: [
            labeledRow(String(localized: "Rename mask:"), [nameMaskField]),
            buildTokensRow(),
            labeledRow(String(localized: "Extension:"), [extMaskField]),
            labeledRow(String(localized: "Search for:"), [searchField]),
            labeledRow(String(localized: "Replace with:"), [replaceField]),
            buildCheckboxRow(),
            labeledRow(String(localized: "Case:"), [casePopup]),
            buildCounterRow()
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }

    /// A fixed-width blank view used to align a row under the label column of `labeledRow`.
    private func spacerView() -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.widthAnchor.constraint(equalToConstant: 110).isActive = true
        return spacer
    }

    /// Quick-insert buttons that append a literal token to the name mask field.
    private func buildTokensRow() -> NSStackView {
        let buttons: [NSView] = ["[N]", "[N1-9]", "[C]", "[d]", "[P]"].map { token in
            let button = NSButton(title: token, target: self, action: #selector(insertToken(_:)))
            button.bezelStyle = .rounded
            button.font = Fonts.system13
            return button
        }
        let stack = NSStackView(views: [spacerView()] + buttons)
        stack.orientation = .horizontal
        stack.spacing = 6
        return stack
    }

    private func buildCheckboxRow() -> NSStackView {
        regexCheckbox.title = String(localized: "Regex")
        regexCheckbox.target = self
        regexCheckbox.action = #selector(controlChanged(_:))
        caseSensitiveCheckbox.title = String(localized: "Case sensitive")
        caseSensitiveCheckbox.target = self
        caseSensitiveCheckbox.action = #selector(controlChanged(_:))
        repeatCheckbox.title = String(localized: "Repeat")
        repeatCheckbox.target = self
        repeatCheckbox.action = #selector(controlChanged(_:))

        let stack = NSStackView(views: [spacerView(), regexCheckbox, caseSensitiveCheckbox, repeatCheckbox])
        stack.orientation = .horizontal
        stack.spacing = 12
        return stack
    }

    private func buildCounterRow() -> NSStackView {
        for field in [counterStartField, counterStepField, counterDigitsField] {
            field.stringValue = "1"
            field.font = Fonts.monospacedDigit13
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 50).isActive = true
            field.delegate = self
        }
        let startLabel = NSTextField(labelWithString: String(localized: "Start"))
        let stepLabel = NSTextField(labelWithString: String(localized: "Step"))
        let digitsLabel = NSTextField(labelWithString: String(localized: "Digits"))
        [startLabel, stepLabel, digitsLabel].forEach { $0.font = Fonts.system13 }
        return labeledRow(String(localized: "Counter:"), [
            startLabel, counterStartField, stepLabel, counterStepField, digitsLabel, counterDigitsField
        ])
    }

    private func buildPreviewScrollView() -> NSScrollView {
        let oldColumn = NSTableColumn(identifier: Self.oldColumnID)
        oldColumn.title = String(localized: "Old name")
        oldColumn.width = 320
        let newColumn = NSTableColumn(identifier: Self.newColumnID)
        newColumn.title = String(localized: "New name")
        newColumn.width = 320
        tableView.addTableColumn(oldColumn)
        tableView.addTableColumn(newColumn)
        tableView.rowHeight = Metrics.rowHeight
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        return scrollView
    }

    /// Configures a bottom-bar button's title, style, target/action and optional key equivalent.
    private func configure(_ button: NSButton, title: String, action: Selector, keyEquivalent: String = "") {
        button.title = title
        button.bezelStyle = .rounded
        button.keyEquivalent = keyEquivalent
        button.target = self
        button.action = action
    }

    private func buildButtonRow() -> NSStackView {
        configure(startButton, title: String(localized: "Start"), action: #selector(startAction), keyEquivalent: "\r")
        configure(undoButton, title: String(localized: "Undo"), action: #selector(undoAction))
        undoButton.isEnabled = false
        configure(closeButton, title: String(localized: "Close"), action: #selector(closeAction), keyEquivalent: "\u{1B}")

        let presetLabel = NSTextField(labelWithString: String(localized: "Preset:"))
        presetPopup.target = self
        presetPopup.action = #selector(applySelectedPreset)
        presetPopup.setContentHuggingPriority(.defaultLow, for: .horizontal)
        configure(savePresetButton, title: String(localized: "Save as Preset…"), action: #selector(savePreset))

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.addView(presetLabel, in: .leading)
        stack.addView(presetPopup, in: .leading)
        stack.addView(savePresetButton, in: .leading)
        stack.addView(closeButton, in: .trailing)
        stack.addView(undoButton, in: .trailing)
        stack.addView(startButton, in: .trailing)
        return stack
    }

    // MARK: - Presets (F-176)

    /// Write a saved SpecValues snapshot back into every control.
    private func loadValues(_ v: SpecValues) {
        nameMaskField.stringValue = v.nameMask
        extMaskField.stringValue = v.extMask
        searchField.stringValue = v.search
        replaceField.stringValue = v.replace
        regexCheckbox.state = v.useRegex ? .on : .off
        caseSensitiveCheckbox.state = v.caseSensitive ? .on : .off
        repeatCheckbox.state = v.repeatReplace ? .on : .off
        if v.caseModeIndex >= 0, v.caseModeIndex < casePopup.numberOfItems {
            casePopup.selectItem(at: v.caseModeIndex)
        }
        counterStartField.stringValue = String(v.counterStart)
        counterStepField.stringValue = String(v.counterStep)
        counterDigitsField.stringValue = String(v.counterDigits)
        scheduleSpecChanged()
    }

    private func reloadPresetPopup() {
        presetPopup.removeAllItems()
        presetPopup.addItem(withTitle: String(localized: "(no preset)"))
        presetPopup.isEnabled = presetStore != nil
        for p in presets { presetPopup.addItem(withTitle: p.name) }
    }

    @objc private func applySelectedPreset() {
        let idx = presetPopup.indexOfSelectedItem - 1   // 0 == "(no preset)"
        guard idx >= 0, idx < presets.count else { return }
        loadValues(presets[idx].values)
    }

    @objc private func savePreset() {
        guard let store = presetStore else { return }
        let dialog = InputDialog(title: String(localized: "Save as Preset"),
                                 prompt: String(localized: "Preset name:"), initialValue: "")
        dialog.onConfirm = { [weak self] name in
            guard let self else { return }
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            self.presets = store.upsert(RenamePreset(name: trimmed, values: self.currentSpec()))
            self.reloadPresetPopup()
            self.presetPopup.selectItem(withTitle: trimmed)
        }
        dialog.runModalDialog()
    }

    // MARK: - Actions

    @objc private func insertToken(_ sender: NSButton) {
        nameMaskField.stringValue += sender.title
        scheduleSpecChanged()
    }

    @objc private func controlChanged(_ sender: Any?) {
        scheduleSpecChanged()
    }

    @objc private func startAction() {
        onStart?(currentSpec())
    }

    @objc private func undoAction() {
        onUndo?()
    }

    @objc private func closeAction() {
        onClose?()
        close()
    }

    // MARK: - Spec reporting

    /// Reads all controls into a `SpecValues` snapshot.
    private func currentSpec() -> SpecValues {
        SpecValues(
            nameMask: nameMaskField.stringValue,
            extMask: extMaskField.stringValue,
            search: searchField.stringValue,
            replace: replaceField.stringValue,
            useRegex: regexCheckbox.state == .on,
            caseSensitive: caseSensitiveCheckbox.state == .on,
            repeatReplace: repeatCheckbox.state == .on,
            caseModeIndex: casePopup.indexOfSelectedItem,
            counterStart: Int(counterStartField.stringValue) ?? 1,
            counterStep: Int(counterStepField.stringValue) ?? 1,
            counterDigits: Int(counterDigitsField.stringValue) ?? 1
        )
    }

    /// Debounces control changes (~150 ms) before reporting the new spec.
    private func scheduleSpecChanged() {
        pendingSpecChangeToken += 1
        let token = pendingSpecChangeToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.pendingSpecChangeToken == token else { return }
            self.onSpecChanged?(self.currentSpec())
        }
    }
}

// MARK: - NSTextFieldDelegate

extension MultiRenameWindowController: NSTextFieldDelegate {
    public func controlTextDidChange(_ notification: Notification) {
        scheduleSpecChanged()
    }
}

// MARK: - NSTableViewDataSource, NSTableViewDelegate

extension MultiRenameWindowController: NSTableViewDataSource, NSTableViewDelegate {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        previewRows.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < previewRows.count, let identifier = tableColumn?.identifier else { return nil }
        let cellID = NSUserInterfaceItemIdentifier("cell.\(identifier.rawValue)")
        let cellView = (tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView)
            ?? makeCellView(id: cellID)
        guard let textField = cellView.textField else { return cellView }

        let rowData = previewRows[row]
        textField.stringValue = identifier == Self.oldColumnID ? rowData.old : rowData.new
        textField.textColor = rowData.ok ? Theme.current.listText : Theme.current.selectedText
        return cellView
    }

    /// Builds a fresh view-based cell (a label pinned inside an `NSTableCellView`) for reuse by identifier.
    private func makeCellView(id: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let textField = NSTextField(labelWithString: "")
        textField.font = Fonts.system13
        textField.translatesAutoresizingMaskIntoConstraints = false

        let cellView = NSTableCellView()
        cellView.identifier = id
        cellView.addSubview(textField)
        cellView.textField = textField
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        return cellView
    }
}
