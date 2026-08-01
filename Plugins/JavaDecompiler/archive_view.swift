// SPDX-License-Identifier: Apache-2.0
// archive_view.swift — F3 on a whole JAR, APK or DEX (F-349).
//
// F3 on a single .class shows one file (see java_decompiler.swift). F3 on a JAR runs the engine
// once over the whole archive and shows the result as a package tree with a source panel — which
// is the only way "where is this string used?" is answerable at all, since the answer is in a class
// whose name you do not yet know.
//
// This does not collide with opening a JAR as an archive: Enter browses it through the host's built-in
// ZIP support, F3 decompiles it. The two verbs were already separate, so both fit.
//
// Nothing here spawns a process or parses a config file. Running the engine, caching the tree,
// building the node hierarchy and scanning every class live in Plugins/SDK/PluginDecompiler.swift,
// so an .apk plugin or a future .wasm one inherits all of it and supplies only a detect string.

import AppKit

final class DecompiledArchiveView: DecompilerListerView {
    // Left: the tree. Right: one class. An NSSplitView rather than constraints, because the
    // divider should be draggable — a package name can be long, and a fixed split would truncate
    // either the tree or the code depending on the archive.
    private let split = NSSplitView()
    private let treeScroll = NSScrollView()
    private let outline = NSOutlineView()
    private let scroll = NSScrollView()
    private let text = NSTextView()

    private let enginePopup = NSPopUpButton()
    private let revealButton = NSButton(title: L("Engine Folder…"), target: nil, action: nil)
    private let searchField = NSSearchField()
    private let status = NSTextField(labelWithString: "")

    private let path: String
    private let kind: String
    private let configRootPath: String
    private let registry: PluginDecompilerRegistry
    /// Engines that can do a whole archive of this kind — not merely handle the extension.
    private let candidates: [PluginDecompilerEngine]

    /// Where the current engine's result sits on disk. Everything is read from here on demand.
    private var resultDirectory = ""
    /// Every source file in the result, relative to `resultDirectory`.
    private var files: [String] = []
    /// The tree as shown: the whole archive, or only what a search matched.
    private var roots: [PluginDecompilerNode] = []
    /// The file the source panel is showing, so a search hit can scroll within it.
    private var currentFile: String?
    /// Raised to abandon a scan whose query the user has already replaced.
    private var searchGeneration = 0

    init(path: String, configRoot: String) {
        self.path = path
        self.configRootPath = configRoot
        self.kind = (path as NSString).pathExtension.lowercased()
        self.registry = PluginDecompilerRegistry(configRoot: configRoot)
        self.candidates = registry.archiveEngines(for: kind)
        super.init(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        build()
        log.info("open archive \((path as NSString).lastPathComponent, privacy: .public): \(self.candidates.count) engine(s), available: \(self.candidates.filter(\.isAvailable).map(\.id).joined(separator: ","), privacy: .public)")
        // The engine chosen last for this kind, if it can still run; the same rule as the
        // single-class view, and stored in the same file so the two agree.
        let preferred = PluginDecompilerPreference.read(configRoot: configRoot)[kind]
        let initial = candidates.firstIndex { $0.id == preferred && $0.isAvailable }
            ?? candidates.firstIndex { $0.isAvailable } ?? 0
        if candidates.isEmpty {
            showMessage(PluginDecompileError.noEngine(kind: kind).userMessage, includingInstallHelp: true)
        } else {
            enginePopup.selectItem(at: initial)
            run(candidates[initial])
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Layout

    private func build() {
        outline.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("class")))
        outline.headerView = nil
        outline.dataSource = self
        outline.delegate = self
        outline.rowSizeStyle = .default
        outline.autoresizesOutlineColumn = true
        // Double-click and Enter both open — a tree the keyboard cannot drive is a tree a file
        // manager's users will complain about.
        outline.target = self
        outline.doubleAction = #selector(rowActivated)
        outline.action = #selector(rowActivated)
        treeScroll.documentView = outline
        treeScroll.hasVerticalScroller = true
        treeScroll.autohidesScrollers = true

        text.isEditable = false
        text.isRichText = false
        text.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        text.textContainerInset = NSSize(width: 6, height: 6)
        scroll.documentView = text
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true

        split.isVertical = true
        split.dividerStyle = .thin
        split.addArrangedSubview(treeScroll)
        split.addArrangedSubview(scroll)
        split.translatesAutoresizingMaskIntoConstraints = false

        for (i, engine) in candidates.enumerated() {
            enginePopup.addItem(withTitle: engine.name + (engine.isAvailable ? "" : " — " + L("not installed")))
            enginePopup.lastItem?.tag = i
        }
        enginePopup.target = self
        enginePopup.action = #selector(engineChanged)
        enginePopup.isEnabled = candidates.count > 1
        revealButton.target = self
        revealButton.action = #selector(revealEngineFolder)
        revealButton.bezelStyle = .rounded

        searchField.placeholderString = L("Search all classes")
        searchField.target = self
        searchField.action = #selector(searchChanged)
        // Only on Enter, not per keystroke: each scan reads every class in the archive, and doing
        // that while someone is still typing would spend minutes answering queries they abandoned.
        searchField.sendsWholeSearchString = true
        searchField.isEnabled = false

        status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail

        for v in [enginePopup, revealButton, searchField, status] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        addSubview(split)
        NSLayoutConstraint.activate([
            enginePopup.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            enginePopup.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            revealButton.centerYAnchor.constraint(equalTo: enginePopup.centerYAnchor),
            revealButton.leadingAnchor.constraint(equalTo: enginePopup.trailingAnchor, constant: 8),
            searchField.centerYAnchor.constraint(equalTo: enginePopup.centerYAnchor),
            searchField.leadingAnchor.constraint(equalTo: revealButton.trailingAnchor, constant: 12),
            searchField.widthAnchor.constraint(equalToConstant: 220),
            status.centerYAnchor.constraint(equalTo: enginePopup.centerYAnchor),
            status.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 12),
            status.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            split.topAnchor.constraint(equalTo: enginePopup.bottomAnchor, constant: 6),
            split.leadingAnchor.constraint(equalTo: leadingAnchor),
            split.trailingAnchor.constraint(equalTo: trailingAnchor),
            split.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        // A starting split, not a rule: the divider is draggable from here on.
        split.setPosition(280, ofDividerAt: 0)
    }

    // MARK: Running the engine

    @objc private func engineChanged() {
        let i = enginePopup.selectedItem?.tag ?? 0
        guard candidates.indices.contains(i) else { return }
        PluginDecompilerPreference.set(engine: candidates[i].id, forKind: kind, configRoot: configRootPath)
        run(candidates[i])
    }

    @objc private func revealEngineFolder() {
        let dir = PluginDecompilerRegistry.engineDirectory(configRoot: configRootPath)
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: dir)])
    }

    private func run(_ engine: PluginDecompilerEngine) {
        guard let cacheDir = PluginDecompilerCache.treeDirectory(path: path, engine: engine,
                                                                 configRoot: configRootPath) else {
            showMessage(PluginDecompileError.notReadable(L("This file could not be read.")).userMessage,
                        includingInstallHelp: false)
            return
        }
        // A finished result from a previous session, reused as-is. The marker is what makes this
        // safe: a directory left behind by a timeout would otherwise be served as a complete
        // archive with classes silently missing.
        if PluginDecompilerCache.treeIsComplete(cacheDir) {
            let found = PluginDecompilerRunner.sourceFiles(in: cacheDir)
            if !found.isEmpty {
                log.info("\(engine.id, privacy: .public): tree served from cache, \(found.count) file(s)")
                present(files: found, directory: cacheDir, engine: engine, fromCache: true)
                return
            }
        }
        guard engine.isAvailable else {
            showMessage((engine.missingPath.map {
                PluginDecompileError.engineMissing(engine: engine.name, path: $0)
            } ?? .engineMissing(engine: engine.name, path: engine.tool)).userMessage,
                        includingInstallHelp: true, note: engine.note)
            return
        }
        roots = []
        outline.reloadData()
        searchField.isEnabled = false
        // Whole archives are minutes, not seconds. Say so, because a progress-free wait that long
        // is indistinguishable from a hang.
        status.stringValue = String(format: L("Decompiling %@ with %@ — this can take a while…"),
                                   (path as NSString).lastPathComponent, engine.name)
        text.string = ""
        let file = path
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PluginDecompilerRunner.runArchive(engine, input: file, outputDirectory: cacheDir)
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let found):
                    PluginDecompilerCache.markTreeComplete(cacheDir)
                    log.info("\(engine.id, privacy: .public): produced \(found.count) file(s)")
                    self.present(files: found, directory: cacheDir, engine: engine, fromCache: false)
                case .failure(let error):
                    log.warning("\(engine.id, privacy: .public): \(error.userMessage, privacy: .public)")
                    self.showMessage(error.userMessage, includingInstallHelp: false, note: engine.note)
                }
            }
        }
    }

    private func present(files: [String], directory: String, engine: PluginDecompilerEngine,
                         fromCache: Bool) {
        self.files = files
        self.resultDirectory = directory
        roots = PluginDecompilerNode.tree(from: files)
        outline.reloadData()
        searchField.isEnabled = true
        status.stringValue = String(format: fromCache ? L("%@ — %d classes (cached)")
                                                     : L("%@ — %d classes"),
                                   engine.name, files.count)
        log.info("tree: \(self.outline.numberOfRows) row(s) from \(files.count) file(s)")
        // Expand only the top level. Expanding everything in an archive with thousands of packages
        // costs a visibly long pause and leaves a tree no one can scan.
        for root in roots { outline.expandItem(root) }
        // Open something straight away, so the panel is not blank while the user works out that the
        // tree on the left is clickable.
        if let first = PluginDecompilerNode.shallowestLeaf(in: roots),
           let rel = first.relativePath { reveal(rel) }
    }

    /// A message in the source panel, with the install instructions when that is the problem.
    private func showMessage(_ message: String, includingInstallHelp: Bool, note: String? = nil) {
        status.stringValue = message
        var body = [message, ""]
        if let note, !note.isEmpty { body += [note, ""] }
        if includingInstallHelp {
            body.append(L("Install one of these engines, then reopen this file:"))
            body.append("")
            let engineDir = PluginDecompilerRegistry.engineDirectory(configRoot: configRootPath)
            // Only engines that can do a whole archive: offering javap here would recommend an
            // engine that cannot answer this question however well it is installed.
            for engine in PluginDecompilerEngine.builtIns(engineDirectory: engineDir)
            where engine.handlesArchive(kind: kind) {
                body.append("  • \(engine.name)")
                if let n = engine.note { body.append("    \(n)") }
            }
            body.append("")
            body.append(L("“Engine Folder…” opens the folder they belong in."))
        }
        text.string = body.joined(separator: "\n")
    }

    // MARK: Showing one class

    @objc private func rowActivated() {
        guard let node = outline.item(atRow: outline.selectedRow) as? PluginDecompilerNode else { return }
        if node.isLeaf, let rel = node.relativePath { reveal(rel) }
        else if outline.isItemExpanded(node) { outline.collapseItem(node) }
        else { outline.expandItem(node) }
    }

    /// Show a class and make its row visible, expanding the packages above it.
    ///
    /// Selecting a row inside a collapsed package used to leave the source panel showing a class the
    /// tree gave no sign of — `row(forItem:)` answers -1 for a hidden row, so the selection was
    /// silently dropped while the text stayed. Walking the path down and expanding as it goes keeps
    /// the two halves of the view telling the same story.
    private func reveal(_ relativePath: String, scrollingToLine line: Int? = nil) {
        show(file: relativePath, scrollingToLine: line)
        var remaining = relativePath
        var level = roots
        while let match = level.first(where: {
            remaining == $0.name || remaining.hasPrefix($0.name + "/")
        }) {
            if match.isLeaf { break }
            outline.expandItem(match)
            remaining = String(remaining.dropFirst(match.name.count + 1))
            level = match.children
        }
        guard let node = leaf(for: relativePath, in: roots) else { return }
        let row = outline.row(forItem: node)
        guard row >= 0 else { return }
        outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        outline.scrollRowToVisible(row)
    }

    /// Read one class from the result directory and highlight it.
    private func show(file rel: String, scrollingToLine line: Int? = nil) {
        guard let source = PluginDecompilerRunner.readSource(rel, from: resultDirectory) else {
            text.string = String(format: L("%@ could not be read."), rel)
            return
        }
        currentFile = rel
        let font = text.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        text.textStorage?.setAttributedString(
            PluginSyntax.highlight(source, palette: .system, font: font))
        if let line { scroll(to: line) } else { text.scrollRangeToVisible(NSRange(location: 0, length: 0)) }
    }

    private func scroll(to line: Int) {
        let ns = text.string as NSString
        var current = 1
        var index = 0
        while current < line, index < ns.length {
            index = NSMaxRange(ns.lineRange(for: NSRange(location: index, length: 0)))
            current += 1
        }
        let range = ns.lineRange(for: NSRange(location: min(index, ns.length), length: 0))
        text.setSelectedRange(range)
        text.scrollRangeToVisible(range)
    }

    // MARK: Searching every class

    @objc private func searchChanged() {
        let needle = searchField.stringValue
        searchGeneration += 1
        let generation = searchGeneration
        guard !needle.isEmpty else {
            // Back to the whole archive, not to an empty tree.
            roots = PluginDecompilerNode.tree(from: files)
            outline.reloadData()
            for root in roots { outline.expandItem(root) }
            status.stringValue = String(format: L("%d classes"), files.count)
            return
        }
        status.stringValue = String(format: L("Searching %d classes…"), files.count)
        let all = files, directory = resultDirectory
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PluginDecompilerSearch.scan(files: all, in: directory, for: needle,
                                                    matchCase: false,
                                                    isCancelled: { [weak self] in
                // Read on a background thread but only ever written on the main one, so this is a
                // comparison against a value that changes rather than a shared mutation.
                self?.searchGeneration != generation
            })
            DispatchQueue.main.async {
                guard let self, self.searchGeneration == generation else { return }
                self.showSearchResults(result.hits, capped: result.capped, needle: needle)
            }
        }
    }

    private func showSearchResults(_ hits: [PluginDecompilerSearch.Hit], capped: Bool, needle: String) {
        guard !hits.isEmpty else {
            status.stringValue = String(format: L("“%@” — no match in %d classes"), needle, files.count)
            roots = []
            outline.reloadData()
            return
        }
        // The tree narrows to what matched, keeping the package structure so a hit's location is
        // still readable — a flat list of file names loses exactly the context being looked for.
        roots = PluginDecompilerNode.tree(from: hits.map(\.relativePath))
        outline.reloadData()
        for root in roots { expandAll(root) }
        status.stringValue = capped
            ? String(format: L("“%@” — %d of many classes (search was capped)"), needle, hits.count)
            : String(format: L("“%@” — %d of %d classes"), needle, hits.count, files.count)
        // Jump straight to the first hit's line: finding the file is half the answer.
        if let first = hits.first { reveal(first.relativePath, scrollingToLine: first.line) }
    }

    /// Expanding a filtered tree is safe: it only holds what matched.
    private func expandAll(_ node: PluginDecompilerNode) {
        outline.expandItem(node)
        for child in node.children where !child.isLeaf { expandAll(child) }
    }

    private func leaf(for relativePath: String, in nodes: [PluginDecompilerNode]) -> PluginDecompilerNode? {
        for node in nodes {
            if node.relativePath == relativePath { return node }
            if let found = leaf(for: relativePath, in: node.children) { return found }
        }
        return nil
    }

    // MARK: Viewer commands

    /// The host's F7. Searches the open class first, then every other class in the archive.
    ///
    /// Falling through to the archive is the point of this view: a viewer that answers "not found"
    /// while the string sits in the class next door would be technically right and useless.
    override func find(_ needle: String, matchCase: Bool) -> Bool {
        let haystack = text.string
        let options: String.CompareOptions = matchCase ? [] : [.caseInsensitive]
        if let range = haystack.range(of: needle, options: options) {
            let ns = NSRange(range, in: haystack)
            text.scrollRangeToVisible(ns)
            text.setSelectedRange(ns)
            return true
        }
        let others = files.filter { $0 != currentFile }
        let result = PluginDecompilerSearch.scan(files: others, in: resultDirectory, for: needle,
                                                matchCase: matchCase)
        guard let hit = result.hits.first else { return false }
        reveal(hit.relativePath, scrollingToLine: hit.line)
        status.stringValue = String(format: L("Found in %@"), hit.relativePath)
        return true
    }

    override func selectAll() {
        text.setSelectedRange(NSRange(location: 0, length: (text.string as NSString).length))
    }

    override func changeFontSize(by delta: CGFloat) {
        let size = min(32, max(8, (text.font?.pointSize ?? 12) + delta))
        let font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        text.font = font
        text.textStorage?.addAttribute(.font, value: font,
                                       range: NSRange(location: 0, length: text.textStorage?.length ?? 0))
    }

    override func copySelection() {
        let sel = text.selectedRange()
        let content = sel.length > 0 ? (text.string as NSString).substring(with: sel) : text.string
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
}

// MARK: - The tree

extension DecompiledArchiveView: NSOutlineViewDataSource, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? PluginDecompilerNode)?.children.count ?? roots.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (item as? PluginDecompilerNode)?.children[index] ?? roots[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !((item as? PluginDecompilerNode)?.isLeaf ?? true)
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?,
                     item: Any) -> NSView? {
        guard let node = item as? PluginDecompilerNode else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("row")
        let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            ?? {
                let created = NSTableCellView()
                created.identifier = identifier
                let field = NSTextField(labelWithString: "")
                field.lineBreakMode = .byTruncatingMiddle
                field.translatesAutoresizingMaskIntoConstraints = false
                created.addSubview(field)
                created.textField = field
                NSLayoutConstraint.activate([
                    field.leadingAnchor.constraint(equalTo: created.leadingAnchor),
                    field.trailingAnchor.constraint(equalTo: created.trailingAnchor),
                    field.centerYAnchor.constraint(equalTo: created.centerYAnchor),
                ])
                return created
            }()
        cell.textField?.stringValue = node.name
        // Packages dimmer than classes, so the tree reads as a hierarchy at a glance.
        cell.textField?.textColor = node.isLeaf ? .labelColor : .secondaryLabelColor
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let node = outline.item(atRow: outline.selectedRow) as? PluginDecompilerNode,
              let rel = node.relativePath, rel != currentFile else { return }
        show(file: rel)
    }
}
