// PreviewPanelView.swift - Collapsible right-hand info/preview sidebar (backlog).
//
// Three modes via a segmented control: Info (a Quick Look preview + metadata of
// the item under the cursor), Activities (running background transfers), and Log
// (finished transfers). The owner drives content via the setters and reads
// `mode`; visibility/width is managed by MainWindowController.

import AppKit
import PCFoundation

final class PreviewPanelView: NSView {
    enum Mode: Int { case info, activities, log }

    /// Fired when the user switches mode (so the owner can refresh content).
    var onModeChange: ((Mode) -> Void)?

    private static let builtinTitles = [
        String(localized: "Info"), String(localized: "Activities"), String(localized: "Log"),
    ]
    private let segmented = NSSegmentedControl(labels: builtinTitles,
                                               trackingMode: .selectOne, target: nil, action: nil)

    // Plugin view contributions (appended as extra segments after the built-ins).
    private var providers: [PreviewViewProvider] = []
    private let pluginContainer = NSView()
    private var mountedViews: [String: NSView] = [:]

    // Info mode.
    private let imageView = NSImageView()
    private let infoLabel = NSTextField(wrappingLabelWithString: "")
    private let infoScroll = NSScrollView()
    private let infoContent = NSView()

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
        segmented.selectedSegment = 0
        segmented.target = self
        segmented.action = #selector(modeChanged)
        segmented.translatesAutoresizingMaskIntoConstraints = false
        addSubview(segmented)

        // Info: image on top, metadata below (scrollable).
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.font = Fonts.system13
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoContent.translatesAutoresizingMaskIntoConstraints = false
        infoContent.addSubview(imageView)
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

        NSLayoutConstraint.activate([
            segmented.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            segmented.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            segmented.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),

            infoScroll.topAnchor.constraint(equalTo: segmented.bottomAnchor, constant: 6),
            infoScroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            infoScroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            infoScroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            infoContent.leadingAnchor.constraint(equalTo: infoScroll.leadingAnchor),
            infoContent.trailingAnchor.constraint(equalTo: infoScroll.trailingAnchor),
            infoContent.widthAnchor.constraint(equalTo: infoScroll.widthAnchor),
            infoContent.topAnchor.constraint(equalTo: infoScroll.topAnchor),

            imageView.topAnchor.constraint(equalTo: infoContent.topAnchor, constant: 10),
            imageView.centerXAnchor.constraint(equalTo: infoContent.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 160),
            imageView.heightAnchor.constraint(equalToConstant: 160),

            infoLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 12),
            infoLabel.leadingAnchor.constraint(equalTo: infoContent.leadingAnchor, constant: 10),
            infoLabel.trailingAnchor.constraint(equalTo: infoContent.trailingAnchor, constant: -10),
            infoLabel.bottomAnchor.constraint(equalTo: infoContent.bottomAnchor, constant: -10),
        ])
        for area in [activitiesScroll, logScroll, pluginContainer] {
            NSLayoutConstraint.activate([
                area.topAnchor.constraint(equalTo: segmented.bottomAnchor, constant: 6),
                area.leadingAnchor.constraint(equalTo: leadingAnchor),
                area.trailingAnchor.constraint(equalTo: trailingAnchor),
                area.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }
    }

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

    /// Replace the plugin segments. Tears down previously mounted views, rebuilds
    /// the segmented control, and resets to Info if the selection is now invalid.
    func setViewProviders(_ providers: [PreviewViewProvider]) {
        for v in mountedViews.values { v.removeFromSuperview() }
        mountedViews.removeAll()
        self.providers.forEach { $0.closeView() }
        self.providers = providers

        let titles = Self.builtinTitles + providers.map(\.title)
        segmented.segmentCount = titles.count
        for (i, t) in titles.enumerated() { segmented.setLabel(t, forSegment: i) }
        if segmented.selectedSegment < 0 || segmented.selectedSegment >= titles.count {
            segmented.selectedSegment = 0
        }
        modeChanged()
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

    func setInfo(image: NSImage?, text: String) {
        imageView.image = image
        infoLabel.stringValue = text
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
        activitiesText.textColor = Theme.current.listText
        logText.textColor = Theme.current.listText
    }
}
