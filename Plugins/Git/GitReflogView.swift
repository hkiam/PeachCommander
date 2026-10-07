// SPDX-License-Identifier: Apache-2.0
// GitReflogView.swift — every move of HEAD, and the way back to a commit nothing points at any more.
//
// Phase 7. A commit lost to a reset, a rebase or a deleted branch is still in the reflog for weeks, and
// that is the one place it can be found: the history only walks refs. The list shows git's own words for
// each move ("reset: moving to HEAD~1", "commit: …"); the actions are the two that recover a commit —
// a branch on it, or checking it out.

import AppKit

@MainActor
final class GitReflogView: NSView {
    private let services: PcHostServices
    private let root: String
    private var theme: PluginTheme
    private var entries: [PluginGit.ReflogEntry] = []
    private let header = NSTextField(labelWithString: "")
    private let table = GitTable()
    private let busy = GitBusyIndicator()
    private var preferredWidth: [NSUserInterfaceItemIdentifier: CGFloat] = [:]

    init(services: PcHostServices, root: String) {
        self.services = services
        self.root = root
        self.theme = PluginTheme(services)
        super.init(frame: NSRect(x: 0, y: 0, width: 760, height: 420))
        build()
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        header.font = .systemFont(ofSize: 12, weight: .semibold)
        header.stringValue = L("Every move of HEAD, newest first. A commit nothing else points at can be brought back from here.")
        header.lineBreakMode = .byWordWrapping
        header.maximumNumberOfLines = 2
        busy.style = .spinning
        busy.controlSize = .small
        busy.isDisplayedWhenStopped = false

        table.rowHeight = 18
        table.usesAlternatingRowBackgroundColors = true
        table.columnAutoresizingStyle = .noColumnAutoresizing
        for (id, title, width) in [("selector", "", 80), ("action", L("Action"), 260), ("subject", L("Subject"), 300),
                                   ("date", L("Date"), 130)] as [(String, String, CGFloat)] {
            let column = NSTableColumn(identifier: .init(id))
            column.title = title
            column.width = width
            column.resizingMask = [.autoresizingMask, .userResizingMask]
            column.minWidth = min(width, 60)
            preferredWidth[column.identifier] = width
            table.addTableColumn(column)
        }
        table.dataSource = self
        table.delegate = self
        table.onEnter = { [weak self] in self?.branchHere() }
        table.menu = gitMenu([
            (L("New branch here…"), #selector(branchHere)),
            (L("Check out this commit…"), #selector(checkout)),
            (nil, nil),
            (L("Copy commit hash"), #selector(copyHash)),
            (L("Reload"), #selector(reloadFromMenu)),
        ], target: self)
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.contentView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(clipFrameChanged),
                                               name: NSView.frameDidChangeNotification, object: scroll.contentView)

        let top = NSStackView(views: [header, busy])
        top.orientation = .horizontal
        top.setHuggingPriority(.defaultHigh, for: .vertical)
        header.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let stack = NSStackView(views: [top, scroll])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.distribution = .fill
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        for child in [top, scroll] as [NSView] {
            child.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -16).isActive = true
        }
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        applyTheme()
    }

    func applyTheme() {
        theme = PluginTheme(services)
        wantsLayer = true
        layer?.backgroundColor = theme.windowBackground.cgColor
        header.textColor = theme.text
        table.backgroundColor = theme.background
        table.enclosingScrollView?.drawsBackground = true
        table.enclosingScrollView?.backgroundColor = theme.background
        table.reloadData()
    }

    @objc private func clipFrameChanged() { gitFitColumns(table, preferred: preferredWidth) }

    private func reload() {
        busy.startAnimation(nil)
        let root = self.root
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let entries = PluginGit.parseReflog(PluginGitRepo.run(["-C", root] + PluginGit.reflogArguments(limit: 500)).out)
            DispatchQueue.main.async {
                self?.busy.stopAnimation(nil)
                guard let self else { return }
                self.entries = entries
                self.table.reloadData()
            }
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "r" { reload(); return true }
        return super.performKeyEquivalent(with: event)
    }

    private var selected: PluginGit.ReflogEntry? {
        entries.indices.contains(table.selectedRow) ? entries[table.selectedRow] : nil
    }

    @objc private func reloadFromMenu() { reload() }
    @objc private func copyHash() { selected.map { gitCopyToClipboard($0.hash) } }

    @objc private func branchHere() {
        guard let entry = selected else { return }
        GitCommitActions.branchHere(PluginGit.commit(of: entry), root: root, services: services, busy: busy) { [weak self] in
            self?.reload()
        }
    }

    @objc private func checkout() {
        guard let entry = selected else { return }
        GitCommitActions.checkout(PluginGit.commit(of: entry), root: root, services: services, busy: busy) { [weak self] in
            self?.reload()
        }
    }
}

extension GitReflogView: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.action == #selector(reloadFromMenu) || selected != nil
    }
}

extension GitReflogView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { entries.count }

    func tableViewColumnDidResize(_ notification: Notification) {
        gitAdoptDraggedWidths(table, preferred: &preferredWidth)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let id = tableColumn?.identifier.rawValue, entries.indices.contains(row) else { return nil }
        let field = (tableView.makeView(withIdentifier: .init("GitReflogText"), owner: self) as? NSTextField)
            ?? {
                let f = NSTextField(labelWithString: "")
                f.identifier = .init("GitReflogText")
                f.usesSingleLineMode = true
                f.lineBreakMode = .byTruncatingTail
                return f
            }()
        let entry = entries[row]
        field.font = .systemFont(ofSize: 11)
        field.textColor = theme.text
        switch id {
        case "selector":
            field.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            field.stringValue = entry.selector
            field.textColor = theme.secondaryText
        case "action": field.stringValue = entry.action
        case "subject": field.stringValue = entry.subject
        default:
            field.stringValue = gitDisplayDate(entry.date)
            field.textColor = theme.secondaryText
        }
        field.toolTip = "\(entry.hash)\n\(entry.action)"
        return field
    }
}
