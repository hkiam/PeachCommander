// SPDX-License-Identifier: Apache-2.0
// HexEditorWindowController.swift - Editable hex editor (TODOS #26, UI).
//
// A caret-based hex grid over a HexDocument: type hex digits to overwrite (or insert,
// in insert mode) bytes nibble by nibble, arrow keys move the caret, Backspace/Delete
// remove bytes, Cmd+Z/Cmd+Shift+Z undo/redo, Cmd+S saves with a one-time .bak backup.
// All byte manipulation goes through the tested HexDocument; this view is display +
// input mapping.

import AppKit
import PCFoundation
import PCVFS

// MARK: - The editable grid

final class HexEditorView: NSView {
    let doc: HexDocument
    var onChange: (() -> Void)?
    /// Asked to delete the given byte range; the controller runs the remove/fill dialog.
    var onRequestDeleteSelection: ((Range<Int>) -> Void)?

    private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private let rowHeight: CGFloat = 16
    private var cellW: CGFloat = 8
    private var caret = 0
    private var nibbleHigh = true
    private(set) var insertMode = false
    /// Selected byte range (half-open) and the anchor a drag/shift-select grows from.
    private var selection: Range<Int>?
    private var anchor = 0

    init(doc: HexDocument) {
        self.doc = doc
        super.init(frame: .zero)
        cellW = ("0" as NSString).size(withAttributes: [.font: font]).width
        resize()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    private var offsetDigits: Int { max(8, String(max(0, doc.count - 1), radix: 16).count) }
    private var hexOriginX: CGFloat { CGFloat(offsetDigits + 2) * cellW + 4 }
    private var rowCount: Int { max(1, (doc.count + 15) / 16) }

    private func resize() {
        setFrameSize(NSSize(width: hexOriginX + CGFloat(16 * 3) * cellW + 20 + CGFloat(16) * cellW,
                            height: CGFloat(rowCount) * rowHeight))
    }

    func toggleInsertMode() { insertMode.toggle(); onChange?() }
    var modeName: String { insertMode ? "INS" : "OVR" }
    var caretOffset: Int { caret }

    /// The current selection (half-open byte range), or nil.
    var selectedRange: Range<Int>? { selection }
    /// Bytes in the current selection (empty if nothing selected).
    var selectedBytes: [UInt8] {
        guard let sel = selection else { return [] }
        return Array(doc.bytes[clampToBytes(sel)])
    }

    func selectAll() {
        guard doc.count > 0 else { return }
        anchor = 0
        selection = 0..<doc.count
        needsDisplay = true
        onChange?()
    }

    func clearSelection() {
        guard selection != nil else { return }
        selection = nil
        needsDisplay = true
        onChange?()
    }

    /// Select a byte range (used by Find to highlight the match) and scroll to it.
    func selectRange(_ range: Range<Int>) {
        let r = clampToBytes(range)
        guard !r.isEmpty else { return }
        selection = r
        caret = r.lowerBound
        anchor = r.lowerBound
        nibbleHigh = true
        scrollToVisible(NSRect(x: 0, y: CGFloat(r.lowerBound / 16) * rowHeight, width: 1, height: rowHeight * 3))
        needsDisplay = true
        onChange?()
    }

    private func clampToBytes(_ r: Range<Int>) -> Range<Int> {
        let lo = max(0, min(r.lowerBound, doc.count))
        let hi = max(lo, min(r.upperBound, doc.count))
        return lo..<hi
    }

    /// Move the caret to `index` and scroll it into view (used by find).
    func setCaret(_ index: Int) {
        caret = max(0, min(index, max(0, doc.count - 1)))
        nibbleHigh = true
        scrollToVisible(NSRect(x: 0, y: CGFloat(caret / 16) * rowHeight, width: 1, height: rowHeight * 3))
        needsDisplay = true
        onChange?()
    }

    /// Re-layout and redraw after the document was edited externally (e.g. replace-all).
    func reloadAfterExternalEdit() { selection = nil; clampCaret(); resize(); needsDisplay = true; onChange?() }

    /// Undo/redo the last byte edit (used by keyboard + the Edit menu).
    func performUndo() { doc.undo(); clampCaret(); refresh() }
    func performRedo() { doc.redo(); clampCaret(); refresh() }
    /// Copy the current selection to the pasteboard as spaced hex (Edit ▸ Copy).
    func copySelectionHex() { copySelection(as: .hex) }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        Theme.current.listBackground.setFill()
        dirtyRect.fill()
        let first = max(0, Int(dirtyRect.minY / rowHeight))
        let last = min(rowCount - 1, Int(dirtyRect.maxY / rowHeight))
        guard first <= last else { return }
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Theme.current.listText]

        let changedAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.systemRed]
        let asciiX = hexOriginX + CGFloat(16 * 3) * cellW + 16
        for row in first...last {
            let base = row * 16
            let y = CGFloat(row) * rowHeight
            let offset = String(format: "%0\(offsetDigits)x", base)
            NSAttributedString(string: offset, attributes: attrs).draw(at: NSPoint(x: 4, y: y))

            for i in 0..<16 {
                let idx = base + i
                guard idx < doc.count, let b = doc.byte(at: idx) else { break }
                let x = hexOriginX + CGFloat(i * 3) * cellW
                let asciiCharX = asciiX + CGFloat(i) * cellW
                // Selection highlight spans both the hex pair and the ASCII cell.
                if let sel = selection, sel.contains(idx) {
                    NSColor.selectedTextBackgroundColor.withAlphaComponent(0.6).setFill()
                    NSRect(x: x - 1, y: y, width: cellW * 2 + 2, height: rowHeight).fill()
                    NSRect(x: asciiCharX, y: y, width: cellW, height: rowHeight).fill()
                }
                if idx == caret {
                    (insertMode ? NSColor.systemGreen : NSColor.systemBlue).withAlphaComponent(0.30).setFill()
                    NSRect(x: x - 1, y: y, width: cellW * 2 + 2, height: rowHeight).fill()
                }
                let byteAttrs = doc.isChanged(at: idx) ? changedAttrs : attrs
                NSAttributedString(string: String(format: "%02x", b), attributes: byteAttrs)
                    .draw(at: NSPoint(x: x, y: y))
                let ch = (0x20...0x7e).contains(b) ? String(UnicodeScalar(b)) : "."
                NSAttributedString(string: ch, attributes: byteAttrs).draw(at: NSPoint(x: asciiCharX, y: y))
            }
        }
    }

    // MARK: Input

    /// Map a point to a byte index, in either the hex or the ASCII column.
    private func byteIndex(at p: NSPoint) -> Int? {
        guard p.y >= 0 else { return nil }
        let row = Int(p.y / rowHeight)
        let asciiX = hexOriginX + CGFloat(16 * 3) * cellW + 16
        var col: Int
        if p.x >= asciiX {
            col = Int((p.x - asciiX) / cellW)
        } else if p.x >= hexOriginX {
            col = Int((p.x - hexOriginX) / (cellW * 3))
        } else {
            col = 0
        }
        guard col >= 0, col < 16 else { return nil }
        let idx = row * 16 + col
        return (idx >= 0 && idx < doc.count) ? idx : nil
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard let idx = byteIndex(at: p) else { return }
        caret = idx
        nibbleHigh = true
        if event.modifierFlags.contains(.shift) {
            selection = min(anchor, idx)..<(max(anchor, idx) + 1)
        } else {
            anchor = idx
            selection = nil
        }
        needsDisplay = true
        onChange?()
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard let idx = byteIndex(at: p) else { return }
        caret = idx
        selection = min(anchor, idx)..<(max(anchor, idx) + 1)
        needsDisplay = true
        onChange?()
    }

    // MARK: Context menu (copy / delete selection)

    override func menu(for event: NSEvent) -> NSMenu? {
        // Right-clicking with no selection selects the byte under the pointer.
        if selection == nil {
            let p = convert(event.locationInWindow, from: nil)
            if let idx = byteIndex(at: p) { caret = idx; anchor = idx; selection = idx..<(idx + 1); needsDisplay = true }
        }
        guard selection != nil else { return nil }
        let menu = NSMenu()
        menu.addItem(withTitle: String(localized: "Copy (Hex)"), action: #selector(copyHex), keyEquivalent: "")
        let copyAs = NSMenu()
        for fmt in ByteFormat.allCases {
            let item = NSMenuItem(title: fmt.label, action: #selector(copyAsFormat(_:)), keyEquivalent: "")
            item.representedObject = fmt.rawValue
            item.target = self
            copyAs.addItem(item)
        }
        let copyAsItem = NSMenuItem(title: String(localized: "Copy Selection As"), action: nil, keyEquivalent: "")
        copyAsItem.submenu = copyAs
        menu.addItem(copyAsItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Delete Selected Bytes…"), action: #selector(deleteSelection), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Select All"), action: #selector(selectAllBytes), keyEquivalent: "")
        for item in menu.items where item.action != nil && item.submenu == nil { item.target = self }
        return menu
    }

    @objc private func copyHex() { copySelection(as: .hex) }
    @objc private func selectAllBytes() { selectAll() }
    @objc private func deleteSelection() { if let sel = selection { onRequestDeleteSelection?(sel) } }
    @objc private func copyAsFormat(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let fmt = ByteFormat(rawValue: raw) else { return }
        copySelection(as: fmt)
    }

    func copySelection(as format: ByteFormat) {
        let bytes = selectedBytes
        guard !bytes.isEmpty else { NSSound.beep(); return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ByteFormatter.format(bytes, as: format), forType: .string)
    }

    override func keyDown(with event: NSEvent) {
        let cmd = event.modifierFlags.contains(.command)
        let shift = event.modifierFlags.contains(.shift)
        if cmd {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "z": shift ? performRedo() : performUndo(); return
            case "c": copySelection(as: .hex); return
            case "a": selectAll(); return
            default: break
            }
        }
        // With a selection, Delete/Backspace routes to the remove/fill dialog.
        if selection != nil, event.keyCode == 51 || event.keyCode == 117 {
            if let sel = selection { onRequestDeleteSelection?(sel) }
            return
        }
        switch event.keyCode {
        case 123: shift ? extendSelection(-1) : moveCaret(-1)     // ←
        case 124: shift ? extendSelection(1) : moveCaret(1)       // →
        case 126: shift ? extendSelection(-16) : moveCaret(-16)   // ↑
        case 125: shift ? extendSelection(16) : moveCaret(16)     // ↓
        case 51:  if caret > 0 { doc.delete((caret - 1)..<caret); caret -= 1; refresh() }   // Backspace
        case 117: if caret < doc.count { doc.delete(caret..<(caret + 1)); refresh() }        // Delete
        case 34:  toggleInsertMode()                             // i → toggle insert/overwrite
        default:
            if let s = event.charactersIgnoringModifiers?.lowercased(),
               s.count == 1, let v = UInt8(s, radix: 16) {
                typeHex(v)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    /// Grow/shrink the selection from the anchor as the caret moves by `delta`.
    private func extendSelection(_ delta: Int) {
        if selection == nil { anchor = caret }
        caret = max(0, min(caret + delta, max(0, doc.count - 1)))
        nibbleHigh = true
        selection = min(anchor, caret)..<(max(anchor, caret) + 1)
        scrollToVisible(NSRect(x: 0, y: CGFloat(caret / 16) * rowHeight, width: 1, height: rowHeight))
        needsDisplay = true
        onChange?()
    }

    private func typeHex(_ v: UInt8) {
        if insertMode, nibbleHigh {
            doc.insert(at: caret, [0x00])                        // fresh byte to fill in
        } else if doc.byte(at: caret) == nil {
            doc.insert(at: caret, [0x00])                        // typing past the end appends
        }
        let cur = doc.byte(at: caret) ?? 0
        let newByte = nibbleHigh ? ((cur & 0x0F) | (v << 4)) : ((cur & 0xF0) | v)
        doc.overwrite(at: caret, with: [newByte])
        if nibbleHigh { nibbleHigh = false } else { nibbleHigh = true; caret += 1 }
        clampCaret(); refresh()
    }

    private func moveCaret(_ delta: Int) {
        caret = max(0, min(caret + delta, max(0, doc.count - 1)))
        nibbleHigh = true
        selection = nil
        needsDisplay = true
        onChange?()
    }

    private func clampCaret() { caret = max(0, min(caret, max(0, doc.count))) }

    private func refresh() {
        resize()
        needsDisplay = true
        onChange?()
    }
}

// MARK: - Window controller

final class HexEditorWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?

    private let path: String
    private let doc: HexDocument
    private let editor: HexEditorView
    private let statusLabel = NSTextField(labelWithString: "")
    private var didBackup = false
    private var lastFind: [UInt8] = []
    private var findDialog: InputDialog?

    init(path: String) {
        self.path = path
        let bytes = (try? Data(contentsOf: URL(fileURLWithPath: path))).map { Array($0) } ?? []
        self.doc = HexDocument(bytes)
        self.editor = HexEditorView(doc: doc)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        super.init(window: window)
        window.delegate = self
        buildUI()
        editor.onChange = { [weak self] in self?.updateStatus() }
        editor.onRequestDeleteSelection = { [weak self] range in self?.promptDeleteSelection(range) }
        updateStatus()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showWindow() {
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(editor)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.spacing = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        let save = NSButton(title: String(localized: "Save"), target: self, action: #selector(save))
        save.bezelStyle = .rounded; save.keyEquivalent = "s"; save.keyEquivalentModifierMask = .command
        let mode = NSButton(title: String(localized: "Toggle Insert/Overwrite"), target: self, action: #selector(toggleMode))
        mode.bezelStyle = .rounded
        let find = NSButton(title: String(localized: "Find…"), target: self, action: #selector(findBytes))
        find.bezelStyle = .rounded; find.keyEquivalent = "f"; find.keyEquivalentModifierMask = .command
        let replace = NSButton(title: String(localized: "Replace All…"), target: self, action: #selector(replaceAllBytes))
        replace.bezelStyle = .rounded
        let goto = NSButton(title: String(localized: "Go to…"), target: self, action: #selector(gotoAddress))
        goto.bezelStyle = .rounded; goto.keyEquivalent = "g"; goto.keyEquivalentModifierMask = .command
        toolbar.addArrangedSubview(save)
        toolbar.addArrangedSubview(mode)
        toolbar.addArrangedSubview(find)
        toolbar.addArrangedSubview(replace)
        toolbar.addArrangedSubview(goto)
        content.addSubview(toolbar)

        let scroll = NSScrollView()
        scroll.documentView = editor
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

    @objc private func toggleMode() { editor.toggleInsertMode() }

    private func hexString(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    @objc private func findBytes() {
        let dialog = InputDialog(title: String(localized: "Find"),
                                 prompt: String(localized: "Hex bytes (e.g. 48 65 6c) or text:"),
                                 initialValue: hexString(lastFind))
        dialog.onConfirm = { [weak self] input in
            guard let self else { return }
            // A valid, non-empty hex string is searched as bytes; otherwise as UTF-8 text.
            let trimmed = input.trimmingCharacters(in: .whitespaces)
            let pattern: [UInt8]?
            if let hex = ByteSearch.parseHex(trimmed), !hex.isEmpty {
                pattern = hex
            } else if !trimmed.isEmpty {
                pattern = Array(input.utf8)
            } else {
                pattern = nil
            }
            guard let pattern, !pattern.isEmpty else { NSSound.beep(); return }
            self.lastFind = pattern
            let from = self.editor.caretOffset + 1
            let idx = ByteSearch.firstIndex(of: pattern, in: self.doc.bytes, from: from)
                    ?? ByteSearch.firstIndex(of: pattern, in: self.doc.bytes, from: 0)
            if let idx { self.editor.selectRange(idx..<(idx + pattern.count)) } else { NSSound.beep() }
        }
        findDialog = dialog
        dialog.runModalDialog(over: window)
    }

    @objc private func gotoAddress() {
        let dialog = InputDialog(title: String(localized: "Go to Address"),
                                 prompt: String(localized: "Address (0x…, $…, …h, decimal, or an expression like 0x1000+16):"),
                                 initialValue: "")
        dialog.onConfirm = { [weak self] input in
            guard let self, let addr = HexAddress.parse(input) else { NSSound.beep(); return }
            self.editor.setCaret(Int(addr))
        }
        findDialog = dialog
        dialog.runModalDialog(over: window)
    }

    /// Ask whether to remove the selected bytes or fill them with a chosen byte.
    private func promptDeleteSelection(_ range: Range<Int>) {
        let count = range.count
        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("Delete %d selected byte(s)?", comment: ""), count)
        alert.informativeText = String(localized: "Remove them (shifting the rest), or overwrite them with a fill byte?")
        alert.addButton(withTitle: String(localized: "Remove"))
        alert.addButton(withTitle: String(localized: "Fill with Byte…"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            doc.delete(range)
            editor.reloadAfterExternalEdit()
        case .alertSecondButtonReturn:
            DispatchQueue.main.async { [weak self] in self?.promptFillByte(range) }
        default:
            break
        }
    }

    private func promptFillByte(_ range: Range<Int>) {
        let dialog = InputDialog(title: String(localized: "Fill Byte"),
                                 prompt: String(localized: "Fill value (hex, e.g. 00 or FF):"), initialValue: "00")
        dialog.onConfirm = { [weak self] input in
            guard let self, let bytes = ByteSearch.parseHex(input), bytes.count == 1 else { NSSound.beep(); return }
            self.doc.overwrite(at: range.lowerBound, with: Array(repeating: bytes[0], count: range.count))
            self.editor.reloadAfterExternalEdit()
        }
        findDialog = dialog
        dialog.runModalDialog(over: window)
    }

    @objc private func replaceAllBytes() {
        let findDlg = InputDialog(title: String(localized: "Replace — Find"),
                                  prompt: String(localized: "Find hex:"), initialValue: hexString(lastFind))
        findDlg.onConfirm = { [weak self] fs in
            guard let self, let pattern = ByteSearch.parseHex(fs), !pattern.isEmpty else { NSSound.beep(); return }
            self.lastFind = pattern
            // Defer the second dialog so the first modal session fully ends first.
            DispatchQueue.main.async { [weak self] in self?.promptReplacement(for: pattern) }
        }
        findDialog = findDlg
        findDlg.runModalDialog(over: window)
    }

    private func promptReplacement(for pattern: [UInt8]) {
        let dlg = InputDialog(title: String(localized: "Replace — With"),
                              prompt: String(localized: "Replacement hex (empty = delete):"), initialValue: "")
        dlg.onConfirm = { [weak self] rs in
            guard let self else { return }
            let replacement = rs.trimmingCharacters(in: .whitespaces).isEmpty ? [] : ByteSearch.parseHex(rs)
            guard let replacement else { NSSound.beep(); return }
            let indices = ByteSearch.allIndices(of: pattern, in: self.doc.bytes)
            // Replace from the end so earlier match indices stay valid.
            for i in indices.reversed() { self.doc.replace(i..<(i + pattern.count), with: replacement) }
            self.editor.reloadAfterExternalEdit()
            self.statusLabel.stringValue = String(format:
                NSLocalizedString("Replaced %d occurrence(s)", comment: ""), indices.count)
        }
        findDialog = dlg
        dlg.runModalDialog(over: window)
    }

    @objc private func save() {
        if DocumentFile.writeWithBackup(Data(doc.bytes), toPath: path, didBackup: &didBackup) {
            doc.markSaved()
            editor.needsDisplay = true
            updateStatus()
        }
    }

    private func updateStatus() {
        let name = (path as NSString).lastPathComponent
        window?.title = (doc.isModified ? "• " : "") + name + " — Hex"
        var text = String(format:
            NSLocalizedString("%@   offset 0x%llX   %d bytes%@", comment: ""),
            editor.modeName, Int64(editor.caretOffset), doc.count,
            doc.isModified ? "   —   " + NSLocalizedString("modified", comment: "") : "")
        if let sel = editor.selectedRange, !sel.isEmpty {
            text += String(format: NSLocalizedString("   —   sel 0x%llX…0x%llX (%d)", comment: ""),
                           Int64(sel.lowerBound), Int64(sel.upperBound - 1), sel.count)
        }
        statusLabel.stringValue = text
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard doc.isModified else { return true }
        switch DocumentFile.confirmClose(name: (path as NSString).lastPathComponent) {
        case .save: save(); return !doc.isModified
        case .discard: return true
        case .cancel: return false
        }
    }

    func windowWillClose(_ notification: Notification) { onClose?() }
}

#if DEBUG
// MARK: - Automation probes (F-400, F-401)

extension HexEditorWindowController {

    /// Run the real "Go to Address" command with `expression` answered from the script queue, and report
    /// where the caret ended up. Goes through `gotoAddress`, so the dialog's own parsing is what is
    /// measured — not a second copy of it in the harness.
    func automationGoto(_ expression: String) -> String {
        InputDialog.queueScriptedAnswer(expression)
        gotoAddress()
        return """
        expr=\(expression)
        caret=\(editor.caretOffset)
        answersleft=\(InputDialog.hasScriptedAnswers ? 1 : 0)
        """ + "\n"
    }

    /// Type into a real dialog field and use the window's own clipboard actions on it.
    ///
    /// The defect this exists for: this window binds ⌘C to "Copy (Hex)" and had no Paste item at all, so
    /// in the Go To field ⌘C copied the *file's bytes* and ⌘V did nothing. `answer` cannot cover it — a
    /// scripted answer means the dialog never appears — so the sheet is opened for real and driven
    /// through the same actions the menu items invoke.
    func automationDialogClipboard(_ typed: String) -> String {
        editor.selectAll()                       // so "Copy (Hex)" has something to put on the pasteboard
        NSPasteboard.general.clearContents()
        // Both halves, on purpose: with no field being edited the same action must still copy the
        // document's bytes, or the fix would have traded one wrong answer for another.
        editCopy()
        let withoutField = (NSPasteboard.general.string(forType: .string) ?? "").prefix(11)
        NSPasteboard.general.clearContents()
        gotoAddress()                            // a sheet, so this returns
        guard let field = window?.attachedSheet?.firstResponder as? NSTextView else {
            return "ERROR: no field editor in the sheet (attachedSheet=\(window?.attachedSheet != nil))\n"
        }
        field.insertText(typed, replacementRange: NSRange(location: 0, length: 0))
        field.selectAll(nil)

        editCopy()                               // exactly what ⌘C is bound to in this window
        let copied = NSPasteboard.general.string(forType: .string) ?? ""

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("PASTED-FROM-CLIPBOARD", forType: .string)
        field.selectAll(nil)
        // Straight to the field editor, not `to: nil`.
        //
        // `to: nil` is what the *menu item* does, and AppKit resolves that through the KEY window's
        // responder chain — which an application without activation does not have. A scripted session
        // frequently has none (a system consent panel took it in the guest), and `NSApp.activate` does
        // not take hold by the next line, so measuring that route says nothing about this app. What the
        // item is — that Paste exists at all and carries ⌘V, which is the half F-401 was about — is
        // measured in the menu dump instead.
        let pasteDelivered = NSApp.sendAction(#selector(NSText.paste(_:)), to: field, from: nil)
        let after = field.string

        if let sheet = window?.attachedSheet { window?.endSheet(sheet) }
        return """
        responder=\(String(describing: type(of: field)))
        copiedWithoutField=\(withoutField)
        typed=\(typed)
        copied=\(copied)
        pasteDelivered=\(pasteDelivered)
        fieldAfterPaste=\(after)
        """ + "\n"
    }
}
#endif

// MARK: - Contextual menu-bar menu (TODOS #189)

@MainActor
extension HexEditorWindowController: WindowContextMenuProviding {
    // Edit-menu wrappers forwarding to the hex view (its own copy/select-all are
    // view-level context-menu actions).
    // Each of these owns a ⌘-key the whole window shares with its dialogs, so each asks a focused text
    // field first — see AppMenu.forwardToEditedText. Without it, ⌘C in "Go to Address" copied the
    // file's bytes over what the user was trying to copy out of the field.
    @objc func editUndo() {
        if AppMenu.forwardToEditedText(Selector(("undo:"))) { return }
        editor.performUndo()
    }
    @objc func editRedo() {
        if AppMenu.forwardToEditedText(Selector(("redo:"))) { return }
        editor.performRedo()
    }
    @objc func editCopy() {
        if AppMenu.forwardToEditedText(#selector(NSText.copy(_:))) { return }
        editor.copySelectionHex()
    }
    @objc func editSelectAll() {
        if AppMenu.forwardToEditedText(#selector(NSText.selectAll(_:))) { return }
        editor.selectAll()
    }

    func makeEditMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Edit"))
        AppMenu.editItem(menu, String(localized: "Undo"), action: #selector(editUndo), target: self, key: "z")
        AppMenu.editItem(menu, String(localized: "Redo"), action: #selector(editRedo), target: self,
                         key: "z", mask: [.command, .shift])
        menu.addItem(.separator())
        AppMenu.editItem(menu, String(localized: "Copy (Hex)"), action: #selector(editCopy), target: self, key: "c")
        AppMenu.editItem(menu, String(localized: "Select All"), action: #selector(editSelectAll), target: self, key: "a")
        AppMenu.appendTextClipboardItems(to: menu)
        menu.addItem(.separator())
        AppMenu.editItem(menu, String(localized: "Find…"), action: #selector(findBytes), target: self, key: "f")
        AppMenu.editItem(menu, String(localized: "Go to…"), action: #selector(gotoAddress), target: self, key: "g")
        return menu
    }

    func makeWindowMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Hex Editor"))
        func add(_ title: String, _ selector: Selector, key: String = "", mask: NSEvent.ModifierFlags = []) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.keyEquivalentModifierMask = mask
            item.target = self
            menu.addItem(item)
        }
        add(String(localized: "Save"), #selector(save), key: "s", mask: .command)
        add(String(localized: "Toggle Insert/Overwrite"), #selector(toggleMode))
        menu.addItem(.separator())
        add(String(localized: "Find…"), #selector(findBytes), key: "f", mask: .command)
        add(String(localized: "Go to…"), #selector(gotoAddress), key: "g", mask: .command)
        add(String(localized: "Replace All…"), #selector(replaceAllBytes))
        return menu
    }
}
