// CommandBrowserWindowController.swift - Searchable command list (I13 T01, F-255).
//
// Lists every registered command (name, category, help) with a live search filter.
// Double-click or Run executes the selected command through the owner. Not-yet-
// implemented commands are shown greyed. This is the standalone browser; the same
// list will back the toolbar/keymap/Start-menu editors' "choose command" pickers.

import AppKit

struct CommandRow {
    let name: String
    let category: String
    let help: String
    let implemented: Bool
}

final class CommandBrowserWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    var onRun: ((String) -> Void)?
    var onClose: (() -> Void)?

    private let all: [CommandRow]
    private var shown: [CommandRow]
    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let runButton = NSButton(title: "", target: nil, action: nil)

    /// The confirm-button title ("Run" for the standalone browser, "Choose" when
    /// used as a picker in an editor — F-255).
    private let runTitle: String

    init(commands: [CommandRow], runButtonTitle: String? = nil) {
        self.all = commands.sorted { $0.name < $1.name }
        self.shown = self.all
        self.runTitle = runButtonTitle ?? String(localized: "Run")
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "Command Browser")
        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showWindow() {
        tableView.reloadData()
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = String(localized: "Search commands…")
        searchField.target = self
        searchField.action = #selector(searchChanged)
        content.addSubview(searchField)

        for (id, title, width) in [("name", String(localized: "Name"), CGFloat(210)),
                                   ("category", String(localized: "Category"), 120),
                                   ("help", String(localized: "Description"), 280)] {
            let col = NSTableColumn(identifier: .init(id))
            col.title = title
            col.width = width
            tableView.addTableColumn(col)
        }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(runSelected)
        tableView.rowHeight = 18

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)

        runButton.title = runTitle
        runButton.bezelStyle = .rounded
        runButton.target = self
        runButton.action = #selector(runSelected)
        runButton.keyEquivalent = "\r"
        runButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(runButton)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            searchField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            scroll.bottomAnchor.constraint(equalTo: runButton.topAnchor, constant: -8),
            runButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            runButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10),
        ])
    }

    @objc private func searchChanged() {
        let q = searchField.stringValue.lowercased()
        shown = q.isEmpty ? all : all.filter {
            $0.name.lowercased().contains(q) || $0.category.lowercased().contains(q)
                || $0.help.lowercased().contains(q)
        }
        tableView.reloadData()
    }

    @objc private func runSelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < shown.count else { return }
        onRun?(shown[row].name)
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { shown.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cmd = shown[row]
        let id = NSUserInterfaceItemIdentifier("c")
        let field = (tableView.makeView(withIdentifier: id, owner: self) as? NSTextField)
            ?? { let f = NSTextField(labelWithString: ""); f.identifier = id; f.isBordered = false; f.drawsBackground = false; return f }()
        switch tableColumn?.identifier.rawValue {
        case "name": field.stringValue = cmd.name
        case "category": field.stringValue = cmd.category
        default: field.stringValue = cmd.help
        }
        field.textColor = cmd.implemented ? .labelColor : .tertiaryLabelColor
        return field
    }
}

extension CommandBrowserWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) { onClose?() }
}
