// SPDX-License-Identifier: Apache-2.0
// InputDialog.swift - Generic single-line text input dialog (I04)
//
// A reusable modal prompt used by file operations (rename, mkdir, etc.) that
// need a single line of text from the user. Mirrors the structure of
// SelectUnselectDialog: NSApp.runModal(for:) / NSApp.stopModal() + close().

import AppKit
import PCFoundation
import PCOperations

/// Generic modal single-line text input dialog.
final class InputDialog: ModalWindowController {
    private let logger = PCFoundationLogger.logger

    /// Called on OK with the entered text.
    var onConfirm: ((String) -> Void)?
    /// Called on Cancel or Esc.
    var onCancel: (() -> Void)?

    private let prompt: String
    private let okTitle: String
    private let textField: NSTextField
    private let confirmButton = NSButton()
    private let cancelButton = NSButton()
    /// Optional accessory checkbox (e.g. "Run in background"); nil = not shown.
    private let checkboxTitle: String?
    private let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    /// Optional second accessory checkbox (e.g. "Only newer files"); nil = not shown.
    private let secondCheckboxTitle: String?
    private let secondCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    /// Optional third accessory checkbox (e.g. "Queue for later"); nil = not shown.
    private let thirdCheckboxTitle: String?
    private let thirdCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    /// Whether the accessory checkbox is checked (only meaningful when a
    /// `checkboxTitle` was provided).
    var isChecked: Bool { checkbox.state == .on }
    /// Whether the second accessory checkbox is checked.
    var isSecondChecked: Bool { secondCheckbox.state == .on }
    /// Whether the third accessory checkbox is checked.
    var isThirdChecked: Bool { thirdCheckbox.state == .on }

    /// Builds the dialog.
    /// - Parameters:
    ///   - title: The window title.
    ///   - prompt: The label shown above the text field.
    ///   - initialValue: The text pre-filled (and selected) in the field.
    ///   - okTitle: The title of the confirm button.
    init(title: String, prompt: String, initialValue: String, okTitle: String = "OK", secure: Bool = false,
         checkboxTitle: String? = nil, checkboxOn: Bool = false,
         secondCheckboxTitle: String? = nil, secondCheckboxOn: Bool = false,
         thirdCheckboxTitle: String? = nil, thirdCheckboxOn: Bool = false) {
        self.prompt = prompt
        self.okTitle = okTitle
        self.textField = secure ? NSSecureTextField() : NSTextField()
        self.checkboxTitle = checkboxTitle
        self.secondCheckboxTitle = secondCheckboxTitle
        self.thirdCheckboxTitle = thirdCheckboxTitle

        let extra = (checkboxTitle == nil ? 0 : 32) + (secondCheckboxTitle == nil ? 0 : 26)
            + (thirdCheckboxTitle == nil ? 0 : 26)
        // 620pt and resizable, because the old fixed 420 could not show what it was asking about.
        // A path is the longest thing typed into this dialog and 420pt left 380pt for the field —
        // 83 characters of `\\srv-ablage.pdv.lan\ablage\…` measure 542pt in this font, so the
        // interesting end of the path was never on screen and the window could not be pulled
        // wider either. Every InputDialog gets this: rename and mkdir ask about long names too.
        let window = NSWindow(
            contentRect: NSMakeRect(0, 0, 620, 150 + CGFloat(extra)),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        // Vertically the dialog is exactly as tall as its contents; only the width is worth
        // dragging, and an unbounded height would just stretch empty space.
        window.minSize = NSSize(width: 420, height: 150 + CGFloat(extra))
        window.maxSize = NSSize(width: 2400, height: 150 + CGFloat(extra))
        window.center()
        window.level = .modalPanel
        super.init(window: window)
        window.delegate = self   // closing the window must end the modal session
        checkbox.state = checkboxOn ? .on : .off
        secondCheckbox.state = secondCheckboxOn ? .on : .off
        thirdCheckbox.state = thirdCheckboxOn ? .on : .off
        setupDialog(initialValue: initialValue)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Runs the dialog modally (NSApp.runModal). OK fires `onConfirm(text)`
    /// then stops the modal session and closes the window; Esc/Cancel fires
    /// `onCancel`.
    /// Present the dialog. Preferred: a window-modal SHEET attached to `parent` (appears
    /// on the parent's Space, incl. full-screen viewers, and never freezes the app);
    /// falls back to an app-modal run loop only when there is no usable parent.
    #if DEBUG
    /// Answers queued by the automation harness, oldest first.
    ///
    /// Deliberately a queue and not a single value: a scenario that copies, then confirms an
    /// overwrite, then names something else asks three questions, and one slot would silently give
    /// the same answer to all of them.
    private static var scriptedAnswers: [String] = []

    /// Queue one answer for the next dialog that asks (automation only).
    static func queueScriptedAnswer(_ text: String) { scriptedAnswers.append(text) }

    /// Whether anything is still waiting to be consumed — a script can then assert that the dialog
    /// it expected actually appeared, instead of passing because nothing asked.
    static var hasScriptedAnswers: Bool { !scriptedAnswers.isEmpty }

    private static func takeScriptedAnswer() -> String? {
        scriptedAnswers.isEmpty ? nil : scriptedAnswers.removeFirst()
    }
    #endif

    func runModalDialog(over parent: NSWindow? = nil) {
        guard let window else { return }
        #if DEBUG
        // Answered from a script, without ever showing the dialog.
        //
        // Every command that asks for something goes through here, and until now that made all of
        // them unreachable from the harness: a modal session does not return, so a script that runs
        // one stops at that line and the rest of the scenario never happens. Whole features have
        // therefore had no end-to-end coverage at all — not because they were hard to check, but
        // because nothing could get past the first question.
        //
        // DEBUG-only and consumed one at a time, so a script has to say what it expects for each
        // prompt in turn and a stray dialog cannot quietly eat an answer meant for the next one.
        if let canned = Self.takeScriptedAnswer() {
            onConfirm?(canned)
            return
        }
        #endif
        if let parent, parent.isVisible {
            parent.beginSheet(window) { _ in }
        } else {
            window.makeKeyAndOrderFront(nil)
        }
        window.makeFirstResponder(textField)
        textField.currentEditor()?.selectAll(nil)
        if window.sheetParent == nil { NSApp.runModal(for: window) }
    }

    private func dismiss() {
        if let window, let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            NSApp.stopModal()
            close()
        }
    }

    private func setupDialog(initialValue: String) {
        guard let window else { return }
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        let promptLabel = NSTextField(labelWithString: prompt)
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        promptLabel.font = Fonts.system13
        content.addSubview(promptLabel)

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = Fonts.monospacedDigit13
        textField.isBezeled = true
        textField.isEditable = true
        // A programmatically created NSTextField is a WRAPPING, non-scrolling field: measured
        // defaults are `usesSingleLineMode = false`, `cell.wraps = true`, `isScrollable = false`,
        // `lineBreakMode = .byWordWrapping`. With the 24pt height constraint below, a long value
        // therefore laid itself out over three lines (the cell asked for 56pt for the path that
        // prompted this) and had all but the first clipped away — and could not be scrolled into
        // view either, so the rest of it was simply unreachable. Interface Builder sets these;
        // code has to.
        //
        // Both lines are needed and the order matters. `usesSingleLineMode` alone leaves
        // `cell.wraps == true`, and `lineBreakMode` and `isScrollable` overwrite each other —
        // whichever is assigned last wins, so a truncating line-break mode set afterwards turns
        // scrolling back off. Scrolling is the one to keep: this field is *edited*, and an
        // ellipsis the caret cannot travel past would look tidier while hiding the same text.
        textField.usesSingleLineMode = true
        textField.cell?.isScrollable = true
        textField.stringValue = initialValue
        content.addSubview(textField)

        let buttons = NSStackView()
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.orientation = .horizontal
        buttons.spacing = 10

        cancelButton.title = String(localized: "Cancel")
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1B}"
        cancelButton.action = #selector(cancelAction)
        cancelButton.target = self

        confirmButton.title = okTitle
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

            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])

        // Stack any accessory checkboxes vertically between the field and the buttons.
        var lastBottom = textField.bottomAnchor
        var topGap: CGFloat = 12
        for (title, box) in [(checkboxTitle, checkbox), (secondCheckboxTitle, secondCheckbox),
                             (thirdCheckboxTitle, thirdCheckbox)] {
            guard let title else { continue }
            box.title = title
            box.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(box)
            NSLayoutConstraint.activate([
                box.topAnchor.constraint(equalTo: lastBottom, constant: topGap),
                box.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20)
            ])
            lastBottom = box.bottomAnchor
            topGap = 6
        }
        buttons.topAnchor.constraint(equalTo: lastBottom,
                                     constant: checkboxTitle == nil ? 16 : 14).isActive = true
    }

    @objc private func confirmAction() {
        let value = textField.stringValue
        dismiss()
        onConfirm?(value)
    }

    @objc private func cancelAction() {
        dismiss()
        onCancel?()
    }
}
