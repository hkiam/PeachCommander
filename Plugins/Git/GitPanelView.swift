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
    private var status: PluginGit.RepoStatus?
    private var groups: [(section: PluginGit.Section, files: [PluginGit.FileStatus])] = []

    private let header = NSTextField(labelWithString: "")
    private let outline = NSOutlineView()
    private let scroll = NSScrollView()
    private let messageField = NSTextField()
    private let commitButton = NSButton()
    private let amendCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let stageButton = NSButton()
    private let unstageButton = NSButton()
    private let discardButton = NSButton()
    private let refreshButton = NSButton()
    private let busy = NSProgressIndicator()

    /// Host services, copied — the host's is a stack value and must not be kept by pointer.
    private let services: PcHostServices

    init(services: PcHostServices) {
        self.services = services
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 360))
        build()
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Host notifications

    /// The active panel moved, or the theme changed.
    func notify(key: String, value: String) {
        switch key {
        case "dir", "cursorPath", "sidebarViewRoot":
            let directory = key == "cursorPath" ? (value as NSString).deletingLastPathComponent : value
            guard directory != self.directory else { return }
            self.directory = directory
            reload()
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

        for (button, title, action) in [
            (stageButton, L("Stage"), #selector(stageSelected)),
            (unstageButton, L("Unstage"), #selector(unstageSelected)),
            (discardButton, L("Discard…"), #selector(discardSelected)),
            (refreshButton, L("Refresh"), #selector(refreshNow)),
        ] as [(NSButton, String, Selector)] {
            button.title = title
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.font = .systemFont(ofSize: 11)
            button.target = self
            button.action = action
        }
        amendCheckbox.title = L("Amend")
        amendCheckbox.controlSize = .small
        amendCheckbox.font = .systemFont(ofSize: 11)

        let buttons = NSStackView(views: [stageButton, unstageButton, discardButton, refreshButton])
        buttons.orientation = .horizontal
        buttons.spacing = 4
        buttons.distribution = .fillEqually

        outline.headerView = nil
        outline.rowHeight = 18
        outline.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        outline.dataSource = self
        outline.delegate = self
        outline.target = self
        outline.doubleAction = #selector(diffSelected)
        outline.allowsMultipleSelection = true
        outline.addTableColumn(NSTableColumn(identifier: .init("file")))
        outline.outlineTableColumn = outline.tableColumns.first
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        messageField.placeholderString = L("Commit message")
        messageField.font = .systemFont(ofSize: 11)
        messageField.controlSize = .small
        commitButton.title = L("Commit")
        commitButton.bezelStyle = .rounded
        commitButton.controlSize = .small
        commitButton.font = .systemFont(ofSize: 11)
        commitButton.target = self
        commitButton.action = #selector(commit)
        busy.style = .spinning
        busy.controlSize = .small
        busy.isDisplayedWhenStopped = false

        let commitRow = NSStackView(views: [messageField, amendCheckbox, commitButton, busy])
        commitRow.orientation = .horizontal
        commitRow.spacing = 6
        messageField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [header, buttons, scroll, commitRow])
        stack.orientation = .vertical
        stack.alignment = .width
        // Same as the log window: `.width` alone does not stretch a scroll or split view inside a stack,
        // so the ones that should fill the window say so (F-419).
        for child in [header, buttons, scroll, commitRow] as [NSView] {
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
            // A container may legitimately be zero-sized while hidden, so this is a preference rather
            // than a rule: a required height against a collapsed dock is an Auto Layout conflict
            // (CONVENTIONS.md).
            scroll.heightAnchor.constraint(greaterThanOrEqualTo: heightAnchor, multiplier: 0.4),
        ])
        for constraint in constraints where constraint.firstItem === scroll {
            constraint.priority = .init(999)
        }
        applyTheme()
    }

    /// Colours come from the host, so the panel matches whichever palette is active.
    private func applyTheme() {
        let background = hostColor("theme.listBackground") ?? .controlBackgroundColor
        let text = hostColor("theme.listText") ?? .labelColor
        wantsLayer = true
        layer?.backgroundColor = background.cgColor
        header.textColor = text
        outline.backgroundColor = background
        scroll.backgroundColor = background
        outline.reloadData()
    }

    private func hostColor(_ key: String) -> NSColor? {
        var buffer = [CChar](repeating: 0, count: 32)
        guard let get = services.getContext, get(services.host, key, &buffer, 32) != 0 else { return nil }
        return NSColor(hex: String(cString: buffer))
    }

    // MARK: - Loading

    @objc private func refreshNow() { PluginGitRepo.invalidate(); reload() }

    /// Re-read the repository off the main thread and rebuild the list on it.
    private func reload() {
        let directory = self.directory.isEmpty ? hostDirectory() : self.directory
        self.directory = directory
        busy.startAnimation(nil)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let located = PluginGitRepo.locate(directory)
            let status = located.flatMap { PluginGitRepo.status(root: $0.root) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                self.root = located?.root
                self.status = status
                self.groups = status.map { PluginGit.grouped($0) } ?? []
                self.outline.reloadData()
                self.outline.expandItem(nil, expandChildren: true)
                self.updateHeader()
                self.updateButtons()
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
        let changes = status.files.values.filter { !PluginGit.sections(for: $0).isEmpty }.count
        text += changes == 0
            ? "  ·  " + L("Working tree clean.")
            : "  ·  " + String(format: L("%lld change(s)"), changes)
        header.stringValue = text
    }

    private func updateButtons() {
        let selected = selectedFiles()
        let hasRepo = root != nil
        stageButton.isEnabled = hasRepo && !selected.isEmpty
        unstageButton.isEnabled = hasRepo && selected.contains { $0.file.isStaged }
        discardButton.isEnabled = hasRepo && !selected.isEmpty
        refreshButton.isEnabled = hasRepo
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
            field.textColor = .secondaryLabelColor
        } else if let node = item as? FileNode {
            field.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            field.stringValue = node.file.path
            field.toolTip = node.file.originalPath.map { String(format: L("Renamed from %@"), $0) }
                ?? node.file.path
            field.textColor = node.section == .conflicts ? .systemRed : .labelColor
        }
        return field
    }

    func outlineViewSelectionDidChange(_ notification: Notification) { updateButtons() }

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
