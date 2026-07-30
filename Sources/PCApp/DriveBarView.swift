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

    private var volumes: [Volume] = []
    private var currentIndex: Int?
    private let font = NSFont.systemFont(ofSize: 11)

    private enum Chip { case go; case drives; case volume(Int) }
    /// Hit rectangles computed during draw(), consulted by mouseDown.
    private var chipHits: [(rect: NSRect, chip: Chip)] = []

    private let edgeInset: CGFloat = 4
    private let spacing: CGFloat = 3
    private let chipHeight: CGFloat = 18
    private let textPad: CGFloat = 7

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
        needsDisplay = true
    }

    /// Highlight the volume at `index` (others normal).
    func setCurrentIndex(_ index: Int?) {
        guard index != currentIndex else { return }
        currentIndex = index
        needsDisplay = true
    }

    private func label(for volume: Volume) -> String {
        let icon: String
        if !volume.icon.isEmpty { icon = volume.icon + " " }  // plugin-defined chip icon
        else if volume.path == "/" { icon = "🖥 " }           // boot drive
        else { icon = "💾 " }                                 // other local/removable volume
        return icon + volume.name
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        Theme.current.statusBarBackground.setFill()
        bounds.fill()

        chipHits.removeAll()
        var x = edgeInset
        chipHits.append((drawChip("★", at: &x, highlighted: false), .go))
        // Drive dropdown (F-006): lists ALL volumes, so drives whose chips overflow
        // the bar's width are still reachable.
        chipHits.append((drawChip("▾", at: &x, highlighted: false), .drives))
        for (i, volume) in volumes.enumerated() {
            guard x < bounds.width else { break }
            chipHits.append((drawChip(label(for: volume), at: &x, highlighted: i == currentIndex), .volume(i)))
        }
    }

    /// Draw one chip starting at `x`, advance `x` past it, and return its rect.
    private func drawChip(_ text: String, at x: inout CGFloat, highlighted: Bool) -> NSRect {
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let rect = NSRect(x: x, y: (bounds.height - chipHeight) / 2,
                          width: textSize.width + textPad * 2, height: chipHeight)
        (highlighted ? NSColor.controlAccentColor : NSColor.controlColor).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        (text as NSString).draw(
            at: NSPoint(x: rect.minX + textPad, y: rect.midY - textSize.height / 2),
            withAttributes: [.font: font,
                             .foregroundColor: highlighted ? NSColor.white : NSColor.labelColor])
        x = rect.maxX + spacing
        return rect
    }

    // MARK: - Interaction

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let hit = chipHits.first(where: { $0.rect.contains(point) }) else { return }
        switch hit.chip {
        case .go: showGoMenu(at: hit.rect)
        case .drives: showDrivesMenu(at: hit.rect)
        case .volume(let i): if volumes.indices.contains(i) { onSelect?(volumes[i].path) }
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
            let item = NSMenuItem(title: label(for: volume), action: #selector(driveMenuItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = volume.path
            item.state = (i == currentIndex) ? .on : .off
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
