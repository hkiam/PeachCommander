// SPDX-License-Identifier: Apache-2.0
// DuplicateFinderWindowController.swift - Grouped results UI for the duplicate
// finder (I17-T05). The engine (DuplicateFinder) returns byte-identical groups;
// this window shows them as a tree (group → its copies), lets the user tick which
// copies to remove (with a one-click "keep one per group" helper), reports the
// wasted space, and deletes the ticked files (to the Trash) via a host callback.
// Double-click reveals a file in the panel.

import AppKit
import PCFoundation
import PCOperations

@MainActor
final class DuplicateFinderWindowController: NSWindowController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private final class FileNode {
        let path: String
        var marked: Bool = false
        init(_ path: String) { self.path = path }
    }
    private final class GroupNode {
        let size: Int64
        var files: [FileNode]
        init(size: Int64, files: [FileNode]) { self.size = size; self.files = files }
        var wasted: Int64 { size * Int64(max(0, files.count - 1)) }
    }

    /// Delete the given paths (host moves them to the Trash + refreshes panels).
    var onDelete: (([String]) async -> Void)?
    /// Reveal a path in the active panel.
    var onReveal: ((String) -> Void)?

    private var groups: [GroupNode]
    private let canDelete: Bool
    private let outline = NSOutlineView()
    private let summary = NSTextField(labelWithString: "")
    private let deleteButton = NSButton()

    init(groups: [DuplicateGroup], canDelete: Bool) {
        self.groups = groups.map { GroupNode(size: $0.size, files: $0.paths.map(FileNode.init)) }
        self.canDelete = canDelete
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "Duplicate Files")
        window.minSize = NSSize(width: 480, height: 300)
        super.init(window: window)
        window.center()
        buildUI()
        updateSummary()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() { showWindow(nil); window?.makeKeyAndOrderFront(nil); outline.expandItem(nil, expandChildren: true) }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        for (id, title, w) in [("dup", String(localized: "File"), CGFloat(460)),
                               ("wasted", String(localized: "Wasted"), CGFloat(120))] {
            let col = NSTableColumn(identifier: .init(id))
            col.title = title
            col.width = w
            if id == "wasted" { col.headerCell.alignment = .right }
            outline.addTableColumn(col)
            if id == "dup" { outline.outlineTableColumn = col }
        }
        outline.dataSource = self
        outline.delegate = self
        outline.usesAlternatingRowBackgroundColors = true
        outline.rowSizeStyle = .default
        outline.target = self
        outline.doubleAction = #selector(rowDoubleClicked)

        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        summary.translatesAutoresizingMaskIntoConstraints = false
        summary.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        summary.textColor = .secondaryLabelColor

        let keepOne = NSButton(title: String(localized: "Select All but One per Group"),
                               target: self, action: #selector(selectAllButOne))
        let clear = NSButton(title: String(localized: "Deselect All"),
                             target: self, action: #selector(deselectAll))
        deleteButton.title = String(localized: "Delete Selected…")
        deleteButton.target = self
        deleteButton.action = #selector(deleteSelected)
        deleteButton.keyEquivalent = "\r"
        deleteButton.isEnabled = false
        if !canDelete { deleteButton.toolTip = String(localized: "Deletion is available for local files only.") }

        let buttons = NSStackView(views: [keepOne, clear, NSView(), deleteButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(scroll)
        content.addSubview(summary)
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            summary.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 6),
            summary.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            buttons.topAnchor.constraint(equalTo: summary.bottomAnchor, constant: 6),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
        ])
    }

    private var markedFiles: [FileNode] { groups.flatMap { $0.files }.filter(\.marked) }

    private func updateSummary() {
        let totalWasted = groups.reduce(Int64(0)) { $0 + $1.wasted }
        let markedCount = markedFiles.count
        summary.stringValue = String(
            format: String(localized: "%d group(s) · %@ recoverable · %d selected for deletion"),
            groups.count, SelectionSummaryFormatter.dynamicSize(totalWasted), markedCount)
        deleteButton.isEnabled = canDelete && markedCount > 0
    }

    // MARK: - Actions

    @objc private func selectAllButOne() {
        for g in groups {
            for (i, f) in g.files.enumerated() { f.marked = (i != 0) }   // keep the first copy
        }
        outline.reloadData()
        updateSummary()
    }

    @objc private func deselectAll() {
        for g in groups { for f in g.files { f.marked = false } }
        outline.reloadData()
        updateSummary()
    }

    @objc private func rowDoubleClicked() {
        if let f = outline.item(atRow: outline.clickedRow) as? FileNode { onReveal?(f.path) }
    }

    @objc private func markToggled(_ sender: NSButton) {
        guard let f = fileNode(forTag: sender.tag) else { return }
        f.marked = sender.state == .on
        updateSummary()
    }

    @objc private func deleteSelected() {
        let paths = markedFiles.map(\.path)
        guard !paths.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = String(localized: "Delete Selected Duplicates?")
        alert.informativeText = String(format: String(localized: "%d file(s) will be moved to the Trash."), paths.count)
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Move to Trash"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        Task { @MainActor in
            await onDelete?(paths)
            // Drop the deleted files; a group with <2 copies left is no longer a
            // duplicate set and is removed.
            let gone = Set(paths)
            for g in groups { g.files.removeAll { gone.contains($0.path) } }
            groups.removeAll { $0.files.count < 2 }
            outline.reloadData()
            outline.expandItem(nil, expandChildren: true)
            updateSummary()
        }
    }

    // MARK: - Node lookup (checkbox tags map to a flat file index)

    private var flatFiles: [FileNode] { groups.flatMap { $0.files } }
    private func fileNode(forTag tag: Int) -> FileNode? {
        let all = flatFiles
        return all.indices.contains(tag) ? all[tag] : nil
    }
    private func tag(for file: FileNode) -> Int {
        flatFiles.firstIndex { $0 === file } ?? -1
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return groups.count }
        return (item as? GroupNode)?.files.count ?? 0
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let g = item as? GroupNode { return g.files[index] }
        return groups[index]
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool { item is GroupNode }

    // MARK: - NSOutlineViewDelegate (view-based cells)

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let colID = tableColumn?.identifier.rawValue ?? ""
        if let g = item as? GroupNode {
            if colID == "wasted" {
                return label(SelectionSummaryFormatter.dynamicSize(g.wasted), align: .right, secondary: true)
            }
            let text = String(format: String(localized: "%d copies · %@ each"),
                              g.files.count, SelectionSummaryFormatter.dynamicSize(g.size))
            return label(text, align: .left, secondary: false, bold: true)
        }
        if let f = item as? FileNode {
            if colID == "wasted" { return label("", align: .right, secondary: true) }
            let id = NSUserInterfaceItemIdentifier("dupCheck")
            let check = (outlineView.makeView(withIdentifier: id, owner: self) as? NSButton) ?? {
                let b = NSButton(checkboxWithTitle: "", target: self, action: #selector(markToggled(_:)))
                b.identifier = id
                b.lineBreakMode = .byTruncatingMiddle
                return b
            }()
            check.title = f.path
            check.state = f.marked ? .on : .off
            check.tag = tag(for: f)
            check.isEnabled = canDelete
            return check
        }
        return nil
    }

    private func label(_ text: String, align: NSTextAlignment, secondary: Bool, bold: Bool = false) -> NSTextField {
        let id = NSUserInterfaceItemIdentifier(secondary ? "dupSecondary\(align.rawValue)" : "dupPrimary")
        let field = (outline.makeView(withIdentifier: id, owner: self) as? NSTextField) ?? {
            let f = NSTextField(labelWithString: "")
            f.identifier = id
            f.lineBreakMode = .byTruncatingMiddle
            return f
        }()
        field.stringValue = text
        field.alignment = align
        field.textColor = secondary ? .secondaryLabelColor : .labelColor
        field.font = bold ? .boldSystemFont(ofSize: NSFont.systemFontSize) : .systemFont(ofSize: NSFont.systemFontSize)
        return field
    }
}
