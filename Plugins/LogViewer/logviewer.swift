// logviewer.swift — the Log Viewer as an external contribution plugin.
//
// PcRunCommand opens a specialised log-file window (level-classified, colour-coded,
// filterable, live-tailing) for the cursor file (resolved to a local path by the
// host because the command declares needsLocalPath). The window contributes its
// own Edit + Log menu-bar menus while it is key via the host's registerToolWindow
// service, so there is no functional loss versus the former built-in viewer. The
// plugin owns its windows (kept in a global list until closed). Self-contained
// AppKit; talks to the host only through the PcHostServices C-ABI.
//
// Performance model: the file is memory-mapped and a line-offset index is built on
// a background queue (see LogStore), so opening a multi-GB log is instant and only
// the physical lines currently on screen are ever decoded to String. The table is
// one row per physical line, virtualized by NSTableView. Filtering builds a
// `filteredRows` projection in main-thread chunks (UI stays responsive); with no
// active filter the projection is nil (identity) at zero cost.

import AppKit

// MARK: - Entry points

private var openWindows: [LogViewerWindow] = []

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?, _ services: UnsafePointer<PcHostServices>?) {
    guard let services else { return }
    let svc = services.pointee
    guard let path = hostLocalCursorPath(svc) ?? hostCursorPath(svc), !path.isEmpty else {
        svc.presentInfo?(svc.host, L("Log Viewer"), L("Select a file first."))
        return
    }
    let win = LogViewerWindow(path: path)
    openWindows.append(win)
    win.onClose = { [weak win] in openWindows.removeAll { $0 === win } }
    if let reg = svc.registerToolWindow, let window = win.window {
        let edit = win.makeEditMenu()
        let content = win.makeContentMenu()
        win.retainMenus(edit, content)
        reg(svc.host, Unmanaged.passUnretained(window).toOpaque(),
            Unmanaged.passUnretained(edit).toOpaque(),
            Unmanaged.passUnretained(content).toOpaque(), L("Log"))
    }
    win.show()
}

@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?, _ container: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    // The only view this plugin contributes is its pane in the host Settings dialog.
    if let container, String(cString: container) == "settings" {
        return Unmanaged.passRetained(LogSettingsView()).toOpaque()
    }
    return nil
}

@_cdecl("PcCloseView")
public func PcCloseView(_ view: UnsafeMutableRawPointer?) {
    guard let view else { return }
    Unmanaged<NSView>.fromOpaque(view).release()
}

private func hostLocalCursorPath(_ svc: PcHostServices) -> String? {
    guard let fn = svc.localCursorPath else { return nil }
    var buf = [CChar](repeating: 0, count: 4096)
    return fn(svc.host, &buf, 4096) != 0 ? String(cString: buf) : nil
}
private func hostCursorPath(_ svc: PcHostServices) -> String? {
    guard let fn = svc.cursorPath else { return nil }
    var buf = [CChar](repeating: 0, count: 4096)
    return fn(svc.host, &buf, 4096) != 0 ? String(cString: buf) : nil
}

// MARK: - Window

final class LogViewerWindow: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    var onClose: (() -> Void)?

    private let path: String
    private let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private var registeredMenus: [NSMenu] = []

    private var store: LogStore?
    /// Row → physical line index projection. nil means identity (row i == line i),
    /// which is the zero-cost common case (no active filter).
    private var filteredRows: [Int]?
    private var filter = LogFilter()
    /// Bumped on each filter run so an in-flight chunked pass can detect it is stale.
    private var filterGeneration = 0
    private var buildComplete = false

    private struct ParsedRow { let raw: String; let message: String; let level: LogLevel; let timestamp: String? }

    /// Cache of the last decoded/classified line so viewFor doesn't re-classify the
    /// same physical line once per column.
    private var cacheLine = -1
    private var cacheRow = ParsedRow(raw: "", message: "", level: .unknown, timestamp: nil)

    // Format engine: built-in + custom formats, auto-detected or forced via the picker.
    private let engine = FormatEngine()
    private var formats: [LogFormat] = LogConfigStore.shared.config.allFormats
    private var detectedFormat: LogFormat?
    private var forcedFormatId: String?     // nil == Auto
    private var didDetect = false
    private var resolvedFormat: LogFormat? {
        if let id = forcedFormatId { return formats.first { $0.id == id } }
        return detectedFormat
    }

    private var pollTimer: Timer?
    private var config = LogConfigStore.shared.config

    private let tableView = NSTableView()
    private var lineColumn: NSTableColumn?
    private let formatPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    private let searchField = NSSearchField()
    private let regexToggle = NSButton(checkboxWithTitle: L("Regex"), target: nil, action: nil)
    private let liveToggle = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private var levelChecks: [(level: LogLevel, button: NSButton)] = []
    private let statusLabel = NSTextField(labelWithString: "")

    // Find + Mark (non-destructive: highlights matching rows without filtering).
    private let findBar = NSStackView()
    private let findField = NSSearchField()
    private let findCountLabel = NSTextField(labelWithString: "")
    private var findMatches: Set<Int> = []      // matched physical line indices
    private var findMatchList: [Int] = []        // sorted, for next/prev navigation
    private var findGeneration = 0

    // Detail pane: word-wrapped, selectable full text of the current selection.
    private let detailScroll = NSScrollView()
    private let detailText = NSTextView()

    // Incremental filtering during tail: highest line already projected into filteredRows.
    private var filteredUpTo = 0
    /// Start line of the last (possibly still-growing) entry in the current filter
    /// projection — re-evaluated on each tail tick since new lines may extend it.
    private var filterOpenStart = 0

    // Memoized owning-entry classification (continuation rows share their entry's
    // start line, so we don't re-classify the entry head for every visible row).
    private var cacheEntryOwner = -1
    private var cacheEntryLevel: LogLevel = .unknown
    private var cacheEntryTimestamp: String?

    init(path: String) {
        self.path = path
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 640),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(format: L("%@ — Log"), (path as NSString).lastPathComponent)
        super.init(window: window)
        window.delegate = self
        buildUI()
        NotificationCenter.default.addObserver(self, selector: #selector(configChanged),
                                               name: .logViewerConfigChanged, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func configChanged() {
        config = LogConfigStore.shared.config
        lineColumn?.isHidden = !config.showLineNumbers
        for (level, button) in levelChecks { button.contentTintColor = LogStyle.color(level, config: config) }
        // Custom formats may have changed: rebuild the picker and re-detect.
        formats = config.allFormats
        detectedFormat = nil
        didDetect = false
        populateFormatPicker()
        maybeDetect()
        detailScroll.isHidden = !config.wordWrap
        updateDetail()
        cacheLine = -1; cacheEntryOwner = -1
        if filteredRows == nil { tableView.reloadData() } else { applyFilter() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        loadInitial()
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func retainMenus(_ menus: NSMenu...) { registeredMenus.append(contentsOf: menus) }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let toolbar = NSStackView()
        toolbar.orientation = .horizontal; toolbar.spacing = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        for level in LogStyle.ordered {
            let button = NSButton(checkboxWithTitle: LogStyle.displayName(level),
                                  target: self, action: #selector(filterChanged))
            button.state = .on
            button.contentTintColor = LogStyle.color(level, config: config)
            toolbar.addArrangedSubview(button)
            levelChecks.append((level, button))
        }

        searchField.placeholderString = L("Filter…")
        searchField.target = self
        searchField.action = #selector(filterChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.widthAnchor.constraint(equalToConstant: 220).isActive = true
        regexToggle.target = self
        regexToggle.action = #selector(filterChanged)
        liveToggle.title = L("Live (auto-scroll)")
        liveToggle.target = self
        liveToggle.action = #selector(liveChanged)
        toolbar.addArrangedSubview(searchField)
        toolbar.addArrangedSubview(regexToggle)
        toolbar.addArrangedSubview(liveToggle)

        formatPicker.target = self
        formatPicker.action = #selector(formatChanged)
        toolbar.addArrangedSubview(NSTextField(labelWithString: L("Format:")))
        toolbar.addArrangedSubview(formatPicker)
        populateFormatPicker()
        content.addSubview(toolbar)

        for (id, title, width) in [("line", L("#"), CGFloat(60)), ("time", L("Time"), 180),
                                    ("level", L("Level"), 70), ("message", L("Message"), 680)] {
            let col = NSTableColumn(identifier: .init(id)); col.title = title; col.width = width
            tableView.addTableColumn(col)
            if id == "line" { lineColumn = col; col.isHidden = !config.showLineNumbers }
        }
        tableView.rowHeight = 15
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsColumnResizing = true
        tableView.allowsMultipleSelection = true
        tableView.menu = makeContextMenu()

        buildFindBar()

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        scroll.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        // Detail pane: read-only, selectable, word-wrapping text of the selection.
        detailText.isEditable = false
        detailText.isSelectable = true
        detailText.font = font
        detailText.textContainerInset = NSSize(width: 4, height: 4)
        detailText.isVerticallyResizable = true
        detailText.isHorizontallyResizable = false
        detailText.autoresizingMask = [.width]
        detailText.textContainer?.widthTracksTextView = true
        detailScroll.documentView = detailText
        detailScroll.hasVerticalScroller = true
        detailScroll.translatesAutoresizingMaskIntoConstraints = false
        detailScroll.heightAnchor.constraint(equalToConstant: 72).isActive = true
        detailScroll.isHidden = !config.wordWrap

        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        let statusRow = NSStackView(views: [statusLabel])
        statusRow.orientation = .horizontal
        statusRow.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 4, right: 10)

        let vstack = NSStackView(views: [toolbar, findBar, scroll, detailScroll, statusRow])
        vstack.orientation = .vertical
        vstack.alignment = .leading
        vstack.spacing = 0
        vstack.distribution = .fill
        vstack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(vstack)
        NSLayoutConstraint.activate([
            vstack.topAnchor.constraint(equalTo: content.topAnchor),
            vstack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            vstack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            vstack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        for v in [toolbar, findBar, scroll, detailScroll, statusRow] {
            v.leadingAnchor.constraint(equalTo: vstack.leadingAnchor).isActive = true
            v.trailingAnchor.constraint(equalTo: vstack.trailingAnchor).isActive = true
        }
    }

    private func buildFindBar() {
        findBar.orientation = .horizontal
        findBar.spacing = 8
        findBar.edgeInsets = NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        findBar.translatesAutoresizingMaskIntoConstraints = false
        findField.placeholderString = L("Find (mark & jump)…")
        findField.target = self
        findField.action = #selector(findChanged)
        findField.translatesAutoresizingMaskIntoConstraints = false
        findField.widthAnchor.constraint(equalToConstant: 260).isActive = true
        let prev = NSButton(title: "◀", target: self, action: #selector(findPrevious))
        let next = NSButton(title: "▶", target: self, action: #selector(findNext))
        prev.bezelStyle = .rounded; next.bezelStyle = .rounded
        let done = NSButton(title: L("Done"), target: self, action: #selector(toggleFindBar))
        done.bezelStyle = .rounded
        findCountLabel.font = NSFont.systemFont(ofSize: 11)
        findCountLabel.textColor = .secondaryLabelColor
        findBar.addArrangedSubview(NSTextField(labelWithString: L("Find:")))
        findBar.addArrangedSubview(findField)
        findBar.addArrangedSubview(prev)
        findBar.addArrangedSubview(next)
        findBar.addArrangedSubview(findCountLabel)
        findBar.addArrangedSubview(done)
        findBar.isHidden = true
    }

    // MARK: - Formats

    private func populateFormatPicker() {
        let selected = forcedFormatId
        formatPicker.removeAllItems()
        formatPicker.addItem(withTitle: autoItemTitle())
        formatPicker.menu?.items.first?.representedObject = nil as String?
        for f in formats {
            let item = NSMenuItem(title: f.name, action: nil, keyEquivalent: "")
            item.representedObject = f.id
            formatPicker.menu?.addItem(item)
        }
        // Restore selection (Auto, or the same forced format if it still exists).
        if let id = selected, let idx = formats.firstIndex(where: { $0.id == id }) {
            formatPicker.selectItem(at: idx + 1)
        } else {
            forcedFormatId = nil
            formatPicker.selectItem(at: 0)
        }
    }

    private func autoItemTitle() -> String {
        if let d = detectedFormat { return String(format: L("Auto (%@)"), d.name) }
        return L("Auto")
    }

    @objc private func formatChanged() {
        let idx = formatPicker.indexOfSelectedItem
        forcedFormatId = idx <= 0 ? nil : (formats.indices.contains(idx - 1) ? formats[idx - 1].id : nil)
        cacheLine = -1; cacheEntryOwner = -1
        if filteredRows == nil { tableView.reloadData() } else { applyFilter() }
    }

    /// Auto-detect the format once enough lines are indexed (only while in Auto mode).
    private func maybeDetect() {
        guard !didDetect, let store, store.count >= 20 || buildComplete else { return }
        didDetect = true
        let sampleCount = min(store.count, 200)
        let sample = (0..<sampleCount).map { store.line($0) }
        detectedFormat = engine.detect(sample: sample, formats: formats)
        formatPicker.item(at: 0)?.title = autoItemTitle()
        if forcedFormatId == nil, detectedFormat != nil {
            cacheLine = -1; cacheEntryOwner = -1
            if filteredRows == nil { tableView.reloadData() } else { applyFilter() }
        }
    }

    private func classify(_ text: String) -> ParsedRow {
        if let f = resolvedFormat, let m = engine.match(text, format: f) {
            return ParsedRow(raw: text, message: m.message, level: m.level, timestamp: m.timestamp)
        }
        let p = LogLineParser.parse(text)
        return ParsedRow(raw: text, message: text, level: p.level, timestamp: p.timestamp)
    }

    // MARK: - Loading & live tail

    private func loadInitial() {
        guard let store = LogStore(path: path) else {
            statusLabel.stringValue = L("Could not open file.")
            return
        }
        self.store = store
        store.onProgress = { [weak self] _ in self?.indexProgressed() }
        store.buildIndex()
        updateStatus()
    }

    /// Called on the main thread as the background index grows and when it finishes.
    private func indexProgressed() {
        guard let store else { return }
        // Detect completion: whole file scanned.
        if !buildComplete, store.byteSize == store.indexedBytes {
            buildComplete = true
        }
        maybeDetect()
        if filteredRows == nil {
            tableView.reloadData()
        } else {
            // A filter is active — re-project over the enlarged index.
            applyFilter()
        }
        updateStatus()
    }

    @objc private func liveChanged() {
        if liveToggle.state == .on {
            pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.pollForNewData()
            }
        } else {
            pollTimer?.invalidate(); pollTimer = nil
        }
    }

    private func pollForNewData() {
        guard let store, buildComplete else { return }
        guard store.extendForGrowth() else { return }
        if filteredRows == nil {
            tableView.reloadData()
        } else {
            extendFilterForTail()   // classify only the appended lines, not a full rescan
        }
        updateStatus()
        if liveToggle.state == .on {
            let rows = numberOfRows(in: tableView)
            if rows > 0 { tableView.scrollRowToVisible(rows - 1) }
        }
    }

    /// Incrementally project newly-indexed lines into an active filter. New lines
    /// may extend the last (open) entry, so drop that entry's rows and re-group
    /// from its start — bounded to that entry + the appended lines, not a full rescan.
    private func extendFilterForTail() {
        guard let store, var rows = filteredRows, !filter.isEmpty else { return }
        let total = store.count
        guard total > filteredUpTo else { return }
        if let cut = rows.firstIndex(where: { $0 >= filterOpenStart }) { rows.removeSubrange(cut...) }

        let needleEmpty = filter.text.trimmingCharacters(in: .whitespaces).isEmpty
        var pending: [Int] = []
        var pendingLevel: LogLevel = .unknown
        var pendingHit = false
        var lastStart = filterOpenStart
        func flush() {
            guard !pending.isEmpty else { return }
            let levelOK = filter.levels.isEmpty || filter.levels.contains(pendingLevel)
            if levelOK, needleEmpty || pendingHit { rows.append(contentsOf: pending) }
            pending.removeAll(keepingCapacity: true); pendingHit = false
        }
        for i in filterOpenStart..<total {
            let raw = store.line(i)
            if pending.isEmpty || LogLineParser.startsWithTimestamp(raw) {
                flush(); pendingLevel = classify(raw).level; lastStart = i
            }
            pending.append(i)
            if !needleEmpty, !pendingHit, filter.matchesText(raw) { pendingHit = true }
        }
        flush()
        filteredRows = rows
        filterOpenStart = lastStart
        filteredUpTo = total
        tableView.reloadData()
    }

    // MARK: - Filter (chunked, main-thread, race-free)

    @objc private func filterChanged() {
        let active = Set(levelChecks.filter { $0.button.state == .on }.map(\.level))
        let levels = active.count == levelChecks.count ? [] : active
        filter = LogFilter(levels: levels, text: searchField.stringValue, isRegex: regexToggle.state == .on)
        applyFilter()
    }

    /// Rebuild `filteredRows`. If the filter is empty, restore the identity
    /// projection (nil) immediately. Otherwise scan the indexed lines in chunks on
    /// the main run loop so the UI stays responsive on huge files.
    private func applyFilter() {
        guard let store else { return }
        filterGeneration += 1
        let gen = filterGeneration
        if filter.isEmpty {
            filteredRows = nil
            tableView.reloadData()
            updateStatus()
            return
        }
        // Entry-based: an entry matches when its level passes AND any of its lines
        // match the text; a matching entry contributes ALL its physical lines, so
        // multi-line entries (stack traces) stay intact under a filter.
        var result: [Int] = []
        let total = store.count
        let needleEmpty = filter.text.trimmingCharacters(in: .whitespaces).isEmpty
        var pending: [Int] = []
        var pendingLevel: LogLevel = .unknown
        var pendingHit = false
        var lastStart = 0
        func flush() {
            guard !pending.isEmpty else { return }
            let levelOK = filter.levels.isEmpty || filter.levels.contains(pendingLevel)
            if levelOK, needleEmpty || pendingHit { result.append(contentsOf: pending) }
            pending.removeAll(keepingCapacity: true); pendingHit = false
        }
        func processChunk(_ from: Int) {
            guard gen == filterGeneration else { return }
            let upper = min(from + 20_000, total)
            for i in from..<upper {
                let raw = store.line(i)
                if pending.isEmpty || LogLineParser.startsWithTimestamp(raw) {
                    flush(); pendingLevel = classify(raw).level; lastStart = i
                }
                pending.append(i)
                if !needleEmpty, !pendingHit, filter.matchesText(raw) { pendingHit = true }
            }
            if upper < total {
                statusLabel.stringValue = String(format: L("Filtering… %lld%%"), Int(Double(upper) / Double(total) * 100))
                DispatchQueue.main.async { processChunk(upper) }
            } else {
                flush()
                filteredRows = result
                filteredUpTo = total
                filterOpenStart = lastStart
                tableView.reloadData()
                updateStatus()
            }
        }
        processChunk(0)
    }

    private func updateStatus() {
        guard let store else { return }
        let shown = filteredRows?.count ?? store.count
        statusLabel.stringValue = String(format: L("%lld of %lld lines · %@"),
                                         shown, store.count, Self.humanSize(store.byteSize))
    }

    private static func humanSize(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes); var unit = 0
        while value >= 1024, unit < units.count - 1 { value /= 1024; unit += 1 }
        return unit == 0 ? "\(bytes) B" : String(format: "%.1f %@", value, units[unit])
    }

    // MARK: - Row ⇄ line mapping

    private func lineIndex(forRow row: Int) -> Int? {
        if let f = filteredRows { return f.indices.contains(row) ? f[row] : nil }
        guard let store, row >= 0, row < store.count else { return nil }
        return row
    }

    /// Decode + classify a physical line, memoised for the current viewFor pass.
    private func parsed(forLine line: Int) -> ParsedRow {
        if line == cacheLine { return cacheRow }
        let row = classify(store?.line(line) ?? "")
        cacheLine = line; cacheRow = row
        return row
    }

    // MARK: - Multi-line entry grouping

    /// Whether a physical line begins a new log entry (starts with a timestamp) as
    /// opposed to continuing the previous one (stack traces, wrapped messages).
    private func isEntryStart(_ line: Int) -> Bool {
        guard let store, line > 0 else { return true }
        return LogLineParser.startsWithTimestamp(store.linePrefix(line, maxBytes: 40))
    }

    /// Nearest entry-start line at or before `line` (capped backward scan so a
    /// pathological run of continuation lines can't stall rendering).
    private func entryStart(forLine line: Int) -> Int {
        guard let store, line > 0 else { return max(0, line) }
        var i = line
        let floorLine = max(0, line - 5000)
        while i > floorLine {
            if LogLineParser.startsWithTimestamp(store.linePrefix(i, maxBytes: 40)) { return i }
            i -= 1
        }
        return i
    }

    /// Owning-entry context for a physical line: is it the entry head, and the
    /// entry's level/timestamp (so continuation rows inherit colour and grouping).
    private func entryContext(forLine line: Int) -> (isPrimary: Bool, level: LogLevel, timestamp: String?) {
        let owner = entryStart(forLine: line)
        if owner != cacheEntryOwner {
            let p = classify(store?.line(owner) ?? "")
            cacheEntryOwner = owner; cacheEntryLevel = p.level; cacheEntryTimestamp = p.timestamp
        }
        return (owner == line, cacheEntryLevel, cacheEntryTimestamp)
    }

    /// Physical line range [start, end) of the entry containing `line`.
    private func entryLineRange(containing line: Int) -> Range<Int> {
        guard let store else { return line..<(line + 1) }
        let start = entryStart(forLine: line)
        var end = start + 1
        let cap = min(store.count, start + 5000)
        while end < cap, !isEntryStart(end) { end += 1 }
        return start..<max(end, start + 1)
    }

    // MARK: - NSTableView

    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredRows?.count ?? store?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let colID = tableColumn?.identifier.rawValue, let line = lineIndex(forRow: row) else { return nil }
        let ctx = entryContext(forLine: line)
        let id = NSUserInterfaceItemIdentifier("cell")
        let field = (tableView.makeView(withIdentifier: id, owner: self) as? NSTextField) ?? {
            let f = NSTextField(labelWithString: ""); f.identifier = id; f.font = font
            f.lineBreakMode = .byTruncatingTail; return f
        }()
        field.alignment = .left
        switch colID {
        case "line":
            field.stringValue = "\(line + 1)"
            field.textColor = .tertiaryLabelColor
            field.alignment = .right
        case "time":
            // Timestamp/level only on the entry head; continuation rows stay blank.
            field.stringValue = ctx.isPrimary ? (ctx.timestamp ?? "") : ""
            field.textColor = .secondaryLabelColor
        case "level":
            field.stringValue = (ctx.isPrimary && ctx.level != .unknown) ? LogStyle.displayName(ctx.level).uppercased() : ""
            field.textColor = LogStyle.color(ctx.level, config: config)
        default:
            // Head shows the format-stripped message; continuations show their raw
            // text (e.g. a stack frame). Both inherit the entry's level colour.
            field.stringValue = ctx.isPrimary ? parsed(forLine: line).message : (store?.line(line) ?? "")
            field.textColor = LogStyle.color(ctx.level, config: config)
        }
        return field
    }

    func windowWillClose(_ notification: Notification) {
        pollTimer?.invalidate(); pollTimer = nil
        onClose?()
    }

    // MARK: - Go to line

    @objc private func goToLine() {
        guard let store else { return }
        let alert = NSAlert()
        alert.messageText = L("Go to Line")
        alert.informativeText = String(format: L("Enter a line number (1–%lld):"), store.count)
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: L("Go"))
        alert.addButton(withTitle: L("Cancel"))
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn, let n = Int(field.stringValue.trimmingCharacters(in: .whitespaces)), n >= 1 {
            scrollToLine(n - 1)
        }
    }

    /// Scroll to the row showing physical line `lineIndex` (nearest visible row when
    /// a filter is hiding it).
    private func scrollToLine(_ lineIndex: Int) {
        let row: Int
        if let f = filteredRows {
            // First row whose line index is >= the target (binary search; f is ascending).
            var lo = 0, hi = f.count
            while lo < hi { let mid = (lo + hi) / 2; if f[mid] < lineIndex { lo = mid + 1 } else { hi = mid } }
            row = lo
        } else {
            row = lineIndex
        }
        let rows = numberOfRows(in: tableView)
        guard rows > 0 else { return }
        let target = min(max(row, 0), rows - 1)
        tableView.scrollRowToVisible(target)
        tableView.selectRowIndexes([target], byExtendingSelection: false)
    }

    // MARK: - Find + Mark (non-destructive highlight & jump)

    @objc private func toggleFindBar() {
        findBar.isHidden.toggle()
        if findBar.isHidden {
            clearFind()
        } else {
            window?.makeFirstResponder(findField)
            if !findField.stringValue.isEmpty { findChanged() }
        }
    }

    private func clearFind() {
        findGeneration += 1
        findMatches = []; findMatchList = []
        findCountLabel.stringValue = ""
        tableView.reloadData()
    }

    @objc private func findChanged() {
        guard let store else { return }
        let needle = findField.stringValue
        findGeneration += 1
        let gen = findGeneration
        guard !needle.isEmpty else { clearFind(); return }
        var matches: [Int] = []
        let total = store.count
        func chunk(_ from: Int) {
            guard gen == findGeneration else { return }
            let upper = min(from + 30_000, total)
            for i in from..<upper where store.line(i).range(of: needle, options: .caseInsensitive) != nil {
                matches.append(i)
            }
            if upper < total {
                findCountLabel.stringValue = String(format: L("Searching… %lld%%"), Int(Double(upper) / Double(total) * 100))
                DispatchQueue.main.async { chunk(upper) }
            } else {
                findMatchList = matches
                findMatches = Set(matches)
                findCountLabel.stringValue = String(format: L("%lld matches"), matches.count)
                tableView.reloadData()
                navigateFind(forward: true)
            }
        }
        chunk(0)
    }

    private func currentLine() -> Int? {
        let row = tableView.selectedRow
        return row >= 0 ? lineIndex(forRow: row) : nil
    }

    @objc private func findNext() { navigateFind(forward: true) }
    @objc private func findPrevious() { navigateFind(forward: false) }

    private func navigateFind(forward: Bool) {
        guard !findMatchList.isEmpty else { NSSound.beep(); return }
        let cur = currentLine() ?? (forward ? -1 : Int.max)
        let target = forward
            ? (findMatchList.first { $0 > cur } ?? findMatchList.first!)
            : (findMatchList.last { $0 < cur } ?? findMatchList.last!)
        scrollToLine(target)
    }

    // MARK: - Go to date/time

    @objc private func goToTime() {
        guard let store else { return }
        let alert = NSAlert()
        alert.messageText = L("Go to Date/Time")
        alert.informativeText = L("Jump to the first line at or after a timestamp (e.g. 2024-01-15 10:23:45).")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: L("Go"))
        alert.addButton(withTitle: L("Cancel"))
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let query = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        findGeneration += 1
        let gen = findGeneration
        let total = store.count
        // Chunked async scan (logs are typically chronological): first line whose
        // timestamp is lexicographically >= the query. Non-blocking on huge files.
        func chunk(_ from: Int) {
            guard gen == findGeneration else { return }
            let upper = min(from + 30_000, total)
            for i in from..<upper {
                if let ts = classify(store.line(i)).timestamp, ts >= query {
                    scrollToLine(i); updateStatus(); return
                }
            }
            if upper < total {
                statusLabel.stringValue = String(format: L("Searching… %lld%%"), Int(Double(upper) / Double(total) * 100))
                DispatchQueue.main.async { chunk(upper) }
            } else {
                NSSound.beep(); updateStatus()
            }
        }
        chunk(0)
    }

    // MARK: - Detail pane

    private func updateDetail() {
        guard !detailScroll.isHidden, let store else { return }
        let texts = tableView.selectedRowIndexes.compactMap { lineIndex(forRow: $0).map { store.line($0) } }
        detailText.string = texts.joined(separator: "\n")
    }

    // MARK: - NSTableView marks & selection

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let id = NSUserInterfaceItemIdentifier("markrow")
        let v = (tableView.makeView(withIdentifier: id, owner: self) as? MarkRowView) ?? {
            let r = MarkRowView(); r.identifier = id; return r
        }()
        v.isMarked = !findMatches.isEmpty && (lineIndex(forRow: row).map { findMatches.contains($0) } ?? false)
        return v
    }

    func tableViewSelectionDidChange(_ notification: Notification) { updateDetail() }

    // MARK: - Menus (own Edit + Log, installed by the host while this window is key)

    func makeEditMenu() -> NSMenu {
        let menu = NSMenu(title: L("Edit"))
        menuItem(menu, L("Copy"), #selector(copySelectedLines), key: "c")
        menuItem(menu, L("Select All"), #selector(NSTableView.selectAll(_:)), key: "a", target: nil)
        menu.addItem(.separator())
        menuItem(menu, L("Find…"), #selector(toggleFindBar), key: "f")
        menuItem(menu, L("Find Next"), #selector(findNext), key: "g")
        let prev = NSMenuItem(title: L("Find Previous"), action: #selector(findPrevious), keyEquivalent: "g")
        prev.keyEquivalentModifierMask = [.command, .shift]
        prev.target = self
        menu.addItem(prev)
        return menu
    }

    func makeContentMenu() -> NSMenu {
        let menu = NSMenu(title: L("Log"))
        menuItem(menu, L("Go to Line…"), #selector(goToLine), key: "l")
        menuItem(menu, L("Go to Date/Time…"), #selector(goToTime), key: "t")
        menu.addItem(.separator())
        menuItem(menu, L("Copy Entry (all lines)"), #selector(copyEntry))
        menuItem(menu, L("Copy Line"), #selector(copyLine))
        menuItem(menu, L("Copy Selected Lines"), #selector(copySelectedLines))
        return menu
    }

    private func menuItem(_ menu: NSMenu, _ title: String, _ selector: Selector, key: String = "", target: AnyObject? = nil) {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = target ?? self
        menu.addItem(item)
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menuItem(menu, L("Copy Entry (all lines)"), #selector(copyEntry))
        menuItem(menu, L("Copy Line"), #selector(copyLine))
        menuItem(menu, L("Copy Selected Lines"), #selector(copySelectedLines), key: "c")
        menuItem(menu, L("Go to Line…"), #selector(goToLine))
        return menu
    }

    private func copyToPasteboard(_ lines: [String]) {
        guard !lines.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }

    @objc private func copyEntry() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard let line = lineIndex(forRow: row), let store else { return }
        copyToPasteboard(entryLineRange(containing: line).map { store.line($0) })
    }
    @objc private func copyLine() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        if let line = lineIndex(forRow: row), let store { copyToPasteboard([store.line(line)]) }
    }
    @objc private func copySelectedLines() {
        guard let store else { return }
        let texts = tableView.selectedRowIndexes.compactMap { lineIndex(forRow: $0).map { store.line($0) } }
        copyToPasteboard(texts)
    }
    @objc func copy(_ sender: Any?) { copySelectedLines() }
}

/// Table row view that tints its background when its line is a Find match.
final class MarkRowView: NSTableRowView {
    var isMarked = false { didSet { if isMarked != oldValue { needsDisplay = true } } }
    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        guard isMarked else { return }
        NSColor.systemYellow.withAlphaComponent(0.30).setFill()
        dirtyRect.fill()
    }
}
