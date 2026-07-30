// CommandLineView.swift - Bottom command line (SPEC-001 §5, I06-T05).
//
// A cwd prompt + editable field. Enter executes (via onExecute), Tab completes the
// last path token (PathCompleter), Up/Down walk command history.

import AppKit
import PCFoundation

@MainActor
final class CommandLineView: NSView, NSTextFieldDelegate {
    private let promptLabel = NSTextField(labelWithString: "")
    private let field = NSTextField()

    /// Returns the active panel's current directory (for the prompt + completion).
    var cwdProvider: (() -> String)?
    /// Called when the user presses Return with a non-empty line.
    var onExecute: ((String) -> Void)?

    private var history: [String] = []
    private var historyIndex = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = Theme.current.statusBarBackground.cgColor

        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        promptLabel.font = Fonts.monospacedDigit13
        promptLabel.textColor = Theme.current.statusBarText
        promptLabel.lineBreakMode = .byTruncatingMiddle
        promptLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = Fonts.monospacedDigit13
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.textColor = Theme.current.statusBarText
        field.delegate = self
        field.placeholderString = String(localized: "command…")

        addSubview(promptLabel)
        addSubview(field)
        NSLayoutConstraint.activate([
            promptLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            promptLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            promptLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 340),
            field.leadingAnchor.constraint(equalTo: promptLabel.trailingAnchor, constant: 6),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            field.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    /// Re-apply theme colors (called on light/dark appearance changes).
    func applyTheme() {
        layer?.backgroundColor = Theme.current.statusBarBackground.cgColor
        promptLabel.textColor = Theme.current.statusBarText
        field.textColor = Theme.current.statusBarText
    }

    func setPrompt(_ cwd: String) {
        promptLabel.stringValue = "\(cwd) ›"
    }

    func focusField() { window?.makeFirstResponder(field) }

    /// Insert text at the end of the field and focus it (type-routing / append).
    func insertText(_ text: String) {
        field.stringValue += text
        focusField()
        field.currentEditor()?.selectedRange = NSRange(location: field.stringValue.count, length: 0)
    }

    // MARK: - Field editor commands

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            execute()
            return true
        case #selector(NSResponder.insertTab(_:)):
            completePath()
            return true
        case #selector(NSResponder.moveUp(_:)):
            recallHistory(offset: -1)
            return true
        case #selector(NSResponder.moveDown(_:)):
            recallHistory(offset: 1)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            field.stringValue = ""
            return true
        default:
            return false
        }
    }

    private func execute() {
        let line = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return }
        history.append(line)
        historyIndex = history.count
        field.stringValue = ""
        onExecute?(line)
    }

    private func completePath() {
        let text = field.stringValue
        let cwd = cwdProvider?() ?? NSHomeDirectory()
        // Complete the last whitespace-separated token.
        let parts = text.split(separator: " ", omittingEmptySubsequences: false)
        guard let last = parts.last.map(String.init), !last.isEmpty else { return }
        if let completed = PathCompleter.complete(last, in: cwd) {
            let prefix = text.dropLast(last.count)
            field.stringValue = prefix + completed
        }
    }

    private func recallHistory(offset: Int) {
        guard !history.isEmpty else { return }
        historyIndex = max(0, min(history.count, historyIndex + offset))
        field.stringValue = historyIndex < history.count ? history[historyIndex] : ""
    }
}
