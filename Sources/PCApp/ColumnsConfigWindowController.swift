// SPDX-License-Identifier: Apache-2.0
// ColumnsConfigWindowController.swift - Configure the panel's visible columns.
//
// Lists every available field (built-in + enabled plugin content fields) as a
// reorderable row with a "show" checkbox and an editable width. OK produces the
// ordered set of shown columns; the owner persists it (global column set) and
// applies it to both panels. Global scope for v1 (see
// docs/plugin-contribution-architecture.md).

import AppKit
import PCFoundation

@MainActor
final class ColumnsConfigWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    var onApply: (([ColumnSpec]) -> Void)?
    var onClose: (() -> Void)?

    private struct Row { var spec: ColumnSpec; var visible: Bool }
    private var rows: [Row]
    private let table = NSTableView()

    /// `available` = every field the user may show; `current` = the currently
    /// shown columns in order (their widths seed the editor); `sideLabel` names the
    /// panel being configured ("Left"/"Right").
    init(available: [ColumnSpec], current: [ColumnSpec], sideLabel: String = "") {
        // Shown columns first (in order), then the rest (hidden), de-duplicated by fieldID.
        var rows: [Row] = current.map { Row(spec: $0, visible: true) }
        let shown = Set(current.map(\.fieldID))
        for spec in available where !shown.contains(spec.fieldID) {
            rows.append(Row(spec: spec, visible: false))
        }
        self.rows = rows
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = sideLabel.isEmpty ? "Columns" : "Columns — \(sideLabel) Panel"
        super.init(window: window)
        window.center()
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showWindow() { showWindow(nil); window?.makeKeyAndOrderFront(nil) }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        for (id, title, w) in [("show", "Show", CGFloat(50)), ("title", "Column", 250), ("width", "Width", 80)] {
            let col = NSTableColumn(identifier: .init(id)); col.title = title; col.width = w
            table.addTableColumn(col)
        }
        table.dataSource = self
        table.delegate = self
        table.allowsColumnResizing = false
        let scroll = NSScrollView(); scroll.documentView = table; scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)

        let up = NSButton(title: String(localized: "Move Up"), target: self, action: #selector(moveRowUp))
        let down = NSButton(title: String(localized: "Move Down"), target: self, action: #selector(moveRowDown))
        let cancel = NSButton(title: String(localized: "Cancel"), target: self, action: #selector(cancel))
        cancel.keyEquivalent = "\u{1b}"
        let ok = NSButton(title: String(localized: "OK"), target: self, action: #selector(apply))
        ok.keyEquivalent = "\r"
        for b in [up, down, cancel, ok] { b.bezelStyle = .rounded }
        let moveStack = NSStackView(views: [up, down]); moveStack.spacing = 8
        let okStack = NSStackView(views: [cancel, ok]); okStack.spacing = 10
        let bar = NSStackView(views: [moveStack, NSView(), okStack])
        bar.orientation = .horizontal; bar.distribution = .fill
        bar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(bar)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            bar.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 12),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            bar.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
        ])
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let colID = tableColumn?.identifier.rawValue, rows.indices.contains(row) else { return nil }
        switch colID {
        case "show":
            let b = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleShow(_:)))
            b.state = rows[row].visible ? .on : .off
            b.tag = row
            return b
        case "width":
            let f = NSTextField(string: String(rows[row].spec.width))
            f.tag = row; f.target = self; f.action = #selector(widthChanged(_:))
            f.alignment = .right; f.isBordered = true; f.isEditable = true
            return f
        default:
            return NSTextField(labelWithString: rows[row].spec.title)
        }
    }

    @objc private func toggleShow(_ sender: NSButton) {
        guard rows.indices.contains(sender.tag) else { return }
        rows[sender.tag].visible = sender.state == .on
    }

    @objc private func widthChanged(_ sender: NSTextField) {
        guard rows.indices.contains(sender.tag), let w = Int(sender.stringValue), w >= 30 else { return }
        let old = rows[sender.tag].spec
        rows[sender.tag].spec = ColumnSpec(fieldID: old.fieldID, title: old.title, width: w, alignment: old.alignment)
    }

    private func move(_ delta: Int) {
        let r = table.selectedRow
        let target = r + delta
        guard rows.indices.contains(r), rows.indices.contains(target) else { return }
        rows.swapAt(r, target)
        table.reloadData()
        table.selectRowIndexes([target], byExtendingSelection: false)
    }
    @objc private func moveRowUp() { move(-1) }
    @objc private func moveRowDown() { move(1) }

    @objc private func apply() {
        onApply?(rows.filter(\.visible).map(\.spec))
        dismissSelf()
    }
    @objc private func cancel() { dismissSelf() }

    private func dismissSelf() { window?.orderOut(nil); onClose?() }
}
