// SPDX-License-Identifier: Apache-2.0
// StringsSidebar.swift - The strings panel shared by the hex viewer and the hex editor
// (F-489): every readable run in the file, in every encoding at once, and a click puts the
// hex view on it.
//
// Deliberately the same shape as `SymbolSidebar` — a filter field over a list, collapsed to
// zero width when it is off, opened from a toolbar toggle — because it answers the same
// question about a different kind of file. In a source file the structure worth jumping
// around by is its definitions; in a binary it is its strings, and in both cases the panel
// is a table of contents rather than a search.
//
// **Only in hex.** The toggle is disabled in every other representation, and the owner
// hides an open panel when the representation changes. A strings list beside a rendered
// image or a syntax-highlighted source file would be answering a question nobody asked
// there — in text mode the text *is* the strings.
//
// The list is a view of the scan, not the scan: filtering, and the encodings and length that
// shape it, are separate. Typing in the filter never re-reads the file; changing the length
// or the encodings does, because those change what "a string" means.

import AppKit
import PCFoundation

@MainActor
final class StringsSidebar: NSView {
    /// Called when a row is chosen: show me these bytes.
    var onSelect: ((FoundString) -> Void)?

    private let search = NSSearchField()
    private let lengthField = NSTextField()
    private let encodingsButton = NSPopUpButton()
    private let table = NSTableView()
    private let scroll = NSScrollView()
    private let status = NSTextField(labelWithString: "")
    private let job = StringScanJob()

    private var source: StringScanJob.Source?
    private var all: [FoundString] = []
    private var shown: [FoundString] = []
    private var truncated = false
    private var options = StringScanOptions()
    /// The dimmed text colour for the offset and encoding columns and the two labels.
    ///
    /// Derived from the palette, never borrowed from the system. `.secondaryLabelColor` follows
    /// the *macOS* appearance rather than the app's theme, so under Midnight it resolved to
    /// near-black on a near-black panel — the colour audit found forty findings at a contrast
    /// ratio of 1.1, which is text nobody can read. `quietened` dims the theme's own text
    /// against the theme's own background and holds a floor of 4.0 while doing it.
    private let dimmedText = ColourContrast.quietened(Theme.current.listText,
                                                      on: Theme.current.listBackground)

    // MARK: - Construction

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = Theme.current.listBackground.cgColor

        search.placeholderString = String(localized: "Filter strings")
        search.controlSize = .small
        search.font = NSFont.systemFont(ofSize: 11)
        search.target = self
        search.action = #selector(filterChanged)
        search.sendsSearchStringImmediately = true
        search.delegate = self
        search.translatesAutoresizingMaskIntoConstraints = false
        addSubview(search)

        let lengthLabel = NSTextField(labelWithString: String(localized: "Min. length:"))
        lengthLabel.font = NSFont.systemFont(ofSize: 11)
        lengthLabel.textColor = dimmedText
        lengthLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lengthLabel)

        lengthField.stringValue = String(options.minimumLength)
        lengthField.alignment = .right
        lengthField.controlSize = .small
        lengthField.font = NSFont.systemFont(ofSize: 11)
        lengthField.target = self
        lengthField.action = #selector(lengthChanged)
        lengthField.setAccessibilityLabel(String(localized: "Minimum string length"))
        lengthField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lengthField)

        encodingsButton.pullsDown = true
        encodingsButton.controlSize = .small
        encodingsButton.font = NSFont.systemFont(ofSize: 11)
        encodingsButton.setAccessibilityLabel(String(localized: "Encodings"))
        encodingsButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(encodingsButton)
        rebuildEncodingsMenu()

        table.setAccessibilityLabel(String(localized: "Strings"))
        table.headerView = NSTableHeaderView()
        table.rowSizeStyle = .small
        table.backgroundColor = Theme.current.listBackground
        table.usesAlternatingRowBackgroundColors = false
        table.allowsEmptySelection = true
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(rowChosen)
        for (id, title, width) in [("offset", String(localized: "Offset"), CGFloat(68)),
                                   ("encoding", String(localized: "Enc."), CGFloat(32)),
                                   ("text", String(localized: "String"), CGFloat(232))] {
            let column = NSTableColumn(identifier: .init(id))
            column.title = title
            column.width = width
            column.resizingMask = id == "text" ? .autoresizingMask : .userResizingMask
            table.addTableColumn(column)
        }

        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = Theme.current.listBackground
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        status.font = NSFont.systemFont(ofSize: 10)
        status.textColor = dimmedText
        status.translatesAutoresizingMaskIntoConstraints = false
        addSubview(status)

        // A hidden panel is `width == 0`, and insets plus a search field do not fit in
        // nothing. Same shape (and same priority) as the symbol sidebar's filter field: the
        // inset is how it should look, and a collapsed container is a real state, not a
        // contradiction.
        let sides = [
            search.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            search.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            lengthLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            lengthField.leadingAnchor.constraint(equalTo: lengthLabel.trailingAnchor, constant: 4),
            lengthField.widthAnchor.constraint(equalToConstant: 42),
            encodingsButton.leadingAnchor.constraint(equalTo: lengthField.trailingAnchor, constant: 6),
            encodingsButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
            status.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            status.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
        ]
        for side in sides { side.priority = .init(999) }
        NSLayoutConstraint.activate(sides + [
            search.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            lengthLabel.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 6),
            lengthField.centerYAnchor.constraint(equalTo: lengthLabel.centerYAnchor),
            encodingsButton.centerYAnchor.constraint(equalTo: lengthLabel.centerYAnchor),
            scroll.topAnchor.constraint(equalTo: lengthLabel.bottomAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -3),
            status.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
        updateStatus()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Scanning

    /// Scan `source` and show what it finds. Repeated calls replace the running scan.
    func load(_ source: StringScanJob.Source) {
        self.source = source
        rescan()
    }

    /// Forget everything and stop any scan (the representation changed, or the window closed).
    func clear() {
        job.cancel()
        source = nil
        all = []
        shown = []
        truncated = false
        table.reloadData()
        updateStatus()
    }

    /// Re-read the current source with the current options.
    private func rescan() {
        guard let source else { return }
        all = []
        shown = []
        truncated = false
        table.reloadData()
        updateStatus()
        job.start(source, options: options,
                  onProgress: { [weak self] fraction in self?.showProgress(fraction) },
                  onFinished: { [weak self] hits, cut in
                      guard let self else { return }
                      self.job.markFinished()
                      self.all = hits
                      self.truncated = cut
                      self.applyFilter()
                  })
    }

    private func showProgress(_ fraction: Double) {
        guard fraction < 1 else { return }
        status.stringValue = String(format: String(localized: "Scanning… %d%%"), Int(fraction * 100))
    }

    // MARK: - Filtering and display

    @objc private func filterChanged() { applyFilter() }

    private func applyFilter() {
        let query = search.stringValue.trimmingCharacters(in: .whitespaces)
        shown = query.isEmpty ? all : all.filter { $0.text.localizedCaseInsensitiveContains(query) }
        table.reloadData()
        updateStatus()
    }

    private func updateStatus() {
        if source == nil {
            status.stringValue = ""
            return
        }
        var text = String(format: String(localized: "%d string(s)"), shown.count)
        if shown.count != all.count {
            text = String(format: String(localized: "%d of %d string(s)"), shown.count, all.count)
        }
        if truncated {
            text += " · " + String(localized: "list cut short")
        }
        status.stringValue = text
    }

    @objc private func lengthChanged() {
        let wanted = Int(lengthField.stringValue) ?? options.minimumLength
        options = StringScanOptions(minimumLength: wanted, maximumLength: options.maximumLength,
                                    encodings: options.encodings, plausibleOnly: options.plausibleOnly)
        // Read it back: the options clamp, and a field still showing what was typed while
        // the scan used something else is a small lie that costs a bug report.
        lengthField.stringValue = String(options.minimumLength)
        rescan()
    }

    // MARK: - The encodings menu

    /// Short label for the table's narrow encoding column.
    private static func tag(_ kind: StringEncodingKind) -> String {
        switch kind {
        case .ascii: return "A"
        case .latin1: return "L1"
        case .utf8: return "U8"
        case .utf16le: return "16L"
        case .utf16be: return "16B"
        }
    }

    private static func name(_ kind: StringEncodingKind) -> String {
        switch kind {
        case .ascii: return String(localized: "ASCII")
        case .latin1: return String(localized: "Latin-1")
        case .utf8: return String(localized: "UTF-8")
        case .utf16le: return String(localized: "UTF-16 LE")
        case .utf16be: return String(localized: "UTF-16 BE")
        }
    }

    private func rebuildEncodingsMenu() {
        let menu = NSMenu()
        // A pull-down button shows item 0 as its title and never as a choice.
        menu.addItem(withTitle: String(localized: "Encodings"), action: nil, keyEquivalent: "")
        for kind in StringEncodingKind.allCases {
            let item = NSMenuItem(title: Self.name(kind), action: #selector(encodingToggled(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = kind.rawValue
            item.state = options.encodings.contains(kind) ? .on : .off
            if kind == .latin1 {
                item.toolTip = String(localized: "Off by default: three quarters of all byte values are printable Latin-1, so compiled code passes this reading in bulk.")
            }
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let unlikely = NSMenuItem(title: String(localized: "Show unlikely strings"),
                                  action: #selector(plausibilityToggled), keyEquivalent: "")
        unlikely.target = self
        unlikely.state = options.plausibleOnly ? .off : .on
        unlikely.toolTip = String(localized: "Also list runs that are printable without reading like text — including UTF-16 text that is not mostly Latin.")
        menu.addItem(unlikely)
        encodingsButton.menu = menu
    }

    @objc private func encodingToggled(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let kind = StringEncodingKind(rawValue: raw) else { return }
        var wanted = options.encodings
        if wanted.contains(kind) { wanted.remove(kind) } else { wanted.insert(kind) }
        options.encodings = wanted
        rebuildEncodingsMenu()
        rescan()
    }

    @objc private func plausibilityToggled() {
        options.plausibleOnly.toggle()
        rebuildEncodingsMenu()
        rescan()
    }

    // MARK: - Selection

    @objc private func rowChosen() {
        guard shown.indices.contains(table.clickedRow) else { return }
        onSelect?(shown[table.clickedRow])
    }

    /// Move keyboard focus to the filter field (opening the panel focuses it).
    func focusFilter() { window?.makeFirstResponder(search) }

    /// Whether a scan is still running — an automation run has to wait for it, and a
    /// screenshot taken before it finishes shows an empty list that means nothing.
    var isScanning: Bool { job.isRunning }

    #if DEBUG
    /// Diagnostic: activate row `index` exactly as a click does, and report which finding
    /// that was. Goes through the real selection so the owner's `onSelect` runs.
    @discardableResult
    func automationSelectRow(_ index: Int) -> FoundString? {
        guard shown.indices.contains(index) else { return nil }
        // Selecting posts the delegate notification, which is what calls `onSelect` — going
        // through it rather than around it is the point, since the owner's jump is what is
        // being measured.
        table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        return shown[index]
    }

    /// Diagnostic: what the panel is showing, for the VM scenarios (F-489). A blank list and
    /// a scan that never started look identical in a screenshot.
    var automationSummary: String {
        var lines = ["stringsfound=\(all.count)", "stringsshown=\(shown.count)",
                     "stringsstatus=\(status.stringValue)"]
        for hit in shown.prefix(8) {
            lines.append("stringrow=\(String(format: "%08llx", hit.offset)) \(hit.encoding.rawValue) \(hit.text)")
        }
        return lines.joined(separator: "\n") + "\n"
    }
    #endif
}

// MARK: - The table

extension StringsSidebar: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { shown.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard shown.indices.contains(row), let column = tableColumn else { return nil }
        let id = NSUserInterfaceItemIdentifier("StringCell." + column.identifier.rawValue)
        let field = (tableView.makeView(withIdentifier: id, owner: self) as? NSTextField)
            ?? { let f = NSTextField(labelWithString: ""); f.identifier = id
                 f.usesSingleLineMode = true; f.maximumNumberOfLines = 1
                 f.lineBreakMode = .byTruncatingTail; f.cell?.truncatesLastVisibleLine = true
                 f.drawsBackground = false; f.isBordered = false; f.isEditable = false
                 return f }()
        let hit = shown[row]
        field.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        field.textColor = Theme.current.listText
        switch column.identifier.rawValue {
        case "offset":
            field.stringValue = String(format: "%08llx", hit.offset)
            field.textColor = dimmedText
            field.toolTip = String(format: String(localized: "%lld byte(s) at 0x%llX"),
                                   Int64(hit.byteLength), hit.offset)
        case "encoding":
            field.stringValue = Self.tag(hit.encoding)
            field.textColor = dimmedText
            field.toolTip = Self.name(hit.encoding)
        default:
            // Tabs inside a string would render as a gap wide enough to look like the end
            // of the row; the tooltip carries the text as it stands.
            field.stringValue = hit.text.replacingOccurrences(of: "\t", with: " ")
            field.toolTip = hit.text
        }
        return field
    }

    /// A single click is enough: the panel exists to move the hex view around.
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard shown.indices.contains(table.selectedRow) else { return }
        onSelect?(shown[table.selectedRow])
    }
}

extension StringsSidebar: NSSearchFieldDelegate {
    /// Esc in the filter field: clear it, and once it is empty hand the key on — otherwise
    /// the viewer would stop closing on Esc for as long as this field had focus.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        if !textView.string.isEmpty {
            textView.string = ""
            search.stringValue = ""
            applyFilter()
            return true
        }
        return nextResponder?.tryToPerform(selector, with: nil) ?? false
    }
}
