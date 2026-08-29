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
import UniformTypeIdentifiers

final class MacroManagerWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    /// Called whenever the list on disk has changed, so the host can re-register the commands.
    var onChanged: (() -> Void)?
    /// Asked to remove the button bar entries pointing at these command names. Returns how many went.
    var onRemoveButtons: (([String]) -> Int)?
    /// Asked to add a button for this macro.
    var onAddButton: ((Macro) -> Void)?
    /// Asked to run this macro, through the same gate every other way of running one goes through.
    var onRun: ((Macro) -> Void)?
    /// Asked to open a macro's own file in the app's editor — or, with nothing selected, the folder
    /// they all live in.
    var onEditFile: ((Macro?) -> Void)?
    /// Asked to start a recording, or to stop the one that is running.
    var onToggleRecording: (() -> Void)?
    /// Asked to build a macro out of what recently happened.
    var onMacroFromRecentActions: (() -> Void)?
    /// Whether a recording is running right now, so the button says the right thing when the window is
    /// opened *during* one — which is the normal case, because starting one closes this window.
    var isRecording: Bool = false

    private let store: MacroStore
    private var macros: [Macro] = []
    private let table = NSTableView()
    /// Kept, because its title is the state: this is the one control that says whether a recording is
    /// running, and a stale "Record Macro…" over a running one is a lie the user acts on.
    private let recordButton = NSButton()
    /// What the wordless buttons are called.
    ///
    /// Held here rather than read back off the button: `accessibilityLabel()` answers with the role
    /// ("Button") on an image button whatever is set on it, and `identifier` is not reliably kept
    /// either — so the report listed the two arrows as the same word and could no longer tell a
    /// missing button from a picture. A map the window fills in itself cannot disagree with the row.
    private var wordlessNames: [ObjectIdentifier: String] = [:]

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

        // "Needs" carries a floor as well as a width. The table shares its spare width out among all
        // four columns proportionally, so the narrowest one stays narrowest — and at 100pt it rendered
        // "changes files" as "change…", which answers nothing. That is the column this window exists
        // for: it is what makes "this one deletes" visible before a macro goes on a key. Measured
        // against the longest phrase `PlanPhraseText` produces, in English and in German.
        for (id, title, width, minimum) in [("title", String(localized: "Macro"), 240, 120),
                                            ("command", String(localized: "Command"), 150, 90),
                                            ("steps", String(localized: "Steps"), 60, 44),
                                            ("needs", String(localized: "Needs"), 150, 135)] {
            let column = NSTableColumn(identifier: .init(id))
            column.title = title
            column.width = CGFloat(width)
            column.minWidth = CGFloat(minimum)
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
        // Hidden while there is nothing to scroll. It was always drawn, and the last column's text ran
        // under it: "changes files" lost its final letter in a window whose whole point is that column.
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)

        func button(_ title: String, _ action: Selector) -> NSButton {
            let b = NSButton(title: title, target: self, action: action)
            b.bezelStyle = .rounded
            return b
        }
        /// A button that is an arrow rather than a word.
        ///
        /// Only for the two whose meaning an arrow carries completely — moving a row up and down. The
        /// row of buttons is a row of *labels* otherwise, and turning the rest into icons would trade
        /// a wide window for a guessing game. `title` is still the button's name to everything that
        /// asks: the accessibility label, the tooltip, and the automation report, which reads a
        /// picture no better than VoiceOver does.
        func arrowButton(_ symbol: String, _ title: String, _ action: Selector) -> NSButton {
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            let b = NSButton(image: image ?? NSImage(), target: self, action: action)
            b.bezelStyle = .rounded
            b.imageScaling = .scaleProportionallyDown
            // `NSButton(image:target:action:)` leaves the default title in place — "Button", localized,
            // which is why the report listed both arrows as the same word. It is not drawn (the button
            // is image-only), but it is still what `title` answers, so it is cleared here.
            b.title = ""
            b.setAccessibilityLabel(title)
            b.toolTip = title
            wordlessNames[ObjectIdentifier(b)] = title
            return b
        }
        // Running one from here is not a convenience: it is the only way to *try* a macro you have
        // just recorded without first closing this window and going to find the command. It runs
        // through the same permission gate and the same confirmation as every other way in — this
        // window has no privileges of its own.
        let run = button(String(localized: "Run"), #selector(runMacro))
        run.toolTip = String(localized: "Run the selected macro on the panels behind this window. It is shown as a plan and confirmed first, like any other run.")
        // Export sits with the actions on the *selected* macro, not with the ones that make a new one:
        // it takes the macro that is highlighted and writes it somewhere. Its counterpart, Import, is
        // below with the other ways a macro arrives.
        let export = button(String(localized: "Export…"), #selector(exportMacro))
        export.toolTip = String(localized: "Write the selected macro to a file of its own, to send to somebody or keep with your dotfiles.")
        let toolbar = NSStackView(views: [
            run,
            button(String(localized: "Rename…"), #selector(rename)),
            button(String(localized: "Duplicate"), #selector(duplicate)),
            button(String(localized: "Delete"), #selector(deleteMacro)),
            arrowButton("arrow.up", String(localized: "Move Up"), #selector(moveMacroUp)),
            arrowButton("arrow.down", String(localized: "Move Down"), #selector(moveMacroDown)),
            button(String(localized: "Add Button"), #selector(addButton)),
            export,
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

        // The three ways a macro comes into existence, together and under the list they land in. They
        // were three separate entries in the Configuration menu, which put the same feature in three
        // places and made none of them the obvious one to press first: this window is now the single
        // entry, and the making of a macro is what sits under the list of them.
        recordButton.bezelStyle = .rounded
        recordButton.target = self
        recordButton.action = #selector(toggleRecording)
        applyRecordingTitle()
        let fromRecent = button(String(localized: "From Recent Actions…"),
                                #selector(macroFromRecentActions))
        fromRecent.toolTip = String(localized: "Build a macro out of what has already happened, instead of recording it now.")
        let importButton = button(String(localized: "Import…"), #selector(importMacros))
        importButton.toolTip = String(localized: "Add macros from files somebody sent you. An id that is already taken gets a free one, so nothing of yours is replaced.")
        let editFile = button(String(localized: "Edit File…"), #selector(editFile))
        editFile.toolTip = String(localized: "Edit the selected macro's own file — this is where its steps are changed. With nothing selected, the folder they all live in is shown in the panel.")
        let done = button(String(localized: "Done"), #selector(closeWindow))
        done.keyEquivalent = "\r"
        let bottom = NSStackView(views: [recordButton, fromRecent, importButton, editFile,
                                        NSView(), done])
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
            // The toolbar may not run off the right edge. Six buttons at English lengths fit the 620
            // this window opens at; at German ones the last one was cut in half — and with **zero**
            // `Unable to simultaneously satisfy constraints`, because a stack view happily lays its
            // arranged views out past its own trailing edge. The layout was satisfiable and wrong,
            // which is the class no conflict count can catch, so it is stated as a constraint here
            // and the window is widened to whatever satisfying it costs.
            toolbar.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12),
            // The same rule for the bottom row, which now carries four buttons instead of two and can
            // run off the edge exactly the way the toolbar did — silently, with no layout conflict.
            bottom.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12),
        ])
        sizeToFitContents()
    }

    /// Open at least as wide as the toolbar needs, and refuse to be dragged narrower.
    ///
    /// Measured rather than guessed at: the width a row of buttons wants is the sum of nine localized
    /// strings, and no number written here would survive the next translation. `contentMinSize` is
    /// what makes it stick — without it the user can drag the window back to the broken state.
    private func sizeToFitContents() {
        guard let window, let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        // The explanatory line is *told* how wide it may be before anything is measured. A wrapping
        // label answers its fitting size as one line unless it is given a `preferredMaxLayoutWidth`,
        // so it — a sentence, not a control — was what decided how wide this window opened: measured
        // at 869pt against a button row that needed 781. Now the buttons set the width and the
        // sentence wraps into it, which is the right way round.
        let wanted = max(toolbarWidth(), bottomWidth())
        if let note = (content.subviews.compactMap { $0 as? NSTextField }).first, wanted > 0 {
            note.preferredMaxLayoutWidth = wanted - 24
            note.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            content.layoutSubtreeIfNeeded()
        }
        let needed = content.fittingSize.width
        guard needed > 0 else { return }
        window.contentMinSize = NSSize(width: needed, height: 320)
        if window.frame.width < needed {
            window.setContentSize(NSSize(width: needed, height: window.frame.height))
        }
    }

    /// What this window is showing, as text an automation run can read back (F-478).
    ///
    /// A dump rather than the accessibility tree, for the reason the drawn bars have one: the tree
    /// came back holding the table and nothing else — the stack views are laid out and rendered but
    /// contribute no accessible children until a client attaches — so a scenario could not see the
    /// buttons at all. And a dump can report the *measurement*, which the tree could never do: the
    /// toolbar's fitting width against the window's, which is the difference between the clipped
    /// toolbar this window shipped with and the one it has now. Zero Auto Layout conflicts either way.
    func automationReport() -> String {
        window?.contentView?.layoutSubtreeIfNeeded()
        let width = window?.frame.width ?? 0
        let needed = toolbarWidth()
        var lines = ["window-width=\(Int(width))",
                     "toolbar-width=\(Int(needed))",
                     "toolbar-fits=\(needed <= width ? "yes" : "NO")",
                     "buttons=" + toolbarTitles().joined(separator: "|"),
                     // The bottom row is measured too: it is now the wider of the two, so it is what
                     // decides how wide this window opens — and a row that quietly runs off the edge
                     // is the failure this report was written for.
                     "make-width=\(Int(bottomWidth()))",
                     "note-width=\(Int(noteWidth()))",
                     "make-fits=\(bottomWidth() <= width ? "yes" : "NO")",
                     // The bottom row now carries the three ways a macro is made, and one of them says
                     // whether a recording is running — which is state a scenario has to be able to
                     // read back, and the accessibility tree does not report it.
                     "make=" + bottomTitles().joined(separator: "|"),
                     "recording=\(isRecording ? "yes" : "no")"]
        for macro in macros {
            lines.append("row=\(macro.commandName)|\(macro.steps.count)|"
                         + PlanPhraseText.localized(MacroPlan.capability(of: macro)))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The toolbar row's own views, found back out of the content view rather than held in a field:
    /// what has to be measured is what is *on screen*, and a field could go stale against it.
    private func toolbarRow() -> NSStackView? {
        (window?.contentView?.subviews.compactMap { $0 as? NSStackView } ?? [])
            .first { $0.arrangedSubviews.count > 3 }
    }

    private func toolbarWidth() -> CGFloat {
        guard let row = toolbarRow() else { return 0 }
        // The buttons' own widths plus the gaps and the two margins — not `row.frame.width`, which is
        // whatever the constraint gave it and is exactly the number that lied before.
        let buttons = row.arrangedSubviews.reduce(0) { $0 + $1.fittingSize.width }
        return buttons + row.spacing * CGFloat(max(0, row.arrangedSubviews.count - 1)) + 24
    }

    private func toolbarTitles() -> [String] {
        (toolbarRow()?.arrangedSubviews.compactMap { $0 as? NSButton } ?? []).map(name(of:))
    }

    /// What a button is called, whether or not it has a word on it.
    ///
    /// The two reordering buttons are arrows, and a report that listed them as two empty strings would
    /// make the layout scenario unable to tell a missing button from a picture — which is the class of
    /// wrongness `automationReport` exists to catch.
    private func name(of button: NSButton) -> String {
        button.title.isEmpty ? (wordlessNames[ObjectIdentifier(button)] ?? "?") : button.title
    }

    /// What the explanatory line under the buttons wants to be. A wrapping label answers its fitting
    /// size as *one line* unless it is told otherwise, so it — and not the buttons — can be the thing
    /// that decides how wide this window opens.
    private func noteWidth() -> CGFloat {
        let labels = (window?.contentView?.subviews.compactMap { $0 as? NSTextField } ?? [])
        return labels.first?.fittingSize.width ?? 0
    }

    private func bottomWidth() -> CGFloat {
        guard let row = bottomRow() else { return 0 }
        let buttons = row.arrangedSubviews.reduce(0) { $0 + $1.fittingSize.width }
        return buttons + row.spacing * CGFloat(max(0, row.arrangedSubviews.count - 1)) + 24
    }

    private func bottomRow() -> NSStackView? {
        let rows = (window?.contentView?.subviews.compactMap { $0 as? NSStackView } ?? [])
        guard let bottom = rows.last, bottom !== toolbarRow() else { return nil }
        return bottom
    }

    /// The row under the list: the ways a macro is made, plus Done.
    private func bottomTitles() -> [String] {
        (bottomRow()?.arrangedSubviews.compactMap { $0 as? NSButton } ?? []).map(name(of:))
    }

    /// Drive one of this window's actions from a scenario (F-478).
    ///
    /// Its own entry point rather than a scripted click, for the reason `automationReport` gives: the
    /// accessibility tree does not report these buttons until a client attaches, so a scenario cannot
    /// find them to press. `row` is one-based and 0 means "no selection", which is itself a case worth
    /// exercising — **Edit File…** with nothing selected shows the folder instead.
    @discardableResult
    func performForAutomation(row: Int, action: String) -> Bool {
        if row > 0, macros.indices.contains(row - 1) {
            table.selectRowIndexes([row - 1], byExtendingSelection: false)
        } else {
            table.deselectAll(nil)
        }
        switch action {
        case "run":        runMacro()
        case "export":     exportMacro()
        case "import":     importMacros()
        case "edit":       editFile()
        case "record":     toggleRecording()
        case "recent":     macroFromRecentActions()
        case "duplicate":  duplicate()
        case "delete":     deleteMacro()
        case "up":         moveMacroUp()
        case "down":       moveMacroDown()
        case "addbutton":  addButton()
        default:           return false
        }
        return true
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
        default:        text = PlanPhraseText.localized(MacroPlan.capability(of: macro))
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
        // Answered from the environment in an automation run. A bare `runModal()` here would hang the
        // run in its nested runloop — the script carries on and `quit` never lands, which looks
        // exactly like a launch that died. The same arrangement the three macro sheets already use.
        guard MacroManagerPrompt.confirm(alert) else { return }
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

    /// Run the selected macro. The window steps aside first: what the macro does happens in the
    /// panels, and a list sitting over them is the one thing that would make the result invisible.
    @objc private func runMacro() {
        guard let macro = selected else { return }
        window?.orderOut(nil)
        onRun?(macro)
    }

    @objc private func addButton() {
        guard let macro = selected else { return }
        onAddButton?(macro)
    }

    @objc private func editFile() { onEditFile?(selected) }

    /// Write the selected macro to a file of its own.
    @objc private func exportMacro() {
        guard let macro = selected else { return }
        guard let url = MacroManagerPrompt.chooseExportFile(named: "\(macro.id).json",
                                                            in: window) else { return }
        do {
            // Without an `order`: what position it happens to occupy here means nothing on the machine
            // it is going to, and a number that survives the trip would only be wrong there.
            try MacroStore.encoded(macro).write(to: url, options: .atomic)
        } catch {
            MacroManagerPrompt.note(String(localized: "The macro could not be exported.")
                                    + "\n" + String(describing: error), in: window)
        }
    }

    /// Read macros out of files somebody sent and add them.
    @objc private func importMacros() {
        let urls = MacroManagerPrompt.chooseImportFiles(in: window)
        guard !urls.isEmpty else { return }
        var incoming: [Macro] = []
        var unreadable: [String] = []
        for url in urls {
            guard let data = try? Data(contentsOf: url) else {
                unreadable.append(url.lastPathComponent); continue
            }
            let found = MacroStore.decodeForImport(data)
            if found.isEmpty { unreadable.append(url.lastPathComponent) }
            incoming += found
        }
        var added: [Macro] = []
        do { added = try store.importing(incoming) }
        catch {
            MacroManagerPrompt.note(String(localized: "The macros could not be imported.")
                                    + "\n" + String(describing: error), in: window)
            return
        }
        reload()
        onChanged?()
        // Said out loud, and with the ids they ended up with: an import that renamed `backup` to
        // `backup-2` to protect the one you already had is exactly the thing you need to be told,
        // because the button you were about to make has to name the right one.
        var lines: [String] = []
        if !added.isEmpty {
            // The ids, not a count: listing them *is* the count, and it is the ids the user needs —
            // an import that renamed `backup` to `backup-2` to protect the one they already had is
            // exactly the thing they have to be told, because the button they make has to name the
            // right one. It also keeps this message free of a counted noun to inflect.
            lines.append(String(format: String(localized: "Imported: %@"),
                                added.map(\.id).joined(separator: ", ")))
        }
        if !unreadable.isEmpty {
            lines.append(String(format: String(localized: "Not a macro file: %@"),
                                unreadable.joined(separator: ", ")))
        }
        if added.isEmpty, unreadable.isEmpty {
            lines.append(String(localized: "There was no macro in those files."))
        }
        MacroManagerPrompt.note(lines.joined(separator: "\n"), in: window)
    }

    @objc private func toggleRecording() { onToggleRecording?() }

    @objc private func macroFromRecentActions() { onMacroFromRecentActions?() }

    /// Told by the host when a recording starts or stops, from wherever it was started — the button in
    /// this window, a key, or a toolbar button running `cm_MacroRecord`.
    func recordingChanged(isRecording: Bool) {
        self.isRecording = isRecording
        applyRecordingTitle()
    }

    private func applyRecordingTitle() {
        recordButton.title = isRecording
            ? String(localized: "Stop Recording…") : String(localized: "Record Macro…")
        recordButton.toolTip = isRecording
            ? String(localized: "Stop the recording and choose which of its steps the macro keeps.")
            : String(localized: "Start recording. Do the steps in the panels, then stop — what happened in between becomes the macro.")
    }

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

    /// Whether an automation run is answering this window's dialogs instead of a person.
    static var isScripted: Bool { AutomationProbe.value("PC_MACRO_MANAGER_INPUT") != nil }

    /// Put `alert` up and say whether its first button was chosen — or answer it from the environment.
    ///
    /// `PC_MACRO_MANAGER_CONFIRM=0` says no; anything else, including the variable being absent while
    /// `PC_MACRO_MANAGER_INPUT` is set, says yes. A destructive question defaults to *yes* only
    /// because a scripted run has already declared itself scripted by setting the other variable.
    @MainActor
    static func confirm(_ alert: NSAlert) -> Bool {
        guard !isScripted else {
            return AutomationProbe.value("PC_MACRO_MANAGER_CONFIRM") != "0"
        }
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// A single-field prompt. Returns nil on cancel.
    @MainActor
    static func ask(_ message: String, value: String, in window: NSWindow?) -> String? {
        if let scripted = AutomationProbe.value("PC_MACRO_MANAGER_INPUT") {
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

    /// Where to write an exported macro. Answered from the environment in an automation run, for the
    /// reason the other dialogs here are: an open panel is a modal, and a modal in a headless run is a
    /// nested runloop the script never gets out of (F-436).
    @MainActor
    static func chooseExportFile(named name: String, in window: NSWindow?) -> URL? {
        if let scripted = AutomationProbe.value("PC_MACRO_EXPORT") {
            return URL(fileURLWithPath: scripted)
        }
        guard !isScripted else { return nil }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.message = String(localized: "Where should this macro be written?")
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    /// The files to import. `PC_MACRO_IMPORT` may name several, separated by `|`.
    @MainActor
    static func chooseImportFiles(in window: NSWindow?) -> [URL] {
        if let scripted = AutomationProbe.value("PC_MACRO_IMPORT") {
            return scripted.split(separator: "|").map { URL(fileURLWithPath: String($0)) }
        }
        guard !isScripted else { return [] }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json]
        panel.message = String(localized: "Which macro files should be added?")
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }

    @MainActor
    static func note(_ message: String, in window: NSWindow?) {
        guard !isScripted else { return }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = message
        alert.addButton(withTitle: String(localized: "OK"))
        if let window { alert.beginSheetModal(for: window) } else { alert.runModal() }
    }
}
