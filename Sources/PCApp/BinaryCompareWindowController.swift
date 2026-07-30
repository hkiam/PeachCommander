// BinaryCompareWindowController.swift - Compare files as hex (TODOS #7, SPEC-010).
//
// Side-by-side hex dump of two files in a single virtual NSTableView (one row per
// 16-byte offset, so scrolling stays synchronized and any size is handled without
// loading the files into memory — FileSlice is mmap-backed). Differing rows are
// tinted; a summary reports the first difference, differing-byte count and sizes;
// Prev/Next jump between differing regions (from BinaryDiff's coalesced ranges).

import AppKit
import PCVFS
import PCFoundation

private struct ZeroSource: ByteSource {
    var count: Int64 { 0 }
    func bytes(at offset: Int64, length: Int) -> [UInt8] { [] }
}

final class BinaryCompareWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    var onClose: (() -> Void)?

    private let leftPath: String
    private let rightPath: String
    private var leftSlice: FileSlice?
    private var rightSlice: FileSlice?
    private var leftSize: Int64 = 0
    private var rightSize: Int64 = 0
    private var result: BinaryDiffResult?
    private var diffRows: [Int] = []
    private var rowCount = 0

    private let tableView = NSTableView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private var lastFind: [UInt8] = []
    private var findDialog: InputDialog?
    /// Cap for the on-demand full-file read used by search (avoids loading huge files).
    private static let maxSearchBytes: Int64 = 128 * 1024 * 1024

    init(leftPath: String, rightPath: String) {
        self.leftPath = leftPath
        self.rightPath = rightPath
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 620),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "Compare by Content (Hex)")
        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showWindow() {
        openSlices()
        rowCount = Int((max(leftSize, rightSize) + 15) / 16)
        tableView.reloadData()
        statusLabel.stringValue = String(localized: "Comparing…")
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        // Compare after the window is on screen so it appears immediately.
        DispatchQueue.main.async { [weak self] in self?.runCompare() }
    }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.spacing = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        let prev = NSButton(title: String(localized: "◀ Prev Diff"), target: self, action: #selector(prevDiff))
        let next = NSButton(title: String(localized: "Next Diff ▶"), target: self, action: #selector(nextDiff))
        let find = NSButton(title: String(localized: "Find…"), target: self, action: #selector(find))
        find.keyEquivalent = "f"; find.keyEquivalentModifierMask = .command
        let goto = NSButton(title: String(localized: "Go to…"), target: self, action: #selector(gotoAddress))
        goto.keyEquivalent = "g"; goto.keyEquivalentModifierMask = .command
        prev.bezelStyle = .rounded
        next.bezelStyle = .rounded
        find.bezelStyle = .rounded
        goto.bezelStyle = .rounded
        toolbar.addArrangedSubview(prev)
        toolbar.addArrangedSubview(next)
        toolbar.addArrangedSubview(find)
        toolbar.addArrangedSubview(goto)
        content.addSubview(toolbar)

        let leftCol = NSTableColumn(identifier: .init("left"))
        leftCol.title = (leftPath as NSString).lastPathComponent
        leftCol.width = 470
        let rightCol = NSTableColumn(identifier: .init("right"))
        rightCol.title = (rightPath as NSString).lastPathComponent
        rightCol.width = 470
        tableView.addTableColumn(leftCol)
        tableView.addTableColumn(rightCol)
        tableView.rowHeight = 15
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.gridStyleMask = [.solidVerticalGridLineMask]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = true
        tableView.menu = buildContextMenu()

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)

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
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusLabel.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            statusLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -6)
        ])
    }

    // MARK: - Load & compare

    private func openSlices() {
        leftSlice = FileSlice(path: leftPath)
        rightSlice = FileSlice(path: rightPath)
        leftSize = leftSlice?.count ?? Self.fileSize(leftPath)
        rightSize = rightSlice?.count ?? Self.fileSize(rightPath)
    }

    private static func fileSize(_ path: String) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.size] as? Int64) ?? 0
    }

    private func runCompare() {
        let a: ByteSource = leftSlice ?? ZeroSource()
        let b: ByteSource = rightSlice ?? ZeroSource()
        let r = BinaryDiff.compare(a, b)
        result = r
        diffRows = Self.rowsWithDifferences(r)
        statusLabel.stringValue = Self.summary(r)
        tableView.reloadData()
        if let first = r.firstDifference { jump(toOffset: first) }
    }

    private static func rowsWithDifferences(_ r: BinaryDiffResult) -> [Int] {
        var set = Set<Int>()
        for range in r.ranges {
            var row = Int(range.lowerBound / 16)
            let last = Int((range.upperBound - 1) / 16)
            while row <= last { set.insert(row); row += 1 }
        }
        if r.sizeA != r.sizeB { set.insert(Int(Swift.min(r.sizeA, r.sizeB) / 16)) }
        return set.sorted()
    }

    private static func summary(_ r: BinaryDiffResult) -> String {
        if r.equal {
            return String(format: NSLocalizedString("Files are identical (%lld bytes).", comment: ""), r.sizeA)
        }
        var parts: [String] = []
        if let first = r.firstDifference {
            parts.append(String(format: NSLocalizedString("Differ at offset 0x%llX", comment: ""), first))
        }
        parts.append(String(format: NSLocalizedString("%lld differing bytes", comment: ""), r.differingBytes))
        parts.append(String(format: NSLocalizedString("sizes %lld / %lld", comment: ""), r.sizeA, r.sizeB))
        if r.truncatedRanges { parts.append(String(localized: "(more differences not listed)")) }
        return parts.joined(separator: "  ·  ")
    }

    // MARK: - Navigation

    @objc private func nextDiff() {
        guard !diffRows.isEmpty else { NSSound.beep(); return }
        let current = tableView.selectedRow
        if let target = diffRows.first(where: { $0 > current }) { select(target) } else { NSSound.beep() }
    }

    @objc private func prevDiff() {
        guard !diffRows.isEmpty else { NSSound.beep(); return }
        let current = tableView.selectedRow < 0 ? rowCount : tableView.selectedRow
        if let target = diffRows.last(where: { $0 < current }) { select(target) } else { NSSound.beep() }
    }

    private func jump(toOffset offset: Int64) { select(Int(offset / 16)) }

    private func select(_ row: Int) {
        guard row >= 0, row < rowCount else { return }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    // MARK: - Row rendering

    private func rowBytes(_ slice: FileSlice?, size: Int64, offset: Int64) -> [UInt8] {
        guard offset < size else { return [] }
        let len = Int(Swift.min(16, size - offset))
        return slice?.bytes(at: offset, length: len) ?? []
    }

    private func rowDiffers(_ offset: Int64) -> Bool {
        rowBytes(leftSlice, size: leftSize, offset: offset) != rowBytes(rightSlice, size: rightSize, offset: offset)
    }

    /// Byte columns (0..<16) that differ between the two rows — a column differs when
    /// the bytes differ or the byte is present on only one side.
    private func differingColumns(_ a: [UInt8], _ b: [UInt8]) -> Set<Int> {
        var set = Set<Int>()
        for i in 0..<max(a.count, b.count) {
            let av = i < a.count ? a[i] : nil
            let bv = i < b.count ? b[i] : nil
            if av != bv { set.insert(i) }
        }
        return set
    }

    /// Build a hex row with only the differing byte columns highlighted (hex pair +
    /// ASCII char), so a shared prefix stays uncoloured — byte-precise, not per-row.
    private func attributedHexRow(bytes: [UInt8], offset: Int64, differing: Set<Int>) -> NSAttributedString {
        let text = HexFormatter.row(bytes: bytes, offset: offset)
        let attr = NSMutableAttributedString(string: text,
            attributes: [.font: font, .foregroundColor: NSColor.textColor])
        guard !differing.isEmpty else { return attr }
        // HexFormatter layout (all-ASCII, so UTF-16 offset == character index):
        //   <offset>  <16 * "XX" joined by " ">  <ascii>
        let offsetLen = max(8, String(offset, radix: 16).count)
        let hexStart = offsetLen + 2
        let asciiStart = hexStart + (16 * 2 + 15) + 2
        let total = attr.length
        let color = NSColor.systemRed.withAlphaComponent(0.30)
        for i in differing where (0..<16).contains(i) {
            let hexPos = hexStart + i * 3
            if hexPos + 2 <= total {
                attr.addAttribute(.backgroundColor, value: color, range: NSRange(location: hexPos, length: 2))
            }
            let asciiPos = asciiStart + i
            if asciiPos + 1 <= total {
                attr.addAttribute(.backgroundColor, value: color, range: NSRange(location: asciiPos, length: 1))
            }
        }
        return attr
    }

    // MARK: - Copy / export (selected rows)

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        for (side, title) in [("left", String(localized: "Copy Left Selection As")),
                              ("right", String(localized: "Copy Right Selection As"))] {
            let sub = NSMenu()
            for fmt in ByteFormat.allCases {
                let item = NSMenuItem(title: fmt.label, action: #selector(copySelectionAs(_:)), keyEquivalent: "")
                item.representedObject = "\(side):\(fmt.rawValue)"
                item.target = self
                sub.addItem(item)
            }
            let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            parent.submenu = sub
            menu.addItem(parent)
        }
        return menu
    }

    /// Bytes of the currently selected rows on one side, in row order.
    private func selectedBytes(side: String) -> [UInt8] {
        let slice = side == "left" ? leftSlice : rightSlice
        let size = side == "left" ? leftSize : rightSize
        var out: [UInt8] = []
        for row in tableView.selectedRowIndexes.sorted() {
            out.append(contentsOf: rowBytes(slice, size: size, offset: Int64(row) * 16))
        }
        return out
    }

    @objc private func copySelectionAs(_ sender: NSMenuItem) {
        guard let token = sender.representedObject as? String else { return }
        let parts = token.split(separator: ":")
        guard parts.count == 2, let fmt = ByteFormat(rawValue: String(parts[1])) else { return }
        let bytes = selectedBytes(side: String(parts[0]))
        guard !bytes.isEmpty else { NSSound.beep(); return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ByteFormatter.format(bytes, as: fmt), forType: .string)
    }

    // MARK: - Find (text or bytes)

    @objc private func gotoAddress() {
        let dialog = InputDialog(title: String(localized: "Go to Address"),
                                 prompt: String(localized: "Address (0x…, $…, …h, or decimal):"), initialValue: "")
        dialog.onConfirm = { [weak self] input in
            guard let self, let addr = HexAddress.parse(input) else { NSSound.beep(); return }
            self.select(Int(addr / 16))
        }
        findDialog = dialog
        dialog.runModalDialog()
    }

    @objc private func find() {
        let dialog = InputDialog(title: String(localized: "Find"),
                                 prompt: String(localized: "Hex bytes (e.g. 48 65 6c) or text:"),
                                 initialValue: hexString(lastFind))
        dialog.onConfirm = { [weak self] input in
            guard let self else { return }
            let trimmed = input.trimmingCharacters(in: .whitespaces)
            let pattern: [UInt8]?
            if let hex = ByteSearch.parseHex(trimmed), !hex.isEmpty { pattern = hex }
            else if !trimmed.isEmpty { pattern = Array(input.utf8) }
            else { pattern = nil }
            guard let pattern, !pattern.isEmpty else { NSSound.beep(); return }
            self.lastFind = pattern
            self.performFind(pattern)
        }
        findDialog = dialog
        dialog.runModalDialog()
    }

    private func performFind(_ pattern: [UInt8]) {
        // Search from just after the current selection, on the left then the right file.
        let start = Int64(max(0, tableView.selectedRow)) * 16 + 1
        for (side, slice, size) in [("left", leftSlice, leftSize), ("right", rightSlice, rightSize)] {
            guard size <= Self.maxSearchBytes else { continue }
            guard let bytes = fullBytes(slice, size: size) else { continue }
            let from = side == "left" ? Int(min(start, size)) : 0
            if let idx = ByteSearch.firstIndex(of: pattern, in: bytes, from: from)
                       ?? ByteSearch.firstIndex(of: pattern, in: bytes, from: 0) {
                select(Int(Int64(idx) / 16))
                statusLabel.stringValue = String(format:
                    NSLocalizedString("Found at offset 0x%llX in %@", comment: ""), Int64(idx),
                    side == "left" ? (leftPath as NSString).lastPathComponent : (rightPath as NSString).lastPathComponent)
                return
            }
        }
        NSSound.beep()
        statusLabel.stringValue = String(localized: "Not found.")
    }

    /// Read a whole file's bytes on demand (for search), in chunks, respecting the cap.
    private func fullBytes(_ slice: FileSlice?, size: Int64) -> [UInt8]? {
        guard let slice, size > 0, size <= Self.maxSearchBytes else { return size == 0 ? [] : nil }
        var out = [UInt8](); out.reserveCapacity(Int(size))
        var offset: Int64 = 0
        let chunk = 1 << 20
        while offset < size {
            let len = Int(Swift.min(Int64(chunk), size - offset))
            out.append(contentsOf: slice.bytes(at: offset, length: len))
            offset += Int64(len)
        }
        return out
    }

    private func hexString(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { rowCount }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let isLeft = tableColumn?.identifier.rawValue == "left"
        let offset = Int64(row) * 16
        let leftBytes = rowBytes(leftSlice, size: leftSize, offset: offset)
        let rightBytes = rowBytes(rightSlice, size: rightSize, offset: offset)
        let bytes = isLeft ? leftBytes : rightBytes

        let id = NSUserInterfaceItemIdentifier("cell")
        let field: NSTextField
        if let reused = tableView.makeView(withIdentifier: id, owner: self) as? NSTextField {
            field = reused
        } else {
            field = NSTextField(labelWithString: "")
            field.identifier = id
            field.font = font
            field.lineBreakMode = .byClipping
            field.drawsBackground = false
            field.isBordered = false
        }
        if bytes.isEmpty {
            field.stringValue = ""
        } else {
            field.attributedStringValue = attributedHexRow(bytes: bytes, offset: offset,
                                                           differing: differingColumns(leftBytes, rightBytes))
        }
        return field
    }
}

extension BinaryCompareWindowController {
    func windowWillClose(_ notification: Notification) { onClose?() }
}

// MARK: - Contextual menu-bar menu (TODOS #189)

@MainActor
extension BinaryCompareWindowController: WindowContextMenuProviding {
    func makeEditMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Edit"))
        // Copy the selected rows of the left file as hex (richer per-side "Copy as…"
        // options remain on the table's right-click menu).
        AppMenu.editItem(menu, String(localized: "Copy (Hex)"), action: #selector(copySelectionAs(_:)),
                         target: self, key: "c", representedObject: "left:hex")
        AppMenu.editItem(menu, String(localized: "Select All"), action: #selector(NSText.selectAll(_:)),
                         target: nil, key: "a")
        menu.addItem(.separator())
        AppMenu.editItem(menu, String(localized: "Find…"), action: #selector(find), target: self, key: "f")
        AppMenu.editItem(menu, String(localized: "Go to…"), action: #selector(gotoAddress), target: self, key: "g")
        return menu
    }

    func makeWindowMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Compare"))
        func add(_ title: String, _ selector: Selector, key: String = "", mask: NSEvent.ModifierFlags = []) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.keyEquivalentModifierMask = mask
            item.target = self
            menu.addItem(item)
        }
        add(String(localized: "Find…"), #selector(find), key: "f", mask: .command)
        add(String(localized: "Go to…"), #selector(gotoAddress), key: "g", mask: .command)
        menu.addItem(.separator())
        add(String(localized: "Previous Difference"), #selector(prevDiff))
        add(String(localized: "Next Difference"), #selector(nextDiff))
        return menu
    }
}
