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
    private var header: [String] = []
    private var allRows: [[String]] = []   // unfiltered, unsorted source
    private var rows: [[String]] = []       // currently displayed (filtered + sorted)
    private var sortColumn: Int?
    private var sortAscending = true

    init(csv: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        parse(csv)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Very small CSV split: lines on \n (\r trimmed); the field delimiter is
    /// auto-detected among , ; tab | : (most consistent across the first lines);
    /// optional surrounding double quotes are stripped. Enough for a reference renderer.
    private func parse(_ csv: String) {
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.hasSuffix("\r") ? String($0.dropLast()) : String($0) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return }
        let delimiter = Self.detectDelimiter(lines)
        func fields(_ line: String) -> [String] {
            line.split(separator: delimiter, omittingEmptySubsequences: false).map {
                var s = String($0)
                if s.hasPrefix("\""), s.hasSuffix("\""), s.count >= 2 { s = String(s.dropFirst().dropLast()) }
                return s
            }
        }
        header = fields(lines[0])
        allRows = lines.dropFirst().map(fields)
        rows = allRows
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

    /// Pick the delimiter whose per-line occurrence count is most consistent (and > 0)
    /// across a sample of lines, favouring more columns to break ties.
    static func detectDelimiter(_ lines: [String]) -> Character {
        let candidates: [Character] = [",", ";", "\t", "|", ":"]
        let sample = Array(lines.prefix(20))
        var best: Character = ","
        var bestScore = 0.0
        for d in candidates {
            let counts = sample.map { line in line.reduce(0) { $1 == d ? $0 + 1 : $0 } }
            let sorted = counts.sorted()
            let modal = sorted[sorted.count / 2]
            guard modal > 0 else { continue }
            let consistent = Double(counts.filter { $0 == modal }.count) / Double(counts.count)
            let score = consistent * Double(modal)
            if score > bestScore { bestScore = score; best = d }
        }
        return best
    }

    private func build() {
        if header.isEmpty { header = ["(empty)"] }

        // Filter bar: a column selector + a search field (filters as you type).
        let filterBar = NSStackView()
        filterBar.translatesAutoresizingMaskIntoConstraints = false
        filterBar.orientation = .horizontal
        filterBar.spacing = 8
        filterBar.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        columnPopup.addItem(withTitle: "All columns")
        for (i, title) in header.enumerated() {
            columnPopup.addItem(withTitle: title.isEmpty ? "Column \(i + 1)" : title)
        }
        columnPopup.target = self
        columnPopup.action = #selector(filterChanged)
        searchField.placeholderString = "Filter…"
        searchField.target = self
        searchField.action = #selector(filterChanged)
        searchField.sendsSearchStringImmediately = false
        searchField.sendsWholeSearchString = false
        let label = NSTextField(labelWithString: "Filter:")
        filterBar.addArrangedSubview(label)
        filterBar.addArrangedSubview(columnPopup)
        filterBar.addArrangedSubview(searchField)
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addSubview(filterBar)

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        table.usesAlternatingRowBackgroundColors = true
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.rowHeight = 18

        for (i, title) in header.enumerated() {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c\(i)"))
            col.title = title.isEmpty ? "Column \(i + 1)" : title
            col.width = 140
            table.addTableColumn(col)
        }
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
