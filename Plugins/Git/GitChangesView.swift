// SPDX-License-Identifier: Apache-2.0
// GitChangesView.swift — the panel's Changes tab: the files a commit touched as a tree, and the diff.
//
// Phase 6. The diff is git's own unified diff, numbered and coloured — `PluginGit.parseUnifiedDiff` reads
// it, nothing here computes one, so this is not the second diff implementation the plan's §6 warned
// about. Double-click (or Return) on a file still opens the host's side-by-side compare window, which
// remains the place for a long or subtle change.
//
// Tree and diff sit side by side when the panel is wide (the bottom dock) and one above the other when
// it is narrow (the sidebar).

import AppKit

@MainActor
final class GitChangesView: NSView {
    private let services: PcHostServices
    private var theme: PluginTheme
    private let busy: NSProgressIndicator
    private let split = NSSplitView()
    private let outline = GitOutline()
    private let outlineScroll = NSScrollView()
    private let diff: GitDiffView
    private var tree: [TreeItem] = []
    /// "Show in the left/right panel": the full path and the side (0 left, 1 right). The panel does the
    /// navigating, because it has to keep itself still while the file panel moves (see `reveal`).
    var onReveal: ((String, Int) -> Void)?
    /// The listed files Git LFS stores, by the repository's current `.gitattributes`.
    private var lfs: Set<String> = []
    private var commit: PluginGit.Commit?
    private var root: String?
    /// The commit / file being loaded; a late result for anything else is dropped.
    private var loadingFiles: String?
    private var loadingDiff: String?

    init(services: PcHostServices, busy: NSProgressIndicator) {
        self.services = services
        self.theme = PluginTheme(services)
        self.busy = busy
        self.diff = GitDiffView(theme: theme)
        super.init(frame: NSRect(x: 0, y: 0, width: 400, height: 240))
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        outline.headerView = nil
        outline.rowHeight = 18
        outline.style = .plain
        let column = NSTableColumn(identifier: .init("file"))
        column.resizingMask = .autoresizingMask
        outline.addTableColumn(column)
        outline.outlineTableColumn = column
        // The tree fits its pane and truncates long names in the middle; by default the outline column
        // widens with every level of indentation and the pane scrolls sideways instead.
        outline.autoresizesOutlineColumn = false
        outline.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        outline.dataSource = self
        outline.delegate = self
        outline.target = self
        outline.doubleAction = #selector(compareSelected)
        outline.onEnter = { [weak self] in self?.compareSelected() }
        outline.menu = gitMenu([
            (L("Show changes of this file"), #selector(compareSelected)),
            (nil, nil),
            (L("Show in the left panel"), #selector(revealLeft)),
            (L("Show in the right panel"), #selector(revealRight)),
            (nil, nil),
            (L("Copy file path"), #selector(copyFilePath)),
        ], target: self)
        outlineScroll.documentView = outline
        outlineScroll.hasVerticalScroller = true
        outlineScroll.autohidesScrollers = true

        split.dividerStyle = .thin
        split.isVertical = false
        split.addArrangedSubview(outlineScroll)
        split.addArrangedSubview(diff)
        split.translatesAutoresizingMaskIntoConstraints = false
        addSubview(split)
        NSLayoutConstraint.activate([
            split.topAnchor.constraint(equalTo: topAnchor),
            split.leadingAnchor.constraint(equalTo: leadingAnchor),
            split.trailingAnchor.constraint(equalTo: trailingAnchor),
            split.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        // Pane sizes as preferences (the split view is free to give one pane everything otherwise, see the
        // log window's note on `setPosition`): the tree takes a third, the diff the rest.
        treeShare = outlineScroll.heightAnchor.constraint(equalTo: split.heightAnchor, multiplier: 0.35)
        treeShare?.priority = .init(500)
        treeShare?.isActive = true
        applyTheme(theme)
    }

    private var treeShare: NSLayoutConstraint?

    /// Side by side from this width on; above one another below it.
    private static let sideBySideWidth: CGFloat = 640

    override func layout() {
        super.layout()
        let wide = bounds.width >= Self.sideBySideWidth
        guard wide != split.isVertical else { return }
        split.isVertical = wide
        treeShare?.isActive = false
        treeShare = wide
            ? outlineScroll.widthAnchor.constraint(equalTo: split.widthAnchor, multiplier: 0.3)
            : outlineScroll.heightAnchor.constraint(equalTo: split.heightAnchor, multiplier: 0.35)
        treeShare?.priority = .init(500)
        treeShare?.isActive = true
        split.adjustSubviews()
        needsLayout = true
    }

    func applyTheme(_ theme: PluginTheme) {
        self.theme = theme
        outline.backgroundColor = theme.background
        outlineScroll.backgroundColor = theme.background
        outlineScroll.drawsBackground = true
        diff.applyTheme(theme)
        outline.reloadData()
    }

    // MARK: - Loading

    func show(commit: PluginGit.Commit, root: String) {
        guard commit.hash != self.commit?.hash || root != self.root else { return }
        self.commit = commit
        self.root = root
        loadingFiles = commit.hash
        tree = []
        outline.reloadData()
        diff.show(lines: [], truncated: false, placeholder: "")
        busy.startAnimation(nil)
        let hash = commit.hash
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PluginGitRepo.run(["-C", root] + PluginGit.nameStatusArguments(hash))
            let files = PluginGit.parseNameStatus(result.out)
            // Which of them LFS stores — a pointer file's diff is three lines of hash, which reads as
            // nonsense unless the tree says what it is. The paths go on standard input, however many.
            let paths = files.map(\.path)
            let lfs = paths.isEmpty ? [] : PluginGit.lfsPaths(PluginGitRepo.run(
                ["-C", root] + PluginGit.lfsCheckArguments, input: PluginGit.lfsCheckInput(paths)).out)
            DispatchQueue.main.async {
                // Stopped before the staleness check: the indicator counts, and a dropped result that
                // never stops it would leave it spinning.
                self?.busy.stopAnimation(nil)
                guard let self, self.loadingFiles == hash else { return }
                self.lfs = lfs
                self.tree = PluginGit.fileTree(files).map(TreeItem.init)
                self.outline.reloadData()
                self.outline.expandItem(nil, expandChildren: true)
                self.outline.sizeLastColumnToFit()
                // The first file is shown straight away, the way the reference products open a commit.
                if let row = (0..<self.outline.numberOfRows).first(where: {
                    (self.outline.item(atRow: $0) as? TreeItem)?.node.file != nil }) {
                    self.outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                } else {
                    self.diff.show(lines: [], truncated: false,
                                   placeholder: files.isEmpty ? L("This commit changes no files.") : "")
                }
            }
        }
    }

    /// The tree's files and the diff on screen, for the verification dump.
    func automationSummary() -> [String] {
        func files(_ items: [TreeItem]) -> [String] {
            items.flatMap { item in
                item.node.file.map { ["\($0.status) \($0.path)" + (lfs.contains($0.path) ? " LFS" : "")] }
                    ?? files(item.children)
            }
        }
        return ["files=" + files(tree).joined(separator: ", "),
                "selectedFile=\(selectedFile?.path ?? "<none>")"] + diff.automationSummary()
    }

    private var selectedFile: PluginGit.ChangedFile? {
        (outline.item(atRow: outline.selectedRow) as? TreeItem)?.node.file
    }

    private func loadDiff(_ file: PluginGit.ChangedFile) {
        guard let commit, let root else { return }
        let key = commit.hash + "\u{0}" + file.path
        loadingDiff = key
        // Both paths of a rename: limited to the new one, git sees an added file and diffs nothing.
        let paths = [file.oldPath, file.path].compactMap { $0 }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PluginGitRepo.run(["-C", root, "--no-optional-locks", "show", "--format=", "-m",
                                            "--first-parent", "--no-color", commit.hash, "--"] + paths)
            let parsed = PluginGit.parseUnifiedDiff(result.out)
            DispatchQueue.main.async {
                guard let self, self.loadingDiff == key else { return }
                self.diff.show(lines: parsed.lines, truncated: parsed.truncated,
                               placeholder: parsed.lines.isEmpty ? L("No textual changes.") : "")
            }
        }
    }

    // MARK: - Actions

    @objc private func compareSelected() {
        guard let commit, let root, let file = selectedFile else { return }
        GitCommitActions.compareFile(file.path, oldPath: file.oldPath, in: commit, root: root,
                                     services: services, busy: busy)
    }

    /// Verification only: select the first file of the tree and show it in a file panel.
    func revealFirstFile(side: Int) {
        guard let row = (0..<outline.numberOfRows).first(where: { (outline.item(atRow: $0) as? TreeItem)?.node.file != nil })
        else { return }
        outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        reveal(side: side)
    }

    @objc private func revealLeft() { reveal(side: 0) }
    @objc private func revealRight() { reveal(side: 1) }

    private func reveal(side: Int) {
        guard let path = selectedFullPath else { return }
        onReveal?(path, side)
    }

    /// The selected row on disk — a file, or a folder of the tree — when it is still there: a file this
    /// commit deleted, or one deleted since, has nowhere to be shown.
    private var selectedFullPath: String? {
        guard let root, let item = outline.item(atRow: outline.selectedRow) as? TreeItem else { return nil }
        let path = (root as NSString).appendingPathComponent(item.node.path)
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    @objc private func copyFilePath() {
        guard let root, let item = outline.item(atRow: outline.selectedRow) as? TreeItem else { return }
        gitCopyToClipboard((root as NSString).appendingPathComponent(item.node.path))
    }
}

/// An outline item. A class because NSOutlineView holds its items by identity.
private final class TreeItem {
    let node: PluginGit.FileTreeNode
    let children: [TreeItem]
    init(_ node: PluginGit.FileTreeNode) {
        self.node = node
        self.children = node.children.map(TreeItem.init)
    }
}

extension GitChangesView: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(revealLeft) || menuItem.action == #selector(revealRight) {
            return selectedFullPath != nil
        }
        return outline.selectedRow >= 0
    }
}

extension GitChangesView: NSOutlineViewDataSource, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? TreeItem)?.children.count ?? (item == nil ? tree.count : 0)
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (item as? TreeItem)?.children[index] ?? tree[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? TreeItem)?.node.isFolder ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let item = item as? TreeItem else { return nil }
        let cell = (outlineView.makeView(withIdentifier: .init("GitTreeCell"), owner: self) as? NSTableCellView)
            ?? Self.makeCell()
        let node = item.node
        cell.imageView?.image = NSImage(systemSymbolName: node.isFolder ? "folder.fill" : "doc",
                                        accessibilityDescription: nil)
        cell.imageView?.contentTintColor = node.isFolder ? .systemBlue : theme.secondaryText
        let text = NSMutableAttributedString()
        if let file = node.file {
            text.append(NSAttributedString(string: file.status + "  ", attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold),
                .foregroundColor: Self.statusColor(file.status),
            ]))
        }
        text.append(NSAttributedString(string: node.name, attributes: [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: theme.text,
        ]))
        if let file = node.file, lfs.contains(file.path) {
            text.append(NSAttributedString(string: "  LFS", attributes: [
                .font: NSFont.systemFont(ofSize: 9, weight: .semibold), .foregroundColor: NSColor.systemPurple,
            ]))
        }
        cell.textField?.attributedStringValue = text
        cell.toolTip = node.file?.oldPath.map { String(format: L("Renamed from %@"), $0) } ?? node.path
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        if let file = selectedFile { loadDiff(file) }
    }

    static func statusColor(_ status: String) -> NSColor {
        switch status {
        case "A": return .systemGreen
        case "D": return .systemRed
        case "R", "C": return .systemBlue
        default: return .systemOrange
        }
    }

    private static func makeCell() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = .init("GitTreeCell")
        let image = NSImageView()
        let field = NSTextField(labelWithString: "")
        field.lineBreakMode = .byTruncatingMiddle
        field.usesSingleLineMode = true
        for view in [image, field] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(view)
        }
        cell.imageView = image
        cell.textField = field
        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: 14),
            image.heightAnchor.constraint(equalToConstant: 14),
            field.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 4),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}

// MARK: - The inline diff

/// git's unified diff of one file, one table row per line: old number, new number, text, and the whole
/// row tinted for an added or removed line. A table rather than a text view because a row background is
/// what a diff needs, it stays fast on a five-thousand-line diff, and Cmd+C copies the selected lines.
@MainActor
final class GitDiffView: NSView {
    private let table = DiffTable()
    private let scroll = NSScrollView()
    private let placeholder = NSTextField(labelWithString: "")
    private var lines: [PluginGit.DiffLine] = []
    private var theme: PluginTheme
    /// The diff's own lines, without the "rest not shown" note `show` may append — what a line patch is
    /// built from. Row indices below the note are the same in both.
    private(set) var diffLines: [PluginGit.DiffLine] = []
    private(set) var isTruncated = false

    /// The rows the reader selected, and the one a right-click was on (selected rows win).
    var selectedRows: Set<Int> { Set(table.selectedRowIndexes) }
    var clickedRow: Int { table.clickedRow >= 0 ? table.clickedRow : table.selectedRow }

    /// Select diff rows without a click (the verification probe).
    func selectRows(_ rows: IndexSet) { table.selectRowIndexes(rows, byExtendingSelection: false) }

    /// A context menu for the lines — the working copy's stage / unstage / discard.
    var lineMenu: NSMenu? {
        get { table.menu }
        set { table.menu = newValue }
    }

    init(theme: PluginTheme) {
        self.theme = theme
        super.init(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        table.headerView = nil
        table.rowHeight = 16
        table.intercellSpacing = NSSize(width: 4, height: 0)
        table.style = .plain
        table.allowsMultipleSelection = true
        table.columnAutoresizingStyle = .noColumnAutoresizing
        for (id, width) in [("old", 34), ("new", 34), ("text", 600)] as [(String, CGFloat)] {
            let column = NSTableColumn(identifier: .init(id))
            column.width = width
            column.resizingMask = []
            table.addTableColumn(column)
        }
        table.dataSource = self
        table.delegate = self
        table.copyText = { [weak self] rows in
            guard let self else { return "" }
            return rows.compactMap { self.lines.indices.contains($0) ? self.lines[$0].text : nil }
                .joined(separator: "\n")
        }
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        placeholder.textColor = .secondaryLabelColor
        placeholder.alignment = .center
        for view in [scroll, placeholder] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            placeholder.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholder.topAnchor.constraint(equalTo: topAnchor, constant: 16),
        ])
        applyTheme(theme)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func applyTheme(_ theme: PluginTheme) {
        self.theme = theme
        table.backgroundColor = theme.background
        scroll.backgroundColor = theme.background
        scroll.drawsBackground = true
        table.reloadData()
    }

    func show(lines: [PluginGit.DiffLine], truncated: Bool, placeholder text: String) {
        diffLines = lines
        isTruncated = truncated
        var shown = lines
        if truncated {
            shown.append(.init(kind: .meta, text: L("… the rest of this diff is not shown. Double-click the file to compare it.")))
        }
        self.lines = shown
        placeholder.stringValue = text
        placeholder.isHidden = text.isEmpty
        // The text column is as wide as the longest line, so a long line scrolls rather than wraps.
        let font = Self.font
        let charWidth = ("M" as NSString).size(withAttributes: [.font: font]).width
        let longest = shown.map { $0.text.replacingOccurrences(of: "\t", with: "    ").count }.max() ?? 0
        table.tableColumn(withIdentifier: .init("text"))?.width = max(200, CGFloat(longest) * charWidth + 16)
        // The number columns are as wide as the largest number in this diff — five digits in a long file.
        let largest = shown.map { max($0.oldLine ?? 0, $0.newLine ?? 0) }.max() ?? 0
        let digits = CGFloat(max(String(largest).count, 2))
        for id in ["old", "new"] {
            table.tableColumn(withIdentifier: .init(id))?.width = digits * charWidth + 6
        }
        table.reloadData()
        table.scrollRowToVisible(0)
    }

    static let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

    func automationSummary() -> [String] {
        ["diffLines=\(lines.count)"] + lines.prefix(8).map { line in
            let number = line.newLine ?? line.oldLine
            return "diff \(line.kind.rawValue) \(number.map(String.init) ?? "-") \(line.text)"
        }
    }

    private func background(_ kind: PluginGit.DiffLine.Kind) -> NSColor? {
        switch kind {
        case .added:   return NSColor.systemGreen.withAlphaComponent(theme.isDark ? 0.22 : 0.16)
        case .removed: return NSColor.systemRed.withAlphaComponent(theme.isDark ? 0.22 : 0.14)
        case .hunk:    return theme.separator.withAlphaComponent(0.25)
        default:       return nil
        }
    }
}

extension GitDiffView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { lines.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let id = tableColumn?.identifier.rawValue, lines.indices.contains(row) else { return nil }
        let field = (tableView.makeView(withIdentifier: .init("GitDiffText"), owner: self) as? NSTextField)
            ?? {
                let f = NSTextField(labelWithString: "")
                f.identifier = .init("GitDiffText")
                f.usesSingleLineMode = true
                f.lineBreakMode = .byClipping
                f.font = Self.font
                return f
            }()
        let line = lines[row]
        switch id {
        case "old":
            field.stringValue = line.oldLine.map(String.init) ?? ""
            field.alignment = .right
            field.textColor = theme.secondaryText
        case "new":
            field.stringValue = line.newLine.map(String.init) ?? ""
            field.alignment = .right
            field.textColor = theme.secondaryText
        default:
            field.alignment = .left
            // Tabs as four spaces: a table cell has no tab stops, and a raw tab collapses.
            field.stringValue = line.text.replacingOccurrences(of: "\t", with: "    ")
            switch line.kind {
            case .hunk, .meta, .binary: field.textColor = theme.secondaryText
            default: field.textColor = theme.text
            }
        }
        return field
    }

    func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
        guard lines.indices.contains(row) else { return }
        rowView.backgroundColor = background(lines[row].kind) ?? theme.background
    }
}

/// A table whose Cmd+C copies the selected diff lines as text.
@MainActor
private final class DiffTable: NSTableView {
    var copyText: ((IndexSet) -> String)?

    @objc func copy(_ sender: Any?) {
        guard let text = copyText?(selectedRowIndexes), !text.isEmpty else { return }
        gitCopyToClipboard(text)
    }
}
