// SPDX-License-Identifier: Apache-2.0
// EditorRegexFindDialog.swift - Find and replace with a regular expression in the editor (F-151).
//
// The editor's ⌘F is the *native* find bar (`NSTextFinder`), which cannot do regular expressions and
// offers no way to be taught: it searches on its own behalf, and its client protocol supplies text,
// not a matcher. Replacing the bar would mean rebuilding ⌘G, the shared find pasteboard and the
// incremental highlighting that come free with it.
//
// So this sits *beside* the bar rather than instead of it. ⌘F stays exactly as it was for plain
// text; this is a second, pattern-aware search reached by its own command — and once a pattern has
// been used, Find Next and Find Previous step through *its* matches, so ⌘G keeps meaning what it
// always meant.
//
// Modal, like every other dialog in this window (Go to Line, Filter Through Command, Mark All), for
// two reasons: it is what the rest of the editor does, and a modeless panel owns a lifetime problem
// that has already cost this project a dialog that opened and then answered nothing.

import AppKit
import PCFoundation

final class EditorRegexFindDialog: ModalWindowController {

    /// What the user asked for. `replacement` is nil when only searching.
    struct Request {
        let pattern: String
        let replacement: String?
        let caseInsensitive: Bool
        let inSelection: Bool
        /// True when "Replace All" was pressed rather than "Find".
        let replaceAll: Bool
    }

    var onConfirm: ((Request) -> Void)?

    private let patternField = NSTextField()
    private let replacementField = NSTextField()
    private let caseBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let selectionBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let errorLabel = NSTextField(labelWithString: "")
    private let showsReplace: Bool
    private var pendingReplaceAll = false

    /// - Parameters:
    ///   - showsReplace: whether the replacement field and "Replace All" are offered. A read-only
    ///     document gets the search half only, rather than a button that fails when pressed.
    ///   - hasSelection: gates "in selection" — offering a scope that does not exist is a checkbox
    ///     that silently does nothing.
    init(pattern: String, replacement: String, caseInsensitive: Bool,
         showsReplace: Bool, hasSelection: Bool) {
        self.showsReplace = showsReplace
        let height: CGFloat = showsReplace ? 250 : 200
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: height),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = showsReplace
            ? String(localized: "Find & Replace with a Regular Expression")
            : String(localized: "Find with a Regular Expression")
        super.init(window: window)
        window.delegate = self
        build(pattern: pattern, replacement: replacement,
              caseInsensitive: caseInsensitive, hasSelection: hasSelection)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build(pattern: String, replacement: String,
                       caseInsensitive: Bool, hasSelection: Bool) {
        guard let window else { return }
        patternField.stringValue = pattern
        patternField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        patternField.setAccessibilityLabel(String(localized: "Regular expression"))
        replacementField.stringValue = replacement
        replacementField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        replacementField.setAccessibilityLabel(String(localized: "Replacement"))

        caseBox.title = String(localized: "Ignore case")
        caseBox.state = caseInsensitive ? .on : .off
        selectionBox.title = String(localized: "In selection only")
        selectionBox.isEnabled = hasSelection
        selectionBox.toolTip = hasSelection
            ? String(localized: "Search and replace only inside the selected text.")
            : String(localized: "Select some text first to limit the search to it.")

        errorLabel.font = NSFont.systemFont(ofSize: 11)
        errorLabel.textColor = .systemRed
        errorLabel.isHidden = true

        // `$1` is worth saying out loud: it is the reason to use a pattern for a replacement at all,
        // and nothing else in the dialog would hint at it.
        let hint = NSTextField(wrappingLabelWithString: showsReplace
            ? String(localized: "`^` and `$` match the start and end of a line. In the replacement, `$1` is the first capture group and `$0` the whole match.")
            : String(localized: "`^` and `$` match the start and end of a line."))
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        var rows: [NSView] = [labelled(String(localized: "Find:"), patternField)]
        if showsReplace { rows.append(labelled(String(localized: "Replace with:"), replacementField)) }
        rows.append(contentsOf: [caseBox, selectionBox, hint, errorLabel])

        let find = NSButton(title: String(localized: "Find"), target: self, action: #selector(confirmFind))
        find.bezelStyle = .rounded
        find.keyEquivalent = "\r"
        let cancel = NSButton(title: String(localized: "Close"), target: self, action: #selector(cancelDialog))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        var buttonViews: [NSView] = [cancel, NSView()]
        if showsReplace {
            let all = NSButton(title: String(localized: "Replace All"), target: self,
                               action: #selector(confirmReplaceAll))
            all.bezelStyle = .rounded
            buttonViews.append(all)
        }
        buttonViews.append(find)
        let buttons = NSStackView(views: buttonViews)
        buttons.orientation = .horizontal
        buttons.spacing = 10
        rows.append(buttons)

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor),
            patternField.widthAnchor.constraint(equalToConstant: 400),
            replacementField.widthAnchor.constraint(equalToConstant: 400),
            buttons.widthAnchor.constraint(equalToConstant: 500),
        ])
        window.contentView = content
        window.initialFirstResponder = patternField
    }

    private func labelled(_ title: String, _ field: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 100).isActive = true
        let row = NSStackView(views: [label, field])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    @objc private func confirmFind() { pendingReplaceAll = false; confirm() }
    @objc private func confirmReplaceAll() { pendingReplaceAll = true; confirm() }

    /// Validate the pattern here, so a typo is answered in the dialog that has the field in it —
    /// not by a search that finds nothing, which reads as "the text is not there".
    @objc private func confirm() {
        let pattern = patternField.stringValue
        guard !pattern.isEmpty else { NSSound.beep(); return }
        let made = RegexTextSearch.compile(pattern, caseInsensitive: caseBox.state == .on)
        guard made.regex != nil else {
            errorLabel.stringValue = made.error ?? String(localized: "That is not a valid regular expression")
            errorLabel.isHidden = false
            return
        }
        errorLabel.isHidden = true
        onConfirm?(Request(pattern: pattern,
                           replacement: showsReplace ? replacementField.stringValue : nil,
                           caseInsensitive: caseBox.state == .on,
                           inSelection: selectionBox.isEnabled && selectionBox.state == .on,
                           replaceAll: pendingReplaceAll))
        dismiss()
    }

    @objc private func cancelDialog() { dismiss() }

    private func dismiss() {
        guard let window else { return }
        if let parent = window.sheetParent { parent.endSheet(window) } else { NSApp.stopModal(); close() }
    }

    /// Present as a sheet over `parent` when there is one, else app-modally — the same two-way
    /// presentation the other editor dialogs use.
    func present(over parent: NSWindow?) {
        guard let window else { return }
        if let parent, parent.isVisible {
            parent.beginSheet(window) { _ in }
        } else {
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
        window.makeFirstResponder(patternField)
        if window.sheetParent == nil { NSApp.runModal(for: window) }
    }
}
