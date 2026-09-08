// SPDX-License-Identifier: Apache-2.0
// SyncFilterSheetController.swift - The advanced filter for the directory synchronisation.
//
// A sheet with three tabs rather than tabs in the sync window itself. The criteria in here are needed
// in a few cases and would be in the way in all the others, and the sync window is not the tool for
// asking questions about files the way Find Files is — so the main window gains exactly one control,
// the button that opens this.
//
// The tabs and their row shapes come from `TabbedFormLayout`, the same builder the search window uses,
// so somebody who knows the advanced search recognises this and neither window can drift from the
// other's measured constraint priorities.
//
// The sheet works on a *copy*: it is handed the current filter, edits its own controls, and the caller
// reads the result only when OK is pressed. Two live views of one value in two windows is a
// synchronisation bug waiting for a place to happen.

import AppKit
import PCFoundation
import PCOperations
import PCVFS

final class SyncFilterSheetController: NSWindowController {

    /// The edited filter, once OK was pressed.
    var onConfirm: ((SyncFilter) -> Void)?
    /// Called whichever way the sheet goes away, so the owner can drop its reference.
    var onDismiss: (() -> Void)?

    private let form = TabbedFormLayout()
    private let tabView = NSTabView()

    private let excludeField = NSTextField()
    private let sizeMinField = NSTextField()
    private let sizeMaxField = NSTextField()
    private let dateAfterCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let dateAfterPicker = NSDatePicker()
    private let dateBeforeCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let dateBeforePicker = NSDatePicker()
    private let recentDaysField = NSTextField()

    private let pluginCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let pluginFieldPopup = NSPopUpButton()
    private let pluginOpPopup = NSPopUpButton()
    private let pluginValueField = NSTextField()
    private let pluginReason = NSTextField(wrappingLabelWithString: "")
    private var pluginFields: [(id: String, title: String)] = []

    private let clearButton = NSButton()
    private let summaryLabel = NSTextField(wrappingLabelWithString: "")

    private let initial: SyncFilter
    private let pluginsAvailable: Bool
    private let pluginsUnavailableReason: String

    /// - Parameters:
    ///   - filter: The filter as it stands. Edited on a copy.
    ///   - fields: The plugin fields on offer, as `(qualifiedID, title)`.
    ///   - pluginsAvailable: Whether a plugin criterion can be answered for these two sides at all —
    ///     `SyncPluginFilter.canEvaluate`. False for a server or an archive side, and then the tab is
    ///     disabled with the reason on it rather than offering a criterion that would do nothing.
    init(filter: SyncFilter, fields: [(id: String, title: String)],
         pluginsAvailable: Bool, pluginsUnavailableReason: String) {
        self.initial = filter
        self.pluginFields = fields
        self.pluginsAvailable = pluginsAvailable && !fields.isEmpty
        self.pluginsUnavailableReason = fields.isEmpty && pluginsAvailable
            ? String(localized: "No content plugin offers a field to filter by.")
            : pluginsUnavailableReason
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 340),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.title = String(localized: "Sync Filter")
        super.init(window: window)
        buildUI()
        apply(filter)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: - Building

    private func buildUI() {
        guard let window else { return }
        let content = NSView()
        tabView.translatesAutoresizingMaskIntoConstraints = false

        for f in [excludeField, sizeMinField, sizeMaxField, recentDaysField, pluginValueField] {
            f.font = Fonts.system13
        }

        // Excluded patterns. The field is the reason the whole feature exists, so it is the first row
        // of the first tab, with the language spelled out under it rather than in a tooltip nobody
        // hovers over.
        excludeField.placeholderString = String(localized: "e.g. node_modules/;*.tmp;.git/")
        let excludeRow = form.labeledField(String(localized: "Exclude:"), excludeField)

        sizeMinField.placeholderString = String(localized: "min (e.g. 10K)")
        // The search window's own placeholders, word for word: they are already translated into all
        // nineteen languages, and two size fields in two dialogs that read differently for no reason
        // are worse than an example value that says 5M where 2G would be more typical here.
        sizeMaxField.placeholderString = String(localized: "max (e.g. 5M)")
        for f in [sizeMinField, sizeMaxField] { form.preferWidth(f, exactly: 130) }
        let sizeRow = form.hStack([NSTextField(labelWithString: String(localized: "Size:")),
                                   sizeMinField,
                                   NSTextField(labelWithString: String(localized: "to")),
                                   sizeMaxField], spacing: 8)

        dateAfterCheckbox.title = String(localized: "Modified after:")
        dateAfterCheckbox.target = self; dateAfterCheckbox.action = #selector(dateToggled)
        dateBeforeCheckbox.title = String(localized: "before:")
        dateBeforeCheckbox.target = self; dateBeforeCheckbox.action = #selector(dateToggled)
        for p in [dateAfterPicker, dateBeforePicker] {
            p.datePickerStyle = .textFieldAndStepper
            p.datePickerElements = .yearMonthDay
            p.dateValue = Date()
            p.isEnabled = false
        }
        recentDaysField.placeholderString = String(localized: "N")
        recentDaysField.alignment = .right
        form.preferWidth(recentDaysField, exactly: 44)
        let dateRow = form.hStack([dateAfterCheckbox, dateAfterPicker,
                                   dateBeforeCheckbox, dateBeforePicker], spacing: 8)
        let recentRow = form.hStack([NSTextField(labelWithString: String(localized: "Or modified within the last")),
                                     recentDaysField,
                                     NSTextField(labelWithString: String(localized: "days"))], spacing: 8)

        clearButton.title = String(localized: "Clear Filter")
        clearButton.bezelStyle = .rounded
        clearButton.target = self; clearButton.action = #selector(clearFilter)

        tabView.addTabViewItem(form.makeTab(String(localized: "Advanced"), rows: [
            excludeRow,
            form.hintLabel(String(localized: "One pattern per entry, separated by ; or |. A name without a slash matches at any depth (*.tmp), a trailing slash means a folder and everything in it (node_modules/), and a pattern with a slash matches the path (src/*/generated). Case is ignored.")),
            sizeRow,
            dateRow,
            recentRow,
            form.hintLabel(String(localized: "Measured from each comparison, not from when a preset was saved. Size and date judge a pair as a whole — if either side falls outside, the whole pair is left out, so an exclusion can never turn into a copy. Folders are judged by pattern only. For attributes, use “Ignore hidden” in the window.")),
            clearButton,
        ]))

        // Plugin criterion.
        pluginCheckbox.title = String(localized: "Field:")
        pluginCheckbox.target = self; pluginCheckbox.action = #selector(pluginToggled)
        for op in ContentOperator.allCases { pluginOpPopup.addItem(withTitle: op.rawValue) }
        for f in pluginFields { pluginFieldPopup.addItem(withTitle: f.title) }
        form.preferWidth(pluginOpPopup, exactly: 70)
        form.preferWidth(pluginValueField, atLeast: 140)
        pluginReason.font = NSFont.systemFont(ofSize: 11)
        pluginReason.textColor = .secondaryLabelColor
        let pluginRow = form.hStack([pluginCheckbox, pluginFieldPopup, pluginOpPopup, pluginValueField],
                                    spacing: 8)
        tabView.addTabViewItem(form.makeTab(String(localized: "Plugins"), rows: [
            form.hintLabel(String(localized: "Include only files whose content-plugin field satisfies a condition (e.g. image width > 800).")),
            pluginRow,
            pluginReason,
            form.hintLabel(String(localized: "Asked of the side a file is copied from, once per file. A file the plugin can say nothing about does not satisfy the condition and is left out.")),
        ]))

        tabView.addTabViewItem(form.makeTab(String(localized: "Load / Save"), rows: [
            form.hintLabel(String(localized: "A filter is part of a sync preset. Save or load one with “Preset” in the synchronisation window, and the filter travels with it.")),
            summaryLabel,
        ]))

        summaryLabel.font = Fonts.system13
        pluginCheckbox.isEnabled = pluginsAvailable
        for c in [pluginFieldPopup, pluginOpPopup] { c.isEnabled = false }
        pluginValueField.isEnabled = false
        pluginReason.stringValue = pluginsAvailable ? "" : pluginsUnavailableReason

        let ok = NSButton(title: String(localized: "OK"), target: self, action: #selector(confirm))
        ok.bezelStyle = .rounded
        ok.keyEquivalent = "\r"
        let cancel = NSButton(title: String(localized: "Cancel"), target: self, action: #selector(cancel))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, ok])
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(tabView)
        content.addSubview(buttons)
        window.contentView = content
        form.alignRowLabels()

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            tabView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            // A lower bound from the tallest page's own fitting height, never an equality — see
            // TabbedFormLayout for what pinning it exactly did to the search dialog.
            tabView.heightAnchor.constraint(greaterThanOrEqualToConstant: form.measuredTabHeight()),
            buttons.topAnchor.constraint(equalTo: tabView.bottomAnchor, constant: 12),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])
        window.setContentSize(content.fittingSize)
        window.contentMinSize = content.fittingSize
    }

    // MARK: - Reading and writing the controls

    private func apply(_ f: SyncFilter) {
        excludeField.stringValue = f.excludePatterns
        // `.kb`, the same style the search window round-trips its size fields with — what `formatted`
        // writes, `ByteSize.parse` reads back, including the comma decimal separator.
        sizeMinField.stringValue = f.minSize.map { ByteSize($0).formatted(style: .kb) } ?? ""
        sizeMaxField.stringValue = f.maxSize.map { ByteSize($0).formatted(style: .kb) } ?? ""
        dateAfterCheckbox.state = f.modifiedAfter != nil ? .on : .off
        if let after = f.modifiedAfter { dateAfterPicker.dateValue = after }
        dateBeforeCheckbox.state = f.modifiedBefore != nil ? .on : .off
        if let before = f.modifiedBefore { dateBeforePicker.dateValue = before }
        recentDaysField.stringValue = f.modifiedWithinDays.map { String($0) } ?? ""
        if let text = f.pluginPredicate, let p = ContentFieldPredicate.parse(text), pluginsAvailable {
            pluginCheckbox.state = .on
            if let index = pluginFields.firstIndex(where: { $0.id == p.qualifiedID }) {
                pluginFieldPopup.selectItem(at: index)
            }
            pluginOpPopup.selectItem(withTitle: p.op.rawValue)
            pluginValueField.stringValue = p.value
        }
        dateToggled()
        pluginToggled()
        refreshSummary()
    }

    /// What the controls currently say, as a filter.
    private func currentFilter() -> SyncFilter {
        var f = SyncFilter()
        f.excludePatterns = excludeField.stringValue.trimmingCharacters(in: .whitespaces)
        f.minSize = ByteSize.parse(sizeMinField.stringValue)
        f.maxSize = ByteSize.parse(sizeMaxField.stringValue)
        f.modifiedAfter = dateAfterCheckbox.state == .on ? dateAfterPicker.dateValue : nil
        f.modifiedBefore = dateBeforeCheckbox.state == .on ? dateBeforePicker.dateValue : nil
        if let days = Int(recentDaysField.stringValue.trimmingCharacters(in: .whitespaces)), days > 0 {
            f.modifiedWithinDays = days
        }
        f.pluginPredicate = currentPluginPredicate()
        return f
    }

    private func currentPluginPredicate() -> String? {
        guard pluginsAvailable, pluginCheckbox.state == .on else { return nil }
        let index = pluginFieldPopup.indexOfSelectedItem
        guard pluginFields.indices.contains(index) else { return nil }
        let value = pluginValueField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        return "\(pluginFields[index].id) \(pluginOpPopup.titleOfSelectedItem ?? "=") \(value)"
    }

    private func refreshSummary() {
        let count = currentFilter().activeCriteriaCount
        summaryLabel.stringValue = count == 0
            ? String(localized: "No criteria set — every file is part of the comparison.")
            : String(localized: "\(count) criteria set. The synchronisation window shows this on its Filter button.")
    }

    // MARK: - Actions

    @objc private func dateToggled() {
        dateAfterPicker.isEnabled = dateAfterCheckbox.state == .on
        dateBeforePicker.isEnabled = dateBeforeCheckbox.state == .on
        refreshSummary()
    }

    @objc private func pluginToggled() {
        let on = pluginsAvailable && pluginCheckbox.state == .on
        for c in [pluginFieldPopup, pluginOpPopup] { c.isEnabled = on }
        pluginValueField.isEnabled = on
        refreshSummary()
    }

    @objc private func clearFilter() {
        apply(SyncFilter())
        pluginCheckbox.state = .off
        pluginValueField.stringValue = ""
        pluginToggled()
    }

    /// OK, unless the plugin criterion is switched on and does not produce a predicate.
    ///
    /// Refused here rather than shrugged off later: a filter is saved into a preset, and a criterion
    /// that never parses is one that quietly matches nothing every time that preset is used. The
    /// engine's own answer to an unparseable predicate is to hold nothing back, which is the safe
    /// reading for a file written by hand — but it is not a reason to let this window write one.
    @objc private func confirm() {
        if pluginsAvailable, pluginCheckbox.state == .on {
            let text = currentPluginPredicate()
            guard let text, ContentFieldPredicate.parse(text) != nil else {
                let alert = NSAlert()
                alert.messageText = String(localized: "The plugin condition is incomplete.")
                alert.informativeText = String(localized: "Enter a value to compare against, or switch the condition off.")
                alert.alertStyle = .warning
                if let window { alert.beginSheetModal(for: window) { _ in } } else { alert.runModal() }
                return
            }
        }
        let filter = currentFilter()
        dismissSheet()
        onConfirm?(filter)
    }

    @objc private func cancel() { dismissSheet() }

    private func dismissSheet() {
        defer { onDismiss?() }
        guard let window else { return }
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            NSApp.stopModal()
            window.orderOut(nil)
        }
    }

    func present(over parent: NSWindow?) {
        guard let window else { return }
        if let parent, parent.isVisible {
            parent.beginSheet(window) { _ in }
        } else {
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.runModal(for: window)
        }
    }

    // MARK: - Automation (DEBUG)

    #if DEBUG
    /// Set the fields from a `key=value;;key=value` spec, so a script can put a filter in without
    /// clicking. Keys: exclude, min, max, days, plugin.
    ///
    /// `;;` between the pairs and not `;`, because a single semicolon is what separates patterns
    /// *inside* an exclusion list — the first version split on one and silently dropped every
    /// pattern after the first, so the commonest case a script would want to set was the one it
    /// could not express.
    func automationSet(_ spec: String) {
        for pair in spec.components(separatedBy: ";;") {
            // `omittingEmptySubsequences: false`, or `exclude=` — clearing a criterion — splits into
            // one piece and is skipped, which made "take this filter off again" the one thing a
            // script could not express. Measured in the running window.
            let kv = pair.split(separator: "=", maxSplits: 1,
                                omittingEmptySubsequences: false).map(String.init)
            guard kv.count == 2 else { continue }
            let value = kv[1]
            switch kv[0].trimmingCharacters(in: .whitespaces) {
            case "exclude": excludeField.stringValue = value
            case "min": sizeMinField.stringValue = value
            case "max": sizeMaxField.stringValue = value
            case "days": recentDaysField.stringValue = value
            case "plugin":
                pluginCheckbox.state = .on
                pluginValueField.stringValue = value
                pluginToggled()
            default: break
            }
        }
        refreshSummary()
    }

    func automationReport() -> String {
        let f = currentFilter()
        return """
        exclude=\(f.excludePatterns)
        min=\(f.minSize.map(String.init) ?? "-")
        max=\(f.maxSize.map(String.init) ?? "-")
        days=\(f.modifiedWithinDays.map(String.init) ?? "-")
        plugin=\(f.pluginPredicate ?? "-")
        criteria=\(f.activeCriteriaCount)
        pluginsEnabled=\(pluginCheckbox.isEnabled)
        pluginReason=\(pluginReason.stringValue)
        summary=\(summaryLabel.stringValue)

        """
    }

    func automationConfirm() { confirm() }
    #endif
}
