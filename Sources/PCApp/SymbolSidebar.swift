// SymbolSidebar.swift - The collapsible symbol-outline sidebar shared by the file
// viewer and the editor: a filter field over a hierarchical NSOutlineView of a file's
// definitions. Parsing runs on a background queue (serialized) so large files don't
// stall typing; a content signature skips redundant re-parses.

import AppKit
import PCFoundation

@MainActor
final class SymbolSidebar: NSView {
    /// Called when a symbol is chosen (navigate to it).
    var onSelect: ((SymbolNode) -> Void)?
    /// Called (on the main thread) after a load with whether the file has any symbols.
    var onAvailabilityChanged: ((Bool) -> Void)?

    private let search = NSSearchField()
    private let outline = NSOutlineView()
    private let scroll = NSScrollView()
    private let controller = SymbolOutlineController()
    private let queue = DispatchQueue(label: "com.peachcommander.symbols", qos: .utility)
    private var generation = 0
    private var lastSignature: Int?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = Theme.current.listBackground.cgColor

        search.placeholderString = String(localized: "Filter symbols")
        search.translatesAutoresizingMaskIntoConstraints = false
        search.controlSize = .small
        search.font = NSFont.systemFont(ofSize: 11)
        search.target = self
        search.action = #selector(filterChanged)
        search.sendsSearchStringImmediately = true
        addSubview(search)

        outline.headerView = nil
        outline.rowSizeStyle = .small
        outline.backgroundColor = Theme.current.listBackground
        outline.autoresizesOutlineColumn = false
        outline.indentationPerLevel = 12
        let col = NSTableColumn(identifier: .init("symbol"))
        col.resizingMask = .autoresizingMask
        outline.addTableColumn(col)
        outline.outlineTableColumn = col
        outline.dataSource = controller
        outline.delegate = controller
        outline.allowsEmptySelection = true
        controller.outline = outline
        controller.onSelect = { [weak self] node in self?.onSelect?(node) }

        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = Theme.current.listBackground
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        NSLayoutConstraint.activate([
            search.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            search.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            search.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            scroll.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 5),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Extract + display the outline for `text` (background parse). Clears when the
    /// language is unsupported, the file is empty, or it exceeds the size cap.
    func load(text: String, ext: String) {
        guard SymbolOutline.supports(ext: ext), !text.isEmpty, text.utf16.count <= 4_000_000,
              let handles = SymbolOutline.handles(ext: ext) else {
            lastSignature = nil; setRoots([]); return
        }
        let signature = text.utf16.count &* 31 &+ text.hashValue
        if signature == lastSignature { return }   // content unchanged since last parse
        lastSignature = signature
        generation += 1
        let gen = generation
        let query = handles.query, language = handles.language
        queue.async { [weak self] in
            let roots = SymbolOutline.parse(text, query: query, language: language)
            DispatchQueue.main.async {
                guard let self, gen == self.generation else { return }
                self.setRoots(roots)
            }
        }
    }

    /// Reset the dedupe cache so the next `load` re-parses even if the text matches
    /// (e.g. when switching to a different file that happens to hash the same).
    func invalidate() { lastSignature = nil }

    /// Clear the outline (e.g. when the content isn't code).
    func clear() { generation += 1; lastSignature = nil; setRoots([]) }

    /// Move keyboard focus to the filter field (for a "go to symbol" shortcut).
    func focusFilter() { window?.makeFirstResponder(search) }

    /// The chain of definitions enclosing a UTF-16 offset (outermost → innermost),
    /// for a breadcrumb. Uses the full (unfiltered) tree.
    func enclosingPath(utf16 offset: Int) -> [SymbolNode] { controller.enclosingPath(utf16: offset) }

    /// The definition with the given name (depth-first), for go-to-definition.
    func definition(named name: String) -> SymbolNode? { controller.find(named: name) }

    private func setRoots(_ roots: [SymbolNode]) {
        controller.update(roots)
        applyFilter()
        onAvailabilityChanged?(!roots.isEmpty)
    }

    #if DEBUG
    /// Diagnostic: read the strings CURRENTLY rendered into each outline row (no
    /// forced reload/relayout), so it faithfully captures the on-screen state a
    /// user sees — a re-render could otherwise mask an invalidation bug.
    func renderedCellStrings() -> [String] {
        var out: [String] = []
        for r in 0..<outline.numberOfRows {
            let made = outline.view(atColumn: 0, row: r, makeIfNecessary: false)
            let live = outline.view(atColumn: 0, row: r, makeIfNecessary: true)
            let liveStr = (live as? NSTextField)?.stringValue ?? "<no-textfield>"
            let madeStr = made == nil ? "<not-rendered>" : ((made as? NSTextField)?.stringValue ?? "<no-textfield>")
            let frame = live?.frame ?? .zero
            out.append("madeIfNec=[\(madeStr)] live=[\(liveStr)] frame=\(Int(frame.width))x\(Int(frame.height))")
        }
        return out
    }
    #endif

    @objc private func filterChanged() { applyFilter() }

    private func applyFilter() {
        controller.setFilter(search.stringValue)
    }
}

/// NSOutlineView data source / delegate over a (filtered) tree of `SymbolNode`s.
@MainActor
final class SymbolOutlineController: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private var roots: [SymbolNode] = []
    private var display: [SymbolNode] = []
    var onSelect: ((SymbolNode) -> Void)?
    weak var outline: NSOutlineView?

    func update(_ roots: [SymbolNode]) { self.roots = roots }

    func enclosingPath(utf16 offset: Int) -> [SymbolNode] { SymbolTree.enclosingPath(roots, utf16: offset) }

    func find(named name: String) -> SymbolNode? { SymbolTree.find(roots, named: name) }

    func setFilter(_ query: String) {
        display = SymbolTree.filter(roots, query: query)
        outline?.reloadData()
        outline?.expandItem(nil, expandChildren: true)   // keep everything visible
    }

    private func node(_ item: Any?) -> SymbolNode? { item as? SymbolNode }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        node(item)?.children.count ?? display.count
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (node(item)?.children ?? display)[index]
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any?) -> Bool {
        !(node(item)?.children.isEmpty ?? true)
    }

    /// Short colored kind tag shown before the name.
    private static func tag(_ kind: String) -> (String, NSColor) {
        let p = Theme.currentSyntax
        switch kind {
        case "class", "struct", "enum", "union": return ("C", p.type)
        case "interface", "protocol", "trait":   return ("I", p.type)
        case "method":                            return ("m", p.function)
        case "function", "macro":                 return ("ƒ", p.function)
        case "module", "namespace":               return ("M", p.keyword)
        case "constant":                          return ("K", p.constant)
        case "type":                              return ("T", p.type)
        default:                                   return ("•", Theme.current.listText)
        }
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let sym = node(item) else { return nil }
        let id = NSUserInterfaceItemIdentifier("SymbolCell")
        let field = (outlineView.makeView(withIdentifier: id, owner: self) as? NSTextField)
            ?? { let f = NSTextField(labelWithString: ""); f.identifier = id
                 // Labels wrap by default: a long single-token symbol name would wrap
                 // to a clipped second line, leaving only the glyph visible. Force a
                 // single truncated line.
                 f.usesSingleLineMode = true; f.maximumNumberOfLines = 1
                 f.lineBreakMode = .byTruncatingTail; f.cell?.truncatesLastVisibleLine = true
                 f.drawsBackground = false; f.isBordered = false
                 f.isEditable = false; return f }()
        let (glyph, color) = Self.tag(sym.kind)
        let s = NSMutableAttributedString(string: glyph + "  ",
            attributes: [.foregroundColor: color, .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)])
        s.append(NSAttributedString(string: sym.name,
            attributes: [.foregroundColor: Theme.current.listText, .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]))
        field.attributedStringValue = s
        field.toolTip = "\(sym.name) — \(sym.kind) · \(String(localized: "line")) \(sym.line)"
        return field
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outline = notification.object as? NSOutlineView,
              let sym = outline.item(atRow: outline.selectedRow) as? SymbolNode else { return }
        onSelect?(sym)
    }
}
