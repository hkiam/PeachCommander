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

/// Give a list's width to its flexible columns in their declared proportions, so the list always fills
/// its pane. `preferred` names the flexible columns and their weights; any other column keeps its width,
/// and a hidden one counts for nothing.
///
/// AppKit's autoresizing styles did not do this: measured, a table already wider than its clip view — the
/// log window's commit list opens 824 points wide in a 442-point pane — is left alone when the pane grows,
/// so in a 1373-point window it was still 824 inside 729, the date column cut off at the edge; and
/// `sizeToFit` under `.uniform` shares space *equally*, which made the date column as wide as the subject.
/// Below the minimums the list scrolls horizontally rather than clipping.
///
/// Call it from the clip view's own frame change, not from the container's `layout()`: the scroll view
/// tiles after its container has laid out, so there the clip still had its old width, and a stale table
/// frame turned the difference into columns pinned at their minimums. `tile()` first for the same
/// reason — a column width set without it leaves the frame from before. The table's
/// `columnAutoresizingStyle` must be `.noColumnAutoresizing`, or AppKit fights it.
@MainActor
func gitFitColumns(_ table: NSTableView, preferred: [NSUserInterfaceItemIdentifier: CGFloat]) {
    guard let clip = table.enclosingScrollView?.contentView, clip.bounds.width > 0 else { return }
    table.tile()
    // What the columns occupy, not the table's frame: without autoresizing the frame never gets narrower
    // than the clip, so it cannot say that the columns stop short of the edge. The leading inset is
    // counted once more for the trailing one.
    let visible = table.tableColumns.indices.filter { !table.tableColumns[$0].isHidden }
    guard let first = visible.first, let last = visible.last else { return }
    let used = table.rect(ofColumn: last).maxX + table.rect(ofColumn: first).minX
    let delta = clip.bounds.width - used
    guard abs(delta) > 0.5 else { return }
    let flexible = table.tableColumns.filter { !$0.isHidden && preferred[$0.identifier] != nil }
    var target = flexible.reduce(0) { $0 + $1.width } + delta
    // A column whose share falls below its minimum takes the minimum, and the rest is shared again among
    // the others — otherwise the clamped ones overflow the pane while the subject stays wide.
    var open = flexible
    var settled = false
    while !settled {
        settled = true
        let weight = open.reduce(0) { $0 + (preferred[$1.identifier] ?? 0) }
        guard weight > 0 else { break }
        for column in open where target * (preferred[column.identifier] ?? 0) / weight < column.minWidth {
            column.width = column.minWidth
            target -= column.minWidth
            open.removeAll { $0 === column }
            settled = false
        }
        if settled {
            for column in open {
                column.width = (target * (preferred[column.identifier] ?? 0) / weight).rounded(.down)
            }
        }
    }
}

/// A column the reader dragged makes the current widths the proportions `gitFitColumns` keeps — otherwise
/// the next window resize put every column back to its declared share and undid the drag. Only a drag
/// counts: the header names the column being resized while the reader drags it, and nothing while
/// `gitFitColumns` sets widths itself.
@MainActor
func gitAdoptDraggedWidths(_ table: NSTableView, preferred: inout [NSUserInterfaceItemIdentifier: CGFloat]) {
    guard let header = table.headerView, header.resizedColumn >= 0 else { return }
    for column in table.tableColumns where preferred[column.identifier] != nil {
        preferred[column.identifier] = column.width
    }
}

/// Dates as the plugin's lists and detail views show them: medium date, short time, the reader's locale.
@MainActor
let gitDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
}()

/// A spinner that several loads can share: it spins while any of them is running. Starting and stopping a
/// plain NSProgressIndicator is not counted, so the first load to finish stopped it while the panel's
/// Changes tab was still reading its diff. Every start must be paired with exactly one stop.
@MainActor
final class GitBusyIndicator: NSProgressIndicator {
    private var running = 0

    override func startAnimation(_ sender: Any?) {
        running += 1
        if running == 1 { super.startAnimation(sender) }
    }

    override func stopAnimation(_ sender: Any?) {
        guard running > 0 else { return }
        running -= 1
        if running == 0 { super.stopAnimation(sender) }
    }
}
