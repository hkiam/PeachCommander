// SPDX-License-Identifier: Apache-2.0
// IconGridView.swift - Custom-drawn icon/thumbnail grid for the panel (TODOS #58).
//
// A self-contained grid view (consistent with the app's other custom views:
// PanelListView, HexListerView) that lays items out via PCFoundation.GridLayout and
// draws an icon + (wrapped) name per cell, highlighting the cursor. It handles mouse
// selection / double-click activation and arrow/Enter keys, reporting through
// callbacks — so the panel can drive it the same way it drives the detail table.
// Pure AppKit drawing (no NSCollectionView), so layout is deterministic/verifiable.

import AppKit
import PCFoundation

final class IconGridView: NSView, NSDraggingSource {
    struct Item {
        let name: String
        let icon: NSImage
        let isDirectory: Bool
        /// Absolute filesystem path, when the item is a real local file (enables
        /// drag-out). Nil for the synthetic ".." row or non-local entries.
        let path: String?
        init(name: String, icon: NSImage, isDirectory: Bool, path: String? = nil) {
            self.name = name
            self.icon = icon
            self.isDirectory = isDirectory
            self.path = path
        }
    }

    private var items: [Item] = []
    private(set) var cursorIndex = 0
    private var layout = GridLayout(itemWidth: 110, itemHeight: 92, spacing: 12, edgeInset: 12)
    private var iconSize: CGFloat = 48
    private let nameFont = NSFont.systemFont(ofSize: 11)
    /// Brief mode: column-major flow (top-to-bottom, then next column) + horizontal scroll.
    private var columnMajor = false
    /// Brief mode: small icon at the left + left-aligned name (a compact "list row").
    private var nameOnly = false

    /// Reconfigure cell geometry + flow (icons / gallery / brief). Triggers relayout+redraw.
    func configure(layout: GridLayout, iconSize: CGFloat, columnMajor: Bool = false, nameOnly: Bool = false) {
        self.layout = layout
        self.iconSize = iconSize
        self.columnMajor = columnMajor
        self.nameOnly = nameOnly
        relayout()
        needsDisplay = true
    }

    /// Replace one cell's image in place (e.g. an async thumbnail arrived).
    func setThumbnail(_ image: NSImage, at index: Int) {
        guard items.indices.contains(index) else { return }
        let old = items[index]
        items[index] = Item(name: old.name, icon: image, isDirectory: old.isDirectory, path: old.path)
        setNeedsDisplay(cellFrame(at: index))
    }

    /// Frame of a cell in the current flow (row-major by width, or column-major by height).
    private func cellFrame(at index: Int) -> CGRect {
        columnMajor ? layout.frameColumnMajor(at: index, height: bounds.height)
                    : layout.frame(at: index, width: bounds.width)
    }

    /// Activate (open / enter) the item at the index (double-click or Enter).
    var onActivate: ((Int) -> Void)?
    /// The cursor moved to a new index (click or arrows).
    var onCursorChanged: ((Int) -> Void)?
    /// Files were dropped onto the grid (`move` true when Command was held).
    var onDropFiles: (([String], _ move: Bool) -> Void)?
    /// Pending drag gesture captured on mouseDown, promoted in mouseDragged.
    private var dragCandidate: (index: Int, point: NSPoint)?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    func setItems(_ items: [Item], cursor: Int) {
        self.items = items
        cursorIndex = items.isEmpty ? 0 : max(0, min(cursor, items.count - 1))
        relayout()
        needsDisplay = true
    }

    func setCursor(_ index: Int) {
        guard items.indices.contains(index), index != cursorIndex else { return }
        cursorIndex = index
        scrollToCursor()
        needsDisplay = true
        onCursorChanged?(index)
    }

    /// Recompute the document size. Row-major (icons/gallery) matches the clip width
    /// and grows vertically; column-major (brief) matches the clip height and grows
    /// horizontally.
    func relayout() {
        if columnMajor {
            let height = superview?.bounds.height ?? enclosingScrollView?.contentSize.height ?? bounds.height
            let width = layout.contentWidth(count: items.count, height: height)
            setFrameSize(NSSize(width: max(width, 1), height: max(height, 1)))
        } else {
            let width = superview?.bounds.width ?? enclosingScrollView?.contentSize.width ?? bounds.width
            let height = layout.contentHeight(count: items.count, width: width)
            setFrameSize(NSSize(width: max(width, 1), height: max(height, 1)))
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        guard let clip = superview else { return }
        clip.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(clipResized),
                                               name: NSView.frameDidChangeNotification, object: clip)
        registerForDraggedTypes([.fileURL])
        relayout()
    }
    @objc private func clipResized() { relayout(); needsDisplay = true }

    private var columns: Int { layout.columns(forWidth: bounds.width) }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        Theme.current.listBackground.setFill()
        dirtyRect.fill()
        let para = NSMutableParagraphStyle()
        para.alignment = nameOnly ? .left : .center
        para.lineBreakMode = .byTruncatingTail
        for index in items.indices {
            let frame = cellFrame(at: index)
            guard frame.intersects(dirtyRect) else { continue }
            let item = items[index]

            if index == cursorIndex {
                Theme.current.cursorFrame.withAlphaComponent(0.25).setFill()
                NSBezierPath(roundedRect: frame.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
            }

            let attrs: [NSAttributedString.Key: Any] = [
                .font: nameFont, .foregroundColor: Theme.current.listText, .paragraphStyle: para
            ]
            if nameOnly {
                // Compact list row: small icon at the left, name vertically centered.
                let iconBox = NSRect(x: frame.minX + 4, y: frame.midY - iconSize / 2,
                                     width: iconSize, height: iconSize)
                item.icon.draw(in: Self.aspectFit(item.icon.size, in: iconBox))
                let nameRect = NSRect(x: iconBox.maxX + 5, y: frame.midY - nameFont.ascender + nameFont.descender,
                                      width: frame.maxX - iconBox.maxX - 7, height: nameFont.ascender - nameFont.descender + 2)
                NSAttributedString(string: item.name, attributes: attrs).draw(in: nameRect)
            } else {
                // Icon above a (wrapped/truncated) centered name.
                let iconBox = NSRect(x: frame.midX - iconSize / 2, y: frame.minY + 6,
                                     width: iconSize, height: iconSize)
                item.icon.draw(in: Self.aspectFit(item.icon.size, in: iconBox))
                let nameRect = NSRect(x: frame.minX + 2, y: iconBox.maxY + 3,
                                      width: frame.width - 4, height: frame.height - iconSize - 12)
                NSAttributedString(string: item.name, attributes: attrs).draw(in: nameRect)
            }
        }
    }

    /// Aspect-fit `imageSize` centered inside `box` (thumbnails aren't square).
    private static func aspectFit(_ imageSize: NSSize, in box: NSRect) -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return box }
        let scale = min(box.width / imageSize.width, box.height / imageSize.height)
        let w = imageSize.width * scale, h = imageSize.height * scale
        return NSRect(x: box.midX - w / 2, y: box.midY - h / 2, width: w, height: h)
    }

    private func scrollToCursor() {
        guard items.indices.contains(cursorIndex) else { return }
        scrollToVisible(cellFrame(at: cursorIndex).insetBy(dx: -layout.spacing, dy: -layout.spacing))
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let index = columnMajor
            ? layout.indexColumnMajor(at: point, height: bounds.height, count: items.count)
            : layout.index(at: point, width: bounds.width, count: items.count)
        guard let index else { return }
        if event.clickCount == 2 {
            onActivate?(index)
        } else {
            setCursor(index)
            dragCandidate = (index, point)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let cand = dragCandidate else { return }
        let p = convert(event.locationInWindow, from: nil)
        guard abs(p.x - cand.point.x) > 4 || abs(p.y - cand.point.y) > 4 else { return }
        dragCandidate = nil
        guard items.indices.contains(cand.index), let path = items[cand.index].path,
              FileManager.default.fileExists(atPath: path) else { return }
        let item = NSDraggingItem(pasteboardWriter: URL(fileURLWithPath: path) as NSURL)
        let box = cellFrame(at: cand.index)
        item.setDraggingFrame(box, contents: items[cand.index].icon)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        dragCandidate = nil
        super.mouseUp(with: event)
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        // Row-major: ←/→ step by one, ↑/↓ jump a row (column count). Column-major
        // (brief): ↑/↓ step by one, ←/→ jump a column (rows-per-column).
        let (stepH, jumpV): (Int, Int) = columnMajor
            ? (layout.rowsPerColumn(forHeight: bounds.height), 1)
            : (1, columns)
        switch event.keyCode {
        case 123: move(columnMajor ? -stepH : -1)   // ←
        case 124: move(columnMajor ? stepH : 1)     // →
        case 126: move(columnMajor ? -1 : -jumpV)   // ↑
        case 125: move(columnMajor ? 1 : jumpV)     // ↓
        case 36, 76: onActivate?(cursorIndex)        // Enter
        default: super.keyDown(with: event)
        }
    }

    private func move(_ delta: Int) {
        guard !items.isEmpty else { return }
        setCursor(max(0, min(cursorIndex + delta, items.count - 1)))
    }

    // MARK: - Drag & drop

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .move]
    }

    private func dropIsMove() -> Bool { NSEvent.modifierFlags.contains(.command) }

    private func canReadFileURLs(_ info: NSDraggingInfo) -> Bool {
        info.draggingPasteboard.canReadObject(forClasses: [NSURL.self],
                                              options: [.urlReadingFileURLsOnly: true])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        canReadFileURLs(sender) ? (dropIsMove() ? .move : .copy) : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        canReadFileURLs(sender) ? (dropIsMove() ? .move : .copy) : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(
                forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty else { return false }
        onDropFiles?(urls.map { $0.path }, dropIsMove())
        return true
    }
}
