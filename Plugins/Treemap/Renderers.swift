// Renderers.swift — colour coding + the two Disk Map visualisations.
//
// Colour coding: files are grouped into a handful of curated categories (media, docs,
// code, …) with a muted, legible palette instead of a per-extension "rainbow". A size
// heatmap is offered as an alternative. Label text picks black/white by tile luminance
// so it stays readable in light and dark themes and on any tile colour.
//
// Two layouts share the same Node tree and both hit-test the DEEPEST tile/segment under
// the cursor, so the user can drill straight into a nested sub-folder:
//   • Treemap  — squarified rectangles, visually nested a few levels deep.
//   • Sunburst — concentric rings (DaisyDisk-style), one ring per depth.

import AppKit

// MARK: - Categories & palette

enum FileCategory: CaseIterable, Hashable {
    case folder, video, image, audio, document, code, archive, app, diskImage, other

    var displayName: String {
        switch self {
        case .folder: return L("Folders")
        case .video: return L("Video")
        case .image: return L("Images")
        case .audio: return L("Audio")
        case .document: return L("Documents")
        case .code: return L("Code")
        case .archive: return L("Archives")
        case .app: return L("Apps & binaries")
        case .diskImage: return L("Disk images")
        case .other: return L("Other")
        }
    }

    /// Muted accent palette (same family as the System Monitor plugin).
    var color: NSColor {
        switch self {
        case .folder:    return hex(0x8E9AAF)
        case .video:     return hex(0xBF5AF2)
        case .image:     return hex(0xFF9F0A)
        case .audio:     return hex(0x64D2FF)
        case .document:  return hex(0x0A84FF)
        case .code:      return hex(0x30D158)
        case .archive:   return hex(0xAC8E68)
        case .app:       return hex(0xFF453A)
        case .diskImage: return hex(0x5E5CE6)
        case .other:     return hex(0x98989D)
        }
    }

    static func of(_ node: Node) -> FileCategory {
        if node.isDir { return .folder }
        switch (node.name as NSString).pathExtension.lowercased() {
        case "mov", "mp4", "m4v", "avi", "mkv", "webm", "wmv", "flv", "mpg", "mpeg": return .video
        case "jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "tif", "bmp", "raw", "psd", "svg", "webp": return .image
        case "mp3", "aac", "wav", "aiff", "flac", "m4a", "ogg", "caf", "alac": return .audio
        case "pdf", "doc", "docx", "pages", "txt", "rtf", "md", "xls", "xlsx", "numbers",
             "ppt", "pptx", "key", "epub", "csv": return .document
        case "swift", "c", "cc", "cpp", "h", "hpp", "m", "mm", "java", "kt", "js", "ts",
             "py", "rb", "go", "rs", "sh", "json", "xml", "yml", "yaml", "html", "css": return .code
        case "zip", "tar", "gz", "bz2", "xz", "7z", "rar", "tgz", "zst": return .archive
        case "app", "dylib", "so", "o", "a", "framework", "bundle", "exe": return .app
        case "dmg", "iso", "sparseimage", "sparsebundle", "img", "pkg": return .diskImage
        default: return .other
        }
    }

    private func hex(_ v: Int) -> NSColor { Palette.color(v) }
}

enum Palette {
    static func color(_ hex: Int, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0, alpha: alpha)
    }
    /// A size heatmap from cool (small) to hot (large), `f` in 0…1.
    static func heat(_ f: Double) -> NSColor {
        let c = max(0, min(1, f))
        // blue → cyan → green → yellow → red
        let hue = (0.62 - 0.62 * c)   // 0.62 (blue) down to 0 (red)
        return NSColor(calibratedHue: CGFloat(hue), saturation: 0.62, brightness: 0.92, alpha: 1)
    }
    /// Black or white, whichever contrasts better with `bg`.
    static func labelColor(on bg: NSColor) -> NSColor {
        let c = bg.usingColorSpace(.sRGB) ?? bg
        let l = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
        return l > 0.6 ? .black : .white
    }
}

/// Resolve a tile's fill for the chosen scheme.
func tileFill(_ node: Node, scheme: String, maxSize: Int64) -> NSColor {
    if scheme == "heatmap" {
        let f = maxSize > 0 ? Double(node.size) / Double(maxSize) : 0
        return Palette.heat(f)
    }
    return FileCategory.of(node).color
}

// MARK: - Treemap

struct TreemapTile { let rect: NSRect; let node: Node; let depth: Int }

enum TreemapLayout {
    /// Lay out `root`'s children into `rect`, nesting a few levels for visual depth.
    static func layout(_ root: Node, in rect: NSRect) -> [TreemapTile] {
        var out: [TreemapTile] = []
        place(root, in: rect, depth: 0, into: &out)
        return out
    }

    private static func place(_ node: Node, in rect: NSRect, depth: Int, into out: inout [TreemapTile]) {
        guard depth < 4, rect.width > 6, rect.height > 6 else { return }
        let kids = node.children.filter { $0.size > 0 }.sorted { $0.size > $1.size }
        guard !kids.isEmpty else { return }
        let frames = squarify(kids.map { Double($0.size) }, in: rect)
        for (i, child) in kids.enumerated() {
            let f = frames[i]
            guard f.width >= 2, f.height >= 2 else { continue }
            out.append(TreemapTile(rect: f, node: child, depth: depth))
            // Nest this folder's own contents into its interior (below a small header).
            if child.isDir, !child.children.isEmpty, f.width > 60, f.height > 44 {
                let inner = NSRect(x: f.minX + 2, y: f.minY + 16, width: f.width - 4, height: f.height - 18)
                place(child, in: inner, depth: depth + 1, into: &out)
            }
        }
    }

    static func squarify(_ areas: [Double], in rect: NSRect) -> [NSRect] {
        let total = areas.reduce(0, +)
        guard total > 0 else { return Array(repeating: .zero, count: areas.count) }
        let scale = Double(rect.width) * Double(rect.height) / total
        let px = areas.map { $0 * scale }
        var frames = Array(repeating: NSRect.zero, count: areas.count)
        var r = rect
        var start = 0
        while start < px.count {
            let side = Double(min(r.width, r.height))
            guard side > 0 else { break }
            var end = start
            var row: [Double] = []
            while end < px.count {
                let candidate = row + [px[end]]
                if row.isEmpty || worst(candidate, side) <= worst(row, side) { row = candidate; end += 1 }
                else { break }
            }
            let s = row.reduce(0, +)
            let thickness = CGFloat(s / side)
            if r.width >= r.height {
                var y = r.minY
                for k in start..<end { let h = CGFloat(px[k]) / max(thickness, 0.0001)
                    frames[k] = NSRect(x: r.minX, y: y, width: thickness, height: h); y += h }
                r = NSRect(x: r.minX + thickness, y: r.minY, width: r.width - thickness, height: r.height)
            } else {
                var x = r.minX
                for k in start..<end { let w = CGFloat(px[k]) / max(thickness, 0.0001)
                    frames[k] = NSRect(x: x, y: r.minY, width: w, height: thickness); x += w }
                r = NSRect(x: r.minX, y: r.minY + thickness, width: r.width, height: r.height - thickness)
            }
            start = end
        }
        return frames
    }
    private static func worst(_ row: [Double], _ side: Double) -> Double {
        guard let rmax = row.max(), let rmin = row.min(), rmin > 0 else { return .greatestFiniteMagnitude }
        let s = row.reduce(0, +)
        return max((side * side * rmax) / (s * s), (s * s) / (side * side * rmin))
    }
}

// MARK: - Sunburst

struct SunburstArc {
    let node: Node
    let depth: Int
    let start: CGFloat   // radians
    let end: CGFloat
    let inner: CGFloat   // radius
    let outer: CGFloat
}

enum SunburstLayout {
    /// Concentric rings for `root`'s descendants around `center`. Ring 0 is the inner
    /// disc (the current folder); each deeper level is one ring further out.
    static func layout(_ root: Node, center: NSPoint, maxRadius: CGFloat) -> [SunburstArc] {
        var out: [SunburstArc] = []
        let ringCount = max(2, min(6, Int(maxRadius / 34)))
        let ring = maxRadius / CGFloat(ringCount)
        // Inner disc for the root itself.
        out.append(SunburstArc(node: root, depth: 0, start: 0, end: .pi * 2, inner: 0, outer: ring))
        place(root, center: center, start: 0, end: .pi * 2, depth: 1,
              ring: ring, maxDepth: ringCount, into: &out)
        return out
    }

    private static func place(_ node: Node, center: NSPoint, start: CGFloat, end: CGFloat,
                              depth: Int, ring: CGFloat, maxDepth: Int, into out: inout [SunburstArc]) {
        guard depth < maxDepth else { return }
        let kids = node.children.filter { $0.size > 0 }.sorted { $0.size > $1.size }
        let total = kids.reduce(0.0) { $0 + Double($1.size) }
        guard total > 0 else { return }
        let span = Double(end - start)
        var a = start
        for child in kids {
            let sweep = CGFloat(Double(child.size) / total * span)
            guard sweep > 0.002 else { a += sweep; continue }   // skip slivers
            let inner = CGFloat(depth) * ring
            out.append(SunburstArc(node: child, depth: depth, start: a, end: a + sweep,
                                   inner: inner, outer: inner + ring))
            if child.isDir, !child.children.isEmpty {
                place(child, center: center, start: a, end: a + sweep, depth: depth + 1,
                      ring: ring, maxDepth: maxDepth, into: &out)
            }
            a += sweep
        }
    }

    static func path(for arc: SunburstArc, center: NSPoint) -> NSBezierPath {
        let p = NSBezierPath()
        let s = arc.start * 180 / .pi, e = arc.end * 180 / .pi
        if arc.inner <= 0.5 {
            p.move(to: center)
            p.appendArc(withCenter: center, radius: arc.outer, startAngle: s, endAngle: e)
            p.close()
        } else {
            p.appendArc(withCenter: center, radius: arc.inner, startAngle: s, endAngle: e)
            p.appendArc(withCenter: center, radius: arc.outer, startAngle: e, endAngle: s, clockwise: true)
            p.close()
        }
        return p
    }

    /// The arc under `point` (deepest ring wins), or nil.
    static func hit(_ arcs: [SunburstArc], point: NSPoint, center: NSPoint) -> Node? {
        let dx = point.x - center.x, dy = point.y - center.y
        let r = sqrt(dx * dx + dy * dy)
        var ang = atan2(dy, dx); if ang < 0 { ang += .pi * 2 }
        var best: SunburstArc?
        for arc in arcs where r >= arc.inner && r <= arc.outer && ang >= arc.start && ang <= arc.end {
            if best == nil || arc.depth > best!.depth { best = arc }
        }
        return best?.node
    }
}
