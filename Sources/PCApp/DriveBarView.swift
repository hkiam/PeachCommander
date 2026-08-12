// SPDX-License-Identifier: Apache-2.0
// DriveBarView.swift - Per-panel row of drive/volume buttons (TODOS #9).
//
// A horizontal strip of drive "chips" above each panel's path bar: a "★" chip
// (special dirs + favorites menu) followed by one chip per mounted volume.
// Clicking a volume chip navigates the panel to that volume's root; the chip for
// the volume owning the current directory is highlighted. Which volumes appear and
// which is current is decided by DriveBarModel (tested); this view just renders.
//
// Fully custom-drawn (draw() + mouseDown hit-testing) with NO NSStackView/NSButton
// subviews — an earlier NSStackView-based version never composited to screen inside
// the layer-backed split-view panel (TODOS #179), whereas the app's other custom
// bars (path/status) draw reliably.

import AppKit
import PCVFS

final class DriveBarView: NSView {
    /// Called with the chosen volume's mount path.
    var onSelect: ((String) -> Void)?
    /// Called with a special-directory / favorite path chosen from the Go menu.
    var onGoTo: ((String) -> Void)?
    /// Called to open the favorites (directory hotlist) manager.
    var onManageFavorites: (() -> Void)?
    /// Supplies the current favorites (hotlist) to list inline in the Go menu.
    var favoritesProvider: (() -> [(title: String, path: String)])?
    /// Called with the volume whose chip was right-clicked and whose Eject was chosen (F-385).
    var onEject: ((Volume) -> Void)?

    private var volumes: [Volume] = []
    private var currentIndex: Int?
    private let font = NSFont.systemFont(ofSize: 11)
    /// Each volume's own icon, keyed by mount path — the system's, so a share, a stick and a mounted
    /// image look here the way they look in Finder. Filled off the main thread by `loadIcons`.
    private var icons: [String: NSImage] = [:]
    private let iconQueue = DispatchQueue(label: "com.peachcommander.drivebar.icons", qos: .userInitiated)
    /// Square, and a little smaller than the chip so it does not touch its rounded edge.
    private static let iconSize: CGFloat = 13
    private let iconGap: CGFloat = 4

    private enum Chip: Sendable { case go; case drives; case volume(Int); case eject(Int) }
    /// Hit rectangles computed during draw(), consulted by mouseDown — in the order they must be
    /// consulted, which `DriveBarHit` resolves and `DriveBarHitTests` pins.
    private var chipHits: [DriveBarHit.Region<Chip>] = []

    private let edgeInset: CGFloat = 4
    private let spacing: CGFloat = 3
    private let chipHeight: CGFloat = 18
    private let textPad: CGFloat = 7
    /// The eject glyph drawn inside an ejectable volume's chip (F-385). U+23CF, drawn as text like
    /// everything else here — the bar builds no controls, so a button would be the odd one out.
    private let ejectGlyph = "⏏"
    /// Room the glyph takes at the chip's trailing edge, plus the gap before it.
    private let ejectPad: CGFloat = 6

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func applyTheme() { needsDisplay = true }

    // MARK: - Data

    /// Replace the volume set (already display-ordered by DriveBarModel).
    func setVolumes(_ vols: [Volume]) {
        guard vols.map(\.id) != volumes.map(\.id) else { return }   // avoid churn
        volumes = vols
        loadIcons(for: vols)
        needsDisplay = true
    }

    /// Fetch each volume's own icon — the one Finder shows, which is what tells a share from a stick
    /// from a mounted disk image. Off the main thread and never from `draw`: reading an icon touches
    /// the disk, and for a network share that can mean waiting on the server.
    private func loadIcons(for vols: [Volume]) {
        let paths = vols.filter { $0.icon.isEmpty && VolumeKind.of($0).hasSystemIcon }.map(\.path)
        let wanted = paths.filter { icons[$0] == nil }
        guard !wanted.isEmpty else { return }
        iconQueue.async { [weak self] in
            let loaded = Self.readIcons(wanted)
            DispatchQueue.main.async {
                guard let self else { return }
                for (path, image) in loaded { self.icons[path] = image }
                self.needsDisplay = true
            }
        }
    }

    private nonisolated static func readIcons(_ paths: [String]) -> [(String, NSImage)] {
        paths.map { path in
            let image = NSWorkspace.shared.icon(forFile: path)
            image.size = NSSize(width: iconSize, height: iconSize)
            return (path, image)
        }
    }

    /// The chip's text. A real volume's kind is carried by its icon, so the name stands alone; a
    /// plugin's own emoji is text, and so is the kind glyph that stands in until an icon arrives (or
    /// for good, if the system has none to give).
    private func chipText(for volume: Volume) -> String {
        if !volume.icon.isEmpty { return volume.icon + " " + volume.name }
        if icons[volume.path] != nil { return volume.name }
        return VolumeKind.of(volume).glyph + " " + volume.name
    }

    /// Which volume is drawn highlighted (nil = none) — read by the automation report, since the
    /// highlight is drawn rather than a control's state and nothing else can observe it.
    var highlightedIndex: Int? { currentIndex }

    /// What each chip is showing: its name, the kind it was classified as, and where its picture
    /// came from. For the automation report — the chips are painted, and "the icons tell the kinds
    /// apart" is otherwise a claim only a human looking at the screen can check.
    var chipsForAutomation: String {
        volumes.map { v in
            let art = !v.icon.isEmpty ? "plugin" : (icons[v.path] != nil ? "system" : "glyph")
            return "\(v.name):\(VolumeKind.of(v).rawValue):\(art)"
        }.joined(separator: "|")
    }

    /// Highlight the volume at `index` (others normal).
    func setCurrentIndex(_ index: Int?) {
        guard index != currentIndex else { return }
        currentIndex = index
        needsDisplay = true
    }

    /// What a screen reader is told the volume is. The icon says it to everyone else, and an icon
    /// says nothing at all here — the chips are painted, so without this the kind would be
    /// information only sighted users get.
    private func kindName(for volume: Volume) -> String {
        switch VolumeKind.of(volume) {
        case .startupDisk: return String(localized: "Startup disk", comment: "Drive bar: volume kind")
        case .internalDisk: return String(localized: "Internal volume", comment: "Drive bar: volume kind")
        case .externalDisk: return String(localized: "External volume", comment: "Drive bar: volume kind")
        case .networkShare: return String(localized: "Network share", comment: "Drive bar: volume kind")
        case .cloudFolder: return String(localized: "Cloud folder", comment: "Drive bar: volume kind")
        case .pluginDrive: return String(localized: "Plugin drive", comment: "Drive bar: volume kind")
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        Theme.current.statusBarBackground.setFill()
        bounds.fill()

        chipHits.removeAll()
        var x = edgeInset
        chipHits.append(.init(rect: drawChip("★", at: &x, highlighted: false).chip, payload: .go))
        // Drive dropdown (F-006): lists ALL volumes, so drives whose chips overflow
        // the bar's width are still reachable.
        chipHits.append(.init(rect: drawChip("▾", at: &x, highlighted: false).chip, payload: .drives))
        for (i, volume) in volumes.enumerated() {
            guard x < bounds.width else { break }
            // The glyph is only drawn where it would work. Which volumes those are is
            // VolumeEjection's to say — the same call the context menu and the command make, so a
            // chip never offers an eject that would then be refused.
            let ejectable = VolumeEjection.refusal(for: volume) == nil
            let (chip, eject) = drawChip(chipText(for: volume), at: &x,
                                         highlighted: i == currentIndex, ejectable: ejectable,
                                         icon: icons[volume.path])
            // Before the chip, not after: `mouseDown` takes the first hit whose rect contains the
            // point, and the glyph's rect lies inside the chip's. Appended the other way round the
            // chip always wins and the glyph is decoration.
            if let eject { chipHits.append(.init(rect: eject, payload: .eject(i))) }
            chipHits.append(.init(rect: chip, payload: .volume(i)))
        }
    }

    /// Draw one chip starting at `x`, advance `x` past it, and return its rect — plus the eject
    /// glyph's own rect when one was drawn. `icon` is the volume's own image, drawn ahead of the
    /// text; without one the text carries its kind glyph instead and nothing is reserved.
    @discardableResult
    private func drawChip(_ text: String, at x: inout CGFloat, highlighted: Bool,
                          ejectable: Bool = false,
                          icon: NSImage? = nil) -> (chip: NSRect, eject: NSRect?) {
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let glyphSize = ejectable ? (ejectGlyph as NSString).size(withAttributes: [.font: font])
                                  : .zero
        let extra = ejectable ? glyphSize.width + ejectPad : 0
        let iconRoom = icon == nil ? 0 : Self.iconSize + iconGap
        let rect = NSRect(x: x, y: (bounds.height - chipHeight) / 2,
                          width: iconRoom + textSize.width + textPad * 2 + extra, height: chipHeight)
        let foreground = highlighted ? Theme.current.driveBarHighlightText : Theme.current.driveBarText
        (highlighted ? Theme.current.driveBarHighlight : Theme.current.driveBarBackground).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        if let icon {
            icon.draw(in: NSRect(x: rect.minX + textPad, y: rect.midY - Self.iconSize / 2,
                                 width: Self.iconSize, height: Self.iconSize))
        }
        (text as NSString).draw(
            at: NSPoint(x: rect.minX + textPad + iconRoom, y: rect.midY - textSize.height / 2),
            withAttributes: [.font: font, .foregroundColor: foreground])

        var ejectRect: NSRect?
        if ejectable {
            let origin = NSPoint(x: rect.maxX - textPad - glyphSize.width,
                                 y: rect.midY - glyphSize.height / 2)
            (ejectGlyph as NSString).draw(at: origin,
                                          withAttributes: [.font: font, .foregroundColor: foreground])
            // Taller and wider than the glyph itself: a 7pt symbol is not a click target, and the
            // whole chip height is available anyway.
            ejectRect = NSRect(x: origin.x - ejectPad / 2, y: rect.minY,
                               width: glyphSize.width + ejectPad, height: rect.height)
        }
        x = rect.maxX + spacing
        return (rect, ejectRect)
    }

    // MARK: - Interaction

    // MARK: - Accessibility (I19 T06)

    /// The bar is a group; the chips are its children.
    ///
    /// Without this the whole bar is one opaque rectangle to VoiceOver and every volume in it is
    /// unreachable — the chips are drawn, not built from controls. `chipHits` already holds what is
    /// needed, because hit-testing clicks and describing controls want the same information.
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { String(localized: "Drive bar") }

    override func accessibilityChildren() -> [Any]? {
        chipHits.map { hit in
            switch hit.payload {
            case .go:
                return AccessibleHotspot(label: String(localized: "Favorites"), role: .button,
                                         frameInView: hit.rect, parent: self) { [weak self] in
                    self?.showGoMenu(at: hit.rect)
                }
            case .drives:
                return AccessibleHotspot(label: String(localized: "All volumes"), role: .button,
                                         frameInView: hit.rect, parent: self) { [weak self] in
                    self?.showDrivesMenu(at: hit.rect)
                }
            case .volume(let i):
                // Name, kind *and* free space: the chip shows all three — the kind as its icon — so
                // announcing only the name would tell a screen-reader user less than the screen
                // tells everyone else, and the kind is precisely what the icon was added to say.
                let volume = volumes.indices.contains(i) ? volumes[i] : nil
                let label = volume.map { v in
                    "\(v.name), \(kindName(for: v)), " + String(
                        format: String(localized: "%@ free"),
                        ByteCountFormatter.string(fromByteCount: v.freeSpace, countStyle: .file))
                } ?? String(localized: "Volume")
                return AccessibleHotspot(label: label, role: .button,
                                         frameInView: hit.rect, parent: self) { [weak self] in
                    guard let self, self.volumes.indices.contains(i) else { return }
                    self.onSelect?(self.volumes[i].path)
                }
            case .eject(let i):
                let name = volumes.indices.contains(i) ? volumes[i].name : ""
                return AccessibleHotspot(label: String(format: String(localized: "Eject %@"), name),
                                         role: .button,
                                         frameInView: hit.rect, parent: self) { [weak self] in
                    guard let self, self.volumes.indices.contains(i) else { return }
                    self.onEject?(self.volumes[i])
                }
            }
        }
    }

    /// Right-click (and Control-click, which AppKit routes here as well) on a volume chip.
    ///
    /// Until now the bar answered only to a left click, so the one place a user actually looks for
    /// "eject this" — the drive it is sitting on — was the one place that offered nothing. The
    /// command existed and acted on the *panel cursor* instead, which is a different question.
    ///
    /// Eject is shown for every volume and disabled for the ones that cannot go, rather than hidden:
    /// a menu that appears empty over the startup disk reads as broken, while a greyed-out entry
    /// teaches the rule at a glance. Which volumes those are is `VolumeEjection`'s to say, not this
    /// view's — asking separately here is how an Eject that is offered and then refuses comes about.
    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        guard let hit = DriveBarHit.region(at: point, in: chipHits) else { return nil }
        let index: Int
        switch hit.payload {
        case .volume(let i), .eject(let i): index = i
        default: return nil
        }
        guard volumes.indices.contains(index) else { return nil }
        let volume = volumes[index]

        let menu = NSMenu()
        let item = NSMenuItem(title: String(localized: "Eject"), action: #selector(ejectMenuItem(_:)),
                              keyEquivalent: "")
        item.target = self
        item.representedObject = index
        switch VolumeEjection.refusal(for: volume) {
        case .none:
            item.isEnabled = true
        case .some(.bootVolume):
            item.isEnabled = false
            item.toolTip = String(localized: "The startup disk cannot be ejected.")
        case .some:
            item.isEnabled = false
            item.toolTip = String(localized: "Network shares and internal disks stay mounted.")
        }
        menu.addItem(item)
        // Off, or the enabled state above is recomputed by the responder chain and every item goes
        // grey — nothing here has a validating target.
        menu.autoenablesItems = false
        return menu
    }

    @objc private func ejectMenuItem(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int, volumes.indices.contains(index) else { return }
        onEject?(volumes[index])
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let hit = DriveBarHit.region(at: point, in: chipHits) else { return }
        switch hit.payload {
        case .go: showGoMenu(at: hit.rect)
        case .drives: showDrivesMenu(at: hit.rect)
        case .volume(let i): if volumes.indices.contains(i) { onSelect?(volumes[i].path) }
        case .eject(let i): if volumes.indices.contains(i) { onEject?(volumes[i]) }
        }
    }

    /// Dropdown of every volume (drive combo, F-006) — the current one checkmarked.
    private func showDrivesMenu(at rect: NSRect) {
        let menu = NSMenu()
        if volumes.isEmpty {
            let item = NSMenuItem(title: String(localized: "No volumes"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        for (i, volume) in volumes.enumerated() {
            let item = NSMenuItem(title: chipText(for: volume), action: #selector(driveMenuItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = volume.path
            item.state = (i == currentIndex) ? .on : .off
            // The same icon the chip draws: this menu exists for the volumes whose chips do not fit,
            // and they should not become unrecognisable by being listed instead of drawn.
            item.image = icons[volume.path]
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: rect.minX, y: rect.minY), in: self)
    }

    @objc private func driveMenuItem(_ sender: NSMenuItem) {
        if let path = sender.representedObject as? String { onSelect?(path) }
    }

    private func showGoMenu(at rect: NSRect) {
        let menu = NSMenu()
        for dir in SpecialDirectories.all() {
            let item = NSMenuItem(title: dir.name, action: #selector(goToItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = dir.path
            menu.addItem(item)
        }
        let favorites = favoritesProvider?() ?? []
        if !favorites.isEmpty {
            menu.addItem(.separator())
            let header = NSMenuItem(title: String(localized: "Favorites"), action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for fav in favorites {
                let item = NSMenuItem(title: fav.title, action: #selector(goToItem(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = fav.path
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        let manage = NSMenuItem(title: String(localized: "Directory Hotlist…"),
                                action: #selector(manageFavorites), keyEquivalent: "")
        manage.target = self
        menu.addItem(manage)
        menu.popUp(positioning: nil, at: NSPoint(x: rect.minX, y: rect.minY), in: self)
    }

    @objc private func goToItem(_ sender: NSMenuItem) {
        if let path = sender.representedObject as? String { onGoTo?(path) }
    }

    @objc private func manageFavorites() { onManageFavorites?() }
}
