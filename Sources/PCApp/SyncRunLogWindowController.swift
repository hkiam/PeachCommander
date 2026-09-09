// SPDX-License-Identifier: Apache-2.0
// SyncRunLogWindowController.swift - What the runs did, and the one thing that can be taken back.
//
// The help file has always said the honest sentence: a deleted file is in the Trash and can be put
// back from the Finder, and that is the whole safety net. It was not usable. Nobody can pick this
// run's files out of several hundred items in there, and the app knew which they were for about two
// seconds before throwing the knowledge away.
//
// So this window is not housekeeping either. It is the one place where "what did that do?" has an
// answer, and where the answer can be acted on for the rows it is safe to act on — the deletions,
// which are in the Trash and can be moved back to a path this record wrote down at the same moment.
// A copy is not offered: taking one back means trashing a file the user may have edited since, and
// the rule this project already states for undoing a creation says the created thing stays.
//
// Its own window rather than a sheet, `over: nil`, for the reason written at the sync window's error
// report: measured, a run that ended with a sheet up would not let the app quit, and a report about
// a finished run has no business holding the window it came from either.

import AppKit
import PCFoundation
import PCOperations

final class SyncRunLogWindowController: NSWindowController {

    /// Called when anything was forgotten or put back, so the window that opened this can re-compare.
    var onChange: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let store: SyncRunStore
    /// The run the opening window has just carried out, so it can be pointed out among the others.
    private let currentRunID: String?

    private let split = NSSplitView()
    private let runTable = NSTableView()
    private let itemTable = NSTableView()
    private let hint = NSTextField(wrappingLabelWithString: "")
    private let resultLabel = NSTextField(labelWithString: "")
    private let putBackButton = NSButton()
    private let revealButton = NSButton()
    private let trashButton = NSButton()
    private let forgetButton = NSButton()

    private var runs: [SyncRunStore.Run] = []
    private var items: [SyncRunItem] = []

    /// Kept alive by itself while it is on screen, `ErrorLogWindowController`'s pattern: nothing else
    /// owns a window that does not belong to the run that opened it.
    private static var presented: [SyncRunLogWindowController] = []

    init(store: SyncRunStore, currentRunID: String?) {
        self.store = store
        self.currentRunID = currentRunID
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 620),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "What Was Done")
        super.init(window: window)
        window.delegate = self
        buildUI()
        reloadRuns()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    static func present(store: SyncRunStore, currentRunID: String?,
                        onChange: (() -> Void)?) -> SyncRunLogWindowController {
        let controller = SyncRunLogWindowController(store: store, currentRunID: currentRunID)
        controller.onChange = onChange
        presented.append(controller)
        controller.window?.center()
        controller.showWindow(nil)
        // After the window has a frame, or the split has nothing to divide.
        controller.split.setPosition(200, ofDividerAt: 0)
        return controller
    }

    private func buildUI() {
        guard let window else { return }
        let content = NSView()

        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.stringValue = String(localized: "Every synchronization is written down here. A file that was deleted into the Trash can be put back where it came from; a copy cannot be taken back, and a file that was overwritten kept no earlier version.")

        // 130 + 190 + 190 + 80 + 66 + 66 + 76 = 798, plus the inter-column spacing, the two 16 pt
        // insets and the scroller, inside 980. Measured, not estimated: at 900 with wider columns a
        // screenshot showed "Gelöscl" and no "Probleme" column at all — the same way the memory
        // list's last column once read "Pf…", and neither shows up in any report.
        for (id, title, width) in [("when", String(localized: "When"), CGFloat(130)),
                                   ("left", String(localized: "Left"), CGFloat(190)),
                                   ("right", String(localized: "Right"), CGFloat(190)),
                                   ("mode", String(localized: "Mode"), CGFloat(80)),
                                   ("copied", String(localized: "Copied"), CGFloat(66)),
                                   ("deleted", String(localized: "Deleted"), CGFloat(66)),
                                   ("problems", String(localized: "Problems"), CGFloat(76))] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            column.title = title
            column.width = width
            runTable.addTableColumn(column)
        }
        runTable.dataSource = self
        runTable.delegate = self
        runTable.rowHeight = 18
        runTable.usesAlternatingRowBackgroundColors = true
        runTable.allowsMultipleSelection = true

        // 44 for the glyph, because `→🗑` is two characters wide and at 34 it came out as `→…` —
        // a direction column that cannot show a direction. 34 + 300 + 120 + 420 also ran a few
        // points past the window, which cut the last character off every path in the last column.
        for (id, title, width) in [("action", "", CGFloat(44)),
                                   ("path", String(localized: "Path"), CGFloat(290)),
                                   ("outcome", String(localized: "Outcome"), CGFloat(120)),
                                   ("now", String(localized: "Now at"), CGFloat(396))] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            column.title = title
            column.width = width
            itemTable.addTableColumn(column)
        }
        itemTable.dataSource = self
        itemTable.delegate = self
        itemTable.rowHeight = 18
        itemTable.usesAlternatingRowBackgroundColors = true
        itemTable.allowsMultipleSelection = true

        let runScroll = NSScrollView()
        runScroll.documentView = runTable
        runScroll.hasVerticalScroller = true
        let itemScroll = NSScrollView()
        itemScroll.documentView = itemTable
        itemScroll.hasVerticalScroller = true
        split.isVertical = false
        split.dividerStyle = .thin
        split.addArrangedSubview(runScroll)
        split.addArrangedSubview(itemScroll)
        // The lower half is the one that grows. Without this the runs table took the whole height
        // and the items table got none — measured on a screenshot: the window showed one run and
        // nothing about what it did, which is the half the window exists for.
        split.setHoldingPriority(NSLayoutConstraint.Priority(260), forSubviewAt: 0)
        split.setHoldingPriority(NSLayoutConstraint.Priority(250), forSubviewAt: 1)
        runScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        itemScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        split.translatesAutoresizingMaskIntoConstraints = false

        configure(putBackButton, String(localized: "Put Back…"), #selector(putBackSelected))
        configure(revealButton, String(localized: "Reveal in Finder"), #selector(revealSelected))
        configure(trashButton, String(localized: "Show in Trash"), #selector(showInTrash))
        configure(forgetButton, String(localized: "Forget"), #selector(forgetSelected))
        let forgetAll = NSButton(title: String(localized: "Forget All"), target: self,
                                 action: #selector(forgetEverything))
        forgetAll.bezelStyle = .rounded
        let close = NSButton(title: String(localized: "Close"), target: self,
                             action: #selector(dismissWindow))
        close.bezelStyle = .rounded
        close.keyEquivalent = "\u{1b}"

        resultLabel.font = NSFont.systemFont(ofSize: 11)
        resultLabel.textColor = .secondaryLabelColor
        resultLabel.lineBreakMode = .byTruncatingTail

        let buttons = NSStackView(views: [putBackButton, revealButton, trashButton, NSView(),
                                          forgetButton, forgetAll, close])
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        hint.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(hint)
        content.addSubview(split)
        content.addSubview(resultLabel)
        content.addSubview(buttons)
        window.contentView = content
        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            hint.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            hint.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            split.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 10),
            split.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            split.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            resultLabel.topAnchor.constraint(equalTo: split.bottomAnchor, constant: 10),
            resultLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            resultLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 8),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            split.heightAnchor.constraint(greaterThanOrEqualToConstant: 380),
        ])
    }

    private func configure(_ button: NSButton, _ title: String, _ action: Selector) {
        button.title = title
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        button.isEnabled = false
    }

    // MARK: - Contents

    private func reloadRuns() {
        runs = store.runs()
        runTable.reloadData()
        if runs.indices.contains(0), runTable.selectedRow < 0 {
            let index = runs.firstIndex { $0.id == currentRunID } ?? 0
            runTable.selectRowIndexes([index], byExtendingSelection: false)
        }
        reloadItems()
    }

    private func reloadItems() {
        items = selectedRun.map { store.items(id: $0.id) } ?? []
        itemTable.reloadData()
        updateButtons()
    }

    private var selectedRun: SyncRunStore.Run? {
        let row = runTable.selectedRow
        return runs.indices.contains(row) ? runs[row] : nil
    }

    private var selectedItems: [SyncRunItem] {
        itemTable.selectedRowIndexes.compactMap { items.indices.contains($0) ? items[$0] : nil }
    }

    private func updateButtons() {
        let chosenItems = selectedItems
        forgetButton.isEnabled = !runTable.selectedRowIndexes.isEmpty
        revealButton.isEnabled = chosenItems.contains {
            $0.destinationSide == "localDir" && $0.destinationPath != nil
        }
        trashButton.isEnabled = chosenItems.contains { $0.trashedPath != nil }
        // The offer is computed rather than guessed at, and *before* the confirmation — a gated
        // action that cannot work must not be proposed (`DefaultAutomationCore.refusalBeforeAsking`).
        putBackButton.isEnabled = !plannedPutBack().steps.isEmpty
    }

    /// What could be put back out of the current selection, and why the rest could not.
    ///
    /// The selection narrows it; with nothing selected the whole run is considered, which is what
    /// somebody means by pressing the button after opening the window on the run that just ran.
    private func plannedPutBack() -> (steps: [SyncUndoPlan.Step], refusals: [SyncUndoPlan.Refusal]) {
        guard let run = selectedRun, run.isReadable else { return ([], []) }
        let chosen = selectedItems
        let considered = chosen.isEmpty ? items : chosen
        return SyncUndoPlan.plan(header: run.header, items: considered,
                                 probe: SyncUndoRunner.facts(at:))
    }

    // MARK: - Actions

    @objc private func putBackSelected() {
        guard let run = selectedRun else { return }
        let (steps, refusals) = plannedPutBack()
        guard !steps.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = String(localized: "Put back \(steps.count) item(s)?")
        var text = String(localized: "Each one is moved out of the Trash to the path it was deleted from. Anything that is in the way is left alone.")
        if !refusals.isEmpty {
            // The refusals in the same breath as the offer, because "put back 3" when 12 were
            // deleted is a number somebody has to be able to account for.
            text += "\n\n" + refusals.prefix(8)
                .map { "• \($0.subject): \($0.reason)" }.joined(separator: "\n")
            if refusals.count > 8 {
                text += "\n" + String(localized: "… and \(refusals.count - 8) more.")
            }
        }
        alert.informativeText = text
        alert.addButton(withTitle: String(localized: "Put Back"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let report = SyncUndoRunner.run(steps, header: run.header)
        if !report.putBack.isEmpty {
            store.markUndone(id: run.id, paths: Set(report.putBack),
                             reason: String(localized: "already put back"))
        }
        resultLabel.stringValue =
            String(localized: "Put back \(report.putBack.count) of \(steps.count) item(s).")
        if !report.failures.isEmpty {
            ErrorLogWindowController.present(over: nil, summary: resultLabel.stringValue,
                                             entries: report.failures.map { ($0.path, $0.message) })
        }
        reloadItems()
        onChange?()
    }

    @objc private func revealSelected() {
        let urls = selectedItems.compactMap { item -> URL? in
            guard item.destinationSide == "localDir", let path = item.destinationPath,
                  FileManager.default.fileExists(atPath: path) else { return nil }
            return URL(fileURLWithPath: path)
        }
        guard !urls.isEmpty else { NSSound.beep(); return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    /// Point the Finder at the items in the Trash. The whole reason the trashed path is recorded:
    /// "it is in the Trash" is a sentence, this is an answer.
    @objc private func showInTrash() {
        let urls = selectedItems.compactMap { item -> URL? in
            guard let path = item.trashedPath,
                  FileManager.default.fileExists(atPath: path) else { return nil }
            return URL(fileURLWithPath: path)
        }
        guard !urls.isEmpty else { NSSound.beep(); return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    @objc private func forgetSelected() {
        let chosen = runTable.selectedRowIndexes.compactMap {
            runs.indices.contains($0) ? runs[$0] : nil
        }
        guard !chosen.isEmpty else { return }
        // Asked, because the record is the only copy — and worded as what it costs rather than as a
        // danger: forgetting a run changes nothing about the folders, it only takes away the offer.
        let alert = NSAlert()
        alert.messageText = String(localized: "Forget \(chosen.count) run(s)?")
        alert.informativeText = String(localized: "The folders are not touched. What is lost is the record of what was done, and with it the offer to put anything from those runs back.")
        alert.addButton(withTitle: String(localized: "Forget"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        for run in chosen { store.forget(id: run.id) }
        reloadRuns()
        onChange?()
    }

    /// The whole of the answer to "this holds the absolute paths of both trees": there is no age
    /// setting and no switch to turn recording off, there is this.
    @objc private func forgetEverything() {
        guard !runs.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = String(localized: "Forget every recorded run?")
        alert.informativeText = String(localized: "The folders are not touched. What is lost is the record of what was done, and with it the offer to put anything back.")
        alert.addButton(withTitle: String(localized: "Forget All"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.forgetAll()
        reloadRuns()
        onChange?()
    }

    @objc private func dismissWindow() {
        window?.performClose(nil)
    }

    // MARK: - Automation (DEBUG)

    #if DEBUG
    func automationReport() -> String {
        var out = "window=open\nruns=\(runs.count)\nselected=\(selectedRun?.id ?? "none")\n"
        out += "items=\(items.count)\n"
        out += "putBackEnabled=\(putBackButton.isEnabled)\n"
        let (steps, refusals) = plannedPutBack()
        out += "putBackSteps=\(steps.count)\nputBackRefusals=\(refusals.count)\n"
        for refusal in refusals { out += "refusal=\(refusal.subject): \(refusal.reason)\n" }
        out += "result=\(resultLabel.stringValue)\n"
        return out
    }

    /// Put back without the confirmation, which a script cannot answer — the reason
    /// `automationSynchronize` exists.
    func automationPutBack() -> String {
        guard let run = selectedRun else { return "putBack=norun\n" }
        let (steps, refusals) = plannedPutBack()
        let report = SyncUndoRunner.run(steps, header: run.header)
        if !report.putBack.isEmpty {
            store.markUndone(id: run.id, paths: Set(report.putBack),
                             reason: String(localized: "already put back"))
        }
        var out = "putBack=\(report.putBack.count)\nplanned=\(steps.count)\n"
        out += "refused=\(refusals.count + report.refusals.count)\n"
        out += "failed=\(report.failures.count)\n"
        for path in report.putBack { out += "back=\(path)\n" }
        for refusal in refusals { out += "refusal=\(refusal.subject): \(refusal.reason)\n" }
        for refusal in report.refusals { out += "refusal=\(refusal.path): \(refusal.reason)\n" }
        for failure in report.failures { out += "failure=\(failure.path): \(failure.message)\n" }
        reloadItems()
        onChange?()
        return out
    }

    func automationForgetAll() {
        store.forgetAll()
        reloadRuns()
        onChange?()
    }

    /// Close the window. A scenario has to, or the app keeps it and the run looks unfinished.
    func automationClose() { dismissWindow() }
    #endif
}

extension SyncRunLogWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        onDismiss?()
        Self.presented.removeAll { $0 === self }
    }
}

extension SyncRunLogWindowController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === runTable ? runs.count : items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let field = NSTextField(labelWithString: "")
        field.isBordered = false
        field.drawsBackground = false
        field.font = Fonts.system13
        // Truncated in the middle, because the end of a path is what tells two of them apart.
        field.lineBreakMode = .byTruncatingMiddle

        if tableView === runTable {
            guard runs.indices.contains(row) else { return nil }
            fill(field, run: runs[row], column: tableColumn?.identifier.rawValue)
        } else {
            guard items.indices.contains(row) else { return nil }
            fill(field, item: items[row], column: tableColumn?.identifier.rawValue)
        }
        return field
    }

    private func fill(_ field: NSTextField, run: SyncRunStore.Run, column: String?) {
        let header = run.header
        switch column {
        case "when":
            // An unreadable record says what it *is* rather than showing empty cells and leaving
            // the reader to guess — the memory list's rule.
            field.stringValue = run.isReadable
                ? Self.dateFormatter.string(from: header.runDate)
                : String(localized: "(unreadable)")
        case "left": field.stringValue = run.isReadable ? header.leftRoot : run.id
        case "right": field.stringValue = run.isReadable ? header.rightRoot : ""
        case "mode": field.stringValue = run.isReadable ? header.mode : "—"
        case "copied":
            field.stringValue = run.isReadable ? "\(header.copied)" : "—"
            field.alignment = .right
        case "deleted":
            field.stringValue = run.isReadable ? "\(header.deleted)" : "—"
            field.alignment = .right
        case "problems":
            field.stringValue = run.isReadable ? "\(header.problems)" : "—"
            field.alignment = .right
            if run.isReadable, header.problems > 0 { field.textColor = .systemOrange }
        default: field.stringValue = ""
        }
        if run.id == currentRunID { field.font = NSFont.boldSystemFont(ofSize: 13) }
        if !run.isReadable { field.textColor = .systemOrange }
        if !header.itemsListed, column == "problems" { field.textColor = .systemOrange }
    }

    private func fill(_ field: NSTextField, item: SyncRunItem, column: String?) {
        switch column {
        case "action":
            // The same glyph vocabulary the result grid uses, so a row means the same thing in both
            // places. Mapped from the record's strings rather than shared, because the record holds
            // strings on purpose — it is read by versions that predate the action it names.
            field.stringValue = Self.glyph(for: item)
            field.alignment = .center
        case "path": field.stringValue = item.relativePath
        case "outcome":
            field.stringValue = Self.outcomeText(item)
            if item.undoneAt != nil { field.textColor = .secondaryLabelColor }
        case "now":
            if item.undoneAt != nil {
                field.stringValue = item.destinationPath ?? ""
            } else if let trashed = item.trashedPath {
                field.stringValue = trashed
            } else if item.outcome == SyncRunItem.Outcome.deleted {
                field.stringValue = String(localized: "gone for good")
                field.textColor = .systemOrange
            } else {
                field.stringValue = item.destinationPath ?? ""
            }
        default: field.stringValue = ""
        }
    }

    private static func glyph(for item: SyncRunItem) -> String {
        if item.basis == "propagatedDeletion" {
            return item.action == "deleteRight" ? "⇒🗑" : "🗑⇐"
        }
        switch item.action {
        case "copyToRight": return "→"
        case "copyToLeft": return "←"
        case "deleteRight": return "→🗑"
        case "deleteLeft": return "🗑←"
        default: return ""
        }
    }

    private static func outcomeText(_ item: SyncRunItem) -> String {
        switch item.outcome {
        case SyncRunItem.Outcome.copied:
            // Which kind of copy, because that is the difference between "there is a version of
            // this somewhere" and "the previous one is gone".
            switch item.created {
            case .some(true): return String(localized: "Created")
            case .some(false): return String(localized: "Overwritten")
            case nil: return String(localized: "Copied")
            }
        case SyncRunItem.Outcome.deleted: return String(localized: "Deleted")
        case SyncRunItem.Outcome.refused: return String(localized: "Kept back")
        case SyncRunItem.Outcome.failed: return String(localized: "Failed")
        default: return String(localized: "Nothing happened")
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        if table === runTable { reloadItems() } else { updateButtons() }
    }

    private static let dateFormatter =
        PanelDateFormatter.makeFormatter(pattern: PanelDateFormatter.defaultPattern)
}
