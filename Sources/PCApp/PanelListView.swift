// SPDX-License-Identifier: Apache-2.0
// PanelListView.swift - View-based NSTableView for directory listing
//
// TC-style file list: columns Name(+icon)/Ext/Size/Date/Attr, dense rows,
// synthesized `..` pinned first. A consistent VISIBLE-row model is used:
//   table row 0            -> `..`
//   table row r (r >= 1)   -> visibleEntries[r - 1]
// The cursor is a visible index (`-1` == `..`). Marks live in the SelectionState
// actor; a main-thread `selectedPaths` mirror drives synchronous red rendering.

import AppKit
import UniformTypeIdentifiers
import PCVFS
import PCFoundation
import PCCommands
import PCPluginHost
import PCAutomation

/// Column types for the panel list
enum PanelColumn: String, CaseIterable {
    case name
    case ext
    case size
    case date
    case attr
    case tag
    case comment

    var title: String {
        // Display-only (the column identifier is `rawValue`, not this title — see
        // `spec` below), so localizing the header is safe.
        switch self {
        case .name: return String(localized: "Name")
        case .ext: return String(localized: "Ext")
        case .size: return String(localized: "Size")
        case .date: return String(localized: "Date")
        case .attr: return String(localized: "Attr")
        case .tag: return String(localized: "Tags")
        case .comment: return String(localized: "Comment")
        }
    }

    var width: CGFloat {
        switch self {
        case .name: return 260
        case .ext: return 60
        case .size: return 90
        case .date: return 140
        case .attr: return 90
        case .tag: return 70
        case .comment: return 220
        }
    }

    var defaultSortDescriptor: DirectoryModel.SortDescriptor {
        switch self {
        case .name: return .name(ascending: true)
        case .ext: return .ext(ascending: true)
        case .size: return .size(ascending: false)
        case .date: return .date(ascending: false)
        case .attr: return .name(ascending: true)
        case .tag: return .name(ascending: true)
        case .comment: return .name(ascending: true)
        }
    }

    /// The built-in column's spec. `fieldID` == rawValue so NSTableColumn
    /// identifiers stay unchanged (sort/arrow code keeps working); it is NOT a
    /// content-field id — built-ins render from VFSEntry directly.
    var spec: ColumnSpec {
        ColumnSpec(fieldID: rawValue, title: title, width: Int(width),
                   alignment: self == .size ? .right : .left)
    }

    /// The default visible set: the classic built-ins in their natural order.
    /// `comment` is opt-in (descript.ion is often absent), so it is offered in the
    /// picker (`allSpecs`) but not shown until the user adds it.
    static var defaultSpecs: [ColumnSpec] { allCases.filter { $0 != .comment }.map(\.spec) }

    /// Every built-in column, including opt-in ones — the column picker's choices.
    static var allSpecs: [ColumnSpec] { allCases.map(\.spec) }
}

/// Sort direction for UI display
enum SortDirection {
    case none
    case ascending
    case descending

    var arrow: String {
        switch self {
        case .none: return ""
        case .ascending: return "▲"
        case .descending: return "▼"
        }
    }
}

/// Custom header view for sort arrows
/// Column header cell that follows the palette (F-340).
///
/// AppKit draws the header with system colours, which left a grey strip between a themed path bar
/// and a themed list. Drawing is only taken over when a palette is actually selected: with the
/// default theme this falls straight through to `super`, so the header stays exactly the control
/// AppKit renders rather than an approximation of it.
///
/// No new palette colours — the header is the strip directly above the list, so it borrows the
/// active path bar's pair, which is also what the original Norton Commander did with its column
/// captions: dark text on the cyan bar.
final class ThemedHeaderCell: NSTableHeaderCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        guard Theme.paletteActive else { return super.draw(withFrame: cellFrame, in: controlView) }
        Theme.current.activePathBarBackground.setFill()
        cellFrame.fill()
        Theme.current.headerSeparator.setStroke()
        let sep = NSBezierPath()
        sep.move(to: NSPoint(x: cellFrame.maxX - 0.5, y: cellFrame.minY + 2))
        sep.line(to: NSPoint(x: cellFrame.maxX - 0.5, y: cellFrame.maxY - 2))
        sep.lineWidth = 1
        sep.stroke()
        drawInterior(withFrame: cellFrame.insetBy(dx: 4, dy: 0), in: controlView)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        guard Theme.paletteActive else { return super.drawInterior(withFrame: cellFrame, in: controlView) }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? Fonts.bold13,
            .foregroundColor: Theme.current.activePathBarText,
        ]
        let text = stringValue as NSString
        let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: cellFrame.minX, y: cellFrame.midY - size.height / 2), withAttributes: attrs)
    }
}

final class SortableHeaderView: NSTableHeaderView {
    private weak var tableViewRef: NSTableView?
    // Keyed by column identifier (fieldID) so both built-in and plugin columns
    // can show a sort arrow.
    private var sortDirectionMap: [String: SortDirection] = [:]

    init(tableView: NSTableView) {
        super.init(frame: .zero)
        self.tableViewRef = tableView
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func setSortDirection(_ direction: SortDirection, for columnID: String) {
        sortDirectionMap = [columnID: direction]
        needsDisplay = true
    }

    /// Builds the right-click column menu (context-aware; supplied by the owner).
    var menuProvider: (() -> NSMenu?)?
    override func menu(for event: NSEvent) -> NSMenu? { menuProvider?() ?? super.menu(for: event) }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let tableView = tableViewRef else { return }
        for (columnID, direction) in sortDirectionMap where direction != .none {
            // Use the actual on-screen header rect so the arrow follows column
            // reordering and resizing (static widths/allCases order do not).
            guard let colIndex = tableView.tableColumns.firstIndex(where: {
                $0.identifier.rawValue == columnID
            }) else { continue }
            let headerRect = self.headerRect(ofColumn: colIndex)

            let arrowString = NSAttributedString(string: direction.arrow,
                                                 attributes: [.font: Fonts.bold13,
                                                              .foregroundColor: Theme.current.listText])
            let arrowSize = arrowString.size()
            // Right-align inside the column header with a small padding; clamp so it
            // never spills left of the column start.
            let arrowX = max(headerRect.minX + 2, headerRect.maxX - arrowSize.width - 6)
            let arrowY = (frame.height - arrowSize.height) / 2
            arrowString.draw(at: NSMakePoint(arrowX, arrowY))
        }
    }
}

/// View-based table view for directory listing.
@MainActor
final class PanelListView: NSTableView, NSTableViewDataSource, NSTableViewDelegate {
    private let logger = PCFoundationLogger.logger

    // MARK: Model state
    private var snapshot: DirectorySnapshot?
    private var visibleEntries: [VFSEntry] = []
    /// Cursor as a visible index; -1 means cursor is on `..`.
    private(set) var cursorRow: Int = -1
    /// True while an in-cell rename (F-081) is active; suppresses model-driven
    /// reloads that would tear down the field editor.
    private(set) var isInlineEditing = false
    private var selectedPaths: Set<String> = []
    private var dirSizes: [String: Int64] = [:]
    private var showHiddenFiles = false
    /// Display options (I05): size format ("kb"/"dynamic"/"bytes") and folder brackets.
    private var sizeStyleKey = "kb"
    private var bracketDirs = false
    // Date column format (F-031): the Unicode pattern plus a cached formatter
    // (rebuilt only when the pattern changes; created per-row would be wasteful).
    private var dateFormatPattern = PanelDateFormatter.defaultPattern
    private lazy var dateFormatter = PanelDateFormatter.makeFormatter(pattern: dateFormatPattern)
    /// Quick filter (I06-T04): live substring/wildcard filter over visible entries.
    private var filterMode = false
    private var filterText = ""
    /// Type-ahead cursor search: accumulated typed prefix + last keystroke time.
    private var typeAheadBuffer = ""
    private var typeAheadLast: Date?
    /// Ends the search after a pause, so the indicator never shows a prefix that is no longer live.
    private var typeAheadTimer: Timer?
    /// The typed prefix, which match the cursor is on, and how many there are — or nil once the
    /// search has ended. Drawn by the panel as a small indicator; until it existed you typed blind.
    var onTypeAheadChanged: ((_ prefix: String?, _ position: Int?, _ total: Int) -> Void)?
    /// How long a search survives without a keystroke.
    ///
    /// Was 0.8 s and invisible, which is the shortest a *guess* can be: nothing on screen said a
    /// search was in progress, so the only safe window was one short enough that a later keystroke
    /// could not surprise you. Now that the prefix is shown and can be corrected with Backspace, a
    /// window that expires before you can read it defeats the point.
    private static let typeAheadWindow: TimeInterval = 2.0
    /// Quick-search mode (F-060): "direct" = plain letters jump (default),
    /// "ctrlalt" = only Ctrl+Alt+letter jumps, "off" = disabled.
    var quickSearchMode = "direct"
    private var typeColors = TypeColorRules()
    /// Apply by-file-type row colors from the compact config string (F-032).
    func setTypeColors(_ config: String) { typeColors = TypeColorRules(config); reloadData() }

    /// How a process holds the searched file open (F-390) — the plugin's per-row tag.
    enum FileHandleKind: String {
        case read = "r", write = "w", readWrite = "b"
        var color: NSColor {
            switch self {
            case .read: return Theme.current.fileHandleReadText
            case .write: return Theme.current.fileHandleWriteText
            case .readWrite: return Theme.current.fileHandleReadWriteText
            }
        }
    }

    /// Every content field the current mount publishes (qualified ids), so a filter can name a
    /// column that is not currently on screen. Set by the controller on entering a content mount.
    var mountContentFieldIDs: [String] = []

    /// Processes holding the searched file open, keyed by entry name ("Safari (1234)").
    ///
    /// Keyed by name and not by row, because the TaskManager mount is volatile: it re-lists itself
    /// roughly every two seconds and every row is a new `VFSEntry`. The name carries the PID, so a
    /// process keeps its colour across refreshes and a died-and-restarted one does not inherit it.
    private var fileHandleHighlights: [String: FileHandleKind] = [:]
    /// The panel path the highlights were resolved in, so leaving the mount drops them.
    private var fileHandleHighlightPath: String?

    /// Colour the given processes (F-390). Empty map = clear. The listing they belong to is taken
    /// from the view's own snapshot rather than passed in — two sources for one path is how they
    /// come to disagree, and a mismatch here would clear the highlight on the very next refresh.
    func setFileHandleHighlights(_ map: [String: FileHandleKind]) {
        fileHandleHighlights = map
        fileHandleHighlightPath = map.isEmpty ? nil : snapshot?.path
        reloadData()
    }

    func clearFileHandleHighlights() {
        guard !fileHandleHighlights.isEmpty else { return }
        fileHandleHighlights = [:]
        fileHandleHighlightPath = nil
        reloadData()
    }

    var hasFileHandleHighlights: Bool { !fileHandleHighlights.isEmpty }

    /// The highlighted rows in listing order, for the status line and the automation dump.
    func fileHandleHighlightRows() -> [(name: String, kind: FileHandleKind)] {
        visibleEntries.compactMap { e in fileHandleHighlights[e.name].map { (e.name, $0) } }
    }
    /// Anchor row (visible index) for Shift+click range selection.
    private var selectionAnchor = 0
    /// Fired when the quick filter changes (nil = off) so the panel can show an indicator. The
    /// counts are what the filter kept and what it looked at — in a 1200-row process list, a filter
    /// that shows three rows and one that shows none look identical without them.
    var onFilterChanged: ((_ text: String?, _ shown: Int, _ total: Int) -> Void)?
    /// Route a printable keystroke to the command line (TC default focus behavior).
    var onTypeToCommandLine: ((String) -> Void)?
    /// Append the cursor name (Ctrl+Enter) or full path (Ctrl+Shift+Enter) to the command line.
    var onAppendToCommandLine: ((String) -> Void)?
    /// Go up one level (parent dir, or leave a mounted archive at its root).
    var onGoUp: (() -> Void)?
    /// Enter the archive file at the given local path (Enter on a .zip etc.).
    var onEnterArchive: ((String) -> Void)?

    /// Enter on a file whose extension says nothing, when a packer plugin has offered to
    /// recognise archives by *content* (PC_CAP_BY_CONTENT).
    ///
    /// Left nil unless such a plugin is enabled, and that is the whole safety of it:
    /// with no content detector installed nothing about Enter changes, and no file gets
    /// read speculatively. Firmware is the case this exists for — a squashfs called
    /// `firmware.bin` or a rootfs with no extension at all is not something an
    /// extension list can ever match.
    ///
    /// Separate from `onEnterArchive` because the two need different answers when
    /// nothing can open the file: that one beeps, which is right for a `.zip` that turned
    /// out to be broken, and quite wrong for a `.txt` that was only being asked about.
    /// This one falls through to opening the file normally.
    var onProbeThenEnterArchive: ((String) -> Void)?
    /// Files were dropped onto this panel (from Finder, another app, or the other
    /// panel). `move` is true when the Command modifier was held. Paths are absolute.
    /// `intoFolder` is the absolute path of a folder row the files were dropped onto
    /// (F-067), or nil for a drop on the panel as a whole.
    var onDropFiles: (([String], _ move: Bool, _ intoFolder: String?) -> Void)?
    /// A drag hovered over the folder row at `path` long enough to spring-load it
    /// (open it in this panel) — F-067.
    var onSpringLoadFolder: ((String) -> Void)?
    /// Pending drag gesture: the row + start point captured on mouseDown, promoted
    /// to a real dragging session once the pointer moves past a small threshold.
    private var dragCandidate: (visible: Int, point: NSPoint)?
    /// Spring-loading (F-067): the folder row currently hovered during a drop drag
    /// and a timer that opens it if the hover persists.
    private var springLoadRow: Int = -1
    private var springLoadTimer: Timer?

    /// Does this name look like something we can open as an archive?
    ///
    /// Asked rather than kept. This used to be a private set that accumulated from
    /// three sources and was still a different answer from the one the search used —
    /// which is how a `.tar.gz` came to be openable with Enter and invisible to a
    /// content search at the same time. The window controller wires this to the
    /// shared registry (F-463); nil until then, so an unwired panel simply opens
    /// files the way it always would.
    var isArchiveName: (@Sendable (String) -> Bool)?

    // The ordered, configurable set of visible columns. Built-in columns keep
    // fieldID == PanelColumn.rawValue (so sort/arrow code is unchanged); plugin
    // columns carry a qualified content-field id ("provider.field").
    private var visibleColumns: [ColumnSpec] = PanelColumn.defaultSpecs

    /// descript.ion comments for the current directory (name → comment), shown in
    /// the opt-in `comment` column. Refilled per listing by the controller.
    private var commentMap: [String: String] = [:]

    /// Whether `fieldID` is currently a visible column (built-in or plugin).
    func hasColumn(_ fieldID: String) -> Bool {
        visibleColumns.contains { $0.fieldID == fieldID }
    }

    #if DEBUG
    /// Diagnostic: the comment the *table* holds for `name` — what the Comment column draws (F-372).
    /// Reading the store instead would prove the store, and the column is fed by a separate read.
    func automationComment(forName name: String) -> String? { commentMap[name] }

    /// Diagnostic: the string actually **rendered** into the Comment cell of `name`'s row.
    ///
    /// The map above can be right while nothing is drawn — a column that is not in the visible set draws
    /// no cell at all, and the first version of this check passed with the column switched off.
    func automationRenderedComment(forName name: String) -> String {
        guard let column = tableColumns.firstIndex(where: { $0.identifier.rawValue == PanelColumn.comment.rawValue })
        else { return "<no such column>" }
        // Row 0 is "..", so the table's row is the entry index plus one. Without that the cell of the
        // *previous* file was read, which has no comment — and the check reported an empty cell for a
        // column that was drawing correctly.
        guard let index = visibleEntries.firstIndex(where: { $0.name == name })
        else { return "<no such row>" }
        let row = index + 1
        guard let cell = view(atColumn: column, row: row, makeIfNecessary: true) else { return "<no cell>" }
        if let field = cell as? NSTextField { return field.stringValue }
        if let field = (cell as? NSTableCellView)?.textField { return field.stringValue }
        return "<no text field>"
    }

    /// Where the panel is looking: the cursor, the rows on screen, and the scroll offset.
    ///
    /// A refresh that keeps the cursor can still throw the view somewhere else, and no dump of names
    /// shows that — "the list is correct" and "I lost my place" are the same report otherwise.
    func automationViewport() -> String {
        let rows = self.rows(in: visibleRect)
        let offset = enclosingScrollView?.documentVisibleRect.origin.y ?? 0
        let cursor = cursorEntryName() ?? (cursorRow < 0 ? ".." : "<none>")
        return "cursor=\(cursor)\ncursorRow=\(cursorRow)\nfirstVisible=\(rows.location)"
            + "\nvisibleCount=\(rows.length)\noffsetY=\(Int(offset.rounded()))\nrows=\(numberOfRows)\n"
    }

    /// Scroll the view without moving the cursor — what a user does with the wheel while the cursor
    /// stays where they left it. The case a refresh must not undo.
    func automationScrollTo(row: Int) {
        guard row >= 0, row < numberOfRows else { return }
        scrollRowToVisible(numberOfRows - 1)
        scrollRowToVisible(row)
    }

    /// Every visible column's id and the text it shows for the cursor row — what the panel is
    /// actually rendering, column by column, for a check that cares about formatting (a byte count
    /// that should read "4.1 MB", a metric that must stay blank rather than claim zero).
    func automationCursorRowCells() -> [(field: String, text: String)] {
        guard cursorRow >= 0, let entry = entry(atCursor: cursorRow) else { return [] }
        return visibleColumns.map { ($0.fieldID, cellText(forColumn: $0.fieldID, entry: entry)) }
    }

    /// The SF Symbol each column of the cursor row is actually *drawing* (F-428).
    ///
    /// Read from the cell view rather than from the value, for the same reason
    /// `automationRenderedNameColor` exists: a value that contains a symbol name is not proof that an
    /// image was drawn, and a screenshot cannot tell one glyph from another.
    func automationCursorRowSymbols() -> [(field: String, symbol: String)] {
        guard cursorRow >= 0 else { return [] }
        var out: [(String, String)] = []
        for (index, column) in tableColumns.enumerated() {
            guard let cell = view(atColumn: index, row: cursorRow + 1, makeIfNecessary: true)
                    as? PlainCellView, let symbol = cell.symbolName else { continue }
            out.append((column.identifier.rawValue, symbol))
        }
        return out
    }

    /// The colour the name cell of `name` is actually drawing its label in, as "#RRGGBB".
    ///
    /// A colour that was *decided* is not a colour that is *drawn*: the row colour travels through
    /// `configure` into the label and can be overruled there (a marked file keeps `selectedText`).
    /// Reading the label back is the only way a check can tell the two apart — a screenshot cannot,
    /// since the three file-handle colours differ by hue at one lightness.
    func automationRenderedNameColor(forName name: String) -> String? {
        guard let column = tableColumns.firstIndex(where: { $0.identifier.rawValue == PanelColumn.name.rawValue }),
              let index = visibleEntries.firstIndex(where: { $0.name == name }),
              let cell = view(atColumn: column, row: index + 1, makeIfNecessary: true)
        else { return nil }
        let field = (cell as? NSTableCellView)?.textField ?? cell as? NSTextField
        guard let color = field?.textColor else { return nil }
        return "#" + color.hexString.uppercased()
    }

    /// Diagnostic: scroll the panel fully to the right, so a wide opt-in column is inside the screenshot.
    func automationScrollToLastColumn() {
        guard let clip = enclosingScrollView?.contentView else { return }
        let maxX = max(0, bounds.width - clip.bounds.width)
        clip.scroll(to: NSPoint(x: maxX, y: clip.bounds.origin.y))
        enclosingScrollView?.reflectScrolledClipView(clip)
    }
    #endif

    /// Supply the directory's descript.ion comments and repaint the comment column.
    func setComments(_ map: [String: String]) {
        commentMap = map
        if hasColumn(PanelColumn.comment.rawValue) { reloadData() }
    }

    /// Whether the listing comes from the local filesystem. Columns that read local-only
    /// metadata (extended attributes, Finder tags) are skipped when it does not: a remote
    /// path can never carry them, and querying it anyway spends a syscall per visible row on
    /// a path the kernel has to resolve — under an automounted prefix like `/home`, one that
    /// blocks for milliseconds. Set by `PanelView.update(with:)`.
    var isLocalFileSystem: Bool = true

    /// Resolves a qualified field id + local path to a display string (async).
    var contentValueProvider: ((_ fieldID: String, _ path: String) async -> String?)?
    /// A content field (qualified id) shown as a small badge on the name cell
    /// (e.g. the Notes "●"), independent of whether it is also a column.
    var badgeFieldID: String?
    /// Content-field ids whose values sort numerically rather than lexically
    /// (e.g. a TaskManager's CPU/PID/Threads columns).
    var numericContentFields: Set<String> = []
    /// Plugin fields whose value is `symbolName\ttext` — opted into with unit "icon" (F-428), the same
    /// shape the "badge" unit already used to opt into a name-cell badge.
    var iconContentFields: Set<String> = []
    /// path -> fieldID -> SF Symbol, split off the raw value on the way in (F-430).
    private var contentSymbols: [String: [String: String]] = [:]
    private var contentValues: [String: [String: String]] = [:]   // path -> fieldID -> value
    private var contentPending: Set<String> = []

    private var sortDescriptor: DirectoryModel.SortDescriptor = .name(ascending: true)
    private var sortableHeaderView: SortableHeaderView?

    private var selectionState: SelectionState?
    private let dirSizeCalculator = DirectorySizeCalculator()

    // MARK: Callbacks
    var onNavigate: ((String) -> Void)?
    var onSortColumn: ((PanelColumn, Bool) -> Void)?
    /// Fired whenever the cursor moves or the selection changes (drives the status bar).
    var onSelectionOrCursorChanged: (() -> Void)?
    /// Ask the controller to present the Select/Unselect-by-mask dialog. Bool = unselect.
    var onShowSelectDialog: ((_ unselect: Bool) -> Void)?
    /// Ask the controller to present the properties dialog for a path.
    var onShowProperties: ((_ path: String) -> Void)?
    /// Run a registered command by name (routed through the window controller).
    var onRunCommand: ((_ name: String) -> Void)?
    /// Fired when hidden-file visibility changes (for persistence).
    var onHiddenFilesChanged: ((Bool) -> Void)?
    /// Fired when the view is clicked (to activate its panel).
    var onActivate: (() -> Void)?
    /// Switch to the other panel synchronously (Tab); bypasses the async command
    /// registry so the active-panel highlight updates immediately.
    var onSwitchPanel: (() -> Void)?
    /// Mouse selection mode: "nc" (right-click marks) or "windows" (left selects).
    var mouseMode = "left"   // "left" (Windows/context-menu) | "nc" (right-click marks)

    init() {
        super.init(frame: .zero)
        setupTableView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTableView()
    }

    private func setupTableView() {
        gridStyleMask = []
        selectionHighlightStyle = .none
        allowsMultipleSelection = false
        allowsTypeSelect = false
        allowsColumnReordering = true
        usesAlternatingRowBackgroundColors = false
        backgroundColor = Theme.current.listBackground
        dataSource = self
        delegate = self
        rowHeight = Metrics.rowHeight
        registerForDraggedTypes([.fileURL])
        setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        setDraggingSourceOperationMask([.copy, .move], forLocal: false)

        let header = SortableHeaderView(tableView: self)
        // A custom NSTableHeaderView starts at zero height (→ invisible); give it the
        // standard header height so the column titles + sort arrows actually show.
        header.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 22)
        sortableHeaderView = header
        headerView = header
        header.menuProvider = { [weak self] in self?.buildColumnsHeaderMenu() }

        setupColumns()
    }

    // MARK: - Header column menu (context-aware column show/hide; F-024)

    /// Supplies (available fields, currently shown) for the header menu — set by
    /// the controller so the menu reflects the panel's current context.
    var columnsMenuData: (() -> (available: [ColumnSpec], current: [ColumnSpec]))?
    /// Toggle a column on/off in the current context (persisted by the controller).
    var onToggleColumn: ((String) -> Void)?
    /// Open the full column-configuration dialog for the current context.
    var onConfigureColumns: (() -> Void)?

    private func buildColumnsHeaderMenu() -> NSMenu? {
        guard let data = columnsMenuData?() else { return nil }
        let menu = NSMenu()
        let shown = Set(data.current.map(\.fieldID))
        for spec in data.available {
            let item = NSMenuItem(title: spec.title, action: #selector(toggleColumnItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = spec.fieldID
            item.state = shown.contains(spec.fieldID) ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let cfg = NSMenuItem(title: String(localized: "Configure Columns…"),
                             action: #selector(configureColumnsItem), keyEquivalent: "")
        cfg.target = self
        menu.addItem(cfg)
        return menu
    }

    @objc private func toggleColumnItem(_ sender: NSMenuItem) {
        if let fieldID = sender.representedObject as? String { onToggleColumn?(fieldID) }
    }
    @objc private func configureColumnsItem() { onConfigureColumns?() }

    private func setupColumns() {
        for spec in visibleColumns {
            addColumn(id: spec.fieldID, title: spec.title, width: CGFloat(spec.width))
        }
    }

    private func addColumn(id: String, title: String, width: CGFloat) {
        let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
        tableColumn.width = width
        tableColumn.minWidth = 30
        let headerCell = ThemedHeaderCell()
        headerCell.alignment = .left
        headerCell.font = Fonts.bold13
        tableColumn.headerCell = headerCell
        // Set the title AFTER assigning the header cell — assigning a fresh cell
        // resets the title to the default "Field".
        tableColumn.title = title
        addTableColumn(tableColumn)
    }

    /// Replace the full ordered set of visible columns (built-in + plugin).
    func setColumns(_ specs: [ColumnSpec]) {
        for tc in tableColumns { removeTableColumn(tc) }
        visibleColumns = specs.isEmpty ? PanelColumn.defaultSpecs : specs
        contentValues.removeAll(); contentSymbols.removeAll(); contentPending.removeAll()
        for spec in visibleColumns { addColumn(id: spec.fieldID, title: spec.title, width: CGFloat(spec.width)) }
        reloadData()
    }

    /// The current visible columns with live widths (for persistence).
    func currentColumns() -> [ColumnSpec] {
        visibleColumns.map { spec in
            let w = tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(spec.fieldID))
                .map { Int($0.width) } ?? spec.width
            return ColumnSpec(fieldID: spec.fieldID, title: spec.title, width: w, alignment: spec.alignment)
        }
    }

    /// Store a value a provider returned, undoing the `symbolName\ttext` wire format of an icon column
    /// *here* rather than where the cell is drawn (F-430).
    ///
    /// One place, because everything else reads this cache: sorting, "copy column value", the unaimed
    /// filter and the harness dump. The first version split it only while drawing, so the column sorted by
    /// SF Symbol name and the clipboard got `pencil.circle.fill<TAB>Modified`.
    private func storeContent(_ raw: String, _ fieldID: String, path: String) {
        guard iconContentFields.contains(fieldID) else {
            contentValues[path, default: [:]][fieldID] = raw
            return
        }
        let split = IconColumnValue.split(raw)
        contentValues[path, default: [:]][fieldID] = split.text
        if let symbol = split.symbol {
            contentSymbols[path, default: [:]][fieldID] = symbol
        } else {
            contentSymbols[path]?[fieldID] = nil
        }
    }

    /// The words of a value a *synchronous* provider returned — the two closures that bypass the cache.
    private func contentText(_ raw: String, _ fieldID: String) -> String {
        iconContentFields.contains(fieldID) ? IconColumnValue.split(raw).text : raw
    }

    /// Cached content value for `fieldID`/`path`, kicking a one-shot async fetch
    /// (then reloading the row) when not yet cached.
    private func contentValue(_ fieldID: String, path: String) -> String {
        if let v = contentValues[path]?[fieldID] { return v }
        let key = path + "\t" + fieldID
        if !contentPending.contains(key), let provider = contentValueProvider {
            contentPending.insert(key)
            Task { @MainActor in
                let val = await provider(fieldID, path) ?? ""
                storeContent(val, fieldID, path: path)
                contentPending.remove(key)
                // Find the row by name and confirm with one path build, rather than building
                // every entry's path to compare. One of these tasks runs per row, so the scan
                // was O(N²) path joins over the listing — the shape that made a large remote
                // directory freeze the panel for minutes.
                let name = (path as NSString).lastPathComponent
                if let idx = visibleEntries.firstIndex(where: { $0.name == name }),
                   fullPath(of: visibleEntries[idx]) == path {
                    reloadRow(forVisible: idx)
                }
            }
        }
        return ""
    }

    // MARK: - Public API

    /// Update the view with a new directory snapshot.
    func update(with snapshot: DirectorySnapshot, sortDescriptor: DirectoryModel.SortDescriptor? = nil,
                preserveViewport: Bool = false) {
        // Don't rebuild the table while an in-cell rename is open — the field
        // editor would be destroyed. The post-commit reload picks up the change.
        if isInlineEditing { return }
        // A file-handle highlight belongs to the listing it was searched in. The volatile
        // auto-refresh re-enters this with the same path and keeps it; navigating away drops it,
        // so colours cannot survive into a directory where they mean nothing.
        if let hl = fileHandleHighlightPath, hl != snapshot.path {
            fileHandleHighlights = [:]
            fileHandleHighlightPath = nil
        }
        // A search belongs to the listing it was typed into. Navigating away and keeping the prefix
        // would leave an indicator counting matches in names that are no longer on screen. A
        // *refresh* of the same directory leaves it alone — that is the volatile mount ticking, not
        // the user going anywhere.
        if self.snapshot?.path != snapshot.path { endTypeAhead() }
        self.snapshot = snapshot
        if let sortDescriptor { self.sortDescriptor = sortDescriptor }
        dirSizes.removeAll()
        commentMap.removeAll()   // descript.ion comments are per-listing (controller refills)
        contentValues.removeAll(); contentSymbols.removeAll(); contentPending.removeAll()   // plugin-column values are per-listing
        rebuildVisibleEntries()
        // A refresh must not move the cursor OR the view. Resetting to the first row was right for a
        // navigation and wrong for the reload a volatile mount does every two seconds: it threw away
        // the place the user was reading, and it did it while they were reading it.
        if preserveViewport {
            cursorRow = visibleEntries.isEmpty ? -1 : min(cursorRow, visibleEntries.count - 1)
        } else {
            cursorRow = visibleEntries.isEmpty ? -1 : 0
        }
        updateSortArrows(self.sortDescriptor)
        reapplyPluginSortSync()   // keep a content-column sort across auto-refresh
        prefetchContentValuesSync()   // fill content cells before drawing → no flicker
        // The scroll offset survives `reloadData` only if it is put back: the row count changes with
        // every process that starts or exits, and AppKit answers that by scrolling to the top.
        let offset = preserveViewport ? enclosingScrollView?.documentVisibleRect.origin : nil
        reloadData()
        if let offset { enclosingScrollView?.contentView.scroll(to: offset) }
        Task { await self.syncEntriesToSelectionState(); self.notifyChanged() }
    }

    /// Resolve the visible content-column values up front (synchronously, via the
    /// mount's `syncContentValue`) and cache them, so on a volatile auto-refresh the
    /// cells redraw already populated instead of blanking then filling in
    /// asynchronously (the visible flicker). No-op without a sync resolver (local FS).
    private func prefetchContentValuesSync() {
        guard let resolve = syncContentValue else { return }
        let contentColumns = visibleColumns.map(\.fieldID).filter { $0.contains(".") }
        guard !contentColumns.isEmpty else { return }
        for entry in visibleEntries {
            let p = fullPath(of: entry)
            for fieldID in contentColumns {
                storeContent(resolve(fieldID, p) ?? "", fieldID, path: p)
            }
        }
    }

    /// Assign the shared selection-state actor for this panel.
    func setSelectionState(_ state: SelectionState) {
        selectionState = state
        Task { await self.syncEntriesToSelectionState() }
    }

    /// Reflect the given sort descriptor's arrow in the header.
    func updateSortArrows(_ descriptor: DirectoryModel.SortDescriptor) {
        let column: PanelColumn
        switch descriptor {
        case .name: column = .name
        case .ext: column = .ext
        case .size: column = .size
        case .date: column = .date
        }
        sortableHeaderView?.setSortDirection(descriptor.isAscending ? .ascending : .descending, for: column.rawValue)
    }

    /// Full path of the entry (or `..`) under the cursor.
    func currentCursorFullPath() -> String? {
        guard let snapshot else { return nil }
        if cursorRow == -1 { return (snapshot.path as NSString).deletingLastPathComponent }
        guard let entry = entry(atCursor: cursorRow) else { return nil }
        return fullPath(of: entry)
    }

    /// Full path of the real entry under the cursor, or nil when the cursor is on `..`.
    func cursorItemFullPath() -> String? {
        guard cursorRow >= 0, let entry = entry(atCursor: cursorRow) else { return nil }
        return fullPath(of: entry)
    }

    /// Synchronous selection (or the cursor item when nothing is selected), for
    /// AppleScript reads. Uses the main-thread `selectedPaths` mirror.
    func selectedOrCursorPathsSync() -> [String] {
        if !selectedPaths.isEmpty { return selectedPaths.sorted() }
        if let cursor = cursorItemFullPath() { return [cursor] }
        return []
    }

    /// Full path of the directory under the cursor, or nil if the cursor is on `..`
    /// or a non-directory. Used by "open in new tab".
    func cursorDirectoryPath() -> String? {
        guard cursorRow >= 0, let entry = entry(atCursor: cursorRow),
              PanelEntryHelpers.isDirectoryLike(entry.kind) else { return nil }
        return fullPath(of: entry)
    }

    /// Visible file paths + the start index for the Lister (files only; cursor file if any).
    func listerContext() -> (paths: [String], index: Int) {
        let files = visibleEntries.filter { !PanelEntryHelpers.isDirectoryLike($0.kind) }
        let paths = files.map { fullPath(of: $0) }
        var start = 0
        if let name = cursorEntryName(),
           let i = files.firstIndex(where: { PathUtils.nameEquivalent($0.name, name) }) { start = i }
        return (paths, start)
    }

    /// Name of the entry under the cursor (nil when on `..`) — for per-tab cursor memory.
    func cursorEntryName() -> String? {
        guard cursorRow >= 0, let entry = entry(atCursor: cursorRow) else { return nil }
        return entry.name
    }

    /// Place the cursor on the entry with the given name (no-op → first entry if absent).
    /// Place the cursor on the ".." (parent) row — the default when entering a
    /// directory, so the cursor starts at the top rather than on the first file.
    func focusParent() {
        cursorRow = -1
        reloadData()
        scrollRowToVisible(0)
        Task { _ = await selectionState?.setCursorIndex(-1); notifyChanged() }
    }

    /// Put the cursor on `name`.
    ///
    /// `scroll` is false for a refresh: bringing the cursor row into view is what a *move* means, and
    /// doing it on a reload drags the view back every two seconds while the user is reading elsewhere.
    /// A name that is no longer there (a process exited) then keeps the cursor's place in the list
    /// rather than sending it to the top — the rows around it are still the ones being looked at.
    func focusEntry(named name: String?, scroll: Bool = true) {
        // NFC-tolerant match: the filesystem may return a decomposed (NFD) name
        // while the caller holds a precomposed (NFC) one, or vice versa (F-100).
        guard let name, let idx = visibleEntries.firstIndex(where: { PathUtils.nameEquivalent($0.name, name) }) else {
            if visibleEntries.isEmpty { cursorRow = -1 }
            else if !scroll { cursorRow = max(0, min(cursorRow, visibleEntries.count - 1)) }
            else { cursorRow = 0 }
            reloadData()
            Task { _ = await selectionState?.setCursorIndex(cursorRow); notifyChanged() }
            return
        }
        cursorRow = idx
        reloadData()
        if scroll { scrollRowToVisible(idx + 1) }
        Task { _ = await selectionState?.setCursorIndex(idx); notifyChanged() }
    }

    // MARK: - In-cell rename (F-081)

    /// Start an in-cell rename of the cursor item. Fails (returns false, so the
    /// caller can fall back to the dialog) when the cursor is on `..`, empty, or
    /// the Name column isn't visible. `onCommit` receives (oldName, newName) with a
    /// non-empty, changed name; the caller performs the actual rename.
    func beginInlineRename(onCommit: @escaping (_ old: String, _ new: String) -> Void) -> Bool {
        guard !isInlineEditing, cursorRow >= 0, let entry = entry(atCursor: cursorRow) else { return false }
        guard let nameCol = visibleColumns.firstIndex(where: { $0.fieldID == PanelColumn.name.rawValue })
        else { return false }
        let tableRow = cursorRow + 1   // row 0 is `..`
        scrollRowToVisible(tableRow)
        guard let cell = view(atColumn: nameCol, row: tableRow, makeIfNecessary: true) as? DirectoryCellView
        else { return false }
        let oldName = entry.name
        let basenameLen = inlineBasenameLength(oldName, isDir: PanelEntryHelpers.isDirectoryLike(entry.kind))
        isInlineEditing = true
        cell.beginInlineEdit(rawName: oldName, selectingBasenameOfLength: basenameLen) { [weak self] value in
            guard let self else { return }
            self.isInlineEditing = false
            let newName = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty, newName != oldName else {
                self.reloadRow(forVisible: self.cursorRow)   // repaint original name/decorations
                return
            }
            onCommit(oldName, newName)
        }
        return true
    }

    /// How many leading characters to preselect: the name minus its extension for
    /// files (so ".txt" isn't selected), the whole name for directories/dotfiles.
    private func inlineBasenameLength(_ name: String, isDir: Bool) -> Int {
        let ns = name as NSString
        if isDir { return ns.length }
        let dot = ns.range(of: ".", options: .backwards)
        if dot.location == NSNotFound || dot.location == 0 { return ns.length }
        return dot.location
    }

    /// Snapshot of selection counts/sizes for the status bar, including a
    /// files-vs-folders breakdown computed from the visible entries.
    func selectionSummary() async -> (selected: Int, total: Int, selectedBytes: Int64, totalBytes: Int64,
                                      selectedFiles: Int, totalFiles: Int, selectedDirs: Int, totalDirs: Int) {
        let dirs = visibleEntries.filter { PanelEntryHelpers.isDirectoryLike($0.kind) }
        let files = visibleEntries.filter { !PanelEntryHelpers.isDirectoryLike($0.kind) }
        let selDirs = dirs.filter { selectedPaths.contains(fullPath(of: $0)) }.count
        let selFiles = files.filter { selectedPaths.contains(fullPath(of: $0)) }.count
        guard let state = selectionState else {
            return (0, visibleEntries.count, 0, 0, 0, files.count, 0, dirs.count)
        }
        let stats = await state.getStatistics()
        let selBytes = await state.getSelectedSize()
        let totalBytes = await state.getTotalSize()
        return (stats.selected, stats.total, selBytes, totalBytes, selFiles, files.count, selDirs, dirs.count)
    }

    var isShowingHiddenFiles: Bool { showHiddenFiles }

    /// Apply display options and re-render.
    func applyDisplayOptions(sizeStyle: String, bracketDirs: Bool, dateFormat: String) {
        self.sizeStyleKey = sizeStyle
        self.bracketDirs = bracketDirs
        if dateFormat != dateFormatPattern {
            dateFormatPattern = dateFormat
            dateFormatter = PanelDateFormatter.makeFormatter(pattern: dateFormat)
        }
        reloadData()
    }

    /// Re-render after a theme/appearance change.
    func reloadForAppearance() {
        backgroundColor = Theme.current.listBackground
        reloadData()
    }

    // MARK: - Model helpers

    /// Rows in the listing before the filter — the denominator of "3 of 1217".
    private var allEntryCount: Int {
        guard let snapshot else { return 0 }
        return showHiddenFiles ? snapshot.entries.count : snapshot.entries.filter { !$0.isHidden }.count
    }

    private func rebuildVisibleEntries() {
        guard let snapshot else { visibleEntries = []; return }
        var result = showHiddenFiles ? snapshot.entries : snapshot.entries.filter { !$0.isHidden }
        if !filterText.isEmpty {
            let lower = filterText.lowercased()
            if lower.hasPrefix("tag:") || lower.hasPrefix("#") {
                // Finder-tag filter: "tag:red" / "#blau" match a tag color; a bare
                // "tag:" (or "tag:*"/"tag:any") matches any tagged file.
                let spec = lower.hasPrefix("tag:") ? String(lower.dropFirst(4)) : String(lower.dropFirst(1))
                result = result.filter { entry in
                    let indices = FinderTagColor.tagColorIndices(forPath: fullPath(of: entry))
                    if spec.isEmpty || spec == "*" || spec == "any" { return !indices.isEmpty }
                    if let wanted = FinderTagColor.colorIndex(forName: spec) { return indices.contains(wanted) }
                    return false
                }
            } else {
                // "user:root state:R" — see PanelFilterQuery. Plain text keeps its old meaning: one
                // substring over the name and (on a mount) the columns.
                let query = PanelFilterQuery.parse(filterText, fieldIDs: filterableFieldIDs())
                result = result.filter { entry in
                    query.matches(value: { fieldValue($0, entry: entry) },
                                  anywhere: { rowValues(of: entry) })
                }
            }
        }
        visibleEntries = result
    }

    /// Field ids a filter term may name (F-397): the mount's own columns, whether or not they are
    /// currently shown. Aiming at a column you have hidden is still a fair question — and it is the
    /// difference between "the filter forgot how to do that" and "add the column back first".
    private func filterableFieldIDs() -> [String] {
        guard syncContentValue != nil else { return [] }
        var ids = mountContentFieldIDs
        // A mount may publish more fields than the panel shows; the shown ones are a superset only
        // when the controller has not been told about the rest, so both lists contribute.
        for spec in visibleColumns where PanelColumn(rawValue: spec.fieldID) == nil {
            if !ids.contains(spec.fieldID) { ids.append(spec.fieldID) }
        }
        return ids
    }

    /// One column's value for an entry, from the prefetch cache or the mount.
    private func fieldValue(_ fieldID: String, entry: VFSEntry) -> String {
        let path = fullPath(of: entry)
        if let v = contentValues[path]?[fieldID] { return v }
        return contentText(syncContentValue?(fieldID, path) ?? "", fieldID)
    }

    /// Everything an unaimed term may match: the name, and on a mount the columns it shows.
    ///
    /// The *shown* columns, deliberately: an unaimed word searches what is on screen, which is what
    /// makes the result explainable ("it matched that cell"). A hidden column is reachable by naming
    /// it instead.
    private func rowValues(of entry: VFSEntry) -> [String] {
        var values = [entry.name]
        guard syncContentValue != nil else { return values }
        for spec in visibleColumns where PanelColumn(rawValue: spec.fieldID) == nil {
            let v = fieldValue(spec.fieldID, entry: entry)
            if !v.isEmpty { values.append(v) }
        }
        return values
    }

    // MARK: - Quick filter (I06-T04)

    /// Public entry for cm_QuickFilter (mirrors the Ctrl+S in-view shortcut).
    func toggleQuickFilter() { toggleFilterMode() }

    /// Apply a quick filter without typing it, so a check can ask what the filter actually keeps.
    func automationSetFilter(_ text: String) {
        filterMode = true
        filterText = text
        applyFilterLive()
    }

    private func toggleFilterMode() {
        filterMode.toggle()
        if filterMode {
            filterText = ""
            onFilterChanged?("", visibleEntries.count, allEntryCount)
        } else {
            clearFilter()
        }
    }

    private func clearFilter() {
        endTypeAhead()
        filterMode = false
        filterText = ""
        onFilterChanged?(nil, visibleEntries.count, allEntryCount)
        rebuildVisibleEntries()
        cursorRow = visibleEntries.isEmpty ? -1 : 0
        reloadData()
        Task { await self.syncEntriesToSelectionState(); notifyChanged() }
    }

    private func exitFilterKeepingResults() {
        filterMode = false
        onFilterChanged?(filterText.isEmpty ? nil : filterText, visibleEntries.count, allEntryCount)
    }

    private func appendFilter(_ s: String) {
        filterText += s
        applyFilterLive()
    }

    private func backspaceFilter() {
        guard !filterText.isEmpty else { return }
        filterText.removeLast()
        applyFilterLive()
    }

    private func applyFilterLive() {
        onFilterChanged?(filterText, visibleEntries.count, allEntryCount)
        rebuildVisibleEntries()
        cursorRow = visibleEntries.isEmpty ? -1 : 0
        reloadData()
        Task { await self.syncEntriesToSelectionState(); notifyChanged() }
    }

    private func entry(atCursor visibleIndex: Int) -> VFSEntry? {
        guard visibleIndex >= 0 && visibleIndex < visibleEntries.count else { return nil }
        return visibleEntries[visibleIndex]
    }

    /// Joins the listing's directory with an entry name — as a *string*, never through `URL`.
    ///
    /// `URL(fileURLWithPath:)` and `appendingPathComponent(_:)` default to `directoryHint:
    /// .checkFileSystem`, so each of them asks the local filesystem whether the path is a
    /// directory. That is wrong twice over for a remote listing: the path is not a local file
    /// at all, and an SFTP server's `/home/...` collides with the macOS `auto_home` automount,
    /// where a single `lstat` costs ~7 ms instead of ~1 µs. This is the hottest call in the
    /// panel (every cell, every row), so it does no I/O.
    private func fullPath(of entry: VFSEntry) -> String {
        guard let snapshot else { return entry.name }
        return (snapshot.path as NSString).appendingPathComponent(entry.name)
    }

    private func effectiveSize(of entry: VFSEntry) -> Int64 {
        if PanelEntryHelpers.isDirectoryLike(entry.kind) {
            return dirSizes[fullPath(of: entry)] ?? -1
        }
        return entry.size
    }

    /// Push the current visible entries (with any computed dir sizes) into the actor.
    private func syncEntriesToSelectionState() async {
        guard let state = selectionState else { return }
        let entries = visibleEntries.map { entry in
            SelectableEntry(path: fullPath(of: entry),
                            size: effectiveSize(of: entry),
                            isDirectory: PanelEntryHelpers.isDirectoryLike(entry.kind))
        }
        await state.setEntries(entries)
        _ = await state.setCursorIndex(cursorRow)
        selectedPaths = await state.getSelectedPaths()
    }

    private func refreshSelectionMirror() async {
        guard let state = selectionState else { return }
        selectedPaths = await state.getSelectedPaths()
    }

    private func notifyChanged() {
        onSelectionOrCursorChanged?()
    }

    // MARK: - Data source / delegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        visibleEntries.count + 1 // +1 for `..`
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = (tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("PCRow"), owner: self) as? CursorRowView) ?? {
            let v = CursorRowView()
            v.identifier = NSUserInterfaceItemIdentifier("PCRow")
            return v
        }()
        rowView.isCursor = (row == cursorRow + 1)
        rowView.isActivePanel = isActivePanel
        rowView.zebra = zebraStripes          // F-032
        rowView.isOddRow = (row % 2 == 1)
        return rowView
    }

    /// Alternating row background (F-032). Repaints visible rows on change.
    var zebraStripes = false {
        didSet { if oldValue != zebraStripes { reloadData() } }
    }

    /// Set the configurable panel-list font size (F-272): updates the shared panel
    /// fonts, grows the row height to fit, and repaints. Clamped to a sane range.
    func setPanelFontSize(_ size: Int) {
        Fonts.panelSize = CGFloat(max(9, min(28, size)))
        rowHeight = max(Metrics.rowHeight, Fonts.panelSize + 6)
        reloadData()
    }

    /// Whether this panel is the active one (drives the cursor-row tint).
    var isActivePanel: Bool = false {
        didSet {
            guard oldValue != isActivePanel else { return }
            enumerateAvailableRowViews { rowView, _ in
                (rowView as? CursorRowView)?.isActivePanel = isActivePanel
            }
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let columnID = tableColumn?.identifier.rawValue else { return nil }

        // Plugin-provided content column (any id that isn't a built-in) — e.g.
        // Git Status / Branch. Value fetched lazily via the content-field cache.
        guard let column = PanelColumn(rawValue: columnID) else {
            let cell = makePlainCell()
            if row == 0 { cell.configure(text: "", isSelected: false); return cell }
            guard let entry = entry(atCursor: row - 1) else { return nil }
            let path = fullPath(of: entry)
            // The file-handle highlight (F-390) reaches these too, or the row would be coloured in
            // its name and plain in PID / CPU / Command — which in a TaskManager listing is most of
            // what the eye is on.
            let handleColor = fileHandleHighlights[entry.name]?.color
            // The words come from the value cache and the icon from beside it: both were split on the way
            // in, so nothing here has to know about the wire format (F-430).
            let text = contentValue(columnID, path: path)
            let symbol = contentSymbols[path]?[columnID]
            cell.configure(text: text, isSelected: selectedPaths.contains(path),
                           color: handleColor, keepColorOnCursorRow: handleColor != nil,
                           symbolName: symbol)
            return cell
        }

        // Row 0 is `..`
        if row == 0 {
            if column == .name {
                let cell = makeNameCell()
                let req = IconRequest(fullPath: parentPath(), ext: "", isDirectory: true,
                                      isApplication: false, isSymlink: false)
                cell.configure(name: "..", request: req, isSelected: false)
                return cell
            }
            let cell = makePlainCell()
            cell.configure(text: column == .attr ? "<UP>" : "", isSelected: false,
                           alignment: column == .size ? .right : .left)
            return cell
        }

        guard let entry = entry(atCursor: row - 1) else { return nil }
        let path = fullPath(of: entry)
        let isSelected = selectedPaths.contains(path)
        let isDir = PanelEntryHelpers.isDirectoryLike(entry.kind)
        // The file-handle highlight (F-390) outranks the by-type colour: it answers a question the
        // user asked a moment ago, while the type colour is standing decoration. It is also pinned
        // through the cursor bar, which the type colour is not — see `PlainCellView.isMarked`.
        let handleColor = fileHandleHighlights[entry.name]?.color
        let keepColor = handleColor != nil
        let rowColor = handleColor ?? (typeColors.isEmpty ? nil : typeColors.color(for: entry.name))   // F-032

        switch column {
        case .name:
            let cell = makeNameCell()
            let req = PanelEntryHelpers.iconRequest(for: entry, fullPath: path)
            // Show a POSIX ":" as "/" the way the Finder does (F-100).
            let shownName = PathUtils.displayName(fromPOSIX: entry.name)
            var display = (bracketDirs && isDir) ? "[\(shownName)]" : shownName
            if PanelEntryHelpers.isSymlink(entry.kind) { display += "  ↳" }
            let badge = badgeFieldID.map { contentValue($0, path: path) }
            cell.configure(name: display, request: req, isSelected: isSelected,
                           badge: (badge?.isEmpty ?? true) ? nil : badge, color: rowColor,
                           keepColorOnCursorRow: keepColor)
            return cell
        case .ext:
            let cell = makePlainCell()
            cell.configure(text: entry.ext, isSelected: isSelected, color: rowColor,
                           keepColorOnCursorRow: keepColor)
            return cell
        case .size:
            let cell = makePlainCell()
            cell.configure(text: sizeText(for: entry, isDir: isDir), isSelected: isSelected,
                           monospaced: true, alignment: .right, color: rowColor,
                           keepColorOnCursorRow: keepColor)
            return cell
        case .date:
            let cell = makePlainCell()
            cell.configure(text: dateText(entry.modified), isSelected: isSelected, monospaced: true,
                           color: rowColor, keepColorOnCursorRow: keepColor)
            return cell
        case .attr:
            let cell = makePlainCell()
            cell.configure(text: attrText(entry, path: isLocalFileSystem ? path : nil),
                           isSelected: isSelected, monospaced: true,
                           color: rowColor, keepColorOnCursorRow: keepColor)
            return cell
        case .tag:
            let cell = makeTagCell()
            cell.configure(colors: isLocalFileSystem ? FinderTagColor.colors(forPath: path) : [])
            return cell
        case .comment:
            let cell = makePlainCell()
            cell.configure(text: commentMap[entry.name] ?? "", isSelected: isSelected, color: rowColor,
                           keepColorOnCursorRow: keepColor)
            return cell
        }
    }

    /// The text a column currently shows for `entry` — used to copy column values.
    /// Built-ins format from the entry; content columns read the cache (populated
    /// by the sync prefetch) or resolve on the spot.
    func cellText(forColumn fieldID: String, entry: VFSEntry) -> String {
        let path = fullPath(of: entry)
        guard let column = PanelColumn(rawValue: fieldID) else {
            return contentValues[path]?[fieldID]
                ?? contentText(syncContentValue?(fieldID, path) ?? "", fieldID)
        }
        switch column {
        case .name: return entry.name
        case .ext:  return entry.ext
        case .size: return sizeText(for: entry, isDir: PanelEntryHelpers.isDirectoryLike(entry.kind))
        case .date: return dateText(entry.modified)
        case .attr: return attrText(entry, path: path)
        case .tag:  return ""   // tags are colors, not copyable text
        case .comment: return commentMap[entry.name] ?? ""
        }
    }

    /// Submenu that copies the cursor row's value for any visible column (or the
    /// whole row, tab-separated). Nil when the cursor is on `..`/empty.
    func buildCopyValueMenu() -> NSMenu? {
        guard cursorRow >= 0, let entry = entry(atCursor: cursorRow) else { return nil }
        let menu = NSMenu()
        for spec in visibleColumns where spec.fieldID != "tag" {
            let item = NSMenuItem(title: spec.title, action: #selector(copyColumnValue(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = spec.fieldID
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let row = NSMenuItem(title: String(localized: "Whole Row"), action: #selector(copyWholeRow), keyEquivalent: "")
        row.target = self
        menu.addItem(row)
        _ = entry
        return menu
    }

    @objc private func copyColumnValue(_ sender: NSMenuItem) {
        guard let fieldID = sender.representedObject as? String,
              cursorRow >= 0, let entry = entry(atCursor: cursorRow) else { return }
        writeToClipboard(cellText(forColumn: fieldID, entry: entry))
    }

    @objc private func copyWholeRow() {
        guard cursorRow >= 0, let entry = entry(atCursor: cursorRow) else { return }
        let text = visibleColumns.filter { $0.fieldID != "tag" }
            .map { cellText(forColumn: $0.fieldID, entry: entry) }
            .joined(separator: "\t")
        writeToClipboard(text)
    }

    private func writeToClipboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func makeNameCell() -> DirectoryCellView {
        (makeView(withIdentifier: DirectoryCellView.reuseID, owner: self) as? DirectoryCellView) ?? DirectoryCellView()
    }

    private func makePlainCell() -> PlainCellView {
        (makeView(withIdentifier: PlainCellView.reuseID, owner: self) as? PlainCellView) ?? PlainCellView()
    }

    private func makeTagCell() -> TagCellView {
        (makeView(withIdentifier: TagCellView.reuseID, owner: self) as? TagCellView) ?? TagCellView()
    }

    private func parentPath() -> String {
        guard let snapshot else { return "/" }
        return (snapshot.path as NSString).deletingLastPathComponent
    }

    // MARK: - Formatting

    private func sizeText(for entry: VFSEntry, isDir: Bool) -> String {
        if isDir {
            if let size = dirSizes[fullPath(of: entry)] { return formatBytes(size) }
            return "<DIR>"
        }
        return formatBytes(entry.size)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        switch sizeStyleKey {
        case "bytes": return ByteSize(bytes).formatted(style: .bytesWithSep)
        case "dynamic": return SelectionSummaryFormatter.dynamicSize(bytes)
        default: return ByteSize(bytes).formatted(style: .kb)
        }
    }

    private func dateText(_ date: Date) -> String {
        // A mount says "0" for a timestamp it does not have (the SDK spells that out), and the
        // formatter turns that into 1970-01-01 — a date the row does not have, printed as though it
        // did. Blank instead: TaskManager cannot read another user's process start time, and an
        // empty cell says so where "1970" claims something false.
        guard date.timeIntervalSince1970 != 0 else { return "" }
        return dateFormatter.string(from: date)
    }

    private func attrText(_ entry: VFSEntry, path: String? = nil) -> String {
        let base = entry.attrColumnString   // type + rwx + BSD-flag suffix (F-038)
        // Trailing "@" when the file carries extended attributes (like `ls -l@`).
        // Queried only for the given (visible-row) path, so it stays cheap.
        if let path, Self.hasExtendedAttributes(path) { return base + "@" }
        return base
    }

    /// True if `path` has a *meaningful* extended attribute. macOS auto-stamps
    /// nearly every file with `com.apple.provenance`, so counting it (as `ls -l@`
    /// does) would badge everything; we ignore it and flag only real xattrs
    /// (quarantine, Finder comment/tags, resource forks, custom metadata, …).
    private static func hasExtendedAttributes(_ path: String) -> Bool {
        let size = path.withCString { listxattr($0, nil, 0, XATTR_NOFOLLOW) }
        guard size > 0 else { return false }
        var buffer = [CChar](repeating: 0, count: size)
        let written = path.withCString { listxattr($0, &buffer, size, XATTR_NOFOLLOW) }
        guard written > 0 else { return false }
        var start = 0
        let bytes = buffer.prefix(written)
        for (i, c) in bytes.enumerated() where c == 0 {
            if i > start,
               let name = String(bytes: bytes[start..<i].map { UInt8(bitPattern: $0) }, encoding: .utf8),
               name != "com.apple.provenance" {
                return true
            }
            start = i + 1
        }
        return false
    }

    // MARK: - Cursor movement

    private func moveCursor(to newRow: Int) {
        guard !visibleEntries.isEmpty || newRow == -1 else { return }
        let clamped = max(-1, min(newRow, visibleEntries.count - 1))
        guard clamped != cursorRow else { return }
        let old = cursorRow
        cursorRow = clamped
        updateCursorFrame(oldVisible: old, newVisible: clamped)
        scrollRowToVisible(clamped + 1)
        Task { _ = await selectionState?.setCursorIndex(clamped); self.notifyChanged() }
    }

    private func updateCursorFrame(oldVisible: Int, newVisible: Int) {
        for tableRow in [oldVisible + 1, newVisible + 1] {
            if let rv = rowView(atRow: tableRow, makeIfNecessary: false) as? CursorRowView {
                rv.isCursor = (tableRow == newVisible + 1)
            }
        }
    }

    /// The current visible entries (for an alternate view, e.g. the icon grid).
    func currentVisibleEntries() -> [VFSEntry] { visibleEntries }
    /// Move the cursor to a visible-entry index (used by the icon grid to sync).
    func focusVisibleIndex(_ index: Int) { moveCursor(to: index) }
    /// Move the cursor to a visible-entry index and open it (icon-grid double-click/Enter).
    func activateVisibleIndex(_ index: Int) { moveCursor(to: index); handleEnter() }

    func moveCursorUp() { moveCursor(to: cursorRow - 1) }
    func moveCursorDown() { moveCursor(to: cursorRow + 1) }
    func moveCursorTop() { moveCursor(to: visibleEntries.isEmpty ? -1 : 0) }
    func moveCursorBottom() { moveCursor(to: visibleEntries.count - 1) }
    func moveCursorPageUp() { moveCursor(to: max(-1, cursorRow - visibleRowCount())) }
    func moveCursorPageDown() { moveCursor(to: cursorRow + visibleRowCount()) }

    private func visibleRowCount() -> Int {
        max(1, Int(enclosingScrollView?.contentView.bounds.height ?? bounds.height) / Int(rowHeight) - 1)
    }

    // MARK: - Selection operations

    private func reloadRow(forVisible visibleIndex: Int) {
        let tableRow = visibleIndex + 1
        guard tableRow >= 0 && tableRow < numberOfRows(in: self) else { return }
        reloadData(forRowIndexes: IndexSet(integer: tableRow), columnIndexes: IndexSet(0..<numberOfColumns))
    }

    /// Space: toggle mark on the cursor entry; if a directory, also compute its size.
    func toggleMarkAtCursor() {
        guard let entry = entry(atCursor: cursorRow) else { return }
        let path = fullPath(of: entry)
        let visible = cursorRow
        Task {
            guard let state = selectionState else { return }
            _ = await state.toggleSelection(path)
            await refreshSelectionMirror()
            reloadRow(forVisible: visible)
            notifyChanged()
            if PanelEntryHelpers.isDirectoryLike(entry.kind) {
                await computeDirSize(for: entry)
            }
        }
    }

    /// Insert: toggle mark on the cursor entry, then advance the cursor.
    func toggleMarkAndAdvance() {
        guard let entry = entry(atCursor: cursorRow) else { return }
        let path = fullPath(of: entry)
        let visible = cursorRow
        Task {
            guard let state = selectionState else { return }
            _ = await state.toggleSelection(path)
            await refreshSelectionMirror()
            reloadRow(forVisible: visible)
            moveCursorDown()
            notifyChanged()
        }
    }

    /// Shift+arrow: toggle the current entry, then move (TC range marking).
    private func rangeToggle(moveDown: Bool) {
        guard entry(atCursor: cursorRow) != nil else {
            moveDown ? moveCursorDown() : moveCursorUp()
            return
        }
        toggleMarkAndAdvanceDirection(down: moveDown)
    }

    private func toggleMarkAndAdvanceDirection(down: Bool) {
        guard let entry = entry(atCursor: cursorRow) else { return }
        let path = fullPath(of: entry)
        let visible = cursorRow
        Task {
            guard let state = selectionState else { return }
            _ = await state.toggleSelection(path)
            await refreshSelectionMirror()
            reloadRow(forVisible: visible)
            down ? moveCursorDown() : moveCursorUp()
            notifyChanged()
        }
    }

    func markAll() {
        runSelectionOp { await $0.selectAll() != false }
    }

    func unmarkAll() {
        runSelectionOp { await $0.clearSelection() != false }
    }

    func invertMarks() {
        runSelectionOp { _ = await $0.invertSelection(); return true }
    }

    /// Num/ — bring back the selection from before the last selection operation (F-056).
    ///
    /// Deliberately *not* through `runSelectionOp`: that helper saves the current selection to the
    /// history before running the operation, which is right for every operation except this one. Routed
    /// through it, the restore pushed the current selection and then popped the very thing it had just
    /// pushed, so Num/ did nothing at all.
    func restoreSelection() {
        Task {
            guard let state = selectionState else { return }
            guard await state.restoreSelectionFromHistory() else { return }
            await refreshSelectionMirror()
            reloadData()
            notifyChanged()
        }
    }

    func selectSameExtensionAtCursor() {
        Task {
            guard let state = selectionState else { return }
            _ = await state.setCursorIndex(cursorRow)
            await state.saveSelectionToHistory()
            _ = await state.selectSameExtension()
            await refreshSelectionMirror()
            reloadData()
            notifyChanged()
        }
    }

    /// Keymap router: given a key event, returns true if it was routed to a command.
    /// Set by the window controller; consulted before menu/keyDown handling.
    var keymapRouter: ((NSEvent) -> Bool)?

    /// Does the focused view want this key untouched? Set by the window controller (F-381).
    var wantsRawKeyboard: ((NSEvent) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // performKeyEquivalent is broadcast to every view in the window, so the panel would otherwise
        // swallow keys aimed at whatever is focused — Cmd+C/V/X/A are mapped to file-clipboard
        // commands, and the F-keys and Ctrl combinations to everything else.
        //
        // This used to ask `window?.firstResponder is NSText`, and to hand over only the five standard
        // edit shortcuts. That was a fix for the command line rather than for the class: anything
        // focusable that is not an NSText — a terminal, a plugin's editor — walked back into the same
        // defect, with F5 taken by "copy files" while the user was aiming at what was running inside
        // it. `RawKeyboard` asks the focused view instead, and when the answer is yes *nothing* is
        // taken, not merely the five.
        if wantsRawKeyboard?(event) == true { return false }
        if keymapRouter?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }

    // Standard edit actions routed to the panel's file-clipboard commands. The Edit
    // menu's Copy/Cut/Paste/Select-All use these selectors and target the first
    // responder, so when a text field is focused they do TEXT copy/paste (its field
    // editor gets them) and when the panel is focused they operate on files — both
    // via menu clicks and the responder chain, in every window.
    @objc func copy(_ sender: Any?)  { runClipboardCommand("cm_CopyToClipboard") }
    @objc func cut(_ sender: Any?)   { runClipboardCommand("cm_CutToClipboard") }
    @objc func paste(_ sender: Any?) { runClipboardCommand("cm_PasteFromClipboard") }
    @objc override func selectAll(_ sender: Any?) { runClipboardCommand("cm_MarkAll") }
    /// Undo the last file operation when a panel is first responder (F-101); a
    /// focused text field gets its own field-editor undo via the same menu item.
    @objc func undo(_ sender: Any?) { (window?.windowController as? MainWindowController)?.undoLastOperation() }

    private func runClipboardCommand(_ name: String) {
        (window?.windowController as? MainWindowController)?.runCommandNamed(name)
    }

    /// The entries currently visible in the panel (files + dirs, post hidden-filter).
    func currentEntries() -> [VFSEntry] { visibleEntries }

    /// Full paths of the currently selected non-directory entries (main-thread mirror).
    func selectedFilePaths() -> [String] {
        visibleEntries
            .filter { !PanelEntryHelpers.isDirectoryLike($0.kind) && selectedPaths.contains(fullPath(of: $0)) }
            .map { fullPath(of: $0) }
    }

    /// Selected items including directories (excludes the ".." entry). Used by
    /// occupied-space, where folders count recursively.
    func selectedItemPaths() -> [String] {
        visibleEntries
            .filter { $0.name != ".." && selectedPaths.contains(fullPath(of: $0)) }
            .map { fullPath(of: $0) }
    }

    /// Select exactly the entries whose leaf name is in `names` (Compare Directories).
    /// Existing selection is cleared first; the previous selection is saved for restore.
    func markNames(_ names: Set<String>) {
        Task {
            guard let state = selectionState else { return }
            await state.saveSelectionToHistory()
            _ = await state.clearSelection()
            for entry in visibleEntries where names.contains(entry.name) {
                _ = await state.select(fullPath(of: entry))
            }
            await refreshSelectionMirror()
            reloadData()
            notifyChanged()
        }
    }

    /// Apply a wildcard mask to select or unselect entries (Num+/Num- dialog result).
    func applySelectionMask(_ mask: String, unselect: Bool, includeDirectories: Bool) {
        Task { _ = await applyingSelectionMask(mask, unselect: unselect, includeDirectories: includeDirectories) }
    }

    /// The same, awaited, returning how many entries it newly marked (or unmarked).
    ///
    /// The fire-and-forget version above is right for a keystroke: nothing is waiting on the answer. It
    /// is wrong for a caller that has to *report* what happened — `set_selection` read the selection on
    /// the line after calling it and got the state from before the Task ran, so a mask that had just
    /// matched three files was reported as matching none (F-478). Same body, one `await` available.
    ///
    /// The count is of *newly* marked entries, so it is not a match count: a mask naming files that were
    /// already selected returns zero. A caller that wants "is anything selected now" has to ask the
    /// selection state, not this.
    ///
    /// - Parameter replacing: clear the selection first, so afterwards *only* the matches are marked.
    ///   The keyboard's mask commands add to the selection, and so does AppleScript's `select` — that is
    ///   what "select more" means at a keystroke and it is long-shipped behaviour. A macro needs the
    ///   other reading: a macro that says "select every PDF" has to do the same thing whatever was
    ///   marked when it started, or it is not reproducible, and its next step would move files nobody
    ///   named (F-478).
    @discardableResult
    func applyingSelectionMask(_ mask: String, unselect: Bool, includeDirectories: Bool,
                               replacing: Bool = false) async -> Int {
        guard let state = selectionState else { return 0 }
        await state.saveSelectionToHistory()
        if replacing { _ = await state.clearSelection() }
        let changed = unselect
            ? await state.unselectByMask(mask, includeDirectories: includeDirectories)
            : await state.selectByMask(mask, includeDirectories: includeDirectories)
        await refreshSelectionMirror()
        reloadData()
        notifyChanged()
        return changed
    }

    private func runSelectionOp(_ op: @escaping (SelectionState) async -> Bool) {
        Task {
            guard let state = selectionState else { return }
            await state.saveSelectionToHistory()
            _ = await op(state)
            await refreshSelectionMirror()
            reloadData()
            notifyChanged()
        }
    }

    // MARK: - Directory sizes

    private func computeDirSize(for entry: VFSEntry) async {
        let path = fullPath(of: entry)
        let size = await dirSizeCalculator.size(of: path)
        dirSizes[path] = size
        await syncEntriesToSelectionState()
        if let idx = visibleEntries.firstIndex(where: { fullPath(of: $0) == path }) {
            reloadRow(forVisible: idx)
        }
        notifyChanged()
    }

    /// Alt+Shift+Enter: compute sizes for all visible directories (bounded concurrency).
    func calculateAllDirectorySizes() {
        let dirPaths = visibleEntries
            .filter { PanelEntryHelpers.isDirectoryLike($0.kind) }
            .map { fullPath(of: $0) }
        guard !dirPaths.isEmpty else { return }
        Task {
            let results = await dirSizeCalculator.sizes(of: dirPaths, maxConcurrency: 4)
            for (path, size) in results { dirSizes[path] = size }
            await syncEntriesToSelectionState()
            reloadData()
            notifyChanged()
        }
    }

    // MARK: - Hidden files

    /// Set hidden-file visibility without toggling (used on session restore).
    func setHiddenFiles(_ show: Bool) {
        guard show != showHiddenFiles else { return }
        applyHiddenChange(show)
    }

    func toggleHiddenFiles() {
        applyHiddenChange(!showHiddenFiles)
        onHiddenFilesChanged?(showHiddenFiles)
    }

    private func applyHiddenChange(_ show: Bool) {
        showHiddenFiles = show
        let cursorPath = currentCursorFullPath()
        rebuildVisibleEntries()
        // Keep cursor on the same entry if still visible, else clamp.
        if let cursorPath, let idx = visibleEntries.firstIndex(where: { fullPath(of: $0) == cursorPath }) {
            cursorRow = idx
        } else {
            cursorRow = visibleEntries.isEmpty ? -1 : min(cursorRow, visibleEntries.count - 1)
        }
        reloadData()
        Task { await self.syncEntriesToSelectionState(); self.notifyChanged() }
    }

    // MARK: - Sorting

    func sort(by column: PanelColumn) {
        let newDescriptor: DirectoryModel.SortDescriptor
        if descriptorColumn(sortDescriptor) == column {
            newDescriptor = sortDescriptor.reversed()
        } else {
            newDescriptor = column.defaultSortDescriptor
        }
        sortDescriptor = newDescriptor
        updateSortArrows(newDescriptor)
        onSortColumn?(column, newDescriptor.isAscending)
    }

    /// Header click → sort by that column (toggling direction on repeat clicks).
    func tableView(_ tableView: NSTableView, mouseDownInHeaderOf tableColumn: NSTableColumn) {
        onActivate?()
        if let column = PanelColumn(rawValue: tableColumn.identifier.rawValue) {
            pluginSort = nil
            sort(by: column)
        } else {
            sortByPluginColumn(tableColumn.identifier.rawValue)
        }
    }

    // Client-side sort by a plugin (content-field) column — the values live in the
    // view's cache, not the model. Transient: a new listing or a built-in sort resets it.
    private var pluginSort: (fieldID: String, ascending: Bool)?

    /// A synchronous per-entry value resolver for the active mount's content
    /// columns (PFXFileSystem.contentDisplay). Set by the controller for content
    /// mounts; lets a plugin-column sort be re-applied instantly on auto-refresh.
    var syncContentValue: ((_ fieldID: String, _ path: String) -> String?)?

    /// The value a plugin column SORTS by, when that differs from what it shows — a size column
    /// displays "9.9 MB" and must order by the byte count behind it. Falls back to the displayed
    /// string when the mount does not distinguish the two.
    var sortContentValue: ((_ fieldID: String, _ path: String) -> String?)?

    /// Order two entries by a plugin column's value (dirs first, numeric-aware,
    /// name tiebreak). `value` resolves an entry's display string for the column.
    private func pluginRowLess(_ a: VFSEntry, _ b: VFSEntry, numeric: Bool,
                               ascending: Bool, value: (VFSEntry) -> String) -> Bool {
        let ad = PanelEntryHelpers.isDirectoryLike(a.kind), bd = PanelEntryHelpers.isDirectoryLike(b.kind)
        if ad != bd { return ad }   // directories first
        let av = value(a), bv = value(b)
        let cmp: ComparisonResult
        if numeric {
            // Blanks (missing metric) sink to the bottom so real values lead.
            let an = Double(av) ?? -Double.greatestFiniteMagnitude
            let bn = Double(bv) ?? -Double.greatestFiniteMagnitude
            cmp = an < bn ? .orderedAscending : (an > bn ? .orderedDescending : .orderedSame)
        } else {
            cmp = av.localizedCaseInsensitiveCompare(bv)
        }
        if cmp == .orderedSame { return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending }
        return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
    }

    /// Re-apply the active plugin-column sort synchronously (values resolved via
    /// `syncContentValue`, cached in `contentValues`). Used from `update` so the
    /// chosen sort survives a volatile mount's auto-refresh. No-op if no plugin
    /// sort is active or no synchronous resolver is available.
    private func reapplyPluginSortSync() {
        guard let ps = pluginSort, let resolve = syncContentValue else { return }
        let numeric = numericContentFields.contains(ps.fieldID)
        let order = sortContentValue ?? resolve
        visibleEntries.sort { a, b in
            pluginRowLess(a, b, numeric: numeric, ascending: ps.ascending) { e in
                let p = fullPath(of: e)
                // The displayed value is still cached for drawing; ordering asks for the raw one.
                if contentValues[p]?[ps.fieldID] == nil {
                    contentValues[p, default: [:]][ps.fieldID] = resolve(ps.fieldID, p) ?? ""
                }
                return order(ps.fieldID, p) ?? ""
            }
        }
        sortableHeaderView?.setSortDirection(ps.ascending ? .ascending : .descending, for: ps.fieldID)
    }

    /// Sort by a plugin column, as clicking its header does — so a check can ask whether a
    /// formatted column still orders by the value behind it (F-392).
    func automationSortByPluginColumn(_ fieldID: String) { sortByPluginColumn(fieldID) }

    private func sortByPluginColumn(_ fieldID: String) {
        guard let provider = contentValueProvider else { return }
        let ascending = (pluginSort?.fieldID == fieldID) ? !(pluginSort?.ascending ?? true) : true
        pluginSort = (fieldID, ascending)
        sortableHeaderView?.setSortDirection(ascending ? .ascending : .descending, for: fieldID)
        Task { @MainActor in
            var values: [String: String] = [:]
            for e in visibleEntries {
                let p = fullPath(of: e)
                if contentValues[p]?[fieldID] == nil {
                    storeContent(await provider(fieldID, p) ?? "", fieldID, path: p)
                }
                // Order by the raw value where the mount offers one (a formatted size does not
                // compare), else by what is on screen — in both cases the *words*, never the icon's
                // symbol name, which would order a status column alphabetically by symbol (F-430).
                let sorted = sortContentValue?(fieldID, p)
                values[p] = sorted.map { contentText($0, fieldID) }
                    ?? contentValues[p]?[fieldID] ?? ""
            }
            let numeric = numericContentFields.contains(fieldID)
            visibleEntries.sort { a, b in
                pluginRowLess(a, b, numeric: numeric, ascending: ascending) { values[fullPath(of: $0)] ?? "" }
            }
            reloadData()
            await syncEntriesToSelectionState()
        }
    }

    private func descriptorColumn(_ d: DirectoryModel.SortDescriptor) -> PanelColumn {
        switch d {
        case .name: return .name
        case .ext: return .ext
        case .size: return .size
        case .date: return .date
        }
    }

    // MARK: - Navigation

    func navigate(to path: String) { onNavigate?(path) }

    /// Up one level — the controller decides (parent dir, or leave an archive).
    func navigateUp() { onGoUp?() }

    /// Ctrl+PageDown: descend into the item under the cursor — directories are
    /// entered, and any file is opened AS AN ARCHIVE by content (so a zip with a
    /// non-".zip" extension like .jar/.war/.apk can be browsed). The controller
    /// beeps if the file isn't actually a readable archive.
    func enterUnderCursor() {
        guard cursorRow >= 0, let entry = entry(atCursor: cursorRow) else { return }
        let path = effectivePath(of: entry)
        switch entry.kind {
        case .directory, .symlinkDir, .package, .appBundle:
            navigate(to: path)
        case .file, .symlinkFile:
            onEnterArchive?(path)
        }
    }

    /// The path to act on when opening/entering an entry: a macOS alias (or an
    /// absolute-target symlink) resolves to its target so we list/open the real
    /// item rather than the alias file. Relative/absent targets fall back to the
    /// entry's own path (the OS follows a symlink path directly). (F-036)
    private func effectivePath(of entry: VFSEntry) -> String {
        if let t = entry.linkTarget, (t as NSString).isAbsolutePath { return t }
        return fullPath(of: entry)
    }

    private func handleEnter() {
        guard let snapshot else { return }
        if cursorRow == -1 { onGoUp?(); return }
        guard let entry = entry(atCursor: cursorRow) else { return }
        let path = effectivePath(of: entry)
        switch entry.kind {
        case .directory, .symlinkDir, .package:
            navigate(to: path)
        case .appBundle:
            HistoryService.shared.recordFile(path)
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        case .file, .symlinkFile:
            if isArchiveName?(entry.name) == true {
                onEnterArchive?(path)
            } else if let probe = onProbeThenEnterArchive {
                // A content-detecting packer plugin is enabled: let it look before the file
                // is handed to the system. It opens the file normally if nothing claims it,
                // so this only ever adds an answer, never removes one.
                probe(path)
            } else {
                // Opening with the system is a file open like any other, and this is where Enter and a
                // double-click both arrive (F-402).
                HistoryService.shared.recordFile(path)
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            }
        }
    }

    private func showPropertiesAtCursor() {
        guard let path = currentCursorFullPath() else { return }
        onShowProperties?(path)
    }

    // MARK: - Key handling

    /// Whichever mechanism moves keyboard focus to this panel (a click, Tab key-
    /// view traversal, or an explicit switch), make it the active panel so the
    /// active (blue) highlight always follows the focused side.
    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { onActivate?() }
        return ok
    }

    override func keyDown(with event: NSEvent) {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let code = event.keyCode

        // Quick filter toggle (Ctrl+S).
        if code == 1, mods == [.control] { toggleFilterMode(); return }

        // While filtering, typed characters build the filter; nav keys still work.
        if filterMode {
            switch code {
            case 53: clearFilter(); return                    // Esc clears + exits
            case 36, 76: exitFilterKeepingResults(); return   // Enter freezes the filter
            case 51: backspaceFilter(); return                // Backspace edits filter
            case 123, 124, 125, 126, 115, 116, 119, 121, 49:
                break // arrows/home/end/page/space fall through to normal handling
            default:
                if mods.isSubset(of: .shift), let chars = event.charactersIgnoringModifiers,
                   chars.count == 1, let ch = chars.unicodeScalars.first,
                   ch.value >= 32, ch.value != 127 {
                    appendFilter(chars); return
                }
            }
        }

        // A type-ahead search in progress owns Backspace and Esc — and only those two, and only
        // while it is running. Outside a search both keep doing exactly what they did: Backspace
        // goes to the parent folder, which is precisely the wrong answer to a mistyped letter.
        if typeAheadActive, mods.isSubset(of: .shift) {
            switch code {
            case 51: typeAheadBackspace(); return   // correct the prefix
            case 53: endTypeAhead(); return         // give up on the search
            default: break
            }
        }

        // Numpad selection keys (correct virtual keycodes).
        switch code {
        case 69: // Keypad +
            if mods == [.control] { markAll(); return }
            if mods == [.option] { selectSameExtensionAtCursor(); return }
            if mods.isEmpty { onShowSelectDialog?(false); return }
        case 78: // Keypad -
            if mods == [.control] { unmarkAll(); return }
            if mods.isEmpty { onShowSelectDialog?(true); return }
        case 67: // Keypad *
            if mods.isEmpty { invertMarks(); return }
        case 75: // Keypad /
            if mods.isEmpty { restoreSelection(); return }
        default:
            break
        }

        // Function-key file operations (routed through the command registry so
        // Copy/Move can see both panels).
        switch code {
        case 48: // Tab: plain = switch panel; Ctrl(+Shift) = cycle tabs
            if mods.contains(.control) { onRunCommand?(mods.contains(.shift) ? "cm_PrevTab" : "cm_NextTab") }
            else { onSwitchPanel?() }   // direct/synchronous — avoids the async command hop
            return
        case 99: onRunCommand?("cm_List"); return                                   // F3 view
        case 118: onRunCommand?(mods.contains(.shift) ? "cm_EditNewFile" : "cm_Edit"); return // F4
        case 96: onRunCommand?(mods.contains(.option) ? "cm_PackFiles" : "cm_Copy"); return // F5 / Alt+F5 pack
        case 97: onRunCommand?("cm_RenMov"); return                                 // F6
        case 98: onRunCommand?(mods.contains(.option) ? "cm_SearchFor" : "cm_MkDir"); return // F7 / Alt+F7 find
        case 100: onRunCommand?(mods.contains(.shift) ? "cm_DeleteReal" : "cm_Delete"); return // F8
        case 117: onRunCommand?("cm_Delete"); return                                // Forward-Delete
        default: break
        }

        // Navigation and actions.
        switch code {
        case 126: // Up
            mods.contains(.shift) ? rangeToggle(moveDown: false) : moveCursorUp()
        case 125: // Down (Alt+Down = history dropdown)
            if mods.contains(.option) { onRunCommand?("cm_HistoryList") }
            else if mods.contains(.shift) { rangeToggle(moveDown: true) }
            else { moveCursorDown() }
        case 116: // Page Up (Ctrl+PageUp leaves the current dir/archive)
            mods.contains(.control) ? navigateUp() : moveCursorPageUp()
        case 121: // Page Down (Ctrl+PageDown enters the item under the cursor)
            mods.contains(.control) ? enterUnderCursor() : moveCursorPageDown()
        case 115: // Home
            moveCursorTop()
        case 119: // End
            moveCursorBottom()
        case 123: // Left (Alt+Left = history back)
            mods.contains(.option) ? onRunCommand?("cm_HistoryBack") : navigateUp()
        case 124: // Right (Alt+Right = history forward)
            mods.contains(.option) ? onRunCommand?("cm_HistoryForward") : handleEnter()
        case 49: // Space
            toggleMarkAtCursor()
        case 114: // Help / Insert
            toggleMarkAndAdvance()
        case 51: // Backspace
            navigateUp()
        case 36, 76: // Return / Keypad Enter
            if mods == [.option, .shift] { calculateAllDirectorySizes() }
            else if mods == [.option] { showPropertiesAtCursor() }
            else if mods == [.control] { onAppendToCommandLine?(cursorEntryName() ?? "") }
            else if mods == [.control, .shift] { onAppendToCommandLine?(cursorItemFullPath() ?? "") }
            else { handleEnter() }
        default:
            // Printable keystrokes jump the cursor to the matching name (type-ahead),
            // gated by the configured quick-search mode (F-060).
            if let chars = quickSearchChars(event, mods) {
                if quickSearchMode == "cmdline" { onTypeToCommandLine?(chars) }   // F-005
                else { typeAheadJump(chars) }
            } else {
                super.keyDown(with: event)
            }
        }
    }

    /// The single printable character to type-ahead on, per `quickSearchMode`,
    /// or nil if this event should not trigger quick search.
    private func quickSearchChars(_ event: NSEvent, _ mods: NSEvent.ModifierFlags) -> String? {
        let qualifies: Bool
        switch quickSearchMode {
        case "off": qualifies = false
        case "ctrlalt": qualifies = mods.contains(.control) && mods.contains(.option) && !mods.contains(.command)
        default: qualifies = mods.isSubset(of: .shift)   // "direct" and "cmdline": plain typing
        }
        guard qualifies, let chars = event.charactersIgnoringModifiers, chars.count == 1,
              let ch = chars.unicodeScalars.first, ch.value >= 32, ch.value != 127 else { return nil }
        return chars
    }

    /// Move the cursor to the next entry whose name starts with the typed prefix.
    /// Repeating the same single letter cycles through matches; the buffer resets
    /// after a short pause.
    private func typeAheadJump(_ chars: String) {
        let now = Date()
        if let last = typeAheadLast, now.timeIntervalSince(last) > Self.typeAheadWindow {
            typeAheadBuffer = ""
        }
        typeAheadLast = now

        let start: Int
        if typeAheadBuffer.count == 1, typeAheadBuffer.caseInsensitiveCompare(chars) == .orderedSame {
            start = max(0, cursorRow) + 1        // same letter → cycle to next match
        } else {
            typeAheadBuffer += chars
            start = max(0, cursorRow)            // longer prefix → current may still match
        }
        let names = visibleEntries.map { $0.name }
        if let idx = TypeAheadSearch.match(names: names, query: typeAheadBuffer, from: start) {
            moveCursor(to: idx)
        } else {
            // The prefix stays, so Backspace can take back the character that went too far. Dropping
            // it here — which is what happens when there is nothing to see — left you with a buffer
            // you could neither read nor undo.
            NSSound.beep()
        }
        publishTypeAhead()
    }

    /// Drive the type-ahead from the automation runner: `chars` is typed one character at a time,
    /// with `\\b` for Backspace and `\\e` for Esc.
    ///
    /// Here because the indicator is a label and the cursor is a drawn row — "what is the search
    /// showing" is otherwise a question only somebody looking at the screen can answer, and this
    /// feature is almost entirely about what is on screen.
    func automationTypeAhead(_ sequence: String) {
        var rest = Substring(sequence)
        while let ch = rest.first {
            rest = rest.dropFirst()
            if ch == "\\", let next = rest.first {
                rest = rest.dropFirst()
                if next == "b" { if typeAheadActive { typeAheadBackspace() }; continue }
                if next == "e" { endTypeAhead(); continue }
            }
            typeAheadJump(String(ch))
        }
    }

    /// The search as text: the prefix, which match the cursor is on, how many there are, and the
    /// name under the cursor — everything the indicator claims, checkable from a file.
    var typeAheadForAutomation: String {
        let names = visibleEntries.map { $0.name }
        let all = TypeAheadSearch.matches(names: names, query: typeAheadBuffer)
        let pos = cursorRow >= 0 ? all.firstIndex(of: cursorRow).map { $0 + 1 } : nil
        let cursor = cursorRow >= 0 && cursorRow < names.count ? names[cursorRow] : ""
        return "prefix=\(typeAheadBuffer)\npos=\(pos.map(String.init) ?? "-")\n"
            + "total=\(all.count)\ncursor=\(cursor)\n"
    }

    /// Shorten the prefix by one and jump again; ends the search when nothing is left.
    ///
    /// Backspace otherwise leaves the folder, which is the worst possible answer to a typo: you
    /// mistype one letter of a name and find yourself one directory up.
    private func typeAheadBackspace() {
        typeAheadBuffer.removeLast()
        typeAheadLast = Date()
        guard !typeAheadBuffer.isEmpty else { endTypeAhead(); return }
        let names = visibleEntries.map { $0.name }
        if let idx = TypeAheadSearch.match(names: names, query: typeAheadBuffer,
                                           from: max(0, cursorRow), wrap: true) {
            moveCursor(to: idx)
        }
        publishTypeAhead()
    }

    /// True while a prefix is being typed — the state Backspace and Esc belong to.
    private var typeAheadActive: Bool { !typeAheadBuffer.isEmpty }

    private func endTypeAhead() {
        typeAheadBuffer = ""
        typeAheadLast = nil
        typeAheadTimer?.invalidate()
        typeAheadTimer = nil
        onTypeAheadChanged?(nil, nil, 0)
    }

    /// Tell the panel what to show, and arm the timer that ends the search.
    private func publishTypeAhead() {
        let names = visibleEntries.map { $0.name }
        let all = TypeAheadSearch.matches(names: names, query: typeAheadBuffer)
        let position = cursorRow >= 0 ? all.firstIndex(of: cursorRow).map { $0 + 1 } : nil
        onTypeAheadChanged?(typeAheadBuffer, position, all.count)

        typeAheadTimer?.invalidate()
        typeAheadTimer = Timer.scheduledTimer(withTimeInterval: Self.typeAheadWindow,
                                              repeats: false) { [weak self] _ in
            // Only the *display* ends here. The buffer is cleared by the next keystroke's own
            // window check, which is what has always decided whether typing continues a prefix.
            self?.onTypeAheadChanged?(nil, nil, 0)
        }
    }

    // MARK: - Mouse handling (I05-T06)

    override func mouseDown(with event: NSEvent) {
        onActivate?()
        window?.makeFirstResponder(self)
        let row = self.row(at: convert(event.locationInWindow, from: nil))
        guard row >= 0 else { return }
        let visible = row - 1   // -1 == ".."
        let mods = event.modifierFlags.intersection([.command, .shift])

        if event.clickCount == 2 {
            moveCursor(to: visible)
            handleEnter()
            return
        }
        // Arm a potential drag from a real row (promoted in mouseDragged).
        if visible >= 0 { dragCandidate = (visible, convert(event.locationInWindow, from: nil)) }
        if mods.contains(.shift), visible >= 0 {
            // Range-select from the anchor to the clicked row (adds to the marks).
            selectRange(from: selectionAnchor, to: visible)
            moveCursor(to: visible)
        } else if mods.contains(.command), visible >= 0 {
            // Toggle just the clicked item and make it the new anchor.
            moveCursor(to: visible)
            toggleMarkAtCursor()
            selectionAnchor = visible
        } else {
            moveCursor(to: visible)
            selectionAnchor = max(0, visible)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let cand = dragCandidate else { return }
        let p = convert(event.locationInWindow, from: nil)
        guard abs(p.x - cand.point.x) > 4 || abs(p.y - cand.point.y) > 4 else { return }
        dragCandidate = nil
        beginFileDrag(fromVisible: cand.visible, event: event)
    }

    override func mouseUp(with event: NSEvent) {
        dragCandidate = nil
        super.mouseUp(with: event)
    }

    /// Two-finger horizontal swipe navigates the panel history (F-300), like a
    /// browser: swipe right = Back, swipe left = Forward. Fires only when the
    /// system "Swipe between pages" trackpad gesture is enabled.
    override func swipe(with event: NSEvent) {
        // Apple: positive deltaX = swipe left, negative = swipe right.
        if event.deltaX < 0 {
            onRunCommand?("cm_HistoryBack")
        } else if event.deltaX > 0 {
            onRunCommand?("cm_HistoryForward")
        } else {
            super.swipe(with: event)
        }
    }

    // MARK: - Drag out (to Finder / Mail / the other panel)

    /// Paths dragged from a click on `visible`: the whole marked set if that row is
    /// marked, otherwise just that row. Non-existent paths (e.g. inside an archive)
    /// are dropped so we never offer a bogus file promise.
    private func draggedPaths(fromVisible visible: Int) -> [String] {
        guard visibleEntries.indices.contains(visible) else { return [] }
        let clicked = fullPath(of: visibleEntries[visible])
        let paths: [String]
        if selectedPaths.contains(clicked) {
            paths = visibleEntries.map { fullPath(of: $0) }.filter { selectedPaths.contains($0) }
        } else {
            paths = [clicked]
        }
        return paths.filter { FileManager.default.fileExists(atPath: $0) }
    }

    private func beginFileDrag(fromVisible visible: Int, event: NSEvent) {
        let paths = draggedPaths(fromVisible: visible)
        guard !paths.isEmpty else { return }
        var items: [NSDraggingItem] = []
        for (i, path) in paths.enumerated() {
            let item = NSDraggingItem(pasteboardWriter: URL(fileURLWithPath: path) as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: path)
            let origin = convert(event.locationInWindow, from: nil)
            item.setDraggingFrame(NSRect(x: origin.x - 16, y: origin.y - 16 + CGFloat(i) * 4,
                                         width: 32, height: 32), contents: icon)
            items.append(item)
        }
        beginDraggingSession(with: items, event: event, source: self)
    }

    override func draggingSession(_ session: NSDraggingSession,
                                  sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .move]
    }

    // MARK: - Drop in (from Finder / another app / the other panel)

    /// Command held during the drop → move; otherwise copy (TC-style).
    private func dropIsMove() -> Bool { NSEvent.modifierFlags.contains(.command) }

    private func canReadFileURLs(_ info: NSDraggingInfo) -> Bool {
        info.draggingPasteboard.canReadObject(forClasses: [NSURL.self],
                                              options: [.urlReadingFileURLsOnly: true])
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo,
                   proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard canReadFileURLs(info) else { cancelSpringLoad(); return [] }
        // If the pointer is over a folder row, target that folder ("drop into"); the
        // whole panel otherwise (F-067). Use the pointer's row, not the proposed
        // between-rows row, so we can offer a `.on` drop.
        let point = tableView.convert(info.draggingLocation, from: nil)
        let hoverRow = tableView.row(at: point)
        if let folder = folderRow(hoverRow) {
            tableView.setDropRow(hoverRow, dropOperation: .on)
            armSpringLoad(row: hoverRow, path: folder)
        } else {
            tableView.setDropRow(-1, dropOperation: .above)
            cancelSpringLoad()
        }
        return dropIsMove() ? .move : .copy
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo,
                   row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        cancelSpringLoad()
        guard let urls = info.draggingPasteboard.readObjects(
                forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty else { return false }
        // A `.on` drop onto a folder row copies/moves into that folder (F-067).
        let target = (dropOperation == .on) ? folderRow(row) : nil
        onDropFiles?(urls.map { $0.path }, dropIsMove(), target)
        return true
    }

    #if DEBUG
    /// Mimic a file drop onto table row `r` for automation (F-067): targets that
    /// row's folder if it is one, else the panel as a whole.
    func automationDropOnRow(_ r: Int, paths: [String], move: Bool) {
        onDropFiles?(paths, move, folderRow(r))
    }
    #endif

    /// The absolute path of the folder at table row `r` (r≥1 → visibleEntries[r-1]),
    /// or nil when `r` isn't a real directory row (F-067).
    private func folderRow(_ r: Int) -> String? {
        guard r >= 1, let entry = entry(atCursor: r - 1),
              entry.kind == .directory || entry.kind == .symlinkDir else { return nil }
        return fullPath(of: entry)
    }

    /// (Re)arm the spring-load timer for a hovered folder row; opening it if the
    /// hover persists ~0.7 s (F-067). Re-hovering the same row keeps the timer.
    private func armSpringLoad(row: Int, path: String) {
        guard row != springLoadRow else { return }
        cancelSpringLoad()
        springLoadRow = row
        springLoadTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { [weak self] _ in
            self?.onSpringLoadFolder?(path)
            self?.springLoadRow = -1
        }
    }

    private func cancelSpringLoad() {
        springLoadTimer?.invalidate()
        springLoadTimer = nil
        springLoadRow = -1
    }

    /// Mark every visible entry between two rows (inclusive), clamped to bounds.
    private func selectRange(from: Int, to: Int) {
        guard !visibleEntries.isEmpty else { return }
        let a = min(max(0, from), visibleEntries.count - 1)
        let b = min(max(0, to), visibleEntries.count - 1)
        let paths = (min(a, b)...max(a, b)).map { fullPath(of: visibleEntries[$0]) }
        Task {
            guard let state = selectionState else { return }
            for path in paths { _ = await state.select(path) }
            await refreshSelectionMirror()
            reloadData()
            notifyChanged()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onActivate?()
        window?.makeFirstResponder(self)
        let row = self.row(at: convert(event.locationInWindow, from: nil))
        guard row >= 1 else { return }   // no menu on `..` / empty area
        moveCursor(to: row - 1)
        // Norton-Commander mouse mode (F-059): a plain right-click toggles the
        // mark; the context menu stays reachable with Ctrl held. "left"/Windows
        // mode (the macOS-typical default): right-click shows the context menu.
        if mouseMode == "nc", !event.modifierFlags.contains(.control) {
            toggleMarkAtCursor()
            return
        }
        let menu = buildContextMenu()
        // Merge the native macOS Services submenu into the right-click menu (F-068):
        // point NSApp.servicesMenu at a fresh submenu for the duration of the popup so
        // AppKit populates it from the selection this panel offers (NSServicesMenuRequestor),
        // then restore the app-menu Services afterwards.
        let servicesSubmenu = NSMenu(title: String(localized: "Services"))
        let savedServices = NSApp.servicesMenu
        NSApp.servicesMenu = servicesSubmenu
        let servicesItem = NSMenuItem(title: String(localized: "Services"), action: nil, keyEquivalent: "")
        servicesItem.submenu = servicesSubmenu
        menu.addItem(.separator())
        menu.addItem(servicesItem)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
        NSApp.servicesMenu = savedServices
    }

    // MARK: - Finder-style context menu (F-011 / TODOS #11)

    #if DEBUG
    /// A text tree of the context menu (for automation verification, F-068).
    func automationContextMenuDump() -> String {
        func dump(_ m: NSMenu, _ indent: String) -> String {
            m.items.map { item -> String in
                var line = indent + (item.isSeparatorItem ? "----" : item.title)
                if let sub = item.submenu { line += "\n" + dump(sub, indent + "  ") }
                return line
            }.joined(separator: "\n")
        }
        return dump(buildContextMenu(), "")
    }
    #endif

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        func cmd(_ title: String, _ command: String) {
            let item = NSMenuItem(title: title, action: #selector(ctxRunCommand(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = command
            menu.addItem(item)
        }
        func action(_ title: String, _ selector: Selector) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }

        // Inside a process, the rows are the files it has open (F-391) — real files, so the menu
        // is about the file: look at it, and go to where it actually lives. The process actions
        // below would act on the *parent* row and are deliberately absent here.
        if (window?.windowController as? MainWindowController)?.activePanelProcessMount != nil,
           cursorOpenFilePath() != nil {
            cmd(String(localized: "View (F3)"), "cm_List")
            action(String(localized: "Go to File"), #selector(ctxGoToOpenFile))
            action(String(localized: "Reveal in Finder"), #selector(ctxRevealOpenFile))
            menu.addItem(.separator())
            addCopyValueSubmenu(to: menu)
            action(String(localized: "Select/Deselect"), #selector(ctxToggleMark))
            return menu
        }

        // A process mount (TaskManager) gets a small, process-appropriate menu —
        // the file actions (Open, Quick Look, Reveal, Share, Compress, Tags, …)
        // make no sense for a process.
        if (window?.windowController as? MainWindowController)?.activePanelProcessMount != nil {
            cmd(String(localized: "Process Info (F3)"), "cm_List")
            cmd(String(localized: "Quit Process"), "cm_Delete")
            menu.addItem(.separator())
            action(String(localized: "Show Process Tree"), #selector(ctxShowProcessTree))
            action(String(localized: "Find Process by Port…"), #selector(ctxFindProcessByPort))
            action(String(localized: "Find Processes by File…"), #selector(ctxFindProcessesByFile))
            // Only once there is something to clear — an always-present item that does nothing is
            // how the eject entry used to read.
            if hasFileHandleHighlights {
                action(String(localized: "Clear File Highlight"), #selector(ctxClearFileHandleHighlight))
            }
            menu.addItem(.separator())
            addCopyValueSubmenu(to: menu)
            action(String(localized: "Select/Deselect"), #selector(ctxToggleMark))
            return menu
        }

        action(String(localized: "Open"), #selector(ctxOpen))
        action(String(localized: "Open in Default App"), #selector(ctxOpenDefault))
        if let openWith = buildOpenWithMenu() {
            let item = NSMenuItem(title: String(localized: "Open With"), action: nil, keyEquivalent: "")
            item.submenu = openWith
            menu.addItem(item)
        }
        action(String(localized: "Quick Look"), #selector(ctxQuickLook))
        action(String(localized: "Reveal in Finder"), #selector(ctxRevealInFinder))
        // Only when there is something to eject. The command knows exactly which volume that is and
        // says so by name, which is why the title can: "Eject" alone, on a machine with two sticks
        // plugged in, is a question rather than an action.
        if let volume = (window?.windowController as? MainWindowController)?.ejectableVolumeUnderCursor() {
            cmd(String(localized: "Eject “\(volume.name)”"), "cm_EjectVolume")
        }
        action(String(localized: "Share…"), #selector(ctxShare))
        menu.addItem(.separator())
        cmd(String(localized: "View (F3)"), "cm_List")
        cmd(String(localized: "Edit (F4)"), "cm_Edit")
        cmd(String(localized: "Edit as Hex"), "cm_EditHex")
        menu.addItem(.separator())
        cmd(String(localized: "Copy…"), "cm_Copy")
        cmd(String(localized: "Move/Rename…"), "cm_RenMov")
        cmd(String(localized: "Rename…"), "cm_RenameOnly")
        cmd(String(localized: "Delete"), "cm_Delete")
        menu.addItem(.separator())
        cmd(String(localized: "Compress…"), "cm_PackFiles")
        cmd(String(localized: "Copy Name"), "cm_CopyNamesToClip")
        cmd(String(localized: "Get Info"), "cm_Properties")
        if let tags = buildTagsMenu() {
            let item = NSMenuItem(title: String(localized: "Tags"), action: nil, keyEquivalent: "")
            item.submenu = tags
            menu.addItem(item)
        }
        menu.addItem(.separator())
        addCopyValueSubmenu(to: menu)
        action(String(localized: "Select/Deselect"), #selector(ctxToggleMark))
        appendContributions(to: menu, surface: "panel.item")
        return menu
    }

    /// Add a "Copy Value ▸" submenu (per-column copy for the cursor row) — lets the
    /// user copy any column's text, not just the name.
    private func addCopyValueSubmenu(to menu: NSMenu) {
        guard let copyMenu = buildCopyValueMenu() else { return }
        let item = NSMenuItem(title: String(localized: "Copy Value"), action: nil, keyEquivalent: "")
        item.submenu = copyMenu
        menu.addItem(item)
    }

    @objc private func ctxShowProcessTree() {
        (window?.windowController as? MainWindowController)?
            .showProcessTree(cursorEntryName: cursorEntryName())
    }

    @objc private func ctxFindProcessByPort() {
        (window?.windowController as? MainWindowController)?.findProcessByPort()
    }

    /// The real file behind the cursor row when the panel is inside a process (F-391), else nil.
    ///
    /// Such a row's *name* is the file's path with ":" for "/" — the host's own convention for a
    /// name containing a slash, which is why the row already reads as a path on screen. Decoding it
    /// back is what makes "go to it" possible at all: a plugin path leads nowhere on disk.
    func cursorOpenFilePath() -> String? {
        guard let name = cursorEntryName(), name.hasPrefix(":") else { return nil }
        let real = PathUtils.displayName(fromPOSIX: name)
        return FileManager.default.fileExists(atPath: real) ? real : nil
    }

    @objc private func ctxFindProcessesByFile() {
        (window?.windowController as? MainWindowController)?.findProcessesByFile()
    }

    @objc private func ctxGoToOpenFile() {
        guard let real = cursorOpenFilePath() else { NSSound.beep(); return }
        (window?.windowController as? MainWindowController)?.goToOpenFile(real)
    }

    @objc private func ctxRevealOpenFile() {
        guard let real = cursorOpenFilePath() else { NSSound.beep(); return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: real)])
    }

    @objc private func ctxClearFileHandleHighlight() { clearFileHandleHighlights() }

    /// Append enabled plugins' context-menu contributions for `surface`, filtered
    /// by each item's `when` against the clicked item's context. Items route
    /// through the same command dispatch as built-in `cm_*` context items.
    private func appendContributions(to menu: NSMenu, surface: String) {
        let ctx = contributionContext()
        let visible: [(command: String, title: String, submenu: String?)] = MainActor.assumeIsolated {
            ContributionRegistry.shared.contextItems(surface: surface)
                .filter { WhenExpression.evaluate($0.contribution.when, context: ctx) }
                .map { ($0.contribution.command, $0.title, $0.submenu) }
        }
        guard !visible.isEmpty else { return }
        menu.addItem(.separator())
        // Items sharing a `submenu` are grouped under one nested menu (created on
        // first use, in encounter order); submenu-less items appear directly.
        var submenus: [String: NSMenu] = [:]
        for v in visible {
            let item = NSMenuItem(title: v.title, action: #selector(ctxRunCommand(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = v.command
            if let name = v.submenu {
                let sub = submenus[name] ?? {
                    let m = NSMenu()
                    let parent = NSMenuItem(title: name, action: nil, keyEquivalent: "")
                    parent.submenu = m
                    menu.addItem(parent)
                    submenus[name] = m
                    return m
                }()
                sub.addItem(item)
            } else {
                menu.addItem(item)
            }
        }
    }

    /// Context snapshot for evaluating context-menu contributions' `when` — keyed on
    /// the item under the cursor (right-click moved the cursor to it).
    private func contributionContext() -> ContributionContext {
        var c = ContributionContext()
        let path = cursorItemFullPath()
        c.set("cursorPath", path)
        c.set("cursorName", path.map { ($0 as NSString).lastPathComponent })
        c.set("cursorExt", path.map { ($0 as NSString).pathExtension.lowercased() })
        c.set("cursorIsApp", path?.lowercased().hasSuffix(".app") ?? false)
        c.set("hasSelection", path != nil)
        return c
    }

    /// The seven standard Finder color tags; checked when applied to the cursor file.
    private static let standardTags = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Gray"]

    private func buildTagsMenu() -> NSMenu? {
        guard let path = cursorItemFullPath(), FileManager.default.fileExists(atPath: path) else { return nil }
        let url = URL(fileURLWithPath: path)
        // By colour index, for the reason spelled out in `ctxToggleTag`: the stored names are localized.
        let current = Set(FinderTagColor.tagColorIndices(forPath: url.path))
        let submenu = NSMenu()
        for tag in Self.standardTags {
            let item = NSMenuItem(title: tag, action: #selector(ctxToggleTag(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = tag
            item.state = FinderTagColor.colorIndex(forName: tag).map { current.contains($0) } == true ? .on : .off
            submenu.addItem(item)
        }
        return submenu
    }

    @objc private func ctxToggleTag(_ sender: NSMenuItem) {
        guard let tag = sender.representedObject as? String, let path = cursorItemFullPath(),
              let colorIndex = FinderTagColor.colorIndex(forName: tag) else { return }
        // Matched and written by *colour index*, not by name. The names of the standard labels are
        // localized — a file tagged red on a German system carries "Rot\n6" — so a name comparison saw
        // no tag, added a second one called "Red", and stored it through an API that drops the colour
        // (index 0). The result was two tags on the file, neither of them the red label (F-291).
        var tags = FinderTagColor.rawTags(forPath: path)
        if let existing = tags.firstIndex(where: { entry in
            entry.components(separatedBy: "\n").count > 1
                ? Int(entry.components(separatedBy: "\n")[1]) == colorIndex
                : FinderTagColor.colorIndex(forName: entry) == colorIndex
        }) {
            tags.remove(at: existing)
        } else {
            tags.append("\(tag)\n\(colorIndex)")
        }
        FinderTagColor.writeRawTags(tags, toPath: path)
        needsDisplay = true      // the colour dot is drawn from the file, so redraw it
    }

    @objc private func ctxRunCommand(_ sender: NSMenuItem) {
        if let command = sender.representedObject as? String { onRunCommand?(command) }
    }
    @objc private func ctxOpen() { handleEnter() }
    @objc private func ctxOpenDefault() {
        if let path = cursorItemFullPath() { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
    }
    @objc private func ctxRevealInFinder() {
        if let path = cursorItemFullPath() {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        }
    }
    @objc private func ctxToggleMark() { toggleMarkAtCursor() }
    @objc private func ctxQuickLook() { onRunCommand?("cm_QuickLook") }

    /// "Open With" submenu: the apps macOS can open the cursor file with (name +
    /// icon), or nil for the ".." row / non-local entries.
    private func buildOpenWithMenu() -> NSMenu? {
        guard let path = cursorItemFullPath(), FileManager.default.fileExists(atPath: path) else { return nil }
        let url = URL(fileURLWithPath: path)
        let apps = NSWorkspace.shared.urlsForApplications(toOpen: url)
        guard !apps.isEmpty else { return nil }
        let submenu = NSMenu()
        for app in apps {
            let name = FileManager.default.displayName(atPath: app.path)
            let item = NSMenuItem(title: name, action: #selector(ctxOpenWith(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = app
            let icon = NSWorkspace.shared.icon(forFile: app.path)
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
            submenu.addItem(item)
        }
        // Finder-style "Other…" to pick any application (F-068).
        submenu.addItem(.separator())
        let other = NSMenuItem(title: String(localized: "Other…"), action: #selector(ctxOpenWithOther), keyEquivalent: "")
        other.target = self
        submenu.addItem(other)
        return submenu
    }

    @objc private func ctxOpenWith(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? URL, let path = cursorItemFullPath() else { return }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([URL(fileURLWithPath: path)], withApplicationAt: app, configuration: config)
    }

    /// "Open With ▸ Other…": choose an arbitrary application to open the file (F-068).
    @objc private func ctxOpenWithOther() {
        guard let path = cursorItemFullPath() else { return }
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose Application")
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let app = panel.url else { return }
        NSWorkspace.shared.open([URL(fileURLWithPath: path)], withApplicationAt: app,
                                configuration: NSWorkspace.OpenConfiguration())
    }

    /// macOS Share sheet for the selected (or cursor) LOCAL files.
    @objc private func ctxShare() {
        var paths = selectedFilePaths()
        if paths.isEmpty, let cursor = cursorItemFullPath() { paths = [cursor] }
        let urls = paths.filter { FileManager.default.fileExists(atPath: $0) }.map { URL(fileURLWithPath: $0) }
        guard !urls.isEmpty else { NSSound.beep(); return }
        let picker = NSSharingServicePicker(items: urls)
        let rowRect = rect(ofRow: cursorRow + 1)
        picker.show(relativeTo: rowRect, of: self, preferredEdge: .maxY)
    }
}

// MARK: - Services menu integration (F-293)

extension PanelListView: NSServicesMenuRequestor {
    /// File URLs for the current selection (marked entries, else the cursor item),
    /// used to feed the standard macOS Services menu.
    fileprivate func serviceFileURLs() -> [URL] {
        var paths = selectedFilePaths()
        if paths.isEmpty, let cursor = cursorItemFullPath() { paths = [cursor] }
        return paths.filter { FileManager.default.fileExists(atPath: $0) }
                    .map { URL(fileURLWithPath: $0) }
    }

    override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?,
                                 returnType: NSPasteboard.PasteboardType?) -> Any? {
        if sendType == .fileURL, returnType == nil, !serviceFileURLs().isEmpty {
            return self
        }
        return super.validRequestor(forSendType: sendType, returnType: returnType)
    }

    /// `nonisolated` + `assumeIsolated`: `NSServicesMenuRequestor` carries no `@MainActor` in the
    /// SDK, so a main-actor witness "crosses into main actor-isolated code" — a warning today, an
    /// error in the Swift 6 language mode. AppKit only ever sends these from the main thread, and
    /// asserting that beats a nonisolated witness that reads panel state from wherever it is
    /// called: the same shape that crashed the hidden-files toggle (F-436).
    nonisolated func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        MainActor.assumeIsolated {
            let urls = serviceFileURLs()
            guard !urls.isEmpty else { return false }
            pboard.clearContents()
            return pboard.writeObjects(urls.map { $0 as NSURL })
        }
    }

    /// Nothing isolated to reach, so no assertion is needed — the panel accepts no incoming
    /// service data.
    nonisolated func readSelection(from pboard: NSPasteboard) -> Bool { false }
}
