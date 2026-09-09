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
import PCVFS

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
    /// The one control the advanced filter adds to this window. Its title carries how many criteria
    /// are set, because a filter nobody can see is the dangerous kind: a forgotten search finds too
    /// little and you search again, a forgotten sync filter leaves a backup incomplete and reports
    /// that it is done.
    private let filterButton = NSButton()
    /// The criteria themselves. Edited in a sheet, on a copy, and taken over when it is confirmed.
    private var filter = SyncFilter()
    /// How many entries the last comparison held back, for the status line.
    private var heldBack = 0
    /// What each side's walk was able to see, from the last comparison. `.unknown` until there has
    /// been one — which refuses every deletion, and is the right answer before anything was looked at.
    private var leftScope = SyncSideScope.unknown
    private var rightScope = SyncSideScope.unknown
    /// Whether the two roots are the same folder or one inside the other. Established with the
    /// filesystem when a comparison starts, not from the two strings.
    private var rootRelation = SyncPlanGuard.RootRelation.distinct
    /// Why the plan as it stands must not be offered. Recomputed whenever the plan changes.
    private var refusals: [SyncPlanGuard.Refusal] = []
    /// The last run's verdict, in one line, kept until the next run.
    ///
    /// Because a run is immediately followed by a forced re-comparison, and that overwrites the
    /// status line within a moment: measured, "Done — trees synchronized." was set and then replaced
    /// by the fresh comparison's counts before it could be read. The verdict is the one thing about a
    /// run the user has to see, so it survives the re-comparison instead of racing it.
    private var lastRunSummary = ""

    /// What the last run actually did, item by item. Kept because the forced re-comparison right
    /// after a run destroys the plan that produced it, and the outcomes are the only record of what
    /// happened — a state file will be written from exactly this.
    private var lastRunReport: SyncRunReport?
    /// Where a pair's record of the last run lives. Nil when the host did not hand one over, and
    /// two-way mode is then unavailable — the same shape as the preset store.
    private let stateStore: SyncStateStore?
    /// The record the last comparison read, kept so the run can write its successor.
    private var loadedState = SyncStateLoad.unknown(reason: "no comparison yet")

    /// Where a plugin criterion's fields come from. Nil when the host did not hand one over, and the
    /// filter sheet then says so instead of offering an empty popup.
    private let contentFields: ContentFieldRegistry?
    /// Held while the sheet is up: an NSWindowController with no owner is released out from under
    /// its own window.
    private var filterSheet: SyncFilterSheetController?
    private var memorySheet: SyncStateSheetController?
    private let subdirsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let byContentButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let ignoreDateButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let asymmetricButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    /// Keep both sides the same, using a record of the last run (F-192). The only mode that can
    /// delete on *either* side, and the only one that needs to remember anything.
    private let twoWayButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    /// Opens the list of what the app remembers, and lets it be forgotten. Beside the two-way
    /// switch because that is the mode the memory serves — and a safety valve rather than
    /// housekeeping: a record that no longer fits its folders is the one input this design fears,
    /// and until now there was no way to look at it.
    private let memoryButton = NSButton()
    private let ignoreHiddenButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)   // F-192
    /// FAT/DST: absorb a whole-hour difference rather than calling it a change (F-192 follow-up).
    private let daylightButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    /// Off by default, which is what `SyncOptions` always declared and what a Mac volume usually is.
    private let caseButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    /// How far two timestamps may be apart and still count as the same moment.
    ///
    /// `SyncOptions` has carried this since it was written and nothing could set it: two seconds, for
    /// everyone, for ever. Two is the right default — FAT stores timestamps to that precision — but
    /// it is the wrong answer for a network share whose clock is a few seconds off its client, which
    /// is an ordinary thing for a share to be, and there the whole tree reads as changed.
    private let toleranceField = NSTextField()
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
    /// Why each row says what it says, parallel to `rowAction`. Read for the glyph, the colour, the
    /// tick default and whether the arrow can be clicked — never inferred from the action, because a
    /// mirror deletion and a propagated one are the same `SyncAction` on purpose.
    private var rowBasis: [SyncBasis] = []
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

    convenience init(leftDir: String, rightDir: String, presetsURL: URL? = nil,
                     contentFields: ContentFieldRegistry? = nil, stateDirectory: URL? = nil) {
        self.init(left: .localDir(leftDir), right: .localDir(rightDir), presetsURL: presetsURL,
                  contentFields: contentFields, stateDirectory: stateDirectory)
    }

    init(left: SyncSide, right: SyncSide, presetsURL: URL? = nil,
         contentFields: ContentFieldRegistry? = nil, stateDirectory: URL? = nil) {
        self.leftSide = left
        self.rightSide = right
        self.presetStore = presetsURL.map { SyncPresetStore(url: $0) }
        self.contentFields = contentFields
        self.stateStore = stateDirectory.map { SyncStateStore(directory: $0) }
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
        filterButton.bezelStyle = .rounded
        filterButton.target = self
        filterButton.action = #selector(openFilterSheet)
        filterButton.toolTip = String(localized: "Exclude paths, sizes or dates from this comparison")
        maskRow.addArrangedSubview(filterButton)
        updateFilterButton()
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
        toleranceField.stringValue = "2"
        toleranceField.alignment = .right
        toleranceField.toolTip = String(localized: "How far two timestamps may be apart and still count as equal. Raise it for a share whose clock differs from this machine's.")
        toleranceField.widthAnchor.constraint(equalToConstant: 44).isActive = true
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
        twoWayButton.title = String(localized: "Two-way (remember)")
        memoryButton.bezelStyle = .rounded
        memoryButton.target = self
        memoryButton.action = #selector(openMemorySheet)
        memoryButton.isEnabled = stateStore != nil
        for b in [asymmetricButton, twoWayButton, daylightButton, caseButton] {
            opts2.addArrangedSubview(b)
        }
        opts2.addArrangedSubview(memoryButton)
        // Exclusive, so the combination that means nothing cannot be produced here.
        asymmetricButton.target = self; asymmetricButton.action = #selector(modeChanged(_:))
        twoWayButton.target = self; twoWayButton.action = #selector(modeChanged(_:))
        refreshTwoWayAvailability()
        updateMemoryButton()
        opts2.addArrangedSubview(NSTextField(labelWithString: String(localized: "Tolerance:")))
        opts2.addArrangedSubview(toleranceField)
        opts2.addArrangedSubview(NSTextField(labelWithString: String(localized: "s")))
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
                    caseSensitive: caseButton.state == .on,
                    toleranceSeconds: tolerance,
                    twoWay: twoWayButton.state == .on)
    }

    /// Whether keeping a record is possible for these two sides at all.
    ///
    /// Local folders only, in this version, and the reason is what the surrounding machinery cannot
    /// yet do rather than anything about the record. A deletion inside an archive is an irreversible
    /// rewrite and a deletion on a server is permanent — and `SyncExecutor.deletesPermanently` sees
    /// neither, so the warning would not even mention them. Nothing anywhere pushes a synchronisation
    /// onto the undo stack. A mode whose whole point is deleting on both sides is not the one to
    /// switch on over that.
    private var twoWayIsPossible: Bool {
        guard stateStore != nil else { return false }
        if case .localDir = leftSide, case .localDir = rightSide { return true }
        return false
    }

    /// Keep the two deletion modes exclusive, so `asymmetric && twoWay` — which means nothing — is
    /// not reachable from the window. `SyncOptions.mode` still settles it for a preset that arrives
    /// with both, by reading it as the mode that deletes nothing.
    @objc private func modeChanged(_ sender: NSButton) {
        if sender === twoWayButton, sender.state == .on { asymmetricButton.state = .off }
        if sender === asymmetricButton, sender.state == .on { twoWayButton.state = .off }
        refreshTwoWayAvailability()
    }

    private func refreshTwoWayAvailability() {
        twoWayButton.isEnabled = twoWayIsPossible
        if !twoWayIsPossible { twoWayButton.state = .off }
        twoWayButton.toolTip = twoWayIsPossible
            ? String(localized: "Remembers what both folders looked like last time, so a deletion on one side is carried to the other. There is no undo for a deletion.")
            : String(localized: "Only two folders on this Mac can be kept in step both ways — not a server or an archive.")
    }

    /// The typed tolerance, or the two seconds that were hardcoded before there was a field.
    ///
    /// Nonsense is not an error worth a dialog: an empty field or a word means "the default", and a
    /// negative number means none. The comparison reads the number, so a bad one cannot do anything
    /// worse than compare exactly.
    private var tolerance: TimeInterval {
        let text = toleranceField.stringValue.trimmingCharacters(in: .whitespaces)
        guard let value = Double(text) else { return 2 }
        return max(0, value)
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

    // MARK: - The advanced filter

    /// The button says what the filter is doing, without anybody having to open it.
    private func updateFilterButton() {
        // One base string plus the count, not two strings. Built from "Filter" and "Filter…"
        // separately, the German catalogue gave the idle button "Filtern…" and the active one
        // "Filter (1)" — the word changed form depending on whether a filter was set, which reads
        // like two different controls. Measured in the running window.
        let count = filter.activeCriteriaCount
        let base = String(localized: "Filter…")
        filterButton.title = count == 0 ? base : "\(base) (\(count))"
    }

    /// Build the sheet for the filter as it stands. One place, so the button and a script take the
    /// same path — a scripted filter that skipped the sheet would exercise the struct and nothing of
    /// what a person actually goes through.
    private func makeFilterSheet() -> SyncFilterSheetController {
        let fields = contentFields?.allQualifiedFields().map { (id: $0.qualifiedID, title: $0.field.title) } ?? []
        let canEvaluate = SyncPluginFilter.canEvaluate(left: leftSide, right: rightSide)
        let sheet = SyncFilterSheetController(
            filter: filter, fields: fields,
            pluginsAvailable: canEvaluate,
            pluginsUnavailableReason: canEvaluate
                ? ""
                : String(localized: "A plugin field can only be read from a folder on this Mac — not from a server or an archive."))
        sheet.onConfirm = { [weak self] edited in
            guard let self else { return }
            self.filter = edited
            self.updateFilterButton()
            // Not applied to the rows on screen: those came out of a comparison run without it, and
            // silently reinterpreting them would be a plan the user never saw produced. The next
            // Compare uses it.
            if !self.results.isEmpty {
                self.statusLabel.stringValue = String(localized: "Filter changed — compare again to apply it.")
            }
        }
        sheet.onDismiss = { [weak self] in self?.filterSheet = nil }
        filterSheet = sheet
        return sheet
    }

    /// The button's title carries whether this pair is remembered at all, so the answer is readable
    /// without opening anything — the same reason the filter button carries its criteria count.
    private func updateMemoryButton() {
        guard stateStore != nil else {
            memoryButton.title = String(localized: "Memory…")
            return
        }
        memoryButton.title = loadedState.isKnown
            ? "\(String(localized: "Memory")) (\(loadedState.entries.count))"
            : String(localized: "Memory…")
    }

    @objc private func openMemorySheet() {
        guard let store = stateStore else { return }
        let sheet = SyncStateSheetController(store: store,
                                             currentLeft: leftSide.path, currentRight: rightSide.path)
        sheet.onChange = { [weak self] in
            guard let self else { return }
            // Forgetting a pair changes what the *next* comparison would decide, so the grid on
            // screen — which was decided with the record that has just gone — is no longer something
            // this window can stand behind.
            self.loadedState = .unknown(reason: String(localized: "the record was forgotten"))
            self.updateMemoryButton()
            if !self.results.isEmpty {
                self.lastRunSummary = String(localized: "Memory cleared — compare again.")
                self.updateStatus()
            }
        }
        sheet.onDismiss = { [weak self] in self?.memorySheet = nil }
        memorySheet = sheet
        sheet.present(over: window)
    }

    @objc private func openFilterSheet() {
        makeFilterSheet().present(over: window)
    }

    /// The current dialog settings as a preset with the given name.
    private func currentPreset(name: String) -> SyncPreset {
        SyncPreset(name: name, options: options(),
                   fileMask: maskField.stringValue, withSubdirs: subdirsButton.state == .on,
                   ignoreHidden: ignoreHiddenButton.state == .on,
                   filter: filter.isActive ? filter : nil)
    }

    /// Push a preset's settings into the controls.
    private func apply(_ preset: SyncPreset) {
        byContentButton.state = preset.options.byContent ? .on : .off
        ignoreDateButton.state = preset.options.ignoreDate ? .on : .off
        asymmetricButton.state = preset.options.asymmetric ? .on : .off
        // The preset store has round-tripped these three all along; only the window could not show
        // them, so loading a preset used to quietly drop back to the defaults for two of them.
        daylightButton.state = preset.options.ignoreDaylightHour ? .on : .off
        caseButton.state = preset.options.caseSensitive ? .on : .off
        toleranceField.stringValue = String(Int(preset.options.toleranceSeconds))
        maskField.stringValue = preset.fileMask
        subdirsButton.state = preset.withSubdirs ? .on : .off
        // And this one the store could not round-trip at all until now: it reached the engine as a
        // bare argument and was in no preset, so a saved comparison came back with hidden files in
        // it however it had been saved.
        ignoreHiddenButton.state = preset.ignoreHidden ? .on : .off
        // And the filter, whose whole danger is being invisible: loading a preset that carries one
        // has to move the button too. The comment above records this exact mistake happening once
        // already, for two options the store round-tripped while the window dropped them.
        filter = preset.filter ?? SyncFilter()
        updateFilterButton()
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

    /// Open the memory list and leave it up, so it can be read and photographed.
    func automationOpenMemory() { openMemorySheet() }

    /// What the list says, without closing it.
    func automationMemoryReport() -> String {
        (memorySheet?.automationReport() ?? "ERROR: no memory sheet\n")
            + "memorybutton=\(memoryButton.title)\n"
    }

    /// Forget everything the app remembers, the way a person would from the list.
    func automationForgetAllMemory() {
        memorySheet?.automationForgetAll()
    }

    func automationCloseMemory() { memorySheet?.automationClose() }

    /// Switch two-way mode on before an automated compare. Exclusive with mirror, as the window
    /// keeps them.
    func automationSetTwoWay(_ on: Bool) {
        twoWayButton.state = on ? .on : .off
        modeChanged(twoWayButton)
    }

    /// What the window knows about the pair's record — the thing a two-run scenario has to be able
    /// to see between the runs.
    func automationStateReport() -> String {
        var out = "twoWayEnabled=\(twoWayButton.isEnabled)\n"
        out += "twoWayOn=\(twoWayButton.state == .on)\n"
        out += "mode=\(options().mode)\n"
        switch loadedState {
        case .unknown(let reason):
            out += "state=unknown\nreason=\(reason)\n"
        case .known(let header, let entries):
            out += "state=known\nentries=\(entries.count)\nrecordedAt=\(header.runAt.timeIntervalSince1970)\n"
        }
        out += "propagated=\(rowBasis.filter { $0 == .propagatedDeletion }.count)\n"
        out += "stateConflicts=\(rowBasis.filter { $0 == .stateConflict }.count)\n"
        out += "status=\(statusLabel.stringValue)\n"
        return out
    }

    /// Set mirror mode before an automated compare. It is the only mode that deletes today, so it
    /// is the one a guard scenario has to be able to switch on.
    func automationSetAsymmetric(_ on: Bool) { asymmetricButton.state = on ? .on : .off }

    /// Put filter criteria in as though the sheet had been filled in and confirmed, and report what
    /// the window makes of them.
    ///
    /// Through the sheet rather than straight onto `filter`, so that what a script exercises is the
    /// path a person takes: the sheet parses the size and date text, refuses an incomplete plugin
    /// condition, and hands back a filter. Setting the field directly would test nothing but the
    /// struct, which `SyncFilterTests` already does.
    func automationSetFilterCriteria(_ spec: String) -> String {
        let sheet = filterSheet ?? makeFilterSheet()
        sheet.automationSet(spec)
        let sheetReport = sheet.automationReport()
        sheet.automationConfirm()
        return sheetReport + automationFilterReport()
    }

    /// Press the Filter button and leave the sheet up, so it can be photographed.
    func automationOpenFilterSheet() { openFilterSheet() }

    /// What the sheet says while it is open, without closing it.
    func automationFilterSheetReport() -> String {
        filterSheet?.automationReport() ?? "ERROR: no filter sheet\n"
    }

    /// What the window refuses, and why — the whole point being that this is readable without
    /// clicking Synchronize, because a plan that cannot run must not be offered.
    func automationGuardReport() -> String {
        var out = "refusals=\(refusals.count)\n"
        for r in refusals { out += "refusal=\(r.subject): \(r.reason)\n" }
        out += "syncEnabled=\(syncButton.isEnabled)\n"
        out += "deleteRows=\(rowAction.filter { $0 == .deleteRight || $0 == .deleteLeft }.count)\n"
        out += "leftReliable=\(leftScope.isReliable)\nrightReliable=\(rightScope.isReliable)\n"
        out += "status=\(statusLabel.stringValue)\n"
        return out
    }

    /// What the window says about the filter without anybody opening the sheet — which is the whole
    /// requirement: a filter that is only visible from inside its own dialog is an invisible one.
    func automationFilterReport() -> String {
        """
        filterbutton=\(filterButton.title)
        filtercriteria=\(filter.activeCriteriaCount)
        filterexclude=\(filter.excludePatterns)
        heldback=\(heldBack)
        status=\(statusLabel.stringValue)

        """
    }

    /// `save <name>` or `load <name>` on the preset row, then the filter report — so the round trip
    /// a preset has to survive is one scripted step.
    func automationPreset(_ command: String) -> String {
        let parts = command.split(separator: " ", maxSplits: 1).map(String.init)
        guard let store = presetStore, parts.count == 2 else { return "ERROR: no preset store\n" }
        let name = parts[1]
        switch parts[0] {
        case "save":
            _ = store.upsert(currentPreset(name: name))
            reloadPresetPopup()
            presetPopup.selectItem(withTitle: name)
        case "load":
            guard let preset = store.load().first(where: { $0.name == name }) else {
                return "ERROR: no preset \(name)\n"
            }
            presetPopup.selectItem(withTitle: name)
            apply(preset)
        default:
            return "ERROR: unknown preset command \(parts[0])\n"
        }
        return "preset=\(name)\n" + automationFilterReport()
    }

    /// Set the result filter and report what the grid then shows.
    ///
    /// One line per visible row with its basis and whether it is ticked — what a scenario needs to
    /// tell a propagated deletion from a mirror one, which are the same action on purpose.
    func automationBasisReport() -> String {
        var out = "rows=\(visibleRows.count)\n"
        for index in visibleRows {
            guard results.indices.contains(index) else { continue }
            out += "row=\(results[index].item.relativePath) action=\(rowAction[index])"
                + " basis=\(basis(index)) included=\(rowIncluded[index])\n"
        }
        return out
    }

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
        // Asked once per comparison, with the filesystem, before anything is scanned: two paths can
        // reach the same folder without looking alike.
        rootRelation = SyncScanner.rootRelation(left: leftSide, right: rightSide)
        setComparing(true)
        statusLabel.stringValue = String(localized: "Comparing…")
        syncButton.isEnabled = false
        let (l, r) = (leftSide, rightSide)
        // `progress` is called from the scan's own context, so each report hops back. Reports are
        // strided inside the scanner precisely so that hop is rare enough to be free.
        let report: @Sendable (SyncScanPhase) -> Void = { phase in
            Task { @MainActor in self.show(phase) }
        }
        let activeFilter = filter
        let registry = contentFields
        // The record is read before the scan, on the main actor, so the detached work has a plain
        // value and no store to reach into. Two-way only: the other two modes must behave exactly as
        // they always have, whatever is on disk.
        let state: SyncStateLoad = opts.mode == .twoWay
            ? (stateStore?.load(leftRoot: l.path, rightRoot: r.path)
                ?? .unknown(reason: "no place to keep a record"))
            : .unknown(reason: "not two-way")
        loadedState = state
        compareTask = Task.detached(priority: .userInitiated) {
            let outcome = await SyncScanner.scanDetailed(left: l, right: r, mask: mask,
                                         withSubdirs: withSubdirs, byContent: byContent,
                                         ignoreHidden: ignoreHidden, caseSensitive: opts.caseSensitive,
                                         filter: activeFilter, progress: report)
            let items = outcome.items
            // A cancelled scan returns what it had, which is a *partial* tree — showing it as a
            // result would be a comparison that quietly left files out.
            if Task.isCancelled {
                await MainActor.run {
                    self.compareTask = nil
                    self.setComparing(false)
                    self.leftScope = .unknown
                    self.rightScope = .unknown
                    self.statusLabel.stringValue = String(localized: "Cancelled")
                }
                return
            }
            var classified = SyncTwoWay.classify(items, options: opts,
                                                 state: state.entries,
                                                 stateKnown: state.isKnown && opts.mode == .twoWay,
                                                 leftScope: outcome.leftScope,
                                                 rightScope: outcome.rightScope)
            var heldBack = outcome.heldBack
            let scopes = (outcome.leftScope, outcome.rightScope)
            // The plugin criterion runs here and not in the scan: it needs to know which side a row
            // reads from, which is only settled once the row has been classified. See SyncPluginFilter.
            if let predicate = activeFilter.pluginPredicate, let registry {
                let pass = await SyncPluginFilter.apply(to: classified, predicate: predicate,
                                                        left: l, right: r, registry: registry)
                if Task.isCancelled { return }
                classified = pass.kept
                heldBack += pass.heldBack
            }
            await MainActor.run {
                self.compareTask = nil
                self.setComparing(false)
                self.heldBack = heldBack
                (self.leftScope, self.rightScope) = scopes
                self.updateMemoryButton()
                self.results = classified.filter { $0.action != .none }
                self.rowAction = self.results.map(\.action)
                self.rowBasis = self.results.map(\.basis)
                // Everything actionable is ticked — except a deletion carried across from the other
                // side. That row is the one where a wrong record costs data, and it is the only one
                // the user did not ask for directly: it comes from the app's memory rather than from
                // anything visible in the two folders. It has to be armed by hand.
                self.rowIncluded = self.results.map {
                    Self.isActionable($0.action) && $0.basis != .propagatedDeletion
                }
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
            case "act":   return Self.actionGlyph(actions[a], basis(a))
                              < Self.actionGlyph(actions[b], basis(b))
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
        // Appended, never in place of the counts: an incomplete backup that reports success is the
        // failure this whole feature has to avoid, so how much the filter left out belongs on the
        // same line as what will happen.
        if heldBack > 0 {
            text += "   ·   \(heldBack) \(String(localized: "held back by the filter"))"
        }
        // A deletion carried across from the other side is deliberately unticked, so the counts
        // above say nothing about it — and a grid showing a row nobody mentioned next to "delete 0"
        // is exactly the kind of quiet the rest of this window exists to avoid. Counted separately
        // *because* it is not counted above.
        let waiting = rowBasis.indices.filter {
            rowBasis[$0] == .propagatedDeletion && !(rowIncluded.indices.contains($0)
                                                     && rowIncluded[$0])
        }.count
        if waiting > 0 {
            text += "   ·   \(waiting) \(String(localized: "deleted on the other side — tick to carry over"))"
        }
        // Recomputed on every change, because the plan changes with every tick and every flipped
        // arrow — a refusal computed once after the scan would still be shown for a row the user has
        // since unticked.
        // The share is measured against what the *last run* knew, when there is a record. Against
        // the plan's own length a run that also copies a thousand files would dilute the share until
        // the guard stopped firing — and a plan built from a record that belongs to a different pair
        // is exactly the case this net is for.
        refusals = SyncPlanGuard.refusals(plan: currentPlan(), leftScope: leftScope,
                                          rightScope: rightScope, roots: rootRelation,
                                          knownEntries: loadedState.isKnown
                                              ? loadedState.entries.count : nil)
        if let first = refusals.first {
            // The refusal replaces the counts rather than being appended to them. It is the only
            // thing that matters about this plan, and a fourth clause after "→ 3 ← 0 delete 812" is
            // a sentence nobody reads.
            text = "\(String(localized: "Cannot synchronize")): \(first.reason)"
            if refusals.count > 1 {
                text += "   ·   \(refusals.count - 1) \(String(localized: "more"))"
            }
        }
        // Appended last, so it is there whatever else the line says — including after the automatic
        // re-comparison, which is the only reason it is kept at all.
        if !lastRunSummary.isEmpty { text += "   ·   \(lastRunSummary)" }
        statusLabel.stringValue = text
        // Recomputed here rather than once after the scan: a conflict that has just been given a
        // direction is something to synchronize, and unticking the last row is not. Fixed at scan
        // time, the button stayed disabled for a grid of nothing but conflicts however they were
        // resolved, and enabled for a grid the user had emptied by hand.
        //
        // And disabled outright while the plan is refused. Refusing at the click would be a dialog
        // saying no to something the window had just offered; a gated action that cannot work must
        // not be proposed in the first place — the principle `DefaultAutomationCore` writes down for
        // the automation surface, and there is no reason it should be weaker here.
        syncButton.isEnabled = syncTask == nil && refusals.isEmpty && rowIncluded.indices.contains {
            rowIncluded[$0] && Self.isActionable(rowAction[$0])
        }
    }

    /// The rows that would actually run: included, actionable, with any per-row direction override
    /// applied (F-192).
    ///
    /// Lifted out of `synchronize()` because the guard has to judge exactly this — not everything
    /// the comparison produced. Judging the whole result would refuse a copy-only run because of
    /// delete rows the user had already unticked.
    private func currentPlan() -> [SyncResult] {
        results.enumerated().compactMap { i, r in
            guard i < rowIncluded.count, rowIncluded[i], Self.isActionable(rowAction[i]) else { return nil }
            return SyncResult(action: rowAction[i], item: r.item)
        }
    }

    @objc private func synchronize() {
        // The Synchronize button is the Stop button while it runs, exactly as Compare is.
        if let running = syncTask { running.cancel(); return }
        let actionable = currentPlan()
        guard !actionable.isEmpty else { return }
        // Nothing should be able to get here — the button is disabled while there are refusals — but
        // the check is repeated rather than trusted: this is the one path in the window that deletes,
        // and a disabled button is a statement about the last layout pass.
        guard refusals.isEmpty else { return }
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
        lastRunSummary = ""
        lastRunReport = nil
        // Only two-way keeps a record, and only then is it worth reading each destination back —
        // which on a server would be a round trip per file.
        let opts = options()
        let recording = opts.mode == .twoWay && stateStore != nil
        let scanned = results.map(\.item)
        let previous = loadedState.entries
        let scopes = (leftScope, rightScope)
        setSynchronizing(true)
        statusLabel.stringValue = String(localized: "Synchronizing…")
        let report: @Sendable (Int, Int) -> Void = { done, total in
            Task { @MainActor in self.showSyncProgress(done: done, total: total) }
        }
        syncTask = Task.detached(priority: .userInitiated) {
            let runReport = await SyncExecutor.execute(actionable, left: l, right: r, toTrash: true,
                                                       observeDestinations: recording,
                                                       progress: report)
            let errors = runReport.errors
            let refusals = runReport.refusals
            // From the report, not from re-reading `Task.isCancelled` here: the run knows whether it
            // stopped, and asking afterwards was a second answer to a question already settled.
            let stopped = runReport.stopped
            await self.reload?()
            await MainActor.run {
                self.syncTask = nil
                self.setSynchronizing(false)
                if stopped {
                    // What was carried out before the stop, which used to be thrown away entirely:
                    // the errors gathered until then went with it, and the line said only
                    // "Cancelled".
                    self.lastRunSummary =
                        String(localized: "Cancelled — \(runReport.applied) of \(runReport.outcomes.count) item(s) done.")
                } else if runReport.completedEverything {
                    // Asserted from every item having actually happened, not from an empty error
                    // list. An empty list also described a run that staged files into an archive and
                    // never wrote them, and one whose only "errors" were deliberate refusals.
                    self.lastRunSummary = String(localized: "Done — trees synchronized.")
                } else if errors.isEmpty {
                    self.lastRunSummary =
                        String(localized: "Done — \(refusals.count) item(s) kept back.")
                } else {
                    self.lastRunSummary = String(localized: "Completed with \(errors.count) error(s).")
                    // The list itself, not just how long it is. `SyncExecutor` says which item failed
                    // and why; a count told the user that something went wrong and nothing about
                    // what — with a window for exactly this already in the app (F-089).
                    // Its own window, not a sheet on this one — the way the transfer manager
                    // reports its failures. As a sheet it sat on the application's terminate path:
                    // measured, a run that ended with the sheet up would not quit, while the same
                    // run with nothing to report quit at once. A report about a run that is over has
                    // no business holding the window it came from, either.
                    ErrorLogWindowController.present(over: nil,
                                                     summary: self.lastRunSummary,
                                                     entries: errors.map { ($0.path, $0.message) })
                }
                // The refusals go in the same window, whatever else happened, and stay out of the
                // error count: a folder the mirror declined to delete because it held something the
                // comparison never looked at is a decision, not a fault, and an ordinary
                // `node_modules/` exclusion produces one on every single run.
                if !refusals.isEmpty, !errors.isEmpty || stopped == false {
                    ErrorLogWindowController.present(over: nil,
                                                     summary: String(localized: "Kept back"),
                                                     entries: refusals.map { ($0.path, $0.message) })
                }
                self.lastRunReport = runReport
                // Written before the re-comparison, because that destroys the plan this came from —
                // the outcomes are the only record of what actually happened.
                if recording {
                    self.writeState(runReport, items: scanned, previous: previous,
                                    options: opts, scopes: scopes, left: l, right: r)
                }
                self.compare() // re-scan to reflect the new state
            }
        }
    }

    /// Write the record the next comparison will read.
    ///
    /// From the run's outcomes and not from the plan: a propagated deletion that failed must leave
    /// the previous record standing, or the next run reads the file as new on the surviving side and
    /// copies it back — resurrecting exactly what the user deleted. `SyncState.next` holds that rule;
    /// this only translates the executor's outcomes into the terms it takes, and the translation is
    /// deliberately dumb.
    private func writeState(_ report: SyncRunReport, items: [SyncItem],
                            previous: [String: SyncStateEntry], options: SyncOptions,
                            scopes: (SyncSideScope, SyncSideScope),
                            left: SyncSide, right: SyncSide) {
        guard let store = stateStore else { return }
        let summaries: [SyncItemOutcomeSummary] = report.outcomes.map { outcome in
            let change: SyncItemOutcomeSummary.Change
            switch (outcome.action, outcome.status) {
            case (.copyToRight, .copied(let destination)):
                change = .copiedToRight(observedSide(destination, outcome, items))
            case (.copyToLeft, .copied(let destination)):
                change = .copiedToLeft(observedSide(destination, outcome, items))
            case (.deleteRight, .deleted): change = .deletedRight
            case (.deleteLeft, .deleted): change = .deletedLeft
            default: change = .nothingHappened
            }
            return SyncItemOutcomeSummary(relativePath: outcome.relativePath, change: change)
        }
        // A path is only droppable from the record when *both* walks could account for it — a run
        // with a narrower mask must not erase the history of the files it did not consider.
        let (leftScope, rightScope) = scopes
        let entries = SyncState.next(items: items, outcomes: summaries, previous: previous,
                                     caseSensitive: options.caseSensitive,
                                     inScope: { path in
                                         leftScope.provesAbsence(of: path)
                                             && rightScope.provesAbsence(of: path)
                                     })
        let header = SyncStateHeader(leftRoot: (left.path as NSString).standardizingPath
                                        .precomposedStringWithCanonicalMapping,
                                     rightRoot: (right.path as NSString).standardizingPath
                                        .precomposedStringWithCanonicalMapping,
                                     runAt: Date(), options: options,
                                     fileMask: maskField.stringValue,
                                     withSubdirs: subdirsButton.state == .on,
                                     ignoreHidden: ignoreHiddenButton.state == .on,
                                     filter: filter.isActive ? filter : nil,
                                     leftRootInode: FileStamp.of(left.path)?.inode,
                                     rightRootInode: FileStamp.of(right.path)?.inode)
        if case .refused(let reason) = store.save(header: header, entries: entries) {
            // Said out loud: keeping no record silently turns the mode off at the next run, with
            // nothing to explain why it stopped propagating deletions.
            lastRunSummary += "   ·   \(String(localized: "no record kept")): \(reason)"
        }
    }

    /// The destination side as the run observed it, or nil when it did not — in which case
    /// `SyncState.next` deliberately does not record the copy, so the next run offers it again.
    private func observedSide(_ destination: CopiedDestination, _ outcome: SyncItemOutcome,
                              _ items: [SyncItem]) -> SyncStateSide? {
        guard let size = destination.size, let modified = destination.modified else { return nil }
        let isDirectory = items.first { $0.relativePath == outcome.relativePath }?.isDirectory ?? false
        return SyncStateSide(size: size, modified: modified, isDirectory: isDirectory)
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
    /// Deleting a folder on this Mac goes to the Trash and can be put back from the Finder. Three
    /// other cases cannot: a server has no Trash, a deletion inside an archive is a whole-file
    /// rewrite, and a folder on a network volume generally refuses `trashItem`. The wording no
    /// longer says "on the server", because it was saying that for an archive too — the sentence was
    /// right about the consequence and wrong about the reason, which is how somebody ends up
    /// checking the wrong path field.
    private func permanentDeleteWarning(for actionable: [SyncResult]) -> String {
        guard SyncExecutor.deletesPermanently(actionable, left: leftSide, right: rightSide) else { return "" }
        return "\n\n" + String(localized: "Some of these deletions cannot be taken back — there is no Trash on that side.")
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
            let rowKind = basis(index)
            let btn = NSButton(title: Self.actionGlyph(action, rowKind), target: self,
                               action: #selector(flipDirection(_:)))
            btn.tag = index
            btn.isBordered = false
            btn.contentTintColor = Self.actionColor(action, rowKind)
            // A conflict is clickable too, and that is the whole of finding it a way out: the
            // classifier refuses to guess between two files of the same age and different content,
            // and until now that refusal was final — the row could never be included in a run at
            // all. Clicking cycles ≠ → → → ← → ≠, so the guess the program will not make is made by
            // the person who can.
            // A propagated deletion is clickable too, and it is the row that most needs to be: when
            // the record is wrong, what the user wants is not "skip this" but "no, it was not
            // deleted — put it back", and that is one click away now. Until this, a delete row's
            // glyph could not be clicked at all.
            btn.isEnabled = action == .copyToRight || action == .copyToLeft || action == .conflict
                || rowKind == .propagatedDeletion
            btn.toolTip = rowKind == .propagatedDeletion
                ? String(localized: "Deleted on the other side since the last run. Click to copy it back instead, or to leave both sides alone.")
                : action == .conflict
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
            ? Self.actionColor(action, basis(index)) : .disabledControlTextColor
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

        // A deletion carried across from the other side has its own cycle, and it is the answer to
        // the only question a wrong record raises: *delete it here → no, copy it back → leave both
        // alone → delete it here*. "Copy it back" is what somebody actually wants when the record is
        // wrong, and until now a delete row could not be clicked at all.
        if basis(index) == .propagatedDeletion {
            let original = results[index].action
            let back: SyncAction = original == .deleteRight ? .copyToLeft : .copyToRight
            switch rowAction[index] {
            case .deleteRight, .deleteLeft:
                rowAction[index] = back
                rowIncluded[index] = true
            case .copyToRight, .copyToLeft:
                rowAction[index] = SyncAction.none      // leave both sides as they are
                rowIncluded[index] = false
            default:
                rowAction[index] = original
                // Back to the deletion, and *still* unticked: coming full circle must not arm the
                // one row in the grid whose default is deliberately off.
                rowIncluded[index] = false
            }
            reloadVisibleRows()
            return
        }

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

    /// The glyph, which has to distinguish a deletion the mirror decided from one carried across
    /// from the other side — they are the same `SyncAction` on purpose, and telling them apart is
    /// what the basis is for. A propagated deletion gets a second arrow, because that is what it is:
    /// something that happened over there arriving here.
    private static func actionGlyph(_ a: SyncAction, _ basis: SyncBasis = .comparison) -> String {
        if basis == .propagatedDeletion {
            return a == .deleteRight ? "⇒🗑" : "🗑⇐"
        }
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

    private static func actionColor(_ a: SyncAction, _ basis: SyncBasis = .comparison) -> NSColor {
        // A propagated deletion is not orange like the mirror's: it is the row a wrong record turns
        // into lost data, and it is unticked by default, so it needs to stand out from the rows that
        // will run.
        if basis == .propagatedDeletion { return .systemPurple }
        switch a {
        case .copyToRight, .copyToLeft: return .systemBlue
        case .equal: return .secondaryLabelColor
        case .conflict: return .systemRed
        case .deleteRight, .deleteLeft: return .systemOrange
        case .none: return .labelColor
        }
    }

    /// The basis of one row, or `.comparison` for a caller that has none — never inferred from the
    /// action.
    private func basis(_ index: Int) -> SyncBasis {
        rowBasis.indices.contains(index) ? rowBasis[index] : .comparison
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
