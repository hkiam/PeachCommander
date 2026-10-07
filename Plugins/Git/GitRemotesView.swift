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
    private var worktrees: [PluginGit.Worktree] = []
    private let remoteTable = GitTable()
    private let submoduleTable = GitTable()
    private let worktreeTable = GitTable()
    /// The name and e-mail this repository commits with (phase 8); empty = git's global ones, shown as
    /// the placeholder.
    private let localName = NSTextField()
    private let localEmail = NSTextField()
    private var loadedName = "", loadedEmail = ""
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
            (worktreeTable, [("wtpath", L("Path"), 380), ("branch", L("Branch"), 200), ("wtstate", L("State"), 140)]),
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
            (L("Update submodules"), #selector(updateSubmodules)),
            (L("Add submodule…"), #selector(addSubmodule)), (L("Remove submodule…"), #selector(removeSubmodule)),
            (nil, nil),
            (L("Show in the left panel"), #selector(showLeft)), (L("Show in the right panel"), #selector(showRight)),
        ], target: self)
        submoduleTable.doubleAction = #selector(showLeft)
        submoduleTable.target = self
        worktreeTable.menu = gitMenu([
            (L("Add worktree…"), #selector(addWorktree)), (L("Remove worktree…"), #selector(removeWorktree)),
            (nil, nil),
            (L("Show in the left panel"), #selector(showWorktreeLeft)), (L("Show in the right panel"), #selector(showWorktreeRight)),
        ], target: self)
        worktreeTable.doubleAction = #selector(showWorktreeLeft)
        worktreeTable.target = self

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
        let submodulesPane = pane(L("Submodules"), submoduleTable, [(L("Update submodules"), #selector(updateSubmodules)),
                                                                    (L("Add submodule…"), #selector(addSubmodule)),
                                                                    (L("Remove submodule…"), #selector(removeSubmodule))])
        let worktreesPane = pane(L("Worktrees"), worktreeTable, [(L("Add worktree…"), #selector(addWorktree)),
                                                                 (L("Remove worktree…"), #selector(removeWorktree))])
        for field in [localName, localEmail] {
            field.target = self
            field.action = #selector(identityChanged)
            field.delegate = self
        }
        let identityTitle = NSTextField(labelWithString: L("Identity for this repository"))
        identityTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        let identityRow = NSStackView(views: [NSTextField(labelWithString: L("Name:")), localName,
                                              NSTextField(labelWithString: L("E-mail:")), localEmail])
        identityRow.orientation = .horizontal
        identityRow.spacing = 6
        localName.widthAnchor.constraint(equalTo: localEmail.widthAnchor).isActive = true
        let identityPane = NSStackView(views: [identityTitle, identityRow])
        identityPane.orientation = .vertical
        identityPane.alignment = .leading
        identityPane.spacing = 4
        identityPane.setHuggingPriority(.defaultHigh, for: .vertical)
        identityRow.widthAnchor.constraint(equalTo: identityPane.widthAnchor).isActive = true
        let stack = NSStackView(views: [identityPane, remotesPane, submodulesPane, worktreesPane, busy])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.distribution = .fill
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        for child in [identityPane, remotesPane, submodulesPane, worktreesPane] as [NSView] {
            child.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -16).isActive = true
        }
        for other in [submodulesPane, worktreesPane] {
            let share = remotesPane.heightAnchor.constraint(equalTo: other.heightAnchor)
            share.priority = .init(500)
            share.isActive = true
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
        for table in [remoteTable, submoduleTable, worktreeTable] {
            table.backgroundColor = theme.background
            table.enclosingScrollView?.drawsBackground = true
            table.enclosingScrollView?.backgroundColor = theme.background
            table.reloadData()
        }
    }

    @objc private func clipFrameChanged() {
        gitFitColumns(remoteTable, preferred: preferredWidth)
        gitFitColumns(submoduleTable, preferred: preferredWidth)
        gitFitColumns(worktreeTable, preferred: preferredWidth)
    }

    private func reload() {
        busy.startAnimation(nil)
        let root = self.root
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let remotes = PluginGit.parseRemotes(PluginGitRepo.run(["-C", root] + PluginGit.remotesArguments).out)
            let submodules = PluginGit.parseSubmodules(PluginGitRepo.run(["-C", root] + PluginGit.submodulesArguments).out)
            let worktrees = PluginGit.parseWorktrees(PluginGitRepo.run(["-C", root] + PluginGit.worktreesArguments).out)
            func config(_ scope: String, _ key: String) -> String {
                PluginGitRepo.run(["-C", root, "config", scope, key]).out.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let identity = (config("--local", "user.name"), config("--local", "user.email"),
                            config("--global", "user.name"), config("--global", "user.email"))
            DispatchQueue.main.async {
                self?.busy.stopAnimation(nil)
                guard let self else { return }
                self.remotes = remotes
                self.submodules = submodules
                self.worktrees = worktrees
                self.remoteTable.reloadData()
                self.submoduleTable.reloadData()
                self.worktreeTable.reloadData()
                self.loadedName = identity.0; self.loadedEmail = identity.1
                self.localName.stringValue = identity.0
                self.localEmail.stringValue = identity.1
                self.localName.placeholderString = identity.2.isEmpty ? L("Name for commits") : identity.2
                self.localEmail.placeholderString = identity.3.isEmpty ? L("E-mail for commits") : identity.3
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

    // MARK: - Identity for this repository (phase 8)

    /// Written only when changed; an emptied field goes back to the global value.
    @objc private func identityChanged() {
        var calls: [[String]] = []
        let name = localName.stringValue.trimmingCharacters(in: .whitespaces)
        let email = localEmail.stringValue.trimmingCharacters(in: .whitespaces)
        if name != loadedName { calls.append(["-C", root] + PluginGit.localIdentityArguments(key: "user.name", value: name)) }
        if email != loadedEmail { calls.append(["-C", root] + PluginGit.localIdentityArguments(key: "user.email", value: email)) }
        guard !calls.isEmpty else { return }
        loadedName = name; loadedEmail = email
        DispatchQueue.global(qos: .utility).async { for call in calls { _ = PluginGitRepo.run(call) } }
    }

    // MARK: - Worktrees (phase 8)

    private var selectedWorktree: PluginGit.Worktree? {
        worktrees.indices.contains(worktreeTable.selectedRow) ? worktrees[worktreeTable.selectedRow] : nil
    }

    /// A second checkout of this repository on another branch, beside it: `<repository>-<branch>`.
    @objc private func addWorktree() {
        guard let branch = gitPrompt(L("Add worktree…"), L("Branch (an existing one, or a new name):")) else { return }
        let parent = (root as NSString).deletingLastPathComponent
        let folder = (root as NSString).lastPathComponent + "-" + branch.replacingOccurrences(of: "/", with: "-")
        let path = (parent as NSString).appendingPathComponent(folder)
        let root = self.root, box = ServicesBox(services)
        busy.startAnimation(nil)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let exists = PluginGitRepo.run(["-C", root, "rev-parse", "--verify", "--quiet", "refs/heads/" + branch]).ok
            let result = PluginGitRepo.run(["-C", root] + PluginGit.addWorktreeArguments(path: path, branch: branch, create: !exists),
                                           combined: true)
            DispatchQueue.main.async {
                self?.busy.stopAnimation(nil)
                if !result.ok { GitCommitActions.report(box.services, L("Worktrees"), result.out) }
                self?.reload()
            }
        }
    }

    @objc private func removeWorktree() {
        guard let worktree = selectedWorktree, !worktree.isMain else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(format: L("Remove the worktree %@?"), (worktree.path as NSString).lastPathComponent)
        alert.informativeText = L("Its folder is deleted. git refuses while it has uncommitted changes; its branch stays.")
        alert.addButton(withTitle: L("Remove"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        run(PluginGit.removeWorktreeArguments(worktree.path), L("Worktrees"))
    }

    @objc private func showWorktreeLeft() { showWorktree(side: 0) }
    @objc private func showWorktreeRight() { showWorktree(side: 1) }

    private func showWorktree(side: Int) {
        guard let worktree = selectedWorktree else { return }
        worktree.path.withCString { services.openPathInPanel?(services.host, Int32(side), $0) }
    }

    // MARK: - Submodules

    @objc private func addSubmodule() {
        guard let url = gitPrompt(L("Add submodule…"), L("URL:")),
              let name = PluginGit.cloneDirectoryName(url),
              let path = gitPrompt(L("Add submodule…"), String(format: L("Path in this repository (e.g. libs/%@):"), name))
        else { return }
        run(PluginGit.addSubmoduleArguments(url: url, path: path), L("Submodules"))
    }

    @objc private func removeSubmodule() {
        guard let submodule = selectedSubmodule else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(format: L("Remove the submodule %@?"), submodule.path)
        alert.informativeText = L("Its checkout, its entry in .gitmodules and the index are removed; commit to record it.")
        alert.addButton(withTitle: L("Remove"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let calls = PluginGit.removeSubmoduleArguments(submodule.path)
        let root = self.root, box = ServicesBox(services)
        busy.startAnimation(nil)
        let checkout = (root as NSString).appendingPathComponent(submodule.path)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Its repository under .git/modules is found first — `deinit` empties the checkout that
            // knows where it is — and deleted last, or adding a submodule at this path again would
            // find the old one and refuse.
            func line(_ arguments: [String]) -> String? {
                let result = PluginGitRepo.run(arguments)
                let text = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
                return result.ok && !text.isEmpty ? text : nil
            }
            let gitDir = line(["-C", checkout] + PluginGit.submoduleGitDirArguments)
            let common = line(["-C", root] + PluginGit.commonGitDirArguments)
            var failure: String?
            for call in calls {
                let result = PluginGitRepo.run(["-C", root] + call, combined: true)
                if !result.ok { failure = result.out; break }
            }
            if failure == nil, let gitDir, let common,
               PluginGit.isRemovableSubmoduleGitDir(gitDir, commonGitDir: common) {
                try? FileManager.default.removeItem(atPath: gitDir)
            }
            DispatchQueue.main.async {
                self?.busy.stopAnimation(nil)
                if let failure { GitCommitActions.report(box.services, L("Submodules"), failure) }
                self?.reload()
            }
        }
    }

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
        case #selector(removeSubmodule): return selectedSubmodule != nil
        case #selector(removeWorktree): return selectedWorktree.map { !$0.isMain } ?? false
        case #selector(showWorktreeLeft), #selector(showWorktreeRight): return selectedWorktree != nil
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
        tableView === remoteTable ? remotes.count : tableView === worktreeTable ? worktrees.count : submodules.count
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
        } else if tableView === worktreeTable, worktrees.indices.contains(row) {
            let worktree = worktrees[row]
            switch id {
            case "wtpath": field.stringValue = worktree.path
            case "branch": field.stringValue = worktree.branch ?? L("(detached)")
            default:
                field.stringValue = worktree.isMain ? L("Main") : (worktree.isLocked ? L("Locked") : "")
                field.textColor = theme.secondaryText
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

extension GitRemotesView: NSTextFieldDelegate {
    /// Saved when a field loses focus as well as on Return.
    func controlTextDidEndEditing(_ notification: Notification) { identityChanged() }
}
