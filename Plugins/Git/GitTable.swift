// SPDX-License-Identifier: Apache-2.0
// GitTable.swift — the two interactions every list in this plugin was missing (F-424).
//
// A review of the plugin's own windows found no context menu in any of its six views and no keyboard
// handling at all: every action needed the mouse, and it needed the *right* button, which in a file
// manager is where a right-click is expected first. Two behaviours cover almost all of it, and both belong
// to the table rather than to each window:
//
//   * **Right-click selects the row under the cursor, then opens the menu.** Without that, the menu acts on
//     whatever was selected before — the classic "I right-clicked *that* commit and it reverted this one".
//   * **Return runs the primary action**, the same one a double-click runs, so a list that is navigated with
//     the arrow keys can be used without reaching for the mouse at all.
//
// `Cmd+R` is deliberately *not* here: reloading is a property of the window, not of a list, and the views
// implement it in `performKeyEquivalent` where the shortcut works no matter which control has focus.

import AppKit

/// A table that selects what was right-clicked and treats Return as its double-click.
@MainActor
final class GitTable: NSTableView {
    /// Return / keypad Enter. nil leaves the key to the responder chain.
    var onEnter: (() -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        if row >= 0, !selectedRowIndexes.contains(row) {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        return super.menu(for: event)
    }

    override func keyDown(with event: NSEvent) {
        // 36 = Return, 76 = keypad Enter. Compared by key code rather than by characters, because a
        // keyboard layout may put something else on that key and the *key* is what the reader pressed.
        if event.keyCode == 36 || event.keyCode == 76, let onEnter {
            onEnter()
            return
        }
        super.keyDown(with: event)
    }
}

/// The same two behaviours for the panel's grouped list, which is an outline rather than a table.
@MainActor
final class GitOutline: NSOutlineView {
    var onEnter: (() -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        if row >= 0, !selectedRowIndexes.contains(row) {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        return super.menu(for: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76, let onEnter {
            onEnter()
            return
        }
        super.keyDown(with: event)
    }
}

/// Build a context menu from (title, selector) pairs; nil title means a separator.
@MainActor
func gitMenu(_ items: [(String?, Selector?)], target: AnyObject) -> NSMenu {
    let menu = NSMenu()
    for (title, selector) in items {
        guard let title, let selector else { menu.addItem(.separator()); continue }
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = target
        menu.addItem(item)
    }
    return menu
}

/// Put text on the clipboard — "copy the hash" is the smallest thing a history window is asked for and the
/// one this plugin had no answer to.
@MainActor
func gitCopyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}
