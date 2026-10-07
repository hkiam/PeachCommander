// SPDX-License-Identifier: Apache-2.0
// GitCommitBox.swift — the message a commit is made with: more than one line, and pleasant to write.
//
// Phase 8. The commit box was a one-line field, so a commit could have a subject and nothing else — no
// body, no "why", which is the part of a message anybody reads later. This is a small text view instead:
// the subject on the first line, a body below it, Cmd+Return to commit. The subject's length is shown and
// turns orange past the length Settings ▸ Git names (72 unless changed), the common convention; the
// recent messages (phase 7) moved into a menu beside it.

import AppKit

@MainActor
final class GitCommitBox: NSView, NSTextViewDelegate {
    /// Cmd+Return in the text.
    var onCommit: (() -> Void)?

    private let text = MessageTextView()
    private let scroll = NSScrollView()
    private let recent = NSPopUpButton(frame: .zero, pullsDown: true)
    private let length = NSTextField(labelWithString: "")
    private var recentMessages: [String] = []
    private var theme: PluginTheme

    init(theme: PluginTheme) {
        self.theme = theme
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 70))
        text.isRichText = false
        text.allowsUndo = true
        text.font = .systemFont(ofSize: 12)
        text.textContainerInset = NSSize(width: 3, height: 4)
        text.isVerticallyResizable = true
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.isAutomaticQuoteSubstitutionEnabled = false     // a commit message is plain text, not prose
        text.isAutomaticDashSubstitutionEnabled = false
        text.delegate = self
        text.placeholder = L("Commit message — a subject line, then a body if it helps (Cmd+Return commits)")
        text.onCommandReturn = { [weak self] in self?.onCommit?() }
        scroll.documentView = text
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        recent.bezelStyle = .texturedRounded
        recent.isBordered = false
        recent.controlSize = .small
        (recent.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
        recent.toolTip = L("Recent commit messages")
        length.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        length.alignment = .right

        for view in [scroll, recent, length] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 64),
            recent.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 2),
            recent.leadingAnchor.constraint(equalTo: leadingAnchor),
            recent.bottomAnchor.constraint(equalTo: bottomAnchor),
            length.centerYAnchor.constraint(equalTo: recent.centerYAnchor),
            length.trailingAnchor.constraint(equalTo: trailingAnchor),
            length.leadingAnchor.constraint(greaterThanOrEqualTo: recent.trailingAnchor, constant: 6),
        ])
        setRecentMessages([])
        updateLength()
        applyTheme(theme)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var message: String {
        get { text.string }
        set { text.string = newValue; updateLength(); text.needsDisplay = true }
    }

    var isEnabled: Bool {
        get { text.isEditable }
        set { text.isEditable = newValue; recent.isEnabled = newValue }
    }

    var recentCount: Int { recentMessages.count }

    func applyTheme(_ theme: PluginTheme) {
        self.theme = theme
        text.backgroundColor = theme.background
        text.textColor = theme.text
        text.insertionPointColor = theme.text
        scroll.backgroundColor = theme.background
        text.placeholderColor = theme.secondaryText
        updateLength()
    }

    func setRecentMessages(_ messages: [String]) {
        recentMessages = messages
        recent.removeAllItems()
        recent.addItem(withTitle: "")
        recent.item(at: 0)?.image = NSImage(systemSymbolName: "text.badge.plus", accessibilityDescription: L("Recent commit messages"))
        for message in messages {
            let item = NSMenuItem(title: message, action: #selector(useRecent(_:)), keyEquivalent: "")
            item.target = self
            recent.menu?.addItem(item)
        }
        recent.isHidden = messages.isEmpty
    }

    @objc private func useRecent(_ sender: NSMenuItem) {
        message = sender.title
        window?.makeFirstResponder(text)
    }

    func textDidChange(_ notification: Notification) { updateLength() }

    /// The subject's length against the limit — the number turns orange past it.
    private func updateLength() {
        let subject = text.string.components(separatedBy: "\n").first ?? ""
        let limit = GitSettingsStore.current.subjectLength
        length.stringValue = subject.isEmpty ? "" : "\(subject.count)/\(limit)"
        length.textColor = subject.count > limit ? .systemOrange : theme.secondaryText
    }

    func focus() { window?.makeFirstResponder(text) }
}

/// A text view with a placeholder, and Cmd+Return as "commit".
@MainActor
private final class MessageTextView: NSTextView {
    var placeholder = ""
    var placeholderColor = NSColor.secondaryLabelColor
    var onCommandReturn: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.keyCode == 36 || event.keyCode == 76 {
            onCommandReturn?()
            return
        }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let inset = textContainerInset
        let padding = textContainer?.lineFragmentPadding ?? 0
        (placeholder as NSString).draw(
            in: NSRect(x: inset.width + padding, y: inset.height, width: bounds.width - 2 * (inset.width + padding),
                       height: bounds.height - 2 * inset.height),
            withAttributes: [.font: font ?? .systemFont(ofSize: 12), .foregroundColor: placeholderColor])
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true      // the placeholder comes and goes with the text
    }
}
