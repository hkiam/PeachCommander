// SPDX-License-Identifier: Apache-2.0
// WorkspaceChipHit.swift - What a click on a workspace chip landed on (F-499).
//
// The chip strip is hand-drawn, so a glyph inside a chip is not a control the responder chain knows
// about — it is pixels, and what a click on it *does* is decided entirely by the order the regions are
// tested in. That order is the whole of the correctness here, and it is the kind of defect neither the
// compiler nor a screenshot can see: test the chip first and the ✕ is drawn, looks clickable, and only
// ever switches workspace. F-385 shipped exactly that bug with the drive bar's eject glyph, which is
// why this lives in a function with a test rather than in a loop in the view.
//
// The ✕ deletes. A workspace is **deleted**, not closed — its stash and its journal go with it — so
// this answers where the click landed and nothing more; the confirmation is the caller's, and there is
// only one of it.

import Foundation

public enum WorkspaceChipHit {

    public enum Region: Sendable, Equatable {
        /// Switch to the chip at this index.
        case chip(Int)
        /// Delete the workspace at this index, after asking.
        case close(Int)
        /// The "+" at the end of the strip.
        case new
        /// Free space.
        case none
    }

    /// Where the ✕ sits inside a chip, or nil when this chip has none.
    ///
    /// - Parameters:
    ///   - chip: the chip's own rectangle.
    ///   - showsClose: whether this chip draws a ✕ at all — false for the last remaining workspace
    ///     (which cannot be deleted) and for a chip too narrow to spare the room. A control that
    ///     cannot work is not drawn, the rule the "+" already follows.
    public static func closeRect(in chip: CGRect, showsClose: Bool) -> CGRect? {
        guard showsClose else { return nil }
        // Square, against the chip's trailing edge, inset so it does not touch the rounded corner.
        let side = min(closeSide, chip.height - 4)
        guard side > 6, chip.width > side + minimumNameWidth else { return nil }
        return CGRect(x: chip.maxX - side - 3,
                      y: chip.midY - side / 2,
                      width: side, height: side)
    }

    /// The glyph's own size, and the room a chip must keep for a name beside it.
    public static let closeSide: CGFloat = 14
    public static let minimumNameWidth: CGFloat = 46

    /// What was clicked.
    ///
    /// **The ✕ is tested before its own chip**, because it lies *inside* it: the other order compiles,
    /// runs, draws the glyph and silently never fires it.
    public static func region(at point: CGPoint,
                              chips: [CGRect],
                              showsClose: (Int) -> Bool,
                              plus: CGRect?) -> Region {
        for (index, frame) in chips.enumerated() where frame.contains(point) {
            if let close = closeRect(in: frame, showsClose: showsClose(index)), close.contains(point) {
                return .close(index)
            }
            return .chip(index)
        }
        if let plus, plus != .zero, plus.contains(point) { return .new }
        return .none
    }
}
