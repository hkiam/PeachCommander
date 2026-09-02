// SPDX-License-Identifier: Apache-2.0
// PanelViewMode.swift - Per-panel view modes + grid geometry (TODOS #58).
//
// The panel can render as a detail list (current), a brief multi-column name list,
// an icon/thumbnail grid, or a gallery. `GridLayout` is the pure geometry used by the
// custom-drawn icon/gallery views: given a container width and item size it computes
// the column count, each item's frame, the total content height, and hit-tests a
// point back to an item index. Fully unit-testable.

import CoreGraphics

public enum PanelViewMode: String, Sendable, CaseIterable {
    case details, brief, icons, gallery

    public var next: PanelViewMode {
        let all = PanelViewMode.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }

    public var title: String {
        switch self {
        case .details: return "Details"
        case .brief: return "Brief"
        case .icons: return "Icons"
        case .gallery: return "Gallery"
        }
    }
}

public struct GridLayout: Equatable, Sendable {
    public var itemWidth: CGFloat
    public var itemHeight: CGFloat
    public var spacing: CGFloat
    public var edgeInset: CGFloat

    public init(itemWidth: CGFloat, itemHeight: CGFloat, spacing: CGFloat = 8, edgeInset: CGFloat = 8) {
        self.itemWidth = itemWidth
        self.itemHeight = itemHeight
        self.spacing = spacing
        self.edgeInset = edgeInset
    }

    /// Number of columns that fit in `width` (at least 1).
    public func columns(forWidth width: CGFloat) -> Int {
        let usable = width - 2 * edgeInset + spacing
        let per = itemWidth + spacing
        guard per > 0 else { return 1 }
        return max(1, Int(usable / per))
    }

    public func rows(count: Int, width: CGFloat) -> Int {
        guard count > 0 else { return 0 }
        let cols = columns(forWidth: width)
        return (count + cols - 1) / cols
    }

    /// Frame of item `index` within a container `width`.
    public func frame(at index: Int, width: CGFloat) -> CGRect {
        let cols = columns(forWidth: width)
        let col = index % cols
        let row = index / cols
        let x = edgeInset + CGFloat(col) * (itemWidth + spacing)
        let y = edgeInset + CGFloat(row) * (itemHeight + spacing)
        return CGRect(x: x, y: y, width: itemWidth, height: itemHeight)
    }

    public func contentHeight(count: Int, width: CGFloat) -> CGFloat {
        let r = rows(count: count, width: width)
        guard r > 0 else { return 0 }
        return 2 * edgeInset + CGFloat(r) * itemHeight + CGFloat(r - 1) * spacing
    }

    // MARK: - Column-major (brief) geometry
    //
    // Brief mode flows items top-to-bottom filling a column, then wraps to the next
    // column to the right — so it is driven by the container HEIGHT and scrolls
    // horizontally. `rowsPerColumn` is how many items fit vertically.

    public func rowsPerColumn(forHeight height: CGFloat) -> Int {
        let usable = height - 2 * edgeInset + spacing
        let per = itemHeight + spacing
        guard per > 0 else { return 1 }
        return max(1, Int(usable / per))
    }

    public func columnsNeeded(count: Int, height: CGFloat) -> Int {
        guard count > 0 else { return 0 }
        let rows = rowsPerColumn(forHeight: height)
        return (count + rows - 1) / rows
    }

    public func frameColumnMajor(at index: Int, height: CGFloat) -> CGRect {
        let rows = rowsPerColumn(forHeight: height)
        let col = index / rows
        let row = index % rows
        let x = edgeInset + CGFloat(col) * (itemWidth + spacing)
        let y = edgeInset + CGFloat(row) * (itemHeight + spacing)
        return CGRect(x: x, y: y, width: itemWidth, height: itemHeight)
    }

    public func contentWidth(count: Int, height: CGFloat) -> CGFloat {
        let c = columnsNeeded(count: count, height: height)
        guard c > 0 else { return 0 }
        return 2 * edgeInset + CGFloat(c) * itemWidth + CGFloat(c - 1) * spacing
    }

    public func indexColumnMajor(at point: CGPoint, height: CGFloat, count: Int) -> Int? {
        let rows = rowsPerColumn(forHeight: height)
        let step = (col: itemWidth + spacing, row: itemHeight + spacing)
        let relX = point.x - edgeInset
        let relY = point.y - edgeInset
        guard relX >= 0, relY >= 0 else { return nil }
        let col = Int(relX / step.col)
        let row = Int(relY / step.row)
        guard row < rows else { return nil }
        guard relX - CGFloat(col) * step.col <= itemWidth,
              relY - CGFloat(row) * step.row <= itemHeight else { return nil }
        let index = col * rows + row
        return (index >= 0 && index < count) ? index : nil
    }

    // MARK: - What is on screen
    //
    // The grid draws every cell it has and the panel asked for a thumbnail of every *file* it had —
    // for the whole directory, on every partial batch of a listing. Locally that is churn; on a
    // share or inside an archive it is one full read per entry (F-479). So the caller needs to know
    // which items a viewport actually covers, and it has to be cheap: iterating every index to test
    // its frame is the thing being replaced, not a cheaper way to do it.
    //
    // The answer is a *range* and not a set, in both flows, because the grid is exactly as wide (or
    // tall) as its clip view: a visible row has all of its columns visible with it.

    /// The items whose cells intersect `rect`, row-major (icons / gallery / thumbnails).
    public func indexes(intersecting rect: CGRect, width: CGFloat, count: Int) -> Range<Int> {
        let band = Self.band(from: rect.minY, to: rect.maxY, extent: itemHeight,
                             step: itemHeight + spacing, inset: edgeInset)
        return Self.range(band, perBand: columns(forWidth: width), count: count)
    }

    /// The items whose cells intersect `rect`, column-major (brief).
    public func indexesColumnMajor(intersecting rect: CGRect, height: CGFloat,
                                   count: Int) -> Range<Int> {
        let band = Self.band(from: rect.minX, to: rect.maxX, extent: itemWidth,
                             step: itemWidth + spacing, inset: edgeInset)
        return Self.range(band, perBand: rowsPerColumn(forHeight: height), count: count)
    }

    /// Which rows (or columns) a viewport touches.
    ///
    /// Solved from the cell's own geometry rather than by rounding the viewport, because cells do
    /// **not** tile: `step` is the cell plus the gap, so a coordinate can land between two cells and
    /// belong to neither. Band `b` occupies `[inset + b*step, inset + b*step + extent]`, and it is
    /// touched when its far edge is past `from` and its near edge is before `to`.
    ///
    /// `floor`/`ceil` and not `Int(...)`: Swift's `Int(Double)` truncates *toward zero*, so the
    /// first version turned a cell scrolled half off the top (a negative quotient) into band 0 by
    /// accident and into the wrong band on purpose.
    private static func band(from: CGFloat, to: CGFloat, extent: CGFloat,
                             step: CGFloat, inset: CGFloat) -> Range<Int> {
        guard step > 0, to > from, from.isFinite, to.isFinite else { return 0..<0 }
        let firstD = floor(Double(from - inset - extent) / Double(step)) + 1
        let lastD = ceil(Double(to - inset) / Double(step)) - 1
        guard firstD.isFinite, lastD.isFinite, lastD >= 0 else { return 0..<0 }
        // Clamped at **both** ends before it becomes an `Int`. `Int(Double)` traps on anything
        // outside Int's range, and this took the app down the first time a panel switched to
        // gallery view: a view with no clipping ancestor reports `CGRect.infinite`, whose corner is
        // -8.99e307. Note what that means — `CGRect.infinite` is built from *finite* numbers, so an
        // `isFinite` check sails straight past it, and the first version of this clamp only held the
        // upper end and trapped on the lower one instead.
        let cap = Double(1 << 40)          // past any listing, and far inside Int
        let first = max(0, Int(min(max(firstD, -cap), cap)))
        let last = Int(min(max(lastD, -cap), cap))
        guard last >= first else { return 0..<0 }
        return first..<(last + 1)
    }

    private static func range(_ bands: Range<Int>, perBand: Int, count: Int) -> Range<Int> {
        guard count > 0, perBand > 0, !bands.isEmpty else { return 0..<0 }
        // Clamp the band index before multiplying, not after: `bands.lowerBound * perBand` on a
        // scrolled-past-the-end viewport can overflow, which traps just as hard as the conversion.
        let maxBand = count / perBand + 1
        let lower = min(count, min(bands.lowerBound, maxBand) * perBand)
        let upper = min(count, min(bands.upperBound, maxBand) * perBand)
        return lower..<max(lower, upper)
    }

    /// Item index at `point`, or nil if the point is in a gap / past the end.
    public func index(at point: CGPoint, width: CGFloat, count: Int) -> Int? {
        let cols = columns(forWidth: width)
        let step = (col: itemWidth + spacing, row: itemHeight + spacing)
        let relX = point.x - edgeInset
        let relY = point.y - edgeInset
        guard relX >= 0, relY >= 0 else { return nil }
        let col = Int(relX / step.col)
        let row = Int(relY / step.row)
        guard col < cols else { return nil }
        // Inside the item box (not the trailing gap)?
        guard relX - CGFloat(col) * step.col <= itemWidth,
              relY - CGFloat(row) * step.row <= itemHeight else { return nil }
        let index = row * cols + col
        return (index >= 0 && index < count) ? index : nil
    }
}
