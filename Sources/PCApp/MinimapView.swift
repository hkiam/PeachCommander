// MinimapView.swift - A scaled overview of the whole file next to the editor/viewer:
// each line is drawn as a small block (indentation + length) so the code's shape is
// recognizable; a viewport rectangle shows the visible region; click/drag scrolls.
//
// Rendering is proportional by line index (no-wrap monospace ⇒ uniform line height),
// so the viewport uses simple pixel fractions with no layout-manager queries. The
// code shape is cached in an offscreen image and only re-rendered on text/size change.

import AppKit
import PCFoundation

@MainActor
final class MinimapView: NSView {
    private weak var textView: NSTextView?
    private weak var scrollView: NSScrollView?

    private var lines: [(indent: Int, length: Int)] = []
    private var maxCols = 60
    private var shapeImage: NSImage?
    private var contentSignature: Int?

    override var isFlipped: Bool { true }

    init(textView: NSTextView?, scrollView: NSScrollView) {
        self.textView = textView
        self.scrollView = scrollView
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = Theme.current.listBackground.cgColor
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(viewportMoved),
                                               name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func viewportMoved() { needsDisplay = true }

    /// Rebind to a new text view (the viewer replaces its content view per file/mode).
    /// Pass nil to blank the minimap (non-text content).
    func bind(textView: NSTextView?) {
        self.textView = textView
        contentSignature = nil
        refresh()
    }

    /// Recompute per-line metrics from the current text (cheap signature guard).
    func refresh() {
        guard let text = textView?.string else { lines = []; shapeImage = nil; needsDisplay = true; return }
        let sig = text.utf16.count &* 31 &+ text.hashValue
        if sig == contentSignature { return }
        contentSignature = sig
        (lines, maxCols) = MinimapMetrics.lineMetrics(text)
        shapeImage = nil
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        shapeImage = nil   // re-render at the new size
    }

    override func draw(_ dirtyRect: NSRect) {
        Theme.current.listBackground.setFill(); bounds.fill()
        guard !lines.isEmpty, bounds.height > 1, bounds.width > 1 else { return }
        if shapeImage == nil { shapeImage = renderShape() }
        shapeImage?.draw(in: bounds)
        drawViewport()
    }

    private func renderShape() -> NSImage {
        Self.shapeImage(lines: lines, maxCols: maxCols, size: bounds.size,
                        color: Theme.current.listText.withAlphaComponent(0.55))
    }

    /// Render the code-shape (one block per line) to an offscreen image.
    static func shapeImage(lines: [(indent: Int, length: Int)], maxCols: Int, size: NSSize, color: NSColor) -> NSImage {
        let img = NSImage(size: size)
        img.lockFocusFlipped(true)
        let n = CGFloat(max(1, lines.count))
        let lh = min(3.0, size.height / n)
        let cw = size.width / CGFloat(maxCols)
        color.setFill()
        let h = max(0.7, lh - 0.5)
        for (i, line) in lines.enumerated() where line.length > 0 {
            let y = CGFloat(i) * lh
            let x = CGFloat(line.indent) * cw
            let w = max(cw, CGFloat(line.length) * cw)
            NSRect(x: x, y: y, width: min(w, size.width - x), height: h).fill()
        }
        img.unlockFocus()
        return img
    }


    /// The translucent rectangle over the currently-visible lines.
    private func drawViewport() {
        guard let tv = textView, tv.bounds.height > 1 else { return }
        let vis = tv.visibleRect
        let doc = tv.bounds.height
        let top = (vis.minY / doc) * bounds.height
        let h = max(6, (vis.height / doc) * bounds.height)
        let rect = NSRect(x: 0, y: top, width: bounds.width, height: h)
        NSColor.systemGray.withAlphaComponent(0.22).setFill(); rect.fill()
        NSColor.systemGray.withAlphaComponent(0.5).setStroke()
        NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5)).stroke()
    }

    // MARK: - Click / drag to scroll

    override func mouseDown(with event: NSEvent) { scroll(to: convert(event.locationInWindow, from: nil)) }
    override func mouseDragged(with event: NSEvent) { scroll(to: convert(event.locationInWindow, from: nil)) }

    private func scroll(to point: NSPoint) {
        guard let tv = textView, let clip = scrollView?.contentView, bounds.height > 1 else { return }
        let fraction = max(0, min(1, point.y / bounds.height))
        let targetMidY = fraction * tv.bounds.height
        let maxY = max(0, tv.bounds.height - clip.bounds.height)
        let originY = max(0, min(targetMidY - clip.bounds.height / 2, maxY))
        clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: originY))
        scrollView?.reflectScrolledClipView(clip)
        needsDisplay = true
    }
}
