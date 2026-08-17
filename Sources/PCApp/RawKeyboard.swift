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
// Menu key equivalents used not to be covered here at all, on the grounds that they are matched before
// the responder chain and that this is correct macOS behaviour: ⌘-anything bound in the menu bar
// reaches the menu rather than the focused view, exactly as ⌘W closes a Terminal.app tab. That
// reasoning holds for ⌘ chords and breaks for *bare* ones, which this app has — the keymap binds
// `DELETE=cm_Delete`, and `KeymapMenu.apply` puts it on File ▸ Delete as a modifier-less accelerator.
// A bare accelerator is matched app-wide before any keystroke reaches a text field, so pressing Del
// while typing in the Find dialog asked to move the panel's file to the Trash. `menuMayClaim` below is
// the rule for that case.

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
    static let reservedCommands: Set<String> = ["cm_TerminalFocus"]

    /// May the menu bar claim this key event, or was it aimed at something else?
    ///
    /// Only bare keystrokes are in question. A chord with ⌘/⌃/⌥ belongs to the menu wherever it is
    /// pressed — that is macOS, and changing it would be the surprise. A key with none of those is what
    /// a person is typing, and this app puts file commands on such keys: Del deletes, F5 copies, F7
    /// makes a folder. Two things then have to be true before the menu bar may act on one.
    ///
    /// **The keystroke must have been aimed at the file manager.** These commands work on the panels of
    /// the main window; while a dialog, an inspector or a tool window is key, the person is looking
    /// somewhere else entirely and the panel behind it is not what they are pressing keys at. This is the
    /// half that made the reported defect dangerous: any text field in any window of the app could ask
    /// for a file to be deleted.
    ///
    /// **The keystroke must not be one the focused thing is typing.** Inside the file manager the same
    /// `wantsRaw` rule as everywhere else applies — with one deliberate exception, the function keys.
    /// F1–F12 are not typing keys, and a file manager whose F5 stops copying because the cursor happens
    /// to sit in the command line has lost the property that makes it one. So Del, Backspace, Return and
    /// the arrows stay with the text; the function keys still reach the panels.
    ///
    /// - Parameters:
    ///   - keyWindowIsFileManager: is the key window the one that owns the file panels?
    ///   - responder: the key window's first responder.
    ///   - rawViews: mounted plugin views whose manifest declares `rawKeyboard`.
    static func menuMayClaim(_ event: NSEvent, keyWindowIsFileManager: Bool,
                             firstResponder responder: NSResponder?, rawViews: [NSView]) -> Bool {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return true }
        guard keyWindowIsFileManager else { return false }
        if isFunctionKey(event) { return true }
        return !wantsRaw(event, firstResponder: responder, rawViews: rawViews)
    }

    /// F1…F12 — the same range `KeymapMenu` uses when it turns an event into a key token.
    private static func isFunctionKey(_ event: NSEvent) -> Bool {
        guard let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first else { return false }
        return (0xF704...0xF70F).contains(scalar.value)
    }

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
