// ButtonBarEditorWindowController.swift - In-app editor for the toolbar (.bar) (TODOS).
//
// Replaces "open the .bar file in some external program". A list of the current
// buttons on the left (reorder / add / remove / add separator) and a detail form on
// the right (command, caption, parameters, start path, icon, icon-only). Saving hands
// the edited ButtonBar back to the owner, which writes it and reloads the live strip.

import AppKit
import PCFoundation
import UniformTypeIdentifiers

final class ButtonBarEditorWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSComboBoxDelegate {
    /// Called with the edited bar when the user saves.
    var onSave: ((ButtonBar) -> Void)?
    /// Present a "Choose command" picker (F-255); the completion fills the field.
    var onPickCommand: ((@escaping (String) -> Void) -> Void)?

    private var buttons: [BarButton]
    private let commandNames: [String]
    private let commandHelp: [String: String]

    private let tableView = NSTableView()
    private let commandField = NSComboBox()
    private let commandDescLabel = NSTextField(labelWithString: "")
    private let captionField = NSTextField()
    private let paramField = NSTextField()
    private let pathField = NSTextField()
    private let iconField = NSTextField()
    private let iconicCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private var updatingForm = false

    init(bar: ButtonBar, commands: [(name: String, help: String)]) {
        self.buttons = bar.buttons
        self.commandNames = commands.map(\.name).sorted()
        self.commandHelp = Dictionary(commands.map { ($0.name, $0.help) }, uniquingKeysWith: { a, _ in a })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 460),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "Customize Toolbar")
        super.init(window: window)
        buildUI()
        if !buttons.isEmpty { selectRow(0) } else { updateForm() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() {
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        // Left: button list.
        tableView.headerView = nil
        tableView.addTableColumn(NSTableColumn(identifier: .init("c")))
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 22
        let listScroll = NSScrollView()
        listScroll.documentView = tableView
        listScroll.hasVerticalScroller = true
        listScroll.borderType = .bezelBorder
        listScroll.translatesAutoresizingMaskIntoConstraints = false

        let add = toolButton("+", #selector(addButton))
        let addSep = toolButton("—", #selector(addSeparator))
        let remove = toolButton("−", #selector(removeButton))
        let up = toolButton("↑", #selector(moveButtonUp))
        let down = toolButton("↓", #selector(moveButtonDown))
        let listButtons = NSStackView(views: [add, addSep, remove, up, down])
        listButtons.orientation = .horizontal
        listButtons.spacing = 4
        listButtons.translatesAutoresizingMaskIntoConstraints = false

        // Right: detail form.
        commandField.completes = true
        commandField.usesDataSource = false
        commandField.numberOfVisibleItems = 20
        commandField.addItems(withObjectValues: commandNames)
        commandField.delegate = self
        commandField.target = self
        commandField.action = #selector(fieldChanged)
        commandDescLabel.font = NSFont.systemFont(ofSize: 11)
        commandDescLabel.textColor = .secondaryLabelColor
        commandDescLabel.lineBreakMode = .byTruncatingTail
        commandDescLabel.maximumNumberOfLines = 2
        for field in [captionField, paramField, pathField, iconField] {
            field.delegate = self
        }
        paramField.toolTip = String(localized: "Parameters for the command or external tool (Command may be a program path). Tokens: %P = active folder, %N = cursor file name → full path %P/%N; %T = other panel's folder; %S = selected names; %L = temp file listing full paths of the selection; %% = literal %.")
        iconField.toolTip = String(localized: "SF Symbol (sf:name), an image file path, or a bundled icon name. Use the picker to browse.")
        iconicCheck.title = String(localized: "Show icon only (hide caption)")
        iconicCheck.target = self
        iconicCheck.action = #selector(fieldChanged)

        let iconRow = NSStackView(views: [iconField, toolButton("…", #selector(pickIcon(_:)))])
        iconRow.orientation = .horizontal
        iconRow.spacing = 6
        iconRow.setHuggingPriority(.defaultLow, for: .horizontal)

        let chooseButton = NSButton(title: String(localized: "Choose…"), target: self, action: #selector(chooseCommand))
        chooseButton.bezelStyle = .rounded
        let commandRow = NSStackView(views: [commandField, chooseButton])
        commandRow.orientation = .horizontal
        commandRow.spacing = 6
        commandField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let form = NSGridView(views: [
            [label(String(localized: "Command:")), commandRow],
            [NSGridCell.emptyContentView, commandDescLabel],
            [label(String(localized: "Caption:")), captionField],
            [label(String(localized: "Parameters:")), paramField],
            [label(String(localized: "Start path:")), pathField],
            [label(String(localized: "Icon:")), iconRow],
            [NSGridCell.emptyContentView, iconicCheck]
        ])
        form.translatesAutoresizingMaskIntoConstraints = false
        form.rowSpacing = 8
        form.columnSpacing = 8
        form.column(at: 1).xPlacement = .fill
        form.column(at: 1).width = 320

        // Bottom: Save / Cancel.
        let save = NSButton(title: String(localized: "Save"), target: self, action: #selector(saveAndClose))
        save.bezelStyle = .rounded; save.keyEquivalent = "\r"
        let cancel = NSButton(title: String(localized: "Cancel"), target: self, action: #selector(cancel))
        cancel.bezelStyle = .rounded; cancel.keyEquivalent = "\u{1b}"
        let bottom = NSStackView(views: [NSView(), cancel, save])
        bottom.orientation = .horizontal
        bottom.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(listScroll)
        content.addSubview(listButtons)
        content.addSubview(form)
        content.addSubview(bottom)

        NSLayoutConstraint.activate([
            listScroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            listScroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            listScroll.widthAnchor.constraint(equalToConstant: 240),
            listScroll.bottomAnchor.constraint(equalTo: listButtons.topAnchor, constant: -6),

            listButtons.leadingAnchor.constraint(equalTo: listScroll.leadingAnchor),
            listButtons.bottomAnchor.constraint(equalTo: bottom.topAnchor, constant: -12),

            form.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            form.leadingAnchor.constraint(equalTo: listScroll.trailingAnchor, constant: 16),
            form.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12),

            bottom.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            bottom.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            bottom.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 12)
        ])
    }

    private func label(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.alignment = .right
        return l
    }

    private func toolButton(_ title: String, _ selector: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: selector)
        b.bezelStyle = .rounded
        b.setButtonType(.momentaryPushIn)
        return b
    }

    // MARK: - Selection / form sync

    private var selected: Int { tableView.selectedRow }

    private func selectRow(_ row: Int) {
        guard buttons.indices.contains(row) else { return }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        updateForm()
    }

    /// Populate the detail fields from the selected button.
    private func updateForm() {
        updatingForm = true
        defer { updatingForm = false }
        let enabled = buttons.indices.contains(selected)
        for c in [commandField, captionField, paramField, pathField, iconField] { c.isEnabled = enabled }
        iconicCheck.isEnabled = enabled
        let b = enabled ? buttons[selected] : BarButton()
        commandField.stringValue = b.cmd
        captionField.stringValue = b.menu
        paramField.stringValue = b.param
        pathField.stringValue = b.path
        iconField.stringValue = b.icon
        iconicCheck.state = b.iconic ? .on : .off
        updateCommandDescription()
    }

    /// Show the help text for the currently entered command (below the combo,
    /// and as the combo's tooltip) so the user knows what they're picking.
    private func updateCommandDescription() {
        let name = commandField.stringValue.trimmingCharacters(in: .whitespaces)
        let help = commandHelp[name]
        commandDescLabel.stringValue = help ?? (name.isEmpty ? "" : String(localized: "External tool / unknown command"))
        commandField.toolTip = help
    }

    /// Write the detail fields back into the selected button.
    private func commitForm() {
        guard buttons.indices.contains(selected), !updatingForm else { return }
        buttons[selected].cmd = commandField.stringValue.trimmingCharacters(in: .whitespaces)
        buttons[selected].menu = captionField.stringValue
        buttons[selected].param = paramField.stringValue
        buttons[selected].path = pathField.stringValue
        buttons[selected].icon = iconField.stringValue.trimmingCharacters(in: .whitespaces)
        buttons[selected].iconic = iconicCheck.state == .on
        tableView.reloadData(forRowIndexes: IndexSet(integer: selected), columnIndexes: IndexSet(integer: 0))
    }

    @objc private func fieldChanged() { commitForm(); updateCommandDescription() }

    /// Open the shared command picker and drop the chosen command into the field (F-255).
    @objc private func chooseCommand() {
        onPickCommand? { [weak self] name in
            guard let self else { return }
            self.commandField.stringValue = name
            self.commitForm()
            self.updateCommandDescription()
        }
    }
    func controlTextDidChange(_ obj: Notification) { commitForm(); updateCommandDescription() }
    func comboBoxSelectionDidChange(_ notification: Notification) {
        // Commit the picked command synchronously. On selection-change the combo's
        // stringValue hasn't updated yet, so read the selected item directly (the
        // previous deferred commit could be lost if the row changed first).
        guard buttons.indices.contains(selected), !updatingForm,
              let value = commandField.objectValueOfSelectedItem as? String else { return }
        commandField.stringValue = value
        buttons[selected].cmd = value.trimmingCharacters(in: .whitespaces)
        updateCommandDescription()
        tableView.reloadData(forRowIndexes: IndexSet(integer: selected), columnIndexes: IndexSet(integer: 0))
    }
    func tableViewSelectionDidChange(_ notification: Notification) { updateForm() }

    // MARK: - List editing

    @objc private func addButton() {
        let insertAt = buttons.indices.contains(selected) ? selected + 1 : buttons.count
        buttons.insert(BarButton(icon: "sf:app", cmd: "cm_List", menu: "New Button"), at: insertAt)
        tableView.reloadData()
        selectRow(insertAt)
    }

    // MARK: - Icon picker (graphical + custom images)

    private static let customIconsKey = "PCCustomToolbarIcons"
    private static let sfSymbols = [
        "folder", "doc", "doc.text", "terminal", "magnifyingglass", "arrow.triangle.2.circlepath",
        "trash", "gearshape", "square.grid.2x2", "list.bullet", "scissors", "doc.on.doc",
        "square.and.arrow.down", "square.and.arrow.up", "play.fill", "hammer", "paintbrush", "link",
        "star", "tag", "lock", "network",
    ]

    @objc private func pickIcon(_ sender: NSButton) {
        let menu = NSMenu()
        let sfHeader = NSMenuItem(title: String(localized: "SF Symbols"), action: nil, keyEquivalent: "")
        sfHeader.isEnabled = false
        menu.addItem(sfHeader)
        for name in Self.sfSymbols {
            let item = NSMenuItem(title: name, action: #selector(pickSFSymbol(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = name
            if let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
                img.size = NSSize(width: 16, height: 16)
                item.image = img
            }
            menu.addItem(item)
        }

        let customs = Self.customIcons()
        if !customs.isEmpty {
            menu.addItem(.separator())
            let header = NSMenuItem(title: String(localized: "Custom Icons"), action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for path in customs {
                let item = NSMenuItem(title: (path as NSString).lastPathComponent,
                                      action: #selector(pickCustomIcon(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = path
                if let img = NSImage(contentsOfFile: path) { img.size = NSSize(width: 16, height: 16); item.image = img }
                menu.addItem(item)
            }
            let removeItem = NSMenuItem(title: String(localized: "Remove Custom Icon"), action: nil, keyEquivalent: "")
            let removeMenu = NSMenu()
            for path in customs {
                let r = NSMenuItem(title: (path as NSString).lastPathComponent,
                                   action: #selector(removeCustomIcon(_:)), keyEquivalent: "")
                r.target = self
                r.representedObject = path
                removeMenu.addItem(r)
            }
            removeItem.submenu = removeMenu
            menu.addItem(removeItem)
        }

        menu.addItem(.separator())
        let choose = NSMenuItem(title: String(localized: "Choose Image File…"),
                                action: #selector(chooseCustomIconFile), keyEquivalent: "")
        choose.target = self
        menu.addItem(choose)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 2), in: sender)
    }

    @objc private func pickSFSymbol(_ sender: NSMenuItem) {
        setIcon("sf:\(sender.representedObject as? String ?? "")")
    }

    @objc private func pickCustomIcon(_ sender: NSMenuItem) {
        if let path = sender.representedObject as? String { setIcon(path) }
    }

    @objc private func chooseCustomIconFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image, .icns, .svg]
        panel.prompt = String(localized: "Use Icon")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Self.addCustomIcon(url.path)
        setIcon(url.path)
    }

    @objc private func removeCustomIcon(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        var list = Self.customIcons()
        list.removeAll { $0 == path }
        UserDefaults.standard.set(list, forKey: Self.customIconsKey)
    }

    private func setIcon(_ value: String) {
        iconField.stringValue = value
        commitForm()
    }

    private static func customIcons() -> [String] {
        UserDefaults.standard.stringArray(forKey: customIconsKey) ?? []
    }
    private static func addCustomIcon(_ path: String) {
        var list = customIcons()
        if !list.contains(path) { list.append(path); UserDefaults.standard.set(list, forKey: customIconsKey) }
    }

    @objc private func addSeparator() {
        let insertAt = buttons.indices.contains(selected) ? selected + 1 : buttons.count
        buttons.insert(BarButton(), at: insertAt)   // empty icon+cmd = separator
        tableView.reloadData()
        selectRow(insertAt)
    }

    @objc private func removeButton() {
        guard buttons.indices.contains(selected) else { return }
        let row = selected
        buttons.remove(at: row)
        tableView.reloadData()
        // Reselect a neighbour; when the list is now empty, still refresh the form
        // (selectRow no-ops on an out-of-range index).
        selectRow(min(row, buttons.count - 1))
        updateForm()
    }

    @objc private func moveButtonUp() { swapSelected(with: selected - 1) }
    @objc private func moveButtonDown() { swapSelected(with: selected + 1) }

    private func swapSelected(with other: Int) {
        guard buttons.indices.contains(selected), buttons.indices.contains(other) else { return }
        buttons.swapAt(selected, other)
        tableView.reloadData()
        selectRow(other)
    }

    // MARK: - Save

    @objc private func saveAndClose() {
        window?.makeFirstResponder(nil)   // commit any in-progress field edit
        commitForm()
        onSave?(ButtonBar(buttons: buttons))
        close()
    }

    @objc private func cancel() { close() }

    // MARK: - NSTableView

    func numberOfRows(in tableView: NSTableView) -> Int { buttons.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let field = (tableView.makeView(withIdentifier: id, owner: self) as? NSTextField)
            ?? { let f = NSTextField(labelWithString: ""); f.identifier = id; f.lineBreakMode = .byTruncatingTail; return f }()
        let b = buttons[row]
        if b.isSeparator {
            field.stringValue = "──────────"
            field.textColor = .tertiaryLabelColor
        } else {
            let caption = b.menu.isEmpty ? b.cmd : b.menu
            field.stringValue = caption.isEmpty ? "(empty)" : caption
            field.textColor = .labelColor
        }
        return field
    }
}
