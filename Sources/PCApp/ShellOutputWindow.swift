// SPDX-License-Identifier: Apache-2.0
// ShellOutputWindow.swift - Shows captured output of a command-line run (I06-T05).

import AppKit
import PCFoundation

@MainActor
final class ShellOutputWindow: NSWindowController {
    init(command: String, output: String) {
        let window = NSWindow(
            contentRect: NSMakeRect(0, 0, 640, 360),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = command
        window.center()
        super.init(window: window)

        let scroll = NSScrollView(frame: window.contentView?.bounds ?? .zero)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        let text = NSTextView(frame: scroll.bounds)
        text.isEditable = false
        text.font = Fonts.monospacedDigit13
        text.string = output
        text.autoresizingMask = [.width]
        scroll.documentView = text
        window.contentView?.addSubview(scroll)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
