// SPDX-License-Identifier: Apache-2.0
// SyncStateSheetController.swift - What the app remembers about which pairs of folders, and how to
// make it forget.
//
// Two-way synchronisation only works because it remembers, and that memory is the one input the whole
// design is afraid of: a record that no longer describes the folders it names is how a run proposes
// deletions nobody asked for. There are guards against acting on a bad record — a deletion needs the
// other side to prove the absence, and a plan that would remove more than half the known paths is
// refused — but until now there was no way to *look* at what was kept, or to say "forget these two,
// start again".
//
// So this is a safety valve rather than housekeeping, and it is why nothing is reaped automatically:
// a folder on an unmounted disk does not exist right now, and throwing its history away would leave
// the pair silently unable to carry a deletion across the next time it is plugged in. Records go when
// a person says so, which means a person has to be able to see them.

import AppKit
import PCFoundation

final class SyncStateSheetController: NSWindowController {

    /// Called when anything was forgotten, so the window that opened this can re-read its own pair.
    var onChange: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let store: SyncStateStore
    /// The pair the window is showing, so its own record can be pointed out among the others.
    private let currentKey: String?
    private let table = NSTableView()
    private let forgetButton = NSButton()
    private let hint = NSTextField(wrappingLabelWithString: "")
    private var records: [SyncStateStore.Record] = []

    init(store: SyncStateStore, currentLeft: String?, currentRight: String?) {
        self.store = store
        self.currentKey = (currentLeft != nil && currentRight != nil)
            ? SyncState.key(leftRoot: currentLeft!, rightRoot: currentRight!)
            : nil
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 380),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.title = String(localized: "What Is Remembered")
        super.init(window: window)
        buildUI()
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func buildUI() {
        guard let window else { return }
        let content = NSView()

        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.stringValue = String(localized: "Two-way synchronisation uses these to tell a deletion from a new file. Forgetting a pair is safe: the next comparison then behaves like a first one and deletes nothing.")

        // 250 + 250 + 130 + 70 plus the spacing and the scroller fits inside 820 less the two
        // 16 pt insets; at 720 the last column's header read "Pf…", which is a column that might as
        // well not be there.
        for (id, title, width) in [("left", String(localized: "Left"), CGFloat(250)),
                                   ("right", String(localized: "Right"), CGFloat(250)),
                                   ("when", String(localized: "Last run"), CGFloat(130)),
                                   ("paths", String(localized: "Paths"), CGFloat(70))] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            column.title = title
            column.width = width
            table.addTableColumn(column)
        }
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 18
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = true
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        forgetButton.title = String(localized: "Forget")
        forgetButton.bezelStyle = .rounded
        forgetButton.target = self
        forgetButton.action = #selector(forgetSelected)
        forgetButton.isEnabled = false
        let close = NSButton(title: String(localized: "Close"), target: self, action: #selector(dismissSheet))
        close.bezelStyle = .rounded
        close.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [forgetButton, NSView(), close])
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false

        hint.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(hint)
        content.addSubview(scroll)
        content.addSubview(buttons)
        window.contentView = content
        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            hint.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            hint.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            scroll.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 12),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
        ])
    }

    private func reload() {
        records = store.records()
        table.reloadData()
        forgetButton.isEnabled = !table.selectedRowIndexes.isEmpty
    }

    @objc private func forgetSelected() {
        let chosen = table.selectedRowIndexes.compactMap { records.indices.contains($0) ? records[$0] : nil }
        guard !chosen.isEmpty else { return }
        // Asked, because it cannot be undone — the record is the only copy. Not a warning about
        // danger, though: forgetting is the *safe* direction, and the wording says so rather than
        // implying the user is about to break something.
        let alert = NSAlert()
        alert.messageText = String(localized: "Forget \(chosen.count) record(s)?")
        alert.informativeText = String(localized: "The next comparison of those folders will behave like a first one: it will copy differences and delete nothing, and then start remembering again.")
        alert.addButton(withTitle: String(localized: "Forget"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        for record in chosen { store.forget(key: record.key) }
        reload()
        // Told at once, not when the sheet closes. Measured: the window's own button went on saying
        // "Memory (2)" while nothing was remembered any more — a visible claim outliving its fact,
        // and this list exists precisely so that what the app remembers is legible.
        onChange?()
    }

    @objc private func dismissSheet() {
        // `onChange` has already fired for each forgetting; nothing more to report here.
        defer { onDismiss?() }
        guard let window else { return }
        if let parent = window.sheetParent { parent.endSheet(window) }
        else { NSApp.stopModal(); window.orderOut(nil) }
    }

    func present(over parent: NSWindow?) {
        guard let window else { return }
        if let parent, parent.isVisible {
            parent.beginSheet(window) { _ in }
        } else {
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.runModal(for: window)
        }
    }

    // MARK: - Automation (DEBUG)

    #if DEBUG
    func automationReport() -> String {
        var out = "records=\(records.count)\n"
        for record in records {
            let unreadable = record.header.version == 0
            out += "record=\(record.key) left=\(record.header.leftRoot)"
                + " right=\(record.header.rightRoot) paths=\(record.header.entryCount)"
                + " readable=\(!unreadable) current=\(record.key == currentKey)\n"
        }
        return out
    }

    func automationForgetAll() {
        for record in records { store.forget(key: record.key) }
        reload()
        onChange?()
    }

    /// Close the list. A scenario has to, or the app cannot quit — an open sheet holds it, which is
    /// the same trap the filter sheet's scenario ran into.
    func automationClose() { dismissSheet() }
    #endif
}

extension SyncStateSheetController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { records.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        guard records.indices.contains(row) else { return nil }
        let record = records[row]
        let unreadable = record.header.version == 0
        let field = NSTextField(labelWithString: "")
        field.isBordered = false
        field.drawsBackground = false
        field.font = Fonts.system13
        // Truncated in the middle, because the end of a path is what tells two of them apart. Cut
        // at the end, `/Users/me/Projects/…` and `/Users/me/Projects/…` are the same cell twice.
        field.lineBreakMode = .byTruncatingMiddle
        switch tableColumn?.identifier.rawValue {
        case "left":
            // An unreadable record has no roots to show, so it says what it *is* rather than showing
            // two empty cells and leaving the reader to guess why.
            field.stringValue = unreadable
                ? String(localized: "(unreadable — \(record.key))")
                : record.header.leftRoot
        case "right": field.stringValue = unreadable ? "" : record.header.rightRoot
        case "when":
            field.stringValue = unreadable ? "—"
                : Self.dateFormatter.string(from: record.header.runAt)
        case "paths": field.stringValue = unreadable ? "—" : "\(record.header.entryCount)"
            field.alignment = .right
        default: field.stringValue = ""
        }
        // The pair the window is showing, pointed out among the rest: it is the one the reader came
        // here about, and hunting for it among a hashed filename's worth of others is the whole
        // reason this list exists.
        if record.key == currentKey { field.font = NSFont.boldSystemFont(ofSize: 13) }
        if unreadable { field.textColor = .systemOrange }
        return field
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        forgetButton.isEnabled = !table.selectedRowIndexes.isEmpty
    }

    private static let dateFormatter =
        PanelDateFormatter.makeFormatter(pattern: PanelDateFormatter.defaultPattern)
}
