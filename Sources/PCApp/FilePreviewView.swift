// SPDX-License-Identifier: Apache-2.0
// FilePreviewView.swift - One preview area, used by both quick previews: the Info page of the side
// panel (F-343) and the embedded Quick View that takes over the inactive panel (F-118).
//
// It answers one question per file. An **image** is drawn by us, in a scroll view we own, so it can be
// zoomed — `QLPreviewView` renders and exposes nothing, so a zoom control has nothing to act on there.
// A format a **lister plugin** claims is shown by that plugin, so a preview of a Markdown file and the
// F3 window looking at it are the same rendering rather than two that disagree. Everything else
// QuickLook can render (a PDF, a video, a Keynote deck) still goes to QuickLook untouched, and what
// QuickLook has no generator for falls back to the file's icon.
//
// One class rather than the same routing written twice: the two callers had the same complaint from the
// same user ("no zoom in the quick preview"), and two copies of a rule is how they come to disagree —
// this codebase has paid that bill before, in the three save paths that each kept their own `.bak`.

import AppKit
import PDFKit
import Quartz
import PCFoundation
// PLXLister + DetectContext: a preview may be drawn by the same plugin the F3 window uses.
import PCPluginHost

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
    /// The plugin view currently showing, and what it took to get it — kept whole so `ListLoadNext`
    /// can reuse it for the next file instead of tearing a web view down per cursor row.
    private var pluginRoute: (lister: PLXLister, handle: PLXHandle, view: NSView)?
    /// Which renderer is showing, so the zoom buttons act on the right one.
    private var route: PreviewRoute = .quickLook
    /// The deferral currently on screen (F-479), so the same one is not rebuilt per cursor arrival.
    private var deferredReason: String?

    /// `Viewer.RenderDocumentsInApp` (F-429): render PDFs and word-processor documents in the application,
    /// or leave everything to Quick Look as before.
    ///
    /// Static, because every preview in the window — the side panel, Quick View, the info page — must answer
    /// the same way, and the setting is one switch rather than one per view. Read at startup and on change.
    @MainActor static var rendersDocumentsInApp = true

    /// The lister plugins a preview may use, installed by the host when the enabled plugin set
    /// changes.
    ///
    /// Static for the same reason `rendersDocumentsInApp` is: every preview in the window — the side
    /// panel, Quick View, the info page — must answer the same way, and the set is one fact about
    /// the installation rather than one per view. Opening a plugin library costs a `dlopen`, and the
    /// cursor walking a directory would otherwise pay it per row.
    @MainActor static var listerPlugins: [PLXLister] = []

    /// Which host surface this preview is, for the plugin's `lister.surface` context.
    ///
    /// The side panel's info page and the embedded Quick View are the same class doing the same job
    /// at different sizes, and a renderer is allowed to care: Quick View takes half the window,
    /// the info page a column.
    var surfaceName = "preview"

    private let iconView = NSImageView()
    /// Shown instead of a preview when the file would cost too much to read just because the cursor
    /// landed on it (F-479). A sentence rather than a blank panel: "nothing here" is how the missing
    /// archive preview was reported in the first place.
    private let deferredLabel = NSTextField(wrappingLabelWithString: "")
    private let imageScroll = NSScrollView()
    private let imageView = NSImageView()
    private lazy var zoom = ImageZoomController(scrollView: imageScroll, imageView: imageView)

    private let zoomBar = NSStackView()
    private let levelLabel = NSTextField(labelWithString: "")

    /// The item currently shown, so a repeated selection does not rebuild anything.
    private var shownPath: String?
    /// The icon the host handed over with the current path, so a reload can show it again (F-430).
    private var lastFallbackIcon: NSImage?
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

        deferredLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        deferredLabel.textColor = .secondaryLabelColor
        deferredLabel.alignment = .center
        deferredLabel.isHidden = true
        deferredLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(deferredLabel)

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
            deferredLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            deferredLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
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
            deferredLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            deferredLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
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
        // The icon the caller gave us last time, not nil: for something that cannot be previewed at all,
        // passing nil emptied the panel until the cursor moved again (F-430).
        show(path: path, fallbackIcon: lastFallbackIcon)
    }

    func show(path: String?, fallbackIcon: NSImage?) {
        guard shownPath != path || !deferredLabel.isHidden else { return }
        deferredLabel.isHidden = true
        deferredLabel.stringValue = ""
        deferredReason = nil
        shownPath = path
        lastFallbackIcon = fallbackIcon
        pendingLoad?.cancel()

        guard let path, Self.canQuickLook(path) else {
            // Every renderer, not only QuickLook and the image: a PDFView left visible is drawn *over* the
            // icon, so the panel kept showing the previous document while claiming to preview a folder
            // (F-430). The bar and its number go with them — `hideImage()` cannot do it, since its guard
            // returns early when there was no image.
            quickLook?.previewItem = nil
            quickLook?.isHidden = true
            hidePDF()
            hideRich()
            hideImage()
            hidePlugin()
            route = .quickLook
            zoomBar.isHidden = true
            levelLabel.stringValue = ""
            iconView.isHidden = false
            iconView.image = fallbackIcon
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.load(path) }
        pendingLoad = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounce, execute: work)
    }

    /// Show the file's icon and why it is not being previewed (F-479).
    ///
    /// A state of its own rather than `show(path: nil)`: the panel is not empty because there is
    /// nothing to show, it is waiting because showing it would cost more than a cursor movement is
    /// allowed to. `key` is what makes a repeated cursor arrival cheap — the sentence names a size,
    /// so comparing the text alone would rebuild the label per file of the same size.
    func showDeferred(key: String, message: String, fallbackIcon: NSImage?) {
        guard deferredReason != key else { return }
        deferredReason = key
        shownPath = nil
        lastFallbackIcon = fallbackIcon
        pendingLoad?.cancel()
        quickLook?.previewItem = nil
        quickLook?.isHidden = true
        hidePDF()
        hideRich()
        hideImage()
        hidePlugin()
        route = .quickLook
        zoomBar.isHidden = true
        levelLabel.stringValue = ""
        iconView.isHidden = false
        iconView.image = fallbackIcon
        deferredLabel.stringValue = message
        deferredLabel.isHidden = false
    }

    private func load(_ path: String) {
        iconView.isHidden = true
        let ext = (path as NSString).pathExtension
        route = PreviewRoute.route(forExtension: ext, isImage: Self.isImage(path),
                                   hasPlugin: Self.lister(claiming: path) != nil,
                                   rendersDocumentsInApp: Self.rendersDocumentsInApp)
        // A plugin view is added last, so it lies *over* every other renderer and is opaque. Leaving it
        // there for a file it does not draw kept the panel showing the previous document — the metadata
        // above it updated, the picture did not, and it looked like the preview had stopped following the
        // cursor (measured: an .html rendered by the Markdown lister, then a .png in the other panel).
        // Only the QuickLook fallback at the end of this method used to put it away, which is why a plain
        // text file recovered and an image or a PDF did not. Before the routes below, since each of them
        // returns as soon as it has drawn something.
        if route != .plugin { hidePlugin() }
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
        if route == .plugin, showPlugin(path) { return }
        hidePlugin()
        // Either the file is something else, or the in-process reader could not read it — an .doc AppKit
        // declines, a PDF that is not one. QuickLook is the fallback rather than an error, because it can
        // often still show something.
        // The in-process renderer declined, so this is a QuickLook preview now.
        route = .quickLook
        showQuickLook(path)
    }

    /// Hand a file to QuickLook, creating its view on first use.
    ///
    /// Also used when the in-process reader declines a file *after* it said it would show it (an .doc AppKit
    /// cannot read), which is why the zoom bar is cleared here rather than at the call sites: it may still
    /// be showing the PDF route's "45 %" over a preview it cannot touch (F-430).
    private func showQuickLook(_ path: String) {
        hidePDF(); hideRich()
        zoomBar.isHidden = true
        levelLabel.stringValue = ""
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
    ///
    /// The read happens off the main thread (F-430): `NSAttributedString(url:)` converts the whole document,
    /// and for some formats starts the HTML importer — on a folder of large .docx files, or one on a slow
    /// mount, arrowing down froze the panel for the length of each read. QuickLook did this out of process
    /// and asynchronously, so the in-process route has to do it deliberately.
    ///
    /// Returns true when it *will* show the document; a file AppKit cannot read reports itself later, by
    /// falling back to QuickLook once the read has failed.
    private func showRich(_ path: String) -> Bool {
        hidePDF()
        quickLook?.previewItem = nil
        quickLook?.isHidden = true
        zoomBar.isHidden = true
        levelLabel.stringValue = ""
        let token = path
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // No documentType option: AppKit sniffs the format, which is what makes one call cover .docx,
            // .odt and .rtf — and what makes a file it cannot read return nil instead of an empty document.
            let attributed = try? NSAttributedString(url: URL(fileURLWithPath: path), options: [:],
                                                    documentAttributes: nil)
            DispatchQueue.main.async {
                guard let self, self.shownPath == token else { return }   // the cursor moved on
                guard let attributed, attributed.length > 0 else {
                    // AppKit declined it after all: QuickLook is still worth a try.
                    self.route = .quickLook
                    self.showQuickLook(path)
                    return
                }
                self.presentRich(attributed)
            }
        }
        return true
    }

    /// Put a read document into the text view, creating it on first use.
    private func presentRich(_ attributed: NSAttributedString) {
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
        // Text reflows, so a zoom percentage would promise something it cannot keep (F-429).
        zoomBar.isHidden = true
        levelLabel.stringValue = ""
    }

    @objc private func pdfScaleChanged() { refreshLevel() }

    /// Show `path` through the plugin that claims it. False when there is none, or it declines.
    ///
    /// `ListLoadNext` first: the cursor walking a directory of Markdown files would otherwise build
    /// and tear down a web view per row, and reusing the view is exactly what that entry point is
    /// for. A plugin that does not export it, or cannot reuse its view for this file, gets a fresh
    /// load — which is the same contract the F3 window's viewer cycling has.
    private func showPlugin(_ path: String) -> Bool {
        guard let lister = Self.lister(claiming: path) else { return false }
        quickLook?.previewItem = nil
        quickLook?.isHidden = true

        if let current = pluginRoute, current.lister === lister,
           lister.loadNext(parent: Unmanaged.passUnretained(self).toOpaque(),
                           listWin: current.handle, file: path) {
            current.view.isHidden = false
            return true
        }
        hidePlugin()

        let parent = Unmanaged.passUnretained(self).toOpaque()
        let extras = ["lister.surface": surfaceName,
                      "lister.width": String(Int(bounds.width)),
                      "lister.height": String(Int(bounds.height))]
        var handle: PLXHandle?
        if let context = ListerPluginContext.shared {
            context.withServices(extras) { services in
                handle = lister.loadEx(parent: parent, file: path, services: services)
            }
        } else {
            handle = lister.load(parent: parent, file: path)
        }
        guard let handle else { return false }
        let view = Unmanaged<NSView>.fromOpaque(handle).takeUnretainedValue()
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        pluginRoute = (lister, handle, view)
        return true
    }

    private func hidePlugin() {
        guard let current = pluginRoute else { return }
        current.view.removeFromSuperview()
        current.lister.close(current.handle)
        pluginRoute = nil
    }

    /// The first lister plugin whose detect string claims `path`.
    ///
    /// Detection only — no file is opened here. The plugin decides for itself in `ListLoad`, and a
    /// decline falls through to QuickLook, so a claim is a candidate rather than a promise.
    @MainActor
    private static func lister(claiming path: String) -> PLXLister? {
        guard !listerPlugins.isEmpty else { return nil }
        // The first 4 KB, because a detect string may probe bytes (`[0]=77`) and not only the
        // extension. Read here rather than lazily: this runs after the 0.18 s debounce, once per
        // file the cursor settles on, and a plugin that answers on bytes must be given them.
        let url = URL(fileURLWithPath: path)
        let head = (try? FileHandle(forReadingFrom: url)).map { handle -> [UInt8] in
            defer { try? handle.close() }
            return [UInt8](handle.readData(ofLength: 4096))
        } ?? []
        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
        let context = DetectContext(ext: url.pathExtension, size: size ?? 0, bytes: head)
        return listerPlugins.first { $0.handles(context) }
    }

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
        case .rich, .quickLook, .plugin:
            // None of them is zoomable — a plugin brings its own chrome and its own idea of scale, and
            // the ABI's font-size commands are the F3 window's business, not a preview's. The image
            // controller still has a level from the file before, which is how "100 %" kept appearing
            // beside a hidden bar (measured twice, F-429).
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
        // The plugin first, and not only before quicklook: its view is added last, so whatever else is
        // unhidden underneath it, the plugin is what is on screen. Asking about the image first reported
        // `route=image` over a web view still covering the panel — the report agreed with the code that
        // was wrong, so the harness could not see the defect it was pointed at.
        if let plugin = pluginRoute, !plugin.view.isHidden { route = "plugin · \(plugin.lister.name)" }
        else if !imageScroll.isHidden, zoom.hasImage { route = "image" }
        else if pdfView?.isHidden == false { route = "pdf" }
        else if richScroll?.isHidden == false { route = "rich" }
        else if quickLook?.isHidden == false { route = "quicklook" }
        else if !deferredLabel.isHidden { route = "deferred" }
        else { route = "icon" }
        let size = zoom.hasImage ? ImageZoomController.pixelSize(of: imageView.image ?? NSImage()) : .zero
        return """
        route=\(route)
        deferred=\(deferredLabel.isHidden ? "none" : deferredLabel.stringValue)
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
