// SPDX-License-Identifier: Apache-2.0
// StructureNavigation.swift - Moving and selecting by structure rather than by line (F-369).
//
// In a 900-line docker-compose.yml or a plist, the useful movements are not "up a line" and "down a
// line" — they are "out to the service this belongs to", "on to the next service", "select this whole
// block". Those are one-keystroke operations in an XML editor and absent from a text editor, so people
// fold, count indentation, and select by dragging.
//
// All of it is a query against the outline tree (`SymbolNode`), which the editor already has for the
// sidebar and the breadcrumb, so this works for every format that outline supports.
//
// Containment is by UTF-16 offset because that is what `NSTextView` selects with.

import Foundation

public enum StructureNavigation {

    /// The innermost node containing `offset`, or nil outside every node.
    public static func node(_ roots: [SymbolNode], at offset: Int) -> SymbolNode? {
        chain(roots, at: offset).last
    }

    /// The node enclosing the innermost node at `offset` — one step out.
    public static func parent(_ roots: [SymbolNode], at offset: Int) -> SymbolNode? {
        let path = chain(roots, at: offset)
        return path.count >= 2 ? path[path.count - 2] : nil
    }

    /// The first node nested inside the innermost node at `offset` — one step in.
    public static func firstChild(_ roots: [SymbolNode], at offset: Int) -> SymbolNode? {
        node(roots, at: offset)?.children.first
    }

    /// The next (`delta` = 1) or previous (`delta` = -1) sibling of the innermost node at `offset`.
    ///
    /// Siblings, not "the next node": in a list of forty servers, moving to the next *sibling* skips the
    /// current one's contents, which is the whole reason to navigate by structure. Returns nil at the
    /// ends rather than wrapping — a beep is clearer than jumping to the top of the file.
    public static func sibling(_ roots: [SymbolNode], at offset: Int, delta: Int) -> SymbolNode? {
        let path = chain(roots, at: offset)
        guard let current = path.last else { return nil }
        let siblings = path.count >= 2 ? path[path.count - 2].children : roots
        guard let i = siblings.firstIndex(where: { $0 === current }) else { return nil }
        let j = i + delta
        guard siblings.indices.contains(j) else { return nil }
        return siblings[j]
    }

    /// The node to select when the user asks to widen the selection to enclosing structure.
    ///
    /// Growing is what makes this usable: press once and the value's own node is selected, press again
    /// and it is the mapping around it. So a node whose range is *already* the selection is skipped in
    /// favour of the next one out, and a selection spanning several nodes jumps to their common parent.
    public static func enclosing(_ roots: [SymbolNode], selection: Range<Int>) -> SymbolNode? {
        var best: SymbolNode?
        var level = roots
        while let node = level.first(where: { $0.start <= selection.lowerBound
                                             && selection.upperBound <= $0.end }) {
            // Strictly larger than what is selected, or pressing the key a second time does nothing.
            if node.start < selection.lowerBound || selection.upperBound < node.end { best = node }
            level = node.children
        }
        return best
    }

    /// Outermost → innermost nodes containing `offset`.
    private static func chain(_ roots: [SymbolNode], at offset: Int) -> [SymbolNode] {
        var path: [SymbolNode] = []
        var level = roots
        while let node = level.first(where: { $0.start <= offset && offset <= $0.end }) {
            path.append(node)
            level = node.children
        }
        return path
    }
}
