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

    func applyTheme() {
        layer?.backgroundColor = Theme.current.listBackground.cgColor
        outline.backgroundColor = Theme.current.listBackground
        scroll.backgroundColor = Theme.current.listBackground
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
        text.textColor = Theme.current.listText
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
