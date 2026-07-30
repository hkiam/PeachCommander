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
