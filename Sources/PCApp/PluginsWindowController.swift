// SPDX-License-Identifier: Apache-2.0
// PluginsWindowController.swift - Plugins options page (I14 T05, F-235).
//
// Lists installed plugins (enabled checkbox, name, version, type, API version, path) with
// Install… / Remove. The window is dumb: the owner supplies rows and handles
// toggle/install/remove, then pushes a refreshed row set back.

import AppKit
import PCPluginHost

struct PluginRow {
    let name: String
    /// Stable key the host persists this plugin under; what toggle/remove report back (F-482).
    let identifier: String
    /// The plugin's own version, `major.minor.patch`.
    let version: String
    let type: String
    let apiVersion: Int
    let enabled: Bool
    let path: String
}

final class PluginsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    var onToggle: ((_ name: String, _ enabled: Bool) -> Void)?
    var onRemove: ((_ name: String) -> Void)?
    var onInstall: (() -> Void)?
    /// A file the user dropped on the window: a `.pcplug` package, a `.zip`, or a bundle folder.
    var onInstallFile: ((URL) -> Void)?
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
        let drop = PluginDropView(frame: window.contentLayoutRect)
        drop.onDrop = { [weak self] url in self?.onInstallFile?(url) }
        window.contentView = drop
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
        for (id, title, w) in [("enabled", "", CGFloat(28)), ("name", String(localized: "Name"), 150),
                               ("version", String(localized: "Version"), 64),
                               ("type", String(localized: "Type"), 56), ("api", "API", 40),
                               ("path", String(localized: "Path"), 280)] {
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

        emptyLabel.stringValue = String(localized: "No plugins installed. Use “Install…”, or drop a plugin package here.")
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(emptyLabel)

        let install = NSButton(title: String(localized: "Install…"), target: self, action: #selector(install))
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

    @objc private func install() { onInstall?() }

    @objc private func removeSelected() {
        let r = tableView.selectedRow
        guard r >= 0, r < rows.count else { NSSound.beep(); return }
        onRemove?(rows[r].identifier)
    }

    @objc private func toggleEnabled(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < rows.count else { return }
        onToggle?(rows[sender.tag].identifier, sender.state == .on)
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
        case "name":
            field.stringValue = r.name
            // The identifier is what the on/off state and the packer associations are stored
            // under, so it is the string somebody editing plugins.ini by hand needs to see.
            field.toolTip = r.identifier == r.name ? nil : r.identifier
        case "version": field.stringValue = r.version
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

/// The window's content view, which also accepts a dropped plugin.
///
/// Dropping the thing you just downloaded onto the window that lists plugins is the gesture
/// people try first, and it did nothing: the only way in was a file chooser behind a button.
/// The view accepts exactly what the installer accepts — a `.pcplug` package, a `.zip`, or an
/// unpacked `*.<type>plugin` bundle directory — and refuses everything else so the cursor says
/// no before the user lets go.
final class PluginDropView: NSView {
    var onDrop: ((URL) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func acceptableURL(_ sender: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                              options: options) as? [URL],
              urls.count == 1, let url = urls.first else { return nil }
        let ext = url.pathExtension.lowercased()
        if ext == "pcplug" || ext == "zip" { return url }
        return PluginHost.bundleExtensions.contains(ext) ? url : nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        acceptableURL(sender) != nil ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        acceptableURL(sender) != nil ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = acceptableURL(sender) else { return false }
        onDrop?(url)
        return true
    }
}
