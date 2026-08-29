// SPDX-License-Identifier: Apache-2.0
// MacroRecordingIndicator.swift — the small window that says a recording is running (F-478).
//
// A recording with no visible state is a trap: it is armed from a window the user then closes, it
// survives every folder change, and the only way to find out whether it is still on would be to go
// looking for the menu item again. So while it runs there is exactly one thing on screen that says so,
// says how much it has caught, and stops it.
//
// A non-activating utility panel rather than a sheet or a modal, because the whole point of the
// recording is that the user goes on working in the panels — anything that takes key focus, or that
// blocks the main window, would make the feature impossible to use. `.floating` keeps it above the app
// without it becoming the thing the user has to dismiss.

import AppKit

@MainActor
final class MacroRecordingIndicator: NSWindowController {

    /// Stop and offer the steps.
    var onStop: (() -> Void)?
    /// Throw the recording away.
    var onCancel: (() -> Void)?

    private let countLabel = NSTextField(labelWithString: "")
    private let dot = NSImageView()
    private let hint = NSTextField(wrappingLabelWithString: "")
    /// Whether this indicator came back with a recording that survived a restart.
    private var resumed = false

    init() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 84),
                            styleMask: [.titled, .utilityWindow, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.title = String(localized: "Recording a Macro")
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        // It must not become the key window when the user clicks Stop mid-work; and it must never be
        // what ⌘W closes, which is why there is no close button in the mask above.
        panel.becomesKeyOnlyIfNeeded = true
        super.init(window: panel)
        buildUI()
        update(count: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        // The red dot every recorder on this platform uses, so the window is recognisable before it is
        // read. A template image tinted red rather than a drawn circle: it follows the system's own
        // sizing and stays right in both appearances.
        dot.image = NSImage(systemSymbolName: "record.circle",
                            accessibilityDescription: String(localized: "Recording"))
        dot.contentTintColor = .systemRed
        dot.symbolConfiguration = .init(pointSize: 15, weight: .regular)

        countLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
        countLabel.lineBreakMode = .byTruncatingTail

        hint.stringValue = Self.ordinaryHint
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor

        func button(_ title: String, _ action: Selector) -> NSButton {
            let b = NSButton(title: title, target: self, action: action)
            b.bezelStyle = .rounded
            return b
        }
        let stop = button(String(localized: "Stop and Save…"), #selector(stopTapped))
        stop.keyEquivalent = "\r"
        // Its own string rather than the shared "Discard": that one is the answer to "save your
        // changes?" and several languages had translated it as exactly that — the Russian button would
        // have read "Cancel changes" over a macro recording, which is a different offer.
        let cancel = button(String(localized: "Discard Recording"), #selector(cancelTapped))

        let top = NSStackView(views: [dot, countLabel])
        top.orientation = .horizontal
        top.spacing = 6
        let buttons = NSStackView(views: [cancel, NSView(), stop])
        buttons.orientation = .horizontal
        buttons.spacing = 10

        let column = NSStackView(views: [top, hint, buttons])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 8
        column.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            column.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            column.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            column.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            buttons.widthAnchor.constraint(equalTo: column.widthAnchor),
            hint.widthAnchor.constraint(equalTo: column.widthAnchor),
        ])
        content.layoutSubtreeIfNeeded()
        window?.setContentSize(content.fittingSize)
    }

    /// Put it where it does not sit over the panels: bottom right of the main window's screen.
    func present(relativeTo host: NSWindow?) {
        guard let window else { return }
        if let frame = (host?.screen ?? NSScreen.main)?.visibleFrame {
            window.setFrameOrigin(NSPoint(x: frame.maxX - window.frame.width - 24,
                                          y: frame.minY + 24))
        }
        // `orderFront`, never `makeKeyAndOrderFront`: the user is typing in a panel and the recording
        // must not take that away from them.
        window.orderFront(nil)
    }

    static var ordinaryHint: String {
        String(localized: "Do the steps in the panels, then stop. Copying, moving, renaming, deleting, new folders and new files are recorded — not what you type into a file afterwards.")
    }

    /// Say that this recording was still running when the app last stopped.
    ///
    /// Worth its own sentence rather than coming back silently: a red dot the user did not just press
    /// is a thing to explain, and the two useful answers — carry on, or throw it away — are both right
    /// there. Without this the indicator would look like the app had started recording by itself.
    func setResumed(_ resumed: Bool) {
        self.resumed = resumed
        guard resumed else { return }
        hint.stringValue = String(localized:
            "This recording was still running when Peach Commander last stopped. Carry on where you left off, or discard it.")
    }

    /// The running count. Zero reads differently from "3 steps" on purpose — an armed recorder that has
    /// caught nothing yet is the state somebody has to be able to recognise.
    func update(count: Int) {
        countLabel.stringValue = count == 0
            ? String(localized: "Recording — nothing yet")
            : String(localized: "Recording — \(count) steps")
    }

    @objc private func stopTapped() { onStop?() }
    @objc private func cancelTapped() { onCancel?() }

    /// What the indicator is showing, for an automation run to read back.
    func automationReport() -> String {
        "macro-recording-indicator=\(window?.isVisible == true ? "visible" : "hidden")\n"
            + "label=\(countLabel.stringValue)\n"
            + "resumed=\(resumed ? "yes" : "no")\n"
    }
}
