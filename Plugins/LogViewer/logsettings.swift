// SPDX-License-Identifier: Apache-2.0
// logsettings.swift — the Log Viewer's pane in the host Settings dialog.
//
// Contributed via the `views` (container "settings") entry in Info.plist and built
// by PcMakeView. Self-contained AppKit; reads/writes LogConfigStore, which persists
// under the isolated config root. Changing anything posts .logViewerConfigChanged
// so open viewer windows restyle live.

import AppKit

final class LogSettingsView: NSView {
    private var wells: [(level: LogLevel, well: NSColorWell)] = []
    private let lineNumbersCheck = NSButton(checkboxWithTitle: L("Show line numbers"), target: nil, action: nil)
    private let wordWrapCheck = NSButton(checkboxWithTitle: L("Word wrap long lines"), target: nil, action: nil)
    private let customFormatsPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let removeFormatButton = NSButton(title: "", target: nil, action: nil)

    init() {
        // Sized to fit the narrower embedded pane in the host Settings dialog.
        super.init(frame: NSRect(x: 0, y: 0, width: 460, height: 420))
        build()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        let config = LogConfigStore.shared.config

        let colorsHeader = sectionLabel(L("Level Colors"))
        let grid = NSGridView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 6
        grid.columnSpacing = 10
        for level in LogStyle.ordered {
            let name = NSTextField(labelWithString: LogStyle.displayName(level))
            name.alignment = .right
            let well = NSColorWell()
            well.color = LogStyle.color(level, config: config)
            well.translatesAutoresizingMaskIntoConstraints = false
            well.widthAnchor.constraint(equalToConstant: 44).isActive = true
            well.heightAnchor.constraint(equalToConstant: 22).isActive = true
            well.target = self
            well.action = #selector(colorChanged(_:))
            well.tag = LogStyle.ordered.firstIndex(of: level) ?? 0
            let reset = NSButton(title: L("Default"), target: self, action: #selector(resetColor(_:)))
            reset.bezelStyle = .rounded
            reset.controlSize = .small
            reset.tag = well.tag
            grid.addRow(with: [name, well, reset])
            wells.append((level, well))
        }

        lineNumbersCheck.state = config.showLineNumbers ? .on : .off
        lineNumbersCheck.target = self
        lineNumbersCheck.action = #selector(optionChanged)
        wordWrapCheck.state = config.wordWrap ? .on : .off
        wordWrapCheck.target = self
        wordWrapCheck.action = #selector(optionChanged)

        let optionsHeader = sectionLabel(L("Display"))

        // Log formats section.
        let formatsHeader = sectionLabel(L("Log Formats"))
        let formatsHint = NSTextField(wrappingLabelWithString:
            L("Built-in: log4j, log4net, CSV. Add your own regex formats using named groups (?<time>…), (?<level>…), (?<msg>…)."))
        formatsHint.font = NSFont.systemFont(ofSize: 11)
        formatsHint.textColor = .secondaryLabelColor
        formatsHint.preferredMaxLayoutWidth = 420
        let addButton = NSButton(title: L("Add Regex Format…"), target: self, action: #selector(addRegexFormat))
        addButton.bezelStyle = .rounded
        removeFormatButton.title = L("Remove")
        removeFormatButton.bezelStyle = .rounded
        removeFormatButton.target = self
        removeFormatButton.action = #selector(removeSelectedFormat)
        let formatRow = NSStackView(views: [customFormatsPopup, addButton, removeFormatButton])
        formatRow.orientation = .horizontal
        formatRow.spacing = 8
        refreshFormatsPopup()

        let stack = NSStackView(views: [colorsHeader, grid, optionsHeader, lineNumbersCheck, wordWrapCheck,
                                        formatsHeader, formatsHint, formatRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.boldSystemFont(ofSize: 12)
        return label
    }

    @objc private func colorChanged(_ sender: NSColorWell) {
        guard LogStyle.ordered.indices.contains(sender.tag) else { return }
        let level = LogStyle.ordered[sender.tag]
        let hex = sender.color.hexString
        LogConfigStore.shared.update { $0.levelColors[level.rawValue] = hex }
    }

    @objc private func resetColor(_ sender: NSButton) {
        guard LogStyle.ordered.indices.contains(sender.tag) else { return }
        let level = LogStyle.ordered[sender.tag]
        LogConfigStore.shared.update { $0.levelColors.removeValue(forKey: level.rawValue) }
        if let entry = wells.first(where: { $0.level == level }) {
            entry.well.color = LogStyle.defaultColor(level)
        }
    }

    @objc private func optionChanged() {
        LogConfigStore.shared.update {
            $0.showLineNumbers = lineNumbersCheck.state == .on
            $0.wordWrap = wordWrapCheck.state == .on
        }
    }

    // MARK: - Formats

    /// Populate the popup with all formats; built-ins are shown but cannot be
    /// removed (the Remove button enables only for a selected custom format).
    private func refreshFormatsPopup() {
        let all = LogConfigStore.shared.config.allFormats
        customFormatsPopup.removeAllItems()
        for f in all {
            let title = f.builtin ? "\(f.name) \(L("(built-in)"))" : f.name
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.representedObject = f.id
            customFormatsPopup.menu?.addItem(item)
        }
        updateRemoveEnabled()
        customFormatsPopup.target = self
        customFormatsPopup.action = #selector(formatSelectionChanged)
    }

    @objc private func formatSelectionChanged() { updateRemoveEnabled() }

    private func updateRemoveEnabled() {
        let id = customFormatsPopup.selectedItem?.representedObject as? String
        let isCustom = LogConfigStore.shared.config.customFormats.contains { $0.id == id }
        removeFormatButton.isEnabled = isCustom
    }

    @objc private func removeSelectedFormat() {
        guard let id = customFormatsPopup.selectedItem?.representedObject as? String else { return }
        LogConfigStore.shared.update { $0.customFormats.removeAll { $0.id == id } }
        refreshFormatsPopup()
    }

    @objc private func addRegexFormat() {
        let alert = NSAlert()
        alert.messageText = L("Add Regex Format")
        alert.informativeText = L("Use named groups (?<time>…), (?<level>…), (?<msg>…).")
        let name = NSTextField(frame: NSRect(x: 0, y: 34, width: 360, height: 24))
        name.placeholderString = L("Name")
        let pattern = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        pattern.placeholderString = L("Regular expression")
        pattern.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 62))
        container.addSubview(name); container.addSubview(pattern)
        alert.accessoryView = container
        alert.addButton(withTitle: L("Add"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let trimmedName = name.stringValue.trimmingCharacters(in: .whitespaces)
        let trimmedPattern = pattern.stringValue.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedPattern.isEmpty else { return }
        guard (try? NSRegularExpression(pattern: trimmedPattern)) != nil else {
            let err = NSAlert()
            err.messageText = L("Invalid regular expression")
            err.alertStyle = .warning
            err.runModal()
            return
        }
        let id = "custom.\(UUID().uuidString)"
        let format = LogFormat(id: id, name: trimmedName, kind: .regex, pattern: trimmedPattern)
        LogConfigStore.shared.update { cfg in
            cfg.customFormats.append(format)
        }
        refreshFormatsPopup()
        customFormatsPopup.selectItem(withTitle: trimmedName)
        updateRemoveEnabled()
    }
}
