// SPDX-License-Identifier: Apache-2.0
// PreviewPanelView.swift - Collapsible right-hand info/preview sidebar (backlog).
//
// Three built-in pages via a segmented control: Info (a Quick Look preview + metadata of
// the item under the cursor), Activities (running background transfers), and Log
// (finished transfers), plus one segment per plugin view mounted in the "sidebar"
// container. The owner drives content via the setters and reads `page`;
// visibility/width is managed by MainWindowController.
//
// **Each built-in page can be switched off, and Info alone is what ships (F-476).** Activities and Log
// are transfer lists most people never open, and they were charging a permanently visible switcher
// strip for the privilege. Which pages are on lives in `[Layout] PreviewTab*` and arrives here through
// `setVisibleBuiltins`; the panel itself never reads config.
//
// That is why the tabs are a `SidePanelTabList` rather than arithmetic on a segment index. This class
// used to make the index the identity — `enum Mode: Int { case info, activities, log }` read straight
// out of `selectedSegment`, and three separate methods offsetting by a hard-coded 3 — which is right
// exactly as long as all three built-ins are present. Switch Activities off and Log sits at index 1, so
// the panel reports "activities" and shows the Log page's content under the Activities label. The
// mapping is a tested value in PCFoundation now; nothing here counts segments.
//
// Two states follow from letting every page be switched off:
//
//   * **One tab needs no tab strip.** The switcher hides below two tabs, the same rule the bottom dock
//     already applies, and its constraints collapse to zero — a hidden view still takes part in Auto
//     Layout, so leaving them alone would leave a 30 pt band of dead panel above the Info page.
//   * **No tab at all says so.** Every built-in off with no plugin mounted is reachable — somebody who
//     keeps only the terminal here — and a blank strip reads as a broken panel.

import AppKit
import Quartz
import PCFoundation

final class PreviewPanelView: NSView {

    /// Fired when the user switches to a built-in page (so the owner can refresh content).
    var onPageChange: ((SidePanelPage) -> Void)?

    /// Fired when the user ticks a page in the switcher's context menu. The owner routes it through the
    /// same write path the Settings checkbox uses, so a tick and a checkbox cannot mean two things.
    var onTogglePage: ((SidePanelPage) -> Void)?

    private static func title(for page: SidePanelPage) -> String {
        switch page {
        case .info: return String(localized: "Info")
        case .activities: return String(localized: "Activities")
        case .log: return String(localized: "Log")
        }
    }

    /// Built empty and filled in by `rebuildTabs()`, which is the only thing that knows how many
    /// segments there are — the count is no longer a constant.
    private let segmented = PlacementSegmentedControl(frame: .zero)
    /// Collapsed to zero while the switcher is hidden; see the note at the top of the file.
    private var switcherTop: NSLayoutConstraint?
    private var switcherHeight: NSLayoutConstraint?

    /// The built-in pages that are switched on. Info alone until the owner says otherwise, which is
    /// also what a panel built before the configuration is read should show.
    private var visibleBuiltins: Set<SidePanelPage> = [.info]

    /// The tabs on offer right now. Rebuilt by `rebuildTabs()`, never by hand.
    private var tabs = SidePanelTabList(visibleBuiltins: [.info], pluginViewIds: [])

    // Plugin view contributions (appended as extra segments after the built-ins).
    private var providers: [PreviewViewProvider] = []
    private let pluginContainer = NSView()
    private var mountedViews: [String: NSView] = [:]

    /// Shown when there is no tab at all. Copied from the bottom dock, for the same reason it exists
    /// there: an empty frame reads as a broken panel, a sentence is a state the user can act on.
    private let emptyLabel = NSTextField(labelWithString: "")

    // Info mode (F-343). Modelled on Finder's info sidebar: a large live preview on top, the
    // name and kind under it, then a key/value detail block.
    //
    // The preview is a real `QLPreviewView`, not a thumbnail image. That is what buys "every
    // format macOS can show" and paging through a multi-page document in one move — QuickLook
    // embeds the same renderers Finder uses, so a PDF scrolls page by page inside the panel.
    // The icon view stays as the fallback for what QuickLook has no generator for.
    // The preview itself is `FilePreviewView`: an image is drawn by us so it can be zoomed, everything
    // else QuickLook renders goes to QuickLook, and the file's icon is the fallback (F-343, F-389). The
    // embedded Quick View in the inactive panel uses the same class, so the two quick previews cannot
    // drift apart.
    private let previewArea = FilePreviewView()
    /// The area the preview grows into: the top of the info page, above the name and the details.
    private let previewHost = NSView()
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

    // The Activities and Log pages share a read-only text view each.
    private let activitiesText = NSTextView()
    private let activitiesScroll = NSScrollView()
    private let logText = NSTextView()
    private let logScroll = NSScrollView()

    /// The built-in page showing, or nil when a plugin view or the empty state is.
    ///
    /// Optional rather than falling back to `.info`, because "no built-in page is up" is now an ordinary
    /// state and a caller that gets `.info` for it would refresh a page that is not on screen — or, with
    /// every page switched off, one that does not exist.
    var page: SidePanelPage? {
        guard case .builtin(let page) = tabs.tab(at: segmented.selectedSegment) else { return nil }
        return page
    }

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
        segmented.segmentStyle = .automatic
        segmented.trackingMode = .selectOne
        segmented.target = self
        segmented.action = #selector(tabChanged)
        segmented.translatesAutoresizingMaskIntoConstraints = false
        addSubview(segmented)
        registerForDraggedTypes([.pcPluginView])

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.alignment = .center
        emptyLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        emptyLabel.stringValue = String(localized: "No page is switched on for this side panel.")
        emptyLabel.isHidden = true
        addSubview(emptyLabel)

        // Info: a large preview on top, then name/kind, then details (all scrollable).
        previewHost.translatesAutoresizingMaskIntoConstraints = false
        previewArea.translatesAutoresizingMaskIntoConstraints = false
        previewHost.addSubview(previewArea)
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
        // Both are stored, because a hidden switcher has to stop taking up room: hidden views still take
        // part in Auto Layout, and the content areas below are pinned to `segmented.bottomAnchor`. Left
        // alone, an Info-only panel — the default — would open with a 30 pt band of nothing above the
        // preview. `switcherHeight` is only activated while the switcher is hidden.
        let top = segmented.topAnchor.constraint(equalTo: topAnchor, constant: 6)
        switcherTop = top
        switcherHeight = segmented.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            top,


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

            previewArea.topAnchor.constraint(equalTo: previewHost.topAnchor),
            previewArea.leadingAnchor.constraint(equalTo: previewHost.leadingAnchor),
            previewArea.trailingAnchor.constraint(equalTo: previewHost.trailingAnchor),
            previewArea.bottomAnchor.constraint(equalTo: previewHost.bottomAnchor),

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
        // Centred rather than pinned top-and-bottom in the loop above, which is where it first went.
        // The four areas up there are scroll views and a plain container — none has an intrinsic content
        // size, so pinning them to both edges says nothing about how tall the panel wants to be. An
        // NSTextField does have one, so pinning it the same way puts its height and its vertical hugging
        // into the chain that sizes the panel, for a label that is only ever shown on its own. Centring
        // keeps it out of that chain and is what the bottom dock does with its own empty-state label.
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        // A long translation must not be able to widen the panel or resist being narrowed either; the
        // panel's width is the user's to drag, and a collapsed panel is 0 pt wide.
        emptyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        emptyLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        emptyLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
        emptyLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        rebuildTabs()
    }

    // MARK: - Which tabs are on offer (F-476)

    /// Tell the panel which built-in pages are switched on.
    ///
    /// Called before the first paint and again whenever the setting changes. Idempotent: it costs a
    /// rebuild, and a rebuild keeps the selected tab, so calling it with the set that is already in
    /// force changes nothing on screen.
    func setVisibleBuiltins(_ pages: Set<SidePanelPage>) {
        guard pages != visibleBuiltins else { return }
        visibleBuiltins = pages
        rebuildTabs()
    }

    /// The single place the segmented control is filled in.
    ///
    /// Shared by `setVisibleBuiltins` and `setViewProviders` deliberately: they are the two things that
    /// can change the tab list, and two copies of this would eventually disagree about which tab stays
    /// selected — which is the whole class of bug this rewrite removes.
    private func rebuildTabs() {
        let previous = tabs.tab(at: segmented.selectedSegment)
        tabs = SidePanelTabList(visibleBuiltins: visibleBuiltins, pluginViewIds: providers.map(\.id))

        segmented.segmentCount = tabs.tabs.count
        for (i, tab) in tabs.tabs.enumerated() {
            switch tab {
            case .builtin(let page):
                segmented.setLabel(Self.title(for: page), forSegment: i)
            case .plugin(let id):
                segmented.setLabel(providers.first { $0.id == id }?.title ?? id, forSegment: i)
            }
        }

        // One tab needs no tab strip — the bottom dock's rule, and the reason the Info-only default
        // looks like a panel rather than a panel with a decoration on top.
        let showSwitcher = tabs.tabs.count > 1
        segmented.isHidden = !showSwitcher
        switcherTop?.constant = showSwitcher ? 6 : 0
        switcherHeight?.isActive = !showSwitcher

        if let selection = tabs.selection(keeping: previous), let index = tabs.index(of: selection) {
            segmented.selectedSegment = index
        }
        tabChanged()
    }

    /// Re-show the current file, for a setting that changes which renderer it gets (F-429).
    ///
    /// Deliberately *outside* the `#if DEBUG` block below, and it was inside it once: it reads like the
    /// automation diagnostics it was written next to, but its caller is `refreshOpenPreviews()`, which is
    /// ordinary behaviour and is not guarded. Debug compiled, Release did not, and CI only ever builds
    /// Debug — so the first build that saw it was the release DMG.
    func reloadPreview() { previewArea.reloadCurrent() }

    #if DEBUG
    /// Diagnostic: select the preview tab with this title (a built-in or a plugin view), as a click would.
    /// Returns the titles when there is no match, so a failing scenario says what *was* there (F-372).
    /// Diagnostic: the tab titles, so a sweep can visit every one without knowing what is installed.
    var automationTabTitles: [String] {
        (0..<segmented.segmentCount).map { segmented.label(forSegment: $0) ?? "" }
    }

    /// Diagnostic: which tab is showing, so a sweep can put it back.
    var automationSelectedTab: String { segmented.label(forSegment: segmented.selectedSegment) ?? "" }

    @discardableResult
    func automationSelectTab(titled title: String) -> String {
        let titles = (0..<segmented.segmentCount).map { segmented.label(forSegment: $0) ?? "" }
        guard let index = titles.firstIndex(of: title) else { return "no such tab; have: " + titles.joined(separator: ", ") }
        segmented.selectedSegment = index
        tabChanged()
        return "ok"
    }

    /// Diagnostic: which tabs the panel offers and which is showing (F-476).
    ///
    /// `sidebardump` cannot answer this — it walks text fields, and the tab strip is a segmented control
    /// — and whether the strip is there at all is half the feature.
    ///
    /// The two heights are here because one run of this panel photographed the whole window collapsed to
    /// 98 pt — file lists at zero height, every bar intact — while **Auto Layout logged nothing**: the
    /// layout was satisfiable and wrong, so the conflict count every other scenario leans on could not
    /// have caught it, and a screenshot was the only evidence. It has not reproduced since, in this
    /// panel's own configuration or in the reporter's, so what caused it is not yet known and these two
    /// numbers exist so that the next sighting is a measurement rather than an impression.
    /// `panelHeight` is this view's, `windowHeight` the window's content view's — a panel collapsed to
    /// its own content reads as a small number beside a large one, and a window merely dragged shorter
    /// moves both together.
    func automationTabReport() -> String {
        """
        switcher=\(segmented.isHidden ? "hidden" : "shown")
        tabs=\(automationTabTitles.joined(separator: ","))
        pages=\(tabs.builtinPages.map(\.rawValue).joined(separator: ","))
        selected=\(automationSelectedTab)
        panelHeight=\(Int(bounds.height))
        windowHeight=\(Int(window?.contentView?.bounds.height ?? 0))

        """
    }

    /// Diagnostic: the zoom controls of the preview area (F-389).
    @discardableResult
    func automationPressZoom(_ which: String) -> String { previewArea.automationPressZoom(which) }
    func automationZoomReport() -> String { previewArea.automationZoomReport() }
    #endif

    /// Show whatever the selected segment names.
    ///
    /// Asks the tab list what is at that index rather than comparing the index to 0, 1 and 2. That
    /// arithmetic is what made switching a page off show the wrong content under the right label, and
    /// there is no longer anywhere in this file that counts built-ins.
    @objc private func tabChanged() {
        let tab = tabs.tab(at: segmented.selectedSegment)
        var page: SidePanelPage?
        var pluginId: String?
        switch tab {
        case .builtin(let p): page = p
        case .plugin(let id): pluginId = id
        case nil: break             // no tab at all: every page off and no plugin mounted
        }
        infoScroll.isHidden = page != .info
        activitiesScroll.isHidden = page != .activities
        logScroll.isHidden = page != .log
        pluginContainer.isHidden = pluginId == nil
        emptyLabel.isHidden = tab != nil
        if let pluginId {
            showPluginView(id: pluginId)
        } else if let page {
            onPageChange?(page)
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
    /// panel to a different view. That is `rebuildTabs`'s job now, and it keeps a *built-in* page
    /// selected across a plugin arriving or leaving for the same reason.
    func setViewProviders(_ providers: [PreviewViewProvider]) {
        let keep = Set(providers.map(\.id))
        for (id, view) in mountedViews where !keep.contains(id) {
            // Only if the view is still ours — see BottomDockView.setViewProviders. The container that
            // adopted it may have been told first, and taking the view out of its new home leaves that
            // container showing nothing (F-388).
            if view.superview === pluginContainer { view.removeFromSuperview() }
            mountedViews[id] = nil
        }
        self.providers = providers
        rebuildTabs()
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

    /// Dropping a plugin view here moves it here (F-381).
    private let dropTarget = ViewDropTarget(container: "sidebar")

    /// Set by the window controller; called with the id of a view dropped on this panel.
    var onViewDropped: ((String) -> Void)? {
        didSet { dropTarget.onDrop = onViewDropped }
    }

    #if DEBUG
    /// Diagnostic: the drop path, without a drag (F-381). A drag cannot be scripted.
    @discardableResult
    func dropViewForAutomation(id: String) -> Bool { dropTarget.perform(viewId: id) }
    #endif

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard dropTarget.accepts(sender) else { return [] }
        dropTarget.setHighlighted(true, in: self)
        return .move
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { dropTarget.setHighlighted(false, in: self) }
    override func draggingEnded(_ sender: NSDraggingInfo) { dropTarget.setHighlighted(false, in: self) }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropTarget.setHighlighted(false, in: self)
        return dropTarget.perform(sender)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        dropTarget.drawHighlight(in: self)
    }

    private func installPlacementMenu() {
        // Dragging carries whatever plugin view is showing; a built-in mode is not movable and
        // returning nil there leaves the segmented control behaving as a plain control.
        segmented.draggableViewId = { [weak self] in self?.selectedPluginViewId }
        segmented.dragImageProvider = { [weak self] in
            guard let self, let id = self.selectedPluginViewId,
                  let title = self.providers.first(where: { $0.id == id })?.title else { return nil }
            return Self.dragImage(for: title)
        }
        // The right-click menu now always has something to say. It used to return nil on a built-in
        // segment — there was nothing to move — but which pages the panel offers is decided here too
        // (F-476), and that is the answer somebody right-clicking the tab strip is most likely after.
        // Placement first when a plugin view is showing, because it concerns the tab under the pointer.
        segmented.contextMenuProvider = { [weak self] in
            guard let self else { return nil }
            // The placement menu when there is a plugin view to move, extended rather than copied:
            // `ViewPlacementMenu.menu` builds a fresh one per click, and an NSMenuItem already owned by
            // a menu cannot be added to a second one.
            var placement: NSMenu?
            if let provider = self.placementMenuProvider, let id = self.selectedPluginViewId,
               let view = self.providers.first(where: { $0.id == id }) {
                placement = provider(id, view.title)
                placement?.addItem(.separator())
            }
            let menu = placement ?? NSMenu()
            for page in SidePanelPage.allCases {
                let item = NSMenuItem(title: Self.title(for: page),
                                      action: #selector(self.togglePageFromMenu(_:)), keyEquivalent: "")
                item.target = self
                item.state = self.visibleBuiltins.contains(page) ? .on : .off
                item.representedObject = page.rawValue
                menu.addItem(item)
            }
            return menu
        }
    }

    /// Carry out a tick in the switcher's context menu (F-476).
    ///
    /// Reports the page rather than acting on it: the owner writes the setting and hands the new set
    /// back through `setVisibleBuiltins`, so the menu and the Settings checkbox travel the same path.
    @objc private func togglePageFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let page = SidePanelPage(rawValue: raw) else { return }
        onTogglePage?(page)
    }

    /// A small label to carry under the pointer while dragging a view somewhere else.
    ///
    /// Without one the drag has no picture at all, and a gesture that shows nothing reads as a gesture
    /// that is not working.
    static func dragImage(for title: String) -> NSImage {
        let text = title as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor,
        ]
        let textSize = text.size(withAttributes: attributes)
        let size = NSSize(width: textSize.width + 16, height: textSize.height + 8)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.controlBackgroundColor.withAlphaComponent(0.9).setFill()
        let box = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 4, yRadius: 4)
        box.fill()
        NSColor.separatorColor.setStroke()
        box.stroke()
        text.draw(at: NSPoint(x: 8, y: 4), withAttributes: attributes)
        image.unlockFocus()
        return image
    }

    /// The plugin view currently selected, or nil when a built-in page or the empty state is showing.
    var selectedPluginViewId: String? {
        guard case .plugin(let id) = tabs.tab(at: segmented.selectedSegment) else { return nil }
        return id
    }

    /// Select the plugin segment for `id` (no-op if it isn't currently provided).
    func selectPluginView(id: String) {
        guard let index = tabs.index(of: .plugin(id)) else { return }
        segmented.selectedSegment = index
        tabChanged()
    }

    private func showPluginView(id: String) {
        guard let provider = providers.first(where: { $0.id == id }) else { return }
        for v in mountedViews.values { v.isHidden = true }
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
        // Same reason as the bottom dock: a view mounted after the window became key is invisible to
        // AppKit's own loop calculation, so everything the plugin puts here would be unreachable by
        // Tab. Cheap, and it has to happen on every switch — a second plugin's controls are as new to
        // the loop as the first one's were.
        KeyboardLoop.rebuild(for: window)
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

    /// Swap only the preview, leaving the name and details as they are.
    ///
    /// For the two-step case (F-479): the details come from the listing at once, and the picture
    /// arrives when the member has been unpacked.
    func setPreviewFile(_ path: String?, fallbackIcon: NSImage?) {
        previewArea.show(path: path, fallbackIcon: fallbackIcon)
    }

    /// Hand the item to the preview area, which decides how to draw it.
    private func setPreview(path: String?, fallbackIcon: NSImage?) {
        previewArea.show(path: path, fallbackIcon: fallbackIcon)
    }

    /// The same page, with the file's details but no preview: reading it would cost more than a
    /// cursor movement is allowed to (F-479). The metadata still comes from the listing, so the page
    /// answers "what is this file" even when it declines to draw it.
    func setInfo(path: String?, title: String, subtitle: String, details: [(String, String)],
                 deferredKey: String, deferredMessage: String, fallbackIcon: NSImage?) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        infoLabel.stringValue = ""
        detailStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (key, value) in details { detailStack.addArrangedSubview(Self.detailRow(key, value)) }
        previewArea.showDeferred(key: deferredKey, message: deferredMessage, fallbackIcon: fallbackIcon)
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
        previewArea.applyTheme()
        infoLabel.textColor = Theme.current.listText
        titleLabel.textColor = Theme.current.listText
        activitiesText.textColor = Theme.current.listText
        logText.textColor = Theme.current.listText
        emptyLabel.textColor = Theme.current.statusBarText
    }
}
