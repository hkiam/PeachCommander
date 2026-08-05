// SPDX-License-Identifier: Apache-2.0
// EditorFolding.swift - Collapsing a node's body in the editor (F-371).
//
// A 900-line docker-compose.yml or a plist is read by collapsing what is not being worked on. Everything
// needed for it already exists: the outline knows every node's character range (F-368), so folding is a
// question of *not drawing* those characters.
//
// How the hiding works, and why this way
// --------------------------------------
// Through `NSLayoutManagerDelegate.shouldGenerateGlyphs`, marking every glyph in a folded range as
// `.null`. The alternatives are all worse:
//
//   * Replacing the text with an attachment *changes the document*: the file on disk would gain and lose
//     content as the user folds, and one crash mid-fold would lose the body.
//   * Deleting into a side buffer has the same problem plus an undo stack full of phantom edits.
//   * A separate "folded view" is a second text system to keep in sync.
//
// Null glyphs leave the text storage untouched: the document is exactly what will be saved, undo is
// unaffected, and Find still finds text inside a fold.
//
// What folding must not do
// ------------------------
// Hidden text that can still be typed into is worse than no folding at all — the user edits something
// they cannot see. Three rules prevent that, and each one is a test:
//
//   1. A fold hides the *body* only; the line carrying the key or the tag stays visible, marked, so a
//      collapsed block is visibly collapsed and not simply absent.
//   2. Any edit drops every fold. Character offsets move when text is inserted, and a fold whose range
//      has drifted hides the wrong thing. The outline reparses after an edit anyway.
//   3. A selection that lands inside a fold unfolds it, rather than leaving the caret in hidden text.

import AppKit
import PCFoundation

/// The folded ranges of one editor, and the glyph-level hiding that realizes them.
final class EditorFolding: NSObject, NSLayoutManagerDelegate {

    /// Character ranges that are not drawn. Sorted, non-overlapping.
    private(set) var hidden: [NSRange] = []

    /// Called after the set of folds changed, so the gutter, the minimap and the layout catch up.
    var onChange: (() -> Void)?

    private weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init()
        textView.layoutManager?.delegate = self
    }

    var isEmpty: Bool { hidden.isEmpty }

    /// Whether a character offset is inside a fold — what the gutter asks to skip a hidden line.
    func isHidden(offset: Int) -> Bool {
        hidden.contains { NSLocationInRange(offset, $0) }
    }

    /// The fold containing `offset`, if any.
    func fold(containing offset: Int) -> NSRange? {
        hidden.first { NSLocationInRange(offset, $0) }
    }

    /// Fold a node: hide everything after its first line, up to its end.
    ///
    /// Returns false when there is nothing to fold — a one-line node, or a range already folded. The
    /// caller reports that; silently doing nothing reads as a broken key.
    @discardableResult
    func fold(node: SymbolNode, in text: NSString) -> Bool {
        guard let range = bodyRange(of: node, in: text) else { return false }
        guard !hidden.contains(where: { NSIntersectionRange($0, range).length > 0 }) else { return false }
        hidden.append(range)
        hidden.sort { $0.location < $1.location }
        invalidate()
        return true
    }

    /// Unfold the fold containing `offset` (or the one that starts on the caret's own line).
    @discardableResult
    func unfold(at offset: Int, in text: NSString) -> Bool {
        // The caret usually sits on the *header* line, whose characters are not hidden — the body below
        // it is. So look for a fold that starts within this line as well as one containing the caret.
        let line = text.lineRange(for: NSRange(location: min(offset, text.length), length: 0))
        guard let index = hidden.firstIndex(where: { NSLocationInRange(offset, $0)
                                                    || NSLocationInRange($0.location, line) }) else {
            return false
        }
        hidden.remove(at: index)
        invalidate()
        return true
    }

    /// Fold every node in a list — used for "fold everything at the top level".
    @discardableResult
    func foldAll(_ nodes: [SymbolNode], in text: NSString) -> Int {
        var count = 0
        for node in nodes where fold(node: node, in: text) { count += 1 }
        return count
    }

    @discardableResult
    func unfoldAll() -> Int {
        let count = hidden.count
        guard count > 0 else { return 0 }
        hidden = []
        invalidate()
        return count
    }

    /// Drop every fold because the text changed. See rule 2 in the file comment.
    func textChanged() {
        guard !hidden.isEmpty else { return }
        hidden = []
        invalidate()
    }

    /// Unfold whatever the selection reaches into. See rule 3.
    @discardableResult
    func revealIfNeeded(selection: NSRange) -> Bool {
        let touched = hidden.filter {
            NSIntersectionRange($0, selection).length > 0 || NSLocationInRange(selection.location, $0)
        }
        guard !touched.isEmpty else { return false }
        hidden.removeAll { range in touched.contains { $0 == range } }
        invalidate()
        return true
    }

    /// The characters a fold hides: from the end of the node's first line to the end of the node.
    ///
    /// The trailing newline is left visible, or the line after the fold would join the header line.
    private func bodyRange(of node: SymbolNode, in text: NSString) -> NSRange? {
        let length = text.length
        let start = max(0, min(node.start, length))
        let end = max(start, min(node.end, length))
        guard end > start else { return nil }
        let firstLine = text.lineRange(for: NSRange(location: start, length: 0))
        let bodyStart = NSMaxRange(firstLine)
        guard bodyStart < end else { return nil }        // a one-line node has no body to hide
        var bodyEnd = end
        // Do not swallow the newline that ends the fold: it separates the header from what follows.
        while bodyEnd > bodyStart,
              text.character(at: bodyEnd - 1) == 0x0A || text.character(at: bodyEnd - 1) == 0x0D {
            bodyEnd -= 1
        }
        guard bodyEnd > bodyStart else { return nil }
        return NSRange(location: bodyStart, length: bodyEnd - bodyStart)
    }

    /// Re-lay out the affected text and tell the owner.
    private func invalidate() {
        if let manager = textView?.layoutManager, let storage = textView?.textStorage {
            let whole = NSRange(location: 0, length: storage.length)
            manager.invalidateGlyphs(forCharacterRange: whole, changeInLength: 0,
                                     actualCharacterRange: nil)
            manager.invalidateLayout(forCharacterRange: whole, actualCharacterRange: nil)
            manager.ensureLayout(for: textView!.textContainer!)
        }
        onChange?()
    }

    // MARK: - NSLayoutManagerDelegate

    /// Mark the glyphs of folded characters as `.null` — laid out, measured as nothing, drawn not at all.
    ///
    /// `props` must be filled for the whole glyph range or AppKit uses its own; the loop therefore starts
    /// from the properties it was handed and only overrides what is hidden.
    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
                       properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
                       characterIndexes charIndexes: UnsafePointer<Int>,
                       font aFont: NSFont, forGlyphRange glyphRange: NSRange) -> Int {
        guard !hidden.isEmpty else { return 0 }          // 0 = "I did not interfere"
        var properties = [NSLayoutManager.GlyphProperty](repeating: .init(rawValue: 0), count: glyphRange.length)
        var changed = false
        for i in 0..<glyphRange.length {
            properties[i] = props[i]
            if isHidden(offset: charIndexes[i]) {
                properties[i] = .null
                changed = true
            }
        }
        guard changed else { return 0 }
        layoutManager.setGlyphs(glyphs, properties: &properties, characterIndexes: charIndexes,
                                font: aFont, forGlyphRange: glyphRange)
        return glyphRange.length
    }
}
