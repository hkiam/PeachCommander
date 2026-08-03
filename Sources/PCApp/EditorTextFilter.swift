// SPDX-License-Identifier: Apache-2.0
// EditorTextFilter.swift - Run the selection through a shell command, and edit text undoably (F-356).
//
// Two things live here, both used by every editor text operation:
//
//   * `EditorTextFilter.replace` — the only way this editor should change text. `textView.string = x`
//     works and *clears the undo stack*: after a format, ⌘Z did nothing and the previous content was
//     gone for good. Going through `shouldChangeText` / `didChangeText` instead registers one undo
//     group per operation, keeps the selection sensible, and lets the delegate mark the file dirty.
//   * `EditorFilterDialog` — the prompt. A combo box rather than a plain field, because the whole point
//     of a filter is running it again: last week's `jq` expression is in the dropdown.
//
// The command itself runs in `TextPipe` (PCFoundation), which is where the process handling and its
// tests are.

import AppKit
import PCFoundation

enum EditorTextFilter {

    /// Replace `range` with `text`, undoably.
    ///
    /// Returns false when the text view refuses the edit — a read-only document, most likely — so the
    /// caller can say so rather than silently doing nothing.
    @discardableResult
    @MainActor
    static func replace(_ range: NSRange, with text: String, in textView: NSTextView,
                        actionName: String? = nil) -> Bool {
        guard textView.shouldChangeText(in: range, replacementString: text) else { return false }
        if let actionName { textView.undoManager?.setActionName(actionName) }
        textView.textStorage?.replaceCharacters(in: range, with: text)
        textView.didChangeText()
        return true
    }

    /// What `apply` did, for the status line.
    enum Outcome {
        case replaced(lines: Int)
        case failed(String)
        case unchanged
    }

    /// Pipe the selection — or the whole document, when nothing is selected — through `command`.
    ///
    /// Whole-document is the right fallback rather than an error: `sort` over a file is the common case,
    /// and requiring ⌘A first would be busywork. The selection is *replaced by stdout*, so a command
    /// that prints nothing empties it; that is exactly what `grep` is for, and undo covers the mistake.
    ///
    /// The command runs off the main thread. `TextPipe` waits up to twenty seconds, and spending those
    /// in `waitUntilExit()` on the main thread would be twenty seconds of spinning beachball for a
    /// mistyped command — so the editor stays responsive and the result is applied when it arrives.
    @MainActor
    static func apply(command: String, to textView: NSTextView,
                      workingDirectory: String?) async -> Outcome {
        let selection = textView.selectedRange()
        let whole = NSRange(location: 0, length: (textView.string as NSString).length)
        let range = selection.length > 0 ? selection : whole
        let input = (textView.string as NSString).substring(with: range)

        let result = await Task.detached(priority: .userInitiated) {
            TextPipe.run(command, over: input, workingDirectory: workingDirectory)
        }.value

        // The user could keep typing while the command ran. Replacing `range` then would overwrite
        // whatever moved into it, so the edit is only applied if the text there is still the text that
        // was sent — a stale replacement is far worse than asking for the command again.
        if case .output = result,
           (textView.string as NSString).substring(with:
                NSIntersectionRange(range, NSRange(location: 0,
                                                   length: (textView.string as NSString).length))) != input {
            return .failed(String(localized: "The text changed while the command was running."))
        }

        switch result {
        case .failed(let code, let message):
            // The document is untouched. Showing stderr is the point: `jq: error … at line 3` is
            // what the user needs, and pasting it into their file would be the worst outcome.
            return .failed(String(localized: "Command failed") + " (\(code)): " + firstLine(of: message))
        case .timedOut(let seconds):
            return .failed(String(format: String(localized: "Command did not finish within %d seconds"),
                                  seconds))
        case .output(let out):
            guard out != input else { return .unchanged }
            guard replace(range, with: out, in: textView,
                          actionName: String(localized: "Filter Through Command")) else {
                return .failed(String(localized: "This document is not editable"))
            }
            // Select the result, so a second filter chains onto the first instead of over the file.
            let replaced = NSRange(location: range.location, length: (out as NSString).length)
            textView.setSelectedRange(replaced)
            textView.scrollRangeToVisible(replaced)
            // LineEndings.lineCount, not split(separator: "\n"): "\r\n" is one Swift Character, so
            // splitting a CRLF result on "\n" reports one line for the whole file.
            return .replaced(lines: LineEndings.lineCount(out))
        }
    }

    /// stderr can be a page long (a stack trace, a usage message); the status line holds one line.
    private static func firstLine(of message: String) -> String {
        let line = message.split(separator: "\n").first.map(String.init) ?? message
        return line.count > 140 ? String(line.prefix(140)) + "…" : line
    }
}

/// The editor's built-in line operations (F-359).
///
/// Separate from the shell filter even though `sort` and `uniq` overlap with it: these work with no
/// tools installed, on any machine, and cost one menu pick rather than a typed command line.
enum EditorLineOperations {

    /// Apply `operation` to whole lines — the selected ones, or the whole document when nothing is
    /// selected.
    ///
    /// The selection is grown to line boundaries first. Sorting half a line is meaningless, and a user
    /// who dragged across three lines from the middle of the first means those three lines.
    @MainActor
    static func apply(_ operation: LineOperation, to textView: NSTextView,
                      actionName: String) -> EditorTextFilter.Outcome {
        let text = textView.string as NSString
        let selection = textView.selectedRange()
        let range = selection.length > 0
            ? text.lineRange(for: selection)
            : NSRange(location: 0, length: text.length)
        guard range.length > 0 else { return .unchanged }

        let input = text.substring(with: range)
        let output = LineOperations.apply(operation, to: input)
        guard output != input else { return .unchanged }
        guard EditorTextFilter.replace(range, with: output, in: textView, actionName: actionName) else {
            return .failed(String(localized: "This document is not editable"))
        }
        let replaced = NSRange(location: range.location, length: (output as NSString).length)
        // Keep the same lines selected, so operations chain: filter, then sort, then deduplicate.
        if selection.length > 0 {
            textView.setSelectedRange(replaced)
        } else {
            textView.setSelectedRange(NSRange(location: min(selection.location, replaced.length),
                                              length: 0))
        }
        textView.scrollRangeToVisible(textView.selectedRange())
        return .replaced(lines: LineEndings.lineCount(output))
    }
}

/// Asks for a command line, with the previously used ones in a dropdown.
final class EditorFilterDialog: ModalWindowController, NSComboBoxDelegate {
    /// Called with the command on OK; not called on cancel.
    var onConfirm: ((String) -> Void)?

    private let combo = NSComboBox()
    private let hint = NSTextField(labelWithString: "")

    /// - Parameters:
    ///   - entries: history, most recent first, used to seed the dropdown and the field.
    ///   - scope: what the command will be applied to, shown so nobody pipes a whole file by mistake.
    init(entries: [String], scope: String) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 150),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = String(localized: "Filter Through Command")
        super.init(window: window)
        window.delegate = self
        build(entries: entries, scope: scope)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build(entries: [String], scope: String) {
        guard let window else { return }
        let content = NSView()
        let label = NSTextField(labelWithString:
            String(localized: "Send the text through a shell command and take back its output:"))
        label.font = NSFont.systemFont(ofSize: 12)

        combo.usesDataSource = false
        // History first, then the suggestions the user has not used yet: a dropdown that is empty on
        // first run explains nothing about what belongs in it.
        var offered = entries
        for suggestion in TextPipeHistory.suggestions where !offered.contains(suggestion) {
            offered.append(suggestion)
        }
        combo.addItems(withObjectValues: offered)
        combo.stringValue = entries.first ?? ""
        combo.completes = true
        combo.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        combo.delegate = self
        combo.setAccessibilityLabel(String(localized: "Shell command"))

        hint.stringValue = scope
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        let ok = NSButton(title: String(localized: "Run"), target: self, action: #selector(confirm))
        ok.bezelStyle = .rounded
        ok.keyEquivalent = "\r"
        let cancel = NSButton(title: String(localized: "Cancel"), target: self, action: #selector(cancelDialog))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"

        let buttons = NSStackView(views: [cancel, ok])
        buttons.spacing = 10
        let stack = NSStackView(views: [label, combo, hint, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        window.contentView = content
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            // 999, not required: during window setup the content view is briefly zero-height, and a
            // required rule against it is the contradiction that fills the log. See CONVENTIONS.md.
            preferred(buttons.trailingAnchor.constraint(equalTo: stack.trailingAnchor)),
            preferred(combo.widthAnchor.constraint(equalTo: stack.widthAnchor))
        ])
    }

    private func preferred(_ constraint: NSLayoutConstraint) -> NSLayoutConstraint {
        constraint.priority = .init(999)
        return constraint
    }

    func runModalDialog(over parent: NSWindow?) {
        guard let window else { return }
        if let parent, parent.isVisible {
            parent.beginSheet(window) { _ in }
        } else {
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
        window.makeFirstResponder(combo)
        if window.sheetParent == nil { NSApp.runModal(for: window) }
    }

    @objc private func confirm() {
        let command = combo.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        dismiss()
        guard !command.isEmpty else { return }
        onConfirm?(command)
    }

    /// Not named `close`: NSWindowController already has one, and overriding it here would
    /// intercept every programmatic close of the window rather than only the Cancel button.
    @objc private func cancelDialog() { dismiss() }

    private func dismiss() {
        guard let window else { return }
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            NSApp.stopModal()
        }
        window.close()
    }
}
