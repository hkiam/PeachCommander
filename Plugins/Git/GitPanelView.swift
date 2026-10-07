// SPDX-License-Identifier: Apache-2.0
// GitPanelView.swift — the Git panel: what changed, what is staged, and one place to act on it.
//
// Phase 1 of docs/analysis/git-plugin-plan.md (F-416). The first pass reported a repository's state as
// git's stdout inside an NSAlert, truncated at forty files — a text you cannot select a file in, open,
// stage or diff. That is the difference between this plugin and TortoiseGit or GitFinder, and it is a UI
// question rather than a git one.
//
// What it is: a plugin view (PcMakeView) for the sidebar or the bottom dock, following the active panel
// through PcNotifyView("dir"). An outline with four sections — Conflicts, Staged, Changed, Untracked —
// each file selectable, with Stage / Unstage / Discard, a commit box that commits **the index**, and
// Enter (or double-click) opening the file in the host's own compare window against the right side:
// HEAD for a staged file, the index for a changed one. It brings no diff view of its own; the host
// already has one, and a second implementation in the same application would be a second set of defects.
//
// Everything that decides something — the grouping, which base a diff has, what the temp blob is called —
// lives in Plugins/SDK/PluginGit.swift and is unit-tested. This file is the AppKit around it.

import AppKit

@MainActor
final class GitPanelView: NSView {
    /// Where the panel is looking; set by the host through PcNotifyView("dir").
    private var directory: String = ""
    private var root: String?
    /// The host's palette, re-read when it changes (F-431).
    private var theme: PluginTheme
    private var status: PluginGit.RepoStatus?
    private var groups: [(section: PluginGit.Section, files: [PluginGit.FileStatus])] = []

    private let header = NSTextField(labelWithString: "")
    private let outline = GitOutline()
    private let scroll = NSScrollView()
    /// A combo box: its list holds the reader's recent commit messages (phase 7), to reuse or edit.
    private let messageField = NSComboBox()
    private let commitButton = NSButton()
    private let amendCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let stageButton = NSButton()
    private let unstageButton = NSButton()
    private let discardButton = NSButton()
    private let refreshButton = NSButton()
    private let pullButton = NSButton()
    private let fetchButton = NSButton()
    private let pushButton = NSButton()
    /// The repositories this panel showed lately, newest first — a pull-down beside the header (phase 7).
    private let recentButton = NSPopUpButton(frame: .zero, pullsDown: true)
    private static let recentKey = "PCGitRecentRepositories"
    /// Counted: the panel's reload, the Changes tab and the commit actions all share it.
    private let busy = GitBusyIndicator()

    // Phase 6: the history and what is shown for its selection.
    private let mainSplit = NSSplitView()
    private var history: GitHistoryView!
    private var commitDetail: GitCommitDetailView!
    private var changes: GitChangesView!
    private let workingCopyPane = NSStackView()
    private let workingSplit = NSSplitView()
    private var workingDiff: GitDiffView!
    /// The file whose diff `workingDiff` shows, and from which side of the index.
    private var workingDiffFile: (path: String, section: PluginGit.Section)?
    private var workingDiffToken = 0
    private let commitPane = NSStackView()
    private let detailTabs = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)
    private var commits: [PluginGit.Commit] = []
    private var limit = GitPanelView.pageSize
    /// The repository whose recent commit messages the commit box lists, and whether a commit since has
    /// made them out of date.
    private var messagesRoot: String?
    private var messagesStale = false
    /// Whether the history (or search) has more than is loaded — what "Load more" offers.
    private var hasMoreCommits = false
    /// The search the listed commits came from; empty for the plain history.
    private var activeQuery = ""
    /// Stops the git processes of the read in progress when a newer one starts.
    private var searchCancel: GitCancellation?
    /// The read in progress reads the history (see `reload`).
    private var historyInFlight = false
    /// Bumped by every reload; a result from an older one is dropped. Without it a slow `log` of the
    /// repository the cursor just left could land after the new one's and put the old repository back.
    private var generation = 0
    private var showingWorkingCopy = true
    private static let pageSize = 300

    /// Host services, copied — the host's is a stack value and must not be kept by pointer.
    private let services: PcHostServices

    init(services: PcHostServices) {
        self.services = services
        self.theme = PluginTheme(services)
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 360))
        build()
        updateRecentMenu()
        // Verification only (see `applyAutomationProbe`): a search typed before the first load, so the
        // first load is already the search.
        if let query = Self.probe("PC_GIT_PANEL_SEARCH") { history.setSearchText(query) }
        if Self.probe("PC_GIT_PANEL_SCOPE") == "current" { history.setOnlyCurrentBranch(true) }
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Host notifications

    /// The active panel moved, or the theme changed.
    func notify(key: String, value: String) {
        switch key {
        case "dir", "cursorPath", "sidebarViewRoot":
            let directory = key == "cursorPath" ? (value as NSString).deletingLastPathComponent : value
            // While a file panel moves because this panel asked it to, its notifications are noted, not
            // followed (see `reveal`).
            if Date() < quietUntil {
                quietDirectory = directory
                // The folder the file panel was sent to has arrived — by the panel's own folder, not by
                // its cursor: measured, the host reports the new cursor first and then the *old* folder
                // once more from its cache, so ending at the cursor let that stale folder reload the panel.
                if key == "dir", directory == revealTarget {
                    quietUntil = .distantPast
                    settleAfterReveal()
                }
                return
            }
            guard directory != self.directory else { return }
            self.directory = directory
            // A folder change inside the same repository does not move its history: the status is
            // re-read, the log (and how far "Load more" went) is kept.
            reload(history: false)
        case "theme":
            applyTheme()
        default:
            break
        }
    }

    // MARK: - Building

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false
        header.font = .systemFont(ofSize: 12, weight: .semibold)
        header.lineBreakMode = .byTruncatingTail
        header.maximumNumberOfLines = 1

        // Each button carries a symbol as well as its title: in the sidebar the row is too narrow for seven
        // titles — "Stag…", "Unst…" was all it showed — and `layout()` then drops the titles, keeping the
        // symbol and, as the tooltip, the title.
        for (button, title, symbol, action) in [
            (stageButton, L("Stage"), "plus.circle", #selector(stageSelected)),
            (unstageButton, L("Unstage"), "minus.circle", #selector(unstageSelected)),
            (discardButton, L("Discard…"), "arrow.uturn.backward.circle", #selector(discardSelected)),
            (fetchButton, L("Fetch"), "arrow.triangle.2.circlepath", #selector(fetch)),
            (pullButton, L("Pull"), "arrow.down.circle", #selector(pull)),
            (pushButton, L("Push"), "arrow.up.circle", #selector(push)),
            (refreshButton, L("Refresh"), "arrow.clockwise", #selector(refreshNow)),
        ] as [(NSButton, String, String, Selector)] {
            button.title = title
            button.toolTip = title
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            button.imagePosition = .imageLeading
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.font = .systemFont(ofSize: 11)
            button.target = self
            button.action = action
        }
        amendCheckbox.title = L("Amend")
        amendCheckbox.controlSize = .small
        amendCheckbox.font = .systemFont(ofSize: 11)

        let buttons = NSStackView(views: [stageButton, unstageButton, discardButton,
                                         fetchButton, pullButton, pushButton, refreshButton])
        buttons.orientation = .horizontal
        buttons.spacing = 4
        buttons.distribution = .fillEqually
        // The split view below takes the panel's height, not this row: equal hugging let AppKit hand a
        // quarter of the panel to a row of buttons.
        buttons.setHuggingPriority(.defaultHigh, for: .vertical)

        outline.headerView = nil
        outline.rowHeight = 18
        outline.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        outline.dataSource = self
        outline.delegate = self
        outline.target = self
        outline.doubleAction = #selector(diffSelected)
        outline.onEnter = { [weak self] in self?.diffSelected() }
        // The actions this list has, on the right button — where a file manager's reader looks first (F-424).
        outline.menu = gitMenu([
            (L("Show changes"), #selector(diffSelected)),
            (nil, nil),
            (L("Stage"), #selector(stageSelected)),
            (L("Unstage"), #selector(unstageSelected)),
            (L("Discard…"), #selector(discardSelected)),
            (nil, nil),
            (L("Show in the left panel"), #selector(revealLeftFromList)),
            (L("Show in the right panel"), #selector(revealRightFromList)),
            (nil, nil),
            (L("Copy file path"), #selector(copyFilePath)),
            (L("Reload"), #selector(refreshNow)),
        ], target: self)
        outline.allowsMultipleSelection = true
        outline.addTableColumn(NSTableColumn(identifier: .init("file")))
        outline.outlineTableColumn = outline.tableColumns.first
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        messageField.placeholderString = L("Commit message")
        messageField.font = .systemFont(ofSize: 11)
        messageField.controlSize = .small
        messageField.completes = false          // a list to pick from, not a text that finishes itself
        messageField.numberOfVisibleItems = 12
        commitButton.title = L("Commit")
        commitButton.bezelStyle = .rounded
        commitButton.controlSize = .small
        commitButton.font = .systemFont(ofSize: 11)
        commitButton.target = self
        commitButton.action = #selector(commit)
        busy.style = .spinning
        busy.controlSize = .small
        busy.isDisplayedWhenStopped = false

        let commitRow = NSStackView(views: [messageField, amendCheckbox, commitButton])
        commitRow.orientation = .horizontal
        commitRow.spacing = 6
        messageField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // The working copy: the staging list and the commit box, shown when the history's first row —
        // "Local changes" — is selected (phase 6).
        // Below the list, the selected file's diff (phase 7), whose lines can be staged, unstaged and
        // discarded one by one or a hunk at a time.
        workingDiff = GitDiffView(theme: theme)
        workingDiff.lineMenu = gitMenu([
            (L("Stage selected lines"), #selector(stageLines)),
            (L("Stage hunk"), #selector(stageHunk)),
            (L("Unstage selected lines"), #selector(unstageLines)),
            (L("Unstage hunk"), #selector(unstageHunk)),
            (nil, nil),
            (L("Discard selected lines…"), #selector(discardLines)),
            (L("Discard hunk…"), #selector(discardHunk)),
        ], target: self)
        workingSplit.isVertical = false
        workingSplit.dividerStyle = .thin
        workingSplit.addArrangedSubview(scroll)
        workingSplit.addArrangedSubview(workingDiff)
        let listShare = scroll.heightAnchor.constraint(equalTo: workingSplit.heightAnchor, multiplier: 0.45)
        listShare.priority = .init(500)
        listShare.isActive = true
        workingSplit.setContentHuggingPriority(.init(200), for: .vertical)

        workingCopyPane.setViews([workingSplit, commitRow], in: .top)
        workingCopyPane.orientation = .vertical
        workingCopyPane.alignment = .width
        workingCopyPane.distribution = .fill
        workingCopyPane.spacing = 6
        for child in [workingSplit, commitRow] as [NSView] {
            child.widthAnchor.constraint(equalTo: workingCopyPane.widthAnchor).isActive = true
        }

        // A commit: its details or its changes, one at a time.
        history = GitHistoryView(services: services, busy: busy)
        commitDetail = GitCommitDetailView(theme: theme)
        changes = GitChangesView(services: services, busy: busy)
        changes.onReveal = { [weak self] path, side in self?.reveal(path, side: side) }
        detailTabs.segmentCount = 2
        detailTabs.setLabel(L("Commit"), forSegment: 0)
        detailTabs.setLabel(L("Changes"), forSegment: 1)
        detailTabs.selectedSegment = 1
        detailTabs.controlSize = .small
        detailTabs.font = .systemFont(ofSize: 11)
        detailTabs.target = self
        detailTabs.action = #selector(detailTabChanged)
        commitPane.setViews([detailTabs, commitDetail, changes], in: .top)
        commitPane.orientation = .vertical
        commitPane.alignment = .centerX
        commitPane.distribution = .fill          // the tab's content takes the height, see `stack` below
        commitPane.spacing = 4
        detailTabs.setContentHuggingPriority(.defaultHigh, for: .vertical)
        commitDetail.setContentHuggingPriority(.init(200), for: .vertical)
        changes.setContentHuggingPriority(.init(200), for: .vertical)
        for child in [commitDetail, changes] as [NSView] {
            child.widthAnchor.constraint(equalTo: commitPane.widthAnchor).isActive = true
        }
        commitDetail.isHidden = true
        commitDetail.onSelectCommit = { [weak self] hash in self?.history.select(hash: hash) }
        commitPane.isHidden = true

        let detail = NSStackView(views: [workingCopyPane, commitPane])
        detail.orientation = .vertical
        detail.alignment = .width
        detail.distribution = .fill
        for child in [workingCopyPane, commitPane] as [NSView] {
            child.widthAnchor.constraint(equalTo: detail.widthAnchor).isActive = true
        }
        history.onSelectionChange = { [weak self] selection in self?.show(selection) }
        history.onLoadMore = { [weak self] in
            guard let self else { return }
            self.limit += Self.pageSize
            self.reload(status: false)
        }
        history.onChanged = { [weak self] in self?.refreshNow() }
        history.onScopeChange = { [weak self] in self?.reload() }
        history.onSearch = { [weak self] in
            guard let self else { return }
            self.limit = Self.pageSize          // a new search starts from its first page
            self.reload(status: false)
        }
        mainSplit.isVertical = false
        mainSplit.dividerStyle = .thin
        mainSplit.addArrangedSubview(history)
        mainSplit.addArrangedSubview(detail)
        mainSplit.translatesAutoresizingMaskIntoConstraints = false
        mainSplit.setContentHuggingPriority(.init(200), for: .vertical)

        // The spinner beside the header, where it is on screen whatever the detail area shows — in the
        // commit row it was hidden whenever a commit rather than the working copy was selected.
        recentButton.bezelStyle = .texturedRounded
        recentButton.isBordered = false
        recentButton.controlSize = .small
        recentButton.toolTip = L("Recent repositories")
        (recentButton.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
        // Its items are enabled by hand — a repository that is gone (deleted, on an unmounted volume)
        // stays listed but cannot be picked — so the menu must not enable them itself.
        recentButton.menu?.autoenablesItems = false
        let headerRow = NSStackView(views: [header, busy, recentButton])
        headerRow.orientation = .horizontal
        headerRow.spacing = 6
        headerRow.setHuggingPriority(.defaultHigh, for: .vertical)      // as the buttons, see there
        header.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [headerRow, buttons, mainSplit])
        stack.orientation = .vertical
        stack.alignment = .width
        // `.fill`, not the default gravity areas: those leave the leftover height empty below the split
        // view instead of giving it to the view that hugs least.
        stack.distribution = .fill
        // Same as the log window: `.width` alone does not stretch a scroll or split view inside a stack,
        // so the ones that should fill the window say so (F-419).
        for child in [headerRow, buttons, mainSplit] as [NSView] {
            child.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -16).isActive = true
        }
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setHuggingPriority(.defaultLow, for: .vertical)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        // Preferences, not rules: a container may legitimately be zero-sized while hidden, and a required
        // height against a collapsed dock is an Auto Layout conflict (CONVENTIONS.md). The history takes
        // two fifths of the split, the detail the rest; the divider still drags.
        let historyShare = history.heightAnchor.constraint(equalTo: mainSplit.heightAnchor, multiplier: 0.4)
        historyShare.priority = .init(500)
        let historyMinimum = history.heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        historyMinimum.priority = .init(999)
        let detailMinimum = detail.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        detailMinimum.priority = .init(999)
        let fill = mainSplit.heightAnchor.constraint(greaterThanOrEqualTo: heightAnchor, multiplier: 0.6)
        fill.priority = .init(999)
        NSLayoutConstraint.activate([historyShare, historyMinimum, detailMinimum, fill])
        mainSplit.setHoldingPriority(.init(260), forSubviewAt: 0)
        applyTheme()
    }

    /// Colours come from the host, so the panel matches whichever palette is active.
    ///
    /// Through `PluginTheme`, which reads the keys the host actually publishes. The first version asked for
    /// `theme.listBackground` and `theme.listText` — names that do not exist (the host's raw vocabulary is
    /// `theme.color.<name>`, the semantic one `theme.background`), so every call failed and the fallback
    /// `.controlBackgroundColor` painted the panel **white in every dark palette**, with the labels' own
    /// `theme.text` turning white on top of it. Found by the surface-colour audit, which had been
    /// reporting `GitPanelView bg=#FFFFFF luminance=1.00` all along (F-431).
    func applyTheme() {
        theme = PluginTheme(services)
        wantsLayer = true
        layer?.backgroundColor = theme.windowBackground.cgColor
        header.textColor = theme.text
        outline.backgroundColor = theme.background
        scroll.backgroundColor = theme.background
        scroll.drawsBackground = true
        // A text field keeps its own background: unthemed, it is a white bar under a dark theme.
        messageField.backgroundColor = theme.background
        messageField.textColor = theme.text
        messageField.drawsBackground = true
        amendCheckbox.contentTintColor = theme.text
        outline.reloadData()
        history?.applyTheme(theme)
        commitDetail?.applyTheme(theme)
        workingDiff?.applyTheme(theme)
        changes?.applyTheme(theme)
    }

    // MARK: - Loading

    @objc private func refreshNow() { PluginGitRepo.invalidate(); reload() }

    /// Below this width the buttons show their symbols only, with the title as the tooltip.
    private static let titledButtonsWidth: CGFloat = 520

    override func layout() {
        super.layout()
        let position: NSControl.ImagePosition = bounds.width < Self.titledButtonsWidth ? .imageOnly : .imageLeading
        for button in [stageButton, unstageButton, discardButton, fetchButton, pullButton, pushButton, refreshButton]
        where button.imagePosition != position {
            button.imagePosition = position
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "r" {
            refreshNow()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Sync where the commit is made. Routed back through the host by command id rather than run here:
    /// those two commands are declared asynchronous (F-422), so this way they keep the progress window and
    /// the Cancel button instead of becoming a second, silent implementation inside the panel (F-424).
    @objc private func fetch() { invoke("plugin.git.fetch") }
    @objc private func pull() { invoke("plugin.git.pull") }
    @objc private func push() { invoke("plugin.git.push") }

    private func invoke(_ commandId: String) {
        commandId.withCString { services.invokeCommand?(services.host, $0) }
    }

    // MARK: - Recent repositories

    private func remember(_ root: String) {
        let list = UserDefaults.standard.stringArray(forKey: Self.recentKey) ?? []
        UserDefaults.standard.set(PluginGit.recentRepositories(list, opening: root), forKey: Self.recentKey)
        updateRecentMenu()
    }

    /// A pull-down's first item is its face: here the clock symbol. The others are the repositories, by
    /// folder name, with the path as the tooltip; picking one takes the active file panel there.
    private func updateRecentMenu() {
        recentButton.removeAllItems()
        recentButton.addItem(withTitle: "")
        recentButton.item(at: 0)?.image = NSImage(systemSymbolName: "clock.arrow.circlepath",
                                                  accessibilityDescription: L("Recent repositories"))
        for path in UserDefaults.standard.stringArray(forKey: Self.recentKey) ?? [] {
            let item = NSMenuItem(title: (path as NSString).lastPathComponent, action: #selector(openRecent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = path
            item.toolTip = path
            item.isEnabled = FileManager.default.fileExists(atPath: path)
            recentButton.menu?.addItem(item)
        }
        recentButton.isHidden = recentButton.numberOfItems <= 1
    }

    @objc private func openRecent(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        path.withCString { services.openPath?(services.host, $0) }
    }

    // MARK: - Showing a file in a file panel

    /// Until then, folder notifications are held (see `reveal`).
    private var quietUntil = Date.distantPast
    /// The last folder a held notification named.
    private var quietDirectory: String?
    /// The folder `reveal` sent a file panel to.
    private var revealTarget: String?
    /// Counted for the verification dump: how often the panel read the repository, and revealed a file.
    private var reloadCount = 0
    private var revealCount = 0

    @objc private func revealLeftFromList() { revealSelectedFromList(side: 0) }
    @objc private func revealRightFromList() { revealSelectedFromList(side: 1) }

    private func revealSelectedFromList(side: Int) {
        guard let root, let first = selectedFiles().first else { return }
        let path = (root as NSString).appendingPathComponent(first.file.path)
        guard FileManager.default.fileExists(atPath: path) else { return }
        reveal(path, side: side)
    }

    /// Navigate a file panel to `path` and select it there — without this panel moving at all.
    ///
    /// The host makes the chosen file panel the active one *before* it navigates, so this panel would be
    /// told first about whatever folder that panel was showing — another repository or none — and then
    /// about the new one: it would show "Not a Git repository", come back, and lose the selected commit
    /// and the open tab on the way. So the notifications are only noted until the file panel reports the
    /// folder it was sent to — on a slow volume that can take a while, so the wait is ended by its arrival,
    /// not by a timer; the timer is only the upper bound for a navigation that never arrives. Then that
    /// folder is checked, and only a different repository reloads anything.
    func reveal(_ path: String, side: Int) {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        revealTarget = isDirectory.boolValue ? path : (path as NSString).deletingLastPathComponent
        quietUntil = Date().addingTimeInterval(Self.revealQuietTime)
        quietDirectory = nil
        revealCount += 1
        path.withCString { services.openPathInPanel?(services.host, Int32(side), $0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealQuietTime + 0.1) { [weak self] in
            self?.settleAfterReveal()
        }
    }

    private static let revealQuietTime: TimeInterval = 5

    private func settleAfterReveal() {
        guard Date() >= quietUntil, let directory = quietDirectory else { return }
        quietDirectory = nil
        guard directory != self.directory else { return }
        // Taken over at once: the notifications that follow name the same folder and must find it already
        // here, or each of them would reload (measured: one extra reload when this waited for the lookup).
        self.directory = directory
        let currentRoot = root
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let located = PluginGitRepo.locate(directory)
            DispatchQueue.main.async {
                // The same repository: nothing on screen changes.
                if located?.root != currentRoot { self?.reload(history: false) }
            }
        }
    }

    /// The full path, not the repository-relative one: it is copied to be pasted somewhere else, and
    /// "src/app.swift" means nothing outside this repository.
    @objc private func copyFilePath() {
        guard let root, let first = selectedFiles().first else { return }
        gitCopyToClipboard((root as NSString).appendingPathComponent(first.file.path))
    }

    /// Re-read the repository off the main thread and rebuild the list on it.
    ///
    /// `history: false` keeps the loaded log when the repository is the same one — a folder change inside
    /// it. Another repository always gets its history read, from the first page. `status: false` reads
    /// the history alone: a search, or "Load more", has no reason to re-read the working tree and rebuild
    /// the staging list (which also re-expanded every group the reader had collapsed).
    private func reload(history requested: Bool = true, status readStatus: Bool = true) {
        // A read in progress is superseded by this one, so if it was reading the history — a search, "Load
        // more" — this one has to as well, or its result would be dropped and the old list kept beside the
        // new search text.
        reloadCount += 1
        let history = requested || historyInFlight
        historyInFlight = history
        let directory = self.directory.isEmpty ? hostDirectory() : self.directory
        self.directory = directory
        busy.startAnimation(nil)
        generation += 1
        let generation = self.generation
        let previousRoot = root, kept = self.commits, keptHasMore = self.hasMoreCommits
        let pageLimit = self.limit, firstPage = Self.pageSize, all = !self.history.onlyCurrentBranch
        let messagesRoot = self.messagesRoot, messagesStale = self.messagesStale
        // The search the list will show: a fresh read takes what the field says now; kept commits keep
        // the search they came from, whatever has been typed since without being applied yet.
        let query = history ? self.history.searchText : activeQuery
        // A newer read makes the previous search pointless; its git processes are stopped, not waited for.
        searchCancel?.cancel()
        let cancel = GitCancellation()
        searchCancel = cancel
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let located = PluginGitRepo.locate(directory)
            let sameRepo = located?.root == previousRoot
            let limit = sameRepo ? pageLimit : firstPage
            // Status, log and the search's calls are independent, so they run side by side.
            let found = PanelLoad()
            let group = DispatchGroup()
            if let located {
                let root = located.root
                if readStatus {
                    DispatchQueue.global(qos: .userInitiated).async(group: group) {
                        found.set { $0.status = PluginGitRepo.status(root: root) }
                    }
                    // The commit box's list changes only with a commit or another repository, so it is not
                    // re-read on every refresh — `log --branches` on a large repository is not free.
                    if root != messagesRoot || messagesStale {
                    DispatchQueue.global(qos: .utility).async(group: group) {
                        let email = PluginGitRepo.run(["-C", root, "config", "user.email"]).out
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let output = PluginGitRepo.run(["-C", root] + PluginGit.recentMessagesArguments(author: email)).out
                        let messages = PluginGit.recentMessages(output)
                        found.set { $0.recentMessages = messages }
                    }
                    }
                }
                if !(history || !sameRepo) {
                    found.set { $0.commits = kept; $0.hasMore = keptHasMore }
                } else if query.isEmpty {
                    // Stashes beside the log (phase 7), placed above the commit each was made on.
                    DispatchQueue.global(qos: .userInitiated).async(group: group) {
                        let stashes = PluginGit.stashCommits(PluginGitRepo.run(["-C", root] + PluginGit.stashCommitsArguments).out)
                        found.set { $0.stashes = stashes }
                    }
                    let output = PluginGitRepo.run(["-C", root] + PluginGit.logArguments(limit: limit, all: all)).out
                    let commits = PluginGit.parseLog(output)
                    found.set { $0.commits = commits; $0.hasMore = commits.count >= limit }
                } else {
                    Self.search(query, root: root, limit: limit, all: all, cancel: cancel, group: group, into: found)
                }
            }
            group.wait()
            if query.isEmpty, history || !sameRepo {
                found.set { $0.commits = PluginGit.historyWithStashes($0.commits, stashes: $0.stashes) }
            }
            if !query.isEmpty, history || !sameRepo {
                found.set { load in
                    let merged = PluginGit.mergeSearchResults(load.fields, extra: load.extra, limit: limit)
                    load.commits = merged.commits
                    load.hasMore = merged.hasMore
                }
            }
            let result = found.snapshot()
            DispatchQueue.main.async {
                self?.busy.stopAnimation(nil)
                guard let self, self.generation == generation, !cancel.isCancelled else { return }
                self.historyInFlight = false
                self.limit = limit
                self.root = located?.root
                if readStatus {
                    if let messages = result.recentMessages {
                        self.messageField.removeAllItems()
                        self.messageField.addItems(withObjectValues: messages)
                        self.messagesRoot = located?.root
                        self.messagesStale = false
                    }
                    self.status = result.status
                    self.groups = result.status.map { PluginGit.grouped($0) } ?? []
                    let keep = self.selectedFiles().map { ($0.file.path, $0.section) }
                    self.outline.reloadData()
                    self.outline.expandItem(nil, expandChildren: true)
                    // The rows are new objects after a reload: select the same files again, in the same
                    // section if they are still there — after staging a line the file is still the one
                    // being worked on.
                    self.reselect(keep)
                    // Also when the selection came back unchanged — no selection change is posted then,
                    // and the diff would still show the lines just staged as unstaged.
                    self.loadWorkingDiff()
                }
                self.commits = result.commits
                self.hasMoreCommits = result.hasMore
                self.activeQuery = query
                if let root = located?.root, root != previousRoot { self.remember(root) }
                self.history.root = located?.root
                self.history.update(commits: result.commits, hasRepo: located != nil,
                                    changeCount: self.changeCount, hasMore: result.hasMore,
                                    searching: !query.isEmpty)
                self.updateHeader()
                self.updateButtons()
                self.applyAutomationProbe()
            }
        }
    }

    /// One search: the message and author calls and, for a hash-like text, the hash call, all at once.
    /// The hash call's commit is kept only when the history being searched contains it.
    private nonisolated static func search(_ query: String, root: String, limit: Int, all: Bool,
                                           cancel: GitCancellation, group: DispatchGroup, into found: PanelLoad) {
        let environment = PluginGit.searchEnvironment
        let calls = PluginGit.searchArguments(query, limit: limit, all: all)
        found.set { $0.fields = Array(repeating: [], count: calls.count) }
        for (index, call) in calls.enumerated() {
            DispatchQueue.global(qos: .userInitiated).async(group: group) {
                let output = PluginGitRepo.run(["-C", root] + call, environment: environment, cancel: cancel).out
                let commits = PluginGit.parseLog(output)
                found.set { $0.fields[index] = commits }
            }
        }
        if let call = PluginGit.hashSearchArguments(query) {
            DispatchQueue.global(qos: .userInitiated).async(group: group) {
                let commits = PluginGit.parseLog(PluginGitRepo.run(["-C", root] + call, cancel: cancel).out)
                let reachable = commits.filter { commit in
                    let check = PluginGitRepo.run(["-C", root] + PluginGit.reachabilityArguments(commit.hash, all: all),
                                                  cancel: cancel)
                    return all ? !check.out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : check.ok
                }
                found.set { $0.extra = reachable }
            }
        }
    }

    private func hostDirectory() -> String {
        var buffer = [CChar](repeating: 0, count: 4096)
        if let get = services.getContext, get(services.host, "dir", &buffer, 4096) != 0 {
            return String(cString: buffer)
        }
        return FileManager.default.currentDirectoryPath
    }

    private func updateHeader() {
        guard let root, let status else {
            header.stringValue = L("Not a Git repository.")
            return
        }
        let name = (root as NSString).lastPathComponent
        let branch = status.detached ? L("(detached)") : status.branch
        var text = "\(name) — \(branch)"
        if status.ahead > 0 || status.behind > 0 {
            text += String(format: "  ↑%lld ↓%lld", status.ahead, status.behind)
        }
        text += changeCount == 0
            ? "  ·  " + L("Working tree clean.")
            : "  ·  " + String(format: L("%lld change(s)"), changeCount)
        header.stringValue = text
    }

    private var changeCount: Int {
        status?.files.values.filter { !PluginGit.sections(for: $0).isEmpty }.count ?? 0
    }

    // MARK: - The detail area (phase 6)

    private var probeApplied = false

    /// Verification only: `PC_GIT_PANEL_ROW=<n>` selects history row n (0 is the working copy) and
    /// `PC_GIT_PANEL_TAB=commit|changes` picks the tab, once, after the first load — so an automation run
    /// can lay out the commit views, which no script can reach with a click. `PC_GIT_PANEL_ACTIVATE=1`
    /// then does what a double-click on that row does ("Load more" on the last row); `PC_GIT_PANEL_SEARCH`
    /// types a search before the first load, `PC_GIT_PANEL_SCOPE=current` turns on "Only the current
    /// branch". Read from the environment
    /// and from the argument domain, because the VM harness passes a scenario's variables as arguments.
    private static func probe(_ key: String) -> String? {
        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty { return value }
        let value = UserDefaults.standard.string(forKey: key)
        return (value?.isEmpty ?? true) ? nil : value
    }

    private func applyAutomationProbe() {
        guard !probeApplied, root != nil else { return }
        probeApplied = true
        let probe = Self.probe
        if let tab = probe("PC_GIT_PANEL_TAB") { detailTabs.selectedSegment = tab == "commit" ? 0 : 1 }
        if let row = probe("PC_GIT_PANEL_ROW").flatMap(Int.init) { history.selectRow(row) }
        if probe("PC_GIT_PANEL_ACTIVATE") != nil { history.activateRow() }
        // `PC_GIT_PANEL_DUMP=<file>`: what the panel shows, written once the selected commit's changes
        // have had time to load — the VM scenario's report. A layout dump alone cannot say which pane
        // is on screen or what the history lists, and both have been wrong with zero conflicts.
        // `PC_GIT_PANEL_REVEAL=left|right`: once the selected commit's changes are on screen, show its
        // first file in that file panel — and the dump, written later, says whether the panel moved.
        // `PC_GIT_PANEL_FILE=<path>` selects that file in the working copy's list, and
        // `PC_GIT_PANEL_STAGE_LINE=<text>|<text>…` then stages the changed lines with exactly those texts.
        if let path = probe("PC_GIT_PANEL_FILE") {
            // To stage lines, the file's row in Changed — a file can be in Staged as well, listed first.
            let wanted: PluginGit.Section? = probe("PC_GIT_PANEL_STAGE_LINE") != nil ? .changed : nil
            if let row = (0..<outline.numberOfRows).first(where: {
                guard let node = outline.item(atRow: $0) as? FileNode else { return false }
                return node.file.path == path && (wanted == nil || node.section == wanted)
            }) {
                outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
            if let text = probe("PC_GIT_PANEL_STAGE_LINE") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self else { return }
                    let texts = Set(text.components(separatedBy: "|"))
                    let rows = self.workingDiff.diffLines.indices.filter {
                        texts.contains(self.workingDiff.diffLines[$0].text) && self.workingDiff.diffLines[$0].kind != .context
                    }
                    self.workingDiff.selectRows(IndexSet(rows))
                    self.stageLines()
                }
            }
        }
        let reveal = probe("PC_GIT_PANEL_REVEAL")
        if let reveal {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.changes.revealFirstFile(side: reveal == "right" ? 1 : 0)
            }
        }
        if let path = probe("PC_GIT_PANEL_DUMP") {
            DispatchQueue.main.asyncAfter(deadline: .now() + (reveal == nil ? 2.5 : 5.0)) { [weak self] in
                guard let self else { return }
                try? self.automationReport().write(toFile: path, atomically: true, encoding: .utf8)
            }
        }
    }

    private func automationReport() -> String {
        layoutSubtreeIfNeeded()
        var lines = ["root=\(root.map { ($0 as NSString).lastPathComponent } ?? "<none>")"]
        switch history.selection {
        case .workingCopy?: lines.append("selection=working-copy")
        case .commit(let commit)?: lines.append("selection=\(commit.subject)")
        case nil: lines.append("selection=<none>")
        }
        lines.append("workingCopyShown=\(!workingCopyPane.isHidden)")
        lines.append("tab=\(detailTabs.selectedSegment == 0 ? "commit" : "changes")")
        lines.append("reloads=\(reloadCount) reveals=\(revealCount)")
        lines.append("recentMessages=\(messageField.numberOfItems)")
        lines.append("recentRepositories=" + (recentButton.itemArray.dropFirst().map(\.title)).joined(separator: ","))
        for group in groups { lines.append("\(group.section.rawValue)=" + group.files.map(\.path).joined(separator: ",")) }
        lines.append("workingSelection=" + selectedFiles().map { "\($0.section.rawValue):\($0.file.path)" }.joined(separator: ","))
        lines.append("workingDiffLines=\(workingDiff.diffLines.count)")
        lines += history.automationRows()
        if !commitPane.isHidden, detailTabs.selectedSegment == 1 { lines += changes.automationSummary() }
        // The three layout defects this panel has had, each as a yes/no: the split view stopping short of
        // the bottom (gravity areas), and the header or the button row swallowing height (equal hugging).
        let buttonsHeight = stageButton.superview?.frame.height ?? 0
        let headerHeight = header.superview?.frame.height ?? 0
        lines.append("splitFillsPanel=\(abs(mainSplit.frame.minY - 8) < 1.5)")
        lines.append("buttonsCompact=\(buttonsHeight > 0 && buttonsHeight <= 32)")
        lines.append("headerCompact=\(headerHeight > 0 && headerHeight <= 32)")
        lines.append("historyHeight=\(Int(history.frame.height)) detailHeight=\(Int(mainSplit.frame.height - history.frame.height))")
        return lines.joined(separator: "\n") + "\n"
    }

    /// Follow the history's selection: the working copy, or one commit's details or changes.
    private func show(_ selection: GitHistoryView.Selection?) {
        switch selection {
        case nil where history.isSearching:
            // A search with nothing selected — typically nothing found — shows neither the working copy,
            // which the search did not ask about, nor a commit.
            showingWorkingCopy = false
            workingCopyPane.isHidden = true
            commitPane.isHidden = true
        case .workingCopy?, nil:
            showingWorkingCopy = true
            workingCopyPane.isHidden = false
            commitPane.isHidden = true
        case .commit(let commit)?:
            showingWorkingCopy = false
            workingCopyPane.isHidden = true
            commitPane.isHidden = false
            showDetail(of: commit)
        }
        updateButtons()
    }

    @objc private func detailTabChanged() {
        if case .commit(let commit)? = history.selection { showDetail(of: commit) }
    }

    /// Only the visible tab loads: the Changes tab runs git twice per commit, and arrowing through the
    /// history should not pay for a tab nobody is looking at.
    private func showDetail(of commit: PluginGit.Commit) {
        guard let root else { return }
        let onChanges = detailTabs.selectedSegment == 1
        commitDetail.isHidden = onChanges
        changes.isHidden = !onChanges
        if onChanges {
            changes.show(commit: commit, root: root)
        } else {
            commitDetail.show(commit: commit, root: root)
        }
    }

    private func updateButtons() {
        let selected = selectedFiles()
        let hasRepo = root != nil
        // Staging acts on the working copy's list, which is only on screen while its row is selected.
        let staging = hasRepo && showingWorkingCopy
        stageButton.isEnabled = staging && !selected.isEmpty
        unstageButton.isEnabled = staging && selected.contains { $0.file.isStaged }
        discardButton.isEnabled = staging && !selected.isEmpty
        refreshButton.isEnabled = hasRepo
        fetchButton.isEnabled = hasRepo
        pullButton.isEnabled = hasRepo
        pushButton.isEnabled = hasRepo
        commitButton.isEnabled = hasRepo && (amendCheckbox.state == .on || anythingStaged)
        messageField.isEnabled = hasRepo
        amendCheckbox.isEnabled = hasRepo
    }

    private var anythingStaged: Bool {
        status?.files.values.contains(where: \.isStaged) ?? false
    }

    // MARK: - Selection

    private func selectedFiles() -> [(file: PluginGit.FileStatus, section: PluginGit.Section)] {
        outline.selectedRowIndexes.compactMap { row in
            guard let node = outline.item(atRow: row) as? FileNode else { return nil }
            return (node.file, node.section)
        }
    }

    // MARK: - Actions

    @objc private func stageSelected() {
        let paths = selectedFiles().map(\.file.path)
        guard let root, !paths.isEmpty else { return }
        run(["-C", root, "add", "--"] + paths)
    }

    @objc private func unstageSelected() {
        let paths = selectedFiles().filter(\.file.isStaged).map(\.file.path)
        guard let root, !paths.isEmpty else { return }
        run(["-C", root, "restore", "--staged", "--"] + paths)
    }

    /// Discarding is the one action here that destroys work, so it asks — and it says exactly what it
    /// will throw away. An untracked file is *deleted*, which is a different sentence from "discard the
    /// changes", and the reference products get this wrong often enough to be worth the distinction.
    @objc private func discardSelected() {
        let selected = selectedFiles()
        guard let root, !selected.isEmpty else { return }
        let untracked = selected.filter { $0.section == .untracked }.map(\.file.path)
        let tracked = selected.filter { $0.section != .untracked }.map(\.file.path)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("Discard changes?")
        var lines: [String] = []
        if !tracked.isEmpty {
            lines.append(String(format: L("%lld file(s) will be restored to the last committed state."),
                                tracked.count))
        }
        if !untracked.isEmpty {
            lines.append(String(format: L("%lld untracked file(s) will be deleted."), untracked.count))
        }
        lines.append(L("This cannot be undone."))
        alert.informativeText = lines.joined(separator: "\n")
        alert.addButton(withTitle: L("Discard"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        var arguments: [[String]] = []
        if !tracked.isEmpty { arguments.append(["-C", root, "restore", "--staged", "--worktree", "--"] + tracked) }
        if !untracked.isEmpty { arguments.append(["-C", root, "clean", "-f", "--"] + untracked) }
        runSequence(arguments)
    }

    @objc private func commit() {
        guard let root else { return }
        let message = messageField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let amend = amendCheckbox.state == .on
        guard !message.isEmpty || amend else {
            report(L("Git Commit"), L("Enter a commit message."))
            return
        }
        var arguments = ["-C", root, "commit"]
        if amend { arguments.append("--amend") }
        if message.isEmpty && amend {
            arguments.append("--no-edit")   // amend without a new message: keep the old one
        } else {
            arguments += ["-m", message]
        }
        messagesStale = true          // the commit about to be made joins the list of recent messages
        run(arguments) { [weak self] ok in
            guard ok else { return }
            self?.messageField.stringValue = ""
            self?.amendCheckbox.state = .off
        }
    }

    /// Open the selected file in the host's compare window, against HEAD or the index.
    @objc private func diffSelected() {
        guard let root, let selected = selectedFiles().first else { return }
        let base = PluginGit.diffBase(for: selected.file, section: selected.section)
        guard let spec = PluginGit.showSpec(base: base, path: selected.file.path) else {
            report(L("Git"), L("An untracked file has nothing to compare with."))
            return
        }
        let working = (root as NSString).appendingPathComponent(selected.file.path)
        busy.startAnimation(nil)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let blob = PluginGitRepo.writeBlob(root: root, spec: spec, path: selected.file.path, base: base)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                guard let blob else {
                    self.report(L("Git"), L("That version could not be read."))
                    return
                }
                let title = PluginGit.diffTitle(base: base, path: selected.file.path)
                blob.withCString { left in
                    working.withCString { right in
                        title.withCString { leftTitle in
                            L("Working tree").withCString { rightTitle in
                                self.services.compareFiles?(self.services.host, left, right,
                                                            leftTitle, rightTitle)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Staging lines (phase 7)

    private func reselect(_ files: [(String, PluginGit.Section)]) {
        guard !files.isEmpty else { return }
        var rows = IndexSet()
        for (path, section) in files {
            let matches = (0..<outline.numberOfRows).filter { (outline.item(atRow: $0) as? FileNode)?.file.path == path }
            if let same = matches.first(where: { (outline.item(atRow: $0) as? FileNode)?.section == section }) {
                rows.insert(same)
            } else if let other = matches.first {
                rows.insert(other)
            }
        }
        outline.selectRowIndexes(rows, byExtendingSelection: false)
    }

    /// The diff of the one selected file: the index against HEAD for a staged file, the working tree
    /// against the index for a changed one. An untracked or conflicted file has none to stage lines of.
    private func loadWorkingDiff() {
        workingDiffToken += 1
        let token = workingDiffToken
        let selected = selectedFiles()
        guard let root, selected.count == 1, let file = selected.first else {
            workingDiffFile = nil
            workingDiff.show(lines: [], truncated: false, placeholder: selected.count > 1 ? L("Several files are selected.") : "")
            return
        }
        guard file.section == .staged || file.section == .changed else {
            workingDiffFile = nil
            workingDiff.show(lines: [], truncated: false, placeholder: file.section == .untracked
                ? L("An untracked file is staged as a whole.") : L("Resolve the conflict first."))
            return
        }
        let path = file.file.path
        let arguments = ["-C", root, "--no-optional-locks", "diff", "--no-color"]
            + (file.section == .staged ? ["--cached"] : []) + ["--", path]
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let parsed = PluginGit.parseUnifiedDiff(PluginGitRepo.run(arguments).out)
            DispatchQueue.main.async {
                guard let self, self.workingDiffToken == token else { return }
                self.workingDiffFile = (path, file.section)
                self.workingDiff.show(lines: parsed.lines, truncated: parsed.truncated,
                                      placeholder: parsed.lines.isEmpty ? L("No textual changes.") : "")
            }
        }
    }

    @objc private func stageLines() { applyLines(.stage, hunk: false) }
    @objc private func stageHunk() { applyLines(.stage, hunk: true) }
    @objc private func unstageLines() { applyLines(.unstage, hunk: false) }
    @objc private func unstageHunk() { applyLines(.unstage, hunk: true) }
    @objc private func discardLines() { applyLines(.discard, hunk: false) }
    @objc private func discardHunk() { applyLines(.discard, hunk: true) }

    /// The lines the action is for: the selected change lines, or the hunk the right-click was on.
    private func chosenLines(hunk: Bool) -> Set<Int> {
        let lines = workingDiff.diffLines
        if hunk { return PluginGit.hunkLines(containing: workingDiff.clickedRow, in: lines) }
        return workingDiff.selectedRows.filter { lines.indices.contains($0) && (lines[$0].kind == .added || lines[$0].kind == .removed) }
    }

    /// Which line actions fit the diff on screen: staging and discarding a changed file's lines,
    /// unstaging a staged file's — never on a cut-off diff, whose missing part the patch could not hold.
    private func allows(_ use: PluginGit.LinePatchUse) -> Bool {
        guard let file = workingDiffFile, !workingDiff.isTruncated else { return false }
        return use == .unstage ? file.section == .staged : file.section == .changed
    }

    private func applyLines(_ use: PluginGit.LinePatchUse, hunk: Bool) {
        guard let root, let file = workingDiffFile, allows(use) else { return }
        guard let patch = PluginGit.linePatch(path: file.path, lines: workingDiff.diffLines,
                                              selected: chosenLines(hunk: hunk), use: use) else {
            report(L("Git"), L("Select the changed lines first."))
            return
        }
        if use == .discard {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = L("Discard these changes?")
            alert.informativeText = L("The selected lines go back to how they are in the index. This cannot be undone.")
            alert.addButton(withTitle: L("Discard"))
            alert.addButton(withTitle: L("Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        let patchFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("pc-git-lines-\(UUID().uuidString).patch")
        guard (try? patch.write(toFile: patchFile, atomically: true, encoding: .utf8)) != nil else {
            report(L("Git"), L("The patch could not be written."))
            return
        }
        runSequence([["-C", root] + PluginGit.applyLinePatchArguments(use, patchFile: patchFile)]) { _ in
            try? FileManager.default.removeItem(atPath: patchFile)
        }
    }

    // MARK: - Running git

    private func run(_ arguments: [String], then: ((Bool) -> Void)? = nil) {
        runSequence([arguments], then: then)
    }

    /// Run one or more git calls off the main thread, then refresh everything the result touched.
    private func runSequence(_ calls: [[String]], then: ((Bool) -> Void)? = nil) {
        guard !calls.isEmpty else { return }
        busy.startAnimation(nil)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var ok = true
            var output = ""
            for call in calls {
                let result = PluginGitRepo.run(call, combined: true)
                ok = ok && result.ok
                let text = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { output += (output.isEmpty ? "" : "\n") + text }
                if !result.ok { break }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                PluginGitRepo.invalidate()
                self.services.reloadActivePanel?(self.services.host)
                self.reload()
                then?(ok)
                if !ok || !output.isEmpty {
                    self.report(L("Git"), output.isEmpty ? L("Failed.") : output)
                }
            }
        }
    }

    private func report(_ title: String, _ message: String) {
        services.presentInfo?(services.host, title, message)
    }
}

// MARK: - Outline model

/// A section row. A class because NSOutlineView holds its items.
private final class SectionNode {
    let section: PluginGit.Section
    let files: [PluginGit.FileStatus]
    init(section: PluginGit.Section, files: [PluginGit.FileStatus]) {
        self.section = section; self.files = files
    }
}

private final class FileNode {
    let file: PluginGit.FileStatus
    let section: PluginGit.Section
    init(file: PluginGit.FileStatus, section: PluginGit.Section) { self.file = file; self.section = section }
}

extension GitPanelView: NSOutlineViewDataSource, NSOutlineViewDelegate {
    private func nodes() -> [SectionNode] {
        groups.map { SectionNode(section: $0.section, files: $0.files) }
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return groups.count }
        if let section = item as? SectionNode { return section.files.count }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            let group = groups[index]
            return SectionNode(section: group.section, files: group.files)
        }
        let section = item as! SectionNode
        return FileNode(file: section.files[index], section: section.section)
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        item is SectionNode
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?,
                     item: Any) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("GitCell")
        let field = (outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTextField)
            ?? {
                let f = NSTextField(labelWithString: "")
                f.identifier = identifier
                f.usesSingleLineMode = true
                f.lineBreakMode = .byTruncatingMiddle
                f.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
                return f
            }()
        if let section = item as? SectionNode {
            field.font = .systemFont(ofSize: 11, weight: .semibold)
            field.stringValue = "\(sectionTitle(section.section))  (\(section.files.count))"
            field.textColor = theme.secondaryText
        } else if let node = item as? FileNode {
            field.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            field.stringValue = node.file.path
            field.toolTip = node.file.originalPath.map { String(format: L("Renamed from %@"), $0) }
                ?? node.file.path
            field.textColor = node.section == .conflicts ? .systemRed : theme.text
        }
        return field
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        updateButtons()
        loadWorkingDiff()
    }

    private func sectionTitle(_ section: PluginGit.Section) -> String {
        switch section {
        case .conflicts: return L("Conflicts")
        case .staged:    return L("Staged")
        case .changed:   return L("Changed")
        case .untracked: return L("Untracked")
        }
    }
}

// MARK: - Colour parsing

private extension NSColor {
    /// "#RRGGBB" / "#RRGGBBAA" as the host reports theme colours.
    convenience init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        guard text.hasPrefix("#") else { return nil }
        text.removeFirst()
        guard text.count == 6 || text.count == 8, let value = UInt64(text, radix: 16) else { return nil }
        let shift = text.count == 8 ? 8 : 0
        let r = CGFloat((value >> (16 + shift)) & 0xFF) / 255
        let g = CGFloat((value >> (8 + shift)) & 0xFF) / 255
        let b = CGFloat((value >> shift) & 0xFF) / 255
        let a = text.count == 8 ? CGFloat(value & 0xFF) / 255 : 1
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}

/// What one panel read collects from its parallel git calls. A class with a lock because the calls finish
/// on different queues; `snapshot` hands the main thread a copy.
private final class PanelLoad: @unchecked Sendable {
    struct Values {
        var status: PluginGit.RepoStatus?
        var commits: [PluginGit.Commit] = []
        var hasMore = false
        var fields: [[PluginGit.Commit]] = []
        var extra: [PluginGit.Commit] = []
        var recentMessages: [String]?
        var stashes: [PluginGit.Commit] = []
    }
    private let lock = NSLock()
    private var values = Values()

    func set(_ change: (inout Values) -> Void) { lock.lock(); change(&values); lock.unlock() }
    func snapshot() -> Values { lock.lock(); defer { lock.unlock() }; return values }
}

extension GitPanelView: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(stageLines), #selector(stageHunk): return allows(.stage)
        case #selector(unstageLines), #selector(unstageHunk): return allows(.unstage)
        case #selector(discardLines), #selector(discardHunk): return allows(.discard)
        default: return true
        }
    }
}
