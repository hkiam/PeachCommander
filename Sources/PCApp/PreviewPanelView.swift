// SPDX-License-Identifier: Apache-2.0
// PreviewPanelView.swift - Collapsible right-hand info/preview sidebar (backlog).
//
// Three modes via a segmented control: Info (a Quick Look preview + metadata of
// the item under the cursor), Activities (running background transfers), and Log
// (finished transfers). The owner drives content via the setters and reads
// `mode`; visibility/width is managed by MainWindowController.

import AppKit
import Quartz
import PCFoundation

final class PreviewPanelView: NSView {
    enum Mode: Int { case info, activities, log }

    /// Fired when the user switches mode (so the owner can refresh content).
    var onModeChange: ((Mode) -> Void)?

    private static let builtinTitles = [
        String(localized: "Info"), String(localized: "Activities"), String(localized: "Log"),
    ]
    private let segmented = PlacementSegmentedControl(labels: builtinTitles,
                                               trackingMode: .selectOne, target: nil, action: nil)

    // Plugin view contributions (appended as extra segments after the built-ins).
    private var providers: [PreviewViewProvider] = []
    private let pluginContainer = NSView()
    private var mountedViews: [String: NSView] = [:]

    // Info mode (F-343). Modelled on Finder's info sidebar: a large live preview on top, the
    // name and kind under it, then a key/value detail block.
    //
    // The preview is a real `QLPreviewView`, not a thumbnail image. That is what buys "every
    // format macOS can show" and paging through a multi-page document in one move — QuickLook
    // embeds the same renderers Finder uses, so a PDF scrolls page by page inside the panel.
    // The icon view stays as the fallback for what QuickLook has no generator for.
    private var previewView: QLPreviewView?
    private let previewHost = NSView()
    private let imageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let detailStack = NSStackView()
    private let infoLabel = NSTextField(wrappingLabelWithString: "")
    private let infoScroll = NSScrollView()
    private let infoContent = NSView()
    /// The item currently shown, so a repeated selection does not rebuild the preview.
    private var previewedPath: String?
    /// Pending debounced preview load; cancelled when the cursor moves on.
    private var previewWork: DispatchWorkItem?

    // Activities / Log modes share a read-only text view each.
    private let activitiesText = NSTextView()
    private let activitiesScroll = NSScrollView()
    private let logText = NSTextView()
    private let logScroll = NSScrollView()

    var mode: Mode { Mode(rawValue: segmented.selectedSegment) ?? .info }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true   // never let subviews (the segmented control) spill when collapsed
        isHidden = true               // hidden until toggled on
        setup()
        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        segmented.setAccessibilityLabel(String(localized: "Preview mode"))
        segmented.selectedSegment = 0
        segmented.target = self
        segmented.action = #selector(modeChanged)
        segmented.translatesAutoresizingMaskIntoConstraints = false
        addSubview(segmented)

        // Info: a large preview on top, then name/kind, then details (all scrollable).
        previewHost.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        previewHost.addSubview(imageView)
        titleLabel.font = Fonts.bold13
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        detailStack.orientation = .vertical
        detailStack.alignment = .leading
        detailStack.spacing = 2
        detailStack.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.font = Fonts.system13
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoContent.translatesAutoresizingMaskIntoConstraints = false
        infoContent.addSubview(previewHost)
        infoContent.addSubview(titleLabel)
        infoContent.addSubview(subtitleLabel)
        infoContent.addSubview(detailStack)
        infoContent.addSubview(infoLabel)
        infoScroll.documentView = infoContent
        infoScroll.hasVerticalScroller = true
        infoScroll.drawsBackground = false
        infoScroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(infoScroll)

        for (tv, scroll) in [(activitiesText, activitiesScroll), (logText, logScroll)] {
            tv.isEditable = false
            tv.drawsBackground = false
            tv.font = Fonts.monospacedDigit13
            tv.textContainerInset = NSSize(width: 6, height: 6)
            scroll.documentView = tv
            scroll.hasVerticalScroller = true
            scroll.drawsBackground = false
            scroll.translatesAutoresizingMaskIntoConstraints = false
            scroll.isHidden = true
            addSubview(scroll)
        }

        pluginContainer.translatesAutoresizingMaskIntoConstraints = false
        pluginContainer.isHidden = true
        addSubview(pluginContainer)

        let inset = [
            previewHost.leadingAnchor.constraint(equalTo: infoContent.leadingAnchor, constant: 10),
            previewHost.trailingAnchor.constraint(equalTo: infoContent.trailingAnchor, constant: -10),
            titleLabel.leadingAnchor.constraint(equalTo: infoContent.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: infoContent.trailingAnchor, constant: -10),
            infoLabel.leadingAnchor.constraint(equalTo: infoContent.leadingAnchor, constant: 10),
            infoLabel.trailingAnchor.constraint(equalTo: infoContent.trailingAnchor, constant: -10),
        ]
        // The mode switcher spans the panel with 6 pt on each side, and a hidden panel is `width == 0`
        // — 12 pt of inset plus a control cannot fit in nothing. Same story as the inset constraints
        // below, and missed the first time because this pair was added later with the paging control.
        let switcherSides = [
            segmented.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            segmented.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
        ]
        for side in switcherSides { side.priority = .init(999) }
        NSLayoutConstraint.activate(switcherSides)
        NSLayoutConstraint.activate(inset)
        NSLayoutConstraint.activate([
            segmented.topAnchor.constraint(equalTo: topAnchor, constant: 6),


            infoContent.leadingAnchor.constraint(equalTo: infoScroll.leadingAnchor),
            infoContent.trailingAnchor.constraint(equalTo: infoScroll.trailingAnchor),
            infoContent.widthAnchor.constraint(equalTo: infoScroll.widthAnchor),
            infoContent.topAnchor.constraint(equalTo: infoScroll.topAnchor),
            // Fill the visible height, so previewHost has free space to expand into. Without this
            // the content view is only as tall as its content and the preview collapses to its
            // minimum.
            infoContent.heightAnchor.constraint(greaterThanOrEqualTo: infoScroll.heightAnchor),

            // The preview starts at the very top and takes every point the details below do not
            // need. A fixed aspect ratio left a band of empty panel above or below it depending
            // on how tall the panel was; growing into the free space removes that band and makes
            // the preview as large as the panel allows, which is the whole point.
            previewHost.topAnchor.constraint(equalTo: infoContent.topAnchor),
            previewHost.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),

            imageView.centerXAnchor.constraint(equalTo: previewHost.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: previewHost.centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: previewHost.widthAnchor),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: previewHost.heightAnchor),

            titleLabel.topAnchor.constraint(equalTo: previewHost.bottomAnchor, constant: 12),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            detailStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            detailStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailStack.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            infoLabel.topAnchor.constraint(equalTo: detailStack.bottomAnchor, constant: 10),
            infoLabel.bottomAnchor.constraint(equalTo: infoContent.bottomAnchor, constant: -10),
        ])
        // The panel collapses to width 0 when hidden, and hidden views still take part in layout.
        // The 10 pt insets then cannot hold, and Auto Layout logged a conflict on every pass and
        // dropped one of *its* choosing. Below-required priority says which to relax — the inset,
        // never the panel width — so a collapsed panel is simply a panel with no room for insets.
        for constraint in inset {
            constraint.priority = .init(999)
        }
        // Same story as the inset and switcher constraints above, and it took shipping the plugins into
        // the VM to see it: a *collapsed* panel is `width == 0`, and a scroll view pinned to both edges
        // as a required rule cannot also give its vertical scroller the 17 pt its clip view demands.
        // Seven conflicts, every time the panel was closed — invisible until a scenario closed one.
        for area in [infoScroll, activitiesScroll, logScroll, pluginContainer] {
            let sides = [
                area.leadingAnchor.constraint(equalTo: leadingAnchor),
                area.trailingAnchor.constraint(equalTo: trailingAnchor),
            ]
            for side in sides { side.priority = .init(999) }
            NSLayoutConstraint.activate(sides)
            NSLayoutConstraint.activate([
                area.topAnchor.constraint(equalTo: segmented.bottomAnchor, constant: 6),
                area.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }
    }

    #if DEBUG
    /// Diagnostic: select the preview tab with this title (a built-in or a plugin view), as a click would.
    /// Returns the titles when there is no match, so a failing scenario says what *was* there (F-372).
    @discardableResult
    func automationSelectTab(titled title: String) -> String {
        let titles = (0..<segmented.segmentCount).map { segmented.label(forSegment: $0) ?? "" }
        guard let index = titles.firstIndex(of: title) else { return "no such tab; have: " + titles.joined(separator: ", ") }
        segmented.selectedSegment = index
        modeChanged()
        return "ok"
    }
    #endif

    @objc private func modeChanged() {
        let sel = segmented.selectedSegment
        let isPlugin = sel >= Self.builtinTitles.count
        infoScroll.isHidden = isPlugin || sel != 0
        activitiesScroll.isHidden = isPlugin || sel != 1
        logScroll.isHidden = isPlugin || sel != 2
        pluginContainer.isHidden = !isPlugin
        if isPlugin {
            showPluginView(index: sel - Self.builtinTitles.count)
        } else {
            onModeChange?(mode)
        }
    }

    // MARK: - Plugin view providers (contribution container "sidebar")

    /// Replace the plugin segments, keeping the views that are still here.
    ///
    /// This used to remove every mounted view and call `closeView()` on every provider, which was the
    /// same defect the registry had: a refresh happens whenever *any* plugin's contributions change,
    /// so an unrelated toggle rebuilt this panel's views — and `PcCloseView` is how a plugin destroys
    /// whatever is behind a view. Now only views whose provider has genuinely gone are dropped, and
    /// they are only *dropped*: the mount may have moved to another container, and closing it there
    /// would kill it. The registry owns that decision and has already made it by the time this runs.
    ///
    /// Which segment is showing survives the rebuild too, by id — the segmented control is rebuilt
    /// from scratch, so a plugin appearing earlier in the list would otherwise silently switch the
    /// panel to a different view.
    func setViewProviders(_ providers: [PreviewViewProvider]) {
        let previous = selectedPluginViewId
        let keep = Set(providers.map(\.id))
        for (id, view) in mountedViews where !keep.contains(id) {
            view.removeFromSuperview()
            mountedViews[id] = nil
        }
        self.providers = providers

        let titles = Self.builtinTitles + providers.map(\.title)
        segmented.segmentCount = titles.count
        for (i, t) in titles.enumerated() { segmented.setLabel(t, forSegment: i) }
        if let previous, let index = providers.firstIndex(where: { $0.id == previous }) {
            segmented.selectedSegment = Self.builtinTitles.count + index
        } else if segmented.selectedSegment < 0 || segmented.selectedSegment >= titles.count {
            segmented.selectedSegment = 0
        }
        modeChanged()
    }

    /// Right-clicking the mode switcher offers to move the plugin view that is showing (F-381).
    ///
    /// It asks for the menu when the click happens rather than holding one, because the answer depends
    /// on which segment is selected and on where that view currently sits — a menu built once would be
    /// wrong the first time either changed. On a built-in mode there is nothing to move, so no menu
    /// appears at all; an empty one would suggest the feature is broken rather than inapplicable.
    var placementMenuProvider: ((_ viewId: String, _ title: String) -> NSMenu?)? {
        didSet { installPlacementMenu() }
    }

    private func installPlacementMenu() {
        segmented.contextMenuProvider = { [weak self] in
            guard let self, let provider = self.placementMenuProvider,
                  let id = self.selectedPluginViewId,
                  let view = self.providers.first(where: { $0.id == id }) else { return nil }
            return provider(id, view.title)
        }
    }

    /// The plugin view currently selected, or nil when a built-in mode is showing.
    private var selectedPluginViewId: String? {
        let index = segmented.selectedSegment - Self.builtinTitles.count
        return providers.indices.contains(index) ? providers[index].id : nil
    }

    /// Select the plugin segment for `id` (no-op if it isn't currently provided).
    func selectPluginView(id: String) {
        guard let idx = providers.firstIndex(where: { $0.id == id }) else { return }
        segmented.selectedSegment = Self.builtinTitles.count + idx
        modeChanged()
    }

    private func showPluginView(index: Int) {
        guard providers.indices.contains(index) else { return }
        for v in mountedViews.values { v.isHidden = true }
        let provider = providers[index]
        let view: NSView
        if let existing = mountedViews[provider.id] {
            view = existing
        } else if let made = provider.makeView() {
            made.translatesAutoresizingMaskIntoConstraints = false
            pluginContainer.addSubview(made)
            NSLayoutConstraint.activate([
                made.topAnchor.constraint(equalTo: pluginContainer.topAnchor),
                made.leadingAnchor.constraint(equalTo: pluginContainer.leadingAnchor),
                made.trailingAnchor.constraint(equalTo: pluginContainer.trailingAnchor),
                made.bottomAnchor.constraint(equalTo: pluginContainer.bottomAnchor),
            ])
            mountedViews[provider.id] = made
            view = made
        } else { return }
        view.isHidden = false
    }

    // MARK: - Content setters

    /// Fill the info page for one item (F-343).
    ///
    /// `details` are the Finder-style key/value rows; `fallbackIcon` is shown only when QuickLook
    /// cannot render the item — a folder, a broken link, a type with no generator.
    func setInfo(path: String?, title: String, subtitle: String,
                 details: [(String, String)], fallbackIcon: NSImage?) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        infoLabel.stringValue = ""

        detailStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (key, value) in details { detailStack.addArrangedSubview(Self.detailRow(key, value)) }

        setPreview(path: path, fallbackIcon: fallbackIcon)
    }

    /// Show `path` in a live QuickLook view, or the icon when it cannot be previewed.
    ///
    /// The `QLPreviewView` is created lazily and reused: rebuilding it per selection made the
    /// panel flicker and threw away QuickLook's own state — including which page of a document
    /// you had scrolled to.
    private func setPreview(path: String?, fallbackIcon: NSImage?) {
        guard previewedPath != path else { return }
        previewedPath = path
        previewWork?.cancel()

        guard let path, Self.canQuickLook(path) else {
            previewView?.previewItem = nil
            previewView?.isHidden = true
            imageView.isHidden = false
            imageView.image = fallbackIcon
            return
        }
        // Debounced: holding an arrow key walks a directory in a few milliseconds per row, and
        // asking QuickLook to render each one in passing would spawn a preview per keystroke. The
        // name and details above have already updated, so the panel still responds immediately.
        let work = DispatchWorkItem { [weak self] in self?.loadPreview(path) }
        previewWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }

    private func loadPreview(_ path: String) {
        imageView.isHidden = true
        let view = previewView ?? {
            let v = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
            v.autostarts = false            // don't start playing media just because the cursor moved
            v.shouldCloseWithWindow = false
            v.translatesAutoresizingMaskIntoConstraints = false
            previewHost.addSubview(v)
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: previewHost.topAnchor),
                v.leadingAnchor.constraint(equalTo: previewHost.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: previewHost.trailingAnchor),
                v.bottomAnchor.constraint(equalTo: previewHost.bottomAnchor),
            ])
            previewView = v
            return v
        }()
        view.isHidden = false
        // Lay out before handing QuickLook the item, so the view has its real size when asked to
        // render rather than the zero frame it still has in the run-loop turn it was added in.
        //
        // Kept as correct practice, not as a proven fix: the preview is flaky *inside the test VM*
        // (a spinner that never resolves) and this did not change that. Measured there instead:
        // loadPreview does run, with a 280x350 frame, for both a text file and a PDF — so the
        // integration hands QuickLook a properly sized view and what happens next is QuickLook's.
        // The same VM renders both files via qlmanage, and rendered them in the panel too once it
        // had been up for several minutes, which points at its preview-extension host.
        previewHost.layoutSubtreeIfNeeded()
        view.previewItem = URL(fileURLWithPath: path) as NSURL
    }

    /// Whether QuickLook should be asked at all.
    ///
    /// Directories and packages are deliberately excluded: QuickLook renders a folder as a generic
    /// icon anyway, so the icon path gives the same picture without spinning up a preview agent.
    private static func canQuickLook(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return false }
        guard isDir.boolValue else { return true }
        return NSWorkspace.shared.isFilePackage(atPath: path)
    }

    /// One "Key    Value" row, laid out like Finder's: dimmed key on the left, value right-aligned.
    private static func detailRow(_ key: String, _ value: String) -> NSView {
        let k = NSTextField(labelWithString: key)
        k.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        k.textColor = .secondaryLabelColor
        k.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let v = NSTextField(labelWithString: value)
        v.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        v.alignment = .right
        v.lineBreakMode = .byTruncatingMiddle
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [k, v])
        row.orientation = .horizontal
        row.distribution = .fill
        row.spacing = 8
        return row
    }

    func setActivities(_ text: String) {
        activitiesText.string = text
        activitiesText.textColor = Theme.current.listText
    }

    func setLog(_ text: String) {
        logText.string = text
        logText.textColor = Theme.current.listText
    }

    func applyTheme() {
        layer?.backgroundColor = Theme.current.windowBackground.cgColor
        infoLabel.textColor = Theme.current.listText
        titleLabel.textColor = Theme.current.listText
        activitiesText.textColor = Theme.current.listText
        logText.textColor = Theme.current.listText
    }
}
