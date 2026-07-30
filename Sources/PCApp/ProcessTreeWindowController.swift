// SPDX-License-Identifier: Apache-2.0
// ProcessTreeWindowController.swift - Process hierarchy window for a TaskManager-
// like mount (any PFX content mount exposing "pid" + "ppid" fields).
//
// The host gathers each process's pid/ppid/name (+ CPU/MEM) from the mounted
// PFXFileSystem and this window renders the PPID forest in an NSOutlineView.
// Opened from the panel's context menu ("Show Process Tree"); it expands to and
// selects the process that was under the cursor, and a double-click reveals a
// process back in the panel. Read-only — a snapshot at open time.

import AppKit
import PCFoundation

@MainActor
final class ProcessTreeWindowController: NSWindowController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    /// One process row's data (gathered by the host from the mount).
    struct ProcInfo {
        let pid: Int
        let ppid: Int
        let name: String     // "<name> (<pid>)" — the panel entry name
        let cpu: String      // display string, may be empty
        let rss: Int64       // resident bytes, -1 if unknown
    }

    private final class Node {
        let info: ProcInfo
        weak var parent: Node?
        var children: [Node] = []
        init(_ info: ProcInfo) { self.info = info }
    }

    /// Double-click on a row → reveal that process (by entry name) in the panel.
    var onReveal: ((String) -> Void)?

    private let outline = NSOutlineView()
    private var roots: [Node] = []
    private var nodeByPid: [Int: Node] = [:]
    private let focusPid: Int?

    init(processes: [ProcInfo], focusPid: Int?) {
        self.focusPid = focusPid
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 560),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "Process Tree")
        window.minSize = NSSize(width: 360, height: 240)
        super.init(window: window)
        window.center()
        buildTree(processes)
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() { showWindow(nil); window?.makeKeyAndOrderFront(nil); expandToFocus() }

    // MARK: - Tree building

    private func buildTree(_ processes: [ProcInfo]) {
        for p in processes { nodeByPid[p.pid] = Node(p) }
        for p in processes {
            let node = nodeByPid[p.pid]!
            // Attach to the parent when it exists and isn't the node itself
            // (guards a self-parent); otherwise it's a forest root.
            if p.ppid != p.pid, let parent = nodeByPid[p.ppid] {
                parent.children.append(node)
                node.parent = parent
            } else {
                roots.append(node)
            }
        }
        let byName: (Node, Node) -> Bool = { $0.info.name.localizedCaseInsensitiveCompare($1.info.name) == .orderedAscending }
        roots.sort(by: byName)
        for n in nodeByPid.values { n.children.sort(by: byName) }
    }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let cols: [(String, String, CGFloat)] = [
            ("proc", String(localized: "Process"), 320),
            ("cpu", String(localized: "CPU %"), 70),
            ("mem", String(localized: "MEM"), 90),
        ]
        for (id, title, w) in cols {
            let col = NSTableColumn(identifier: .init(id))
            col.title = title
            col.width = w
            if id != "proc" { col.headerCell.alignment = .right }
            outline.addTableColumn(col)
            if id == "proc" { outline.outlineTableColumn = col }
        }
        outline.dataSource = self
        outline.delegate = self
        outline.rowSizeStyle = .default
        outline.usesAlternatingRowBackgroundColors = true
        outline.target = self
        outline.doubleAction = #selector(rowDoubleClicked)

        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
    }

    /// Expand every ancestor of the cursor's process and select it.
    private func expandToFocus() {
        guard let focusPid, let target = nodeByPid[focusPid] else {
            if roots.count == 1 { outline.expandItem(roots[0]) }
            return
        }
        var chain: [Node] = []
        var n: Node? = target.parent
        while let cur = n { chain.append(cur); n = cur.parent }
        for ancestor in chain.reversed() { outline.expandItem(ancestor) }
        let row = outline.row(forItem: target)
        if row >= 0 {
            outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            outline.scrollRowToVisible(row)
        }
    }

    @objc private func rowDoubleClicked() {
        guard let node = outline.item(atRow: outline.clickedRow) as? Node else { return }
        onReveal?(node.info.name)
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? Node)?.children.count ?? roots.count
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (item as? Node)?.children[index] ?? roots[index]
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !((item as? Node)?.children.isEmpty ?? true)
    }

    // MARK: - NSOutlineViewDelegate (view-based cells)

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? Node, let colID = tableColumn?.identifier.rawValue else { return nil }
        let text: String
        var rightAligned = false
        switch colID {
        case "cpu":
            text = node.info.cpu
            rightAligned = true
        case "mem":
            text = node.info.rss >= 0 ? ByteSize(node.info.rss).formatted(style: .mb) : ""
            rightAligned = true
        default:
            text = node.info.name
        }
        let id = NSUserInterfaceItemIdentifier("cell.\(colID)")
        let field = (outlineView.makeView(withIdentifier: id, owner: self) as? NSTextField) ?? {
            let f = NSTextField(labelWithString: "")
            f.identifier = id
            f.lineBreakMode = .byTruncatingTail
            f.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            return f
        }()
        field.stringValue = text
        field.alignment = rightAligned ? .right : .left
        return field
    }
}
