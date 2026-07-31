// SPDX-License-Identifier: Apache-2.0
// SelectUnselectDialog.swift - Select/Unselect group dialogs (Num+/Num-)
//
// TC "Select group" / "Unselect group": a wildcard mask field (prefilled with
// the last-used mask) plus an "include directories" toggle. Presented modally;
// the result is delivered through `onConfirmMask`.

import AppKit
import PCFoundation

/// Select/Unselect group dialog.
final class SelectUnselectDialog: ModalWindowController {
    private let logger = PCFoundationLogger.logger

    /// Called on OK with the entered mask and the include-directories choice.
    var onConfirmMask: ((_ mask: String, _ includeDirectories: Bool) -> Void)?
    /// Called on Cancel.
    var onCancel: (() -> Void)?

    /// Remembered across invocations (simple mask history).
    private static var lastMask = "*.*"

    private let dialogType: SelectionDialogType
    private let textField = NSTextField()
    private let includeDirsCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let confirmButton = NSButton()
    private let cancelButton = NSButton()

    init(type: SelectionDialogType) {
        self.dialogType = type
        let window = NSWindow(
            contentRect: NSMakeRect(0, 0, 420, 170),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = type.rawValue
        window.center()
        window.level = .modalPanel
        super.init(window: window)
        window.delegate = self   // closing the window must end the modal session
        setupDialog()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Run the dialog modally.
    func runModalDialog() {
        guard let window else { return }
        NSApp.runModal(for: window)
    }

    private var promptText: String {
        String(localized: "Enter file mask (e.g. *.txt or *.c *.h):")
    }

    private func setupDialog() {
        guard let window else { return }
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        let promptLabel = NSTextField(labelWithString: promptText)
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        promptLabel.font = Fonts.system13
        content.addSubview(promptLabel)

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = Fonts.monospacedDigit13
        textField.isBezeled = true
        textField.isEditable = true
        textField.stringValue = SelectUnselectDialog.lastMask
        content.addSubview(textField)

        includeDirsCheckbox.translatesAutoresizingMaskIntoConstraints = false
        includeDirsCheckbox.title = String(localized: "Include directories")
        includeDirsCheckbox.font = Fonts.system13
        includeDirsCheckbox.state = .off
        content.addSubview(includeDirsCheckbox)

        let buttons = NSStackView()
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.orientation = .horizontal
        buttons.spacing = 10

        cancelButton.title = String(localized: "Cancel")
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1B}"
        cancelButton.action = #selector(cancelAction)
        cancelButton.target = self

        confirmButton.title = String(localized: "OK")
        confirmButton.bezelStyle = .rounded
        confirmButton.keyEquivalent = "\r"
        confirmButton.action = #selector(confirmAction)
        confirmButton.target = self

        buttons.addView(cancelButton, in: .trailing)
        buttons.addView(confirmButton, in: .trailing)
        content.addSubview(buttons)

        NSLayoutConstraint.activate([
            promptLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            promptLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            promptLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            textField.topAnchor.constraint(equalTo: promptLabel.bottomAnchor, constant: 8),
            textField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            textField.heightAnchor.constraint(equalToConstant: 24),

            includeDirsCheckbox.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 10),
            includeDirsCheckbox.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            buttons.topAnchor.constraint(equalTo: includeDirsCheckbox.bottomAnchor, constant: 16),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])
    }

    @objc private func confirmAction() {
        let mask = textField.stringValue.trimmingCharacters(in: .whitespaces)
        SelectUnselectDialog.lastMask = mask.isEmpty ? "*.*" : mask
        let includeDirs = includeDirsCheckbox.state == .on
        NSApp.stopModal()
        close()
        onConfirmMask?(SelectUnselectDialog.lastMask, includeDirs)
    }

    @objc private func cancelAction() {
        NSApp.stopModal()
        close()
        onCancel?()
    }
}

/// Dialog type for selection group operations.
enum SelectionDialogType: String {
    case selectByMask = "Select Group"
    case unselectByMask = "Unselect Group"
}
