// SPDX-License-Identifier: Apache-2.0
// HotlistManagerWindowController.swift - Organize the directory hotlist (F-061).
//
// A table of the hotlist bookmarks with inline-editable Title and Path columns
// plus Add / Add Separator / Remove / Move Up / Move Down. A title may contain
// backslashes to nest the entry under submenus ("Work\ProjectA"); a title of "-"
// is a separator. "Done" hands the reordered/renamed list back to the caller.

import AppKit
import PCFoundation

final class HotlistManagerWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate,
                                            NSTextFieldDelegate {
    /// Called on Done with the edited entries.
    var onSave: (([HotlistEntry]) -> Void)?

    private var entries: [HotlistEntry]
    private let table = NSTableView()

    init(entries: [HotlistEntry]) {
        self.entries = entries
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "Organize Hotlist")
        super.init(window: window)
        buildUI()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let titleCol = NSTableColumn(identifier: .init("title"))
        titleCol.title = String(localized: "Title (use \\ for submenus, - for separator)")
        titleCol.width = 220
        let pathCol = NSTableColumn(identifier: .init("path"))
        pathCol.title = String(localized: "Path")
        pathCol.width = 260
        table.addTableColumn(titleCol)
        table.addTableColumn(pathCol)
        table.dataSource = self
        table.delegate = self
        table.setAccessibilityLabel(String(localized: "Favorites"))
        table.usesAlternatingRowBackgroundColors = true
        table.allowsEmptySelection = true

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)

        func button(_ title: String, _ action: Selector) -> NSButton {
            let b = NSButton(title: title, target: self, action: action)
            b.bezelStyle = .rounded
            return b
        }
        let toolbar = NSStackView(views: [
            button(String(localized: "Add"), #selector(addEntry)),
            button(String(localized: "Add Separator"), #selector(addSeparator)),
            button(String(localized: "Remove"), #selector(removeEntry)),
            button(String(localized: "Move Up"), #selector(moveEntryUp)),
            button(String(localized: "Move Down"), #selector(moveEntryDown)),
        ])
        toolbar.orientation = .horizontal
        toolbar.spacing = 8
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(toolbar)

        let done = button(String(localized: "Done"), #selector(saveAndClose))
        done.keyEquivalent = "\r"
        let cancel = button(String(localized: "Cancel"), #selector(cancel))
        cancel.keyEquivalent = "\u{1b}"
        let bottom = NSStackView(views: [cancel, done])
        bottom.orientation = .horizontal
        bottom.spacing = 10
        bottom.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(bottom)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            toolbar.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 10),
            toolbar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            bottom.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 12),
            bottom.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            bottom.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])
    }

    // MARK: - Table data / editable cells

    func numberOfRows(in tableView: NSTableView) -> Int { entries.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn, entries.indices.contains(row) else { return nil }
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.isEditable = true
        field.delegate = self
        field.tag = row * 2 + (column.identifier.rawValue == "title" ? 0 : 1)
        field.stringValue = column.identifier.rawValue == "title" ? entries[row].title : entries[row].path
        return field
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        let row = field.tag / 2, isTitle = field.tag % 2 == 0
        guard entries.indices.contains(row) else { return }
        if isTitle {
            entries[row] = HotlistEntry(title: field.stringValue, path: entries[row].path)
        } else {
            entries[row] = HotlistEntry(title: entries[row].title, path: field.stringValue)
        }
    }

    // MARK: - Actions

    @objc private func addEntry() {
        entries.append(HotlistEntry(title: String(localized: "New Bookmark"), path: NSHomeDirectory()))
        table.reloadData()
        table.selectRowIndexes([entries.count - 1], byExtendingSelection: false)
    }

    @objc private func addSeparator() {
        entries.append(HotlistEntry(title: "-", path: ""))
        table.reloadData()
    }

    @objc private func removeEntry() {
        let row = table.selectedRow
        guard entries.indices.contains(row) else { return }
        entries.remove(at: row)
        table.reloadData()
    }

    @objc private func moveEntryUp() { move(by: -1) }
    @objc private func moveEntryDown() { move(by: 1) }

    private func move(by delta: Int) {
        let row = table.selectedRow
        let dest = row + delta
        guard entries.indices.contains(row), entries.indices.contains(dest) else { return }
        entries.swapAt(row, dest)
        table.reloadData()
        table.selectRowIndexes([dest], byExtendingSelection: false)
    }

    @objc private func saveAndClose() {
        window?.makeFirstResponder(nil)   // commit any in-progress cell edit
        onSave?(entries)
        close()
    }

    @objc private func cancel() { close() }
}
