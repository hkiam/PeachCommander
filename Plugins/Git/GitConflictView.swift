// SPDX-License-Identifier: Apache-2.0
// GitConflictView.swift — resolving a conflict where the conflict is: in the file's own markers.
//
// Phase 5a of docs/analysis/git-plugin-plan.md (F-420). Phase 3 could show *ours* against *theirs* in the
// compare window and then left the reader alone with `<<<<<<<` in the file, which means a conflict still
// ended in a terminal. This lists the file's conflicted regions and takes a decision per region — ours,
// theirs, both, or hand it to the editor — then writes the file and stages it.
//
// Deliberately NOT a merge editor: no base pane, no result pane, no hunk-level text editing. The
// application already has an editor and a compare window, and a second one of each is a second set of
// defects (the plan's §5, "deliberately out of scope"). What is here is the decision, which is the part
// neither of those two can express.
//
// The parsing and the writing-back live in Plugins/SDK/PluginGit.swift and are unit-tested, including the
// cases that must be *refused* — this text is about to be written over the reader's file.

import AppKit

@MainActor
final class GitConflictView: NSView {
    private let services: PcHostServices
    private let root: String
    /// Repository-relative, which is what git wants; `absolute` is what the filesystem wants.
    private let relative: String
    private let absolute: String

    private var file: PluginGit.ConflictFile?
    private var choices: [PluginGit.ConflictChoice] = []

    private let header = NSTextField(labelWithString: "")
    private let table = NSTableView()
    private let oursButton = NSButton()
    private let theirsButton = NSButton()
    private let bothButton = NSButton()
    private let resetButton = NSButton()
    private let compareButton = NSButton()
    private let editButton = NSButton()
    private let writeButton = NSButton()
    private let stageButton = NSButton()
    private let busy = NSProgressIndicator()

    init(services: PcHostServices, root: String, relative: String) {
        self.services = services
        self.root = root
        self.relative = relative
        self.absolute = (root as NSString).appendingPathComponent(relative)
        super.init(frame: NSRect(x: 0, y: 0, width: 780, height: 440))
        build()
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Building

    private func build() {
        header.font = .systemFont(ofSize: 12, weight: .semibold)
        header.lineBreakMode = .byTruncatingMiddle

        for (id, title, width) in [("line", L("Line"), 54), ("state", L("Decision"), 110),
                                   ("ours", L("ours"), 260),
                                   ("theirs", L("theirs"), 260)] as [(String, String, CGFloat)] {
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
        table.target = self
        table.doubleAction = #selector(compareOursAndTheirs)

        for (button, title, action) in [
            (oursButton, L("Take ours"), #selector(takeOurs)),
            (theirsButton, L("Take theirs"), #selector(takeTheirs)),
            (bothButton, L("Take both"), #selector(takeBoth)),
            (resetButton, L("Undecide"), #selector(undecide)),
            (compareButton, L("Compare ours ↔ theirs"), #selector(compareOursAndTheirs)),
            (editButton, L("Open in editor"), #selector(openInEditor)),
            (writeButton, L("Write file"), #selector(write)),
            (stageButton, L("Write and stage"), #selector(writeAndStage)),
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

        let decisions = NSStackView(views: [oursButton, theirsButton, bothButton, resetButton])
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
        footer.addView(compareButton, in: .leading)
        footer.addView(editButton, in: .leading)
        footer.addView(busy, in: .leading)
        footer.addView(writeButton, in: .trailing)
        footer.addView(stageButton, in: .trailing)

        let stack = NSStackView(views: [header, decisions, scroll, footer])
        stack.orientation = .vertical
        // Same as the other windows: a vertical stack aligns `.centerX`, and `.width` alone does not
        // stretch a scroll view inside it (F-419).
        stack.alignment = .width
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

    // MARK: - Loading

    /// Read the working file and split it. A file we cannot read *safely* disables every decision: the
    /// buttons would otherwise offer to write a guess over the reader's conflict.
    ///
    /// UTF-8 only, on purpose. Writing the file back is this window's whole point, and a decoding
    /// fallback would mean writing a Windows-encoded file back out as UTF-8 — re-encoding every line the
    /// reader did not touch, as a side effect of resolving a conflict. Such a file is named as such and
    /// sent to the editor, which is where a re-encoding decision belongs.
    func reload() {
        let data = FileManager.default.contents(atPath: absolute)
        guard let data else {
            file = nil
            choices = []
            header.stringValue = String(format: L("%@ — the file could not be read."), relative)
            setDecisionsEnabled(false)
            table.reloadData()
            return
        }
        guard let text = String(data: data, encoding: .utf8) else {
            file = nil
            choices = []
            header.stringValue = String(format:
                L("%@ — not a UTF-8 text file. Resolve it in the editor."), relative)
            setDecisionsEnabled(false)
            table.reloadData()
            return
        }
        guard let parsed = PluginGit.parseConflicts(text) else {
            file = nil
            choices = []
            header.stringValue = String(format:
                L("%@ — the conflict markers in this file are not readable. Resolve it in the editor."),
                relative)
            setDecisionsEnabled(false)
            table.reloadData()
            return
        }
        file = parsed
        choices = Array(repeating: .unresolved, count: parsed.hunks.count)
        setDecisionsEnabled(!parsed.hunks.isEmpty)
        table.reloadData()
        if !parsed.hunks.isEmpty {
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        updateHeader()
    }

    private func setDecisionsEnabled(_ enabled: Bool) {
        for button in [oursButton, theirsButton, bothButton, resetButton, writeButton, stageButton] {
            button.isEnabled = enabled
        }
        // Comparing and editing stay available: they are exactly what a file this window cannot parse
        // needs, and neither of them writes anything.
        compareButton.isEnabled = true
        editButton.isEnabled = true
    }

    private func updateHeader() {
        guard let file else { return }
        if file.hunks.isEmpty {
            header.stringValue = String(format: L("%@ — no conflict markers in this file."), relative)
            return
        }
        let decided = choices.filter { $0 != .unresolved }.count
        header.stringValue = String(format: L("%@ — %lld conflict(s), %lld decided"),
                                   relative, file.hunks.count, decided)
    }

    // MARK: - Deciding

    @objc private func takeOurs()   { decide(.ours) }
    @objc private func takeTheirs() { decide(.theirs) }
    @objc private func takeBoth()   { decide(.both) }
    @objc private func undecide()   { decide(.unresolved) }

    /// Apply a decision to every selected row, and step to the next one — resolving a file with eight
    /// conflicts should not need eight clicks *plus* eight selections.
    private func decide(_ choice: PluginGit.ConflictChoice) {
        let rows = table.selectedRowIndexes.isEmpty
            ? IndexSet(integer: table.selectedRow) : table.selectedRowIndexes
        guard !rows.isEmpty, rows.first! >= 0 else { return }
        for row in rows where choices.indices.contains(row) { choices[row] = choice }
        table.reloadData()
        updateHeader()
        let next = (rows.max() ?? 0) + 1
        if choices.indices.contains(next) {
            table.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
            table.scrollRowToVisible(next)
        }
    }

    // MARK: - Writing

    @objc private func write() { writeFile(stage: false) }
    @objc private func writeAndStage() { writeFile(stage: true) }

    /// Write the resolved text, and stage it when asked.
    ///
    /// Staging is what tells git the conflict is over, so it is offered — but only when every hunk has
    /// been decided. Staging a file that still contains `<<<<<<<` is how conflict markers reach a commit,
    /// and git will happily let that happen.
    private func writeFile(stage: Bool) {
        guard let file else { return }
        let undecided = choices.filter { $0 == .unresolved }.count
        if stage, undecided > 0 {
            report(String(format: L("%lld conflict(s) are still open — staging would commit the markers."),
                          undecided))
            return
        }
        let text = PluginGit.render(file, choices: choices)
        do {
            try text.write(toFile: absolute, atomically: true, encoding: .utf8)
        } catch {
            report(L("The file could not be written."))
            return
        }
        guard stage else {
            PluginGitRepo.invalidate()
            services.reloadActivePanel?(services.host)
            report(undecided == 0
                ? L("Written. Stage it to mark the conflict resolved.")
                : String(format: L("Written; %lld conflict(s) still carry their markers."), undecided))
            reload()
            return
        }
        busy.startAnimation(nil)
        let root = self.root, relative = self.relative
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PluginGitRepo.run(["-C", root, "add", "--", relative], combined: true)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                PluginGitRepo.invalidate()
                self.services.reloadActivePanel?(self.services.host)
                let message = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
                self.report(result.ok
                    ? L("Resolved and staged.")
                    : (message.isEmpty ? L("Failed.") : message))
                self.reload()
            }
        }
    }

    // MARK: - The other two routes out

    /// The same compare window phase 3 opened, kept because a hunk one cannot decide from two previews is
    /// exactly what it is for.
    @objc private func compareOursAndTheirs() {
        let specs = PluginGit.conflictSpecs(path: relative)
        let root = self.root, relative = self.relative
        busy.startAnimation(nil)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ours = PluginGitRepo.writeBlob(root: root, spec: specs.ours, path: relative, base: .index)
            let theirs = PluginGitRepo.writeBlob(root: root, spec: specs.theirs, path: relative, base: .head)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                guard let ours, let theirs else {
                    self.report(L("That version could not be read."))
                    return
                }
                ours.withCString { a in
                    theirs.withCString { b in
                        L("ours").withCString { at in
                            L("theirs").withCString { bt in
                                self.services.compareFiles?(self.services.host, a, b, at, bt)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Hand the file to the host: a conflict that needs the two sides interleaved by hand needs an editor,
    /// and the application has one.
    @objc private func openInEditor() {
        absolute.withCString { services.openPath?(services.host, $0) }
    }

    private func report(_ message: String) {
        services.presentInfo?(services.host, L("Resolve Conflict"), message)
    }
}

// MARK: - Table

extension GitConflictView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { file?.hunks.count ?? 0 }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn, let file, file.hunks.indices.contains(row) else { return nil }
        let hunk = file.hunks[row]
        let identifier = NSUserInterfaceItemIdentifier("GitConflictCell")
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
        case "line":
            field.stringValue = String(hunk.startLine)
            field.alignment = .right
        case "state":
            let choice = choices.indices.contains(row) ? choices[row] : .unresolved
            field.alignment = .left
            switch choice {
            case .unresolved:
                field.stringValue = "⚠ " + L("open")
                field.textColor = .secondaryLabelColor
            case .ours:   field.stringValue = "◀ " + L("ours")
            case .theirs: field.stringValue = "▶ " + L("theirs")
            case .both:   field.stringValue = "◆ " + L("both")
            }
        case "ours":
            field.alignment = .left
            field.stringValue = Self.preview(hunk.ours)
            field.toolTip = hunk.ours.joined(separator: "\n")
        default:
            field.alignment = .left
            field.stringValue = Self.preview(hunk.theirs)
            field.toolTip = hunk.theirs.joined(separator: "\n")
        }
        return field
    }

    /// One row per hunk, so a side has to fit on one line: the first line that says something, and how
    /// many more there are. The full text is the tooltip.
    private static func preview(_ lines: [String]) -> String {
        let first = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
        guard lines.count > 1 else { return first }
        return first + String(format: L("  (+%lld line(s))"), lines.count - 1)
    }
}
