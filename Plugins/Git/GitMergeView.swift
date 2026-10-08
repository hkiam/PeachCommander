// SPDX-License-Identifier: Apache-2.0
// GitMergeView.swift — the three-way merge editor (phase 9).
//
// Above: the current conflict three times — ours, the common base, theirs — with the lines each side
// changed against the base tinted. Below: the whole file as it will be written, editable, with the
// conflicts still to decide as git's own markers. A button takes ours, theirs, both in either order or
// the base for the current conflict; anything else is typed into the result. The markers are the state:
// what is left to do is whatever markers the result still has, so a hand edit and a button are the same
// kind of change and neither can lose the other.
//
// The base comes from the index (stages 1–3) re-merged with `git merge-file --diff3` — in memory, the
// working file is not touched until Save — and is used only while the file is still exactly what the
// merge left (`PluginGit.adoptBase`). After that the editor works on the file as it is, without a base.
//
// Phase 5a called a merge editor out of scope and kept the decision-only resolver (GitConflictView); it
// stays, for the quick case. The plan's phase 9 placed this on the host's compare window; the compare
// window has no editable pane and no notion of a conflict, and teaching it both would have put git into
// the host. So it is a plugin window, and the diff it shows is git's own merge, not a second algorithm.

import AppKit

@MainActor
final class GitMergeView: NSView, NSTextViewDelegate {
    private let services: PcHostServices
    private var theme: PluginTheme
    private let root: String
    private let relative: String
    private let absolute: String
    /// Called after the file was written (and staged): the panel reloads.
    var onSaved: (() -> Void)?

    private let header = NSTextField(labelWithString: "")
    private let previousButton = NSButton()
    private let nextButton = NSButton()
    private let paneTitles = [NSTextField(labelWithString: ""), NSTextField(labelWithString: ""),
                              NSTextField(labelWithString: "")]
    private let panes = [GitMergeView.makeTextView(editable: false), GitMergeView.makeTextView(editable: false),
                         GitMergeView.makeTextView(editable: false)]
    private let result = GitMergeView.makeTextView(editable: true)
    private let resultTitle = NSTextField(labelWithString: "")
    private var pickButtons: [(NSButton, PluginGit.MergePick)] = []
    private let remainingLabel = NSTextField(labelWithString: "")
    private let saveButton = NSButton()
    private let stageButton = NSButton()
    private let revertButton = NSButton()
    private let busy = NSProgressIndicator()

    /// The result, parsed: nil while its markers do not make sense (edited by hand mid-way).
    private var parsed: PluginGit.ConflictFile?
    private var current = 0
    private var hasBase = false
    private var loadedText = ""
    /// Why the file is not shown, when it could not be read as UTF-8 text: then nothing can be saved —
    /// an empty result written back would be an empty file staged as the resolution.
    private var unreadable: String?

    init(services: PcHostServices, root: String, relative: String) {
        self.services = services
        self.root = root
        self.relative = relative
        self.absolute = (root as NSString).appendingPathComponent(relative)
        self.theme = PluginTheme(services)
        super.init(frame: NSRect(x: 0, y: 0, width: 1100, height: 720))
        build()
        applyTheme()
        load()
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
        text.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticDashSubstitutionEnabled = false
        text.isAutomaticTextReplacementEnabled = false
        text.isAutomaticSpellingCorrectionEnabled = false
        text.isContinuousSpellCheckingEnabled = false
        text.smartInsertDeleteEnabled = false
        // Code does not wrap: a long line scrolls, so the three panes stay line for line comparable.
        text.isHorizontallyResizable = true
        text.textContainer?.widthTracksTextView = false
        text.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        return (scroll, text)
    }

    private func build() {
        header.font = .systemFont(ofSize: 12, weight: .semibold)
        header.lineBreakMode = .byTruncatingMiddle
        for (button, title, symbol, action) in [
            (previousButton, L("Previous conflict"), "chevron.up", #selector(previousConflict)),
            (nextButton, L("Next conflict"), "chevron.down", #selector(nextConflict)),
        ] as [(NSButton, String, String, Selector)] {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            button.toolTip = title
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.target = self
            button.action = action
        }
        busy.style = .spinning
        busy.controlSize = .small
        busy.isDisplayedWhenStopped = false
        let top = NSStackView(views: [header, busy, previousButton, nextButton])
        top.orientation = .horizontal
        top.spacing = 6
        header.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let columns = NSSplitView()
        columns.isVertical = true
        columns.dividerStyle = .thin
        var columnViews: [NSView] = []
        for (index, pane) in panes.enumerated() {
            let title = paneTitles[index]
            title.font = .systemFont(ofSize: 11, weight: .semibold)
            title.lineBreakMode = .byTruncatingTail
            let column = NSStackView(views: [title, pane.scroll])
            column.orientation = .vertical
            column.alignment = .leading
            column.spacing = 2
            pane.scroll.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
            pane.scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
            columns.addArrangedSubview(column)
            columnViews.append(column)
        }
        // A third each, as a preference: the divider can still be dragged.
        for column in columnViews {
            let third = column.widthAnchor.constraint(equalTo: columns.widthAnchor, multiplier: 1.0 / 3.0, constant: -2)
            third.priority = .init(490)
            third.isActive = true
        }

        for (pick, title) in [(PluginGit.MergePick.ours, L("Take ours")), (.theirs, L("Take theirs")),
                              (.oursThenTheirs, L("Ours, then theirs")), (.theirsThenOurs, L("Theirs, then ours")),
                              (.base, L("Take the base"))] {
            let button = NSButton(title: title, target: self, action: #selector(pick(_:)))
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.font = .systemFont(ofSize: 11)
            button.tag = pickButtons.count
            pickButtons.append((button, pick))
        }
        let picks = NSStackView(views: pickButtons.map(\.0))
        picks.orientation = .horizontal
        picks.spacing = 6

        let upper = NSStackView(views: [columns, picks])
        upper.orientation = .vertical
        upper.alignment = .leading
        upper.distribution = .fill
        upper.spacing = 6
        columns.setContentHuggingPriority(.init(1), for: .vertical)
        columns.widthAnchor.constraint(equalTo: upper.widthAnchor).isActive = true

        resultTitle.font = .systemFont(ofSize: 11, weight: .semibold)
        resultTitle.stringValue = L("Result — edit freely; the markers are what is left to decide")
        result.text.delegate = self
        let lower = NSStackView(views: [resultTitle, result.scroll])
        lower.orientation = .vertical
        lower.alignment = .leading
        lower.distribution = .fill
        lower.spacing = 2
        result.scroll.setContentHuggingPriority(.init(1), for: .vertical)
        result.scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        result.scroll.widthAnchor.constraint(equalTo: lower.widthAnchor).isActive = true

        let split = NSSplitView()
        split.isVertical = false
        split.dividerStyle = .thin
        split.addArrangedSubview(upper)
        split.addArrangedSubview(lower)
        let share = upper.heightAnchor.constraint(equalTo: split.heightAnchor, multiplier: 0.42)
        share.priority = .init(500)
        share.isActive = true

        for (button, title, action) in [
            (revertButton, L("Start over"), #selector(startOver)),
            (saveButton, L("Save"), #selector(save)),
            (stageButton, L("Save and stage"), #selector(saveAndStage)),
        ] as [(NSButton, String, Selector)] {
            button.title = title
            button.bezelStyle = .rounded
            button.target = self
            button.action = action
        }
        stageButton.keyEquivalent = "\r"
        stageButton.keyEquivalentModifierMask = [.command]
        remainingLabel.textColor = .secondaryLabelColor
        let footer = NSStackView(views: [remainingLabel, NSView(), revertButton, saveButton, stageButton])
        footer.orientation = .horizontal
        footer.spacing = 8

        let stack = NSStackView(views: [top, split, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        // Fill, not the default gravity areas: with those the split view keeps its fitting height —
        // next to nothing — and the window below it stays empty (measured, first screenshot).
        stack.distribution = .fill
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        for view in [top, split, footer] as [NSView] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true
        }
        split.setContentHuggingPriority(.init(1), for: .vertical)
        // The header row is one line high, said outright: with hugging alone the stack handed it half
        // the window (measured — the spinner beside the title hugs nothing vertically).
        top.heightAnchor.constraint(equalToConstant: 24).isActive = true
        busy.heightAnchor.constraint(equalToConstant: 16).isActive = true
        // A stack view's own hugging (not its content hugging), as the panel's button row learned.
        for view in [top, footer, upper.arrangedSubviews.last!] {
            (view as? NSStackView)?.setHuggingPriority(.defaultHigh, for: .vertical)
        }
    }

    func applyTheme() {
        theme = PluginTheme(services)
        wantsLayer = true
        layer?.backgroundColor = theme.windowBackground.cgColor
        for label in paneTitles + [header, resultTitle] { label.textColor = theme.text }
        for view in panes.map(\.text) + [result.text] {
            view.backgroundColor = theme.background
            view.textColor = theme.text
            view.insertionPointColor = theme.text
        }
        refresh(scroll: false)
    }

    // MARK: - Loading

    private func load() {
        busy.startAnimation(nil)
        let root = self.root, relative = self.relative, absolute = self.absolute
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // UTF-8 only, and refused otherwise, as the conflict window does: a decoding fallback would
            // write every untouched line back re-encoded, and a file that is not there (deleted on one
            // side) has nothing to merge here.
            let data = FileManager.default.contents(atPath: absolute)
            let decoded = data.flatMap { String(data: $0, encoding: .utf8) }
            let working = decoded ?? ""
            let start = decoded == nil ? nil : Self.textWithBase(working: working, root: root, relative: relative)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy.stopAnimation(nil)
                if decoded == nil {
                    self.unreadable = data == nil
                        ? String(format: L("%@ — the file could not be read."), relative)
                        : String(format: L("%@ — not a UTF-8 text file. Resolve it in the editor."), relative)
                    self.result.text.isEditable = false
                }
                self.loadedText = start ?? working
                self.hasBase = start != nil || (PluginGit.parseConflicts(working)?.hunks.allSatisfy { $0.base != nil } ?? false)
                self.result.text.string = self.loadedText
                self.current = 0
                self.reparse()
                self.refresh(scroll: true)
            }
        }
    }

    /// The working file with every conflict's base, from the index's three stages re-merged — or nil when
    /// that cannot be had (a side added on one branch only has no base; an edited file is kept as is).
    private nonisolated static func textWithBase(working: String, root: String, relative: String) -> String? {
        guard let conflicts = PluginGit.parseConflicts(working), let first = conflicts.hunks.first,
              first.base == nil else { return nil }
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pc-git-merge-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var paths: [String] = []
        for stage in 1...3 {
            guard let data = PluginGitRepo.runData(["-C", root, "--no-optional-locks", "show",
                                                    PluginGit.mergeStageSpec(stage, path: relative)]) else { return nil }
            let url = directory.appendingPathComponent("stage\(stage)")
            guard (try? data.write(to: url)) != nil else { return nil }
            paths.append(url.path)
        }
        let labels = (ours: first.oursLabel, base: L("base"), theirs: first.theirsLabel)
        let diff3 = PluginGitRepo.run(PluginGit.mergeFileArguments(ours: paths[1], base: paths[0], theirs: paths[2],
                                                                   labels: labels)).out
        let merged = PluginGitRepo.run(PluginGit.mergeFileArguments(ours: paths[1], base: paths[0], theirs: paths[2],
                                                                    labels: labels, diff3: false)).out
        return PluginGit.adoptBase(working: working, merged: merged, diff3: diff3)
    }

    // MARK: - State

    private func reparse() {
        parsed = PluginGit.parseConflicts(result.text.string)
        let count = parsed?.hunks.count ?? 0
        if current >= count { current = max(0, count - 1) }
    }

    private func refresh(scroll: Bool) {
        if let unreadable {
            header.stringValue = unreadable
            remainingLabel.stringValue = ""
            for button in pickButtons.map(\.0) + [previousButton, nextButton, saveButton, stageButton, revertButton] {
                button.isEnabled = false
            }
            return
        }
        let count = parsed?.hunks.count ?? 0
        let name = (relative as NSString).lastPathComponent
        if parsed == nil {
            header.stringValue = name
            remainingLabel.stringValue = L("The markers were edited and no longer pair up — finish by hand, or start over.")
        } else if count == 0 {
            header.stringValue = name
            remainingLabel.stringValue = L("No conflicts left. Save and stage to mark the file resolved.")
        } else {
            header.stringValue = String(format: L("%@ — conflict %lld of %lld"), name, current + 1, count)
            remainingLabel.stringValue = String(format: L("%lld conflict(s) left"), count)
        }
        previousButton.isEnabled = count > 1 && current > 0
        nextButton.isEnabled = count > 1 && current < count - 1
        let hunk = parsed.flatMap { $0.hunks.indices.contains(current) ? $0.hunks[current] : nil }
        for (button, pick) in pickButtons {
            button.isEnabled = hunk.flatMap { PluginGit.lines(of: $0, pick) } != nil
        }
        stageButton.isEnabled = count == 0 && parsed != nil
        showPanes(hunk)
        highlightMarkers()
        if scroll, hunk != nil, let line = PluginGit.markerLine(of: current, in: result.text.string) {
            scrollResult(toLine: line)
        }
    }

    private func showPanes(_ hunk: PluginGit.ConflictHunk?) {
        let ours = hunk?.ours ?? [], theirs = hunk?.theirs ?? []
        let base = hunk?.base
        paneTitles[0].stringValue = L("Ours") + (hunk.map { $0.oursLabel.isEmpty ? "" : " — " + $0.oursLabel } ?? "")
        paneTitles[1].stringValue = L("Base") + (base == nil && hunk != nil ? " — " + L("not available") : "")
        paneTitles[2].stringValue = L("Theirs") + (hunk.map { $0.theirsLabel.isEmpty ? "" : " — " + $0.theirsLabel } ?? "")
        set(panes[0].text, ours, changed: PluginGit.changedLines(ours, base: base), tint: .systemBlue)
        set(panes[1].text, base ?? [], changed: [], tint: .clear)
        set(panes[2].text, theirs, changed: PluginGit.changedLines(theirs, base: base), tint: .systemPurple)
    }

    private func set(_ view: NSTextView, _ lines: [String], changed: Set<Int>, tint: NSColor) {
        let text = NSMutableAttributedString()
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        for (index, line) in lines.enumerated() {
            var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: theme.text]
            if changed.contains(index) {
                attributes[.backgroundColor] = tint.withAlphaComponent(theme.isDark ? 0.28 : 0.16)
            }
            text.append(NSAttributedString(string: line + "\n", attributes: attributes))
        }
        view.textStorage?.setAttributedString(text)
    }

    /// The markers in the result stand out, so what is left to decide can be seen while scrolling.
    private func highlightMarkers() {
        guard let storage = result.text.textStorage else { return }
        let text = storage.string as NSString
        storage.beginEditing()
        storage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: text.length))
        storage.addAttribute(.foregroundColor, value: theme.text, range: NSRange(location: 0, length: text.length))
        var location = 0
        while location < text.length {
            let line = text.lineRange(for: NSRange(location: location, length: 0))
            let content = text.substring(with: line)
            if ["<<<<<<<", "|||||||", "=======", ">>>>>>>"].contains(where: { content.hasPrefix($0) }) {
                storage.addAttribute(.backgroundColor, value: NSColor.systemRed.withAlphaComponent(theme.isDark ? 0.3 : 0.15),
                                     range: line)
            }
            location = NSMaxRange(line)
        }
        storage.endEditing()
    }

    private func scrollResult(toLine target: Int) {
        let text = result.text.string as NSString
        var location = 0, line = 0
        while line < target, location < text.length {
            location = NSMaxRange(text.lineRange(for: NSRange(location: location, length: 0)))
            line += 1
        }
        let range = NSRange(location: min(location, text.length), length: 0)
        result.text.scrollRangeToVisible(range)
        result.text.setSelectedRange(range)
    }

    func textDidChange(_ notification: Notification) {
        reparse()
        refresh(scroll: false)
    }

    // MARK: - Actions

    @objc private func previousConflict() { current = max(0, current - 1); refresh(scroll: true) }
    @objc private func nextConflict() { current += 1; reparse(); refresh(scroll: true) }

    @objc private func pick(_ sender: NSButton) {
        guard let parsed, parsed.hunks.indices.contains(current), pickButtons.indices.contains(sender.tag),
              let lines = PluginGit.lines(of: parsed.hunks[current], pickButtons[sender.tag].1) else { return }
        let replaced = PluginGit.resolving(parsed, hunk: current, with: lines)
        // Through the text view, so Undo takes a pick back like any typing.
        let whole = NSRange(location: 0, length: (result.text.string as NSString).length)
        if result.text.shouldChangeText(in: whole, replacementString: replaced) {
            result.text.replaceCharacters(in: whole, with: replaced)
            result.text.didChangeText()
        }
        reparse()
        refresh(scroll: true)
    }

    @objc private func startOver() {
        let alert = NSAlert()
        alert.messageText = L("Start over?")
        alert.informativeText = L("Every decision made in this window since it opened is undone. The file on disk is not touched.")
        alert.addButton(withTitle: L("Start over"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        result.text.string = loadedText
        current = 0
        reparse()
        refresh(scroll: true)
    }

    @objc private func save() { write(stage: false) }
    @objc private func saveAndStage() { write(stage: true) }

    /// Written as it stands; staged only without markers — git would commit `<<<<<<<` without a word.
    private func write(stage: Bool) {
        guard unreadable == nil else { return }
        let text = result.text.string
        if stage, parsed == nil || parsed?.hunks.isEmpty == false {
            GitCommitActions.report(services, L("Merge"), L("Conflicts are left in the result. Decide them, or save without staging."))
            return
        }
        do {
            try text.write(toFile: absolute, atomically: true, encoding: .utf8)
        } catch {
            GitCommitActions.report(services, L("Merge"), error.localizedDescription)
            return
        }
        loadedText = text
        guard stage else {
            PluginGitRepo.invalidate()
            onSaved?()
            window?.close()
            return
        }
        let root = self.root, relative = self.relative, box = ServicesBox(services)
        busy.startAnimation(nil)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = PluginGitRepo.run(["-C", root, "add", "--", relative], combined: true)
            DispatchQueue.main.async {
                self?.busy.stopAnimation(nil)
                PluginGitRepo.invalidate()
                guard result.ok else { GitCommitActions.report(box.services, L("Merge"), result.out); return }
                self?.onSaved?()
                self?.window?.close()
            }
        }
    }

    /// For the verification dump.
    func automationSummary() -> [String] {
        ["mergeUnreadable=\(unreadable ?? "")", "mergeStageEnabled=\(stageButton.isEnabled)",
         "mergeConflicts=\(parsed?.hunks.count ?? -1)", "mergeCurrent=\(current)", "mergeBase=\(hasBase)",
         "mergeOurs=" + panes[0].text.string.replacingOccurrences(of: "\n", with: "|"),
         "mergeBaseText=" + panes[1].text.string.replacingOccurrences(of: "\n", with: "|"),
         "mergeTheirs=" + panes[2].text.string.replacingOccurrences(of: "\n", with: "|")]
    }

    /// Verification only: take a pick for the current conflict without a click.
    func automationPick(_ pick: PluginGit.MergePick) {
        guard let index = pickButtons.firstIndex(where: { $0.1 == pick }) else { return }
        self.pick(pickButtons[index].0)
    }
}
