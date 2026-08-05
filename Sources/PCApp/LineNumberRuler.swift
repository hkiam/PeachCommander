// SPDX-License-Identifier: Apache-2.0
// LineNumberRuler.swift - Line numbers in the editor's gutter (F-355).
//
// The editor had a symbol sidebar, a minimap, marks and "go to line" — and no line numbers, which is
// the one thing every compiler error, every stack trace and every code review comment refers to. This
// is the missing half of "go to line": knowing which line you are on without counting.
//
// An NSRulerView rather than a column of labels: AppKit already scrolls, sizes and repaints a ruler in
// step with the text view, and a hand-built gutter has to be kept in sync with wrapping, folding and
// the scroll position by hand — three chances to drift.
//
// Wrapped lines are numbered once, at their first fragment, because the number refers to the line in
// the file and not to a row on screen. That is also what "go to line 42" means.

import AppKit

final class LineNumberRuler: NSRulerView {
    /// Where the lines start. See `EditorLineIndex` for why this is not PCVFS's LineIndexer.
    private var index = EditorLineIndex()
    /// Whether a character offset is currently folded away. Set by the editor; without it the numbers of
    /// hidden lines were all drawn at the header line's y — folded text disappears, its line numbers pile
    /// up on one row (F-371). Not named `isHidden`: a ruler is an NSView, and that name is taken.
    var isOffsetFolded: ((Int) -> Bool)?
    private var digitsShown = 2
    private weak var editorTextView: NSTextView?

    /// Space either side of the digits.
    private static let padding: CGFloat = 6

    /// Reports the gutter's width whenever it changes.
    ///
    /// The owner uses it to inset the text container. NSScrollView is supposed to inset the content for
    /// a ruler by itself and, with this text view's unbounded container and manual sizing, does not:
    /// the first characters of every line sat behind the gutter no matter which order the ruler,
    /// the client view and the document view were assigned in. Rather than keep guessing at AppKit's
    /// ordering rules, the inset is stated explicitly here — one number, in one place, kept in step
    /// with the thickness it comes from.
    var onThicknessChanged: ((CGFloat) -> Void)?

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.editorTextView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        // `clientView` is set by the owner *after* the ruler is attached to the scroll view: setting it
        // here, before the scroll view knows about the ruler, made the ruler size itself to the whole
        // content area and paint over the text.
        ruleThickness = 40
        NotificationCenter.default.addObserver(
            self, selector: #selector(textChanged),
            name: NSText.didChangeNotification, object: textView)
        rebuildLineStarts()
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { NotificationCenter.default.removeObserver(self) }

    /// Re-scan and, when the line count crosses a power of ten, widen the gutter.
    ///
    /// Public so the owner can call it after replacing the whole text — a programmatic change (reload
    /// from disk, format, a line operation) does not post `NSText.didChangeNotification`.
    func refresh() {
        rebuildLineStarts()
        let digits = max(2, String(index.count).count)
        if digits != digitsShown {
            digitsShown = digits
            ruleThickness = CGFloat(digits) * 8 + Self.padding * 2
            onThicknessChanged?(ruleThickness)
        }
        needsDisplay = true
    }

    @objc private func textChanged() { refresh() }

    private func rebuildLineStarts() {
        index.rebuild(from: (editorTextView?.string ?? "") as NSString)
    }

    private func line(containing offset: Int) -> Int { index.line(containing: offset) }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = editorTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        // Paint the gutter strip only, never `rect`. A ruler's *frame* is not its thickness: filling the
        // rect AppKit hands in covered the whole content area, so the file looked empty while the
        // numbers next to it counted its lines correctly — the strongest hint that this was a painting
        // problem and not a loading one.
        let strip = NSRect(x: 0, y: rect.minY, width: ruleThickness, height: rect.height)
        Theme.current.listBackground.setFill()
        strip.fill()
        // A hairline against the text, so the gutter reads as a margin rather than as content.
        Theme.current.columnSeparator.setFill()
        NSRect(x: strip.maxX - 1, y: rect.minY, width: 1, height: rect.height).fill()

        let inset = textView.textContainerInset.height
        let visible = scrollView?.contentView.bounds ?? .zero
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visible, in: container)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        let cursorLine = line(containing: textView.selectedRange().location)
        var attributes: [NSAttributedString.Key: Any] = [.font: font]

        // Walk the *lines* in view, not the glyph fragments: a wrapped line must show one number, at
        // the top of its first fragment.
        var lineNumber = line(containing: charRange.location)
        var offset = index.starts[lineNumber - 1]
        let text = textView.string as NSString
        while offset <= NSMaxRange(charRange), lineNumber <= index.count {
            let fragment = layoutManager.lineFragmentRect(
                forGlyphAt: layoutManager.glyphIndexForCharacter(at: min(offset, max(0, text.length - 1))),
                effectiveRange: nil)
            let y = fragment.minY + inset - visible.minY
            // The current line stands out: this is what makes a gutter useful while typing, rather
            // than only when reading an error message.
            attributes[.foregroundColor] = lineNumber == cursorLine
                ? Theme.current.listText : Theme.current.listText.withAlphaComponent(0.45)
            let label = String(lineNumber) as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(at: NSPoint(x: ruleThickness - size.width - Self.padding, y: y),
                       withAttributes: attributes)

            lineNumber += 1
            guard lineNumber <= index.count else { break }
            offset = index.starts[lineNumber - 1]
            // Skip the lines a fold hides. Their numbers are simply not shown, which is what every editor
            // does and what makes the jump in the numbering the sign that something is collapsed.
            while let isOffsetFolded, lineNumber <= index.count,
                  isOffsetFolded(index.starts[lineNumber - 1]) {
                lineNumber += 1
                if lineNumber <= index.count { offset = index.starts[lineNumber - 1] }
            }
            guard lineNumber <= index.count else { break }
        }
    }
}
