// SPDX-License-Identifier: Apache-2.0
// GitRemotesView.swift — the repository's remotes and submodules, and what can be done to them.
//
// Phase 7. Remotes were configured nowhere in the app: adding a fork's remote, renaming `origin` to
// `upstream` or moving a remote to a new host meant a terminal. Submodules were reported — status and
// branch per file, since phase 4 — and nothing more. This window lists both. Updating submodules talks to
// the network, so it runs as the plugin's asynchronous command, with the host's progress and Cancel.

import AppKit

@MainActor
final class GitRemotesView: NSView {
    private let services: PcHostServices
    private let root: String
    private var theme: PluginTheme
    private var remotes: [PluginGit.Remote] = []
    private var submodules: [PluginGit.Submodule] = []
    private let remoteTable = GitTable()
    private let submoduleTable = GitTable()
    private let busy = GitBusyIndicator()
    private var preferredWidth: [NSUserInterfaceItemIdentifier: CGFloat] = [:]

    init(services: PcHostServices, root: String) {
        self.services = services
        self.root = root
        self.theme = PluginTheme(services)
        super.init(frame: NSRect(x: 0, y: 0, width: 760, height: 460))
        build()
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        busy.style = .spinning
        busy.controlSize = .small
        busy.isDisplayedWhenStopped = false
        for (table, columns) in [
            (remoteTable, [("name", L("Name"), 120), ("fetch", L("Fetch URL"), 300), ("push", L("Push URL"), 300)]),
            (submoduleTable, [("path", L("Path"), 260), ("state", L("State"), 160), ("commit", L("Commit"), 120),
                              ("describe", L("Description"), 180)]),
        ] as [(GitTable, [(String, String, CGFloat)])] {
            table.rowHeight = 18
            table.usesAlternatingRowBackgroundColors = true
            table.columnAutoresizingStyle = .noColumnAutoresizing
            for (id, title, width) in columns {
                let column = NSTableColumn(identifier: .init(id))
                column.title = title
                column.width = width
                column.resizingMask = [.autoresizingMask, .userResizingMask]
                column.minWidth = min(width, 70)
                preferredWidth[column.identifier] = width
                table.addTableColumn(column)
            }
            table.dataSource = self
            table.delegate = self
        }
        remoteTable.menu = gitMenu([
            (L("Add remote…"), #selector(addRemote)), (L("Rename…"), #selector(renameRemote)),
            (L("Change URL…"), #selector(changeURL)), (nil, nil), (L("Remove…"), #selector(removeRemote)),
            (nil, nil), (L("Copy URL"), #selector(copyURL)),
        ], target: self)
        submoduleTable.menu = gitMenu([
            (L("Update submodules"), #selector(updateSubmodules)), (nil, nil),
            (L("Show in the left panel"), #selector(showLeft)), (L("Show in the right panel"), #selector(showRight)),
        ], target: self)
        submoduleTable.doubleAction = #selector(showLeft)
        submoduleTable.target = self

        func pane(_ title: String, _ table: GitTable, _ buttons: [(String, Selector)]) -> NSStackView {
            let label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 12, weight: .semibold)
            let scroll = NSScrollView()
            scroll.documentView = table
            scroll.hasVerticalScroller = true
            scroll.autohidesScrollers = true
            scroll.contentView.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(clipFrameChanged),
                                                   name: NSView.frameDidChangeNotification, object: scroll.contentView)
            let row = NSStackView(views: buttons.map { title, action in
                let button = NSButton(title: title, target: self, action: action)
                button.bezelStyle = .rounded
                button.controlSize = .small
                button.font = .systemFont(ofSize: 11)
                return button
            })
            row.orientation = .horizontal
            row.spacing = 6
            row.setHuggingPriority(.defaultHigh, for: .vertical)
            let stack = NSStackView(views: [label, scroll, row])
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.distribution = .fill
            stack.spacing = 4
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            scroll.setContentHuggingPriority(.init(200), for: .vertical)
            return stack
        }
        let remotesPane = pane(L("Remotes"), remoteTable, [(L("Add remote…"), #selector(addRemote)),
                                                           (L("Rename…"), #selector(renameRemote)),
                                                           (L("Change URL…"), #selector(changeURL)),
                                                           (L("Remove…"), #selector(removeRemote))])
        let submodulesPane = pane(L("Submodules"), submoduleTable, [(L("Update submodules"), #selector(updateSubmodules))])
        let stack = NSStackView(views: [remotesPane, submodulesPane, busy])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.distribution = .fill
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        for child in [remotesPane, submodulesPane] as [NSView] {
            child.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -16).isActive = true
        }
        let share = remotesPane.heightAnchor.constraint(equalTo: submodulesPane.heightAnchor)
        share.priority = .init(500)
        share.isActive = true
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
        for table in [remoteTable, submoduleTable] {
            table.backgroundColor = theme.background
            table.enclosingScrollView?.drawsBackground = true
            table.enclosingScrollView?.backgroundColor = theme.background
            table.reloadData()
        }
    }

    @objc private func clipFrameChanged() {
        gitFitColumns(remoteTable, preferred: preferredWidth)
        gitFitColumns(submoduleTable, preferred: preferredWidth)
    }

    private func reload() {
        busy.startAnimation(nil)
        let root = self.root
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let remotes = PluginGit.parseRemotes(PluginGitRepo.run(["-C", root] + PluginGit.remotesArguments).out)
            let submodules = PluginGit.parseSubmodules(PluginGitRepo.run(["-C", root] + PluginGit.submodulesArguments).out)
            DispatchQueue.main.async {
                self?.busy.stopAnimation(nil)
                guard let self else { return }
                self.remotes = remotes
                self.submodules = submodules
                self.remoteTable.reloadData()
                self.submoduleTable.reloadData()
            }
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "r" { reload(); return true }
        return super.performKeyEquivalent(with: event)
    }

    // MARK: - Remotes

    private var selectedRemote: PluginGit.Remote? {
        remotes.indices.contains(remoteTable.selectedRow) ? remotes[remoteTable.selectedRow] : nil
    }

    private func run(_ arguments: [String], _ title: String) {
        GitCommitActions.run(arguments, title: title, root: root, services: services, busy: busy) { [weak self] in
            self?.reload()
        }
    }

    @objc private func addRemote() {
        guard let name = gitPrompt(L("Add remote…"), L("Name:")),
              let url = gitPrompt(String(format: L("URL of %@"), name), L("URL:")) else { return }
        run(PluginGit.addRemoteArguments(name: name, url: url), L("Remotes"))
    }

    @objc private func renameRemote() {
        guard let remote = selectedRemote,
              let name = gitPrompt(String(format: L("Rename %@"), remote.name), L("New name:")) else { return }
        run(PluginGit.renameRemoteArguments(remote.name, to: name), L("Remotes"))
    }

    @objc private func changeURL() {
        guard let remote = selectedRemote,
              let url = gitPrompt(String(format: L("URL of %@"), remote.name), L("URL:")) else { return }
        run(PluginGit.setRemoteURLArguments(remote.name, url: url), L("Remotes"))
    }

    @objc private func removeRemote() {
        guard let remote = selectedRemote else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(format: L("Remove the remote %@?"), remote.name)
        alert.informativeText = L("Its remote branches disappear from this repository. Nothing on the server changes.")
        alert.addButton(withTitle: L("Remove"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        run(PluginGit.removeRemoteArguments(remote.name), L("Remotes"))
    }

    @objc private func copyURL() { selectedRemote.map { gitCopyToClipboard($0.fetchURL) } }

    // MARK: - Submodules

    private var selectedSubmodule: PluginGit.Submodule? {
        submodules.indices.contains(submoduleTable.selectedRow) ? submodules[submoduleTable.selectedRow] : nil
    }

    /// In *this window's* repository — not through the plugin command, which works out its repository
    /// from the active file panel's cursor, wherever that has moved since the window opened. It may fetch,
    /// so it runs off the main thread with the host's progress window and Cancel, and the list is read
    /// again when it is done.
    @objc private func updateSubmodules() {
        let root = self.root, box = ServicesBox(services)
        busy.startAnimation(nil)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let svc = box.services
            let title = L("Update submodules")
            let handle = DispatchQueue.main.sync { title.withCString { svc.beginProgress?(svc.host, $0) } }
            let result = PluginGitRepo.runCancellable(["-C", root] + PluginGit.updateSubmodulesArguments) { line in
                guard let handle else { return true }
                return DispatchQueue.main.sync { line.withCString { svc.updateProgress?(svc.host, handle, -1, $0) != 0 } }
            }
            DispatchQueue.main.async { [weak self] in
                if let handle { svc.endProgress?(svc.host, handle) }
                self?.busy.stopAnimation(nil)
                PluginGitRepo.invalidate()
                if !result.ok {
                    svc.presentInfo?(svc.host, title, result.cancelled ? L("Cancelled.") : result.out)
                }
                self?.reload()
            }
        }
    }

    @objc private func showLeft() { show(side: 0) }
    @objc private func showRight() { show(side: 1) }

    private func show(side: Int) {
        guard let submodule = selectedSubmodule else { return }
        let path = (root as NSString).appendingPathComponent(submodule.path)
        path.withCString { services.openPathInPanel?(services.host, Int32(side), $0) }
    }

    private static func text(for state: PluginGit.Submodule.State) -> String {
        switch state {
        case .current: return L("Up to date")
        case .uninitialized: return L("Not initialized")
        case .differs: return L("Other commit checked out")
        case .conflict: return L("Conflict")
        }
    }
}

extension GitRemotesView: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(renameRemote), #selector(changeURL), #selector(removeRemote), #selector(copyURL):
            return selectedRemote != nil
        case #selector(showLeft), #selector(showRight):
            return selectedSubmodule.map { $0.state != .uninitialized } ?? false
        case #selector(updateSubmodules): return !submodules.isEmpty
        default: return true
        }
    }
}

extension GitRemotesView: NSTableViewDataSource, NSTableViewDelegate {
    func tableViewColumnDidResize(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        gitAdoptDraggedWidths(table, preferred: &preferredWidth)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === remoteTable ? remotes.count : submodules.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let id = tableColumn?.identifier.rawValue else { return nil }
        let field = (tableView.makeView(withIdentifier: .init("GitRemotesText"), owner: self) as? NSTextField)
            ?? {
                let f = NSTextField(labelWithString: "")
                f.identifier = .init("GitRemotesText")
                f.usesSingleLineMode = true
                f.lineBreakMode = .byTruncatingMiddle
                return f
            }()
        field.font = .systemFont(ofSize: 11)
        field.textColor = theme.text
        if tableView === remoteTable, remotes.indices.contains(row) {
            let remote = remotes[row]
            switch id {
            case "name": field.stringValue = remote.name
            case "fetch": field.stringValue = remote.fetchURL
            default:
                // Shown dimmed when it is the same as the fetch URL, which is almost always.
                field.stringValue = remote.pushURL
                field.textColor = remote.pushURL == remote.fetchURL ? theme.secondaryText : theme.text
            }
        } else if submodules.indices.contains(row) {
            let submodule = submodules[row]
            switch id {
            case "path": field.stringValue = submodule.path
            case "state":
                field.stringValue = Self.text(for: submodule.state)
                field.textColor = submodule.state == .current ? theme.secondaryText : .systemOrange
            case "commit":
                field.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
                field.stringValue = String(submodule.commit.prefix(10))
            default: field.stringValue = submodule.describe ?? ""
            }
        }
        return field
    }
}
