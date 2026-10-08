// SPDX-License-Identifier: Apache-2.0
// GitMessagesView.swift — commit messages changed after the fact (phase 10).
//
// One window for the three ways in: one commit's message from the history ("Edit message…"), several
// selected commits ("Edit messages…"), and find and replace across a branch or all of them — the case of a
// token pasted into a message and pushed. The list shows the commits in scope (with a search, those that
// match); the selected one's message is shown as it is, with the matches marked, and as it will be, which
// can also be typed into. Nothing is written until Apply, and Apply first says what it will move.
//
// The rewrite itself is `PluginGit.rewriteMessages`: commit objects written directly, so it needs no
// checkout, cannot conflict and leaves the working tree alone. After it, the window offers what comes next —
// force-pushing the branches that were pushed with the old commits, undoing (the old tips are kept under
// refs/pc-backup/), and, for a secret, removing the old commits from this repository for good.

import AppKit

@MainActor
final class GitMessagesView: NSView, NSTextViewDelegate, NSTextFieldDelegate {
    private let services: PcHostServices
    private var theme: PluginTheme
    private let root: String
    /// The commits the window was opened on; offered as a scope of their own.
    private var chosen: [String]
    private var scope: PluginGit.MessageScope
    /// The panel reloads after a rewrite.
    var onChanged: (() -> Void)?

    // State
    private var inScope: [PluginGit.MessageCommit] = [] { didSet { inScopeHashes = Set(inScope.map(\.hash)) } }
    private var inScopeHashes: Set<String> = []
    private var shown: [PluginGit.MessageCommit] = []
    /// Every commit loaded in any scope, so a message typed before the scope changed is not lost.
    private var known: [String: PluginGit.MessageCommit] = [:]
    /// Messages typed for a commit, as typed.
    private var typed: [String: String] = [:]
    /// Commits the replacement leaves alone.
    private var excluded: Set<String> = []
    private var replacement: PluginGit.MessageReplacement?
    private var invalidPattern = false
    private var settingText = false
    private var loading = false
    private var working = false
    private var refilter: DispatchWorkItem?

    /// What the last rewrite left to do.
    private var lastStamp: String?
    private var lastPushed: [PluginGit.RewriteRef] = []
    private var lastEdited: [String] = []
    /// A rewritten branch was force-pushed since (or, after a restart, it is not known whether one was).
    private var forcePushed = false

    // Controls
    private let findField = NSTextField()
    private let replaceField = NSTextField()
    private let regexBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let caseBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let wordBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let redactButton = NSButton()
    private let secretsButton = NSButton()
    private let scopePopup = NSPopUpButton()
    private let countLabel = NSTextField(labelWithString: "")
    private let busy = NSProgressIndicator()
    private let table = GitTable()
    private let beforeTitle = NSTextField(labelWithString: "")
    private let afterTitle = NSTextField(labelWithString: "")
    private let before = GitMessagesView.makeTextView(editable: false)
    private let after = GitMessagesView.makeTextView(editable: true)
    private let backupLabel = NSTextField(wrappingLabelWithString: "")
    private let pushButton = NSButton()
    private let cleanButton = NSButton()
    private let undoButton = NSButton()
    private let backupBar = NSStackView()
    private let summaryLabel = NSTextField(wrappingLabelWithString: "")
    private let revertButton = NSButton()
    private let applyButton = NSButton()

    init(services: PcHostServices, root: String, commits: [String]) {
        self.services = services
        self.root = root
        self.chosen = commits
        self.scope = commits.isEmpty ? .currentBranch : .commits(commits)
        self.theme = PluginTheme(services)
        super.init(frame: NSRect(x: 0, y: 0, width: 980, height: 640))
        build()
        applyTheme()
        load()
        loadBackup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Building

    private static func makeTextView(editable: Bool) -> (scroll: NSScrollView, text: NSTextView) {
        let scroll = NSTextView.scrollableTextView()
        let text = scroll.documentView as! NSTextView
        text.isEditable = editable
        text.isSelectable = true
        text.isRichText = false
        text.allowsUndo = editable
        text.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticDashSubstitutionEnabled = false
        text.isAutomaticTextReplacementEnabled = false
        text.isAutomaticSpellingCorrectionEnabled = false
        text.smartInsertDeleteEnabled = false
        text.textContainerInset = NSSize(width: 4, height: 4)
        return (scroll, text)
    }

    private func button(_ button: NSButton, _ title: String, _ action: Selector) {
        button.title = title
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = .systemFont(ofSize: 11)
        button.target = self
        button.action = action
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 11)
        field.alignment = .right
        field.widthAnchor.constraint(equalToConstant: 64).isActive = true
        return field
    }

    private func build() {
        for (field, placeholder) in [(findField, L("Text to find in the messages")),
                                     (replaceField, L("Replace with (empty removes it)"))] {
            field.placeholderString = placeholder
            field.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            field.controlSize = .small
            field.delegate = self
            field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }
        for (box, title) in [(regexBox, L("Regular expression")), (caseBox, L("Match case")),
                             (wordBox, L("Whole words"))] {
            box.title = title
            box.controlSize = .small
            box.font = .systemFont(ofSize: 11)
            box.target = self
            box.action = #selector(optionsChanged)
        }
        button(redactButton, L("Redact"), #selector(redact))
        redactButton.toolTip = String(format: L("Replace with %@"), PluginGit.redactedText)
        button(secretsButton, L("Find secrets…"), #selector(findSecrets))
        secretsButton.toolTip = L("Looks for tokens, keys and passwords in the listed messages")
        scopePopup.controlSize = .small
        scopePopup.font = .systemFont(ofSize: 11)
        scopePopup.target = self
        scopePopup.action = #selector(scopeChanged)
        rebuildScopePopup()
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.lineBreakMode = .byTruncatingTail
        countLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        busy.style = .spinning
        busy.controlSize = .small
        busy.isDisplayedWhenStopped = false

        let findRow = NSStackView(views: [label(L("Find:")), findField, regexBox, caseBox, wordBox])
        let replaceRow = NSStackView(views: [label(L("Replace:")), replaceField, redactButton, secretsButton])
        let scopeRow = NSStackView(views: [label(L("In:")), scopePopup, countLabel, busy])
        for row in [findRow, replaceRow, scopeRow] {
            row.orientation = .horizontal
            row.spacing = 6
            row.alignment = .centerY
        }

        for (id, title, width) in [("use", "", 22), ("hash", L("Commit"), 72), ("subject", L("Subject"), 300),
                                   ("change", L("Change"), 110)] as [(String, String, CGFloat)] {
            let column = NSTableColumn(identifier: .init(id))
            column.title = title
            column.width = width
            if id == "subject" { column.resizingMask = [.autoresizingMask, .userResizingMask] }
            table.addTableColumn(column)
        }
        table.rowHeight = 18
        table.allowsMultipleSelection = false
        table.usesAlternatingRowBackgroundColors = true
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.dataSource = self
        table.delegate = self
        table.menu = gitMenu([
            (L("Leave this message as it is"), #selector(revertSelected)),
            (L("Copy commit hash"), #selector(copyHash)),
        ], target: self)
        let listScroll = NSScrollView()
        listScroll.documentView = table
        listScroll.hasVerticalScroller = true

        beforeTitle.stringValue = L("Now")
        afterTitle.stringValue = L("After the change — can be edited")
        for title in [beforeTitle, afterTitle] {
            title.font = .systemFont(ofSize: 11, weight: .semibold)
            title.lineBreakMode = .byTruncatingTail
        }
        after.text.delegate = self
        let messages = NSStackView(views: [beforeTitle, before.scroll, afterTitle, after.scroll])
        messages.orientation = .vertical
        messages.alignment = .leading
        messages.spacing = 3
        messages.distribution = .fill
        for scroll in [before.scroll, after.scroll] {
            scroll.widthAnchor.constraint(equalTo: messages.widthAnchor).isActive = true
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 70).isActive = true
            scroll.setContentHuggingPriority(.init(1), for: .vertical)
        }
        before.scroll.heightAnchor.constraint(equalTo: after.scroll.heightAnchor).isActive = true

        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.addArrangedSubview(listScroll)
        split.addArrangedSubview(messages)
        let half = listScroll.widthAnchor.constraint(equalTo: split.widthAnchor, multiplier: 0.48)
        half.priority = .init(490)
        half.isActive = true
        listScroll.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        messages.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
        split.setContentHuggingPriority(.init(1), for: .vertical)
        split.heightAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        button(pushButton, L("Force-push…"), #selector(forcePush))
        button(cleanButton, L("Remove old commits…"), #selector(cleanUp))
        button(undoButton, L("Undo"), #selector(undo))
        backupLabel.font = .systemFont(ofSize: 11)
        backupLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        backupLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        for view in [backupLabel, pushButton, cleanButton, undoButton] { backupBar.addArrangedSubview(view) }
        backupBar.orientation = .horizontal
        backupBar.spacing = 6
        backupBar.alignment = .centerY
        backupBar.isHidden = true

        button(revertButton, L("Leave as it is"), #selector(revertSelected))
        button(applyButton, L("Apply…"), #selector(apply))
        // No Return shortcut: Return in the find field must not start a rewrite — Apply takes a click.
        summaryLabel.font = .systemFont(ofSize: 11)
        summaryLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        summaryLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(views: [summaryLabel, revertButton, applyButton])
        footer.orientation = .horizontal
        footer.spacing = 6
        footer.alignment = .centerY

        let stack = NSStackView(views: [findRow, replaceRow, scopeRow, split, backupBar, footer])
        stack.orientation = .vertical
        stack.alignment = .width          // F-419: `.centerX` draws a narrow column
        stack.distribution = .fill
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        for row in [findRow, replaceRow, scopeRow, backupBar, footer] {
            row.setContentHuggingPriority(.init(750), for: .vertical)
        }
        // Full width, said explicitly: a split view has no width of its own, and `.width` alignment alone
        // left it 500 points wide at the right edge with an empty strip beside it (measured).
        for child in [findRow, replaceRow, scopeRow, split, backupBar, footer] as [NSView] {
            child.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true
        }
        updateState()
    }

    func applyTheme() {
        theme = PluginTheme(services)
        wantsLayer = true
        layer?.backgroundColor = theme.windowBackground.cgColor
        for field in [countLabel, beforeTitle, afterTitle, backupLabel, summaryLabel] { field.textColor = theme.text }
        for pane in [before, after] {
            pane.text.backgroundColor = theme.background
            pane.text.textColor = theme.text
            pane.text.insertionPointColor = theme.text
            pane.scroll.backgroundColor = theme.background
        }
        table.backgroundColor = theme.background
        table.enclosingScrollView?.backgroundColor = theme.background
        table.reloadData()
        showSelected()
    }

    private func rebuildScopePopup() {
        scopePopup.removeAllItems()
        var items: [(String, PluginGit.MessageScope)] = []
        if !chosen.isEmpty {
            items.append((chosen.count == 1 ? L("The selected commit") : String(format: L("The %lld selected commits"), chosen.count),
                          .commits(chosen)))
        }
        items += [(L("The current branch"), .currentBranch), (L("Commits not pushed yet"), .notPushed),
                  (L("All branches and tags"), .allBranches)]
        for (index, item) in items.enumerated() {
            scopePopup.addItem(withTitle: item.0)
            scopePopup.item(at: index)?.representedObject = index
            if item.1 == scope { scopePopup.selectItem(at: index) }
        }
        scopes = items.map(\.1)
    }

    private var scopes: [PluginGit.MessageScope] = []

    // MARK: - Loading

    private func load() {
        loading = true
        busy.startAnimation(nil)
        updateState()
        let root = self.root, scope = self.scope
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PluginGitRepo.run(["-C", root] + PluginGit.messagesArguments(scope))
            let commits = result.ok ? PluginGit.parseMessages(result.out) : []
            DispatchQueue.main.async {
                guard let self, self.scope == scope else { return }
                self.loading = false
                self.busy.stopAnimation(nil)
                self.inScope = commits
                for commit in commits { self.known[commit.hash] = commit }
                self.refresh(keepSelection: false)
            }
        }
    }

    private func loadBackup() {
        let root = self.root
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let output = PluginGitRepo.run(["-C", root, "for-each-ref", "--format=%(refname)", PluginGit.backupNamespace]).out
            let stamp = PluginGit.backupStamps(output).first
            DispatchQueue.main.async {
                guard let self, self.lastStamp == nil, let stamp else { return }
                self.lastStamp = stamp
                self.lastPushed = []
                self.lastEdited = []
                let date = PluginGit.backupDate(stamp).map { gitDateFormatter.string(from: $0) } ?? stamp
                self.showBackupBar(String(format: L("The commit messages were last rewritten on %@. The old commits are kept so that it can be undone."), date))
            }
        }
    }

    // MARK: - The list

    /// The message a commit will have: typed, or replaced, or as it is.
    private func newMessage(_ commit: PluginGit.MessageCommit) -> String {
        if let text = typed[commit.hash] { return text }
        if let replacement, !excluded.contains(commit.hash), inScopeHashes.contains(commit.hash) {
            return replacement.apply(to: commit.message)
        }
        return commit.message
    }

    /// What will be written for each commit that changes, as git stores a message.
    private var changes: [String: String] {
        var out: [String: String] = [:]
        var candidates = inScope
        for hash in typed.keys where !inScopeHashes.contains(hash) {
            if let commit = known[hash] { candidates.append(commit) }
        }
        for commit in candidates {
            let text = typed[commit.hash] != nil ? PluginGit.normalizedMessage(newMessage(commit)) : newMessage(commit)
            if text != commit.message { out[commit.hash] = text }
        }
        return out
    }

    private func readReplacement() {
        let value = PluginGit.MessageReplacement(find: findField.stringValue, replacement: replaceField.stringValue,
                                                 regex: regexBox.state == .on, caseSensitive: caseBox.state == .on,
                                                 wholeWord: wordBox.state == .on)
        invalidPattern = !value.find.isEmpty && value.expression == nil
        replacement = value.expression == nil ? nil : value
    }

    private func refresh(keepSelection: Bool = true) {
        let selected = selectedCommit?.hash
        readReplacement()
        if let replacement, !isChosenScope {
            shown = inScope.filter { !replacement.matches(in: $0.message).isEmpty || typed[$0.hash] != nil }
        } else {
            shown = inScope
        }
        table.reloadData()
        let row = keepSelection ? shown.firstIndex { $0.hash == selected } : nil
        if let row = row ?? (shown.isEmpty ? nil : 0) {
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        } else {
            table.deselectAll(nil)
        }
        showSelected()
        updateState()
    }

    private var isChosenScope: Bool { if case .commits = scope { return true }; return false }

    private var selectedCommit: PluginGit.MessageCommit? {
        shown.indices.contains(table.selectedRow) ? shown[table.selectedRow] : nil
    }

    private func matchCount(_ commit: PluginGit.MessageCommit) -> Int {
        replacement?.matches(in: commit.message).count ?? 0
    }

    /// The selected commit's message twice: as it is, with what will be replaced marked, and as it will be.
    private func showSelected() {
        settingText = true
        defer { settingText = false }
        guard let commit = selectedCommit else {
            before.text.string = ""
            after.text.string = ""
            after.text.isEditable = false
            beforeTitle.stringValue = L("Now")
            return
        }
        let marked = NSMutableAttributedString(string: commit.message, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), .foregroundColor: theme.text,
        ])
        if !excluded.contains(commit.hash), typed[commit.hash] == nil {
            for range in replacement?.matches(in: commit.message) ?? [] {
                marked.addAttributes([.backgroundColor: NSColor.systemRed.withAlphaComponent(0.3)], range: range)
            }
        }
        before.text.textStorage?.setAttributedString(marked)
        beforeTitle.stringValue = String(format: L("Now — %@ by %@, %@"), commit.shortHash, commit.author,
                                         gitDisplayDate(commit.date))
        after.text.isEditable = !working
        after.text.string = newMessage(commit)
        after.text.textColor = theme.text
        after.text.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    }

    func textDidChange(_ notification: Notification) {
        guard !settingText, let commit = selectedCommit else { return }
        typed[commit.hash] = after.text.string
        reloadSelectedRow()
        updateState()
    }

    private func reloadSelectedRow() {
        let row = table.selectedRow
        guard row >= 0 else { return }
        table.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integersIn: 0..<table.numberOfColumns))
    }

    func controlTextDidChange(_ obj: Notification) {
        // After a pause: the replacement runs over every message in scope.
        refilter?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        refilter = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    @objc private func optionsChanged() { refresh() }

    @objc private func scopeChanged() {
        let index = scopePopup.indexOfSelectedItem
        guard scopes.indices.contains(index), scopes[index] != scope else { return }
        scope = scopes[index]
        load()
    }

    @objc private func redact() {
        replaceField.stringValue = PluginGit.redactedText
        refresh()
    }

    @objc private func toggleInclude(_ sender: NSButton) {
        guard shown.indices.contains(sender.tag) else { return }
        let hash = shown[sender.tag].hash
        if sender.state == .on { excluded.remove(hash) } else { excluded.insert(hash); typed[hash] = nil }
        table.selectRowIndexes(IndexSet(integer: sender.tag), byExtendingSelection: false)
        reloadSelectedRow()
        showSelected()
        updateState()
    }

    @objc private func revertSelected() {
        guard let commit = selectedCommit else { return }
        typed[commit.hash] = nil
        excluded.insert(commit.hash)
        reloadSelectedRow()
        showSelected()
        updateState()
    }

    @objc private func copyHash() { selectedCommit.map { gitCopyToClipboard($0.hash) } }

    private func updateState() {
        let count = changes.count
        if loading {
            countLabel.stringValue = L("Reading the messages…")
        } else if invalidPattern {
            countLabel.stringValue = L("The regular expression is not valid.")
        } else if replacement != nil {
            let matches = shown.reduce(0) { $0 + matchCount($1) }
            countLabel.stringValue = String(format: L("%lld commits, %lld matches"), shown.filter { matchCount($0) > 0 }.count, matches)
        } else {
            countLabel.stringValue = String(format: L("%lld commits"), shown.count)
        }
        // The listing stops at a limit; a search past it must not look complete.
        if !loading, inScope.count >= PluginGit.messagesLimit {
            countLabel.stringValue += " — " + String(format: L("only the newest %lld commits are searched"), PluginGit.messagesLimit)
        }
        countLabel.textColor = invalidPattern ? .systemRed : theme.text
        summaryLabel.stringValue = count == 0
            ? L("Nothing changes yet. Find and replace, or type into the message below.")
            : String(format: L("%lld messages will change. Every later commit is rewritten with them; files and the working tree are not touched."), count)
        applyButton.isEnabled = count > 0 && !working && !loading
        // Typing while a rewrite is being prepared or runs would not be part of it.
        after.text.isEditable = !working && selectedCommit != nil
        revertButton.isEnabled = selectedCommit.map { newMessage($0) != $0.message } ?? false
        for control in [findField, replaceField, regexBox, caseBox, wordBox, redactButton, secretsButton, scopePopup] as [NSControl] {
            control.isEnabled = !working
        }
        undoButton.isEnabled = !working && lastStamp != nil
        cleanButton.isEnabled = !working && lastStamp != nil
        pushButton.isHidden = lastPushed.isEmpty
        pushButton.isEnabled = !working
    }

    private func showBackupBar(_ text: String) {
        backupLabel.stringValue = text
        backupBar.isHidden = false
        updateState()
    }

    // MARK: - Secrets

    @objc private func findSecrets() {
        var values: [String: (kind: String, commits: Set<String>)] = [:]
        for commit in inScope {
            for finding in PluginGit.secretFindings(in: commit.message) {
                values[finding.value, default: (finding.kind, [])].commits.insert(commit.hash)
            }
        }
        guard !values.isEmpty else {
            report(L("No known kind of token, key or password was found in these messages. Search for it by its text instead."))
            return
        }
        let lines = values.sorted { $0.value.commits.count > $1.value.commits.count }.prefix(12).map {
            "• \($0.value.kind): \(PluginGit.maskedSecret($0.key)) — " + String(format: L("in %lld commit(s)"), $0.value.commits.count)
        }
        let alert = NSAlert()
        alert.messageText = String(format: L("%lld possible secrets found"), values.count)
        alert.informativeText = lines.joined(separator: "\n") + (values.count > 12 ? "\n…" : "")
            + "\n\n" + L("Redacting fills in the search and the replacement; the list then shows what would change, and nothing is written before Apply.")
        alert.addButton(withTitle: L("Redact them"))
        alert.addButton(withTitle: L("Cancel"))
        guard automationAnswers || alert.runModal() == .alertFirstButtonReturn else { return }
        let redaction = PluginGit.redaction(of: Array(values.keys))
        findField.stringValue = redaction.find
        replaceField.stringValue = redaction.replacement
        regexBox.state = .on
        caseBox.state = .on
        wordBox.state = .off
        refresh()
    }

    // MARK: - Applying

    private struct Analysis {
        var refs: [PluginGit.RewriteRef]
        var operation: PluginGit.Operation?
        var bisecting: Bool
        var signed: Int
        /// How many commits get new hashes: the changed ones and their descendants on the refs.
        var rewritten: Int
    }

    @objc private func apply() {
        let changes = self.changes
        guard !changes.isEmpty else { return }
        if let empty = changes.first(where: { PluginGit.normalizedMessage($0.value).isEmpty }) {
            report(String(format: L("The message of %@ would be empty. A commit needs a message."), String(empty.key.prefix(8))))
            return
        }
        working = true
        busy.startAnimation(nil)
        updateState()
        let root = self.root
        let edited = Array(changes.keys)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let git = PluginGitRepo.call(root: root)
            let current = String(decoding: git(["symbolic-ref", "-q", "HEAD"], nil, [:]).out, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let refs = PluginGit.parseContainingRefs(String(decoding: git(PluginGit.containingRefsArguments(edited), nil, [:]).out, as: UTF8.self),
                                                     currentBranch: current.isEmpty ? nil : current)
            let objects = PluginGit.parseCatFileBatch(git(["cat-file", "--batch"], Data((edited.joined(separator: "\n") + "\n").utf8), [:]).out)
            // Counted the way the rewrite walks: parents first, a commit is new when it changes or a parent did.
            let parents = Set(objects.values.compactMap { PluginGit.parseCommitObject($0.content) }.flatMap(\.parents))
            let tips = refs.filter { $0.kind == .branch || $0.kind == .tag }.map(\.name)
            var touched = Set(edited)
            if !tips.isEmpty {
                let walk = String(decoding: git(["rev-list", "--topo-order", "--reverse", "--parents"] + tips
                                                + (parents.isEmpty ? [] : ["--not"] + parents.sorted()), nil, [:]).out, as: UTF8.self)
                for line in walk.split(separator: "\n") {
                    let parts = line.split(separator: " ").map(String.init)
                    if let hash = parts.first, parts.dropFirst().contains(where: touched.contains) { touched.insert(hash) }
                }
            }
            // Signed: every commit that gets a new hash loses its signature, not only the edited ones.
            let all = PluginGit.parseCatFileBatch(git(["cat-file", "--batch"], Data((touched.sorted().joined(separator: "\n") + "\n").utf8), [:]).out)
            let signed = all.values.compactMap { PluginGit.parseCommitObject($0.content) }.filter(\.isSigned).count
            let analysis = Analysis(refs: refs, operation: PluginGitRepo.operationInProgress(root: root),
                                    bisecting: PluginGitRepo.isBisecting(root: root), signed: signed,
                                    rewritten: touched.count)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                self.working = false
                self.updateState()
                self.confirmAndRewrite(changes, analysis)
            }
        }
    }

    private func confirmAndRewrite(_ changes: [String: String], _ analysis: Analysis) {
        if analysis.operation != nil || analysis.bisecting {
            report(L("A merge, rebase, cherry-pick or bisect is in progress. Finish or abort it first."))
            return
        }
        let movable = analysis.refs.filter { $0.kind == .branch || $0.kind == .tag }
        guard !movable.isEmpty else {
            report(L("None of these commits is on a local branch or tag, so there is nothing to rewrite here."))
            return
        }
        let remotes = analysis.refs.filter { $0.kind == .remote }
        var notes: [String] = [
            String(format: L("%lld commits get new hashes: the %lld changed ones and every commit after them on the branches below."),
                   max(analysis.rewritten, changes.count), changes.count),
            L("Files and the working tree are not touched. The old commits are kept, so this can be undone."),
        ]
        if !remotes.isEmpty {
            notes.append("⚠︎ " + String(format: L("Already pushed to %@: the branches will have to be force-pushed afterwards, and anyone who fetched them still has the old commits."),
                                        remotes.map(\.shortName).joined(separator: ", ")))
        }
        if analysis.signed > 0 {
            notes.append(GitSettingsStore.current.signCommits
                ? String(format: L("%lld of them are signed; they are signed again with your key."), analysis.signed)
                : "⚠︎ " + String(format: L("%lld of them are signed and lose their signature (Settings ▸ Git ▸ Sign commits signs them again)."), analysis.signed))
        }
        if analysis.refs.contains(where: { $0.kind == .stash }) {
            notes.append(L("A stash was made on one of these commits; it stays on the old one."))
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(format: L("Change %lld commit messages?"), changes.count)
        alert.informativeText = notes.joined(separator: "\n\n")

        // Every change, before and after, in the order of the history: what is about to be written is read
        // here, not guessed from a count.
        let order = inScope.map(\.hash) + changes.keys.filter { !inScopeHashes.contains($0) }.sorted()
        var listing = ""
        for hash in order {
            guard let new = changes[hash], let commit = known[hash] else { continue }
            let newSubject = new.components(separatedBy: "\n").first ?? ""
            listing += "\(commit.shortHash)  \(commit.subject)\n"
            listing += String(repeating: " ", count: commit.shortHash.count) + "→ "
                + (newSubject == commit.subject ? L("(subject unchanged, the rest of the message changes)") : newSubject) + "\n"
        }
        let changesTitle = NSTextField(labelWithString: String(format: L("The %lld changes:"), changes.count))
        changesTitle.font = .systemFont(ofSize: 11, weight: .semibold)
        let changesView = NSTextView.scrollableTextView()
        changesView.frame = NSRect(x: 0, y: 0, width: 460, height: min(CGFloat(changes.count) * 30 + 10, 200))
        changesView.hasVerticalScroller = true
        changesView.borderType = .bezelBorder
        if let text = changesView.documentView as? NSTextView {
            text.isEditable = false
            text.string = listing
            text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        }
        changesView.translatesAutoresizingMaskIntoConstraints = false
        changesView.widthAnchor.constraint(equalToConstant: 460).isActive = true
        changesView.heightAnchor.constraint(equalToConstant: changesView.frame.height).isActive = true

        // The branches and tags to move: all by default; one left out keeps the old commits.
        let boxes = movable.map { ref -> NSButton in
            let title = ref.kind == .tag ? String(format: L("Tag %@"), ref.shortName)
                : ref.isCurrent ? String(format: L("%@ (current branch)"), ref.shortName) : ref.shortName
            let box = NSButton(checkboxWithTitle: title, target: nil, action: nil)
            box.state = .on
            box.font = .systemFont(ofSize: 11)
            return box
        }
        let heading = NSTextField(labelWithString: L("Move these onto the new commits:"))
        heading.font = .systemFont(ofSize: 11, weight: .semibold)
        let list = NSStackView(views: [heading] + boxes)
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 3
        let height = min(CGFloat(boxes.count + 1) * 20 + 4, 160)
        let refsScroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460, height: height))
        list.frame = NSRect(x: 0, y: 0, width: 440, height: CGFloat(boxes.count + 1) * 20)
        refsScroll.documentView = list
        refsScroll.hasVerticalScroller = boxes.count > 7
        refsScroll.drawsBackground = false
        refsScroll.translatesAutoresizingMaskIntoConstraints = false
        refsScroll.widthAnchor.constraint(equalToConstant: 460).isActive = true
        refsScroll.heightAnchor.constraint(equalToConstant: height).isActive = true

        let accessory = NSStackView(views: [changesTitle, changesView, refsScroll])
        accessory.orientation = .vertical
        accessory.alignment = .leading
        accessory.spacing = 6
        accessory.frame = NSRect(x: 0, y: 0, width: 460, height: changesView.frame.height + height + 30)
        alert.accessoryView = accessory
        let change = alert.addButton(withTitle: L("Change Messages"))
        let cancel = alert.addButton(withTitle: L("Cancel"))
        change.hasDestructiveAction = true
        // More than one commit, or any already pushed: Return cancels, so the rewrite takes a deliberate click.
        if changes.count > 1 || !remotes.isEmpty {
            change.keyEquivalent = ""
            cancel.keyEquivalent = "\r"
        }
        guard automationAnswers || alert.runModal() == .alertFirstButtonReturn else { return }
        let refs = zip(movable, boxes).filter { $0.1.state == .on }.map(\.0.name)
        guard !refs.isEmpty else { return }
        rewrite(changes, refs: refs, pushed: PluginGit.pushedBranches(analysis.refs).filter { refs.contains($0.name) })
    }

    private func rewrite(_ changes: [String: String], refs: [String], pushed: [PluginGit.RewriteRef]) {
        working = true
        busy.startAnimation(nil)
        updateState()
        let root = self.root
        let sign = GitSettingsStore.current.signCommits
        let stamp = PluginGit.backupStamp(Date())
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PluginGit.rewriteMessages(changes, refs: refs, sign: sign, stamp: stamp,
                                                   git: PluginGitRepo.call(root: root))
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                self.working = false
                PluginGitRepo.invalidate()
                switch result {
                case .success(let report): self.rewritten(report, edited: Array(changes.keys), pushed: pushed)
                case .failure(let error): self.updateState(); self.report(Self.text(for: error))
                }
            }
        }
    }

    private func rewritten(_ report: PluginGit.RewriteReport, edited: [String], pushed: [PluginGit.RewriteRef]) {
        lastStamp = report.stamp
        lastEdited = edited
        forcePushed = false
        lastPushed = pushed
        typed = [:]
        excluded = []
        if case .commits(let hashes) = scope {
            chosen = hashes.map { report.mapping[$0] ?? $0 }
            scope = .commits(chosen)
            rebuildScopePopup()
        }
        var text = String(format: L("%lld commits rewritten; moved: %@."), report.mapping.count,
                          report.moved.map { PluginGit.RewriteRef(name: $0.ref, kind: .branch).shortName }.joined(separator: ", "))
        if !pushed.isEmpty {
            text += " " + String(format: L("%@ still has the old commits: force-push to replace them."),
                                 pushed.compactMap(\.upstream).map { PluginGit.RewriteRef(name: $0, kind: .remote).shortName }.joined(separator: ", "))
        }
        if report.unsigned > 0 { text += " " + String(format: L("%lld signatures removed."), report.unsigned) }
        if report.notSigned > 0 { text += " " + String(format: L("%lld commits could not be signed again."), report.notSigned) }
        if !report.unreached.isEmpty {
            text += " " + String(format: L("%lld of the commits are not on a chosen branch and were left as they are."), report.unreached.count)
        }
        showBackupBar(text)
        services.reloadActivePanel?(services.host)
        onChanged?()
        load()
    }

    private static func text(for error: PluginGit.RewriteError) -> String {
        switch error {
        case .notReachable:
            return L("None of these commits is on a chosen branch or tag, so nothing was changed.")
        case .notUTF8(let hashes):
            return String(format: L("The message of %@ is not stored as UTF-8 and cannot be changed here."),
                          hashes.map { String($0.prefix(8)) }.joined(separator: ", "))
        case .refMoved(let ref):
            return String(format: L("%@ moved while the messages were being rewritten. Nothing was changed; try again."), ref)
        case .git(let message), .writeFailed(let message):
            return message.isEmpty ? L("A commit could not be written. Nothing was changed.") : message
        case .historyUnreadable:
            return L("The history could not be read. Nothing was changed.")
        case .nameMismatch:
            return L("Git stored a commit under a different name than expected. No branch was moved.")
        }
    }

    // MARK: - After the rewrite

    @objc private func forcePush() {
        let pushed = lastPushed
        guard !pushed.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = String(format: L("Force-push %@?"), pushed.map(\.shortName).joined(separator: ", "))
        alert.informativeText = L("The remote branches are replaced by the rewritten ones — with a lease: if somebody pushed to them since they were fetched, the push is refused instead.")
        alert.addButton(withTitle: L("Force-push"))
        alert.addButton(withTitle: L("Cancel"))
        guard confirmDeliberately(alert) else { return }
        working = true
        busy.startAnimation(nil)
        updateState()
        let root = self.root
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var lines: [String] = []
            var failed: [PluginGit.RewriteRef] = []
            for ref in pushed {
                guard let arguments = PluginGit.forcePushArguments(for: ref) else { continue }
                let result = PluginGitRepo.run(["-C", root] + arguments, combined: true)
                if !result.ok { failed.append(ref) }
                lines.append("\(ref.shortName): " + (result.ok ? L("pushed.") : result.out.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                self.working = false
                if failed.count < pushed.count { self.forcePushed = true }
                self.lastPushed = failed
                PluginGitRepo.invalidate()
                self.services.reloadActivePanel?(self.services.host)
                self.onChanged?()
                self.updateState()
                self.report(lines.joined(separator: "\n"))
            }
        }
    }

    @objc private func undo() {
        guard let stamp = lastStamp else { return }
        let alert = NSAlert()
        alert.messageText = L("Undo the rewrite of the commit messages?")
        alert.informativeText = L("The branches and tags go back to the old commits — if none of them has moved since.")
            + (forcePushed || lastEdited.isEmpty ? "\n\n" + L("A branch that was force-pushed in between stays rewritten at its remote.") : "")
        alert.addButton(withTitle: L("Undo"))
        alert.addButton(withTitle: L("Cancel"))
        guard confirmDeliberately(alert) else { return }
        run { git in PluginGit.undoRewrite(stamp: stamp, git: git) } done: { [weak self] (result: PluginGit.UndoResult) in
            guard let self else { return }
            switch result {
            case .undone(let refs):
                self.forgetBackup()
                self.report(String(format: L("Undone: %@ are back on the old commits."),
                                   refs.map { PluginGit.RewriteRef(name: $0, kind: .branch).shortName }.joined(separator: ", ")))
            case .moved(let refs):
                self.report(String(format: L("%@ moved since the rewrite. Undoing would throw away the newer commits, so nothing was changed."),
                                   refs.map { PluginGit.RewriteRef(name: $0, kind: .branch).shortName }.joined(separator: ", ")))
            case .noBackup:
                self.forgetBackup()
                self.report(L("There is no backup of that rewrite any more."))
            case .failed(let message):
                self.report(message)
            }
        }
    }

    @objc private func cleanUp() {
        let stamp = lastStamp
        // Checked afterwards: the commits whose message changed, or — after a restart — the old tips.
        let edited = lastEdited
        // First: is an old commit still on a remote-tracking branch? Then the branch has not been
        // force-pushed yet, and removing the old commits' reflog entries now would make that push refuse
        // for good (`--force-if-includes` asks the reflog) — leaving the secret on the server.
        run { git -> (old: [String], remotes: [String]) in
            var old = edited
            if old.isEmpty, let stamp {
                old = PluginGit.parseBackup(String(decoding: git(PluginGit.backupRefsArguments(stamp), nil, [:]).out, as: UTF8.self),
                                            stamp: stamp).values.compactMap(\.old)
            }
            old = Array(Set(old)).sorted()
            let remotes = old.isEmpty ? "" : String(decoding: git(["for-each-ref", "--format=%(refname)"]
                + old.flatMap { ["--contains", $0] } + ["refs/remotes"], nil, [:]).out, as: UTF8.self)
            return (old, remotes.components(separatedBy: "\n").filter { !$0.isEmpty && !$0.hasSuffix("/HEAD") })
        } done: { [weak self] (found: (old: [String], remotes: [String])) in
            guard let self else { return }
            guard found.remotes.isEmpty else {
                self.report(String(format: L("%@ still has the old commits. Force-push the rewritten branches first; removing the old commits before that would make the force-push impossible."),
                                   found.remotes.map { PluginGit.RewriteRef(name: $0, kind: .remote).shortName }.joined(separator: ", ")))
                return
            }
            self.confirmCleanUp(stamp: stamp, old: found.old)
        }
    }

    private func confirmCleanUp(stamp: String?, old: [String]) {
        let alert = NSAlert()
        alert.messageText = L("Remove the old commits from this repository?")
        alert.informativeText = [
            L("For a secret in a message: the backup is deleted, so the rewrite can no longer be undone; reflog entries that no branch reaches any more go too (commits left behind by a reset among them, stashes excepted); then git prunes."),
            L("This is about this repository only. Commits that were pushed may still be reachable at the server — through pull requests, forks or caches — and in every clone. A secret that was pushed has to be revoked or changed."),
        ].joined(separator: "\n\n")
        alert.addButton(withTitle: L("Remove"))
        alert.addButton(withTitle: L("Cancel"))
        guard confirmDeliberately(alert) else { return }
        // `gc --prune=now` must not run beside a process writing objects: the panel's quiet fetch waits.
        guard GitActivity.begin(pruning: root) else {
            report(L("A fetch is running in this repository. Try again when it has finished."))
            return
        }
        let root = self.root
        run { git in PluginGit.cleanUpRewrite(stamp: stamp, old: old, git: git) } done: { [weak self] result in
            GitActivity.end(pruning: root)
            guard let self else { return }
            self.forgetBackup()
            switch result {
            case .success(let report) where report.remaining.isEmpty:
                self.report(String(format: L("The %lld old commits are gone from this repository."), report.removed.count))
            case .success(let report):
                let holders = Set(report.remaining.values.flatMap { $0 }).sorted()
                var text = String(format: L("%lld old commits are still in this repository."), report.remaining.count)
                if holders.isEmpty {
                    text += " " + L("A stash or another worktree may still hold them.")
                } else {
                    text += " " + String(format: L("Still reached from: %@."), holders.map { PluginGit.RewriteRef(name: $0, kind: .branch).shortName }.joined(separator: ", "))
                    if holders.contains(where: { $0.hasPrefix("refs/remotes/") }) {
                        text += " " + L("Force-push the rewritten branches first; then remove again.")
                    }
                }
                self.report(text)
            case .failure(let error):
                self.report(Self.text(for: error))
            }
        }
    }

    /// A question before something that changes the repository's history or a remote: a warning, the action
    /// marked destructive, and Return on Cancel — it takes a click on the action, not a reflex.
    private func confirmDeliberately(_ alert: NSAlert) -> Bool {
        alert.alertStyle = .warning
        let buttons = alert.buttons
        if buttons.count >= 2 {
            buttons[0].hasDestructiveAction = true
            buttons[0].keyEquivalent = ""
            buttons[1].keyEquivalent = "\r"
        }
        return automationAnswers || alert.runModal() == .alertFirstButtonReturn
    }

    private func forgetBackup() {
        lastStamp = nil
        lastEdited = []
        lastPushed = []
        backupBar.isHidden = true
        updateState()
        loadBackup()
        services.reloadActivePanel?(services.host)
        onChanged?()
        load()
    }

    /// Run git work off the main thread with the window busy, then hand the result back.
    private func run<T>(_ work: @escaping @Sendable (PluginGit.GitCall) -> T, done: @escaping (T) -> Void) {
        working = true
        busy.startAnimation(nil)
        updateState()
        let root = self.root
        let box = ResultBox<T>()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            box.value = work(PluginGitRepo.call(root: root))
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                self.working = false
                PluginGitRepo.invalidate()
                self.updateState()
                if let value = box.value { done(value) }
            }
        }
    }

    private func report(_ message: String) {
        if automationAnswers { automationLog.append(message); return }
        services.presentInfo?(services.host, L("Commit Messages"), message)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "r", !working {
            load()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    // MARK: - Verification

    /// Set by the verification probe: every confirmation is answered yes, and reports are kept for the
    /// dump instead of being shown.
    private var automationAnswers = false
    private var automationLog: [String] = []

    /// `ask`: the confirmation is shown for real (to look at it), everything else still answered yes.
    func automationRun(find: String, replace: String, apply: Bool, ask: Bool = false) {
        automationAnswers = !ask
        findField.stringValue = find
        replaceField.stringValue = replace
        refresh()
        if apply { DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.apply() } }
    }

    func automationSummary() -> [String] {
        ["messagesScope=\(scopePopup.titleOfSelectedItem ?? "")", "messagesCount=\(countLabel.stringValue)",
         "messagesRows=" + shown.map { "\($0.shortHash):\(newMessage($0).components(separatedBy: "\n").first ?? "")" }.joined(separator: "|"),
         "messagesBefore=" + before.text.string.replacingOccurrences(of: "\n", with: "|"),
         "messagesAfter=" + after.text.string.replacingOccurrences(of: "\n", with: "|"),
         "messagesSummary=\(summaryLabel.stringValue)", "messagesApplyEnabled=\(applyButton.isEnabled)",
         "messagesBackup=\(backupBar.isHidden ? "hidden" : backupLabel.stringValue)",
         "messagesLog=" + automationLog.joined(separator: " / ")]
    }
}

/// A value made on another queue, read after the hop back to the main one.
private final class ResultBox<T>: @unchecked Sendable { var value: T? }

extension GitMessagesView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { shown.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let id = tableColumn?.identifier.rawValue, shown.indices.contains(row) else { return nil }
        let commit = shown[row]
        if id == "use" {
            let box = (tableView.makeView(withIdentifier: .init("GitMessagesUse"), owner: self) as? NSButton)
                ?? NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleInclude(_:)))
            box.identifier = .init("GitMessagesUse")
            box.tag = row
            box.state = excluded.contains(commit.hash) ? .off : .on
            box.toolTip = L("Change this commit's message")
            return box
        }
        let field = (tableView.makeView(withIdentifier: .init("GitMessagesText"), owner: self) as? NSTextField)
            ?? {
                let f = NSTextField(labelWithString: "")
                f.identifier = .init("GitMessagesText")
                f.usesSingleLineMode = true
                f.lineBreakMode = .byTruncatingTail
                return f
            }()
        field.font = .systemFont(ofSize: 11)
        field.textColor = theme.text
        field.toolTip = nil
        let changed = newMessage(commit) != commit.message
        switch id {
        case "hash":
            field.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            field.stringValue = commit.shortHash
            field.textColor = theme.secondaryText
        case "subject":
            let subject = newMessage(commit).components(separatedBy: "\n").first ?? ""
            field.stringValue = subject
            field.toolTip = changed ? String(format: L("Was: %@"), commit.subject) : commit.subject
            if changed { field.font = .systemFont(ofSize: 11, weight: .semibold) }
        default:
            if typed[commit.hash] != nil {
                field.stringValue = changed ? L("edited") : ""
            } else if excluded.contains(commit.hash) {
                field.stringValue = L("left as it is")
            } else {
                let count = matchCount(commit)
                field.stringValue = count == 0 ? "" : String(format: L("%lld replaced"), count)
            }
            field.textColor = theme.secondaryText
        }
        return field
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        showSelected()
        updateState()
    }
}
