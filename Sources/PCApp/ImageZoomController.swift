// SPDX-License-Identifier: Apache-2.0
// ImageZoomController.swift - Zooming an image inside a scroll view, for the quick preview in the info
// sidebar and for the viewer's image representation (F-389). The arithmetic is `ImageZoom` in
// PCFoundation; this is the AppKit half: what the scroll view and the image view have to be told.
//
// Driven by `NSScrollView.magnification`, which is what makes ⌘-scroll and a trackpad pinch work
// without a line of code here — AppKit does those itself once magnification is allowed, and a control
// that ignored them would be a second, disagreeing zoom.

import AppKit
import PCFoundation

/// A clip view that centres a document smaller than itself.
///
/// Without it a zoomed-out image sits in the bottom-left corner of the viewport with the empty space
/// above it, because a scroll view's job is scrolling and there is nothing to scroll. Centring is a
/// property rather than the class's nature: the same clip view carries text in the viewer, and centred
/// text with two lines in a tall window looks like a bug.
final class CenteringClipView: NSClipView {
    var centersDocument = false

    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard centersDocument, let document = documentView else { return rect }
        // documentView.frame is in *our* coordinates and already carries the magnification, so this
        // compares like with like: what the content occupies against what we can show.
        let content = document.frame.size
        if rect.width > content.width { rect.origin.x = (content.width - rect.width) / 2 }
        if rect.height > content.height { rect.origin.y = (content.height - rect.height) / 2 }
        return rect
    }
}

@MainActor
final class ImageZoomController {
    /// Notified whenever the level changes, including from a pinch or ⌘-scroll the user did.
    var onScaleChange: ((CGFloat) -> Void)?

    /// Whether the image is currently following the viewport ("best fit").
    ///
    /// Kept as a mode rather than derived from the numbers: fit has to *stay* fit while the window or
    /// the sidebar is resized, and comparing the current scale against the fit scale cannot tell the
    /// difference between "the user asked to fit" and "the user happened to land on that number".
    private(set) var isFitting = false

    private let scrollView: NSScrollView
    private let imageView: NSImageView
    private var imageSize: CGSize = .zero

    /// The level, where 1 is one image pixel per point — actual size.
    var scale: CGFloat { scrollView.magnification }

    var hasImage: Bool { imageSize.width > 0 && imageSize.height > 0 }

    /// Take over `scrollView` for image zooming. The clip view is replaced with a centring one, which
    /// only centres while an image is on screen (`present`/`clear` flip it).
    init(scrollView: NSScrollView, imageView: NSImageView) {
        self.scrollView = scrollView
        self.imageView = imageView
        if !(scrollView.contentView is CenteringClipView) {
            let clip = CenteringClipView()
            clip.drawsBackground = scrollView.contentView.drawsBackground
            // Replacing the clip view does **not** carry the document view across: it stays a subview of
            // the old, now-detached clip, and the scroll view is left with `documentView == nil`. Nothing
            // is drawn, while magnification, fit and the level all still compute perfectly — so the panel
            // was empty and every number in the diagnostic looked right. `present` re-installs it, which
            // is also where it belongs: in the viewer this same scroll view carries text between images.
            let existing = scrollView.documentView
            scrollView.contentView = clip
            scrollView.documentView = existing
        }
        // The image view must not resize with the clip view: its frame *is* the zoom level, in image
        // pixels, and a view stretched to the viewport would make magnification 1 mean "fitted" — which
        // is exactly what the viewer used to call "actual size" while showing something else.
        imageView.imageScaling = .scaleAxesIndependently
        imageView.imageAlignment = .alignCenter
        imageView.autoresizingMask = []
        imageView.translatesAutoresizingMaskIntoConstraints = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(liveMagnifyEnded),
            name: NSScrollView.didEndLiveMagnifyNotification, object: scrollView)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    /// Show `image`, at the fitted scale if it is too big for the viewport and at 100% if it is not.
    func present(_ image: NSImage) {
        imageView.image = image
        // Idempotent, and the one place that guarantees the pairing: whatever else the scroll view was
        // showing, from now on it shows this image view.
        if scrollView.documentView !== imageView { scrollView.documentView = imageView }
        // `size` is in points and a Retina PNG reports half its pixels, which would make "100%" a
        // different number for two files that look identical. The pixel dimensions are what a viewer
        // means by actual size, so they are what the representation is asked for.
        let pixels = Self.pixelSize(of: image)
        imageSize = pixels
        imageView.frame = NSRect(origin: .zero, size: pixels)
        scrollView.allowsMagnification = true
        scrollView.minMagnification = ImageZoom.minScale
        scrollView.maxMagnification = ImageZoom.maxScale
        (scrollView.contentView as? CenteringClipView)?.centersDocument = true
        let initial = ImageZoom.initialScale(image: pixels, in: viewport)
        isFitting = initial < 1        // opened fitted ⇒ keep following the viewport
        apply(initial)
    }

    /// Hand the scroll view back to whatever else it shows (the viewer switches representations in it).
    func clear() {
        imageView.image = nil
        imageSize = .zero
        isFitting = false
        scrollView.allowsMagnification = false
        scrollView.magnification = 1
        (scrollView.contentView as? CenteringClipView)?.centersDocument = false
    }

    // MARK: - The four commands

    func zoomIn() { apply(ImageZoom.next(after: scale, zoomingIn: true), fitting: false) }
    func zoomOut() { apply(ImageZoom.next(after: scale, zoomingIn: false), fitting: false) }
    func actualSize() { apply(1, fitting: false) }

    func zoomToFit() {
        guard hasImage else { return }
        isFitting = true
        apply(ImageZoom.fitScale(image: imageSize, in: viewport))
    }

    /// Re-fit after the viewport changed, if fit is what the user asked for.
    ///
    /// Called from `layout`/`resize`, so it must be cheap and must not fight a user who has since zoomed
    /// somewhere else — hence the flag rather than "always re-fit".
    func viewportChanged() {
        guard isFitting, hasImage else { return }
        apply(ImageZoom.fitScale(image: imageSize, in: viewport))
    }

    /// What a status line or a label should show.
    var levelText: String { ImageZoom.percentText(scale) }

    // MARK: - Internals

    /// The visible area in points — the clip view's *frame*, deliberately not its bounds.
    ///
    /// A clip view's bounds are in the document's coordinate system, so magnification divides them: at
    /// 400% a 280-point-wide panel reports 70, and computing a fit scale from that gives an answer four
    /// times too small. Measured, not reasoned about — the first version used bounds and "Zoom to Fit"
    /// after zooming in landed on 5% instead of 9.3%, which a dump of the viewport made obvious.
    private var viewport: CGSize { scrollView.contentView.frame.size }

    private func apply(_ newScale: CGFloat, fitting: Bool? = nil) {
        guard hasImage else { return }
        if let fitting { isFitting = fitting }
        let clamped = ImageZoom.clamped(newScale)
        // Zoom about the middle of what is on screen, not about the corner: zooming in on a detail and
        // having it slide out of view is the difference between a zoom control and a lottery. The point
        // is in the clip view's coordinate system, which is the document's — the same space
        // `documentVisibleRect` is in.
        let visible = scrollView.documentVisibleRect
        scrollView.setMagnification(clamped, centeredAt: NSPoint(x: visible.midX, y: visible.midY))
        onScaleChange?(scale)
    }

    /// A pinch or ⌘-scroll is the user choosing a level, so fit stops following the viewport.
    @objc private func liveMagnifyEnded() {
        isFitting = false
        onScaleChange?(scale)
    }

    #if DEBUG
    /// Diagnostic: is the image really on screen? (F-389)
    ///
    /// Renders the scroll view and compares the colour in the middle of it against the colour in the
    /// middle of the image itself. Every other number — level, fit, viewport, the rects — was right while
    /// the quick preview drew *nothing at all*, because replacing the clip view had left the scroll view
    /// with no document view. Comparing against the image rather than against a literal colour keeps the
    /// check portable: a PNG's colour shifts a little through the profile conversion, and a window is a
    /// different size on every machine.
    ///
    /// Returns "drawn=yes|no rendered=#RRGGBB expected=#RRGGBB" so a failure says which of the two it is.
    static func drawnReport(scrollView: NSScrollView, image: NSImage?) -> String {
        func hex(_ colour: NSColor?) -> String {
            guard let c = colour?.usingColorSpace(.sRGB) else { return "none" }
            return String(format: "#%02X%02X%02X",
                          Int((c.redComponent * 255).rounded()),
                          Int((c.greenComponent * 255).rounded()),
                          Int((c.blueComponent * 255).rounded()))
        }
        let bounds = scrollView.bounds
        guard let image, bounds.width >= 4, bounds.height >= 4,
              let rep = scrollView.bitmapImageRepForCachingDisplay(in: bounds) else {
            return "drawn=no rendered=none expected=none"
        }
        scrollView.cacheDisplay(in: bounds, to: rep)
        let rendered = rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh / 2)
        let source = (image.representations.compactMap { $0 as? NSBitmapImageRep }.first)
            .flatMap { $0.colorAt(x: $0.pixelsWide / 2, y: $0.pixelsHigh / 2) }
        guard let a = rendered?.usingColorSpace(.sRGB), let b = source?.usingColorSpace(.sRGB) else {
            return "drawn=no rendered=\(hex(rendered)) expected=\(hex(source))"
        }
        // Compared by *character*, not by value. Matching channels within a tolerance sounds obvious and
        // is wrong: the file's colour goes through one profile conversion on its way to the screen and
        // another on its way back out of `colorAt`, so a 16x16 blue square read #6383D2 on screen against
        // #4B8DD2 in the file — the same blue by eye, 24 levels apart in red. Which channel dominates
        // survives any such conversion, and it is enough to tell a picture from an empty panel, since a
        // background is grey and a grey has no dominant channel at all.
        func character(_ c: NSColor) -> (dominant: Int, spread: CGFloat) {
            let channels = [c.redComponent, c.greenComponent, c.blueComponent]
            let maxValue = channels.max() ?? 0
            return (channels.firstIndex(of: maxValue) ?? 0, maxValue - (channels.min() ?? 0))
        }
        let screen = character(a), file = character(b)
        let colourful = file.spread > 0.08
        let same = colourful
            ? screen.dominant == file.dominant && screen.spread > 0.08
            // A grey or black fixture cannot be told apart this way, so fall back to closeness there.
            : abs(a.brightnessComponent - b.brightnessComponent) < 0.15
        return "drawn=\(same ? "yes" : "no") rendered=\(hex(a)) expected=\(hex(b))"
    }
    #endif

    /// An image's size in pixels, falling back to its point size for anything with no bitmap
    /// representation (a PDF-backed or symbol image, where points are all there is).
    static func pixelSize(of image: NSImage) -> CGSize {
        let widths = image.representations.map(\.pixelsWide).filter { $0 > 0 }
        let heights = image.representations.map(\.pixelsHigh).filter { $0 > 0 }
        guard let width = widths.max(), let height = heights.max() else { return image.size }
        return CGSize(width: width, height: height)
    }
}
