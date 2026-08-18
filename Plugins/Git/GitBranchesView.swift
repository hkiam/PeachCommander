// SPDX-License-Identifier: Apache-2.0
// GitBranchesView.swift — branches, stashes, and the three commands that talk to a remote.
//
// Phase 3 of docs/analysis/git-plugin-plan.md (F-418). Two lists in one window: branches (local and
// remote, current one marked, ahead/behind against their upstream) and stashes. Actions are the ones a
// reader reaches for daily — switch, create, merge, delete, and stash push/pop/drop — plus Fetch, Pull and
// Push, which are the only operations here that talk to a network.
//
// Three decisions worth stating, because they are what makes this safe rather than merely present:
//
//   * **Switching is refused with a reason**, not attempted and half-finished: a conflict or a staged
//     change in the way produces a sentence naming the count (PluginGit.canSwitch, unit-tested), because
//     git's own message is written for a terminal and a partial checkout is worse than a refusal.
//   * **Network operations can be cancelled.** The Process is kept, the button becomes Cancel, and
//     terminate() ends it. Without that, a `push` to an unreachable host is an application that appears
//     to hang — the F-415 defect one level up.
//   * **No credentials are ever handled here.** `GIT_TERMINAL_PROMPT=0` (in GitRepo) makes git fail
//     loudly instead of waiting for a password on a terminal that does not exist, and the failure text
//     says to use the SSH agent or a credential helper. A file manager that collects passphrases is a
//     file manager that stores them.

import AppKit

@MainActor
final class GitBranchesView: NSView {
    private let services: PcHostServices
    private let root: String

    private var branches: [PluginGit.Branch] = []
    private var stashes: [PluginGit.Stash] = []

    private let header = NSTextField(labelWithString: "")
    private let branchTable = NSTableView()
    private let stashTable = NSTableView()
    private let split = NSSplitView()
    private let busy = NSProgressIndicator()
    private let statusLabel = NSTextField(labelWithString: "")
    private let cancelButton = NSButton()
    private var running: Process?

    init(services: PcHostServices, root: String) {
        self.services = services
        self.root = root
        super.init(frame: NSRect(x: 0, y: 0, width: 720, height: 420))
        build()
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Building

    private func build() {
        header.font = .systemFont(ofSize: 12, weight: .semibold)
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        for (table, columns) in [
            (branchTable, [("current", "", 18), ("name", L("Branch"), 220),
                           ("track", L("Tracking"), 170), ("subject", L("Subject"), 220)]),
            (stashTable, [("ref", "", 90), ("branch", L("Branch"), 120),
                          ("subject", L("Subject"), 300)]),
        ] as [(NSTableView, [(String, String, CGFloat)])] {
            table.rowHeight = 17
            table.usesAlternatingRowBackgroundColors = true
            table.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            for (id, title, width) in columns {
                let column = NSTableColumn(identifier: .init(id))
                column.title = title
                column.width = width
                table.addTableColumn(column)
            }
            table.dataSource = self
            table.delegate = self
        }
        branchTable.target = self
        branchTable.doubleAction = #selector(switchToSelected)

        let branchButtons = buttonRow([
            (L("Switch"), #selector(switchToSelected)),
            (L("New…"), #selector(createBranch)),
            (L("Merge…"), #selector(mergeSelected)),
            (L("Delete…"), #selector(deleteSelected)),
        ])
        let stashButtons = buttonRow([
            (L("Stash changes…"), #selector(stashPush)),
            (L("Pop"), #selector(stashPop)),
            (L("Drop…"), #selector(stashDrop)),
        ])
        let remoteButtons = buttonRow([
            (L("Fetch"), #selector(fetch)),
            (L("Pull"), #selector(pull)),
            (L("Push"), #selector(push)),
        ])
        cancelButton.title = L("Cancel")
        cancelButton.bezelStyle = .rounded
        cancelButton.controlSize = .small
        cancelButton.font = .systemFont(ofSize: 11)
        cancelButton.target = self
        cancelButton.action = #selector(cancelRunning)
        cancelButton.isHidden = true
        busy.style = .spinning
        busy.controlSize = .small
        busy.isDisplayedWhenStopped = false

        let branchPane = NSStackView(views: [labelled(L("Branches")), scrolled(branchTable), branchButtons])
        branchPane.orientation = .vertical
        branchPane.spacing = 4
        let stashPane = NSStackView(views: [labelled(L("Stashes")), scrolled(stashTable), stashButtons])
        stashPane.orientation = .vertical
        stashPane.spacing = 4

        split.isVertical = true
        split.dividerStyle = .thin
        split.addArrangedSubview(branchPane)
        split.addArrangedSubview(stashPane)
        split.translatesAutoresizingMaskIntoConstraints = false

        let footer = NSStackView(views: [remoteButtons, busy, cancelButton, statusLabel])
        footer.orientation = .horizontal
        footer.spacing = 8
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [header, split, footer])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        // Widths by constraint rather than `setPosition`: an NSScrollView has no intrinsic width, so a
        // split view under constraint layout will happily give one pane everything — measured in the log
        // window, where the commit list came out zero points wide (F-417).
        let left = branchPane.widthAnchor.constraint(greaterThanOrEqualToConstant: 300)
        let right = stashPane.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        let ratio = branchPane.widthAnchor.constraint(equalTo: split.widthAnchor, multiplier: 0.58)
        left.priority = .init(999); right.priority = .init(999); ratio.priority = .init(500)
        NSLayoutConstraint.activate([left, right, ratio])
    }

    private func labelled(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 11, weight: .semibold)
        field.textColor = .secondaryLabelColor
        return field
    }

    private func scrolled(_ table: NSTableView) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        let height = scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        height.priority = .init(999)
        height.isActive = true
        return scroll
    }

    private func buttonRow(_ items: [(String, Selector)]) -> NSStackView {
        let buttons = items.map { title, action -> NSButton in
            let button = NSButton()
            button.title = title
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.font = .systemFont(ofSize: 11)
            button.target = self
            button.action = action
            return button
        }
        let row = NSStackView(views: buttons)
        row.orientation = .horizontal
        row.spacing = 4
        return row
    }

    // MARK: - Loading

    private func reload() {
        busy.startAnimation(nil)
        let root = self.root
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let branchResult = PluginGitRepo.run(["-C", root] + PluginGit.branchArguments)
            let stashResult = PluginGitRepo.run(["-C", root] + PluginGit.stashListArguments)
            let branches = branchResult.ok ? PluginGit.parseBranches(branchResult.out) : []
            let stashes = stashResult.ok ? PluginGit.parseStashes(stashResult.out) : []
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                self.branches = branches
                self.stashes = stashes
                self.branchTable.reloadData()
                self.stashTable.reloadData()
                let current = branches.first(where: \.isCurrent)?.name ?? L("(detached)")
                self.header.stringValue = String(
                    format: L("%@ — on %@, %lld branch(es), %lld stash(es)"),
                    (self.root as NSString).lastPathComponent, current,
                    branches.filter { !$0.isRemote }.count, stashes.count)
            }
        }
    }

    private var selectedBranch: PluginGit.Branch? {
        branches.indices.contains(branchTable.selectedRow) ? branches[branchTable.selectedRow] : nil
    }

    private var selectedStash: PluginGit.Stash? {
        stashes.indices.contains(stashTable.selectedRow) ? stashes[stashTable.selectedRow] : nil
    }

    // MARK: - Branch actions

    @objc private func switchToSelected() {
        guard let branch = selectedBranch else { return }
        guard let status = PluginGitRepo.status(root: root) else { return }
        switch PluginGit.canSwitch(status) {
        case .conflicts(let count):
            report(String(format: L("%lld conflicted file(s) have to be resolved first."), count))
            return
        case .staged(let count):
            report(String(format: L("%lld staged change(s) would be carried over. Commit or unstage first."),
                          count))
            return
        case .none:
            break
        }
        // A remote branch is checked out as a local branch that tracks it, which is what the reader means
        // by "switch to origin/x" — `git switch` does that itself when the name is unambiguous.
        let name = branch.isRemote
            ? String(branch.name.drop(while: { $0 != "/" }).dropFirst()) : branch.name
        run(["-C", root, "switch", name])
    }

    @objc private func createBranch() {
        guard let name = prompt(L("New branch"), L("Name:")) else { return }
        run(["-C", root, "switch", "-c", name])
    }

    @objc private func mergeSelected() {
        guard let branch = selectedBranch else { return }
        let alert = NSAlert()
        alert.messageText = String(format: L("Merge %@ into the current branch?"), branch.name)
        alert.informativeText = L("A merge that conflicts stops and leaves the conflicts to resolve.")
        alert.addButton(withTitle: L("Merge"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        run(["-C", root, "merge", "--no-edit", branch.name])
    }

    @objc private func deleteSelected() {
        guard let branch = selectedBranch, !branch.isRemote else {
            report(L("Select a local branch to delete."))
            return
        }
        guard !branch.isCurrent else {
            report(L("The current branch cannot be deleted."))
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(format: L("Delete branch %@?"), branch.name)
        // `-d` refuses to delete an unmerged branch, and that refusal is a feature: the reader is told
        // rather than losing commits. Only the explicit second step forces it.
        alert.informativeText = L("Unmerged commits are refused unless you choose Force.")
        alert.addButton(withTitle: L("Delete"))
        alert.addButton(withTitle: L("Cancel"))
        alert.addButton(withTitle: L("Force delete"))
        let choice = alert.runModal()
        guard choice != .alertSecondButtonReturn else { return }
        let flag = choice == .alertThirdButtonReturn ? "-D" : "-d"
        run(["-C", root, "branch", flag, branch.name])
    }

    // MARK: - Stash actions

    @objc private func stashPush() {
        let message = prompt(L("Stash changes"), L("Message (optional):")) ?? ""
        var arguments = ["-C", root, "stash", "push", "--include-untracked"]
        if !message.isEmpty { arguments += ["-m", message] }
        run(arguments)
    }

    @objc private func stashPop() {
        guard let stash = selectedStash else { return }
        run(["-C", root, "stash", "pop", stash.ref])
    }

    @objc private func stashDrop() {
        guard let stash = selectedStash else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(format: L("Drop %@?"), stash.ref)
        alert.informativeText = L("This cannot be undone.")
        alert.addButton(withTitle: L("Drop"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        run(["-C", root, "stash", "drop", stash.ref])
    }

    // MARK: - Remote actions

    @objc private func fetch() { runCancellable(["-C", root, "fetch", "--prune"], L("Fetching…")) }
    @objc private func pull() { runCancellable(["-C", root, "pull", "--ff-only"], L("Pulling…")) }
    @objc private func push() { runCancellable(["-C", root, "push"], L("Pushing…")) }

    @objc private func cancelRunning() {
        running?.terminate()
        statusLabel.stringValue = L("Cancelled.")
    }

    // MARK: - Running git

    /// A local operation: off the main thread, then reload and report.
    private func run(_ arguments: [String]) {
        busy.startAnimation(nil)
        statusLabel.stringValue = ""
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PluginGitRepo.run(arguments, combined: true)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                PluginGitRepo.invalidate()
                self.services.reloadActivePanel?(self.services.host)
                self.reload()
                let text = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
                self.statusLabel.stringValue = text.isEmpty
                    ? (result.ok ? L("Done.") : L("Failed.")) : text
                if !result.ok, !text.isEmpty { self.report(text) }
            }
        }
    }

    /// A network operation: the same, but the Process is kept so it can be cancelled.
    ///
    /// This is the difference between "the application is thinking" and "the application has hung": a push
    /// to an unreachable host takes as long as the TCP stack decides to, and there has to be a way out
    /// that is not force-quitting the file manager.
    private func runCancellable(_ arguments: [String], _ what: String) {
        guard running == nil else {
            report(L("Another Git operation is still running."))
            return
        }
        guard let executable = PluginGitRepo.executable() else {
            report(L("Git was not found on this Mac."))
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"          // fail loudly rather than wait for a password
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        running = process
        cancelButton.isHidden = false
        busy.startAnimation(nil)
        statusLabel.stringValue = what
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var output = ""
            var ok = false
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                ok = process.terminationStatus == 0
            } catch {
                output = L("Git could not be started.")
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.running = nil
                self.cancelButton.isHidden = true
                self.busy.stopAnimation(nil)
                PluginGitRepo.invalidate()
                self.services.reloadActivePanel?(self.services.host)
                self.reload()
                self.statusLabel.stringValue = output.isEmpty
                    ? (ok ? L("Done.") : L("Failed.")) : output
                // A failure that mentions authentication is the one worth a sentence of its own: the
                // plugin will not ask for a passphrase, and the reader needs to know where to put it.
                if !ok, output.lowercased().contains("authenticat") || output.lowercased().contains("permission denied") {
                    self.report(output + "\n\n" + L("Git asks the SSH agent or your credential helper for "
                                                    + "credentials; this plugin never stores them."))
                }
            }
        }
    }

    /// A one-line text prompt. Returns nil when cancelled or empty.
    private func prompt(_ title: String, _ label: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = label
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
        alert.accessoryView = field
        alert.addButton(withTitle: L("OK"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func report(_ message: String) {
        services.presentInfo?(services.host, L("Git"), message)
    }
}

extension GitBranchesView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === branchTable ? branches.count : stashes.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("GitBranchCell")
        let field = (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField)
            ?? {
                let f = NSTextField(labelWithString: "")
                f.identifier = identifier
                f.usesSingleLineMode = true
                f.lineBreakMode = .byTruncatingTail
                f.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
                return f
            }()
        if tableView === branchTable {
            guard branches.indices.contains(row) else { return nil }
            let branch = branches[row]
            switch tableColumn.identifier.rawValue {
            case "current":
                field.stringValue = branch.isCurrent ? "●" : ""
            case "name":
                field.stringValue = branch.name
                field.textColor = branch.isRemote ? .secondaryLabelColor : .labelColor
            case "track":
                if let upstream = branch.upstream {
                    field.stringValue = branch.ahead == 0 && branch.behind == 0
                        ? upstream : "\(upstream)  ↑\(branch.ahead) ↓\(branch.behind)"
                } else {
                    field.stringValue = ""
                }
            default:
                field.stringValue = branch.subject
            }
        } else {
            guard stashes.indices.contains(row) else { return nil }
            let stash = stashes[row]
            switch tableColumn.identifier.rawValue {
            case "ref":    field.stringValue = stash.ref
            case "branch": field.stringValue = stash.branch
            default:       field.stringValue = stash.subject
            }
        }
        return field
    }
}
