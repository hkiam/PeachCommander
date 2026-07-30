// SPDX-License-Identifier: Apache-2.0
// MarkColorDialog.swift - The "Mark All" dialog for editor + viewer. Beyond the
// search term it lets the user pick which highlight color the occurrences get,
// from the shared MarkPalette — including creating a new custom color via the
// system color picker. A newly picked custom color is persisted into the palette
// (MarkPalette.addCustom) only when it is actually used to mark, so the palette
// doesn't fill up with abandoned picks. Returns (term, paletteColorIndex).

import AppKit
import PCFoundation

@MainActor
final class MarkColorDialog: NSWindowController {
    /// Called on OK with the entered term and the chosen palette color index.
    var onConfirm: ((_ term: String, _ colorIndex: Int) -> Void)?

    private let promptText: String
    private let showsTerm: Bool
    private let termField = NSTextField()
    private let swatchRow = NSStackView()
    private let colorWell = NSColorWell()

    private enum Selection { case palette(Int); case custom }
    private var selection: Selection

    /// - Parameters:
    ///   - term: initial search term (editable; hidden when `showsTerm` is false).
    ///   - showsTerm: whether to show the term field (viewer: yes; editor uses
    ///     the current selection so it can pass it read-only as the title).
    ///   - initialColorIndex: palette index pre-selected when opened.
    init(title: String, prompt: String, term: String, showsTerm: Bool, initialColorIndex: Int) {
        self.promptText = prompt
        self.showsTerm = showsTerm
        let count = MarkPalette.colors.count
        self.selection = .palette(min(max(0, initialColorIndex), max(0, count - 1)))
        let window = NSWindow(contentRect: NSMakeRect(0, 0, 460, showsTerm ? 210 : 170),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = title
        window.center()
        super.init(window: window)
        build(term: term)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Present the dialog. Preferred: a window-modal SHEET attached to `parent` — it
    /// appears on the parent's Space (incl. full-screen viewers) and never freezes the
    /// whole app. Only when there is no usable parent do we fall back to an app-modal
    /// run loop (which previously could leave the app "hung" behind a full-screen window).
    func runModalDialog(over parent: NSWindow? = nil) {
        guard let window else { return }
        if let parent, parent.isVisible {
            window.level = .normal
            parent.beginSheet(window) { _ in }
        } else {
            window.level = .modalPanel
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
        if showsTerm {
            window.makeFirstResponder(termField)
            termField.currentEditor()?.selectAll(nil)
        }
        if window.sheetParent == nil { NSApp.runModal(for: window) }
    }

    /// Dismiss whether we were shown as a sheet or app-modally.
    private func dismiss() {
        colorWell.deactivate()
        if let window, let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            NSApp.stopModal()
            close()
        }
    }

    private func build(term: String) {
        guard let window, let content = window.contentView else { return }

        let promptLabel = NSTextField(labelWithString: promptText)
        promptLabel.font = Fonts.system13
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(promptLabel)

        termField.translatesAutoresizingMaskIntoConstraints = false
        termField.font = Fonts.monospacedDigit13
        termField.isBezeled = true
        termField.stringValue = term
        termField.isHidden = !showsTerm
        content.addSubview(termField)

        let colorLabel = NSTextField(labelWithString: String(localized: "Color:"))
        colorLabel.font = Fonts.system13
        colorLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(colorLabel)

        swatchRow.orientation = .horizontal
        swatchRow.spacing = 6
        swatchRow.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(swatchRow)
        rebuildSwatches()

        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.target = self
        colorWell.action = #selector(customColorChanged)
        colorWell.color = .systemRed
        content.addSubview(colorWell)

        let wellLabel = NSTextField(labelWithString: String(localized: "＋ Custom…"))
        wellLabel.font = Fonts.system13
        wellLabel.textColor = .secondaryLabelColor
        wellLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(wellLabel)

        let cancelButton = NSButton(title: String(localized: "Cancel"), target: self, action: #selector(cancelAction))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1B}"
        let confirmButton = NSButton(title: String(localized: "Mark"), target: self, action: #selector(confirmAction))
        confirmButton.bezelStyle = .rounded
        confirmButton.keyEquivalent = "\r"
        let buttons = NSStackView(views: [cancelButton, confirmButton])
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)

        NSLayoutConstraint.activate([
            promptLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            promptLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            promptLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            termField.topAnchor.constraint(equalTo: promptLabel.bottomAnchor, constant: 8),
            termField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            termField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            termField.heightAnchor.constraint(equalToConstant: showsTerm ? 24 : 0),

            colorLabel.topAnchor.constraint(equalTo: termField.bottomAnchor, constant: showsTerm ? 16 : 4),
            colorLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            swatchRow.centerYAnchor.constraint(equalTo: colorLabel.centerYAnchor),
            swatchRow.leadingAnchor.constraint(equalTo: colorLabel.trailingAnchor, constant: 10),

            colorWell.topAnchor.constraint(equalTo: colorLabel.bottomAnchor, constant: 14),
            colorWell.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            colorWell.widthAnchor.constraint(equalToConstant: 44),
            colorWell.heightAnchor.constraint(equalToConstant: 24),
            wellLabel.centerYAnchor.constraint(equalTo: colorWell.centerYAnchor),
            wellLabel.leadingAnchor.constraint(equalTo: colorWell.trailingAnchor, constant: 8),

            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: colorWell.bottomAnchor, constant: 16),
        ])
    }

    /// Build one selectable swatch per palette color, marking the current choice.
    private func rebuildSwatches() {
        swatchRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, color) in MarkPalette.colors.enumerated() {
            let b = NSButton(title: "", target: self, action: #selector(swatchClicked(_:)))
            b.tag = i
            b.isBordered = false
            b.wantsLayer = true
            b.toolTip = MarkPalette.name(i)
            b.layer?.backgroundColor = color.withAlphaComponent(1).cgColor
            b.layer?.cornerRadius = 4
            b.translatesAutoresizingMaskIntoConstraints = false
            b.widthAnchor.constraint(equalToConstant: 24).isActive = true
            b.heightAnchor.constraint(equalToConstant: 24).isActive = true
            swatchRow.addArrangedSubview(b)
        }
        updateSwatchSelection()
    }

    /// Draw a selection ring on the chosen swatch (none when a custom pick is active).
    private func updateSwatchSelection() {
        let selected: Int? = { if case .palette(let i) = selection { return i }; return nil }()
        for view in swatchRow.arrangedSubviews {
            guard let b = view as? NSButton else { continue }
            b.layer?.borderWidth = (b.tag == selected) ? 3 : 0
            b.layer?.borderColor = NSColor.controlAccentColor.cgColor
        }
    }

    @objc private func swatchClicked(_ sender: NSButton) {
        selection = .palette(sender.tag)
        updateSwatchSelection()
    }

    @objc private func customColorChanged() {
        selection = .custom
        updateSwatchSelection()
    }

    @objc private func confirmAction() {
        let term = termField.stringValue
        let colorIndex: Int
        switch selection {
        case .palette(let i): colorIndex = i
        case .custom: colorIndex = MarkPalette.addCustom(colorWell.color)   // persist on use
        }
        dismiss()
        onConfirm?(term, colorIndex)
    }

    @objc private func cancelAction() {
        dismiss()
    }
}
