// SPDX-License-Identifier: Apache-2.0
// FilePreviewView.swift - One preview area, used by both quick previews: the Info page of the side
// panel (F-343) and the embedded Quick View that takes over the inactive panel (F-118).
//
// It answers one question per file. An **image** is drawn by us, in a scroll view we own, so it can be
// zoomed — `QLPreviewView` renders and exposes nothing, so a zoom control has nothing to act on there.
// Everything else QuickLook can render (a PDF, a video, a Keynote deck) still goes to QuickLook
// untouched, and what QuickLook has no generator for falls back to the file's icon.
//
// One class rather than the same routing written twice: the two callers had the same complaint from the
// same user ("no zoom in the quick preview"), and two copies of a rule is how they come to disagree —
// this codebase has paid that bill before, in the three save paths that each kept their own `.bak`.

import AppKit
import PDFKit
import Quartz
import PCFoundation

@MainActor
final class FilePreviewView: NSView {

    // The three routes. All three live for the view's lifetime; only one is visible at a time, because
    // rebuilding a QLPreviewView per selection makes the panel flicker and throws away QuickLook's own
    // state — including which page of a document the user had scrolled to.
    private var quickLook: QLPreviewView?
    /// PDF and word-processor documents are rendered in-process (F-429): QuickLook draws them out of
    /// process, so nothing here could tell a rendered page from a blank one — and these two are the formats
    /// a file manager is asked about most. They also gain the zoom the image route already had.
    private var pdfView: PDFView?
    private var richScroll: NSScrollView?
    private var richText: NSTextView?
    /// Which renderer is showing, so the zoom buttons act on the right one.
    private var route: PreviewRoute = .quickLook

    /// `Viewer.RenderDocumentsInApp` (F-429): render PDFs and word-processor documents in the application,
    /// or leave everything to Quick Look as before.
    ///
    /// Static, because every preview in the window — the side panel, Quick View, the info page — must answer
    /// the same way, and the setting is one switch rather than one per view. Read at startup and on change.
    @MainActor static var rendersDocumentsInApp = true
    private let iconView = NSImageView()
    private let imageScroll = NSScrollView()
    private let imageView = NSImageView()
    private lazy var zoom = ImageZoomController(scrollView: imageScroll, imageView: imageView)

    private let zoomBar = NSStackView()
    private let levelLabel = NSTextField(labelWithString: "")

    /// The item currently shown, so a repeated selection does not rebuild anything.
    private var shownPath: String?
    /// Pending debounced load; cancelled when the cursor moves on.
    private var pendingLoad: DispatchWorkItem?

    /// How long to wait before loading. Holding an arrow key walks a directory in a few milliseconds per
    /// row, and starting a preview for every row it passes would spawn a renderer per keystroke.
    private static let debounce = 0.18

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        imageScroll.translatesAutoresizingMaskIntoConstraints = false
        imageScroll.hasVerticalScroller = false      // a narrow panel has no points to spare for them
        imageScroll.hasHorizontalScroller = false
        imageScroll.drawsBackground = false
        imageScroll.borderType = .noBorder
        imageScroll.isHidden = true
        imageScroll.documentView = imageView
        addSubview(imageScroll)

        zoomBar.orientation = .horizontal
        zoomBar.spacing = 2
        zoomBar.alignment = .centerY
        zoomBar.edgeInsets = NSEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)
        zoomBar.translatesAutoresizingMaskIntoConstraints = false
        zoomBar.wantsLayer = true
        zoomBar.layer?.cornerRadius = 6
        zoomBar.isHidden = true

        levelLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        levelLabel.textColor = .secondaryLabelColor
        levelLabel.alignment = .right
        levelLabel.setAccessibilityLabel(String(localized: "Zoom level"))
        // Wide enough for "1600%", so the buttons do not shuffle sideways as the number grows.
        levelLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 42).isActive = true

        for (symbol, title, action) in [
            ("minus.magnifyingglass", String(localized: "Zoom Out"), #selector(zoomOutPressed)),
            ("plus.magnifyingglass", String(localized: "Zoom In"), #selector(zoomInPressed)),
            ("1.magnifyingglass", String(localized: "Actual Size"), #selector(actualSizePressed)),
            ("arrow.up.left.and.down.right.magnifyingglass", String(localized: "Zoom to Fit"),
             #selector(zoomToFitPressed)),
        ] as [(String, String, Selector)] {
            zoomBar.addView(button(symbol: symbol, title: title, action: action), in: .leading)
        }
        zoomBar.addView(levelLabel, in: .leading)
        addSubview(zoomBar)

        zoom.onScaleChange = { [weak self] _ in self?.refreshLevel() }
        applyTheme()

        let sides = [
            imageScroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageScroll.trailingAnchor.constraint(equalTo: trailingAnchor),
        ]
        // A collapsed sidebar is width 0, and a scroll view's clip view still wants room for itself: as a
        // required rule the pair cannot hold, and Auto Layout then drops one of its own choosing.
        for side in sides { side.priority = .init(999) }
        NSLayoutConstraint.activate(sides)
        NSLayoutConstraint.activate([
            imageScroll.topAnchor.constraint(equalTo: topAnchor),
            imageScroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor),
            iconView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor),
            zoomBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            zoomBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
    }

    private func button(symbol: String, title: String, action: Selector) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .accessoryBarAction
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.imagePosition = .imageOnly
        button.toolTip = title
        // The image carries the meaning, so the name has to be said as well as drawn: a borderless symbol
        // button is announced as "button" and nothing else.
        button.setAccessibilityLabel(title)
        button.target = self
        button.action = action
        button.widthAnchor.constraint(equalToConstant: 22).isActive = true
        return button
    }

    /// Repaint the strip's own ground. It lies over the picture, so without one its symbols disappear
    /// into whatever happens to be behind them.
    func applyTheme() {
        zoomBar.layer?.backgroundColor = Theme.current.windowBackground.withAlphaComponent(0.85).cgColor
    }

    // MARK: - What to show

    /// Show `path`, or the icon when there is nothing to preview.
    ///
    /// Debounced and deduplicated: called on every cursor move by both callers.
    /// Re-show whatever is showing, ignoring the "same path" shortcut — for a setting that changes which
    /// renderer a file gets (F-429).
    func reloadCurrent() {
        let path = shownPath
        shownPath = nil
        show(path: path, fallbackIcon: nil)
    }

    func show(path: String?, fallbackIcon: NSImage?) {
        guard shownPath != path else { return }
        shownPath = path
        pendingLoad?.cancel()

        guard let path, Self.canQuickLook(path) else {
            quickLook?.previewItem = nil
            quickLook?.isHidden = true
            hideImage()
            iconView.isHidden = false
            iconView.image = fallbackIcon
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.load(path) }
        pendingLoad = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounce, execute: work)
    }

    private func load(_ path: String) {
        iconView.isHidden = true
        let ext = (path as NSString).pathExtension
        route = PreviewRoute.route(forExtension: ext, isImage: Self.isImage(path),
                                   rendersDocumentsInApp: Self.rendersDocumentsInApp)
        if route != .image, route != .pdf {
            // Neither of the zoomable routes: no bar, and no number left over from the file before —
            // `hideImage()` cannot do it, because its guard returns early when there was no image (measured:
            // switching a PDF to Quick Look kept "100 %" beside a hidden bar).
            zoomBar.isHidden = true
            levelLabel.stringValue = ""
        }
        if route == .image, let image = NSImage(contentsOfFile: path) {
            hidePDF(); hideRich()
            quickLook?.previewItem = nil
            quickLook?.isHidden = true
            imageScroll.isHidden = false
            zoomBar.isHidden = false
            // Lay out first: the initial scale is a comparison against the viewport, and in the run-loop
            // turn a view is unhidden in, its clip view may still have the size it had while hidden.
            layoutSubtreeIfNeeded()
            zoom.present(image)
            refreshLevel()
            return
        }
        hideImage()
        if route == .pdf, showPDF(path) { return }
        if route == .rich, showRich(path) { return }
        // Either the file is something else, or the in-process reader could not read it — an .doc AppKit
        // declines, a PDF that is not one. QuickLook is the fallback rather than an error, because it can
        // often still show something.
        route = .quickLook
        hidePDF(); hideRich()
        let view = quickLook ?? {
            let created = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
            created.autostarts = false      // don't start playing media just because the cursor moved
            created.shouldCloseWithWindow = false
            created.translatesAutoresizingMaskIntoConstraints = false
            addSubview(created, positioned: .below, relativeTo: zoomBar)
            NSLayoutConstraint.activate([
                created.topAnchor.constraint(equalTo: topAnchor),
                created.leadingAnchor.constraint(equalTo: leadingAnchor),
                created.trailingAnchor.constraint(equalTo: trailingAnchor),
                created.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            quickLook = created
            return created
        }()
        view.isHidden = false
        // Lay out before handing QuickLook the item, so the view has its real size when asked to render
        // rather than the zero frame it still has in the run-loop turn it was added in.
        layoutSubtreeIfNeeded()
        view.previewItem = URL(fileURLWithPath: path) as NSURL
    }

    // MARK: - PDF and rich documents, in process (F-429)

    /// Show a PDF with PDFKit. Returns false when the file is not a readable PDF, so the caller can fall
    /// back rather than leave an empty view claiming to be a preview.
    private func showPDF(_ path: String) -> Bool {
        guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else { return false }
        hideRich()
        quickLook?.previewItem = nil
        quickLook?.isHidden = true
        let view = pdfView ?? {
            let created = PDFView()
            created.translatesAutoresizingMaskIntoConstraints = false
            created.displayMode = .singlePageContinuous
            created.displayDirection = .vertical
            // PDFKit's own background is a heavy grey; the panel decides its own colours (F-338).
            created.backgroundColor = Theme.current.windowBackground
            addSubview(created, positioned: .below, relativeTo: zoomBar)
            NSLayoutConstraint.activate([
                created.topAnchor.constraint(equalTo: topAnchor),
                created.leadingAnchor.constraint(equalTo: leadingAnchor),
                created.trailingAnchor.constraint(equalTo: trailingAnchor),
                created.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            pdfView = created
            return created
        }()
        view.isHidden = false
        view.document = document
        layoutSubtreeIfNeeded()
        // PDFKit computes the fitting scale *after* it has the document and the size, and says so only by
        // notification. Without this the label read 100 % beside a page drawn at 45 % (measured).
        NotificationCenter.default.removeObserver(self, name: .PDFViewScaleChanged, object: view)
        NotificationCenter.default.addObserver(self, selector: #selector(pdfScaleChanged),
                                              name: .PDFViewScaleChanged, object: view)
        // Fit the page to the panel first: a PDF at 100 % in a 280-point sidebar shows a corner of a page,
        // which reads as "it did not render".
        view.autoScales = true
        zoomBar.isHidden = false
        refreshLevel()
        return true
    }

    /// Show a word-processor document as formatted text, read by AppKit itself.
    private func showRich(_ path: String) -> Bool {
        // No documentType option: AppKit sniffs the format, which is what makes one call cover .docx, .odt
        // and .rtf — and what makes a file it cannot read return nil instead of an empty document.
        guard let attributed = try? NSAttributedString(url: URL(fileURLWithPath: path), options: [:],
                                                      documentAttributes: nil),
              attributed.length > 0 else { return false }
        hidePDF()
        quickLook?.previewItem = nil
        quickLook?.isHidden = true
        let scroll = richScroll ?? {
            let text = NSTextView()
            text.isEditable = false
            text.isSelectable = true
            text.drawsBackground = true
            text.backgroundColor = .white     // a document assumes paper; keeps its own colours readable
            text.textContainerInset = NSSize(width: 8, height: 8)
            let created = NSScrollView()
            created.documentView = text
            created.hasVerticalScroller = true
            created.drawsBackground = false
            created.translatesAutoresizingMaskIntoConstraints = false
            addSubview(created, positioned: .below, relativeTo: zoomBar)
            NSLayoutConstraint.activate([
                created.topAnchor.constraint(equalTo: topAnchor),
                created.leadingAnchor.constraint(equalTo: leadingAnchor),
                created.trailingAnchor.constraint(equalTo: trailingAnchor),
                created.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            richScroll = created
            richText = text
            return created
        }()
        scroll.isHidden = false
        richText?.textStorage?.setAttributedString(attributed)
        // Text reflows, so a zoom percentage would promise something it cannot keep. The label is cleared
        // with the bar: a stale "45%" from the previous file is worse than no number (F-429).
        zoomBar.isHidden = true
        levelLabel.stringValue = ""
        return true
    }

    @objc private func pdfScaleChanged() { refreshLevel() }

    private func hidePDF() {
        pdfView?.document = nil
        pdfView?.isHidden = true
    }

    private func hideRich() {
        richScroll?.isHidden = true
        richText?.textStorage?.setAttributedString(NSAttributedString())
    }

    /// Whether media should start by itself. Quick View follows the cursor and a video that begins
    /// playing on its own there is what the user asked for; in the side panel it is not.
    var autostartsMedia: Bool = false {
        didSet { quickLook?.autostarts = autostartsMedia }
    }

    /// Put the image route away, releasing the bitmap: walking a folder of 40-megapixel photographs
    /// otherwise keeps the last one alive for as long as the preview is open.
    /// Leaving a zoomable route: the bar goes and the number with it, so no stale percentage survives into
    /// a preview that cannot be zoomed (F-429).
    private func hideImage() {
        guard !imageScroll.isHidden || zoom.hasImage else { return }
        imageScroll.isHidden = true
        zoomBar.isHidden = true
        levelLabel.stringValue = ""
        zoom.clear()
    }

    /// Keep a fitted image fitted while the panel is dragged wider or the window resizes.
    override func layout() {
        super.layout()
        zoom.viewportChanged()
    }

    // MARK: - Zoom

    // The same four buttons drive whichever renderer is showing (F-429). PDFKit has its own scale factor
    // and its own idea of "fit", so the PDF route asks it rather than reimplementing zoom over a page.
    @objc private func zoomInPressed() {
        route == .pdf ? scalePDF(by: 1.25) : zoom.zoomIn()
    }
    @objc private func zoomOutPressed() {
        route == .pdf ? scalePDF(by: 1 / 1.25) : zoom.zoomOut()
    }
    @objc private func actualSizePressed() {
        guard route == .pdf else { zoom.actualSize(); return }
        pdfView?.autoScales = false
        pdfView?.scaleFactor = 1
        refreshLevel()
    }
    @objc private func zoomToFitPressed() {
        guard route == .pdf else { zoom.zoomToFit(); return }
        pdfView?.autoScales = true
        refreshLevel()
    }

    private func scalePDF(by factor: CGFloat) {
        guard let view = pdfView else { return }
        view.autoScales = false
        // PDFKit's own limits, so a click that cannot do anything does not pretend to: below the minimum a
        // page is unreadable, above the maximum it stops scaling and the label would drift from the view.
        view.scaleFactor = min(max(view.scaleFactor * factor, view.minScaleFactor), view.maxScaleFactor)
        refreshLevel()
    }

    private func refreshLevel() {
        switch route {
        case .image:
            levelLabel.stringValue = zoom.levelText
            return
        case .rich, .quickLook:
            // Neither is zoomable, and the image controller still has a level from the file before — which
            // is how "100 %" kept appearing beside a hidden bar (measured twice, F-429).
            levelLabel.stringValue = ""
            return
        case .pdf:
            break
        }
        guard let view = pdfView else {
            levelLabel.stringValue = zoom.levelText
            return
        }
        // PDFKit's scale is against the page's natural size, which is what "100 %" means for a document.
        levelLabel.stringValue = "\(Int((view.scaleFactor * 100).rounded()))%"
    }

    /// Whether we draw this file ourselves — i.e. whether it is an image.
    ///
    /// Asked of the *file's* type rather than of its extension, so a `.jpg` that is really a PDF goes to
    /// QuickLook where it belongs. `NSImage` is then asked to load it, and if it declines the file falls
    /// back to QuickLook too: "the system says image" and "we can draw it" are different claims, and a
    /// broken or exotic file can satisfy the first without the second.
    static func isImage(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else { return false }
        return type.conforms(to: .image)
    }

    /// Whether QuickLook should be asked at all.
    ///
    /// Directories and packages are deliberately excluded: QuickLook renders a folder as a generic icon
    /// anyway, so the icon path gives the same picture without spinning up a preview agent.
    private static func canQuickLook(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return false }
        guard isDir.boolValue else { return true }
        return NSWorkspace.shared.isFilePackage(atPath: path)
    }

    #if DEBUG
    /// Diagnostic: press one of the zoom buttons the way a click does (F-389).
    ///
    /// Through the button rather than the controller: the button is what the user has, and a control that
    /// is hidden, disabled or wired to nothing would pass a test that called the controller directly.
    /// Matched on the accessibility label, which is also the assertion that the label is there at all.
    @discardableResult
    func automationPressZoom(_ which: String) -> String {
        let wanted: String
        switch which {
        case "in": wanted = String(localized: "Zoom In")
        case "out": wanted = String(localized: "Zoom Out")
        case "actual": wanted = String(localized: "Actual Size")
        case "fit": wanted = String(localized: "Zoom to Fit")
        default: return "no such zoom command: \(which)"
        }
        guard let button = zoomBar.views.compactMap({ $0 as? NSButton })
            .first(where: { $0.accessibilityLabel() == wanted }) else { return "no button for \(wanted)" }
        guard !button.isHidden, !zoomBar.isHidden, button.isEnabled else { return "\(wanted) is not usable" }
        button.performClick(nil)
        return "ok"
    }

    /// Diagnostic: what the preview is showing and at what level (F-389).
    ///
    /// `route` comes first because it is the whole feature: an image takes a different path from a PDF,
    /// and no screenshot of a zoomed picture can say which view drew it.
    /// Whether a preview view is actually *drawing* anything: sample its cached display and count distinct
    /// colours (F-429).
    ///
    /// For the in-process renderers this is the answer — a uniform image means nothing was drawn. For
    /// QuickLook it is *not*: that content is composited from another process and never appears in our
    /// bitmap, which is precisely why PDF and word-processor documents no longer go through it.
    private static func qlDrawnReport(_ view: NSView?) -> String {
        guard let view, !view.isHidden, view.frame.width > 4, view.frame.height > 4 else { return "n/a" }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return "no-rep" }
        view.cacheDisplay(in: view.bounds, to: rep)
        var colours = Set<String>()
        let width = Int(rep.size.width), height = Int(rep.size.height)
        for y in stride(from: 2, to: max(3, height - 2), by: max(1, height / 12)) {
            for x in stride(from: 2, to: max(3, width - 2), by: max(1, width / 12)) {
                guard let c = rep.colorAt(x: x, y: y) else { continue }
                colours.insert(String(format: "%02X%02X%02X", Int(c.redComponent * 255),
                                      Int(c.greenComponent * 255), Int(c.blueComponent * 255)))
            }
        }
        return "distinct=\(colours.count) sample=\(colours.sorted().prefix(3).joined(separator: ","))"
    }

    /// The preview's state for the harness.
    ///
    /// `level` is what the panel *shows*, whichever renderer drives it; `imagelevel` is the image
    /// controller's own value, reported separately because reading `level=100%` next to `pdfscale=0.45`
    /// cost one wrong conclusion. Note that a comment cannot go inside the literal below — `//` in a
    /// multiline Swift string is text, and it duly appeared in the report (F-429).
    func automationZoomReport() -> String {
        let route: String
        if !imageScroll.isHidden, zoom.hasImage { route = "image" }
        else if pdfView?.isHidden == false { route = "pdf" }
        else if richScroll?.isHidden == false { route = "rich" }
        else if quickLook?.isHidden == false { route = "quicklook" }
        else { route = "icon" }
        let size = zoom.hasImage ? ImageZoomController.pixelSize(of: imageView.image ?? NSImage()) : .zero
        return """
        route=\(route)
        bar=\(zoomBar.isHidden ? "hidden" : "shown")
        level=\(levelLabel.stringValue)
        imagelevel=\(zoom.levelText)
        scale=\(String(format: "%.4f", zoom.scale))
        fitting=\(zoom.isFitting)
        pixels=\(Int(size.width))x\(Int(size.height))
        viewport=\(Int(imageScroll.contentView.frame.width))x\(Int(imageScroll.contentView.frame.height))
        ql=\(quickLook == nil ? "absent" : (quickLook!.isHidden ? "hidden" : "visible"))
        qlframe=\(Int(quickLook?.frame.width ?? 0))x\(Int(quickLook?.frame.height ?? 0))
        qlitem=\((quickLook?.previewItem?.previewItemURL?.lastPathComponent) ?? "none")
        qlpixels=\(Self.qlDrawnReport(quickLook))
        pdfpages=\(pdfView?.document?.pageCount ?? 0)
        pdfscale=\(String(format: "%.2f", pdfView?.scaleFactor ?? 0))
        pdfpixels=\(Self.qlDrawnReport(pdfView?.isHidden == false ? pdfView : nil))
        richchars=\(richText?.string.count ?? 0)
        richhead=\(String((richText?.string ?? "").replacingOccurrences(of: "\n", with: " ⏎ ").prefix(60)))
        buttons=\(zoomBar.views.compactMap { $0 as? NSButton }
                    .map { "\($0.accessibilityLabel() ?? "?"):\($0.image == nil ? "NO-IMAGE" : "ok")" }
                    .joined(separator: ","))
        \(ImageZoomController.drawnReport(scrollView: imageScroll, image: imageView.image))
        label=\(levelLabel.stringValue)
        """ + "\n"
    }
    #endif
}
