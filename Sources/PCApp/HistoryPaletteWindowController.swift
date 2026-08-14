// SPDX-License-Identifier: Apache-2.0
// HistoryPaletteWindowController.swift - The global history, as a command palette (F-402).
//
// One window, reachable from anywhere with ⌘⇧H, that answers "where was I / what did I just do" in a
// second or two without the mouse: the search field has focus the moment it opens, typing filters
// fuzzily as you go, ↑/↓ move through the results *while the caret stays in the field* (as Spotlight
// does — a palette that makes you Tab into the list has already lost the two seconds), and Return acts.
//
// Two decisions worth stating, because both could reasonably have gone the other way:
//
//   * **Backspace is not "remove entry".** The requirement asked for Del, and on this keyboard Del is
//     the key that fixes a typo in the search field. Removing an entry is ⌘⌫, the macOS gesture for
//     exactly that, and forward-delete does it too for a keyboard that has one.
//   * **Return on a shell command fills the command line rather than running it.** Everything else here
//     is safe to repeat; a shell line from three days ago, chosen from a list the user is skimming, is
//     one keystroke away from something they did not read. The line arrives ready to run.
//
// The window is deliberately not a panel and not borderless: it takes keyboard focus, holds a table with
// a selection, and has to be reachable by Tab for the same reasons every other window here does.

import AppKit
import PCFoundation

@MainActor
final class HistoryPaletteWindowController: NSWindowController, NSWindowDelegate,
                                            NSTableViewDataSource, NSTableViewDelegate,
                                            NSSearchFieldDelegate {

    /// What the palette asks the app to do. The window knows nothing about panels, operations or the
    /// Finder — it reports a choice and the host carries it out.
    enum Action {
        case openFolder(String)
        case openFile(String)
        case showInPanel(String)
        case repeatOperation(payload: String, directory: String)
        case fillCommandLine(String)
        case revealInFinder(String)
    }

    /// (action, side) — side 0 = left, 1 = right.
    var onAction: ((Action, Int) -> Void)?
    var onClose: (() -> Void)?

    private enum Filter: Int, CaseIterable {
        case all, folders, files, operations, pinned

        var kind: HistoryKind? {
            switch self {
            case .folders: return .folder
            case .files: return .file
            case .operations: return .operation
            case .all, .pinned: return nil
            }
        }
        var title: String {
            switch self {
            case .all: return String(localized: "All")
            case .folders: return String(localized: "Folders")
            case .files: return String(localized: "Files")
            case .operations: return String(localized: "Operations")
            case .pinned: return String(localized: "Favorites")
            }
        }
    }

    private let searchField = NSSearchField()
    private let filterControl = NSSegmentedControl()
    private let tableView = NSTableView()
    private let hintLabel = NSTextField(labelWithString: "")
    private var rows: [HistoryEntry] = []
    private var filter: Filter = .all
    /// Which panel an entry opens in; Tab flips it. Starts on the active panel's side, because "open
    /// this" most often means "here".
    private var targetSide: Int

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    init(targetSide: Int) {
        self.targetSide = targetSide
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 520),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = String(localized: "History")
        super.init(window: window)
        window.delegate = self
        let content = HistoryPaletteContentView()
        content.controller = self
        window.contentView = content
        buildUI()
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() {
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        KeyboardLoop.rebuild(for: window)
        // The whole point of the palette: type immediately, no click first.
        window?.makeFirstResponder(searchField)
        searchField.currentEditor()?.selectAll(nil)
    }

    // MARK: - Building

    private func buildUI() {
        guard let content = window?.contentView else { return }

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = String(localized: "Search folders, files, operations…")
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.setAccessibilityLabel(String(localized: "Search the history"))
        content.addSubview(searchField)

        filterControl.translatesAutoresizingMaskIntoConstraints = false
        filterControl.segmentCount = Filter.allCases.count
        filterControl.trackingMode = .selectOne
        for f in Filter.allCases {
            filterControl.setLabel(f.title, forSegment: f.rawValue)
            filterControl.setWidth(0, forSegment: f.rawValue)   // 0 = fit the label
        }
        filterControl.selectedSegment = filter.rawValue
        filterControl.target = self
        filterControl.action = #selector(filterChanged)
        filterControl.setAccessibilityLabel(String(localized: "History filter"))
        content.addSubview(filterControl)

        for (id, title, width) in [("what", String(localized: "Name"), CGFloat(240)),
                                   ("where", String(localized: "Path"), CGFloat(330)),
                                   ("when", String(localized: "When"), CGFloat(130)),
                                   ("uses", String(localized: "Uses"), CGFloat(50)),
                                   ("panel", String(localized: "Panel"), CGFloat(60))] {
            let column = NSTableColumn(identifier: .init(id))
            column.title = title
            column.width = width
            tableView.addTableColumn(column)
        }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 20
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.target = self
        tableView.doubleAction = #selector(openSelected)
        tableView.menu = buildContextMenu()
        tableView.setAccessibilityLabel(String(localized: "History entries"))

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        content.addSubview(scroll)

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.maximumNumberOfLines = 2
        content.addSubview(hintLabel)
        updateHint()

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),

            filterControl.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            filterControl.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),

            scroll.topAnchor.constraint(equalTo: filterControl.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),

            hintLabel.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 6),
            hintLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            hintLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            hintLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10)
        ])
        // The list takes the remaining height. Priority 999 so it cannot contradict the window during
        // setup, when the content view legitimately has no height yet.
        let listHeight = scroll.heightAnchor.constraint(greaterThanOrEqualTo: content.heightAnchor,
                                                       multiplier: 0.5)
        listHeight.priority = .init(999)
        listHeight.isActive = true
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        for (title, selector) in [(String(localized: "Open in Left Panel"), #selector(openInLeft)),
                                  (String(localized: "Open in Right Panel"), #selector(openInRight)),
                                  (String(localized: "Show in Finder"), #selector(revealSelected)),
                                  (String(localized: "Copy Path"), #selector(copyPathOfSelected)),
                                  (String(localized: "Pin or Unpin"), #selector(togglePinOfSelected)),
                                  (String(localized: "Remove from History"), #selector(removeSelected))] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        return menu
    }

    // MARK: - Data

    private func reload() {
        let query = searchField.stringValue
        rows = HistoryService.shared.ranked(kind: filter.kind, pinnedOnly: filter == .pinned,
                                            query: query)
        tableView.reloadData()
        if !rows.isEmpty {
            tableView.selectRowIndexes([0], byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
        updateHint()
    }

    private func updateHint() {
        let side = targetSide == 0 ? String(localized: "left panel") : String(localized: "right panel")
        hintLabel.stringValue = String(localized: """
            \(rows.count) entries · Target: \(side) (Tab to switch) · Return opens · ⌥Return shows in the panel \
            · ⌘1…⌘9 opens directly · ⌘⌫ removes · ⌘P pins · ⌘C copies the path · ⌥1…⌥5 filters
            """)
    }

    private var selected: HistoryEntry? {
        let row = tableView.selectedRow
        return (row >= 0 && row < rows.count) ? rows[row] : nil
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        guard row < rows.count, let id = tableColumn?.identifier.rawValue else { return nil }
        let entry = rows[row]
        let cell = NSTableCellView()
        let text = NSTextField(labelWithString: "")
        text.font = NSFont.systemFont(ofSize: 12)
        text.lineBreakMode = .byTruncatingMiddle
        text.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(text)
        cell.textField = text
        var leading: CGFloat = 2

        if id == "what" {
            let image = NSImageView(image: Self.icon(for: entry) ?? NSImage())
            image.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(image)
            cell.imageView = image
            NSLayoutConstraint.activate([
                image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                image.widthAnchor.constraint(equalToConstant: 14),
                image.heightAnchor.constraint(equalToConstant: 14)
            ])
            leading = 20
        }
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: leading),
            text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        switch id {
        case "what":
            text.stringValue = Self.displayName(entry)
            if entry.pinned { text.font = NSFont.boldSystemFont(ofSize: 12) }
        case "where":
            text.stringValue = (entry.path as NSString).abbreviatingWithTildeInPath
            text.textColor = .secondaryLabelColor
        case "when":
            text.stringValue = relativeFormatter.localizedString(for: entry.lastUsed, relativeTo: Date())
            text.textColor = .secondaryLabelColor
        case "uses":
            text.stringValue = String(entry.useCount)
            text.alignment = .right
            text.textColor = .secondaryLabelColor
        case "panel":
            text.stringValue = entry.panel.map {
                $0 == .left ? String(localized: "left") : String(localized: "right")
            } ?? ""
            text.textColor = .secondaryLabelColor
        default:
            break
        }
        return cell
    }

    private static func displayName(_ entry: HistoryEntry) -> String {
        switch entry.kind {
        case .folder, .file:
            let name = (entry.path as NSString).lastPathComponent
            return name.isEmpty ? entry.path : name
        case .operation, .command:
            return entry.detail
        }
    }

    private static func icon(for entry: HistoryEntry) -> NSImage? {
        let name: String
        switch entry.kind {
        case .folder:    name = "folder"
        case .file:      name = "doc"
        case .operation: name = "arrow.left.arrow.right"
        case .command:   name = "terminal"
        }
        return NSImage(systemSymbolName: entry.pinned ? "pin.fill" : name, accessibilityDescription: nil)
    }

    // MARK: - Keyboard

    /// ↑/↓/Return/Esc while the caret is in the search field.
    func control(_ control: NSControl, textView: NSTextView,
                 doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveDown(_:)):   move(1); return true
        case #selector(NSResponder.moveUp(_:)):     move(-1); return true
        case #selector(NSResponder.insertNewline(_:)):
            // ⌥Return arrives as insertNewlineIgnoringFieldEditor:, so plain Return is unambiguous here.
            act(on: selected, mode: .open)
            return true
        case #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)):
            act(on: selected, mode: .showInPanel)
            return true
        case #selector(NSResponder.insertTab(_:)):
            toggleTargetSide()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            close()
            return true
        case #selector(NSResponder.deleteForward(_:)):
            removeSelected()
            return true
        default:
            return false
        }
    }

    func controlTextDidChange(_ obj: Notification) { reload() }

    private func move(_ delta: Int) {
        guard !rows.isEmpty else { return }
        let next = max(0, min(rows.count - 1, tableView.selectedRow + delta))
        tableView.selectRowIndexes([next], byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    private func toggleTargetSide() {
        targetSide = targetSide == 0 ? 1 : 0
        updateHint()
    }

    /// ⌘1…⌘9 — jump straight to one of the nine most relevant entries.
    ///
    /// The only shortcut handled here rather than as a menu item: nine items in a menu would be nine
    /// lines of clutter for one idea, and while this window is key its *own* menu bar is installed, so
    /// ⌘1 is not the panel's view-mode command. Everything else is a real menu item, which is what makes
    /// it discoverable, remappable-looking and reachable by assistive technology — and what keeps ⌘C
    /// meaning "copy the search text" in a field that always has focus (see F-401).
    func handleKeyEquivalent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == .command, let characters = event.charactersIgnoringModifiers,
              let digit = Int(characters), digit >= 1, digit <= 9 else { return false }
        guard digit - 1 < rows.count else { return true }
        act(on: rows[digit - 1], mode: .open)
        return true
    }

    // MARK: - Acting

    private enum Mode { case open, showInPanel }

    @objc private func filterChanged() {
        filter = Filter(rawValue: filterControl.selectedSegment) ?? .all
        reload()
        window?.makeFirstResponder(searchField)
    }

    @objc private func openSelected() { act(on: selected, mode: .open) }
    @objc private func openInLeft() { act(on: selected, mode: .open, side: 0) }
    @objc private func openInRight() { act(on: selected, mode: .open, side: 1) }

    private func act(on entry: HistoryEntry?, mode: Mode, side: Int? = nil) {
        guard let entry else { NSSound.beep(); return }
        let side = side ?? targetSide
        // Counted as a use of *this* entry, and the navigation it causes is not recorded a second time:
        // opening something from the history is one event, not two.
        HistoryService.shared.touch(entry)
        let action: Action
        switch (entry.kind, mode) {
        case (.folder, _):
            action = .openFolder(entry.path)
        case (.file, .open):
            action = .openFile(entry.path)
        case (.file, .showInPanel):
            action = .showInPanel(entry.path)
        case (.operation, .open):
            // Repeatable (copy/move) → do it again; anything else → show where it happened, which is
            // what someone looking at a rename or a delete in a list actually wants.
            action = HistoryOperation.decode(entry.payload) == nil
                ? .showInPanel(entry.path)
                : .repeatOperation(payload: entry.payload, directory: entry.path)
        case (.operation, .showInPanel):
            action = .showInPanel(entry.path)
        case (.command, _):
            action = .fillCommandLine(entry.detail)
        }
        onAction?(action, side)
        close()
    }

    @objc private func revealSelected() {
        guard let entry = selected else { return }
        onAction?(.revealInFinder(entry.path), targetSide)
    }

    @objc private func copyPathOfSelected() {
        guard let entry = selected else { return }
        let text = entry.kind == .command ? entry.detail : entry.path
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func togglePinOfSelected() {
        guard let entry = selected else { return }
        HistoryService.shared.togglePinned(entry)
        let row = tableView.selectedRow
        reload()
        if row >= 0, row < rows.count { tableView.selectRowIndexes([row], byExtendingSelection: false) }
    }

    @objc private func removeSelected() {
        guard let entry = selected else { return }
        let row = tableView.selectedRow
        HistoryService.shared.remove(entry)
        reload()
        // Keep the cursor where it was, so a run of removals does not send it back to the top each time.
        if !rows.isEmpty {
            let next = min(max(0, row), rows.count - 1)
            tableView.selectRowIndexes([next], byExtendingSelection: false)
            tableView.scrollRowToVisible(next)
        }
    }

    func windowWillClose(_ notification: Notification) { onClose?() }

    @objc private func filterAll() { setFilter(.all) }
    @objc private func filterFolders() { setFilter(.folders) }
    @objc private func filterFiles() { setFilter(.files) }
    @objc private func filterOperations() { setFilter(.operations) }
    @objc private func filterPinned() { setFilter(.pinned) }
    @objc private func showSelectedInPanel() { act(on: selected, mode: .showInPanel) }
    @objc private func switchTargetPanel() { toggleTargetSide() }

    private func setFilter(_ f: Filter) {
        filter = f
        filterControl.selectedSegment = f.rawValue
        reload()
        window?.makeFirstResponder(searchField)
    }

    #if DEBUG
    /// The palette's own menu, for the harness to dump (F-402).
    func automationMenu() -> NSMenu { makeWindowMenu() }

    /// What the palette is showing, for the harness (F-402). The rows as the user sees them, in order.
    func automationSummary() -> String {
        var out = "filter=\(filter.title)\nquery=\(searchField.stringValue)\n"
        out += "target=\(targetSide == 0 ? "left" : "right")\n"
        out += "responder=\((window?.firstResponder as? NSView).map { String(describing: type(of: $0)) } ?? "")\n"
        out += "count=\(rows.count)\nselected=\(tableView.selectedRow)\n"
        for entry in rows.prefix(20) {
            out += "row=\(entry.kind.rawValue)|\(Self.displayName(entry))|\(entry.path)"
                + "|uses=\(entry.useCount)|pinned=\(entry.pinned ? 1 : 0)\n"
        }
        return out
    }

    /// Drive the palette from a script: type, filter, move, act.
    func automationType(_ text: String) {
        searchField.stringValue = text
        reload()
    }
    func automationSetFilter(_ index: Int) {
        filter = Filter(rawValue: index) ?? .all
        filterControl.selectedSegment = filter.rawValue
        reload()
    }
    func automationMove(_ delta: Int) { move(delta) }
    func automationToggleTarget() { toggleTargetSide() }
    func automationOpenSelected(showInPanel: Bool = false) {
        act(on: selected, mode: showInPanel ? .showInPanel : .open)
    }
    func automationRemoveSelected() { removeSelected() }
    func automationTogglePin() { togglePinOfSelected() }
    func automationCopyPath() { copyPathOfSelected() }
    #endif
}

// MARK: - Its own menu bar while it is key

/// The palette's actions as menu items rather than as private key handling.
///
/// Three things follow from doing it this way, and all three were learned elsewhere in this app: the
/// keys cannot be shadowed by the panel's own (⌘P, ⌘⌫ and the filter keys belong to whatever window is
/// key), a screen reader can find the actions at all, and the Edit menu stays *standard* — so ⌘C in a
/// search field that always has focus copies the search text, which is what F-401 was about.
@MainActor
extension HistoryPaletteWindowController: WindowContextMenuProviding {
    func makeWindowMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "History"))
        func add(_ title: String, _ selector: Selector, _ key: String = "",
                 _ mask: NSEvent.ModifierFlags = .command) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            if !key.isEmpty { item.keyEquivalentModifierMask = mask }
            item.target = self
            menu.addItem(item)
        }
        // Return and ⌥Return are the field's, so they carry no key equivalent here — a menu item would
        // take Return away from the search field, which is where the user is typing.
        add(String(localized: "Open"), #selector(openSelected))
        add(String(localized: "Show in Panel"), #selector(showSelectedInPanel))
        add(String(localized: "Switch Target Panel"), #selector(switchTargetPanel))
        menu.addItem(.separator())
        add(String(localized: "Open in Left Panel"), #selector(openInLeft))
        add(String(localized: "Open in Right Panel"), #selector(openInRight))
        add(String(localized: "Show in Finder"), #selector(revealSelected), "r", [.command, .shift])
        // ⌥⌘C, as Finder uses for "Copy as Pathname" — ⌘C belongs to the search field.
        add(String(localized: "Copy Path"), #selector(copyPathOfSelected), "c", [.command, .option])
        add(String(localized: "Pin or Unpin"), #selector(togglePinOfSelected), "p")
        add(String(localized: "Remove from History"), #selector(removeSelected), "\u{8}")
        menu.addItem(.separator())
        for (title, selector, digit) in [
            (String(localized: "All"), #selector(filterAll), "1"),
            (String(localized: "Folders"), #selector(filterFolders), "2"),
            (String(localized: "Files"), #selector(filterFiles), "3"),
            (String(localized: "Operations"), #selector(filterOperations), "4"),
            (String(localized: "Favorites"), #selector(filterPinned), "5")
        ] {
            add(title, selector, digit, .option)
        }
        return menu
    }
}

/// Content view that offers ⌘1…⌘9 to the controller before anything else claims them.
final class HistoryPaletteContentView: NSView {
    weak var controller: HistoryPaletteWindowController?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if controller?.handleKeyEquivalent(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}
