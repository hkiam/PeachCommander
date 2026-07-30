// ErrorLogWindowController.swift - End-of-operation error log (F-089).
//
// A file operation that ran with "continue on error" (Skip All, or per-file
// Skip) collects each failure instead of aborting; when it finishes with a
// non-empty log this window summarises what was skipped, so the user can review
// and copy the list rather than losing it (the old behaviour discarded it).

import AppKit

final class ErrorLogWindowController: NSWindowController, NSWindowDelegate {
    private let textView = NSTextView()
    /// Keeps presented controllers alive while their window/sheet is on screen.
    private static var presented: [ErrorLogWindowController] = []

    /// Present a modal-ish log window listing `entries` (path → message). `summary`
    /// is the one-line heading (e.g. "3 of 12 items were skipped"). No-op if empty.
    static func present(over parent: NSWindow?, summary: String, entries: [(path: String, message: String)]) {
        guard !entries.isEmpty else { return }
        let controller = ErrorLogWindowController(summary: summary, entries: entries)
        presented.append(controller)
        if let parent, let sheet = controller.window {
            parent.beginSheet(sheet) { _ in presented.removeAll { $0 === controller } }
        } else {
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
        }
    }

    private init(summary: String, entries: [(path: String, message: String)]) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "Operation Errors")
        super.init(window: window)
        window.delegate = self
        buildUI(summary: summary, body: Self.format(entries))
        window.center()
    }

    func windowWillClose(_ notification: Notification) {
        Self.presented.removeAll { $0 === self }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func format(_ entries: [(path: String, message: String)]) -> String {
        entries.map { "• \($0.path)\n    \($0.message)" }.joined(separator: "\n\n")
    }

    private func buildUI(summary: String, body: String) {
        guard let content = window?.contentView else { return }

        let heading = NSTextField(labelWithString: summary)
        heading.font = .boldSystemFont(ofSize: 13)
        heading.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(heading)

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.string = body
        textView.textContainerInset = NSSize(width: 6, height: 6)
        scroll.documentView = textView
        content.addSubview(scroll)

        let copyButton = NSButton(title: String(localized: "Copy"), target: self, action: #selector(copyLog))
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(copyButton)

        let closeButton = NSButton(title: String(localized: "Close"), target: self, action: #selector(closeWindow))
        closeButton.keyEquivalent = "\r"
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(closeButton)

        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            heading.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            heading.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -16),

            scroll.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            scroll.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -12),

            closeButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
            closeButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),

            copyButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            copyButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            copyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
        ])
    }

    @objc private func copyLog() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)
    }

    @objc private func closeWindow() {
        if let window, let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            close()
        }
    }
}
