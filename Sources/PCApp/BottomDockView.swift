// SPDX-License-Identifier: Apache-2.0
// BottomDockView.swift - A plugin-view container across the bottom of the window (F-381).
//
// `ViewContainerRegistry` says a plugin "can embed a view at nearly any visual seam", and
// `ContributionModel` has documented the container name "bottombar" since the ABI was written. Nothing
// was ever mounted there, so the promise was untested. This is that seam.
//
// It exists because of a measurement rather than a preference. The sidebar is 300 pt wide by default
// and 180 pt at its minimum, and a monospaced cell is 6.80 pt at 11 pt / 7.42 pt at 12 pt — so the
// sidebar offers 44 columns, 26 at its narrowest, while the same font across a 1200 pt window offers
// 176. Anything that wants *width* — a terminal, a build log, a REPL — cannot live in the sidebar at
// any font size, and the bottom of the window has the room to spare.
//
// The dock is deliberately generic: it knows about `PreviewViewProvider` and nothing else. Remove
// every plugin and it has nothing to show and stays shut; that is what keeps the terminal plugin
// removable rather than half-welded into the window.
//
// Two behaviours are worth stating because they are the ones that would otherwise be guessed wrong:
//
//   * **A mounted view is built once and kept.** Switching between two docked plugins hides one and
//     shows the other; it does not close and rebuild them. A terminal whose view is rebuilt is a
//     terminal whose `top` restarted.
//   * **Open with nothing to show says so.** An empty frame reads as a broken dock; a sentence
//     explains that no plugin offers a view here, which is a state the user can act on.

import AppKit
import PCFoundation

final class BottomDockView: NSView {

    /// Height of the header strip: the provider switcher and the close button.
    static let headerHeight: CGFloat = 24
    /// Default height of the whole dock when it is first opened.
    static let defaultHeight: CGFloat = 220
    /// Below this the content area is too short to be worth showing.
    static let minHeight: CGFloat = 80

    /// Fired when the user presses the dock's close button.
    var onClose: (() -> Void)?
    /// Fired when the visible provider changes, so the owner can persist the choice.
    var onSelectionChange: ((String) -> Void)?

    private let switcher = PlacementSegmentedControl(labels: [], trackingMode: .selectOne,
                                                    target: nil, action: nil)
    private let placementButton = NSButton(title: "", target: nil, action: nil)
    private let closeButton = NSButton(title: "", target: nil, action: nil)
    private let content = NSView()
    private let emptyLabel = NSTextField(labelWithString: "")

    /// Dropping a plugin view here moves it here (F-381).
    private let dropTarget = ViewDropTarget(container: "bottom")

    /// Set by the window controller; called with the id of a view dropped on this area.
    var onViewDropped: ((String) -> Void)? {
        didSet { dropTarget.onDrop = onViewDropped }
    }

    #if DEBUG
    /// Diagnostic: the drop path, without a drag (F-381). A drag cannot be scripted.
    @discardableResult
    func dropViewForAutomation(id: String) -> Bool { dropTarget.perform(viewId: id) }
    #endif

    private var providers: [PreviewViewProvider] = []
    /// Views already built, by provider id. Kept across selection changes — see the header.
    private var mountedViews: [String: NSView] = [:]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true   // nothing spills out while the dock is collapsed
        isHidden = true               // shut until toggled on
        setup()
        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        switcher.translatesAutoresizingMaskIntoConstraints = false
        switcher.controlSize = .small
        switcher.segmentDistribution = .fit
        switcher.target = self
        switcher.action = #selector(switcherChanged)
        switcher.setAccessibilityLabel(String(localized: "Docked view"))
        switcher.contextMenuProvider = { [weak self] in self?.placementMenu() }
        switcher.draggableViewId = { [weak self] in self?.selectedProviderId }
        switcher.dragImageProvider = { [weak self] in
            guard let self, let id = self.selectedProviderId,
                  let title = self.providers.first(where: { $0.id == id })?.title else { return nil }
            return PreviewPanelView.dragImage(for: title)
        }
        addSubview(switcher)
        registerForDraggedTypes([.pcPluginView])

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .accessoryBarAction
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark",
                                    accessibilityDescription: String(localized: "Close the dock"))
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        closeButton.toolTip = String(localized: "Close the dock")
        addSubview(closeButton)

        // The same menu the right-click offers, as a button. The dock has room for it and the sidebar
        // does not, and a gesture nobody sees is a gesture nobody uses.
        placementButton.translatesAutoresizingMaskIntoConstraints = false
        placementButton.bezelStyle = .accessoryBarAction
        placementButton.isBordered = false
        placementButton.image = NSImage(systemSymbolName: "ellipsis",
                                        accessibilityDescription: String(localized: "Move this view"))
        placementButton.target = self
        placementButton.action = #selector(placementPressed)
        placementButton.toolTip = String(localized: "Move this view")
        addSubview(placementButton)

        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.alignment = .center
        emptyLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        emptyLabel.stringValue = String(localized: "No plugin provides a view here.")
        content.addSubview(emptyLabel)

        // The header inset is one point below required, and that is not a detail. A closed dock is
        // zero points tall, and "the content starts 24 points down" and "the content reaches the
        // bottom edge" cannot both hold in zero points — AppKit logs the unsatisfiable set and drops
        // one of them of its own accord. Saying which one may go makes it deterministic: at every
        // height the dock is actually used at, nothing competes with this and it is satisfied exactly.
        let contentTop = content.topAnchor.constraint(equalTo: topAnchor, constant: Self.headerHeight)
        contentTop.priority = .required - 1

        NSLayoutConstraint.activate([
            switcher.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            switcher.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            switcher.heightAnchor.constraint(equalToConstant: Self.headerHeight - 6),
            switcher.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor,
                                               constant: -6),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            closeButton.centerYAnchor.constraint(equalTo: switcher.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            placementButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),
            placementButton.centerYAnchor.constraint(equalTo: switcher.centerYAnchor),
            placementButton.widthAnchor.constraint(equalToConstant: 18),
            contentTop,
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: content.centerYAnchor),
        ])
    }

    // MARK: - Plugin view providers (contribution container "bottom")

    /// The id of the provider currently on screen, or nil when the dock is empty.
    var selectedProviderId: String? {
        let index = switcher.selectedSegment
        return providers.indices.contains(index) ? providers[index].id : nil
    }

    /// Every provider currently offered here, in contribution order.
    var providerIds: [String] { providers.map(\.id) }

    /// Replace the docked plugin views.
    ///
    /// Providers that were already here keep the view they had: the registry hands out a fresh
    /// `PreviewViewProvider` on every refresh even when the underlying contribution has not changed,
    /// and rebuilding a view because its wrapper object is new would restart whatever runs in it.
    ///
    /// A view that has gone from the list is *dropped*, not closed. It may have moved to another
    /// container — that is what the placement work is for — and closing it there would destroy it on
    /// arrival. The registry owns a mount's lifetime and has already closed the ones that really went.
    func setViewProviders(_ providers: [PreviewViewProvider]) {
        let keep = Set(providers.map(\.id))
        for (id, view) in mountedViews where !keep.contains(id) {
            view.removeFromSuperview()
            mountedViews[id] = nil
        }

        let previous = selectedProviderId
        self.providers = providers

        switcher.segmentCount = providers.count
        for (i, p) in providers.enumerated() { switcher.setLabel(p.title, forSegment: i) }
        // Only worth showing when there is a choice to make.
        switcher.isHidden = providers.count < 2
        placementButton.isHidden = providers.isEmpty

        if let previous, let index = providers.firstIndex(where: { $0.id == previous }) {
            switcher.selectedSegment = index
        } else if !providers.isEmpty {
            switcher.selectedSegment = 0
        }
        showSelected()
    }

    /// Bring a particular provider to the front (no-op if it is not docked here).
    @discardableResult
    func selectProvider(id: String) -> Bool {
        guard let index = providers.firstIndex(where: { $0.id == id }) else { return false }
        // Already showing: do nothing at all, rather than the same thing again. `showSelected` hides
        // every other mounted view before unhiding this one, and hiding a view that contains the
        // first responder makes the window drop it — so a redundant call cost the focus toggle its
        // memory of where the keyboard was, and "go back to the panel" turned into "stay here".
        guard switcher.selectedSegment != index else { return true }
        switcher.selectedSegment = index
        showSelected()
        return true
    }

    /// The view currently on screen, for the owner to make first responder.
    var visibleContentView: NSView? {
        guard let id = selectedProviderId else { return nil }
        return mountedViews[id]
    }

    @objc private func switcherChanged() {
        showSelected()
        if let id = selectedProviderId { onSelectionChange?(id) }
    }

    @objc private func closePressed() { onClose?() }

    /// Ask for the placement menu for whatever is showing, and put it under the button.
    @objc private func placementPressed() {
        guard let menu = placementMenu() else { return }
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: placementButton.bounds.height), in: placementButton)
    }

    /// Builds the menu for the view on screen; see ViewPlacementMenu for why it is not held.
    var placementMenuProvider: ((_ viewId: String, _ title: String) -> NSMenu?)?

    private func placementMenu() -> NSMenu? {
        guard let provider = placementMenuProvider, let id = selectedProviderId,
              let p = providers.first(where: { $0.id == id }) else { return nil }
        return provider(id, p.title)
    }

    /// Show the selected provider's view, building it on first use.
    private func showSelected() {
        for v in mountedViews.values { v.isHidden = true }
        guard let id = selectedProviderId,
              let provider = providers.first(where: { $0.id == id }) else {
            emptyLabel.isHidden = false
            return
        }
        emptyLabel.isHidden = true

        let view: NSView
        if let existing = mountedViews[id] {
            view = existing
        } else if let made = provider.makeView() {
            made.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(made)
            NSLayoutConstraint.activate([
                made.topAnchor.constraint(equalTo: content.topAnchor),
                made.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                made.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                made.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            ])
            mountedViews[id] = made
            view = made
        } else {
            // The plugin refused to build a view. Say so rather than show a blank strip.
            emptyLabel.isHidden = false
            emptyLabel.stringValue = String(localized: "This view could not be opened.")
            return
        }
        view.isHidden = false
    }

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

    func applyTheme() {
        let theme = Theme.current
        layer?.backgroundColor = theme.windowBackground.cgColor
        emptyLabel.textColor = theme.statusBarText
        closeButton.contentTintColor = theme.statusBarText
        placementButton.contentTintColor = theme.statusBarText
    }
}
