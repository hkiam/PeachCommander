// AssociationsPageView.swift - Options "Edit/View" page: a grid editor for the
// per-extension viewer/editor associations (F-273). Columns: Extension | Open in
// viewer | Open in editor. A blank app cell means "use the built-in". Every edit
// rebuilds a FileAssociations and reports it through `onChange` (the host persists
// it to associations.ini, which is re-parsed on each use).

import AppKit
import PCFoundation

@MainActor
final class AssociationsPageView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let table = NSTableView()
    private let onChange: (FileAssociations) -> Void
    private var rows: [FileAssociations.Row]

    private enum Col: String { case ext, viewer, editor }

    init(associations: FileAssociations, onChange: @escaping (FileAssociations) -> Void) {
        self.onChange = onChange
        self.rows = associations.rows
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        let intro = NSTextField(wrappingLabelWithString: String(localized:
            "Choose which application opens each file type. Leave blank to use the built-in viewer (F3) or editor (F4)."))
        intro.translatesAutoresizingMaskIntoConstraints = false
        intro.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        intro.textColor = .secondaryLabelColor
        addSubview(intro)

        table.headerView = NSTableHeaderView()
        table.usesAlternatingRowBackgroundColors = true
        table.dataSource = self
        table.delegate = self
        table.allowsMultipleSelection = false
        table.rowHeight = 22
        addColumn(.ext, String(localized: "Extension"), width: 90)
        addColumn(.viewer, String(localized: "Open in viewer (F3)"), width: 190)
        addColumn(.editor, String(localized: "Open in editor (F4)"), width: 190)

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        addSubview(scroll)

        let add = button(String(localized: "Add"), #selector(addRow))
        let remove = button(String(localized: "Remove"), #selector(removeRow))
        let pickViewer = button(String(localized: "Set Viewer App…"), #selector(pickViewer))
        let pickEditor = button(String(localized: "Set Editor App…"), #selector(pickEditor))
        let clear = button(String(localized: "Use Built-in"), #selector(clearApps))
        // Two rows so the buttons fit the settings window's width.
        let row1 = NSStackView(views: [add, remove])
        row1.orientation = .horizontal; row1.spacing = 8
        let row2 = NSStackView(views: [pickViewer, pickEditor, clear])
        row2.orientation = .horizontal; row2.spacing = 8
        let buttons = NSStackView(views: [row1, row2])
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.orientation = .vertical
        buttons.alignment = .leading
        buttons.spacing = 8
        addSubview(buttons)

        NSLayoutConstraint.activate([
            intro.topAnchor.constraint(equalTo: topAnchor),
            intro.leadingAnchor.constraint(equalTo: leadingAnchor),
            intro.trailingAnchor.constraint(equalTo: trailingAnchor),

            scroll.topAnchor.constraint(equalTo: intro.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 240),

            buttons.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 10),
            buttons.leadingAnchor.constraint(equalTo: leadingAnchor),
            buttons.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func addColumn(_ col: Col, _ title: String, width: CGFloat) {
        let c = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(col.rawValue))
        c.title = title
        c.width = width
        table.addTableColumn(c)
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.setContentHuggingPriority(.required, for: .horizontal)
        return b
    }

    // MARK: - Editing

    private func commit() { onChange(FileAssociations(rows: rows)) }

    @objc private func addRow() {
        rows.append(FileAssociations.Row(ext: ""))
        table.reloadData()
        let last = rows.count - 1
        table.selectRowIndexes(IndexSet(integer: last), byExtendingSelection: false)
        table.editColumn(0, row: last, with: nil, select: true)
    }

    @objc private func removeRow() {
        let r = table.selectedRow
        guard rows.indices.contains(r) else { return }
        rows.remove(at: r)
        table.reloadData()
        commit()
    }

    @objc private func pickViewer() { pickApp { $0.viewer = $1 } }
    @objc private func pickEditor() { pickApp { $0.editor = $1 } }

    @objc private func clearApps() {
        let r = table.selectedRow
        guard rows.indices.contains(r) else { return }
        rows[r].viewer = ""
        rows[r].editor = ""
        table.reloadData()
        commit()
    }

    /// Present an Applications picker and assign the chosen path via `assign`.
    private func pickApp(_ assign: @escaping (inout FileAssociations.Row, String) -> Void) {
        let r = table.selectedRow
        guard rows.indices.contains(r) else { NSSound.beep(); return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = String(localized: "Choose")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        assign(&rows[r], url.path)
        table.reloadData()
        commit()
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let id = tableColumn?.identifier.rawValue, let col = Col(rawValue: id),
              rows.indices.contains(row) else { return nil }
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.identifier = tableColumn?.identifier
        field.lineBreakMode = .byTruncatingMiddle
        switch col {
        case .ext:
            field.stringValue = rows[row].ext
            field.isEditable = true
            field.placeholderString = "ext"
            field.target = self
            field.action = #selector(fieldEdited(_:))
        case .viewer, .editor:
            // App path columns are set via the picker buttons (read-only display);
            // show the app's display name for readability, full path as tooltip.
            let value = (col == .viewer) ? rows[row].viewer : rows[row].editor
            field.stringValue = value.isEmpty ? String(localized: "(built-in)") : Self.displayName(value)
            field.textColor = value.isEmpty ? .secondaryLabelColor : .labelColor
            field.toolTip = value.isEmpty ? nil : value
            field.isEditable = false
        }
        return field
    }

    @objc private func fieldEdited(_ sender: NSTextField) {
        let r = table.row(for: sender)
        guard rows.indices.contains(r), sender.identifier?.rawValue == Col.ext.rawValue else { return }
        rows[r].ext = sender.stringValue.trimmingCharacters(in: .whitespaces)
        commit()
    }

    /// "/Applications/Visual Studio Code.app" → "Visual Studio Code"; passes
    /// through bundle ids and other non-.app values unchanged.
    private static func displayName(_ appPath: String) -> String {
        guard appPath.hasSuffix(".app") else { return appPath }
        return (appPath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
    }
}
