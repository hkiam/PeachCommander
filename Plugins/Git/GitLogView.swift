// SPDX-License-Identifier: Apache-2.0
// GitLogView.swift — the history: commits with a lane graph, what each one changed, and a diff per file.
//
// Phase 2 of docs/analysis/git-plugin-plan.md (F-417). Two lists side by side rather than one window per
// question: commits on the left (graph, subject, author, date), the selected commit's files on the right,
// and Enter or a double-click on a file opening that commit's version against its parent in the host's
// compare window — the same `compareFiles` handover phase 1 added, so there is still exactly one diff
// implementation in the application.
//
// The same view serves a *file's* history: created with a path, it passes `--follow -- <path>` to git and
// its title says which file. That is the "File history" of the reference products, and it needs no second
// view.
//
// The graph is computed in Plugins/SDK/PluginGit.swift (lane assignment, unit-tested) and drawn as
// monospace text in its own column. A custom renderer would look better and is not what the first version
// of a history list needs to be right about.

import AppKit

@MainActor
final class GitLogView: NSView {
    private let services: PcHostServices
    private let root: String
    /// nil = the whole repository; otherwise this file's history.
    private let path: String?

    private var commits: [PluginGit.Commit] = []
    private var graph: [PluginGit.GraphRow] = []
    private var graphWidth = 1
    private var files: [(status: String, path: String)] = []

    private let header = NSTextField(labelWithString: "")
    private let commitTable = NSTableView()
    private let fileTable = NSTableView()
    private let busy = NSProgressIndicator()
    private let loadMoreButton = NSButton()
    private let revertButton = NSButton()
    private let cherryPickButton = NSButton()
    private var limit = 100
    private let split = NSSplitView()

    init(services: PcHostServices, root: String, path: String?) {
        self.services = services
        self.root = root
        self.path = path
        super.init(frame: NSRect(x: 0, y: 0, width: 720, height: 420))
        build()
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Building

    private func build() {
        header.font = .systemFont(ofSize: 12, weight: .semibold)
        header.lineBreakMode = .byTruncatingMiddle

        for (table, columns) in [
            (commitTable, [("graph", "", 44), ("subject", L("Subject"), 320),
                           ("author", L("Author"), 120), ("date", L("Date"), 130)]),
            (fileTable, [("status", "", 28), ("file", L("File"), 320)]),
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
        commitTable.target = self
        fileTable.target = self
        fileTable.doubleAction = #selector(diffSelectedFile)
        commitTable.doubleAction = #selector(diffSelectedFile)

        for (button, title, action) in [
            (loadMoreButton, L("Load more"), #selector(loadMore)),
            (revertButton, L("Revert commit"), #selector(revertSelectedCommit)),
            (cherryPickButton, L("Cherry-pick"), #selector(cherryPickSelectedCommit)),
        ] as [(NSButton, String, Selector)] {
            button.title = title
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.font = .systemFont(ofSize: 11)
            button.target = self
            button.action = action
        }
        busy.style = .spinning
        busy.controlSize = .small
        busy.isDisplayedWhenStopped = false

        let left = NSScrollView(); left.documentView = commitTable
        left.hasVerticalScroller = true
        let right = NSScrollView(); right.documentView = fileTable
        right.hasVerticalScroller = true
        split.isVertical = true
        split.dividerStyle = .thin
        split.addArrangedSubview(left)
        split.addArrangedSubview(right)
        split.translatesAutoresizingMaskIntoConstraints = false

        // Gravity areas rather than a spacer view: "Load more" belongs to the list on the left, the two
        // commit actions to the right. A spacer NSView would work too, but it is a subview with no
        // intrinsic size whose only job is to be wide, and `.trailing` says the same thing to AppKit
        // without one.
        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.spacing = 6
        footer.alignment = .centerY
        footer.addView(loadMoreButton, in: .leading)
        footer.addView(busy, in: .leading)
        footer.addView(revertButton, in: .trailing)
        footer.addView(cherryPickButton, in: .trailing)

        let stack = NSStackView(views: [header, split, footer])
        stack.orientation = .vertical
        // Vertical stacks default to `.centerX`: children keep their intrinsic width and the whole
        // window's content sits in a narrow column in the middle. Measured in the log window: an 820-point
        // view with a 436-point split view and a 121-point header floating in the centre of it (F-419).
        // `.width` is what "fill the window" means for an NSStackView.
        stack.alignment = .width
        for child in [header, split, footer] as [NSView] {
            child.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -16).isActive = true
        }
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
        // A preference, not a rule: the container is legitimately zero-sized while hidden, and a required
        // height against that is an Auto Layout conflict (CONVENTIONS.md).
        let height = split.heightAnchor.constraint(greaterThanOrEqualTo: heightAnchor, multiplier: 0.6)
        height.priority = .init(999)
        height.isActive = true

        // The two panes get their widths from constraints, not from `setPosition`. Measured: with
        // `setPosition` in `layout()` the commit list came out **zero points wide** — the accessibility
        // dump said `AXSplitter = 0` and the table had created no row views at all, in a window whose data
        // had loaded fine. An NSScrollView has no intrinsic width, so under constraint-based layout the
        // split view is free to give one pane everything, and a position set before the view is sized is
        // exactly the trap CONVENTIONS.md records. Minimums are required-ish (999, since the container may
        // legitimately be zero-sized while hidden); the 55/45 split is a *preference* at 500, so dragging
        // the divider still works.
        let leftMinimum = left.widthAnchor.constraint(greaterThanOrEqualToConstant: 240)
        let rightMinimum = right.widthAnchor.constraint(greaterThanOrEqualToConstant: 160)
        let ratio = left.widthAnchor.constraint(equalTo: split.widthAnchor, multiplier: 0.55)
        leftMinimum.priority = .init(999)
        rightMinimum.priority = .init(999)
        ratio.priority = .init(500)
        NSLayoutConstraint.activate([leftMinimum, rightMinimum, ratio])
    }

    // MARK: - Loading

    @objc private func loadMore() { limit += 200; reload() }

    private func reload() {
        busy.startAnimation(nil)
        let root = self.root, path = self.path, limit = self.limit
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PluginGitRepo.run(["-C", root] + PluginGit.logArguments(limit: limit, path: path))
            let commits = result.ok ? PluginGit.parseLog(result.out) : []
            let graph = PluginGit.graph(commits)
            let width = max(1, graph.map { max($0.lanes.count, $0.lane + 1) }.max() ?? 1)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                self.commits = commits
                self.graph = graph
                self.graphWidth = min(width, 8)   // beyond eight lanes the text column stops helping
                self.commitTable.reloadData()
                self.updateHeader()
                if !commits.isEmpty {
                    self.commitTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                }
            }
        }
    }

    private func updateHeader() {
        let name = (root as NSString).lastPathComponent
        if let path {
            header.stringValue = String(format: L("History of %@ — %lld commit(s)"), path, commits.count)
        } else {
            header.stringValue = String(format: L("%@ — %lld commit(s)"), name, commits.count)
        }
    }

    /// The files a commit touched, against its first parent.
    private func loadFiles(for commit: PluginGit.Commit) {
        busy.startAnimation(nil)
        let root = self.root
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // `--name-status` against the first parent: for a merge that is the useful side, and for a
            // root commit there is no parent, so `show` is asked instead.
            let arguments = ["-C", root, "--no-optional-locks", "show", "--name-status",
                             "--format=", "-m", "--first-parent", commit.hash]
            let result = PluginGitRepo.run(arguments)
            var files: [(String, String)] = []
            for line in result.out.split(separator: "\n", omittingEmptySubsequences: true) {
                let parts = line.split(separator: "\t", omittingEmptySubsequences: true).map(String.init)
                guard parts.count >= 2 else { continue }
                files.append((String(parts[0].prefix(1)), parts.last!))
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                self.files = files
                self.fileTable.reloadData()
            }
        }
    }

    // MARK: - Diff

    /// Compare the selected file at the selected commit with the same file at that commit's first parent.
    @objc private func diffSelectedFile() {
        let commitRow = commitTable.selectedRow
        guard commits.indices.contains(commitRow) else { return }
        let commit = commits[commitRow]
        let fileRow = fileTable.selectedRow
        guard files.indices.contains(fileRow) else {
            report(L("Git"), L("Select a file of that commit."))
            return
        }
        let file = files[fileRow].path
        let parent = commit.parents.first
        busy.startAnimation(nil)
        let root = self.root
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let newer = PluginGitRepo.writeBlob(root: root, spec: "\(commit.hash):\(file)",
                                                path: file, base: .head)
            let older = parent.flatMap {
                PluginGitRepo.writeBlob(root: root, spec: "\($0):\(file)", path: file, base: .index)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                guard let newer else {
                    self.report(L("Git"), L("That version could not be read."))
                    return
                }
                // A file added by this commit has no older side; comparing it with an empty temp file is
                // more honest than refusing, and it is what the reference products show.
                let left = older ?? PluginGitRepo.writeEmptyBlob(path: file)
                let leftTitle = parent.map { "\(String($0.prefix(8))):\(file)" } ?? L("(added)")
                let rightTitle = "\(String(commit.hash.prefix(8))):\(file)"
                guard let left else { return }
                left.withCString { a in
                    newer.withCString { b in
                        leftTitle.withCString { at in
                            rightTitle.withCString { bt in
                                self.services.compareFiles?(self.services.host, a, b, at, bt)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Revert and cherry-pick (phase 4, F-419)

    private enum Sequencer { case revert, cherryPick }

    @objc private func revertSelectedCommit() { run(.revert) }
    @objc private func cherryPickSelectedCommit() { run(.cherryPick) }

    /// Undo a commit on top of the branch, or replay it here.
    ///
    /// Both refuse before they start when the working tree is not clean: git's sequencer requires that and
    /// says so in terms of overwritten local changes, which reads as if the chosen commit were the problem.
    /// A conflicting result is *not* an error — git stops mid-sequence and leaves the conflict markers, and
    /// saying that plainly is more use than a red "failed", since the next step is the conflict command.
    private func run(_ kind: Sequencer) {
        let title = kind == .revert ? L("Revert commit") : L("Cherry-pick")
        guard commits.indices.contains(commitTable.selectedRow) else {
            report(title, L("Select a commit first."))
            return
        }
        let commit = commits[commitTable.selectedRow]
        if let repo = PluginGitRepo.status(root: root),
           let refusal = PluginGit.refusal(forCommitActionIn: repo) {
            report(title, refusal == .conflictOpen
                ? L("There is an unresolved conflict. Finish it first.")
                : L("The working tree has changes. Commit or stash them first."))
            return
        }

        let alert = NSAlert()
        alert.messageText = kind == .revert
            ? String(format: L("Revert %@?"), commit.shortHash)
            : String(format: L("Cherry-pick %@ onto the current branch?"), commit.shortHash)
        alert.informativeText = commit.subject
        alert.addButton(withTitle: kind == .revert ? L("Revert") : L("Cherry-pick"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        busy.startAnimation(nil)
        let root = self.root
        let arguments = kind == .revert
            ? PluginGit.revertArguments(commit.hash)
            : PluginGit.cherryPickArguments(commit.hash)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PluginGitRepo.run(["-C", root] + arguments, combined: true)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                PluginGitRepo.invalidate()          // HEAD and the index both moved
                self.services.reloadActivePanel?(self.services.host)
                let message = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
                self.report(title, message.isEmpty ? L("Done.") : message)
                self.reload()
            }
        }
    }

    private func report(_ title: String, _ message: String) {
        services.presentInfo?(services.host, title, message)
    }
}

// MARK: - Tables

extension GitLogView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === commitTable ? commits.count : files.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("GitLogCell")
        let field = (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField)
            ?? {
                let f = NSTextField(labelWithString: "")
                f.identifier = identifier
                f.usesSingleLineMode = true
                f.lineBreakMode = .byTruncatingTail
                f.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
                return f
            }()
        if tableView === commitTable {
            guard commits.indices.contains(row) else { return nil }
            let commit = commits[row]
            switch tableColumn.identifier.rawValue {
            case "graph":
                field.stringValue = graph.indices.contains(row)
                    ? PluginGit.graphText(graph[row], width: graphWidth) : ""
            case "subject":
                field.stringValue = commit.subject
                field.toolTip = "\(commit.shortHash)  \(commit.subject)"
            case "author":
                field.stringValue = commit.author
            default:
                field.stringValue = Self.dateFormatter.string(from: commit.date)
            }
        } else {
            guard files.indices.contains(row) else { return nil }
            let file = files[row]
            field.stringValue = tableColumn.identifier.rawValue == "status" ? file.status : file.path
        }
        return field
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView, table === commitTable,
              commits.indices.contains(table.selectedRow) else { return }
        files = []
        fileTable.reloadData()
        loadFiles(for: commits[table.selectedRow])
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
}
