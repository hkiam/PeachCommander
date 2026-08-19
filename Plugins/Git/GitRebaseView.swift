// SPDX-License-Identifier: Apache-2.0
// GitRebaseView.swift — cleaning up the commits you have not pushed yet.
//
// Phase 5d of docs/analysis/git-plugin-plan.md (F-423), and deliberately not a general rebase editor: the
// list is the commits *ahead of the upstream*, which is the set one is allowed to rewrite, and the actions
// are the five that "tidy this before pushing" needs — pick, reword, squash, fixup, drop — plus reordering.
// No `exec`, no `break`, no arbitrary revision range.
//
// The mechanism is the one that makes an interactive rebase possible from a GUI with no terminal: git runs
// `$GIT_SEQUENCE_EDITOR <todo-file>`, so `cp <ours>` hands it a todo list this window wrote. `GIT_EDITOR`
// covers the message editor the same way — `true` to accept what git pre-filled (which is what a squash
// wants), or `cp <message-file>` for a reword. That is also why only one reword per run is allowed: every
// invocation would be handed the same file.
//
// A rebase that stops in a conflict is the case this window has to handle rather than hide, so when the
// repository is mid-sequence it opens as Continue / Skip / Abort instead — the reader is not left with a
// half-finished branch and no way back.

import AppKit

@MainActor
final class GitRebaseView: NSView {
    private let services: PcHostServices
    private let root: String

    /// Oldest first, which is the order git applies them in and the order the todo file wants.
    private var commits: [PluginGit.Commit] = []
    private var actions: [PluginGit.RebaseAction] = []
    private var upstream: String?
    private var running = false

    private let header = NSTextField(labelWithString: "")
    private let table = GitTable()
    private let busy = NSProgressIndicator()
    private var actionButtons: [NSButton] = []
    private let upButton = NSButton()
    private let downButton = NSButton()
    private let startButton = NSButton()
    private let continueButton = NSButton()
    private let skipButton = NSButton()
    private let abortButton = NSButton()

    init(services: PcHostServices, root: String) {
        self.services = services
        self.root = root
        super.init(frame: NSRect(x: 0, y: 0, width: 720, height: 420))
        build()
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        header.font = .systemFont(ofSize: 12, weight: .semibold)
        header.lineBreakMode = .byTruncatingMiddle

        for (id, title, width) in [("action", L("Action"), 90), ("hash", L("Commit"), 90),
                                   ("subject", L("Subject"), 420)] as [(String, String, CGFloat)] {
            let column = NSTableColumn(identifier: .init(id))
            column.title = title
            column.width = width
            table.addTableColumn(column)
        }
        table.rowHeight = 17
        table.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        table.usesAlternatingRowBackgroundColors = true
        table.dataSource = self
        table.delegate = self
        table.menu = gitMenu([
            (L("Pick"), #selector(menuPick)),
            (L("Reword…"), #selector(menuReword)),
            (L("Squash"), #selector(menuSquash)),
            (L("Fixup"), #selector(menuFixup)),
            (L("Drop"), #selector(menuDrop)),
            (nil, nil),
            (L("Move up"), #selector(moveCommitUp)),
            (L("Move down"), #selector(moveCommitDown)),
            (nil, nil),
            (L("Copy commit hash"), #selector(copyHash)),
            (L("Reload"), #selector(reloadFromMenu)),
        ], target: self)

        // One button per action rather than a popup in every row: the same shape the conflict resolver uses,
        // and a row's action is a decision about the selection, not a field of it.
        for action in PluginGit.RebaseAction.allCases {
            let button = NSButton()
            button.title = Self.label(for: action)
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.font = .systemFont(ofSize: 11)
            button.target = self
            button.action = #selector(setActionFromButton(_:))
            button.tag = PluginGit.RebaseAction.allCases.firstIndex(of: action) ?? 0
            actionButtons.append(button)
        }
        for (button, title, selector) in [
            (upButton, L("Move up"), #selector(moveCommitUp)),
            (downButton, L("Move down"), #selector(moveCommitDown)),
            (startButton, L("Start rebase"), #selector(start)),
            (continueButton, L("Continue"), #selector(continueRebase)),
            (skipButton, L("Skip commit"), #selector(skipCommit)),
            (abortButton, L("Abort rebase"), #selector(abortRebase)),
        ] as [(NSButton, String, Selector)] {
            button.title = title
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.font = .systemFont(ofSize: 11)
            button.target = self
            button.action = selector
        }
        busy.style = .spinning
        busy.controlSize = .small
        busy.isDisplayedWhenStopped = false

        let decisions = NSStackView(views: actionButtons + [upButton, downButton])
        decisions.orientation = .horizontal
        decisions.spacing = 6

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.spacing = 6
        footer.alignment = .centerY
        footer.addView(busy, in: .leading)
        footer.addView(continueButton, in: .leading)
        footer.addView(skipButton, in: .leading)
        footer.addView(abortButton, in: .leading)
        footer.addView(startButton, in: .trailing)

        let stack = NSStackView(views: [header, decisions, scroll, footer])
        stack.orientation = .vertical
        stack.alignment = .width          // see F-419: `.centerX` is the default and draws a narrow column
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
        for child in [header, decisions, scroll, footer] as [NSView] {
            child.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -16).isActive = true
        }
        let height = scroll.heightAnchor.constraint(greaterThanOrEqualTo: heightAnchor, multiplier: 0.6)
        height.priority = .init(999)
        height.isActive = true
    }

    private static func label(for action: PluginGit.RebaseAction) -> String {
        switch action {
        case .pick:   return L("Pick")
        case .reword: return L("Reword…")
        case .squash: return L("Squash")
        case .fixup:  return L("Fixup")
        case .drop:   return L("Drop")
        }
    }

    // MARK: - Loading

    private func reload() {
        busy.startAnimation(nil)
        let root = self.root
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let running = PluginGitRepo.rebaseIsRunning(root: root)
            let status = PluginGitRepo.status(root: root)
            let upstream = status?.upstream
            var commits: [PluginGit.Commit] = []
            if let upstream, !running {
                let result = PluginGitRepo.run(["-C", root]
                    + PluginGit.logArguments(limit: 200, path: nil) + ["\(upstream)..HEAD"])
                // Reversed: git lists newest first, the todo file is applied oldest first.
                commits = result.ok ? PluginGit.parseLog(result.out).reversed() : []
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                self.running = running
                self.upstream = upstream
                self.commits = commits
                self.actions = Array(repeating: .pick, count: commits.count)
                self.table.reloadData()
                self.updateState()
                if !commits.isEmpty {
                    self.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                }
            }
        }
    }

    private func updateState() {
        for button in actionButtons + [upButton, downButton, startButton] {
            button.isEnabled = !running && !commits.isEmpty
        }
        for button in [continueButton, skipButton, abortButton] { button.isEnabled = running }
        if running {
            header.stringValue = L("A rebase is half-finished. Resolve the conflict, then continue — or abort to get the branch back.")
        } else if let upstream {
            header.stringValue = String(format: L("%lld commit(s) ahead of %@"), commits.count, upstream)
        } else {
            header.stringValue = L("This branch has no upstream, so there is nothing to rebase onto.")
        }
    }

    // MARK: - Editing the plan

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "r" {
            PluginGitRepo.invalidate()
            reload()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    @objc private func reloadFromMenu() { PluginGitRepo.invalidate(); reload() }

    @objc private func menuPick()   { decide(.pick) }
    @objc private func menuReword() { decide(.reword) }
    @objc private func menuSquash() { decide(.squash) }
    @objc private func menuFixup()  { decide(.fixup) }
    @objc private func menuDrop()   { decide(.drop) }

    private func decide(_ action: PluginGit.RebaseAction) {
        let rows = table.selectedRowIndexes
        guard !rows.isEmpty else { return }
        for row in rows where actions.indices.contains(row) { actions[row] = action }
        table.reloadData()
    }

    @objc private func copyHash() {
        guard commits.indices.contains(table.selectedRow) else { return }
        gitCopyToClipboard(commits[table.selectedRow].hash)
    }

    @objc private func setActionFromButton(_ sender: NSButton) {
        let all = PluginGit.RebaseAction.allCases
        guard all.indices.contains(sender.tag) else { return }
        decide(all[sender.tag])
    }

    // Not `moveUp`/`moveDown`: NSResponder has those, and a selector of the same name is ambiguous.
    @objc private func moveCommitUp() { move(by: -1) }
    @objc private func moveCommitDown() { move(by: 1) }

    /// Reordering is what a plain list cannot express: the todo file's order *is* the plan.
    private func move(by offset: Int) {
        let row = table.selectedRow
        let target = row + offset
        guard commits.indices.contains(row), commits.indices.contains(target) else { return }
        commits.swapAt(row, target)
        actions.swapAt(row, target)
        table.reloadData()
        table.selectRowIndexes(IndexSet(integer: target), byExtendingSelection: false)
    }

    // MARK: - Running

    @objc private func start() {
        guard let upstream, let status = PluginGitRepo.status(root: root) else { return }
        if let refusal = PluginGit.rebaseRefusal(repo: status, aheadCount: commits.count,
                                                actions: actions, rebaseRunning: running) {
            report(Self.text(for: refusal))
            return
        }
        // A reword needs a message, and git would otherwise open an editor this process cannot show.
        var messagePath: String?
        if let index = actions.firstIndex(of: .reword) {
            guard let message = promptMessage(for: commits[index]) else { return }
            guard let path = write(message, name: "pc-rebase-message") else {
                report(L("The message could not be written."))
                return
            }
            messagePath = path
        }
        guard let todoPath = write(PluginGit.rebaseTodo(commits: commits, actions: actions),
                                   name: "pc-rebase-todo") else {
            report(L("The plan could not be written."))
            return
        }

        let alert = NSAlert()
        alert.messageText = String(format: L("Rewrite %lld commit(s) on this branch?"), commits.count)
        // Not "you would have to force-push": the list is `upstream..HEAD`, so every commit in it is by
        // construction one the upstream does not have. Warning about rewriting other people's history here
        // was inaccurate, and a warning that does not apply is one a reader learns to click through (F-424).
        alert.informativeText = L("The commits are replaced by new ones. These are not on the upstream yet, so nobody else has them — but anything referring to them locally (another branch, a stash, an open worktree) keeps pointing at the old ones.")
        alert.addButton(withTitle: L("Rebase"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        run(PluginGit.rebaseArguments(upstream: upstream), environment: [
            "GIT_SEQUENCE_EDITOR": PluginGit.sequenceEditorValue(todoPath: todoPath),
            "GIT_EDITOR": PluginGit.editorValue(messagePath: messagePath),
        ], title: L("Rebase"))
    }

    @objc private func continueRebase() {
        // `--continue` also wants an editor for the message of the commit it is finishing.
        run(PluginGit.rebaseContinueArguments,
            environment: ["GIT_EDITOR": PluginGit.editorValue(messagePath: nil)], title: L("Continue"))
    }

    @objc private func skipCommit() {
        run(PluginGit.rebaseSkipArguments, environment: [:], title: L("Skip commit"))
    }

    @objc private func abortRebase() {
        run(PluginGit.rebaseAbortArguments, environment: [:], title: L("Abort rebase"))
    }

    private func run(_ arguments: [String], environment: [String: String], title: String) {
        busy.startAnimation(nil)
        let root = self.root
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PluginGitRepo.runWith(environment: environment, ["-C", root] + arguments)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                PluginGitRepo.invalidate()
                self.services.reloadActivePanel?(self.services.host)
                let message = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
                // A stopped rebase is not a failure: git leaves the sequence open on purpose, and the
                // window reloads into its Continue / Skip / Abort state, which is the next thing to do.
                self.services.presentInfo?(self.services.host, title,
                                           message.isEmpty ? L("Done.") : message)
                self.reload()
            }
        }
    }

    private static func text(for refusal: PluginGit.RebaseRefusal) -> String {
        switch refusal {
        case .dirtyWorkingTree:
            return L("The working tree has changes. Commit or stash them first.")
        case .conflictOpen:
            return L("There is an unresolved conflict. Finish it first.")
        case .noUpstream:
            return L("This branch has no upstream, so there is nothing to rebase onto.")
        case .nothingAhead:
            return L("There is no commit ahead of the upstream to rewrite.")
        case .squashWithoutParent:
            return L("The oldest commit cannot be squashed — there is nothing before it on this branch.")
        case .severalRewords:
            return L("Only one commit can be reworded per run: git would be handed the same message for each of them.")
        case .rebaseAlreadyRunning:
            return L("A rebase is already running. Continue or abort that one first.")
        }
    }

    private func promptMessage(for commit: PluginGit.Commit) -> String? {
        let alert = NSAlert()
        alert.messageText = String(format: L("New message for %@"), commit.shortHash)
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 22))
        field.stringValue = commit.subject
        alert.accessoryView = field
        alert.addButton(withTitle: L("Use it"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text + "\n"
    }

    private func write(_ text: String, name: String) -> String? {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-git-rebase", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name)-\(UUID().uuidString.prefix(6))")
        do { try text.write(to: url, atomically: true, encoding: .utf8) } catch { return nil }
        return url.path
    }

    private func report(_ message: String) {
        services.presentInfo?(services.host, L("Rebase"), message)
    }
}

extension GitRebaseView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { commits.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn, commits.indices.contains(row) else { return nil }
        let commit = commits[row]
        let identifier = NSUserInterfaceItemIdentifier("GitRebaseCell")
        let field = (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField)
            ?? {
                let f = NSTextField(labelWithString: "")
                f.identifier = identifier
                f.usesSingleLineMode = true
                f.lineBreakMode = .byTruncatingTail
                f.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
                return f
            }()
        field.textColor = .labelColor
        switch tableColumn.identifier.rawValue {
        case "action":
            let action = actions.indices.contains(row) ? actions[row] : .pick
            field.stringValue = Self.label(for: action)
            field.textColor = action == .drop ? .secondaryLabelColor : .labelColor
        case "hash":
            field.stringValue = commit.shortHash
        default:
            field.stringValue = commit.subject
            field.toolTip = commit.author
        }
        return field
    }
}
