// SPDX-License-Identifier: Apache-2.0
// treemap.swift — "Disk Map" on-demand disk-usage explorer plugin.
//
// The user starts an analysis via the Commands menu (plugin.treemap.analyze) on the
// active panel's folder/volume. The plugin presents its sidebar view, which scans the
// root off the main thread with the fast getattrlistbulk engine (see ScanEngine.swift),
// then draws either a squarified treemap or a DaisyDisk-style sunburst of the current
// level (see Renderers.swift). A volume bar reconciles what was scanned against the
// disk's Used / Free / Purgeable / Hidden space. Clicking a folder drills in; a Back
// button / breadcrumb goes up. Items can be marked into a Collector and trashed in one
// go, or acted on individually via the context menu. The plugin also contributes a
// Settings pane (see TreemapConfig.swift). Talks to the host only via PcHostServices.

import AppKit

private let kViewId = "plugin.treemap.view"

// MARK: - Entry points

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?, _ services: UnsafePointer<PcHostServices>?) {
    guard let commandId, let services, String(cString: commandId) == "plugin.treemap.analyze" else { return }
    let svc = services.pointee, host = svc.host
    let root = analyzeRoot(svc)
    guard let present = svc.presentSidebarView else { return }
    kViewId.withCString { vid in root.withCString { rp in present(host, vid, rp) } }
}

@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?, _ container: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    // Settings pane contributed into the host Settings dialog.
    if let container, String(cString: container) == "settings" {
        return Unmanaged.passRetained(TreemapSettingsView()).toOpaque()
    }
    let view = DiskMapView(root: contextValue(services, "sidebarViewRoot") ?? NSHomeDirectory())
    view.frame = NSRect(x: 0, y: 0, width: 280, height: 460)
    if let services {
        let svc = services.pointee, host = svc.host
        if let fn = svc.openPathInPanel {
            view.openInPanel = { side, p in p.withCString { fn(host, Int32(side), $0) } }
        }
        if let fn = svc.moveToTrash {
            view.moveToTrash = { paths in withCStringArray(paths) { arr, count in fn(host, arr, count) } }
        }
        if let fn = svc.dismissSidebarView {
            view.dismiss = { kViewId.withCString { fn(host, $0) } }
        }
    }
    return Unmanaged.passRetained(view).toOpaque()
}

@_cdecl("PcCloseView")
public func PcCloseView(_ view: UnsafeMutableRawPointer?) {
    guard let view else { return }
    (Unmanaged<NSView>.fromOpaque(view).takeUnretainedValue() as? DiskMapView)?.cancelScan()
    Unmanaged<NSView>.fromOpaque(view).release()
}

@_cdecl("PcNotifyView")
public func PcNotifyView(_ view: UnsafeMutableRawPointer?, _ key: UnsafePointer<CChar>?, _ value: UnsafePointer<CChar>?) {}

/// Root to analyze: the active panel's current folder, then cursor folder, then home.
private func analyzeRoot(_ svc: PcHostServices) -> String {
    if let d = contextValueSvc(svc, "dir"), !d.isEmpty {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: d, isDirectory: &isDir), isDir.boolValue { return d }
    }
    if let fn = svc.cursorPath {
        var buf = [CChar](repeating: 0, count: 4096)
        if fn(svc.host, &buf, 4096) != 0 {
            let p = String(cString: buf)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: p, isDirectory: &isDir), isDir.boolValue { return p }
        }
    }
    return NSHomeDirectory()
}

private func contextValue(_ services: UnsafePointer<PcHostServices>?, _ key: String) -> String? {
    guard let services else { return nil }
    return contextValueSvc(services.pointee, key)
}
private func contextValueSvc(_ svc: PcHostServices, _ key: String) -> String? {
    guard let fn = svc.getContext else { return nil }
    var buf = [CChar](repeating: 0, count: 4096)
    let got = key.withCString { fn(svc.host, $0, &buf, 4096) }
    return got != 0 ? String(cString: buf) : nil
}

private func withCStringArray(_ strings: [String], _ body: (UnsafePointer<UnsafePointer<CChar>?>, Int32) -> Void) {
    let dups = strings.map { strdup($0) }
    defer { dups.forEach { free($0) } }
    let ptrs: [UnsafePointer<CChar>?] = dups.map { UnsafePointer($0) }
    ptrs.withUnsafeBufferPointer { body($0.baseAddress!, Int32(strings.count)) }
}

// MARK: - View

final class DiskMapView: NSView {
    private let root: String
    private var rootNode: Node?
    private var current: Node?
    private var volume: VolumeSpace?
    private var scanning = true
    private var scannedItems = 0
    private var scannedBytes: Int64 = 0
    private var scanningPath = ""
    private var control = ScanControl()
    private var snapshots: [String] = []      // local APFS snapshots on the volume

    // Hit geometry for the current frame.
    private var tiles: [TreemapTile] = []
    private var arcs: [SunburstArc] = []
    private var sunCenter: NSPoint = .zero
    private var largestRows: [(rect: NSRect, node: Node)] = []
    private var selected: Node?
    private var markedIDs = Set<ObjectIdentifier>()

    // Header hit rects.
    private var backRect = NSRect.zero
    private var closeRect = NSRect.zero
    private var chartToggleRect = NSRect.zero
    private var trashMarkedRect = NSRect.zero
    private var snapshotInfoRect = NSRect.zero

    var openInPanel: ((Int, String) -> Void)?
    var moveToTrash: (([String]) -> Void)?
    var dismiss: (() -> Void)?

    init(root: String) {
        self.root = root
        super.init(frame: .zero)
        wantsLayer = true
        NotificationCenter.default.addObserver(self, selector: #selector(configChanged),
                                               name: kTreemapConfigChanged, object: nil)
        startScan()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }

    private var cfg: TreemapConfig { ConfigStore.shared.config }

    func cancelScan() { control.cancelled = true }
    @objc private func configChanged() { needsDisplay = true }

    // MARK: Scan

    private func startScan() {
        control.cancelled = true
        control = ScanControl()
        let control = self.control
        scanning = true; scannedItems = 0; scannedBytes = 0
        rootNode = nil; current = nil; selected = nil; markedIDs.removeAll()
        needsDisplay = true
        let rootPath = root
        let stayOnVolume = cfg.stayOnVolume
        volume = VolumeSpace.read(forPath: rootPath)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let node = ScanEngine.scan(rootPath: rootPath, control: control, stayOnVolume: stayOnVolume) {
                items, bytes, path in
                DispatchQueue.main.async {
                    guard let self, !control.cancelled else { return }
                    self.scannedItems = items; self.scannedBytes = bytes; self.scanningPath = path
                    self.needsDisplay = true
                }
            }
            DispatchQueue.main.async {
                guard let self, !control.cancelled else { return }
                self.rootNode = node; self.current = node
                self.scanning = false; self.needsDisplay = true
            }
            // Local APFS snapshots (mostly what "purgeable" is) — informational.
            let mount = VolumeSpace.read(forPath: rootPath)?.mountPath ?? "/"
            let snaps = DiskMapView.localSnapshots(mount: mount)
            DispatchQueue.main.async {
                guard let self, !control.cancelled else { return }
                self.snapshots = snaps; self.needsDisplay = true
            }
        }
    }

    /// Read the volume's local APFS (Time Machine) snapshots, read-only.
    private static func localSnapshots(mount: String) -> [String] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        p.arguments = ["listlocalsnapshots", mount]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        guard (try? p.run()) != nil else { return [] }
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self)
        return text.split(separator: "\n").map(String.init)
            .filter { $0.contains("com.apple.TimeMachine") }
            .map { $0.replacingOccurrences(of: "com.apple.TimeMachine.", with: "")
                     .replacingOccurrences(of: ".local", with: "") }
    }

    // MARK: Layout / drawing

    override var isFlipped: Bool { true }
    private let headerH: CGFloat = 24
    private let ringH: CGFloat = 30

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill(); bounds.fill()
        snapshotInfoRect = .zero
        drawHeader()

        var top = headerH + 4
        if cfg.showVolumeRing, let vol = volume {
            drawVolumeBar(vol, in: NSRect(x: 8, y: top, width: bounds.width - 16, height: ringH - 8))
            top += ringH
        }

        if scanning {
            drawText(String(format: L("Analyzing… %lld items"), Int64(scannedItems)) + "  ·  " + bytes(scannedBytes),
                     in: NSRect(x: 8, y: top + 2, width: bounds.width - 16, height: 16), color: .secondaryLabelColor)
            drawText(scanningPath, in: NSRect(x: 8, y: top + 20, width: bounds.width - 16, height: 14),
                     color: .tertiaryLabelColor)
            tiles = []; arcs = []; largestRows = []
            return
        }
        guard let current, current.size > 0, !current.children.isEmpty else {
            drawText(L("(empty)"), in: NSRect(x: 8, y: top + 2, width: 200, height: 16), color: .secondaryLabelColor)
            tiles = []; arcs = []; largestRows = []
            return
        }

        var chartArea = NSRect(x: 6, y: top, width: bounds.width - 12, height: bounds.height - top - 6)
        if cfg.showLargestFiles {
            let listW = min(200, chartArea.width * 0.4)
            let listRect = NSRect(x: chartArea.maxX - listW, y: chartArea.minY, width: listW, height: chartArea.height)
            drawLargestFiles(current, in: listRect)
            chartArea.size.width -= listW + 6
        } else { largestRows = [] }

        // Reserve a strip for the category legend (only meaningful in category mode).
        var legendRect = NSRect.zero
        if cfg.colorScheme == "category" {
            let legendH: CGFloat = 22
            legendRect = NSRect(x: chartArea.minX, y: chartArea.maxY - legendH, width: chartArea.width, height: legendH)
            chartArea.size.height -= legendH
        }

        if cfg.chartType == "sunburst" { drawSunburst(current, in: chartArea) }
        else { drawTreemap(current, in: chartArea) }
        if !legendRect.isEmpty { drawLegend(current, in: legendRect) }
    }

    /// A compact swatch+name legend of the categories actually drawn (tiles are
    /// coloured by their nested file categories, so gather from the drawn geometry).
    private func drawLegend(_ current: Node, in rect: NSRect) {
        let drawn: [Node] = cfg.chartType == "sunburst" ? arcs.map { $0.node } : tiles.map { $0.node }
        let present = Set(drawn.map { FileCategory.of($0) })
        let cats = FileCategory.allCases.filter { present.contains($0) }   // stable order
        guard !cats.isEmpty else { return }
        var x = rect.minX
        let y = rect.minY + 4
        for cat in cats {
            let sw = NSRect(x: x, y: y + 1, width: 10, height: 10)
            cat.color.setFill(); NSBezierPath(roundedRect: sw, xRadius: 2, yRadius: 2).fill()
            let name = cat.displayName as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.secondaryLabelColor]
            name.draw(at: NSPoint(x: x + 14, y: y), withAttributes: attrs)
            x += 14 + name.size(withAttributes: attrs).width + 12
            if x > rect.maxX - 30 { break }
        }
    }

    private func maxChildSize(_ node: Node) -> Int64 { node.children.map { $0.size }.max() ?? 1 }

    private func drawTreemap(_ current: Node, in area: NSRect) {
        arcs = []
        tiles = TreemapLayout.layout(current, in: area)
        let scheme = cfg.colorScheme
        let maxS = maxChildSize(current)
        // Draw shallow first so nested tiles paint on top.
        for tile in tiles.sorted(by: { $0.depth < $1.depth }) {
            let node = tile.node, rect = tile.rect
            let base = tileFill(node, scheme: scheme, maxSize: maxS)
            let fill = tile.depth == 0 ? base : base.blended(withFraction: CGFloat(tile.depth) * 0.16, of: .white) ?? base
            fill.setFill(); rect.insetBy(dx: 0.5, dy: 0.5).fill()
            if markedIDs.contains(ObjectIdentifier(node)) { markOverlay(rect) }
            if node === selected {
                NSColor.controlAccentColor.setStroke()
                let p = NSBezierPath(rect: rect.insetBy(dx: 1, dy: 1)); p.lineWidth = 2; p.stroke()
            }
            if tile.depth == 0, rect.width > 46, rect.height > 24 {
                drawText("\(node.name)\n\(bytes(node.size))", in: rect.insetBy(dx: 4, dy: 3),
                         color: Palette.labelColor(on: base))
            }
        }
    }

    private func drawSunburst(_ current: Node, in area: NSRect) {
        tiles = []
        let center = NSPoint(x: area.midX, y: area.midY)
        let radius = min(area.width, area.height) / 2 - 6
        guard radius > 20 else { arcs = []; return }
        sunCenter = center
        arcs = SunburstLayout.layout(current, center: center, maxRadius: radius)
        let scheme = cfg.colorScheme
        let maxS = maxChildSize(current)
        for arc in arcs {
            let path = SunburstLayout.path(for: arc, center: center)
            let base = arc.depth == 0 ? NSColor.controlBackgroundColor : tileFill(arc.node, scheme: scheme, maxSize: maxS)
            let fill = arc.depth <= 1 ? base : (base.blended(withFraction: CGFloat(arc.depth - 1) * 0.12, of: .white) ?? base)
            fill.setFill(); path.fill()
            NSColor.windowBackgroundColor.setStroke(); path.lineWidth = 0.75; path.stroke()
            if arc.node === selected { NSColor.controlAccentColor.setStroke(); path.lineWidth = 2; path.stroke() }
            if markedIDs.contains(ObjectIdentifier(arc.node)) {
                NSColor.controlAccentColor.withAlphaComponent(0.5).setFill(); path.fill()
            }
        }
        // Center label: current folder + total.
        drawText("\(current.name)\n\(bytes(current.size))",
                 in: NSRect(x: center.x - 54, y: center.y - 12, width: 108, height: 28),
                 centered: true, color: .labelColor)
    }

    private func drawVolumeBar(_ vol: VolumeSpace, in rect: NSRect) {
        let scanned = min(rootNode?.size ?? 0, vol.used)
        let hidden = max(0, vol.used - scanned)
        let segs: [(Int64, NSColor)] = [
            (scanned, NSColor.controlAccentColor),
            (hidden, NSColor.systemGray),
            (vol.purgeable, NSColor.systemOrange.withAlphaComponent(0.7)),
            (vol.free, NSColor.quaternaryLabelColor),
        ]
        let total = max(1, vol.total)
        var x = rect.minX
        let bar = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: 10)
        NSColor.quaternaryLabelColor.setFill(); NSBezierPath(roundedRect: bar, xRadius: 3, yRadius: 3).fill()
        for (v, c) in segs where v > 0 {
            let w = CGFloat(Double(v) / Double(total)) * rect.width
            c.setFill(); NSRect(x: x, y: bar.minY, width: max(0, w), height: bar.height).fill(); x += w
        }
        // At the volume root the unscanned remainder is genuinely "hidden" (system-
        // protected, other users, snapshots); elsewhere it's just the rest of the disk.
        let atRoot = URL(fileURLWithPath: rootNode?.path ?? "").standardizedFileURL.path
            == URL(fileURLWithPath: vol.mountPath).standardizedFileURL.path
        var legend = atRoot
            ? String(format: L("Scanned %@ · Hidden %@ · Purgeable %@ · Free %@"),
                     bytes(scanned), bytes(hidden), bytes(vol.purgeable), bytes(vol.free))
            : String(format: L("This folder %@ · Rest of volume %@ · Purgeable %@ · Free %@"),
                     bytes(scanned), bytes(hidden), bytes(vol.purgeable), bytes(vol.free))
        if !snapshots.isEmpty { legend += String(format: L(" · %lld snapshots (ⓘ)"), Int64(snapshots.count)) }
        let legendRect = NSRect(x: rect.minX, y: bar.maxY + 2, width: rect.width, height: 12)
        drawText(legend, in: legendRect, size: 9, color: .secondaryLabelColor)
        snapshotInfoRect = snapshots.isEmpty ? .zero : legendRect
    }

    private func drawLargestFiles(_ current: Node, in rect: NSRect) {
        NSColor.controlBackgroundColor.setFill(); rect.fill()
        drawText(L("Largest files"), in: NSRect(x: rect.minX + 6, y: rect.minY + 4, width: rect.width - 12, height: 14),
                 bold: true, color: .labelColor)
        var files: [Node] = []
        collectFiles(current, into: &files)
        files.sort { $0.size > $1.size }
        largestRows = []
        var y = rect.minY + 22
        let rowH: CGFloat = 30
        for node in files.prefix(Int((rect.height - 24) / rowH)) {
            let r = NSRect(x: rect.minX + 4, y: y, width: rect.width - 8, height: rowH - 2)
            largestRows.append((r, node))
            if node === selected { NSColor.selectedContentBackgroundColor.setFill(); r.fill() }
            FileCategory.of(node).color.setFill()
            NSRect(x: r.minX, y: r.minY + 4, width: 3, height: r.height - 8).fill()
            drawText(node.name, in: NSRect(x: r.minX + 8, y: r.minY + 1, width: r.width - 10, height: 14),
                     size: 10, color: .labelColor)
            drawText(bytes(node.size), in: NSRect(x: r.minX + 8, y: r.minY + 15, width: r.width - 10, height: 12),
                     size: 9, color: .secondaryLabelColor)
            y += rowH
            if y > rect.maxY - rowH { break }
        }
    }
    private func collectFiles(_ node: Node, into out: inout [Node]) {
        for c in node.children { if c.isDir { collectFiles(c, into: &out) } else { out.append(c) } }
    }

    private func markOverlay(_ rect: NSRect) {
        NSColor.controlAccentColor.withAlphaComponent(0.35).setFill(); rect.insetBy(dx: 0.5, dy: 0.5).fill()
        drawText("✓", in: NSRect(x: rect.minX + 2, y: rect.minY + 1, width: 14, height: 14), bold: true, color: .white)
    }

    private func drawHeader() {
        NSColor.controlBackgroundColor.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: headerH).fill()
        var x: CGFloat = 6
        if let current, current.parent != nil {
            backRect = NSRect(x: x, y: 3, width: 18, height: 18)
            drawText("◂", in: backRect, bold: true, color: .labelColor); x += 22
        } else { backRect = .zero }

        // Right side: close, chart toggle, and (when items are marked) trash-marked.
        closeRect = NSRect(x: bounds.width - 22, y: 3, width: 18, height: 18)
        drawText("✕", in: closeRect, color: .secondaryLabelColor)
        chartToggleRect = NSRect(x: bounds.width - 46, y: 3, width: 20, height: 18)
        drawText(cfg.chartType == "sunburst" ? "▦" : "◎", in: chartToggleRect, color: .secondaryLabelColor)
        var rightEdge = chartToggleRect.minX - 4
        if !markedIDs.isEmpty {
            let label = "🗑 \(markedIDs.count)"
            trashMarkedRect = NSRect(x: rightEdge - 40, y: 3, width: 40, height: 18)
            drawText(label, in: trashMarkedRect, size: 11, color: .systemRed); rightEdge = trashMarkedRect.minX - 6
        } else { trashMarkedRect = .zero }

        drawText(breadcrumb(), in: NSRect(x: x, y: 4, width: rightEdge - x, height: 16), bold: true, color: .labelColor)
    }

    private func breadcrumb() -> String {
        guard let current else { return (root as NSString).lastPathComponent }
        var parts: [String] = []
        var n: Node? = current
        while let node = n, node !== rootNode?.parent { parts.insert(node.name, at: 0); n = node.parent }
        return parts.joined(separator: " ▸ ")
    }

    private func drawText(_ s: String, in rect: NSRect, bold: Bool = false, size: CGFloat? = nil,
                          centered: Bool = false, color: NSColor) {
        let p = NSMutableParagraphStyle()
        p.lineBreakMode = .byTruncatingTail
        if centered { p.alignment = .center }
        (s as NSString).draw(in: rect, withAttributes: [
            .font: NSFont.systemFont(ofSize: size ?? (bold ? 12 : 10), weight: bold ? .semibold : .regular),
            .foregroundColor: color, .paragraphStyle: p,
        ])
    }
    private func bytes(_ n: Int64) -> String { ByteCountFormatter.string(fromByteCount: n, countStyle: .file) }

    // MARK: Interaction

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func nodeAt(_ p: NSPoint) -> Node? {
        if cfg.chartType == "sunburst" { return SunburstLayout.hit(arcs, point: p, center: sunCenter) }
        // Deepest treemap tile wins, so clicking a nested folder drills straight in.
        var best: TreemapTile?
        for t in tiles where t.rect.contains(p) { if best == nil || t.depth > best!.depth { best = t } }
        if let n = best?.node { return n }
        return largestRows.first { $0.rect.contains(p) }?.node
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if !closeRect.isEmpty, closeRect.contains(p) { dismiss?(); return }
        if !chartToggleRect.isEmpty, chartToggleRect.contains(p) {
            ConfigStore.shared.update { $0.chartType = ($0.chartType == "sunburst") ? "treemap" : "sunburst" }; return
        }
        if !trashMarkedRect.isEmpty, trashMarkedRect.contains(p) { trashMarked(); return }
        if !snapshotInfoRect.isEmpty, snapshotInfoRect.contains(p) { showSnapshots(); return }
        if !backRect.isEmpty, backRect.contains(p) { navigateUp(); return }
        guard let node = nodeAt(p) else { return }
        if node.isDir, !node.children.isEmpty { current = node; selected = nil; needsDisplay = true }
        else { selected = node; needsDisplay = true }
    }

    override func rightMouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard let node = nodeAt(p) else { return }
        selected = node; needsDisplay = true
        let menu = NSMenu()
        let marked = markedIDs.contains(ObjectIdentifier(node))
        item(menu, marked ? L("Unmark") : L("Mark for Collector"), #selector(ctxToggleMark))
        menu.addItem(.separator())
        item(menu, L("Open in Left Panel"), #selector(ctxOpenLeft))
        item(menu, L("Open in Right Panel"), #selector(ctxOpenRight))
        item(menu, L("Reveal in Finder"), #selector(ctxReveal))
        menu.addItem(.separator())
        item(menu, L("Move to Trash"), #selector(ctxTrash))
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    private func item(_ m: NSMenu, _ t: String, _ s: Selector) {
        let i = NSMenuItem(title: t, action: s, keyEquivalent: ""); i.target = self; m.addItem(i)
    }

    // Hover tooltip with path, size and item count.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let n = nodeAt(p) {
            let count = n.isDir ? "  ·  " + String(format: L("%lld items"), Int64(n.itemCount)) : ""
            toolTip = "\(n.path)\n\(bytes(n.size))\(count)"
        } else { toolTip = nil }
    }

    private func navigateUp() {
        guard let c = current, let parent = c.parent else { return }
        current = parent; selected = nil; needsDisplay = true
    }

    /// Read-only APFS snapshot report (snapshots are the bulk of purgeable space).
    private func showSnapshots() {
        guard !snapshots.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = String(format: L("%lld local APFS snapshots"), Int64(snapshots.count))
        alert.informativeText = snapshots.prefix(12).joined(separator: "\n")
            + (snapshots.count > 12 ? "\n…" : "")
            + "\n\n" + L("Snapshots retain deleted files and count as purgeable space. Manage them in Disk Utility (View ▸ Show APFS Snapshots) or Time Machine.")
        alert.addButton(withTitle: L("OK"))
        alert.runModal()
    }

    @objc private func ctxOpenLeft()  { if let n = selected { openInPanel?(0, n.path) } }
    @objc private func ctxOpenRight() { if let n = selected { openInPanel?(1, n.path) } }
    @objc private func ctxReveal() {
        if let n = selected { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: n.path)]) }
    }
    @objc private func ctxToggleMark() {
        guard let n = selected else { return }
        let id = ObjectIdentifier(n)
        if markedIDs.contains(id) { markedIDs.remove(id) } else { markedIDs.insert(id) }
        needsDisplay = true
    }
    @objc private func ctxTrash() {
        guard let n = selected else { return }
        trash([n])
    }

    /// Collector: trash everything currently marked in one action.
    private func trashMarked() {
        guard let root = rootNode else { return }
        var nodes: [Node] = []
        collectMarked(root, into: &nodes)
        guard !nodes.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = String(format: L("Move %lld marked item(s) to the Trash?"), Int64(nodes.count))
        alert.addButton(withTitle: L("Move to Trash"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        trash(nodes)
    }
    private func collectMarked(_ node: Node, into out: inout [Node]) {
        if markedIDs.contains(ObjectIdentifier(node)) { out.append(node) }
        for c in node.children { collectMarked(c, into: &out) }
    }

    private func trash(_ nodes: [Node]) {
        let paths = nodes.map { $0.path }
        if let mt = moveToTrash { mt(paths) }
        else { paths.forEach { try? FileManager.default.trashItem(at: URL(fileURLWithPath: $0), resultingItemURL: nil) } }
        for n in nodes { markedIDs.remove(ObjectIdentifier(n)); removeNode(n) }
        needsDisplay = true
    }

    /// Drop a deleted node and subtract its size from every ancestor.
    private func removeNode(_ node: Node) {
        guard let parent = node.parent, let idx = parent.children.firstIndex(where: { $0 === node }) else { return }
        parent.children.remove(at: idx)
        var n: Node? = parent
        while let a = n { a.size -= node.size; a.itemCount -= node.itemCount; n = a.parent }
        if selected === node { selected = nil }
        var c: Node? = current
        while let cc = c { if cc === node { current = parent; break }; c = cc.parent }
    }
}
