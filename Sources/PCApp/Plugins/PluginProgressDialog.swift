// SPDX-License-Identifier: Apache-2.0
// PluginProgressDialog.swift — the window an asynchronous plugin command reports into (F-422).
//
// Not `Dialogs/ProgressDialog.swift`: that one is built around `OperationControl` and `OpProgress` from
// PCOperations — files, bytes, speed, ETA, pause — because it drives the transfer queue. A plugin command
// has a fraction, a line of text and a Cancel button, and reusing the transfer dialog would mean
// synthesising byte counts nobody measured and showing "0 B/s" next to a `git push`. So: a small window
// that says only what is actually known.
//
// Cancellation is cooperative and reads the other way round from a callback: `wasCancelled` is set on the
// main thread and read from the plugin's background thread through `updateProgress`, whose return value is
// the signal. A plugin that never calls `updateProgress` cannot be cancelled — which is why the header
// says so, rather than the host pretending it can kill a command mid-call.

import AppKit

@MainActor
final class PluginProgressDialog: NSWindowController {
    /// Read from the plugin's thread; written on the main thread. Atomic via the lock, since the two are
    /// genuinely different threads and `updateProgress` is the only channel between them.
    private let lock = NSLock()
    private var cancelled = false

    private let messageLabel = NSTextField(labelWithString: "")
    private let bar = NSProgressIndicator()
    private let cancelButton = NSButton()

    init(title: String) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 120),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.title = title
        super.init(window: window)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        messageLabel.font = .systemFont(ofSize: 12)
        messageLabel.lineBreakMode = .byTruncatingMiddle
        messageLabel.stringValue = ""

        bar.isIndeterminate = true
        bar.style = .bar
        bar.minValue = 0
        bar.maxValue = 1
        bar.startAnimation(nil)

        cancelButton.title = String(localized: "Cancel")
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancel)
        cancelButton.keyEquivalent = "\u{1b}"

        let buttons = NSStackView(views: [NSView(), cancelButton])
        buttons.orientation = .horizontal

        let stack = NSStackView(views: [messageLabel, bar, buttons])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        window?.contentView?.addSubview(stack)
        if let content = window?.contentView {
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: content.topAnchor),
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            ])
        }
    }

    func present(over parent: NSWindow?) {
        guard let window else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        if let parent { parent.addChildWindow(window, ordered: .above) }
    }

    /// Update the bar and the text. Returns false once Cancel has been pressed.
    func update(fraction: Double, text: String?) -> Bool {
        if let text { messageLabel.stringValue = text }
        if fraction < 0 {
            if !bar.isIndeterminate { bar.isIndeterminate = true; bar.startAnimation(nil) }
        } else {
            if bar.isIndeterminate { bar.stopAnimation(nil); bar.isIndeterminate = false }
            bar.doubleValue = min(1, fraction)
        }
        lock.lock(); let stop = cancelled; lock.unlock()
        return !stop
    }

    /// Not `close()`: NSWindowController already has one, and overriding it to mean "the command finished"
    /// would make every inherited caller mean something else.
    func dismiss() {
        if let window { window.parent?.removeChildWindow(window) }
        window?.orderOut(nil)
    }

    /// Press Cancel from the automation harness (F-422).
    ///
    /// The button's own action, not a shortcut to the flag: the point of a harness check is that the route
    /// a reader takes works, and Escape does not reach a `keyEquivalent` through a synthesised key event.
    func automationCancel() { cancel() }

    @objc private func cancel() {
        lock.lock(); cancelled = true; lock.unlock()
        cancelButton.isEnabled = false
        // "Cancelled" rather than a new "Cancelling…": the catalogue already has it in all nineteen
        // languages, and by the time the plugin's next `updateProgress` sees the flag there is nothing
        // left to distinguish the two states for the reader.
        messageLabel.stringValue = String(localized: "Cancelled")
    }
}
