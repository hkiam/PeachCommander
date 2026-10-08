// SPDX-License-Identifier: Apache-2.0
// GitHistoryView.swift — the panel's history: every branch as a drawn graph, the working copy on top.
//
// Phase 6 (the panel as a client). The log window already had a history, but as a separate window and
// with the graph as box-drawing text. Here the graph is drawn — lanes, nodes, merges bending out and
// branches bending back in — from `PluginGit.graphLines`, which is where the geometry is tested; this
// view only strokes what it is given.
//
// The first row is not a commit: it is the working copy ("Local changes (3)"), the way Fork shows it.
// Selecting it puts the staging list and the commit box in the panel's detail area, so the panel has one
// list and one selection rather than a status list *and* a history competing for the same height.

import AppKit

@MainActor
final class GitHistoryView: NSView {
    /// `several`: two or more commits selected (phase 8) — compared, oldest against newest, and offered
    /// for a cherry-pick in the order they were made.
    enum Selection: Equatable { case workingCopy, commit(PluginGit.Commit), several([PluginGit.Commit]) }

    /// "Bisect: mark as good / bad" on one commit.
    var onBisect: ((PluginGit.BisectMark, PluginGit.Commit) -> Void)?

    /// "Compare with the working tree" on one commit.
    var onCompareWithWorkingTree: ((PluginGit.Commit) -> Void)?

    /// The selection changed (nil: nothing, or the "load more" row).
    var onSelectionChange: ((Selection?) -> Void)?
    var onLoadMore: (() -> Void)?
    /// Something the context menu did moved HEAD or the refs; the panel reloads.
    var onChanged: (() -> Void)?
    /// "Only the current branch" was toggled; the panel reads `onlyCurrentBranch` for its next load.
    var onScopeChange: (() -> Void)?
    /// The search text changed (after a typing pause, or on Return); the panel reads `searchText`.
    var onSearch: (() -> Void)?

    /// What the search field holds, trimmed; empty when the history is not being searched.
    var searchText: String { searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) }

    var root: String?
    private(set) var onlyCurrentBranch = false

    private let services: PcHostServices
    private var theme: PluginTheme
    private let table = GitTable()
    private let scroll = NSScrollView()
    private let searchField = NSSearchField()
    private let emptyLabel = NSTextField(labelWithString: "")
    /// The list shows search results: no working-copy row, and no lanes — the results are not a
    /// connected history, so a graph through them would draw branches that are not there.
    private var searching = false
    /// The row the first commit is in: 1 below the working copy, 0 when searching.
    private var offset: Int { searching ? 0 : 1 }
    /// Whether the list shows search results — the search that was *applied*, not the field's text.
    var isSearching: Bool { searching }
    private var commits: [PluginGit.Commit] = []
    private var drawn: [(node: Int, lines: [PluginGit.GraphLine])] = []
    private var laneCount = 1
    private var changeCount = 0
    private var hasMore = false
    private var hasRepo = false
    private var preferredWidth: [NSUserInterfaceItemIdentifier: CGFloat] = [:]
    private let busy: NSProgressIndicator
    /// Set while `update` reloads and reselects, so the selection it restores is reported once, by
    /// `update` itself, rather than again by the delegate.
    private var updating = false

    init(services: PcHostServices, busy: NSProgressIndicator) {
        self.services = services
        self.theme = PluginTheme(services)
        self.busy = busy
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 240))
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        table.rowHeight = 20
        table.intercellSpacing = NSSize(width: 6, height: 0)     // the graph's lanes must meet row to row
        table.style = .fullWidth
        table.font = .systemFont(ofSize: 11)
        table.columnAutoresizingStyle = .noColumnAutoresizing
        for (id, title, width, flexible) in [
            ("graph", "", 28, false), ("subject", L("Subject"), 320, true),
            ("author", L("Author"), 120, true), ("hash", L("Hash"), 64, false),
            ("date", L("Date"), 120, true),
        ] as [(String, String, CGFloat, Bool)] {
            let column = NSTableColumn(identifier: .init(id))
            column.title = title
            column.width = width
            if flexible {
                column.resizingMask = [.autoresizingMask, .userResizingMask]
                column.minWidth = min(width, 70)
                preferredWidth[column.identifier] = width
            } else {
                column.resizingMask = .userResizingMask
            }
            table.addTableColumn(column)
        }
        table.allowsMultipleSelection = true
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(activateRow)
        table.onEnter = { [weak self] in self?.activateRow() }
        let menu = gitMenu([
            (L("Apply stash"), #selector(applyStash)),
            (L("Pop stash"), #selector(popStash)),
            (L("Drop stash…"), #selector(dropStash)),
            (L("Copy commit hash"), #selector(copyHash)),
            (L("Copy subject"), #selector(copySubject)),
            (nil, nil),
            (L("Check out this commit…"), #selector(checkoutSelected)),
            (L("New branch here…"), #selector(branchHere)),
            (L("New tag here…"), #selector(tagHere)),
            (nil, nil),
            (L("Merge into the current branch…"), #selector(mergeSelected)),
            (L("Rebase the current branch onto this…"), #selector(rebaseOntoSelected)),
            (L("Interactive rebase from here…"), #selector(interactiveRebaseFromHere)),
            (L("Reset the current branch to here…"), #selector(resetToSelected)),
            (L("Edit message…"), #selector(editMessage)),
            (L("Edit messages…"), #selector(editMessages)),
            (L("Find and replace in messages…"), #selector(replaceInMessages)),
            (nil, nil),
            (L("Revert commit"), #selector(revertSelected)),
            (L("Cherry-pick"), #selector(cherryPickSelected)),
            (L("Cherry-pick the selected commits"), #selector(cherryPickSeveral)),
            (L("Compare with the working tree"), #selector(compareWithWorkingTree)),
            (L("Save as patch…"), #selector(savePatches)),
            (nil, nil),
            (L("Bisect: mark as bad"), #selector(bisectBad)),
            (L("Bisect: mark as good"), #selector(bisectGood)),
            (L("Open on the web"), #selector(openSelectedOnTheWeb)),
            (nil, nil),
            (L("Only the current branch"), #selector(toggleScope)),
            (L("Reflog…"), #selector(showReflog)),
            (L("Reload"), #selector(reloadFromMenu)),
        ], target: self)
        // A stash row and a commit row have different menus; `menuNeedsUpdate` hides what does not apply.
        menu.delegate = self
        table.menu = menu

        searchField.placeholderString = L("Search commits: hash, author, message")
        searchField.toolTip = L("Also: author:name, path:folder/, since:\"2 weeks ago\", until:2026-10-01")
        searchField.controlSize = .small
        searchField.font = .systemFont(ofSize: 11)
        // After a pause in typing rather than on every key: each search is up to three runs of git over
        // the whole history.
        searchField.sendsSearchStringImmediately = false
        searchField.sendsWholeSearchString = false
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.stringValue = L("No commits found.")
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = .systemFont(ofSize: 11)
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.contentView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(clipFrameChanged(_:)),
                                               name: NSView.frameDidChangeNotification,
                                               object: scroll.contentView)
        addSubview(searchField)
        addSubview(scroll)
        addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: topAnchor),
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 40),
            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        applyTheme(theme)
    }

    func applyTheme(_ theme: PluginTheme) {
        self.theme = theme
        table.backgroundColor = theme.background
        scroll.backgroundColor = theme.background
        emptyLabel.textColor = theme.secondaryText
        scroll.drawsBackground = true
        table.reloadData()
    }

    // MARK: - Data

    /// Show a new history, keeping the selected commit selected when it is still there.
    ///
    /// `searching` says the commits are search results: they are listed without the working copy and
    /// without lanes, and the first one is selected when the previous selection is not among them.
    func update(commits: [PluginGit.Commit], hasRepo: Bool, changeCount: Int, hasMore: Bool,
                searching: Bool = false) {
        let previous = selection
        // "Load more" was the selected row: after loading, the first of the new commits takes its place —
        // not the working copy at the top, which would also swap the detail area away.
        let loadedMore = self.hasMore && table.selectedRow > 0 && table.selectedRow == numberOfRows(in: table) - 1
        let previousCount = self.commits.count
        let previousOffset = offset
        updating = true
        defer { updating = false }
        self.searching = searching
        self.commits = commits
        self.hasRepo = hasRepo
        self.changeCount = changeCount
        self.hasMore = hasMore
        drawn = searching ? commits.map { _ in (node: 0, lines: []) } : Self.drawnRows(commits)
        emptyLabel.isHidden = !(searching && commits.isEmpty && hasRepo)
        // Beyond ten lanes the subject is what suffers; the cell clips the strokes past that.
        let lanes = drawn.map { row in max(row.node, row.lines.map { max($0.from, $0.to) }.max() ?? 0) + 1 }
        laneCount = min(max(lanes.max() ?? 1, 1), 10)
        table.tableColumn(withIdentifier: .init("graph"))?.width = GitGraphCell.width(lanes: laneCount)
        table.reloadData()
        fitColumns()

        // Without a match for the previous selection: the working copy, or in a search the first result.
        let fallback = !hasRepo || (searching && commits.isEmpty) ? -1 : 0
        let row: Int
        switch previous {
        case .commit(let commit)?:
            row = commits.firstIndex { $0.hash == commit.hash }.map { $0 + offset } ?? fallback
        case nil where loadedMore && commits.count > previousCount:
            row = previousCount + previousOffset
        default:
            row = fallback
        }
        if row >= 0 {
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            if loadedMore { table.scrollRowToVisible(row) }
        } else {
            table.deselectAll(nil)
        }
        // Reported here, once, whether or not the row changed: reloading with the same row selected posts
        // no selection change, but the detail area must follow the new data (the change count moved).
        onSelectionChange?(selection)
    }

    var selection: Selection? {
        let several = table.selectedRowIndexes.compactMap { row -> PluginGit.Commit? in
            commits.indices.contains(row - offset) ? commits[row - offset] : nil
        }
        // In the history's order — newest first, topologically — which is the only order a series made
        // in one second (a rebase, `git am`) still has; callers reverse it for oldest first.
        if several.count >= 2 { return .several(several) }
        let row = table.selectedRow
        if row == 0, hasRepo, !searching { return .workingCopy }
        let index = row - offset
        return commits.indices.contains(index) ? .commit(commits[index]) : nil
    }

    /// Select the commit with this hash, when it is loaded (a parent link in the Commit tab).
    func select(hash: String) {
        guard let index = commits.firstIndex(where: { $0.hash == hash }) else { return }
        table.selectRowIndexes(IndexSet(integer: index + offset), byExtendingSelection: false)
        table.scrollRowToVisible(index + offset)
    }

    func selectRows(_ rows: IndexSet) {
        table.selectRowIndexes(rows, byExtendingSelection: false)
    }

    func selectRow(_ row: Int) {
        guard row >= 0, row < numberOfRows(in: table) else { return }
        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    /// One line per row as the verification dump reports it: the lane, the refs and the subject.
    func automationRows() -> [String] {
        var out = ["search=\(searching ? searchText : "<none>")", "rows=\(numberOfRows(in: table))",
                   "commits=\(commits.count) hasMore=\(hasMore)"]
        if hasRepo, !searching { out.append("row0=working-copy changes=\(changeCount)") }
        if !emptyLabel.isHidden { out.append("empty=\(emptyLabel.stringValue)") }
        // As the menu opens for the selected row: hidden items left out.
        if let menu = table.menu { menuNeedsUpdate(menu) }
        out.append("menu=" + (table.menu?.items.filter { !$0.isHidden }.map { $0.isSeparatorItem ? "|" : $0.title } ?? [])
            .joined(separator: ";"))
        for (index, commit) in commits.prefix(20).enumerated() {
            let refs = commit.refs.map { "\($0.kind.rawValue):\($0.name)" }.joined(separator: ",")
            out.append("row\(index + offset)=lane\(drawn[index].node) [\(refs)] \(commit.subject)")
        }
        return out
    }

    private var selectedCommit: PluginGit.Commit? {
        if case .commit(let commit)? = selection { return commit }
        return nil
    }

    /// The graph of a history that may hold stash rows. Lanes come from the real commits alone — a stash
    /// is not part of the history — and a stash row lets every lane alive at that point run straight
    /// through, with its node on the lane of the commit below it, the one it was made on.
    private static func drawnRows(_ rows: [PluginGit.Commit]) -> [(node: Int, lines: [PluginGit.GraphLine])] {
        let real = rows.filter { !PluginGit.isStash($0) }
        let graph = PluginGit.graph(real)
        let lines = PluginGit.graphLines(graph)
        var out: [(node: Int, lines: [PluginGit.GraphLine])] = []
        var next = 0          // the real commit the next stash row sits above
        for row in rows {
            if PluginGit.isStash(row) {
                guard next < graph.count else { out.append((0, [])); continue }
                let node = lines[next].node
                var strokes: [PluginGit.GraphLine] = []
                for (lane, waiting) in graph[next].lanes.enumerated() where waiting != nil && next > 0 {
                    strokes.append(.init(from: lane, to: lane, upper: true, color: lane))
                    strokes.append(.init(from: lane, to: lane, upper: false, color: lane))
                }
                if !strokes.contains(where: { !$0.upper && $0.from == node }) {
                    strokes.append(.init(from: node, to: node, upper: false, color: node))
                }
                out.append((node, strokes))
            } else {
                out.append(lines[next])
                next += 1
            }
        }
        return out
    }

    // MARK: - Layout

    @objc private func clipFrameChanged(_ note: Notification) { fitColumns() }

    /// Narrow sidebars drop the columns that matter least first — the hash, then the author — and give the
    /// subject what is left.
    private func fitColumns() {
        let width = scroll.contentView.bounds.width
        table.tableColumn(withIdentifier: .init("hash"))?.isHidden = width < 560
        table.tableColumn(withIdentifier: .init("author"))?.isHidden = width < 420
        table.tableColumn(withIdentifier: .init("date"))?.isHidden = width < 300
        gitFitColumns(table, preferred: preferredWidth)
    }

    // MARK: - Actions

    /// Return or a double-click: on the last row, "Load more".
    @objc func activateRow() {
        if table.selectedRow == numberOfRows(in: table) - 1, hasMore { onLoadMore?() }
    }

    @objc private func searchChanged() { onSearch?() }

    /// Put a search into the field without a reader typing it (the verification probe).
    func setSearchText(_ text: String) { searchField.stringValue = text }

    /// "Only the current branch" without the context menu (the verification probe).
    func setOnlyCurrentBranch(_ on: Bool) { onlyCurrentBranch = on }

    @objc private func copyHash() {
        // Several selected: all their hashes, one per line, newest first as listed.
        let several = selectedSeveral
        if several.count >= 2 { gitCopyToClipboard(several.map(\.hash).joined(separator: "\n")); return }
        selectedCommit.map { gitCopyToClipboard($0.hash) }
    }
    private var selectedStash: PluginGit.Commit? { selectedCommit.flatMap { PluginGit.isStash($0) ? $0 : nil } }

    @objc private func applyStash() { stash(.apply) }
    @objc private func popStash() { stash(.pop) }
    @objc private func dropStash() { stash(.drop) }

    /// The stash is named by its hash, not by the `stash@{n}` it had when the history loaded: a stash
    /// pushed or dropped elsewhere since moves every position, and dropping by an old name would drop a
    /// different stash for good. So its current name is looked up first.
    private func stash(_ action: PluginGit.StashAction) {
        guard let root, let stash = selectedStash else { return }
        let box = ServicesBox(services)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let output = PluginGitRepo.run(["-C", root] + PluginGit.stashCommitsArguments).out
            let ref = PluginGit.currentStashRef(hash: stash.hash, in: output)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard let ref else {
                    GitCommitActions.report(box.services, L("Stash"), L("That stash is gone; the list is reloaded."))
                    self.onChanged?()
                    return
                }
                if action == .drop {
                    let alert = NSAlert()
                    alert.alertStyle = .warning
                    alert.messageText = String(format: L("Drop %@?"), ref)
                    alert.informativeText = stash.subject + "\n\n" + L("This cannot be undone.")
                    alert.addButton(withTitle: L("Drop"))
                    alert.addButton(withTitle: L("Cancel"))
                    guard alert.runModal() == .alertFirstButtonReturn else { return }
                }
                GitCommitActions.run(PluginGit.stashArguments(action, ref: ref), title: L("Stash"), root: root,
                                     services: box.services, busy: self.busy) { [weak self] in self?.onChanged?() }
            }
        }
    }

    @objc private func showReflog() {
        guard let root else { return }
        showReflogWindow(root: root, services)
    }

    @objc private func copySubject() { selectedCommit.map { gitCopyToClipboard($0.subject) } }
    @objc private func revertSelected() { runSequencer(.revert) }
    @objc private func cherryPickSelected() { runSequencer(.cherryPick) }

    private var selectedSeveral: [PluginGit.Commit] {
        if case .several(let commits)? = selection { return commits }
        return []
    }

    @objc private func cherryPickSeveral() {
        guard let root else { return }
        guard let arguments = PluginGit.cherryPickSeriesArguments(selectedSeveral) else {
            GitCommitActions.report(services, L("Cherry-pick"),
                                    L("A merge commit cannot be picked as part of a series. Pick it on its own."))
            return
        }
        if let repo = PluginGitRepo.status(root: root), PluginGit.refusal(forCommitActionIn: repo) != nil {
            GitCommitActions.report(services, L("Cherry-pick"), L("The working tree has changes. Commit or stash them first."))
            return
        }
        let alert = NSAlert()
        alert.messageText = String(format: L("Cherry-pick %lld commits onto the current branch?"), selectedSeveral.count)
        alert.informativeText = L("They are applied in the order they were made. A conflict stops the series; the panel then offers to continue or abort.")
        alert.addButton(withTitle: L("Cherry-pick"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        GitCommitActions.run(arguments, title: L("Cherry-pick"), root: root, services: services, busy: busy) {
            [weak self] in self?.onChanged?()
        }
    }

    @objc private func bisectBad() { selectedCommit.map { onBisect?(.bad, $0) } }
    @objc private func bisectGood() { selectedCommit.map { onBisect?(.good, $0) } }

    /// The selected commit — or each of several, oldest first, numbered as `git format-patch` numbers
    /// them — saved as a patch file to send or apply elsewhere.
    @objc private func savePatches() {
        guard let root else { return }
        let several = Array(selectedSeveral.reversed())     // history order is newest first
        let commits = several.count >= 2 ? several : selectedCommit.map { [$0] } ?? []
        guard !commits.isEmpty else { return }
        let directory: URL
        if commits.count == 1 {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = PluginGit.patchFileName(number: 1, subject: commits[0].subject)
            guard panel.runModal() == .OK, let url = panel.url else { return }
            directory = url.deletingLastPathComponent()
            writePatches(commits, root: root, into: directory, firstName: url.lastPathComponent)
        } else {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
            panel.prompt = L("Save patches here")
            guard panel.runModal() == .OK, let url = panel.url else { return }
            directory = url
            writePatches(commits, root: root, into: directory, firstName: nil)
        }
    }

    private func writePatches(_ commits: [PluginGit.Commit], root: String, into directory: URL, firstName: String?) {
        let box = ServicesBox(services)
        busy.startAnimation(nil)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var failed: String?
            for (index, commit) in commits.enumerated() {
                guard let data = PluginGitRepo.runData(["-C", root] + PluginGit.formatPatchArguments(commit.hash)) else {
                    failed = commit.shortHash; break
                }
                let name = index == 0 && firstName != nil ? firstName! : PluginGit.patchFileName(number: index + 1, subject: commit.subject)
                do { try data.write(to: directory.appendingPathComponent(name)) } catch { failed = commit.shortHash; break }
            }
            DispatchQueue.main.async {
                self?.busy.stopAnimation(nil)
                if let failed {
                    GitCommitActions.report(box.services, L("Save as patch…"), String(format: L("The patch of %@ could not be written."), failed))
                }
            }
        }
    }

    @objc private func compareWithWorkingTree() {
        guard let commit = selectedCommit else { return }
        onCompareWithWorkingTree?(commit)
    }
    @objc private func reloadFromMenu() { onChanged?() }

    @objc private func toggleScope() {
        onlyCurrentBranch.toggle()
        onScopeChange?()
    }

    private func runSequencer(_ kind: GitCommitActions.Sequencer) {
        guard let root, let commit = selectedCommit else { return }
        GitCommitActions.runSequencer(kind, commit: commit, root: root, services: services, busy: busy) {
            [weak self] in self?.onChanged?()
        }
    }

    @objc private func openSelectedOnTheWeb() {
        guard let root, let commit = selectedCommit else { return }
        GitCommitActions.openCommitOnTheWeb(hash: commit.hash, root: root, services: services)
    }

    private typealias CommitAction = (PluginGit.Commit, String, PcHostServices, NSProgressIndicator?,
                                      @escaping () -> Void) -> Void

    private func act(_ action: CommitAction) {
        guard let root, let commit = selectedCommit else { return }
        action(commit, root, services, busy) { [weak self] in self?.onChanged?() }
    }

    @objc private func checkoutSelected() { act { GitCommitActions.checkout($0, root: $1, services: $2, busy: $3, done: $4) } }
    @objc private func branchHere() { act { GitCommitActions.branchHere($0, root: $1, services: $2, busy: $3, done: $4) } }
    @objc private func tagHere() { act { GitCommitActions.tagHere($0, root: $1, services: $2, busy: $3, done: $4) } }
    @objc private func mergeSelected() { act { GitCommitActions.merge($0, root: $1, services: $2, busy: $3, done: $4) } }
    @objc private func rebaseOntoSelected() { act { GitCommitActions.rebaseOnto($0, root: $1, services: $2, busy: $3, done: $4) } }
    @objc private func resetToSelected() { act { GitCommitActions.reset(to: $0, root: $1, services: $2, busy: $3, done: $4) } }

    /// The commit messages window (phase 10): on this commit, on the selected ones, or on the current
    /// branch for find and replace. Stashes are not commits of the history and are left out.
    @objc private func editMessage() {
        guard let root, let commit = selectedCommit, !PluginGit.isStash(commit) else { return }
        showMessagesWindow(root: root, commits: [commit.hash], services)
    }

    @objc private func editMessages() {
        guard let root else { return }
        let commits = selectedSeveral.filter { !PluginGit.isStash($0) }.map(\.hash)
        guard !commits.isEmpty else { return }
        showMessagesWindow(root: root, commits: commits, services)
    }

    @objc private func replaceInMessages() {
        guard let root else { return }
        showMessagesWindow(root: root, services)
    }

    /// The Rebase window, starting at this commit. Only below the current branch's tip: from a commit HEAD
    /// does not contain, the list would be HEAD's own commits and the rebase would move the branch there.
    @objc private func interactiveRebaseFromHere() {
        guard let root, let commit = selectedCommit else { return }
        let box = ServicesBox(services)
        DispatchQueue.global(qos: .userInitiated).async {
            let isAncestor = PluginGitRepo.run(["-C", root] + PluginGit.isAncestorOfHeadArguments(commit.hash)).ok
            DispatchQueue.main.async {
                guard isAncestor else {
                    GitCommitActions.report(box.services, L("Rebase"),
                                            L("That commit is not on the current branch, so there is nothing to rebase from it."))
                    return
                }
                showRebaseWindow(root: root, base: commit.hash, box.services)
            }
        }
    }
}

extension GitHistoryView: NSMenuDelegate {
    /// A stash row offers the stash's three actions, a commit row the commit's; the hash and the view
    /// items are on both. Separators that end up next to each other or at the top are hidden as well.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let stashActions: Set<Selector> = [#selector(applyStash), #selector(popStash), #selector(dropStash)]
        let shared: Set<Selector> = [#selector(copyHash), #selector(copySubject), #selector(toggleScope),
                                     #selector(showReflog), #selector(reloadFromMenu), #selector(replaceInMessages)]
        let severalActions: Set<Selector> = [#selector(cherryPickSeveral), #selector(savePatches), #selector(editMessages)]
        let onStash = selectedStash != nil
        let onSeveral = selectedSeveral.count >= 2
        for item in menu.items where !item.isSeparatorItem {
            guard let action = item.action else { continue }
            if shared.contains(action) {
                item.isHidden = false
            } else if onSeveral {
                item.isHidden = !severalActions.contains(action)      // several commits: what fits several
            } else if severalActions.contains(action) {
                item.isHidden = true
            } else {
                item.isHidden = stashActions.contains(action) ? !onStash : onStash
            }
        }
        var previousVisibleIsSeparator = true
        for item in menu.items where item.isSeparatorItem || !item.isHidden {
            if item.isSeparatorItem {
                item.isHidden = previousVisibleIsSeparator
                if !item.isHidden { previousVisibleIsSeparator = true }
            } else {
                previousVisibleIsSeparator = false
            }
        }
    }
}

extension GitHistoryView: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleScope) {
            menuItem.state = onlyCurrentBranch ? .on : .off
            return hasRepo
        }
        if menuItem.action == #selector(reloadFromMenu) || menuItem.action == #selector(showReflog) { return hasRepo }
        if menuItem.action == #selector(cherryPickSeveral) || menuItem.action == #selector(editMessages) {
            return selectedSeveral.count >= 2
        }
        if menuItem.action == #selector(replaceInMessages) { return hasRepo }
        if menuItem.action == #selector(savePatches) { return selectedCommit != nil || selectedSeveral.count >= 2 }
        if menuItem.action == #selector(copyHash) { return selectedCommit != nil || selectedSeveral.count >= 2 }
        return selectedCommit != nil
    }
}

// MARK: - Table

extension GitHistoryView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard hasRepo else { return 0 }
        return offset + commits.count + (hasMore ? 1 : 0)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let id = tableColumn?.identifier.rawValue else { return nil }
        let index = row - offset
        let isWorkingCopy = row == 0 && !searching
        if id == "graph" {
            let cell = (tableView.makeView(withIdentifier: .init("GitGraphCell"), owner: self) as? GitGraphCell)
                ?? GitGraphCell()
            cell.identifier = .init("GitGraphCell")
            if isWorkingCopy {
                cell.configure(node: headLane(), lines: [], workingCopy: true, isHead: false, isMerge: false)
            } else if commits.indices.contains(index) {
                let isHead = commits[index].refs.contains { $0.kind == .head }
                cell.configure(node: drawn[index].node, lines: drawn[index].lines, workingCopy: false,
                               isHead: isHead, isMerge: commits[index].isMerge,
                               isStash: PluginGit.isStash(commits[index]))
            } else {
                cell.configure(node: nil, lines: [], workingCopy: false, isHead: false, isMerge: false)
            }
            return cell
        }
        let field = (tableView.makeView(withIdentifier: .init("GitHistoryText"), owner: self) as? NSTextField)
            ?? {
                let f = NSTextField(labelWithString: "")
                f.identifier = .init("GitHistoryText")
                f.usesSingleLineMode = true
                f.lineBreakMode = .byTruncatingTail
                f.cell?.truncatesLastVisibleLine = true
                return f
            }()
        field.font = .systemFont(ofSize: 11)
        field.textColor = theme.text
        field.toolTip = nil
        if isWorkingCopy {
            field.attributedStringValue = NSAttributedString(string: "")
            if id == "subject" {
                field.font = .systemFont(ofSize: 11, weight: .semibold)
                field.stringValue = changeCount == 0
                    ? L("Working tree clean.")
                    : String(format: L("Local changes (%lld)"), changeCount)
            } else {
                field.stringValue = ""
            }
            return field
        }
        guard commits.indices.contains(index) else {
            field.stringValue = id == "subject" ? L("Load more") + " …" : ""
            field.textColor = theme.accent
            return field
        }
        let commit = commits[index]
        switch id {
        case "subject":
            field.attributedStringValue = subjectText(commit)
            field.toolTip = commit.subject
        case "author":
            field.attributedStringValue = gitAuthorText(commit.author, color: theme.secondaryText)
        case "hash":
            field.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            field.stringValue = commit.shortHash
            field.textColor = theme.secondaryText
        case "date":
            field.stringValue = gitDisplayDate(commit.date)
            field.toolTip = gitDateFormatter.string(from: commit.date)
            field.textColor = theme.secondaryText
        default:
            field.stringValue = ""
        }
        return field
    }

    func tableViewColumnDidResize(_ notification: Notification) {
        gitAdoptDraggedWidths(table, preferred: &preferredWidth)
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !updating else { return }
        onSelectionChange?(selection)
    }

    /// The lane HEAD's commit sits in, so the working copy's node is drawn above its own branch.
    private func headLane() -> Int {
        guard let index = commits.firstIndex(where: { $0.refs.contains { $0.kind == .head } }) else { return 0 }
        return drawn[index].node
    }

    /// Ref badges first — branch, remote, tag, stash — then the subject.
    private func subjectText(_ commit: PluginGit.Commit) -> NSAttributedString {
        let out = NSMutableAttributedString()
        for ref in commit.refs where !ref.name.hasSuffix("/HEAD") {
            let color: NSColor
            switch ref.kind {
            case .head:   color = theme.accent
            case .branch: color = .systemGreen
            case .remote: color = .systemBlue
            case .tag:    color = .systemOrange
            case .stash:  color = .systemPurple
            }
            out.append(NSAttributedString(string: " \(ref.kind == .tag ? "⚑ " : "")\(ref.name) ", attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: ref.kind == .head ? .bold : .medium),
                .foregroundColor: color,
                .backgroundColor: color.withAlphaComponent(0.15),
            ]))
            out.append(NSAttributedString(string: " ", attributes: [.font: NSFont.systemFont(ofSize: 11)]))
        }
        out.append(NSAttributedString(string: commit.subject, attributes: [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: theme.text,
        ]))
        return out
    }
}

// MARK: - The graph cell

/// One row of the graph: the strokes `PluginGit.graphLines` computed, and the node.
@MainActor
final class GitGraphCell: NSView {
    static let laneWidth: CGFloat = 12
    static func width(lanes: Int) -> CGFloat { CGFloat(lanes) * laneWidth + 8 }

    /// Lane colours. System colours, so they hold in a dark palette as well as a light one.
    static let palette: [NSColor] = [.systemBlue, .systemOrange, .systemGreen, .systemPurple,
                                     .systemPink, .systemTeal, .systemYellow, .systemRed]

    private var node: Int?
    private var lines: [PluginGit.GraphLine] = []
    private var workingCopy = false
    private var isHead = false
    private var isMerge = false
    private var isStash = false

    func configure(node: Int?, lines: [PluginGit.GraphLine], workingCopy: Bool, isHead: Bool, isMerge: Bool,
                   isStash: Bool = false) {
        self.node = node; self.lines = lines
        self.workingCopy = workingCopy; self.isHead = isHead; self.isMerge = isMerge; self.isStash = isStash
        needsDisplay = true
    }

    override var isFlipped: Bool { true }

    private func x(_ lane: Int) -> CGFloat { 4 + CGFloat(lane) * Self.laneWidth + Self.laneWidth / 2 }
    private func color(_ lane: Int) -> NSColor { Self.palette[lane % Self.palette.count] }

    override func draw(_ dirtyRect: NSRect) {
        // Clipped explicitly: built against the macOS 14 SDK a view no longer clips its drawing to its
        // bounds, and lanes past the column's ten would be stroked across the subject beside it.
        NSBezierPath(rect: bounds).setClip()
        let top = bounds.minY, mid = bounds.midY, bottom = bounds.maxY
        for line in lines {
            let path = NSBezierPath()
            path.lineWidth = 1.6
            let (y0, y1) = line.upper ? (top, mid) : (mid, bottom)
            let start = NSPoint(x: x(line.from), y: y0), end = NSPoint(x: x(line.to), y: y1)
            path.move(to: start)
            if line.from == line.to {
                path.line(to: end)
            } else {
                // A lane change bends: vertical at both ends, so it meets the straight strokes cleanly.
                let half = (y1 - y0) / 2
                path.curve(to: end, controlPoint1: NSPoint(x: start.x, y: y0 + half),
                           controlPoint2: NSPoint(x: end.x, y: y1 - half))
            }
            color(line.color).setStroke()
            path.stroke()
        }
        guard let node else { return }
        let radius: CGFloat = isHead ? 4.5 : 3.5
        let dot = NSRect(x: x(node) - radius, y: mid - radius, width: radius * 2, height: radius * 2)
        let circle = NSBezierPath(ovalIn: dot)
        if workingCopy {
            // The working copy is not a commit yet: an open, dashed ring.
            circle.lineWidth = 1.4
            circle.setLineDash([2, 1.5], count: 2, phase: 0)
            color(node).setStroke()
            circle.stroke()
            return
        }
        if isStash {
            // A stash is not part of the history: a small open square on the commit it was made on.
            let square = NSBezierPath(rect: dot.insetBy(dx: 0.5, dy: 0.5))
            square.lineWidth = 1.4
            NSColor.systemPurple.setStroke()
            square.stroke()
            return
        }
        if isMerge {
            NSColor.textBackgroundColor.setFill()
            circle.fill()
            circle.lineWidth = 1.6
            color(node).setStroke()
            circle.stroke()
        } else {
            color(node).setFill()
            circle.fill()
        }
        // HEAD wears a ring whatever kind of commit it is — a merge is often exactly where HEAD is.
        if isHead {
            let ring = NSBezierPath(ovalIn: dot.insetBy(dx: -2, dy: -2))
            ring.lineWidth = 1
            color(node).setStroke()
            ring.stroke()
        }
    }
}
