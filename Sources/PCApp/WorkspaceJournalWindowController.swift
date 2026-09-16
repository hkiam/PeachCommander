// SPDX-License-Identifier: Apache-2.0
// WorkspaceJournalWindowController.swift - "What did I actually do here?" (F-499).
//
// A window of its own rather than a filter in the history palette, and the reason is structural: that
// palette's data source is a frecency ranking, and this is a chronology. Bolting a "this workspace"
// segment onto it would hand somebody their afternoon sorted by a score nobody asked for, and force a
// second data source into a window whose whole design is one.
//
// What it *does* copy from the palette is everything people already know: the search field has focus
// the moment it opens, typing filters as you go, ↑/↓ move through the rows while the caret stays in
// the field, and Return acts. A window that makes you Tab into the list has already lost the two
// seconds it exists to save.
//
// **The "Problems" filter is what earns this window.** Everything that failed or was refused, in one
// place — and the refusals are recorded nowhere else in the application.

import AppKit
import PCFoundation

@MainActor
final class WorkspaceJournalWindowController: NSWindowController, NSTableViewDataSource,
                                              NSTableViewDelegate, NSTextFieldDelegate {

    var onRepeat: ((JournalEntry) -> Void)?
    var onClear: (() -> Void)?

    private let journal: WorkspaceJournal
    private let workspaceName: String
    private var rows: [Row] = []

    /// A day header or an entry. Flattened into one list so the table stays a table — an outline view
    /// for two levels would cost an expandable state nobody wants to manage.
    private enum Row {
        case day(Date)
        case entry(JournalEntry)
    }

    private let search = NSTextField()
    private let filters = NSSegmentedControl()
    private let table = NSTableView()
    private let hint = NSTextField(labelWithString: "")

    /// Index-free, so a filter change cannot leave it pointing at a row that no longer exists.
    private var selectedEntry: JournalEntry? {
        guard table.selectedRow >= 0, rows.indices.contains(table.selectedRow),
              case .entry(let e) = rows[table.selectedRow] else { return nil }
        return e
    }

    init(journal: WorkspaceJournal, workspaceName: String) {
        self.journal = journal
        self.workspaceName = workspaceName
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 460),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = workspaceName.isEmpty
            ? String(localized: "Journal")
            : String(format: String(localized: "Journal — %@"), workspaceName)
        super.init(window: window)
        buildUI()
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Layout

    private func buildUI() {
        guard let content = window?.contentView else { return }

        search.placeholderString = String(localized: "Search this journal")
        search.delegate = self
        search.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(search)

        filters.segmentCount = Filter.allCases.count
        for (i, filter) in Filter.allCases.enumerated() {
            filters.setLabel(filter.title, forSegment: i)
        }
        filters.selectedSegment = 0
        filters.target = self
        filters.action = #selector(filterChanged)
        filters.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(filters)

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)

        table.headerView = nil
        table.rowHeight = 20
        table.dataSource = self
        table.delegate = self
        table.usesAlternatingRowBackgroundColors = true
        let column = NSTableColumn(identifier: .init("entry"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.doubleAction = #selector(repeatSelected)
        table.target = self

        hint.stringValue = String(localized: "Return repeats · ⌘C copies the folder")
        hint.textColor = .secondaryLabelColor
        hint.font = Fonts.system13
        hint.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(hint)

        let copyText = NSButton(title: String(localized: "Copy as Text"),
                                target: self, action: #selector(copyAsText))
        let clear = NSButton(title: String(localized: "Clear Journal…"),
                             target: self, action: #selector(clearJournal))
        let close = NSButton(title: String(localized: "Close"), target: self, action: #selector(closeWindow))
        close.keyEquivalent = "\u{1b}"
        for button in [copyText, clear, close] {
            button.bezelStyle = .rounded
            button.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(button)
        }

        NSLayoutConstraint.activate([
            search.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            search.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            search.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),

            filters.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 8),
            filters.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),

            scroll.topAnchor.constraint(equalTo: filters.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: hint.topAnchor, constant: -8),

            hint.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            hint.bottomAnchor.constraint(equalTo: close.topAnchor, constant: -10),

            close.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            close.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            clear.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -8),
            clear.centerYAnchor.constraint(equalTo: close.centerYAnchor),
            copyText.trailingAnchor.constraint(equalTo: clear.leadingAnchor, constant: -8),
            copyText.centerYAnchor.constraint(equalTo: close.centerYAnchor),
        ])
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        // Focus in the field, the way the palette opens. Anything else costs the two seconds.
        window?.makeFirstResponder(search)
    }

    // MARK: - Filters

    private enum Filter: CaseIterable {
        case all, places, operations, commands, problems

        var title: String {
            switch self {
            case .all: return String(localized: "All")
            case .places: return String(localized: "Places")
            case .operations: return String(localized: "Operations")
            case .commands: return String(localized: "Commands")
            case .problems: return String(localized: "Problems")
            }
        }

        var kind: JournalEntry.Kind? {
            switch self {
            case .all, .problems: return nil
            case .places: return .navigation
            case .operations: return .operation
            case .commands: return .command
            }
        }
    }

    private var filter: Filter {
        Filter.allCases.indices.contains(filters.selectedSegment)
            ? Filter.allCases[filters.selectedSegment] : .all
    }

    @objc private func filterChanged() { reload() }
    func controlTextDidChange(_ obj: Notification) { reload() }

    private func reload() {
        let matched = journal.filtered(kind: filter.kind,
                                       problemsOnly: filter == .problems,
                                       query: search.stringValue)
        // Grouped by day out of the filtered set rather than the whole journal, so a day with nothing
        // left in it does not leave a header behind.
        var built: [Row] = []
        var lastDay: Date?
        let calendar = Calendar.current
        for entry in matched {
            let day = calendar.startOfDay(for: entry.at)
            if day != lastDay { built.append(.day(day)); lastDay = day }
            built.append(.entry(entry))
        }
        rows = built
        table.reloadData()
        if !rows.isEmpty, table.selectedRow < 0 { selectFirstEntry() }
    }

    private func selectFirstEntry() {
        guard let index = rows.firstIndex(where: { if case .entry = $0 { return true }; return false })
        else { return }
        table.selectRowIndexes([index], byExtendingSelection: false)
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let label = NSTextField(labelWithString: "")
        label.font = Fonts.system13
        switch rows[row] {
        case .day(let day):
            label.stringValue = Self.dayFormatter.string(from: day)
            label.font = Fonts.bold13
        case .entry(let entry):
            label.stringValue = Self.describe(entry)
            if entry.isProblem { label.textColor = .systemRed }
        }
        return label
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if case .day = rows[row] { return false }
        return true
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        f.doesRelativeDateFormatting = true   // "Today", "Yesterday"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static func describe(_ entry: JournalEntry) -> String {
        let time = timeFormatter.string(from: entry.at)
        let mark: String
        switch entry.outcome {
        case .done: mark = entry.kind == .command ? "$" : "✓"
        case .failed: mark = "⚠"
        case .refused: mark = "⛔"
        }
        let folder = (entry.directory as NSString).abbreviatingWithTildeInPath
        var line = "  \(time)  \(mark)  \(entry.label)"
        if !folder.isEmpty { line += "   \(folder)" }
        if let reason = entry.reason { line += "  —  \(reason)" }
        return line
    }

    // MARK: - Actions

    @objc private func repeatSelected() {
        guard let entry = selectedEntry else { NSSound.beep(); return }
        onRepeat?(entry)
    }

    @objc private func copyAsText() {
        let text = rows.map { row -> String in
            switch row {
            case .day(let day): return Self.dayFormatter.string(from: day)
            case .entry(let entry): return Self.describe(entry)
            }
        }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func clearJournal() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Clear this workspace's journal?")
        alert.informativeText = String(localized:
            "The record of what was done here is deleted. The files themselves are not touched.")
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.addButton(withTitle: String(localized: "Clear"))
        alert.alertStyle = .warning
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        onClear?()
        close()
    }

    @objc private func closeWindow() { close() }

    // MARK: - Keyboard

    /// ↑/↓ move the selection while the caret stays in the search field, and Return acts — the
    /// palette's behaviour, because people already have it.
    func control(_ control: NSControl, textView: NSTextView,
                 doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveDown(_:)): move(1); return true
        case #selector(NSResponder.moveUp(_:)): move(-1); return true
        case #selector(NSResponder.insertNewline(_:)): repeatSelected(); return true
        case #selector(NSResponder.cancelOperation(_:)): close(); return true
        default: return false
        }
    }

    private func move(_ delta: Int) {
        var row = table.selectedRow
        repeat {
            row += delta
            guard rows.indices.contains(row) else { return }
        } while !tableView(table, shouldSelectRow: row)
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }
}
