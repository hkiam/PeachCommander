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
import PCFoundation

final class LineNumberRuler: NSRulerView {
    /// Where the lines start. See `EditorLineIndex` for why this is not PCVFS's LineIndexer.
    private var index = EditorLineIndex()
    /// Whether a character offset is currently folded away. Set by the editor; without it the numbers of
    /// hidden lines were all drawn at the header line's y — folded text disappears, its line numbers pile
    /// up on one row (F-371). Not named `isHidden`: a ruler is an NSView, and that name is taken.
    var isOffsetFolded: ((Int) -> Bool)?
    private var digitsShown = 2
    private weak var editorTextView: NSTextView?

    // MARK: - Per-line annotations (F-426)

    /// What a plugin knows about each line — blame, coverage — drawn left of the numbers. Index 0 is line 1.
    private var annotations: [GutterAnnotation] = []
    private var annotationWidth: CGFloat = 0
    /// Called with the 1-based line whose annotation was clicked.
    var onAnnotationClicked: ((Int) -> Void)?
    /// What the annotation column is (shown as the gutter's tooltip), e.g. "Blame".
    private var annotationTitle: String = ""

    /// Show these annotations, or none. The gutter widens to fit the widest one and the owner is told, so
    /// the text container is inset in step — the same handshake the digits use.
    func setAnnotations(_ annotations: [GutterAnnotation], title: String) {
        self.annotations = annotations
        self.annotationTitle = title
        let font = Self.annotationFont
        annotationWidth = GutterAnnotations.columnWidth(annotations, measure: {
            ($0 as NSString).size(withAttributes: [.font: font]).width
        })
        if annotationWidth > 0 { annotationWidth += Self.padding }
        toolTip = annotations.isEmpty ? nil : title
        updateThickness(force: true)
        needsDisplay = true
    }

    var hasAnnotations: Bool { !annotations.isEmpty }

    private static let annotationFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)

    /// The gutter's width: digits, plus the annotation column when there is one.
    private func updateThickness(force: Bool) {
        let digits = max(2, String(index.count).count)
        let wanted = CGFloat(digits) * 8 + Self.padding * 2 + annotationWidth
        guard force || digits != digitsShown || wanted != ruleThickness else { return }
        digitsShown = digits
        ruleThickness = wanted
        onThicknessChanged?(ruleThickness)
    }

    /// Which line is at a point in the ruler — the inverse of the drawing loop, used by the click.
    private func line(at point: NSPoint) -> Int? {
        guard let textView = editorTextView, let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return nil }
        let visible = scrollView?.contentView.bounds ?? .zero
        let inset = textView.textContainerInset.height
        // The ruler's y runs the same way as the text view's here, so undo the same shift the drawing adds.
        let textY = point.y + visible.minY - inset
        let glyph = layoutManager.glyphIndex(for: NSPoint(x: 0, y: textY), in: container)
        let offset = layoutManager.characterIndexForGlyph(at: glyph)
        return line(containing: offset)
    }

    override func mouseDown(with event: NSEvent) {
        guard !annotations.isEmpty, let onAnnotationClicked else {
            super.mouseDown(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        guard let line = line(at: point), GutterAnnotations.annotation(annotations, line: line) != nil else {
            super.mouseDown(with: event)
            return
        }
        onAnnotationClicked(line)
    }

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
        updateThickness(force: false)
        needsDisplay = true
    }

    @objc private func textChanged() { refresh() }

    private func rebuildLineStarts() {
        index.rebuild(from: (editorTextView?.string ?? "") as NSString)
    }

    private func line(containing offset: Int) -> Int { index.line(containing: offset) }

    /// Click the annotation of a 1-based line, for the harness (F-426). Returns false when that line has
    /// none — which is the answer to "does the click do anything here".
    func automationClickAnnotation(line: Int) -> Bool {
        guard GutterAnnotations.annotation(annotations, line: line) != nil,
              let onAnnotationClicked else { return false }
        onAnnotationClicked(line)
        return true
    }

    /// What the gutter holds, for the harness: the width it took and the first annotations, so a scenario
    /// can assert that a plugin's blame actually reached the gutter rather than only that a window opened.
    func automationDump() -> String {
        var lines = ["thickness=\(Int(ruleThickness))", "annotations=\(annotations.count)",
                     "title=\(annotationTitle)"]
        for (index, annotation) in annotations.prefix(12).enumerated() where !annotation.isEmpty {
            lines.append("line \(index + 1)=\(annotation.text)\ttip=\(annotation.tooltip)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = editorTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        // Paint the gutter strip only, never `rect`. A ruler's *frame* is not its thickness: filling the
        // rect AppKit hands in covered the whole content area, so the file looked empty while the
        // numbers next to it counted its lines correctly — the strongest hint that this was a painting
        // problem and not a loading one.
        // Tooltip rects are re-added per draw below, so the old ones have to go — otherwise scrolling
        // leaves the previous lines' tooltips behind at the same y (F-426).
        if annotationWidth > 0 { removeAllToolTips() }
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

            // The annotation, left of the numbers and dimmer than the text: it is context, not content
            // (F-426). Clipped to its own column so a long one cannot run under the line number.
            if annotationWidth > 0,
               let annotation = GutterAnnotations.annotation(annotations, line: lineNumber) {
                let column = NSRect(x: Self.padding, y: y,
                                    width: annotationWidth - Self.padding, height: fragment.height)
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(rect: column).addClip()
                (annotation.text as NSString).draw(
                    at: NSPoint(x: column.minX, y: y),
                    withAttributes: [.font: Self.annotationFont,
                                     .foregroundColor: Theme.current.listText.withAlphaComponent(
                                         lineNumber == cursorLine ? 0.8 : 0.5)])
                NSGraphicsContext.restoreGraphicsState()
                if !annotation.tooltip.isEmpty {
                    // Per-line tooltips, rebuilt for the visible lines only: the alternative is one
                    // tooltip for the whole gutter, which cannot say who touched *this* line.
                    addToolTip(column, owner: annotation.tooltip as NSString, userData: nil)
                }
            }

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
