// SPDX-License-Identifier: Apache-2.0
// RawKeyboard.swift - Who gets a key press: the focused view, or the file manager (F-381).
//
// `performKeyEquivalent` is broadcast to *every* view in the window, not just the focused one. The
// file panel takes advantage of that to claim F-keys and Ctrl combinations wherever the cursor is,
// which is the whole point of a Total Commander keyboard — and it is also why the panel used to
// swallow ⌘C while the user was typing in the command line. `PanelListView` carries the note:
//
// > performKeyEquivalent is broadcast to every view in the window, so the panel would otherwise
// > swallow Cmd+C/V/X/A (mapped to file-clipboard commands) even while the user is typing in the
// > command line.
//
// The fix at the time was `window?.firstResponder is NSText`, and it was a fix for one instance
// rather than for the class. Anything focusable that is not an `NSText` walks straight back into the
// defect: a terminal view would have F5 taken by "copy files" and ⌃B by the directory branch, both
// while the user was aiming at whatever was running inside it.
//
// So the question stops being "is a text field focused" and becomes "does the focused thing want this
// key untouched". Two kinds of thing can answer.
//
// **Built-ins** adopt `RawKeyboardConsumer` and may answer per event — a view can want the arrow keys
// and not want ⌘F. Text editors need no adoption: an `NSText` being edited always wants its keys, and
// treating it as a special case here rather than at three call sites is most of what this file buys.
//
// **Plugin views** cannot adopt anything: they arrive as an `NSView*` across a C ABI and know nothing
// of the app's Swift protocols. They declare `rawKeyboard` in their manifest instead, and the host
// resolves the focused responder up its view hierarchy to see whether it lands inside one of them.
//
// What this deliberately does *not* cover: menu key equivalents. Those are matched before the
// responder chain, so ⌘-anything bound in the menu bar reaches the menu rather than the focused view.
// That is correct macOS behaviour and it is what Terminal.app does as well — ⌘W closes the tab, and a
// program wanting ⌘W inside a terminal does not get it there either.

import AppKit

/// A view that consumes key events itself, so the host must not turn them into commands.
///
/// Per event rather than a flag: a view may want the arrows and not ⌘F, and being asked about the
/// specific press is the difference between "this view is special" and "this key is".
@MainActor
protocol RawKeyboardConsumer: AnyObject {
    func wantsRawKeyEvent(_ event: NSEvent) -> Bool
}

@MainActor
enum RawKeyboard {

    /// Commands a focused view may never take, however raw it wants its keyboard.
    ///
    /// A view that claims every key and contains the only way out of itself is a trap: the terminal
    /// declares `rawKeyboard`, so without this the key that moves focus back to the file panels is
    /// swallowed by the terminal and there is no keyboard route out of it at all. Measured — the
    /// toggle simply did nothing while the terminal had focus.
    ///
    /// Deliberately tiny. Every entry here is a key taken away from whatever is focused, which is the
    /// opposite of what `rawKeyboard` is for, so the bar is "without it the user is stuck".
    static let reservedCommands: Set<String> = ["cm_ToggleDock"]

    /// Should this key event be left to the focused view rather than routed to a command?
    ///
    /// - Parameters:
    ///   - responder: the window's first responder.
    ///   - rawViews: mounted plugin views whose manifest declares `rawKeyboard`.
    static func wantsRaw(_ event: NSEvent, firstResponder responder: NSResponder?,
                         rawViews: [NSView]) -> Bool {
        guard let responder else { return false }

        // A text object being edited gets everything. This is the case the old special case covered,
        // and it stays first because it is by far the most common.
        if responder is NSText { return true }

        // A built-in that answers for itself.
        if let consumer = responder as? RawKeyboardConsumer, consumer.wantsRawKeyEvent(event) {
            return true
        }

        guard let view = responder as? NSView else { return false }

        // Walk up: the focused thing is usually a subview several levels inside whatever declared
        // itself. A plugin's terminal view is the plugin's own class and the host holds only the root
        // NSView it was handed, so asking the focused view alone would always answer no.
        var node: NSView? = view
        while let current = node {
            if let consumer = current as? RawKeyboardConsumer, consumer.wantsRawKeyEvent(event) {
                return true
            }
            if rawViews.contains(where: { $0 === current }) { return true }
            node = current.superview
        }
        return false
    }
}
