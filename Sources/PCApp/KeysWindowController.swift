// SPDX-License-Identifier: Apache-2.0
// KeysWindowController.swift - Keyboard shortcut editor (I13 T06, F-254).
//
// A grid of commands with their current shortcut. Selecting a row and pressing
// "Record…" captures the next chord and assigns it (reporting any command it
// displaces). "Clear" suppresses the command's shortcut; "Restore Defaults" drops
// all user overrides. Changes are applied/persisted immediately by the owner.

import AppKit
import PCFoundation

struct KeyBindingRow {
    let command: String
    let category: String
    let spec: String        // current chord spec, "" if unbound
    let implemented: Bool
}

final class KeysWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    /// Assign `chord` to the command; returns the command it displaced, if any.
    var onAssign: ((_ command: String, _ chord: KeyChord) -> String?)?
    var onClear: ((_ command: String) -> Void)?
    var onRestoreDefaults: (() -> Void)?
    var rowsProvider: (() -> [KeyBindingRow])?
    var onClose: (() -> Void)?

    private var all: [KeyBindingRow] = []
    private var shown: [KeyBindingRow] = []
    private let searchField = NSSearchField()
    private let tableView = NSTableView()

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 500),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "Keyboard Shortcuts")
        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showWindow() {
        reloadRows()
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func reloadRows() {
        all = (rowsProvider?() ?? []).sorted { $0.command < $1.command }
        applyFilter()
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = String(localized: "Search commands…")
        searchField.target = self
        searchField.action = #selector(searchChanged)
        content.addSubview(searchField)

        for (id, title, w) in [("cmd", String(localized: "Command"), CGFloat(240)),
                               ("cat", String(localized: "Category"), 120),
                               ("key", String(localized: "Shortcut"), 200)] {
            let col = NSTableColumn(identifier: .init(id)); col.title = title; col.width = w
            tableView.addTableColumn(col)
        }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 18
        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)

        let record = NSButton(title: String(localized: "Record…"), target: self, action: #selector(recordShortcut))
        let clear = NSButton(title: String(localized: "Clear"), target: self, action: #selector(clearShortcut))
        let restore = NSButton(title: String(localized: "Restore Defaults"), target: self, action: #selector(restoreDefaults))
        for b in [record, clear, restore] { b.bezelStyle = .rounded }
        let buttons = NSStackView(views: [record, clear, restore])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            searchField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            scroll.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -8),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10),
        ])
    }

    @objc private func searchChanged() { applyFilter() }

    private func applyFilter() {
        let q = searchField.stringValue.lowercased()
        shown = q.isEmpty ? all : all.filter {
            $0.command.lowercased().contains(q) || $0.category.lowercased().contains(q) || $0.spec.lowercased().contains(q)
        }
        tableView.reloadData()
    }

    private var selectedCommand: String? {
        let r = tableView.selectedRow
        return (r >= 0 && r < shown.count) ? shown[r].command : nil
    }

    /// The capture sheet while it is up.
    ///
    /// Held, because nothing else does. `NSWindowController` retains its window, but a window does
    /// *not* retain its controller, and `beginSheet` retains only the panel — so a controller kept
    /// in a local deallocated the moment `recordShortcut` returned, leaving the sheet on screen with
    /// its key handler gone. The panel looked fine and answered nothing, Esc included.
    private var capture: KeyCaptureController?

    @objc private func recordShortcut() {
        guard let command = selectedCommand else { NSSound.beep(); return }
        guard let window else { return }
        let capture = KeyCaptureController(command: command)
        capture.onCaptured = { [weak self] chord in
            guard let self else { return }
            let displaced = self.onAssign?(command, chord)
            if let displaced, displaced != command {
                let alert = NSAlert()
                alert.messageText = String(localized: "Shortcut reassigned")
                alert.informativeText = String(localized: "\(chord.spec) was taken from \(displaced) and is now bound to \(command).")
                alert.runModal()
            }
            self.reloadRows()
        }
        self.capture = capture     // before presenting: the sheet must never be the only owner
        capture.beginSheet(over: window) { [weak self] in self?.capture = nil }
    }

    @objc private func clearShortcut() {
        guard let command = selectedCommand else { NSSound.beep(); return }
        onClear?(command)
        reloadRows()
    }

    @objc private func restoreDefaults() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Restore default shortcuts?")
        alert.informativeText = String(localized: "This removes all your keyboard overrides.")
        alert.addButton(withTitle: String(localized: "Restore"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        onRestoreDefaults?()
        reloadRows()
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { shown.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let r = shown[row]
        let id = NSUserInterfaceItemIdentifier("c")
        let field = (tableView.makeView(withIdentifier: id, owner: self) as? NSTextField)
            ?? { let f = NSTextField(labelWithString: ""); f.identifier = id; f.isBordered = false; f.drawsBackground = false; return f }()
        switch tableColumn?.identifier.rawValue {
        case "cmd": field.stringValue = r.command
        case "cat": field.stringValue = r.category
        default: field.stringValue = r.spec
        }
        field.textColor = r.implemented ? .labelColor : .tertiaryLabelColor
        return field
    }
}

extension KeysWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) { onClose?() }
}

/// A tiny sheet that captures the next key chord.
private final class KeyCaptureController: NSWindowController {
    var onCaptured: ((KeyChord) -> Void)?
    private let command: String

    init(command: String) {
        self.command = command
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 120),
                            styleMask: [.titled], backing: .buffered, defer: false)
        super.init(window: panel)
        let label = NSTextField(labelWithString: String(localized: "Press the new shortcut for \(command)…\n(Esc to cancel)"))
        label.alignment = .center
        label.maximumNumberOfLines = 3
        let capture = KeyCaptureView()
        capture.onKey = { [weak self] event in self?.handle(event) }
        capture.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(label)
        panel.contentView?.addSubview(capture)
        if let cv = panel.contentView {
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: cv.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: cv.centerYAnchor),
                capture.topAnchor.constraint(equalTo: cv.topAnchor),
                capture.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
                capture.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
                capture.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            ])
        }
        self.captureView = capture
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private weak var captureView: KeyCaptureView?
    private weak var hostWindow: NSWindow?

    /// Present the sheet and start listening. `onFinish` runs when it closes, whichever way — the
    /// owner releases this controller there.
    func beginSheet(over window: NSWindow, onFinish: @escaping () -> Void) {
        guard let panel = self.window else { return }
        hostWindow = window
        // Both: `initialFirstResponder` is what AppKit consults when the sheet becomes key, and the
        // explicit call covers the case where it is key already. A capture view that is not the
        // first responder receives no keyDown, which looks exactly like the defect above.
        panel.initialFirstResponder = captureView
        window.beginSheet(panel) { _ in onFinish() }
        panel.makeFirstResponder(captureView)
    }

    private func handle(_ event: NSEvent) {
        // The sheet goes away *before* the key is reported, not after. What follows can be
        // app-modal — reassigning a chord that was taken puts up an alert — and running that from
        // inside the handler left this sheet standing behind it, still asking for a key that had
        // already been pressed.
        let captured = onCaptured
        end()
        // Esc cancels.
        if event.keyCode == 53 { return }
        if let chord = KeymapMenu.chord(from: event) { captured?(chord) }
    }

    private func end() {
        guard let panel = window else { return }
        hostWindow?.endSheet(panel)
    }
}

private final class KeyCaptureView: NSView {
    var onKey: ((NSEvent) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) { onKey?(event) }

    /// Claim key equivalents too, so a ⌘ chord can be recorded at all.
    ///
    /// A key equivalent is offered to the key window's view hierarchy before the main menu, and
    /// this app's menu is full of ⌘ shortcuts — so without this, pressing ⌘C while recording runs
    /// Copy instead of being recorded, and the sheet sits there waiting for a key it will never be
    /// given. Only while this view is the one listening; a sheet that has lost focus must not be
    /// swallowing the menu's keys.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return false }
        onKey?(event)
        return true
    }
}
