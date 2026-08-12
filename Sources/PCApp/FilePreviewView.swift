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
import Quartz
import PCFoundation

@MainActor
final class FilePreviewView: NSView {

    // The three routes. All three live for the view's lifetime; only one is visible at a time, because
    // rebuilding a QLPreviewView per selection makes the panel flicker and throws away QuickLook's own
    // state — including which page of a document the user had scrolled to.
    private var quickLook: QLPreviewView?
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
        if Self.isImage(path), let image = NSImage(contentsOfFile: path) {
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

    /// Whether media should start by itself. Quick View follows the cursor and a video that begins
    /// playing on its own there is what the user asked for; in the side panel it is not.
    var autostartsMedia: Bool = false {
        didSet { quickLook?.autostarts = autostartsMedia }
    }

    /// Put the image route away, releasing the bitmap: walking a folder of 40-megapixel photographs
    /// otherwise keeps the last one alive for as long as the preview is open.
    private func hideImage() {
        guard !imageScroll.isHidden || zoom.hasImage else { return }
        imageScroll.isHidden = true
        zoomBar.isHidden = true
        zoom.clear()
    }

    /// Keep a fitted image fitted while the panel is dragged wider or the window resizes.
    override func layout() {
        super.layout()
        zoom.viewportChanged()
    }

    // MARK: - Zoom

    @objc private func zoomInPressed() { zoom.zoomIn() }
    @objc private func zoomOutPressed() { zoom.zoomOut() }
    @objc private func actualSizePressed() { zoom.actualSize() }
    @objc private func zoomToFitPressed() { zoom.zoomToFit() }

    private func refreshLevel() { levelLabel.stringValue = zoom.levelText }

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
    func automationZoomReport() -> String {
        let route: String
        if !imageScroll.isHidden, zoom.hasImage { route = "image" }
        else if quickLook?.isHidden == false { route = "quicklook" }
        else { route = "icon" }
        let size = zoom.hasImage ? ImageZoomController.pixelSize(of: imageView.image ?? NSImage()) : .zero
        return """
        route=\(route)
        bar=\(zoomBar.isHidden ? "hidden" : "shown")
        level=\(zoom.levelText)
        scale=\(String(format: "%.4f", zoom.scale))
        fitting=\(zoom.isFitting)
        pixels=\(Int(size.width))x\(Int(size.height))
        viewport=\(Int(imageScroll.contentView.frame.width))x\(Int(imageScroll.contentView.frame.height))
        buttons=\(zoomBar.views.compactMap { $0 as? NSButton }
                    .map { "\($0.accessibilityLabel() ?? "?"):\($0.image == nil ? "NO-IMAGE" : "ok")" }
                    .joined(separator: ","))
        \(ImageZoomController.drawnReport(scrollView: imageScroll, image: imageView.image))
        label=\(levelLabel.stringValue)
        """ + "\n"
    }
    #endif
}
