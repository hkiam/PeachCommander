// SPDX-License-Identifier: Apache-2.0
// DiffWindowController.swift - Compare Files by Content (I12 T02, F-190)
//
// Read-only side-by-side line diff. The two files share a single NSTableView
// (one row per aligned DiffRow), which gives synchronized scrolling and block
// coloring for free. A toolbar offers next/prev-difference navigation and the
// ignore-case / ignore-whitespace / ignore-line-ends options (re-diff on change).
// Intra-line character differences are highlighted in .change rows.
//
// Edit mode: select a differing block and copy it across ("◀ Copy Block" / "Copy
// Block ▶"), then "Save Left"/"Save Right" writes the merged side back (a .bak
// backup is kept); closing with unsaved merges prompts. Binary/hex diff lives in
// BinaryCompareWindowController.

import AppKit
import PCFoundation

final class DiffWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    /// Called when the window closes (so the owner can release it).
    var onClose: (() -> Void)?

    private let leftPath: String
    private let rightPath: String
    private let maxBytes = 256 * 1024 * 1024

    private var leftLines: [String] = []
    private var rightLines: [String] = []
    private var rows: [DiffRow] = []
    private var options = DiffOptions()

    // Edit mode: block merge + save. A side is editable only if it read as text;
    // `dirty` tracks unsaved in-memory merges.
    private var leftReadable = true
    private var rightReadable = true
    private var leftDirty = false
    private var rightDirty = false

    private let tableView = NSTableView()
    private let overviewBar = DiffOverviewBar()
    private let statusLabel = NSTextField(labelWithString: "")
    private let ignoreCaseButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let ignoreLineEndsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let whitespacePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let copyToRightButton = NSButton()
    private let copyToLeftButton = NSButton()
    private let saveLeftButton = NSButton()
    private let saveRightButton = NSButton()
    private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    init(leftPath: String, rightPath: String) {
        self.leftPath = leftPath
        self.rightPath = rightPath
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "Compare by Content")
        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showWindow() {
        loadFiles()
        recompute()
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        // Toolbar row
        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.spacing = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        let prev = NSButton(title: String(localized: "◀ Prev Diff"), target: self, action: #selector(prevDiff))
        let next = NSButton(title: String(localized: "Next Diff ▶"), target: self, action: #selector(nextDiff))
        prev.bezelStyle = .rounded
        next.bezelStyle = .rounded

        ignoreCaseButton.title = String(localized: "Ignore case")
        ignoreCaseButton.target = self
        ignoreCaseButton.action = #selector(optionChanged)
        ignoreLineEndsButton.title = String(localized: "Ignore line ends")
        ignoreLineEndsButton.target = self
        ignoreLineEndsButton.action = #selector(optionChanged)

        whitespacePopup.addItems(withTitles: [String(localized: "Whitespace: significant"),
                                              String(localized: "Ignore all whitespace"),
                                              String(localized: "Ignore leading/trailing")])
        whitespacePopup.target = self
        whitespacePopup.action = #selector(optionChanged)

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 20).isActive = true

        toolbar.addArrangedSubview(prev)
        toolbar.addArrangedSubview(next)
        toolbar.addArrangedSubview(divider)
        toolbar.addArrangedSubview(ignoreCaseButton)
        toolbar.addArrangedSubview(whitespacePopup)
        toolbar.addArrangedSubview(ignoreLineEndsButton)

        // Edit mode: merge the selected difference block across, then save.
        let divider2 = NSBox()
        divider2.boxType = .separator
        divider2.translatesAutoresizingMaskIntoConstraints = false
        divider2.heightAnchor.constraint(equalToConstant: 20).isActive = true
        for (button, title, action) in [
            (copyToLeftButton, String(localized: "◀ Copy Block"), #selector(copyBlockToLeft)),
            (copyToRightButton, String(localized: "Copy Block ▶"), #selector(copyBlockToRight)),
            (saveLeftButton, String(localized: "Save Left"), #selector(saveLeft)),
            (saveRightButton, String(localized: "Save Right"), #selector(saveRight)),
        ] as [(NSButton, String, Selector)] {
            button.title = title; button.bezelStyle = .rounded
            button.target = self; button.action = action; button.isEnabled = false
        }
        toolbar.addArrangedSubview(divider2)
        toolbar.addArrangedSubview(copyToLeftButton)
        toolbar.addArrangedSubview(copyToRightButton)
        toolbar.addArrangedSubview(saveLeftButton)
        toolbar.addArrangedSubview(saveRightButton)
        content.addSubview(toolbar)

        // Columns: line-number gutter + text, for each side.
        let lnLeft = NSTableColumn(identifier: .init("ln-l"))
        lnLeft.title = ""; lnLeft.width = 46; lnLeft.minWidth = 34
        let leftCol = NSTableColumn(identifier: .init("left"))
        leftCol.title = (leftPath as NSString).lastPathComponent
        leftCol.width = 380
        let lnRight = NSTableColumn(identifier: .init("ln-r"))
        lnRight.title = ""; lnRight.width = 46; lnRight.minWidth = 34
        let rightCol = NSTableColumn(identifier: .init("right"))
        rightCol.title = (rightPath as NSString).lastPathComponent
        rightCol.width = 380
        tableView.addTableColumn(lnLeft)
        tableView.addTableColumn(leftCol)
        tableView.addTableColumn(lnRight)
        tableView.addTableColumn(rightCol)
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.rowHeight = 16
        tableView.gridStyleMask = [.solidVerticalGridLineMask]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsColumnResizing = true
        tableView.allowsMultipleSelection = true

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)

        // Change-overview bar (colored ticks per diff block + viewport, click to jump).
        overviewBar.translatesAutoresizingMaskIntoConstraints = false
        overviewBar.tableView = tableView
        overviewBar.scrollView = scroll
        overviewBar.onJump = { [weak self] row in
            guard let self, self.rows.indices.contains(row) else { return }
            self.tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            self.tableView.scrollRowToVisible(row)
        }
        overviewBar.observeScroll()
        content.addSubview(overviewBar)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        content.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: content.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            scroll.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: overviewBar.leadingAnchor),
            overviewBar.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            overviewBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            overviewBar.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            overviewBar.widthAnchor.constraint(equalToConstant: 16),

            statusLabel.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            statusLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -6),
        ])
    }

    // MARK: - Loading & diffing

    private func loadFiles() {
        let l = Self.readLines(leftPath, maxBytes: maxBytes)
        let r = Self.readLines(rightPath, maxBytes: maxBytes)
        leftLines = l.lines; leftReadable = l.ok
        rightLines = r.lines; rightReadable = r.ok
        leftDirty = false; rightDirty = false
    }

    /// Read a text file into lines, trying UTF-8 then ISO Latin-1. `ok` is false
    /// (and a sentinel line is returned) if the file is missing, too large, or not
    /// decodable as text — such a side must not be edited/saved.
    private static func readLines(_ path: String, maxBytes: Int) -> (lines: [String], ok: Bool) {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else {
            return (["<<cannot read \((path as NSString).lastPathComponent)>>"], false)
        }
        if data.count > maxBytes {
            return (["<<file too large for text diff (\(data.count) bytes)>>"], false)
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return (["<<binary file — text diff unavailable>>"], false)
        }
        // Split on \n; keep \r so ignore-line-ends is meaningful.
        return (text.components(separatedBy: "\n"), true)
    }

    private func recompute() {
        options = DiffOptions(ignoreCase: ignoreCaseButton.state == .on,
                              whitespace: [.none, .all, .leadingTrailing][whitespacePopup.indexOfSelectedItem],
                              ignoreLineEndings: ignoreLineEndsButton.state == .on)
        rows = LineDiff.compare(left: leftLines, right: rightLines, options: options)
        tableView.reloadData()
        overviewBar.ops = rows.map(\.op)
        let diffs = rows.filter { $0.op != .equal }.count
        statusLabel.stringValue = diffs == 0
            ? String(localized: "Files are identical.")
            : String(localized: "\(diffs) differing line block(s).")
        updateEditButtons()
        updateTitle()
    }

    @objc private func optionChanged() { recompute() }

    // MARK: - Edit mode (block merge + save)

    func tableViewSelectionDidChange(_ notification: Notification) { updateEditButtons() }

    /// The maximal run of non-equal rows containing (or adjacent to) the selection.
    private func selectedBlockRange() -> ClosedRange<Int>? {
        let sel = tableView.selectedRow
        guard rows.indices.contains(sel), rows[sel].op != .equal else { return nil }
        var lo = sel, hi = sel
        while lo > 0, rows[lo - 1].op != .equal { lo -= 1 }
        while hi < rows.count - 1, rows[hi + 1].op != .equal { hi += 1 }
        return lo...hi
    }

    /// Line ranges (half-open) a block covers on each side. Empty on a side means a
    /// pure insert/delete there; the location is the insertion point.
    private func blockLineRanges(_ block: ClosedRange<Int>) -> (left: Range<Int>, right: Range<Int>) {
        let lIdx = block.compactMap { rows[$0].leftIndex }
        let rIdx = block.compactMap { rows[$0].rightIndex }
        func insertionPoint(after upper: Int, side keyPath: KeyPath<DiffRow, Int?>, count: Int) -> Int {
            var i = upper + 1
            while i < rows.count { if let v = rows[i][keyPath: keyPath] { return v }; i += 1 }
            return count
        }
        let left = lIdx.isEmpty
            ? { let p = insertionPoint(after: block.upperBound, side: \.leftIndex, count: leftLines.count); return p..<p }()
            : lIdx.min()!..<(lIdx.max()! + 1)
        let right = rIdx.isEmpty
            ? { let p = insertionPoint(after: block.upperBound, side: \.rightIndex, count: rightLines.count); return p..<p }()
            : rIdx.min()!..<(rIdx.max()! + 1)
        return (left, right)
    }

    @objc private func copyBlockToLeft() { mergeSelectedBlock(toLeft: true) }
    @objc private func copyBlockToRight() { mergeSelectedBlock(toLeft: false) }

    /// Replace the target side's block lines with the source side's, then re-diff.
    private func mergeSelectedBlock(toLeft: Bool) {
        guard let block = selectedBlockRange() else { NSSound.beep(); return }
        guard (toLeft ? leftReadable : rightReadable) else { NSSound.beep(); return }
        let (lRange, rRange) = blockLineRanges(block)
        let anchor = block.lowerBound
        if toLeft {
            leftLines.replaceSubrange(lRange, with: rightLines[rRange]); leftDirty = true
        } else {
            rightLines.replaceSubrange(rRange, with: leftLines[lRange]); rightDirty = true
        }
        recompute()
        if rows.indices.contains(anchor) {
            tableView.selectRowIndexes(IndexSet(integer: anchor), byExtendingSelection: false)
            tableView.scrollRowToVisible(anchor)
        }
    }

    @objc private func saveLeft() { save(left: true) }
    @objc private func saveRight() { save(left: false) }

    private func save(left: Bool) {
        let path = left ? leftPath : rightPath
        let lines = left ? leftLines : rightLines
        // Back up the current on-disk file to "<name>.bak" once per save, then write.
        let bak = path + ".bak"
        try? FileManager.default.removeItem(atPath: bak)
        try? FileManager.default.copyItem(atPath: path, toPath: bak)
        do {
            try lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
            if left { leftDirty = false } else { rightDirty = false }
            updateEditButtons(); updateTitle()
        } catch {
            let alert = NSAlert()
            alert.messageText = String(localized: "Could not save")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private func updateEditButtons() {
        let hasBlock = selectedBlockRange() != nil
        copyToLeftButton.isEnabled = hasBlock && leftReadable
        copyToRightButton.isEnabled = hasBlock && rightReadable
        saveLeftButton.isEnabled = leftDirty
        saveRightButton.isEnabled = rightDirty
    }

    private func updateTitle() {
        let l = (leftPath as NSString).lastPathComponent + (leftDirty ? " •" : "")
        let r = (rightPath as NSString).lastPathComponent + (rightDirty ? " •" : "")
        window?.title = String(format: String(localized: "Compare — %@ ↔ %@"), l, r)
    }

    // MARK: - Navigation

    @objc private func nextDiff() { jumpDiff(forward: true) }
    @objc private func prevDiff() { jumpDiff(forward: false) }

    private func jumpDiff(forward: Bool) {
        guard !rows.isEmpty else { return }
        let current = tableView.selectedRow
        let range = forward ? Array((current + 1)..<rows.count) : Array((0..<max(0, current)).reversed())
        for i in range where rows[i].op != .equal {
            tableView.selectRowIndexes(IndexSet(integer: i), byExtendingSelection: false)
            tableView.scrollRowToVisible(i)
            return
        }
        NSSound.beep()
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let diff = rows[row]
        let colID = tableColumn?.identifier.rawValue

        // Line-number gutter columns.
        if colID == "ln-l" || colID == "ln-r" {
            let isLeftNum = colID == "ln-l"
            let index = isLeftNum ? diff.leftIndex : diff.rightIndex
            let id = NSUserInterfaceItemIdentifier("lncell")
            let field = (tableView.makeView(withIdentifier: id, owner: self) as? NSTextField)
                ?? { let f = NSTextField(labelWithString: ""); f.identifier = id; f.font = font
                     f.alignment = .right; f.textColor = .tertiaryLabelColor
                     f.drawsBackground = true; f.isBordered = false; return f }()
            field.stringValue = index.map { String($0 + 1) } ?? ""
            field.backgroundColor = Self.rowColor(diff.op, filled: index != nil)
            return field
        }

        let isLeft = colID == "left"
        let index = isLeft ? diff.leftIndex : diff.rightIndex
        let lines = isLeft ? leftLines : rightLines
        let id = NSUserInterfaceItemIdentifier("cell")
        let field: NSTextField
        if let reused = tableView.makeView(withIdentifier: id, owner: self) as? NSTextField {
            field = reused
        } else {
            field = NSTextField(labelWithString: "")
            field.identifier = id
            field.font = font
            field.lineBreakMode = .byClipping
            field.drawsBackground = true
            field.isBordered = false
        }

        if let index, index < lines.count {
            let text = lines[index]
            if diff.op == .change, let li = diff.leftIndex, let ri = diff.rightIndex,
               li < leftLines.count, ri < rightLines.count {
                let intra = LineDiff.intraLine(leftLines[li], rightLines[ri])
                field.attributedStringValue = Self.highlighted(text,
                    ranges: isLeft ? intra.left : intra.right, font: font)
            } else {
                field.stringValue = text
            }
        } else {
            field.stringValue = ""
        }
        field.backgroundColor = Self.rowColor(diff.op, filled: index != nil)
        return field
    }

    private static func highlighted(_ text: String, ranges: [Range<Int>], font: NSFont) -> NSAttributedString {
        let attr = NSMutableAttributedString(string: text, attributes: [.font: font])
        let chars = Array(text)
        let hl = NSColor.systemOrange.withAlphaComponent(0.55)
        for r in ranges where r.lowerBound < chars.count {
            let lo = r.lowerBound
            let hi = min(r.upperBound, chars.count)
            // Map grapheme range to UTF-16 range.
            let start = String(chars[0..<lo]).utf16.count
            let len = String(chars[lo..<hi]).utf16.count
            if len > 0 { attr.addAttribute(.backgroundColor, value: hl, range: NSRange(location: start, length: len)) }
        }
        return attr
    }

    private static func rowColor(_ op: DiffOp, filled: Bool) -> NSColor {
        switch op {
        case .equal: return .clear
        case .insert: return filled ? NSColor.systemGreen.withAlphaComponent(0.18) : NSColor.systemGray.withAlphaComponent(0.10)
        case .delete: return filled ? NSColor.systemRed.withAlphaComponent(0.16) : NSColor.systemGray.withAlphaComponent(0.10)
        case .change: return NSColor.systemYellow.withAlphaComponent(0.20)
        }
    }
}

extension DiffWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard leftDirty || rightDirty else { return true }
        let alert = NSAlert()
        alert.messageText = String(localized: "Unsaved merges")
        alert.informativeText = String(localized: "You merged changes that aren't saved. Close anyway?")
        alert.addButton(withTitle: String(localized: "Discard & Close"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }
    func windowWillClose(_ notification: Notification) { onClose?() }
}

/// A thin vertical overview of all diff blocks: one colored tick per differing row,
/// a viewport rectangle for the visible region, and click/drag to jump.
private final class DiffOverviewBar: NSView {
    weak var tableView: NSTableView?
    weak var scrollView: NSScrollView?
    var ops: [DiffOp] = [] { didSet { needsDisplay = true } }
    var onJump: ((Int) -> Void)?
    override var isFlipped: Bool { true }

    func observeScroll() {
        scrollView?.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(scrolled),
                                               name: NSView.boundsDidChangeNotification, object: scrollView?.contentView)
    }
    @objc private func scrolled() { needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.quaternaryLabelColor.withAlphaComponent(0.15).setFill(); bounds.fill()
        let n = CGFloat(max(1, ops.count))
        let th = max(1.5, bounds.height / n)
        for (i, op) in ops.enumerated() where op != .equal {
            (Self.color(op) ?? .clear).setFill()
            NSRect(x: 2, y: CGFloat(i) / n * bounds.height, width: bounds.width - 4, height: th).fill()
        }
        // Viewport rectangle.
        if let tv = tableView, ops.count > 0 {
            let visible = tv.rows(in: tv.visibleRect)
            if visible.length > 0 {
                let top = CGFloat(visible.location) / n * bounds.height
                let h = max(6, CGFloat(visible.length) / n * bounds.height)
                let r = NSRect(x: 0.5, y: top, width: bounds.width - 1, height: h)
                NSColor.systemGray.withAlphaComponent(0.18).setFill(); r.fill()
                NSColor.systemGray.withAlphaComponent(0.5).setStroke(); NSBezierPath(rect: r.insetBy(dx: 0.5, dy: 0.5)).stroke()
            }
        }
    }

    private static func color(_ op: DiffOp) -> NSColor? {
        switch op {
        case .equal: return nil
        case .insert: return .systemGreen
        case .delete: return .systemRed
        case .change: return .systemYellow
        }
    }

    override func mouseDown(with event: NSEvent) { jump(convert(event.locationInWindow, from: nil)) }
    override func mouseDragged(with event: NSEvent) { jump(convert(event.locationInWindow, from: nil)) }
    private func jump(_ p: NSPoint) {
        guard !ops.isEmpty, bounds.height > 1 else { return }
        let row = Int((p.y / bounds.height) * CGFloat(ops.count))
        onJump?(max(0, min(row, ops.count - 1)))
    }
}

// MARK: - Contextual menu-bar menu (TODOS #189)

@MainActor
extension DiffWindowController: WindowContextMenuProviding {
    /// Copy the selected rows' text from one side (skipping rows absent on that side).
    private func copySide(_ left: Bool) {
        let selected = tableView.selectedRowIndexes.isEmpty
            ? IndexSet(integersIn: 0..<rows.count) : tableView.selectedRowIndexes
        let lines = left ? leftLines : rightLines
        var out: [String] = []
        for row in selected.sorted() {
            guard rows.indices.contains(row) else { continue }
            if let idx = left ? rows[row].leftIndex : rows[row].rightIndex, idx < lines.count {
                out.append(lines[idx])
            }
        }
        guard !out.isEmpty else { NSSound.beep(); return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(out.joined(separator: "\n"), forType: .string)
    }

    @objc func copyLeftSide() { copySide(true) }
    @objc func copyRightSide() { copySide(false) }

    func makeEditMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Edit"))
        AppMenu.editItem(menu, String(localized: "Copy Left Side"), action: #selector(copyLeftSide),
                         target: self, key: "c")
        AppMenu.editItem(menu, String(localized: "Copy Right Side"), action: #selector(copyRightSide),
                         target: self, key: "c", mask: [.command, .shift])
        AppMenu.editItem(menu, String(localized: "Select All"), action: #selector(NSText.selectAll(_:)),
                         target: nil, key: "a")
        return menu
    }

    func makeWindowMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Compare"))
        func add(_ title: String, _ selector: Selector) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        add(String(localized: "Previous Difference"), #selector(prevDiff))
        add(String(localized: "Next Difference"), #selector(nextDiff))
        return menu
    }
}
