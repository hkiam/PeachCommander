// SPDX-License-Identifier: Apache-2.0
// DockerTextWindow.swift — the window the container actions answer into.
//
// Inspect, Logs and Mounts all produce a block of text that wants scrolling and selecting, which is
// three things `presentInfo` is not: it is an `NSAlert`, it runs modal (and so would hang an
// automation run from inside a file operation), and an alert with four hundred lines of JSON in it
// is a wall. `contrib.h` says a command "may open its own windows"; this is that window, and one
// class serves all three because the only difference between them is the text.

import AppKit

/// A read-only, monospaced text window the plugin owns.
final class DockerTextWindow: NSObject, NSWindowDelegate {
    /// Every window currently open. AppKit does not retain a window for us — a programmatically
    /// created one is released when it closes — so the plugin holds them here and lets go in
    /// `windowWillClose`. Without it the window is freed while its delegate still points at it.
    private nonisolated(unsafe) static var open: [DockerTextWindow] = []

    private let window: NSWindow

    /// Show `text` in a window titled `title`, with `subtitle` above it for the thing it is about.
    static func show(title: String, subtitle: String, text: String) {
        let made = DockerTextWindow(title: title, subtitle: subtitle, text: text)
        open.append(made)
        made.window.makeKeyAndOrderFront(nil)
    }

    private init(title: String, subtitle: String, text: String) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init()
        window.title = title
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        build(subtitle: subtitle, text: text)
    }

    private func build(subtitle: String, text: String) {
        guard let content = window.contentView else { return }

        let caption = NSTextField(labelWithString: subtitle)
        caption.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        caption.textColor = .secondaryLabelColor
        caption.lineBreakMode = .byTruncatingMiddle
        caption.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(caption)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = false
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let view = NSTextView()
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = false
        view.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        // Horizontal scrolling rather than wrapping: a line of JSON or a log line means more with its
        // structure intact, and the scroller is there.
        view.isHorizontallyResizable = true
        view.textContainer?.widthTracksTextView = false
        let unbounded = CGFloat.greatestFiniteMagnitude
        view.textContainer?.containerSize = NSSize(width: unbounded, height: unbounded)
        view.maxSize = NSSize(width: unbounded, height: unbounded)
        view.string = text
        scroll.documentView = view
        content.addSubview(scroll)

        NSLayoutConstraint.activate([
            caption.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            caption.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            caption.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            scroll.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])
    }

    func windowWillClose(_ notification: Notification) {
        Self.open.removeAll { $0 === self }
    }
}
