// SPDX-License-Identifier: Apache-2.0
// MacroManagerWindowController.swift — the macros as a list you can act on (F-478).
//
// Everything here is what `macros.json` could always express and a text editor made tedious: rename,
// duplicate, reorder, delete. **Not** editing the steps — that stays in the editor, and the reason is
// the same one that kept the feature from having a form in the first place: a step is a tool name and
// its arguments, which is what JSON is, and a control per tool in the catalogue would be a worse
// editor than the one the app already has. This window is for the operations on a *macro*, and the
// **Edit File…** button hands over for the rest.
//
// Order matters and is not decoration: the file's order is the order the Command Browser and the
// button-bar picker list them in.
//
// Delete offers to take the button with it. That is the defect this window exists for as much as the
// convenience: a macro removed by hand left its button and its key behind, pressing either did nothing
// at all, and the only trace was a line in a log nobody has open.

import AppKit
import PCAutomation
import PCFoundation

final class MacroManagerWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    /// Called whenever the list on disk has changed, so the host can re-register the commands.
    var onChanged: (() -> Void)?
    /// Asked to remove the button bar entries pointing at these command names. Returns how many went.
    var onRemoveButtons: (([String]) -> Int)?
    /// Asked to add a button for this macro.
    var onAddButton: ((Macro) -> Void)?
    /// Asked to open `macros.json` in the app's editor.
    var onEditFile: (() -> Void)?

    private let store: MacroStore
    private var macros: [Macro] = []
    private let table = NSTableView()

    init(store: MacroStore) {
        self.store = store
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 380),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "Manage Macros")
        super.init(window: window)
        buildUI()
        reload()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        for (id, title, width) in [("title", String(localized: "Macro"), 240),
                                   ("command", String(localized: "Command"), 150),
                                   ("steps", String(localized: "Steps"), 60),
                                   ("needs", String(localized: "Needs"), 100)] {
            let column = NSTableColumn(identifier: .init(id))
            column.title = title
            column.width = CGFloat(width)
            table.addTableColumn(column)
        }
        table.dataSource = self
        table.delegate = self
        table.setAccessibilityLabel(String(localized: "Macros"))
        table.usesAlternatingRowBackgroundColors = true
        table.doubleAction = #selector(rename)
        table.target = self

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
            button(String(localized: "Rename…"), #selector(rename)),
            button(String(localized: "Duplicate"), #selector(duplicate)),
            button(String(localized: "Delete"), #selector(deleteMacro)),
            button(String(localized: "Move Up"), #selector(moveMacroUp)),
            button(String(localized: "Move Down"), #selector(moveMacroDown)),
            button(String(localized: "Add Button"), #selector(addButton)),
        ])
        toolbar.orientation = .horizontal
        toolbar.spacing = 8
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(toolbar)

        let note = NSTextField(wrappingLabelWithString: String(localized:
            "The steps themselves are edited in the file. Each macro is also a command, so it can go on a button, in the Start menu or on a key."))
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        note.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(note)

        let editFile = button(String(localized: "Edit File…"), #selector(editFile))
        let done = button(String(localized: "Done"), #selector(closeWindow))
        done.keyEquivalent = "\r"
        let bottom = NSStackView(views: [editFile, NSView(), done])
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
            note.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 10),
            note.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            note.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            bottom.topAnchor.constraint(equalTo: note.bottomAnchor, constant: 12),
            bottom.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            bottom.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            bottom.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])
    }

    /// Re-read the file. Always from disk rather than from a copy held here: the editor can be open on
    /// the same file, and a window that saved a stale list would undo whatever was typed there.
    func reload() {
        macros = store.macros()
        table.reloadData()
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { macros.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn, macros.indices.contains(row) else { return nil }
        let macro = macros[row]
        let text: String
        switch column.identifier.rawValue {
        case "title":   text = macro.title
        case "command": text = macro.commandName
        case "steps":   text = "\(macro.steps.count)"
        // What the permission gate will ask for. Shown because it is the difference between a macro
        // that runs and one that is refused, and because "this one deletes" is worth seeing in a list
        // before choosing which to put on a key.
        default:        text = MacroPlan.capability(of: macro).rawValue
        }
        let field = NSTextField(labelWithString: text)
        field.lineBreakMode = .byTruncatingTail
        field.toolTip = MacroPlan.rows(of: macro).map(PlanPhraseText.text(of:)).joined(separator: "\n")
        return field
    }

    private var selected: Macro? {
        macros.indices.contains(table.selectedRow) ? macros[table.selectedRow] : nil
    }

    // MARK: - Actions

    @objc private func rename() {
        guard let macro = selected else { return }
        guard let title = MacroManagerPrompt.ask(String(localized: "New name for this macro:"),
                                                 value: macro.title, in: window) else { return }
        var renamed = macro
        renamed.title = title.isEmpty ? macro.title : title
        // The *title* only. The id is the command name, and a macro whose id changed would leave every
        // button, key and `.mnu` entry pointing at a name that no longer exists — which is the failure
        // this window is partly here to clean up, not to cause.
        save { all in all.map { $0.id == macro.id ? renamed : $0 } }
    }

    @objc private func duplicate() {
        guard let macro = selected else { return }
        let copy = Macro(id: MacroStore.proposedID(for: macro.id, existing: macros.map(\.id)),
                         title: String(format: String(localized: "%@ copy"), macro.title),
                         icon: macro.icon, steps: macro.steps)
        save { all in
            var out = all
            let at = all.firstIndex { $0.id == macro.id }.map { $0 + 1 } ?? all.count
            out.insert(copy, at: at)
            return out
        }
    }

    @objc private func deleteMacro() {
        guard let macro = selected else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(format: String(localized: "Delete the macro “%@”?"), macro.title)
        alert.informativeText = String(localized: """
            Any button, key or menu entry that runs it will stop working. Buttons can be removed with \
            it; a key or a menu entry has to be taken out where it was set.
            """)
        alert.addButton(withTitle: String(localized: "Delete"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        let removeButtons = NSButton(checkboxWithTitle:
            String(localized: "Also remove its buttons"), target: nil, action: nil)
        removeButtons.state = .on
        alert.accessoryView = removeButtons
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let removed = removeButtons.state == .on ? onRemoveButtons?([macro.commandName]) ?? 0 : 0
        save { all in all.filter { $0.id != macro.id } }
        if removed > 0 {
            MacroManagerPrompt.note(String(format: String(localized: "%lld button(s) removed."), removed),
                                    in: window)
        }
    }

    @objc private func moveMacroUp() { move(by: -1) }
    @objc private func moveMacroDown() { move(by: 1) }

    private func move(by delta: Int) {
        let row = table.selectedRow
        let destination = row + delta
        guard macros.indices.contains(row), macros.indices.contains(destination) else { return }
        let id = macros[row].id
        save { all in
            var out = all
            guard let from = out.firstIndex(where: { $0.id == id }) else { return out }
            let to = from + delta
            guard out.indices.contains(to) else { return out }
            out.swapAt(from, to)
            return out
        }
        table.selectRowIndexes([destination], byExtendingSelection: false)
    }

    @objc private func addButton() {
        guard let macro = selected else { return }
        onAddButton?(macro)
    }

    @objc private func editFile() { onEditFile?() }

    @objc private func closeWindow() { close() }

    /// Apply `change` to the list on disk, then re-read and tell the host.
    ///
    /// Read-modify-write against the file rather than against `macros`, for the reason `reload` gives:
    /// the editor may be open on it. A failed write says so rather than leaving the window showing a
    /// list that is not what is saved.
    private func save(_ change: ([Macro]) -> [Macro]) {
        let selectedRow = table.selectedRow
        do {
            try store.save(change(store.macros()))
        } catch {
            MacroManagerPrompt.note(String(localized: "The macros could not be saved.")
                                    + "\n" + String(describing: error), in: window)
            return
        }
        reload()
        if macros.indices.contains(selectedRow) {
            table.selectRowIndexes([selectedRow], byExtendingSelection: false)
        }
        onChanged?()
    }
}

/// The two one-off dialogs this window needs, kept out of it so the window is a list and its actions.
enum MacroManagerPrompt {

    /// A single-field prompt. Returns nil on cancel.
    @MainActor
    static func ask(_ message: String, value: String, in window: NSWindow?) -> String? {
        if let scripted = ProcessInfo.processInfo.environment["PC_MACRO_MANAGER_INPUT"] {
            return scripted    // headless: a modal here hangs an automation run (F-436)
        }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = message
        alert.addButton(withTitle: String(localized: "OK"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        let field = NSTextField(string: value)
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue.trimmingCharacters(in: .whitespaces)
    }

    @MainActor
    static func note(_ message: String, in window: NSWindow?) {
        guard ProcessInfo.processInfo.environment["PC_MACRO_MANAGER_INPUT"] == nil else { return }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = message
        alert.addButton(withTitle: String(localized: "OK"))
        if let window { alert.beginSheetModal(for: window) } else { alert.runModal() }
    }
}
