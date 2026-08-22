// SPDX-License-Identifier: Apache-2.0
// PanelTreeView.swift - Optional folder-tree column beside a panel's file list (F-015).
//
// TC's Ctrl+F8 "separate tree": a narrow NSOutlineView docked at the leading edge of
// the panel that mirrors the local file system. Selecting a node navigates the panel's
// list into that folder; navigating the list reveals + selects the matching node.
// Local file system only — archives and plugin mounts don't get a tree. Children are
// listed lazily (per level, on expansion) via FileManager, so even "/" opens instantly.

import AppKit
import PCFoundation

/// One directory node in the tree. Children are listed once, on first access, and cached.
@MainActor
final class FSTreeNode {
    let url: URL
    let name: String
    private var loadedChildren: [FSTreeNode]?

    init(url: URL, name: String) {
        self.url = url
        self.name = name
    }

    /// Immediate subdirectories, sorted case-insensitively, hidden folders excluded.
    var children: [FSTreeNode] {
        if let loadedChildren { return loadedChildren }
        let fm = FileManager.default
        let kids = (try? fm.contentsOfDirectory(at: url,
                                                includingPropertiesForKeys: [.isDirectoryKey],
                                                options: [.skipsHiddenFiles, .skipsPackageDescendants])) ?? []
        let dirs = kids.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .map { FSTreeNode(url: $0, name: $0.lastPathComponent) }
        loadedChildren = dirs
        return dirs
    }

    /// Drop the cached children so the next access re-reads the directory.
    func invalidate() { loadedChildren = nil }
}

@MainActor
final class PanelTreeView: NSView, NSOutlineViewDataSource, NSOutlineViewDelegate {
    /// Announced instead of an unnamed outline (I19 T06).
    override func accessibilityLabel() -> String? {
        super.accessibilityLabel() ?? String(localized: "Folder tree")
    }

    /// Called when the user picks a folder in the tree (navigate the panel there).
    var onSelect: ((String) -> Void)?

    static let defaultWidth: CGFloat = 200

    private let outline = NSOutlineView()
    private let scroll = NSScrollView()
    private let root = FSTreeNode(url: URL(fileURLWithPath: "/"), name: "/")
    /// While revealing a path programmatically, don't fire `onSelect` for the
    /// selection change we cause ourselves (which would re-navigate in a loop).
    private var suppressSelection = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = Theme.current.listBackground.cgColor

        outline.setAccessibilityLabel(String(localized: "Folder tree"))

        outline.headerView = nil
        outline.rowSizeStyle = .small
        outline.backgroundColor = Theme.current.listBackground
        outline.autoresizesOutlineColumn = false
        outline.indentationPerLevel = 12
        let col = NSTableColumn(identifier: .init("folder"))
        col.resizingMask = .autoresizingMask
        outline.addTableColumn(col)
        outline.outlineTableColumn = col
        outline.dataSource = self
        outline.delegate = self
        outline.allowsEmptySelection = true

        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = Theme.current.listBackground
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    #if DEBUG
    /// Diagnostic: what this tree is actually painted with, as opposed to what it was told (F-015).
    ///
    /// The row colour is read from a row rather than from the class, because that is where the defect
    /// lived: cells are made once and reused, so what the theme says and what the user sees are two
    /// different questions.
    /// `text` is nil when there is no row view to read — which is a different answer from a colour and
    /// has to stay one (F-445 follow-up).
    ///
    /// It used to fall back to `.labelColor`, and that is not a neutral default: outside a dark drawing
    /// appearance it resolves to exactly `#000000`. So a probe that found nothing reported black, the
    /// light palette *expects* black and passed, and every dark palette failed with a number that looked
    /// like a painting defect. The full suite said the tree was black for four palettes; the tree was
    /// fine and the probe had found no rows.
    var automationColours: (background: NSColor, text: NSColor?) {
        // Lay out first. `reloadData` only marks the rows as needing rebuilding; on screen that
        // happens before the next frame, but this reads in the same turn it was called from and
        // would otherwise find no row views at all — a red herring that cost an hour once already.
        outline.layoutSubtreeIfNeeded()
        // The first *visible* row, not row 0. NSTableView only vends views for rows inside the visible
        // rect, and a tree that has revealed the current folder is scrolled — which the panel's tree
        // almost always is, while the shared one usually still shows "/" at the top. So row 0 had no
        // view, the probe answered with its fallback, and which of the two trees failed depended on
        // where the previous scenario had left them. `makeIfNecessary: false` stays: the point is to
        // read a row that already existed when the palette changed, because a freshly made cell is
        // correctly coloured by construction and proves nothing.
        let visible = outline.rows(in: outline.visibleRect)
        guard visible.length > 0 else { return (outline.backgroundColor, nil) }
        let text = (outline.view(atColumn: 0, row: visible.location,
                                makeIfNecessary: false) as? NSTableCellView)?.textField?.textColor
        return (outline.backgroundColor, text)
    }

    /// Diagnostic: the colour of a row the user opens *after* the theme changed (F-015).
    ///
    /// A different question from `automationColours`, which reads a row that was on screen when the
    /// theme was applied and so was rebuilt by the reload. A row opened afterwards may come from the
    /// reuse pool instead.
    ///
    /// Measured, not assumed: with the colour set only where a cell is *constructed*, this probe still
    /// read the right colour — after a reload the pool hands back nothing stale here. So it is not
    /// evidence for the current arrangement, it is a guard on the case that would break if a later
    /// change dropped the reload or started reusing across one.
    /// Nil for the same reason as `automationColours`: "there was no row to open" is not a colour.
    var automationColourOfRowOpenedLater: NSColor? {
        guard outline.numberOfRows > 0, let first = outline.item(atRow: 0) else { return nil }
        outline.expandItem(first)
        outline.layoutSubtreeIfNeeded()
        guard outline.numberOfRows > 1 else { return nil }
        return (outline.view(atColumn: 0, row: 1, makeIfNecessary: true) as? NSTableCellView)?
            .textField?.textColor
    }
    #endif

    /// Repaint in the current theme.
    ///
    /// This existed and nobody called it, which is the whole of the bug: the colours were read once
    /// when the view was built — before the theme is loaded from the configuration — so the tree kept
    /// the light defaults whatever the user had chosen. With Midnight that is a white column of pale
    /// text beside two dark panels.
    ///
    /// The row text is not set here. It is set where a row is built, and the reload below runs that
    /// for every row — which also keeps the expansion state, because the data source has not changed.
    func applyTheme() {
        layer?.backgroundColor = Theme.current.listBackground.cgColor
        outline.backgroundColor = Theme.current.listBackground
        scroll.backgroundColor = Theme.current.listBackground
        // The enclosing clip view paints the area below the last row; without it a short tree in a
        // tall column is theme-coloured at the top and white underneath.
        scroll.contentView.wantsLayer = true
        scroll.contentView.layer?.backgroundColor = Theme.current.listBackground.cgColor
        scroll.drawsBackground = true
        outline.reloadData()
    }

    // MARK: - Reveal / sync

    /// Expand the tree down to `path` and select that node, without triggering a
    /// navigation callback. Ignored for non-local paths (archives / plugin mounts).
    func reveal(path: String) {
        guard path.hasPrefix("/") else { return }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return }

        // Walk the ancestry from the root, expanding + descending one node per component.
        let target = URL(fileURLWithPath: path).standardizedFileURL
        var node = root
        outline.expandItem(node)
        let components = target.pathComponents.dropFirst()   // drop leading "/"
        for comp in components {
            guard let next = node.children.first(where: { $0.name == comp }) else { break }
            outline.expandItem(next)
            node = next
        }
        let row = outline.row(forItem: node)
        guard row >= 0 else { return }
        suppressSelection = true
        outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        outline.scrollRowToVisible(row)
        suppressSelection = false
    }

    /// Re-read a directory's children (e.g. after a folder is created/removed) and
    /// refresh its subtree if it is currently shown.
    func refresh(path: String) {
        guard let node = existingNode(for: path) else { return }
        node.invalidate()
        outline.reloadItem(node, reloadChildren: true)
    }

    private func existingNode(for path: String) -> FSTreeNode? {
        let target = URL(fileURLWithPath: path).standardizedFileURL
        var node = root
        for comp in target.pathComponents.dropFirst() {
            guard let next = node.children.first(where: { $0.name == comp }) else { return nil }
            node = next
        }
        return node
    }

    // MARK: - NSOutlineViewDataSource / Delegate

    private func node(_ item: Any?) -> FSTreeNode { (item as? FSTreeNode) ?? root }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        item == nil ? 1 : node(item).children.count
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        item == nil ? root : node(item).children[index]
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any?) -> Bool {
        // Optimistic: any folder is treated as expandable so the disclosure triangle
        // appears without eagerly listing every child. Empty folders simply show none.
        item != nil
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let folder = node(item)
        let id = NSUserInterfaceItemIdentifier("FolderCell")
        let cell = (outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView)
            ?? Self.makeCell(id: id)
        cell.textField?.stringValue = folder === root ? "/" : folder.name
        // The one place the row colour is set. Not where the cell is *made*: `makeView` hands back
        // recycled cells, so a colour set at construction is whatever the theme was the first time
        // that cell appeared. Setting it in both places is worse than it looks — either one alone
        // then covers for the other, so neither can be shown to be doing the work.
        cell.textField?.textColor = Theme.current.listText
        cell.imageView?.image = NSWorkspace.shared.icon(forFile: folder.url.path)
        return cell
    }

    private static func makeCell(id: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = id
        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        let text = NSTextField(labelWithString: "")
        text.translatesAutoresizingMaskIntoConstraints = false
        text.lineBreakMode = .byTruncatingTail
        text.font = NSFont.systemFont(ofSize: 11)
        cell.addSubview(icon)
        cell.addSubview(text)
        cell.imageView = icon
        cell.textField = text
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 14),
            icon.heightAnchor.constraint(equalToConstant: 14),
            text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 4),
            text.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !suppressSelection, outline.selectedRow >= 0,
              let folder = outline.item(atRow: outline.selectedRow) as? FSTreeNode else { return }
        onSelect?(folder.url.path)
    }
}
