// SPDX-License-Identifier: Apache-2.0
// PluginsWindowController.swift - Plugins options page (I14 T05, F-235).
//
// Lists installed plugins (enabled checkbox, name, type, API version, path) with
// Install from Folder… / Remove. The window is dumb: the owner supplies rows and
// handles toggle/install/remove, then pushes a refreshed row set back.

import AppKit

struct PluginRow {
    let name: String
    let type: String
    let apiVersion: Int
    let enabled: Bool
    let path: String
}

final class PluginsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    var onToggle: ((_ name: String, _ enabled: Bool) -> Void)?
    var onRemove: ((_ name: String) -> Void)?
    var onInstallFolder: (() -> Void)?
    var onClose: (() -> Void)?

    private var rows: [PluginRow] = []
    private let tableView = NSTableView()
    private let emptyLabel = NSTextField(labelWithString: "")

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "Plugins")
        super.init(window: window)
        window.delegate = self
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showWindow() {
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func setRows(_ rows: [PluginRow]) {
        self.rows = rows
        emptyLabel.isHidden = !rows.isEmpty
        tableView.reloadData()
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        for (id, title, w) in [("enabled", "", CGFloat(28)), ("name", String(localized: "Name"), 160),
                               ("type", String(localized: "Type"), 60), ("api", "API", 44),
                               ("path", String(localized: "Path"), 300)] {
            let col = NSTableColumn(identifier: .init(id)); col.title = title; col.width = w
            tableView.addTableColumn(col)
        }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 20
        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)

        emptyLabel.stringValue = String(localized: "No plugins installed. Use “Install from Folder…”.")
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(emptyLabel)

        let install = NSButton(title: String(localized: "Install from Folder…"), target: self, action: #selector(install))
        let remove = NSButton(title: String(localized: "Remove"), target: self, action: #selector(removeSelected))
        for b in [install, remove] { b.bezelStyle = .rounded }
        let bar = NSStackView(views: [install, remove])
        bar.orientation = .horizontal
        bar.spacing = 8
        bar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(bar)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            scroll.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -8),
            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            bar.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10),
        ])
    }

    @objc private func install() { onInstallFolder?() }

    @objc private func removeSelected() {
        let r = tableView.selectedRow
        guard r >= 0, r < rows.count else { NSSound.beep(); return }
        onRemove?(rows[r].name)
    }

    @objc private func toggleEnabled(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < rows.count else { return }
        onToggle?(rows[sender.tag].name, sender.state == .on)
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let r = rows[row]
        if tableColumn?.identifier.rawValue == "enabled" {
            let box = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleEnabled(_:)))
            box.tag = row
            box.state = r.enabled ? .on : .off
            return box
        }
        let id = NSUserInterfaceItemIdentifier("c")
        let field = (tableView.makeView(withIdentifier: id, owner: self) as? NSTextField)
            ?? { let f = NSTextField(labelWithString: ""); f.identifier = id; f.isBordered = false; f.drawsBackground = false; return f }()
        switch tableColumn?.identifier.rawValue {
        case "name": field.stringValue = r.name
        case "type": field.stringValue = r.type
        case "api": field.stringValue = "\(r.apiVersion)"
        default: field.stringValue = r.path
        }
        field.textColor = r.enabled ? .labelColor : .tertiaryLabelColor
        return field
    }
}

extension PluginsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) { onClose?() }
}
