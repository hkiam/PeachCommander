// SPDX-License-Identifier: Apache-2.0
// csv_lister.swift — a Swift PLX lister plugin (SPEC-012 §3, I16 T02).
//
// Renders a .csv file as a real NSTableView, proving the PLX host can embed a
// plugin-provided AppKit view in the Lister (F3) window. Unlike the C sample
// fixtures, this returns a genuine NSView*, which is what ListLoad's contract
// promises on macOS. Built into a CSVLister.plxplugin bundle by
// Tools/build-csvlister-plugin.sh and loaded via dlopen like any PLX plugin.
//
// All view work must happen on the main thread; the host calls these entry
// points from its @MainActor lister flow.

import AppKit

// MARK: - The plugin's content view

final class CSVListerView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let scroll = NSScrollView()
    private let table = NSTableView()
    private let columnPopup = NSPopUpButton()
    private let searchField = NSSearchField()
    private let headerToggle = NSButton(checkboxWithTitle: "First row is header", target: nil, action: nil)
    private var header: [String] = []
    private var allRows: [[String]] = []   // unfiltered, unsorted source
    private var rows: [[String]] = []       // currently displayed (filtered + sorted)
    private var sortColumn: Int?
    private var sortAscending = true
    /// The document, kept so the header question can be answered again without re-reading the file.
    private let source: String
    /// What the reader chose, or `auto` until they do.
    private var headerMode: PluginCSV.HeaderMode = .auto

    init(csv: String) {
        source = csv
        super.init(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        parse()
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// (Re)read the document with the current header mode. `PluginCSV` holds the parsing and the guess.
    private func parse() {
        let table = PluginCSV.parse(source, headerMode: headerMode)
        header = table.header
        allRows = table.rows
        rows = allRows
        headerToggle.state = table.usedHeader ? .on : .off
    }

    // MARK: - Pure filter/sort logic (isolated for clarity/testability)

    /// Keep rows where `needle` (case-insensitive substring) matches: a specific
    /// column when `columnIndex` is set, otherwise any column. Empty needle = all rows.
    static func filtered(_ rows: [[String]], columnIndex: Int?, needle: String) -> [[String]] {
        let n = needle.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return rows }
        return rows.filter { row in
            if let c = columnIndex {
                return c < row.count && row[c].range(of: n, options: .caseInsensitive) != nil
            }
            return row.contains { $0.range(of: n, options: .caseInsensitive) != nil }
        }
    }

    /// Sort by one column. Numeric when both cells parse as numbers, else a
    /// case-insensitive localized string compare. Stable direction via `ascending`.
    static func sorted(_ rows: [[String]], by columnIndex: Int, ascending: Bool) -> [[String]] {
        func cell(_ r: [String]) -> String { columnIndex < r.count ? r[columnIndex] : "" }
        let out = rows.sorted { a, b in
            let x = cell(a), y = cell(b)
            if let nx = Double(x), let ny = Double(y), nx != ny { return nx < ny }
            let cmp = x.compare(y, options: .caseInsensitive)
            return cmp == .orderedAscending
        }
        return ascending ? out : out.reversed()
    }

    private func applyFilterAndSort() {
        let colIndex = columnPopup.indexOfSelectedItem - 1   // 0 == "All columns"
        var result = Self.filtered(allRows, columnIndex: colIndex >= 0 ? colIndex : nil,
                                   needle: searchField.stringValue)
        if let sc = sortColumn { result = Self.sorted(result, by: sc, ascending: sortAscending) }
        rows = result
        table.reloadData()
    }

    @objc private func filterChanged() { applyFilterAndSort() }

    private func build() {
        if header.isEmpty { header = ["(empty)"] }

        // Filter bar: a column selector + a search field (filters as you type).
        let filterBar = NSStackView()
        filterBar.translatesAutoresizingMaskIntoConstraints = false
        filterBar.orientation = .horizontal
        filterBar.spacing = 8
        filterBar.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        columnPopup.target = self
        columnPopup.action = #selector(filterChanged)
        searchField.placeholderString = "Filter…"
        searchField.target = self
        searchField.action = #selector(filterChanged)
        searchField.sendsSearchStringImmediately = false
        searchField.sendsWholeSearchString = false
        let label = NSTextField(labelWithString: "Filter:")
        // The header question, answered where the table is: a file that starts straight into data used to
        // lose its first record to the column titles, and nothing on screen said so or could undo it.
        headerToggle.target = self
        headerToggle.action = #selector(headerToggleChanged)
        headerToggle.toolTip = "Whether the first line names the columns. Guessed when the file is opened."
        filterBar.addArrangedSubview(label)
        filterBar.addArrangedSubview(columnPopup)
        filterBar.addArrangedSubview(searchField)
        filterBar.addArrangedSubview(headerToggle)
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addSubview(filterBar)

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        table.usesAlternatingRowBackgroundColors = true
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.rowHeight = 18

        rebuildColumns()
        table.dataSource = self
        table.delegate = self
        scroll.documentView = table
        addSubview(scroll)
        NSLayoutConstraint.activate([
            filterBar.topAnchor.constraint(equalTo: topAnchor),
            filterBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            filterBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: filterBar.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    /// (Re)create the table columns and the filter popup from the current `header`.
    ///
    /// Both are derived from the same array, so switching the header row on or off has to redo both or the
    /// popup would offer titles the table no longer has — and the popup's selection is an index into them.
    private func rebuildColumns() {
        for col in table.tableColumns { table.removeTableColumn(col) }
        for (i, title) in header.enumerated() {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c\(i)"))
            col.title = title.isEmpty ? "Column \(i + 1)" : title
            col.width = 140
            table.addTableColumn(col)
        }
        columnPopup.removeAllItems()
        columnPopup.addItem(withTitle: "All columns")
        for (i, title) in header.enumerated() {
            columnPopup.addItem(withTitle: title.isEmpty ? "Column \(i + 1)" : title)
        }
    }

    /// The reader answered the header question: re-read the document that way.
    ///
    /// The sort is dropped, because a sort is by column index and the columns are being replaced; the
    /// filter text is kept, since it is the reader's and still means the same thing.
    @objc private func headerToggleChanged() {
        headerMode = headerToggle.state == .on ? .header : .noHeader
        sortColumn = nil
        for col in table.tableColumns { table.setIndicatorImage(nil, in: col) }
        table.highlightedTableColumn = nil
        parse()
        if header.isEmpty { header = ["(empty)"] }
        rebuildColumns()
        applyFilterAndSort()
    }

    /// Click a column header to sort by it; click again to reverse.
    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        guard let colIndex = Int(tableColumn.identifier.rawValue.dropFirst()) else { return }
        if sortColumn == colIndex { sortAscending.toggle() } else { sortColumn = colIndex; sortAscending = true }
        for col in tableView.tableColumns { tableView.setIndicatorImage(nil, in: col) }
        tableView.setIndicatorImage(
            NSImage(named: sortAscending ? "NSAscendingSortIndicator" : "NSDescendingSortIndicator"),
            in: tableColumn)
        tableView.highlightedTableColumn = tableColumn
        applyFilterAndSort()
    }

    /// Select and reveal the first row containing `needle`; returns whether found.
    func find(_ needle: String, matchCase: Bool) -> Bool {
        let compare: (String) -> Bool = matchCase
            ? { $0.contains(needle) }
            : { $0.range(of: needle, options: .caseInsensitive) != nil }
        for (r, row) in rows.enumerated() where row.contains(where: compare) {
            table.selectRowIndexes(IndexSet(integer: r), byExtendingSelection: false)
            table.scrollRowToVisible(r)
            return true
        }
        return false
    }

    // NSTableViewDataSource / delegate
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn,
              let colIndex = Int(tableColumn.identifier.rawValue.dropFirst()),
              rows.indices.contains(row), rows[row].indices.contains(colIndex) else { return nil }
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell = (tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField)
            ?? { let tf = NSTextField(labelWithString: ""); tf.identifier = id
                 tf.font = .monospacedSystemFont(ofSize: 11, weight: .regular); return tf }()
        cell.stringValue = rows[row][colIndex]
        return cell
    }
}

// MARK: - PLX C-ABI exports (plx.h)

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("ListGetDetectString")
public func ListGetDetectString(_ buf: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) {
    guard let buf, maxlen > 0 else { return }
    let detect = "EXT=\"CSV\" | EXT=\"TSV\""
    _ = detect.withCString { src in strlcpy(buf, src, Int(maxlen)) }
}

@_cdecl("ListLoad")
public func ListLoad(_ parent: UnsafeMutableRawPointer?, _ file: UnsafeMutablePointer<CChar>?,
                     _ showFlags: Int32) -> UnsafeMutableRawPointer? {
    guard let file, let path = String(validatingUTF8: file),
          let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
    let view = CSVListerView(csv: text)
    // Hand the host a retained NSView*; ListCloseWindow balances this.
    return Unmanaged.passRetained(view).toOpaque()
}

@_cdecl("ListCloseWindow")
public func ListCloseWindow(_ listWin: UnsafeMutableRawPointer?) {
    guard let listWin else { return }
    Unmanaged<CSVListerView>.fromOpaque(listWin).release()
}

@_cdecl("ListSearchText")
public func ListSearchText(_ listWin: UnsafeMutableRawPointer?, _ searchString: UnsafeMutablePointer<CChar>?,
                           _ options: Int32) -> Int32 {
    guard let listWin, let searchString, let needle = String(validatingUTF8: searchString) else { return 1 }
    let view = Unmanaged<CSVListerView>.fromOpaque(listWin).takeUnretainedValue()
    return view.find(needle, matchCase: options & 0x0001 != 0) ? 0 : 1
}
