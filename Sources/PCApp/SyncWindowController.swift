// SPDX-License-Identifier: Apache-2.0
// SyncWindowController.swift - Synchronize Directories (I12 T05/T06, F-192)
//
// Dialog: two directory lines, a file mask, the comparison options (with
// subdirs / by content / ignore date / asymmetric), a Compare button that scans
// both trees and classifies each item via SyncModel, a colored result grid, and
// a Synchronize button that executes the copies/deletes. Local filesystem only
// for now (archive/FTP sides are F-193 → I15). Presets (F-194) are deferred.

import AppKit
import PCArchive
import PCFoundation
import PCOperations

/// One side of a sync: a local directory, or a whole `.zip` archive (F-193). A zip
/// side compares/updates from the archive root; timestamps in a zip are unreliable
/// (ZipWriter re-stamps on write), so the UI forces content comparison for it.

final class SyncWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    var onClose: (() -> Void)?
    /// Reload the panels after a successful sync.
    var reload: (() async -> Void)?
    /// Where named sync presets are persisted (F-194).
    private let presetStore: SyncPresetStore?
    private let presetPopup = NSPopUpButton()

    private var leftSide: SyncSide
    private var rightSide: SyncSide
    /// A zip side has unreliable timestamps, so comparison is forced to by-content.
    private var hasZipSide: Bool { leftSide.isZip || rightSide.isZip }

    private let leftField = NSTextField()
    private let rightField = NSTextField()
    private let maskField = NSTextField()
    private let subdirsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let byContentButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let ignoreDateButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let asymmetricButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let ignoreHiddenButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)   // F-192
    /// FAT/DST: absorb a whole-hour difference rather than calling it a change (F-192 follow-up).
    private let daylightButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    /// Off by default, which is what `SyncOptions` always declared and what a Mac volume usually is.
    private let caseButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let tableView = NSTableView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let syncButton = NSButton(title: "", target: nil, action: nil)
    /// Also the Stop button: while a comparison runs it says so and cancels it.
    private let compareButton = NSButton(title: "", target: nil, action: nil)
    /// The only sign a scan of a large tree gives that it is alive at all, next to the count in the
    /// status line — a tree of a few hundred thousand entries spends minutes in `SyncScanner`.
    private let progressSpinner = NSProgressIndicator()
    private let filterPopup = NSPopUpButton()
    private let hideEqualButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    private var results: [SyncResult] = []
    // Per-row state (F-192): included in the sync, and the (possibly overridden)
    // direction/action. Parallel to `results`.
    private var rowIncluded: [Bool] = []
    private var rowAction: [SyncAction] = []
    /// Which entries of `results` the filter leaves on screen, in table order. Every table callback
    /// goes through this, and a cell's `tag` carries the *`results`* index rather than the table row
    /// so a click keeps meaning the same row when the filter changes under it.
    private var visibleRows: [Int] = []
    /// The running comparison, held so the Stop button can cancel it.
    private var compareTask: Task<Void, Never>?
    /// The running synchronization, held for the same reason: copying a large tree takes as long as
    /// comparing one, and until now it was the half of the job with no way out.
    private var syncTask: Task<Void, Never>?
    /// Kept alive while they are on screen; a comparison opened from a row belongs to nobody else.
    private var diffWindows: [DiffWindowController] = []
    /// Which column the grid is ordered by, and which way. `nil` is the scan's own order — by path,
    /// which is the order the two trees are walked in and the only one that groups folders together.
    private var sortKey: String?
    private var sortAscending = true
    /// What `setComparing` last did to the spinner. AppKit has no way to ask an indicator whether it
    /// is animating, and a verification run has to be able to.
    private var spinnerRunning = false

    private static func isActionable(_ a: SyncAction) -> Bool {
        a == .copyToRight || a == .copyToLeft || a == .deleteRight || a == .deleteLeft
    }

    convenience init(leftDir: String, rightDir: String, presetsURL: URL? = nil) {
        self.init(left: .localDir(leftDir), right: .localDir(rightDir), presetsURL: presetsURL)
    }

    init(left: SyncSide, right: SyncSide, presetsURL: URL? = nil) {
        self.leftSide = left
        self.rightSide = right
        self.presetStore = presetsURL.map { SyncPresetStore(url: $0) }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "Synchronize Directories")
        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showWindow() {
        leftField.stringValue = leftSide.path
        rightField.stringValue = rightSide.path
        // A zip side's path is fixed and its timestamps are unreliable, so lock the
        // field and force content comparison (dates ignored).
        // A zip or a server side is not a path the user can retype into: the first is an archive this
        // window rewrites, the second a live connection the panel owns.
        if leftSide.isZip || leftSide.isRemote { leftField.isEditable = false }
        if rightSide.isZip || rightSide.isRemote { rightField.isEditable = false }
        if hasZipSide {
            byContentButton.state = .on;  byContentButton.isEnabled = false
            ignoreDateButton.state = .on; ignoreDateButton.isEnabled = false
        }
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let root = NSStackView()
        root.orientation = .vertical
        // `.fill` plus the trailing pin every row gets at the end of this method. Left as it was —
        // a leading alignment and no distribution — this window grew and its contents did not:
        // measured at a content size of 1400x900 the result table was still the 780x300 it had been
        // built at, and the extra 340 points became an empty band under the status line. `.fill`
        // hands the leftover height to the row that hugs least, which is the table.
        root.alignment = .leading
        root.distribution = .fill
        root.spacing = 8
        root.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        for (label, field) in [(String(localized: "Left:"), leftField), (String(localized: "Right:"), rightField)] {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 6
            row.distribution = .fill
            let l = NSTextField(labelWithString: label)
            l.widthAnchor.constraint(equalToConstant: 44).isActive = true
            field.translatesAutoresizingMaskIntoConstraints = false
            // A path is the longest thing in this window, so the field takes whatever width the
            // window has rather than the 700 points it was built with.
            field.setContentHuggingPriority(.init(1), for: .horizontal)
            row.addArrangedSubview(l)
            row.addArrangedSubview(field)
            root.addArrangedSubview(row)
        }

        let maskRow = NSStackView()
        maskRow.orientation = .horizontal
        maskRow.spacing = 6
        maskRow.addArrangedSubview(NSTextField(labelWithString: String(localized: "Mask:")))
        maskField.stringValue = "*.*"
        maskField.widthAnchor.constraint(equalToConstant: 180).isActive = true
        maskRow.addArrangedSubview(maskField)
        root.addArrangedSubview(maskRow)

        let opts = NSStackView()
        opts.orientation = .horizontal
        opts.spacing = 14
        subdirsButton.title = String(localized: "With subdirs")
        subdirsButton.state = .on
        byContentButton.title = String(localized: "By content")
        ignoreDateButton.title = String(localized: "Ignore date")
        asymmetricButton.title = String(localized: "Asymmetric (mirror →)")
        ignoreHiddenButton.title = String(localized: "Ignore hidden")
        daylightButton.title = String(localized: "Ignore a 1-hour difference")
        daylightButton.toolTip = String(localized: "For FAT volumes and daylight saving, where the same file can be exactly an hour out")
        caseButton.title = String(localized: "Case sensitive")
        caseButton.toolTip = String(localized: "Off, two names differing only in case are the same file — which is what a Mac volume usually says")
        for b in [subdirsButton, byContentButton, ignoreDateButton, ignoreHiddenButton] {
            opts.addArrangedSubview(b)
        }
        root.addArrangedSubview(opts)
        // A second row rather than a longer one: the options row is the widest thing in this window
        // and therefore sets its minimum width, and seven checkboxes in a line would put that floor
        // past a thousand points in German.
        let opts2 = NSStackView()
        opts2.orientation = .horizontal
        opts2.spacing = 14
        for b in [asymmetricButton, daylightButton, caseButton] { opts2.addArrangedSubview(b) }
        root.addArrangedSubview(opts2)

        // Preset row (F-194): pick a saved comparison profile, or save/delete one.
        if presetStore != nil {
            let presetRow = NSStackView()
            presetRow.orientation = .horizontal
            presetRow.spacing = 6
            presetRow.addArrangedSubview(NSTextField(labelWithString: String(localized: "Preset:")))
            presetPopup.target = self
            presetPopup.action = #selector(presetSelected)
            presetPopup.widthAnchor.constraint(equalToConstant: 220).isActive = true
            presetRow.addArrangedSubview(presetPopup)
            let saveBtn = NSButton(title: String(localized: "Save Preset…"), target: self, action: #selector(savePreset))
            let delBtn = NSButton(title: String(localized: "Delete Preset"), target: self, action: #selector(deletePreset))
            for b in [saveBtn, delBtn] { b.bezelStyle = .rounded; presetRow.addArrangedSubview(b) }
            root.addArrangedSubview(presetRow)
            reloadPresetPopup()
        }

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        compareButton.title = String(localized: "Compare")
        compareButton.bezelStyle = .rounded
        compareButton.keyEquivalent = "\r"
        compareButton.target = self
        compareButton.action = #selector(compare)
        syncButton.title = String(localized: "Synchronize")
        syncButton.bezelStyle = .rounded
        syncButton.target = self
        syncButton.action = #selector(synchronize)
        syncButton.isEnabled = false
        buttons.addArrangedSubview(compareButton)
        buttons.addArrangedSubview(syncButton)
        // Mirroring only ever runs left → right (`.deleteLeft` is a case the classifier never
        // produces), so "the right side is the master" had no way to be expressed at all. Swapping
        // the two sides says it without a second mirror direction to explain, and it is worth having
        // on its own: the panels decide which folder lands on which side, and they are often the
        // wrong way round.
        let swapButton = NSButton(title: String(localized: "Swap sides"), target: self,
                                  action: #selector(swapSides))
        swapButton.bezelStyle = .rounded
        buttons.addArrangedSubview(swapButton)
        root.addArrangedSubview(buttons)

        // What the grid shows, and what "select all" then means. Placed under the Compare button and
        // above the grid because that is what it belongs to: it narrows the *result*, not the
        // comparison — nothing is re-scanned when it changes.
        let filterRow = NSStackView()
        filterRow.orientation = .horizontal
        filterRow.spacing = 8
        filterRow.addArrangedSubview(NSTextField(labelWithString: String(localized: "Show:")))
        for title in [String(localized: "All"),
                      String(localized: "Only → to the right"),
                      String(localized: "Only ← to the left")] {
            filterPopup.addItem(withTitle: title)
        }
        filterPopup.target = self
        filterPopup.action = #selector(filterChanged)
        filterRow.addArrangedSubview(filterPopup)
        hideEqualButton.title = String(localized: "Hide identical")
        hideEqualButton.target = self
        hideEqualButton.action = #selector(filterChanged)
        hideEqualButton.toolTip = String(localized: "Leave out the files that are the same on both sides")
        filterRow.addArrangedSubview(hideEqualButton)
        // Paired with the filter deliberately: "only to the right", then "Select All", is how a
        // one-way run is set up — see `selectAllVisible` for why that one is exclusive.
        let selectAll = NSButton(title: String(localized: "Select All"), target: self,
                                 action: #selector(selectAllVisible))
        selectAll.toolTip = String(localized: "Tick the rows shown, and untick everything the filter hides")
        let selectNone = NSButton(title: String(localized: "Deselect All"), target: self,
                                  action: #selector(deselectAllVisible))
        selectNone.toolTip = String(localized: "Untick every row, shown or not")
        for b in [selectAll, selectNone] {
            b.bezelStyle = .rounded
            filterRow.addArrangedSubview(b)
        }
        root.addArrangedSubview(filterRow)

        // Result grid
        // The dates were missing entirely: the grid showed two sizes and an arrow, so the one thing
        // that decides the arrow in the default mode — which side is newer — could not be seen at
        // all. They are what makes the row readable, and what a doubted arrow is checked against.
        let cols: [(String, CGFloat)] = [("inc", 26), ("name", 300),
                                         ("left", 90), ("ldate", 130),
                                         ("act", 60),
                                         ("right", 90), ("rdate", 130)]
        let titles = ["", String(localized: "Name"),
                      String(localized: "Left"), String(localized: "Date"),
                      "",
                      String(localized: "Right"), String(localized: "Date")]
        for (i, c) in cols.enumerated() {
            let col = NSTableColumn(identifier: .init(c.0))
            col.title = titles[i]
            col.width = c.1
            // Sorting is done here rather than by AppKit: the grid is an index list into `results`,
            // and the row's state (included, direction) is kept alongside by that index.
            if c.0 != "inc" {
                col.sortDescriptorPrototype = NSSortDescriptor(key: c.0, ascending: true)
            }
            // A wider window is worth having because the *names* are what does not fit: the two
            // timestamps and the arrow are a known width. Only the name column autoresizes, so the
            // uniform style — which spreads the slack over the columns that allow it — gives all of
            // it to that one, instead of widening the tick box along with it.
            col.resizingMask = c.0 == "name" ? [.autoresizingMask, .userResizingMask]
                                             : [.userResizingMask]
            tableView.addTableColumn(col)
        }
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 18
        tableView.target = self
        // Double-click opens the two sides side by side, which is the only way to answer "which of
        // these do I actually want" without leaving the window — and the only way at all to settle a
        // conflict, where the arrow deliberately refuses to guess.
        tableView.doubleAction = #selector(compareRow)
        tableView.menu = rowMenu()
        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        // The one view in this window that should absorb a resize, and the only one saying so: a
        // hugging priority below every other row's makes `.fill` hand it the leftover height, and
        // the low compression resistance lets it be the row that gives way when the window shrinks.
        // The floor keeps it from being squeezed to nothing on the way down.
        scroll.setContentHuggingPriority(.init(1), for: .vertical)
        scroll.setContentCompressionResistancePriority(.init(1), for: .vertical)
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        root.addArrangedSubview(scroll)

        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        // Stretched rather than sized to its text, so the pin below can span it without fighting its
        // intrinsic width — a label NSStackView cannot stretch it places at the *trailing* edge, and
        // the count of differences then sits at the far right of a wide window instead of under it.
        statusLabel.setContentHuggingPriority(.init(1), for: .horizontal)
        progressSpinner.style = .spinning
        progressSpinner.controlSize = .small
        progressSpinner.isDisplayedWhenStopped = false
        progressSpinner.translatesAutoresizingMaskIntoConstraints = false
        let statusRow = NSStackView(views: [progressSpinner, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.spacing = 6
        statusRow.distribution = .fill
        root.addArrangedSubview(statusRow)

        // Every row spans the window, on both edges and at required priority. The stack's own
        // alignment does not get there: a row it cannot stretch it places at the trailing edge
        // instead, and it holds its rows inside its own edge insets at less than required priority,
        // so a row too wide for the window escapes to x = 0 and overflows them — silently, with no
        // constraint conflict logged either way. Pinned here the geometry is unambiguous, and
        // `fittingSize` below then reports a floor the layout cannot slip under.
        for row in root.arrangedSubviews {
            row.leadingAnchor.constraint(equalTo: root.leadingAnchor,
                                         constant: root.edgeInsets.left).isActive = true
            row.trailingAnchor.constraint(equalTo: root.trailingAnchor,
                                          constant: -root.edgeInsets.right).isActive = true
        }

        // The floor is measured, not typed. The widest row is the row of option checkboxes, and how
        // wide that is depends on the language the app runs in — a number that fits English clips
        // German. Below this the options row breaks out of the stack's insets instead of the window
        // refusing to shrink, and nothing is logged when it does.
        root.layoutSubtreeIfNeeded()
        let floor = root.fittingSize
        window?.contentMinSize = floor
        if let window, window.contentRect(forFrameRect: window.frame).width < floor.width
            || window.contentRect(forFrameRect: window.frame).height < floor.height {
            let current = window.contentRect(forFrameRect: window.frame).size
            window.setContentSize(NSSize(width: max(current.width, floor.width),
                                         height: max(current.height, floor.height)))
        }
    }

    private func options() -> SyncOptions {
        SyncOptions(byContent: byContentButton.state == .on,
                    ignoreDate: ignoreDateButton.state == .on,
                    asymmetric: asymmetricButton.state == .on,
                    ignoreDaylightHour: daylightButton.state == .on,
                    caseSensitive: caseButton.state == .on)
    }

    // MARK: - Presets (F-194)

    /// Rebuild the popup: a placeholder row + one item per saved preset.
    private func reloadPresetPopup() {
        guard let store = presetStore else { return }
        presetPopup.removeAllItems()
        presetPopup.addItem(withTitle: String(localized: "(none)"))
        for p in store.load() { presetPopup.addItem(withTitle: p.name) }
        presetPopup.selectItem(at: 0)
    }

    /// The current dialog settings as a preset with the given name.
    private func currentPreset(name: String) -> SyncPreset {
        SyncPreset(name: name, options: options(),
                   fileMask: maskField.stringValue, withSubdirs: subdirsButton.state == .on)
    }

    /// Push a preset's settings into the controls.
    private func apply(_ preset: SyncPreset) {
        byContentButton.state = preset.options.byContent ? .on : .off
        ignoreDateButton.state = preset.options.ignoreDate ? .on : .off
        asymmetricButton.state = preset.options.asymmetric ? .on : .off
        maskField.stringValue = preset.fileMask
        subdirsButton.state = preset.withSubdirs ? .on : .off
    }

    @objc private func presetSelected() {
        guard let store = presetStore, presetPopup.indexOfSelectedItem > 0 else { return }
        let name = presetPopup.titleOfSelectedItem ?? ""
        if let preset = store.load().first(where: { $0.name == name }) { apply(preset) }
    }

    @objc private func savePreset() {
        guard let store = presetStore else { return }
        let dialog = InputDialog(title: String(localized: "Save Preset"),
                                 prompt: String(localized: "Preset name:"),
                                 initialValue: presetPopup.indexOfSelectedItem > 0 ? (presetPopup.titleOfSelectedItem ?? "") : "")
        dialog.onConfirm = { [weak self] name in
            guard let self else { return }
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            _ = store.upsert(self.currentPreset(name: trimmed))
            self.reloadPresetPopup()
            self.presetPopup.selectItem(withTitle: trimmed)
        }
        dialog.runModalDialog()
    }

    @objc private func deletePreset() {
        guard let store = presetStore, presetPopup.indexOfSelectedItem > 0,
              let name = presetPopup.titleOfSelectedItem else { return }
        _ = store.remove(name: name)
        reloadPresetPopup()
    }

    // MARK: - Actions

    /// Trigger the comparison programmatically (used by automation, F-192).
    func compareNow() { compare() }
    #if DEBUG
    /// Set the "Ignore hidden" option before an automated compare (F-192).
    func automationSetIgnoreHidden(_ on: Bool) { ignoreHiddenButton.state = on ? .on : .off }

    /// Set the result filter and report what the grid then shows.
    ///
    /// The rows are read back from the *table's* own data source rather than from `visibleRows`, so
    /// the report is what a user can see and not what the controller believes: a filter that
    /// computes the right set and a grid that shows the old one look identical from the inside.
    func automationSetFilter(_ direction: String, hideEqual: Bool) -> String {
        switch direction.lowercased() {
        case "right": filterPopup.selectItem(at: 1)
        case "left":  filterPopup.selectItem(at: 2)
        default:      filterPopup.selectItem(at: 0)
        }
        hideEqualButton.state = hideEqual ? .on : .off
        filterChanged()
        return automationGridReport()
    }

    /// Press one of the two buttons beside the filter.
    func automationSelectVisible(_ included: Bool) -> String {
        if included { selectAllVisible() } else { deselectAllVisible() }
        return automationGridReport()
    }

    /// What the grid is showing, row by row, plus the status line under it.
    func automationGridReport() -> String {
        // By identifier, not by position: the grid gained its date columns after this was written,
        // and an index that silently moved would have reported the wrong column rather than failing.
        func cell(_ identifier: String, _ row: Int) -> NSView? {
            guard let column = tableView.tableColumns.first(where: { $0.identifier.rawValue == identifier })
            else { return nil }
            return tableView(tableView, viewFor: column, row: row)
        }
        var out = "rows=\(tableView.numberOfRows)\ntotal=\(results.count)\n"
        for row in 0..<tableView.numberOfRows {
            let inc = cell("inc", row) as? NSButton
            let name = cell("name", row) as? NSTextField
            let act = cell("act", row) as? NSButton
            let ldate = cell("ldate", row) as? NSTextField
            let rdate = cell("rdate", row) as? NSTextField
            out += "row=\(name?.stringValue ?? "?") action=\(act?.title ?? "?")"
                + " included=\(inc?.state == .on)"
                + " ldate=\(ldate?.stringValue ?? "?") rdate=\(rdate?.stringValue ?? "?")\n"
        }
        out += "status=\(statusLabel.stringValue)\n"
        return out
    }

    /// Whether the window is visibly busy, for a script that catches a scan in flight.
    ///
    /// `spinnerRuns` is what `setComparing` last did to the indicator, not a reading off the screen:
    /// AppKit exposes no "is this spinning", and `isHidden` stays false for a *stopped* indeterminate
    /// indicator that draws nothing (`isDisplayedWhenStopped` is off). The independent check on that
    /// same call is `button` — it is set beside it — and the picture is `mainshot`.
    func automationBusyReport() -> String {
        """
        left=\(leftField.stringValue)
        right=\(rightField.stringValue)
        comparing=\(compareTask != nil)
        spinnerRuns=\(spinnerRunning)
        spinnerHidden=\(progressSpinner.isHidden)
        button=\(compareButton.title)
        syncbutton=\(syncButton.title)
        syncing=\(syncTask != nil)
        status=\(statusLabel.stringValue)
        """ + "\n"
    }

    /// Cancel a running comparison, as the Stop button does.
    func automationStopCompare() { if compareTask != nil { compare() } }

    /// Click the action glyph of the visible row `row`, as a user does to reverse it or to give a
    /// conflict a direction.
    func automationFlipRow(_ row: Int) -> String {
        guard visibleRows.indices.contains(row) else { return "ERROR: no visible row \(row)\n" }
        let button = NSButton()
        button.tag = visibleRows[row]
        flipDirection(button)
        return automationGridReport()
    }

    /// Sort by a column, as clicking its header does.
    func automationSort(_ key: String, ascending: Bool) -> String {
        tableView.sortDescriptors = [NSSortDescriptor(key: key, ascending: ascending)]
        return automationGridReport()
    }

    /// Press "Swap sides".
    func automationSwapSides() -> String {
        swapSides()
        return automationBusyReport()
    }

    /// Run the synchronization without the confirmation alert, which a script cannot answer.
    func automationSynchronize() {
        let actionable: [SyncResult] = results.enumerated().compactMap { i, r in
            guard i < rowIncluded.count, rowIncluded[i], Self.isActionable(rowAction[i]) else { return nil }
            return SyncResult(action: rowAction[i], item: r.item)
        }
        guard !actionable.isEmpty else { return }
        runSynchronize(actionable)
    }

    /// What the confirmation would have said about deleting on a server.
    func automationDeleteWarning() -> String {
        let actionable: [SyncResult] = results.enumerated().compactMap { i, r in
            guard i < rowIncluded.count, rowIncluded[i], Self.isActionable(rowAction[i]) else { return nil }
            return SyncResult(action: rowAction[i], item: r.item)
        }
        let warning = permanentDeleteWarning(for: actionable)
        return "warns=\(!warning.isEmpty)\ntext=\(warning.trimmingCharacters(in: .whitespacesAndNewlines))\n"
    }
    #endif

    @objc private func compare() {
        // The same button stops the scan it started. A comparison of a large tree — with subdirs, by
        // content — runs for minutes, and a window whose only button is greyed out for that long
        // gives a user nothing to do but force-quit.
        //
        // The handle is *not* cleared here: only the task itself clears it, when it has actually
        // noticed. Clearing it on the click made the next click start a second scan while the first
        // was still winding down, and the first one's finish then reported "Cancelled" over the top
        // of the new one — which went on running with nothing on screen belonging to it.
        if let running = compareTask {
            running.cancel()
            return
        }
        // Local sides track their editable path field; zip sides are fixed.
        if case .localDir = leftSide { leftSide = .localDir(leftField.stringValue) }
        if case .localDir = rightSide { rightSide = .localDir(rightField.stringValue) }
        let mask = maskField.stringValue
        let withSubdirs = subdirsButton.state == .on
        let byContent = byContentButton.state == .on
        let ignoreHidden = ignoreHiddenButton.state == .on
        let opts = options()
        setComparing(true)
        statusLabel.stringValue = String(localized: "Comparing…")
        syncButton.isEnabled = false
        let (l, r) = (leftSide, rightSide)
        // `progress` is called from the scan's own context, so each report hops back. Reports are
        // strided inside the scanner precisely so that hop is rare enough to be free.
        let report: @Sendable (SyncScanPhase) -> Void = { phase in
            Task { @MainActor in self.show(phase) }
        }
        compareTask = Task.detached(priority: .userInitiated) {
            let items = await SyncScanner.scan(left: l, right: r, mask: mask,
                                         withSubdirs: withSubdirs, byContent: byContent,
                                         ignoreHidden: ignoreHidden, caseSensitive: opts.caseSensitive,
                                         progress: report)
            // A cancelled scan returns what it had, which is a *partial* tree — showing it as a
            // result would be a comparison that quietly left files out.
            if Task.isCancelled {
                await MainActor.run {
                    self.compareTask = nil
                    self.setComparing(false)
                    self.statusLabel.stringValue = String(localized: "Cancelled")
                }
                return
            }
            let classified = SyncModel.classify(items, options: opts)
            await MainActor.run {
                self.compareTask = nil
                self.setComparing(false)
                self.results = classified.filter { $0.action != .none }
                self.rowAction = self.results.map(\.action)
                self.rowIncluded = self.results.map { Self.isActionable($0.action) }   // include all actionable by default
                self.reloadVisibleRows()   // which also decides whether Synchronize is enabled
            }
        }
    }

    /// Swap the Compare button for a Stop button and run the spinner, or the other way back.
    private func setComparing(_ running: Bool) {
        compareButton.title = running ? String(localized: "Stop") : String(localized: "Compare")
        if running { progressSpinner.startAnimation(nil) } else { progressSpinner.stopAnimation(nil) }
        spinnerRunning = running
    }

    /// Report a scan phase in the status line.
    ///
    /// The counts are interpolated outside the localized text rather than into it: "1200/5000" needs
    /// no translation, and every language then gets the number without a nineteenth format string to
    /// keep in step.
    @MainActor private func show(_ phase: SyncScanPhase) {
        // A late report from a scan that has already been called off would overwrite "Cancelled".
        guard let task = compareTask, !task.isCancelled else { return }
        switch phase {
        case .scanningLeft(let count):
            statusLabel.stringValue = "\(String(localized: "Scanning…")) \(String(localized: "Left:")) \(count)"
        case .scanningRight(let count):
            statusLabel.stringValue = "\(String(localized: "Scanning…")) \(String(localized: "Right:")) \(count)"
        case .comparing(let done, let total):
            statusLabel.stringValue = "\(String(localized: "Comparing…")) \(done)/\(total)"
        }
    }

    // MARK: - Result filter

    private var directionFilter: SyncDirectionFilter {
        switch filterPopup.indexOfSelectedItem {
        case 1: return .toRight
        case 2: return .toLeft
        default: return .all
        }
    }

    /// Recompute what the filter leaves visible and redraw.
    ///
    /// A full `reloadData` rather than a row reload, because reversing a row's direction can move it
    /// out of the current filter: the row that was clicked is not necessarily still there.
    private func reloadVisibleRows() {
        visibleRows = SyncModel.visibleRows(actions: rowAction, direction: directionFilter,
                                            hideEqual: hideEqualButton.state == .on)
        applySort()
        tableView.reloadData()
        updateStatus()
    }

    /// Order `visibleRows` by the clicked column.
    ///
    /// Sorted here rather than by AppKit, because the grid is a list of *indices* into `results` and
    /// the per-row state — included, direction — is held alongside by that same index. Sorting the
    /// results themselves would mean renumbering all of it on every click.
    private func applySort() {
        guard let key = sortKey else { return }
        let items = results, actions = rowAction, ascending = sortAscending
        func rises(_ a: Int, _ b: Int) -> Bool {
            switch key {
            case "left":  return (items[a].item.leftSize ?? -1) < (items[b].item.leftSize ?? -1)
            case "right": return (items[a].item.rightSize ?? -1) < (items[b].item.rightSize ?? -1)
            case "ldate": return (items[a].item.leftModified ?? .distantPast)
                              < (items[b].item.leftModified ?? .distantPast)
            case "rdate": return (items[a].item.rightModified ?? .distantPast)
                              < (items[b].item.rightModified ?? .distantPast)
            case "act":   return Self.actionGlyph(actions[a]) < Self.actionGlyph(actions[b])
            default:      return items[a].item.relativePath.lowercased()
                              < items[b].item.relativePath.lowercased()
            }
        }
        visibleRows.sort { ascending ? rises($0, $1) : rises($1, $0) }
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let descriptor = tableView.sortDescriptors.first else { sortKey = nil; reloadVisibleRows(); return }
        sortKey = descriptor.key
        sortAscending = descriptor.ascending
        reloadVisibleRows()
    }

    @objc private func filterChanged() { reloadVisibleRows() }

    /// Select exactly what the filter is showing — and *only* that.
    ///
    /// The exclusive half is the point of pairing this with the filter: "only → to the right", then
    /// this, is a one-way run in two clicks. Were the hidden rows left as they were, the ones the
    /// filter took off screen would still be ticked from the comparison's own defaults, and the run
    /// would go both ways while the grid showed one — the status line would say `← 1` next to a grid
    /// that has no `←` row in it. With no filter on, this selects everything actionable, as before.
    @objc private func selectAllVisible() {
        let shown = Set(visibleRows)
        for index in results.indices {
            rowIncluded[index] = shown.contains(index) && Self.isActionable(rowAction[index])
        }
        tableView.reloadData()
        updateStatus()
    }

    /// Clear every row, shown or not — what a button called "Deselect All" says it does, and the
    /// starting point for picking rows by hand.
    @objc private func deselectAllVisible() {
        for index in results.indices { rowIncluded[index] = false }
        tableView.reloadData()
        updateStatus()
    }

    private func updateStatus() {
        var toRight = 0, toLeft = 0, dels = 0, conflicts = 0
        // Counted from `rowAction` throughout — what the row says *now* — and not from the scan's
        // own verdict in `results`. The old loop skipped anything the scan had called a conflict, so
        // a conflict given a direction by hand was counted in neither column: the grid showed the
        // arrow, the run carried it out, and the line above it did not know about it.
        for i in results.indices {
            if rowAction[i] == .conflict { conflicts += 1; continue }
            guard i < rowIncluded.count, rowIncluded[i] else { continue }   // count only included rows (F-192)
            switch rowAction[i] {
            case .copyToRight: toRight += 1
            case .copyToLeft: toLeft += 1
            case .deleteRight, .deleteLeft: dels += 1
            default: break
            }
        }
        var text = String(localized: "→ \(toRight)   ← \(toLeft)   delete \(dels)   conflicts \(conflicts)")
        // The counts above are what Synchronize will do — every included row, filtered or not. So
        // when the filter is hiding some of them, the line has to say so, or the numbers read as a
        // claim about what is on screen.
        if visibleRows.count != results.count {
            text += "   ·   \(visibleRows.count)/\(results.count) \(String(localized: "shown"))"
        }
        statusLabel.stringValue = text
        // Recomputed here rather than once after the scan: a conflict that has just been given a
        // direction is something to synchronize, and unticking the last row is not. Fixed at scan
        // time, the button stayed disabled for a grid of nothing but conflicts however they were
        // resolved, and enabled for a grid the user had emptied by hand.
        syncButton.isEnabled = syncTask == nil && rowIncluded.indices.contains {
            rowIncluded[$0] && Self.isActionable(rowAction[$0])
        }
    }

    @objc private func synchronize() {
        // The Synchronize button is the Stop button while it runs, exactly as Compare is.
        if let running = syncTask { running.cancel(); return }
        // Only included rows, with any per-row direction override applied (F-192).
        let actionable: [SyncResult] = results.enumerated().compactMap { i, r in
            guard i < rowIncluded.count, rowIncluded[i], Self.isActionable(rowAction[i]) else { return nil }
            return SyncResult(action: rowAction[i], item: r.item)
        }
        guard !actionable.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = String(localized: "Synchronize \(actionable.count) item(s)?")
        alert.informativeText = statusLabel.stringValue + permanentDeleteWarning(for: actionable)
        alert.addButton(withTitle: String(localized: "Synchronize"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        runSynchronize(actionable)
    }

    /// Carry out an already-confirmed plan.
    ///
    /// Split from `synchronize()` so a scripted run can reach the copying half at all: the
    /// confirmation is `runModal`, and an automation script has no way to answer it — `modaldump`
    /// dismisses a modal, which here means cancelling the very thing under test.
    private func runSynchronize(_ actionable: [SyncResult]) {
        let (l, r) = (leftSide, rightSide)
        setSynchronizing(true)
        statusLabel.stringValue = String(localized: "Synchronizing…")
        let report: @Sendable (Int, Int) -> Void = { done, total in
            Task { @MainActor in self.showSyncProgress(done: done, total: total) }
        }
        syncTask = Task.detached(priority: .userInitiated) {
            let errors = await SyncExecutor.execute(actionable, left: l, right: r, toTrash: true,
                                                    progress: report)
            let stopped = Task.isCancelled
            await self.reload?()
            await MainActor.run {
                self.syncTask = nil
                self.setSynchronizing(false)
                if stopped {
                    self.statusLabel.stringValue = String(localized: "Cancelled")
                } else if errors.isEmpty {
                    self.statusLabel.stringValue = String(localized: "Done — trees synchronized.")
                } else {
                    self.statusLabel.stringValue = String(localized: "Completed with \(errors.count) error(s).")
                    // The list itself, not just how long it is. `SyncExecutor` says which item failed
                    // and why; a count told the user that something went wrong and nothing about
                    // what — with a window for exactly this already in the app (F-089).
                    // Its own window, not a sheet on this one — the way the transfer manager
                    // reports its failures. As a sheet it sat on the application's terminate path:
                    // measured, a run that ended with the sheet up would not quit, while the same
                    // run with nothing to report quit at once. A report about a run that is over has
                    // no business holding the window it came from, either.
                    ErrorLogWindowController.present(over: nil,
                                                     summary: self.statusLabel.stringValue,
                                                     entries: errors.map { ($0.path, $0.message) })
                }
                self.compare() // re-scan to reflect the new state
            }
        }
    }

    /// Swap the Synchronize button for a Stop button and run the spinner, or back.
    private func setSynchronizing(_ running: Bool) {
        syncButton.title = running ? String(localized: "Stop") : String(localized: "Synchronize")
        syncButton.isEnabled = true
        compareButton.isEnabled = !running
        if running { progressSpinner.startAnimation(nil) } else { progressSpinner.stopAnimation(nil) }
        spinnerRunning = running
    }

    @MainActor private func showSyncProgress(done: Int, total: Int) {
        guard let task = syncTask, !task.isCancelled else { return }
        statusLabel.stringValue = "\(String(localized: "Synchronizing…")) \(done)/\(total)"
    }

    /// The line the confirmation was missing.
    ///
    /// Deleting on a local side goes to the Trash and can be undone from there; a server has no
    /// Trash, so `SyncExecutor` deletes for good. The code that does it has said so in a comment
    /// since it was written — "the dialog says so before the actions run" — and the dialog did not.
    private func permanentDeleteWarning(for actionable: [SyncResult]) -> String {
        guard SyncExecutor.deletesPermanently(actionable, left: leftSide, right: rightSide) else { return "" }
        return "\n\n" + String(localized: "Deletions on the server are permanent — there is no Trash to take them back out of.")
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { visibleRows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard visibleRows.indices.contains(row) else { return nil }
        let index = visibleRows[row]
        let r = results[index]
        let action = rowAction[index]
        // Include checkbox (F-192): only actionable rows can be toggled.
        if tableColumn?.identifier.rawValue == "inc" {
            let box = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleInclude(_:)))
            box.tag = index
            box.state = rowIncluded[index] ? .on : .off
            box.isEnabled = Self.isActionable(action)
            return box
        }
        // Action cell: a clickable glyph that flips direction on copy rows (F-192).
        if tableColumn?.identifier.rawValue == "act" {
            let btn = NSButton(title: Self.actionGlyph(action), target: self, action: #selector(flipDirection(_:)))
            btn.tag = index
            btn.isBordered = false
            btn.contentTintColor = Self.actionColor(action)
            // A conflict is clickable too, and that is the whole of finding it a way out: the
            // classifier refuses to guess between two files of the same age and different content,
            // and until now that refusal was final — the row could never be included in a run at
            // all. Clicking cycles ≠ → → → ← → ≠, so the guess the program will not make is made by
            // the person who can.
            btn.isEnabled = action == .copyToRight || action == .copyToLeft || action == .conflict
            btn.toolTip = action == .conflict
                ? String(localized: "Click to pick a direction for this conflict")
                : String(localized: "Click to reverse the copy direction")
            return btn
        }
        let id = NSUserInterfaceItemIdentifier("c")
        let field = (tableView.makeView(withIdentifier: id, owner: self) as? NSTextField)
            ?? { let f = NSTextField(labelWithString: ""); f.identifier = id; f.isBordered = false; f.drawsBackground = false; return f }()
        switch tableColumn?.identifier.rawValue {
        case "name": field.stringValue = r.item.relativePath + (r.item.isDirectory ? "/" : "")
        case "left": field.stringValue = r.item.leftSize.map { ByteSize($0).formatted(style: .kb) } ?? "—"
        case "right": field.stringValue = r.item.rightSize.map { ByteSize($0).formatted(style: .kb) } ?? "—"
        case "ldate": field.stringValue = Self.dateText(r.item.leftModified)
        case "rdate": field.stringValue = Self.dateText(r.item.rightModified)
        default: field.stringValue = ""
        }
        // Excluded rows are dimmed; otherwise use the action's colour.
        field.textColor = rowIncluded[index] || !Self.isActionable(action)
            ? Self.actionColor(action) : .disabledControlTextColor
        return field
    }

    /// The panel's own Date column formatting, so a timestamp reads the same everywhere in the app.
    private static let dateFormatter =
        PanelDateFormatter.makeFormatter(pattern: PanelDateFormatter.defaultPattern)

    private static func dateText(_ date: Date?) -> String {
        date.map { dateFormatter.string(from: $0) } ?? "—"
    }

    /// Two entries, and deliberately no more: everything else the grid can do — include a row,
    /// reverse it, resolve a conflict — is already one click away in the row itself, and a menu that
    /// repeats those would be a second place to keep them right.
    private func rowMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: String(localized: "Compare"), action: #selector(compareRow),
                                keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: String(localized: "Reveal in Finder"),
                                action: #selector(revealRow), keyEquivalent: ""))
        for item in menu.items { item.target = self }
        return menu
    }

    /// The `results` index the menu or the double-click is aimed at: the clicked row, or the
    /// selected one when the menu was opened from the keyboard.
    private var targetedIndex: Int? {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard visibleRows.indices.contains(row) else { return nil }
        return visibleRows[row]
    }

    /// The two sides of one row as local paths, when both exist and both are local.
    private func localPair(_ index: Int) -> (String, String)? {
        guard case .localDir(let l) = leftSide, case .localDir(let r) = rightSide else { return nil }
        let item = results[index].item
        guard !item.isDirectory, item.leftSize != nil, item.rightSize != nil else { return nil }
        return ((l as NSString).appendingPathComponent(item.relativePath),
                (r as NSString).appendingPathComponent(item.relativePath))
    }

    @objc private func compareRow() {
        guard let index = targetedIndex, let (l, r) = localPair(index) else { NSSound.beep(); return }
        let win = DiffWindowController(leftPath: l, rightPath: r)
        diffWindows.append(win)
        win.onClose = { [weak self, weak win] in self?.diffWindows.removeAll { $0 === win } }
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func revealRow() {
        guard let index = targetedIndex else { NSSound.beep(); return }
        let item = results[index].item
        let side: SyncSide = item.leftSize != nil ? leftSide : rightSide
        guard case .localDir(let dir) = side else { NSSound.beep(); return }
        NSWorkspace.shared.activateFileViewerSelecting(
            [URL(fileURLWithPath: (dir as NSString).appendingPathComponent(item.relativePath))])
    }

    /// Exchange the two sides, and with them the roles "master" and "copy" that mirroring depends on.
    @objc private func swapSides() {
        guard compareTask == nil, syncTask == nil else { NSSound.beep(); return }
        swap(&leftSide, &rightSide)
        (leftField.stringValue, rightField.stringValue) = (rightField.stringValue, leftField.stringValue)
        (leftField.isEditable, rightField.isEditable) = (rightField.isEditable, leftField.isEditable)
        // The old result described the old arrangement; keeping it on screen with the sides
        // exchanged would have every arrow pointing the wrong way.
        results = []; rowIncluded = []; rowAction = []
        reloadVisibleRows()
        statusLabel.stringValue = ""
    }

    @objc private func toggleInclude(_ sender: NSButton) {
        guard rowIncluded.indices.contains(sender.tag) else { return }
        rowIncluded[sender.tag] = sender.state == .on
        tableView.reloadData()
        updateStatus()
    }

    @objc private func flipDirection(_ sender: NSButton) {
        let index = sender.tag
        guard rowAction.indices.contains(index) else { return }
        // A row the scan called a conflict cycles ≠ → → → ← → ≠; an ordinary copy row just turns
        // round. Choosing a direction for a conflict also ticks it, because choosing one is the
        // whole point of the click — and going back to ≠ unticks it again, since a conflict is not
        // something the run can carry out.
        let wasConflict = results[index].action == .conflict
        switch rowAction[index] {
        case .copyToRight: rowAction[index] = .copyToLeft
        case .copyToLeft:  rowAction[index] = wasConflict ? .conflict : .copyToRight
        case .conflict:    rowAction[index] = .copyToRight
        default: return
        }
        if wasConflict { rowIncluded[index] = Self.isActionable(rowAction[index]) }
        // Through the filter, not a row reload: under "only to the right" a row just reversed has
        // stopped belonging there, and must leave the grid rather than sit in it pointing the wrong
        // way (F-192 follow-up).
        reloadVisibleRows()
    }

    private static func actionGlyph(_ a: SyncAction) -> String {
        switch a {
        case .copyToRight: return "→"
        case .copyToLeft: return "←"
        case .equal: return "="
        case .conflict: return "≠"
        case .deleteRight: return "→🗑"
        case .deleteLeft: return "🗑←"
        case .none: return ""
        }
    }

    private static func actionColor(_ a: SyncAction) -> NSColor {
        switch a {
        case .copyToRight, .copyToLeft: return .systemBlue
        case .equal: return .secondaryLabelColor
        case .conflict: return .systemRed
        case .deleteRight, .deleteLeft: return .systemOrange
        case .none: return .labelColor
        }
    }
}

extension SyncWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // A scan of a large tree runs for minutes; closing the window used to leave it running to
        // completion, reporting into a window nobody can see. A synchronization is stopped too — it
        // stops between items, so what has been copied stays copied.
        compareTask?.cancel()
        syncTask?.cancel()
        onClose?()
    }
}
