// SPDX-License-Identifier: Apache-2.0
// MarksPanelView.swift - The docked "Mark All" results panel shown at the bottom
// of the viewer/editor window (inside a horizontal NSSplitView). Replaces the
// old free-floating marks windows. Each search ("Mark All") becomes its own tab;
// the tab's table lists every occurrence (Line / Text) and scrolls both ways.
// Rows reveal in the host on selection; occurrences and whole searches can be
// removed right here. The panel can be hidden (collapsed, marks kept) or closed
// (marks cleared) via its header buttons — both delegated to the host.

import AppKit

/// One search's worth of marks, as shown in a tab.
struct MarksGroupVM {
    let id: Int
    let term: String
    let color: NSColor
    let occurrences: [MarksOccurrenceVM]
}

struct MarksOccurrenceVM {
    let line: Int      // 1-based, for display
    let text: String   // line snippet
}

/// The window controller that owns the marks backend fulfils these so the panel
/// stays generic across the viewer (line-based) and editor (range-based).
@MainActor
protocol MarksPanelHost: AnyObject {
    func marksPanelGroups() -> [MarksGroupVM]
    func marksPanelReveal(groupID: Int, occurrenceIndex: Int)
    func marksPanelRemoveOccurrence(groupID: Int, occurrenceIndex: Int)
    func marksPanelRemoveGroup(groupID: Int)
    func marksPanelClearAll()
}

/// NSTableView that forwards the Delete key so a selected occurrence can be
/// removed from the keyboard.
final class MarksTableView: NSTableView {
    var onDelete: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 || event.keyCode == 117 { onDelete?(); return }  // ⌫ / ⌦
        super.keyDown(with: event)
    }
}

@MainActor
final class MarksPanelView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    weak var host: MarksPanelHost?
    /// Collapse the panel but keep the marks (header ▽ button).
    var onHide: (() -> Void)?
    /// Close the panel and clear all marks (header × button).
    var onClose: (() -> Void)?

    private let tabScroll = NSScrollView()
    private let tabStack = NSStackView()
    private let table = MarksTableView()
    private let emptyLabel = NSTextField(labelWithString: "")

    private var groups: [MarksGroupVM] = []
    private var activeGroupID: Int?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        build()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Build

    private func build() {
        let header = makeHeader()

        tabStack.orientation = .horizontal
        tabStack.spacing = 4
        tabStack.edgeInsets = NSEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        tabScroll.translatesAutoresizingMaskIntoConstraints = false
        tabScroll.hasHorizontalScroller = true
        tabScroll.hasVerticalScroller = false
        tabScroll.autohidesScrollers = true
        tabScroll.drawsBackground = false
        tabScroll.documentView = tabStack

        let lineCol = NSTableColumn(identifier: .init("line"))
        lineCol.title = String(localized: "Line"); lineCol.width = 60; lineCol.minWidth = 44
        let textCol = NSTableColumn(identifier: .init("text"))
        textCol.title = String(localized: "Text"); textCol.width = 900; textCol.minWidth = 200
        table.addTableColumn(lineCol); table.addTableColumn(textCol)
        table.columnAutoresizingStyle = .noColumnAutoresizing   // allow horizontal scroll on long lines
        table.usesAlternatingRowBackgroundColors = true
        table.dataSource = self; table.delegate = self
        table.target = self; table.doubleAction = #selector(rowDoubleClicked)
        table.onDelete = { [weak self] in self?.removeSelectedOccurrence() }
        table.menu = makeRowMenu()

        let tableScroll = NSScrollView()
        tableScroll.translatesAutoresizingMaskIntoConstraints = false
        tableScroll.documentView = table
        tableScroll.hasVerticalScroller = true
        tableScroll.hasHorizontalScroller = true
        tableScroll.autohidesScrollers = true
        tableScroll.borderType = .noBorder

        emptyLabel.stringValue = String(localized: "No marks. Use “Mark All Occurrences…”.")
        emptyLabel.font = Fonts.system13
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(header)
        addSubview(tabScroll)
        addSubview(tableScroll)
        addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 24),

            tabScroll.topAnchor.constraint(equalTo: header.bottomAnchor),
            tabScroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabScroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            tabScroll.heightAnchor.constraint(equalToConstant: 28),
            tabStack.heightAnchor.constraint(equalTo: tabScroll.contentView.heightAnchor),

            tableScroll.topAnchor.constraint(equalTo: tabScroll.bottomAnchor),
            tableScroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableScroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableScroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: tableScroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableScroll.centerYAnchor),
        ])
    }

    private func makeHeader() -> NSView {
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.wantsLayer = true
        header.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let title = NSTextField(labelWithString: String(localized: "Marks"))
        title.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        title.textColor = .secondaryLabelColor
        title.translatesAutoresizingMaskIntoConstraints = false

        let hideButton = NSButton(title: "", target: self, action: #selector(hideClicked))
        hideButton.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Hide")
        hideButton.bezelStyle = .accessoryBarAction
        hideButton.isBordered = false
        hideButton.toolTip = String(localized: "Hide (keep marks)")
        hideButton.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = NSButton(title: "", target: self, action: #selector(closeClicked))
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.bezelStyle = .accessoryBarAction
        closeButton.isBordered = false
        closeButton.toolTip = String(localized: "Close (clear all marks)")
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        header.addSubview(title); header.addSubview(hideButton); header.addSubview(closeButton)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 8),
            title.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -6),
            closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            hideButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),
            hideButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        return header
    }

    private func makeRowMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: String(localized: "Remove Mark"),
                                action: #selector(removeSelectedOccurrence), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: String(localized: "Remove This Search"),
                                action: #selector(removeActiveGroup), keyEquivalent: ""))
        menu.items.forEach { $0.target = self }
        return menu
    }

    // MARK: - Data

    /// Reload from the host, preserving the active tab where possible.
    func reload() {
        groups = host?.marksPanelGroups() ?? []
        if activeGroupID == nil || !groups.contains(where: { $0.id == activeGroupID }) {
            activeGroupID = groups.last?.id
        }
        rebuildTabs()
        table.reloadData()
        let empty = activeGroup?.occurrences.isEmpty ?? true
        emptyLabel.isHidden = !empty
    }

    private var activeGroup: MarksGroupVM? { groups.first { $0.id == activeGroupID } }

    private func rebuildTabs() {
        tabStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for g in groups {
            let tab = MarkTabButton(group: g, isActive: g.id == activeGroupID)
            tab.onSelect = { [weak self] in self?.activeGroupID = g.id; self?.reload() }
            tab.onClose = { [weak self] in self?.host?.marksPanelRemoveGroup(groupID: g.id); self?.reload() }
            tabStack.addArrangedSubview(tab)
        }
    }

    // MARK: - Actions

    @objc private func hideClicked() { onHide?() }
    @objc private func closeClicked() { onClose?() }

    @objc private func rowDoubleClicked() { revealSelected() }
    func tableViewSelectionDidChange(_ notification: Notification) { revealSelected() }

    private func revealSelected() {
        guard let gid = activeGroupID, table.selectedRow >= 0 else { return }
        host?.marksPanelReveal(groupID: gid, occurrenceIndex: table.selectedRow)
    }

    @objc private func removeSelectedOccurrence() {
        guard let gid = activeGroupID, table.selectedRow >= 0 else { return }
        host?.marksPanelRemoveOccurrence(groupID: gid, occurrenceIndex: table.selectedRow)
        reload()
    }

    @objc private func removeActiveGroup() {
        guard let gid = activeGroupID else { return }
        host?.marksPanelRemoveGroup(groupID: gid)
        reload()
    }

    // MARK: - Table data source / delegate

    func numberOfRows(in tableView: NSTableView) -> Int { activeGroup?.occurrences.count ?? 0 }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let g = activeGroup, g.occurrences.indices.contains(row) else { return nil }
        let occ = g.occurrences[row]
        let isLine = tableColumn?.identifier.rawValue == "line"
        let f = NSTextField(labelWithString: isLine ? "\(occ.line)" : occ.text)
        f.lineBreakMode = .byTruncatingTail
        f.font = Fonts.monospacedDigit13
        if !isLine { f.textColor = g.color.withAlphaComponent(1) }
        return f
    }
}

/// A single tab in the marks panel: a color dot, the term with its count, and a
/// small × to remove that whole search.
@MainActor
private final class MarkTabButton: NSView {
    var onSelect: (() -> Void)?
    var onClose: (() -> Void)?

    init(group: MarksGroupVM, isActive: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.backgroundColor = (isActive ? NSColor.controlAccentColor.withAlphaComponent(0.22)
                                            : NSColor.controlColor).cgColor

        let dot = NSView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.wantsLayer = true
        dot.layer?.backgroundColor = group.color.withAlphaComponent(1).cgColor
        dot.layer?.cornerRadius = 5

        let label = NSButton(title: "\(group.term)  (\(group.occurrences.count))", target: self, action: #selector(selectTab))
        label.isBordered = false
        label.font = NSFont.systemFont(ofSize: 11, weight: isActive ? .semibold : .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let close = NSButton(title: "✕", target: self, action: #selector(closeTab))
        close.isBordered = false
        close.font = NSFont.systemFont(ofSize: 10)
        close.contentTintColor = .secondaryLabelColor
        close.translatesAutoresizingMaskIntoConstraints = false

        addSubview(dot); addSubview(label); addSubview(close)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 22),
            widthAnchor.constraint(lessThanOrEqualToConstant: 240),
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 10),
            dot.heightAnchor.constraint(equalToConstant: 10),
            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            close.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 4),
            close.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            close.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func selectTab() { onSelect?() }
    @objc private func closeTab() { onClose?() }
}
