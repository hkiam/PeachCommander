// ViewerMarks.swift - "Mark All" occurrence highlighting for the byte-oriented
// Lister's own custom-drawn text/code views (TextListerView, CodeListerView).
// Those views are NOT NSTextView-backed, so they can't reuse TextMarkController;
// instead marks live as (line, column-range) tuples because the views are
// monospaced and addressed by line/column. Marks are display-only and
// session-only — they never touch the file. Colors cycle through the same
// palette as the editor (TextMarkController.palette) so different search terms
// get different colors, giving the viewer parity with the editor.

import AppKit

/// One highlighted occurrence, addressed by line and character columns.
struct ViewerMark {
    let line: Int
    let colStart: Int   // 0-based character column
    let colEnd: Int     // exclusive
    let colorIndex: Int
    let groupID: Int
    let term: String
}

/// Adopted by the custom monospaced Lister views to gain uniform mark-all,
/// count, clear (all / by color), navigation and a grouped results list.
@MainActor
protocol ViewerMarkable: AnyObject {
    var viewerMarks: [ViewerMark] { get set }
    var nextMarkColorIndex: Int { get set }
    var nextMarkGroupID: Int { get set }
    /// Decoded text of a line (without trailing newline), for scanning + snippets.
    func lineTextForMark(_ i: Int) -> String
    var lineCountForMarks: Int { get }
    func requestMarkRedraw()
    func scrollMarkLineToVisible(_ line: Int)
}

@MainActor
extension ViewerMarkable {
    var hasViewerMarks: Bool { !viewerMarks.isEmpty }

    /// Distinct palette color indices currently in use (sorted).
    var colorsInUseForMarks: [Int] { Array(Set(viewerMarks.map(\.colorIndex))).sorted() }

    /// Marks in document order (line, then column) — for the bookmark list.
    var sortedViewerMarks: [ViewerMark] {
        viewerMarks.sorted { $0.line != $1.line ? $0.line < $1.line : $0.colStart < $1.colStart }
    }

    /// Searches in insertion order (one tab each): (id, term, colorIndex).
    var viewerGroups: [(id: Int, term: String, colorIndex: Int)] {
        var seen = Set<Int>(); var out: [(Int, String, Int)] = []
        for m in viewerMarks where !seen.contains(m.groupID) {
            seen.insert(m.groupID); out.append((m.groupID, m.term, m.colorIndex))
        }
        return out
    }

    /// Occurrences of one search, in document order.
    func viewerOccurrences(groupID: Int) -> [ViewerMark] {
        viewerMarks.filter { $0.groupID == groupID }
            .sorted { $0.line != $1.line ? $0.line < $1.line : $0.colStart < $1.colStart }
    }

    /// Remove all marks of one search.
    func removeGroup(_ id: Int) {
        let before = viewerMarks.count
        viewerMarks.removeAll { $0.groupID == id }
        if viewerMarks.count != before { requestMarkRedraw() }
    }

    // MARK: - Marks-panel adapter (custom-view path)

    /// Build the docked marks panel's view models from the current groups.
    func panelGroups() -> [MarksGroupVM] {
        let palette = TextMarkController.palette
        return viewerGroups.map { g in
            let occ = viewerOccurrences(groupID: g.id).map { mk in
                MarksOccurrenceVM(line: mk.line + 1,
                                  text: lineTextForMark(mk.line).trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return MarksGroupVM(id: g.id, term: g.term,
                                color: palette[min(g.colorIndex, palette.count - 1)], occurrences: occ)
        }
    }

    /// Reveal an occurrence addressed by (group, index) — for the panel.
    func reveal(groupID: Int, occurrenceIndex: Int) {
        let occ = viewerOccurrences(groupID: groupID)
        guard occ.indices.contains(occurrenceIndex) else { return }
        scrollMarkLineToVisible(occ[occurrenceIndex].line)
    }

    /// Remove a single occurrence (by its position among that search's marks).
    func removeOccurrence(groupID: Int, at index: Int) {
        let occ = viewerOccurrences(groupID: groupID)
        guard occ.indices.contains(index) else { return }
        let t = occ[index]
        if let i = viewerMarks.firstIndex(where: {
            $0.groupID == groupID && $0.line == t.line && $0.colStart == t.colStart
        }) {
            viewerMarks.remove(at: i); requestMarkRedraw()
        }
    }

    /// Case-insensitive occurrences of `term` on line `i`, as (colStart, colEnd).
    /// Column-based (not lowercased-string indices) so column math stays exact
    /// even when case folding changes a character's length.
    private func occurrences(of term: [Character], on line: Int) -> [(Int, Int)] {
        let hay = Array(lineTextForMark(line))
        guard !term.isEmpty, term.count <= hay.count else { return [] }
        var out: [(Int, Int)] = []
        var i = 0
        while i + term.count <= hay.count {
            var match = true
            for j in 0..<term.count where !hay[i + j].lowercased().elementsEqual(term[j].lowercased()) {
                match = false; break
            }
            if match { out.append((i, i + term.count)); i += term.count } else { i += 1 }
        }
        return out
    }

    /// Marks every case-insensitive occurrence of `term`. Uses `colorIndex` when
    /// given, otherwise the next palette color (cycled). Returns the number of
    /// occurrences found.
    @discardableResult
    func markAll(of term: String, colorIndex: Int? = nil) -> Int {
        let needle = Array(term)
        guard !needle.isEmpty else { return 0 }
        let index = (colorIndex ?? nextMarkColorIndex) % TextMarkController.palette.count
        let gid = nextMarkGroupID
        var found = 0
        for line in 0..<lineCountForMarks {
            for (lo, hi) in occurrences(of: needle, on: line) {
                viewerMarks.append(ViewerMark(line: line, colStart: lo, colEnd: hi,
                                              colorIndex: index, groupID: gid, term: term))
                found += 1
            }
        }
        if found > 0 {
            nextMarkGroupID += 1
            if colorIndex == nil { nextMarkColorIndex += 1 }
            requestMarkRedraw()
        }
        return found
    }

    /// Count occurrences without marking (for a "Count" action).
    func countOccurrences(of term: String) -> Int {
        let needle = Array(term)
        guard !needle.isEmpty else { return 0 }
        var total = 0
        for line in 0..<lineCountForMarks { total += occurrences(of: needle, on: line).count }
        return total
    }

    func clearAllMarks() {
        guard !viewerMarks.isEmpty else { return }
        viewerMarks.removeAll(); requestMarkRedraw()
    }

    func clearMarks(colorIndex: Int) {
        let before = viewerMarks.count
        viewerMarks.removeAll { $0.colorIndex == colorIndex }
        if viewerMarks.count != before { requestMarkRedraw() }
    }

    /// A short single-line snippet at a mark (for the bookmark list).
    func snippet(for mark: ViewerMark) -> String {
        lineTextForMark(mark.line).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Draw the mark backgrounds for the visible line range. Call from `draw()`
    /// after the background fill and before the text (colors are translucent).
    func drawViewerMarks(first: Int, last: Int, charW: CGFloat, lineHeight: CGFloat) {
        guard !viewerMarks.isEmpty else { return }
        let palette = TextMarkController.palette
        for m in viewerMarks where m.line >= first && m.line <= last {
            palette[min(m.colorIndex, palette.count - 1)].setFill()
            NSRect(x: 4 + CGFloat(m.colStart) * charW, y: CGFloat(m.line) * lineHeight,
                   width: CGFloat(m.colEnd - m.colStart) * charW, height: lineHeight).fill()
        }
    }
}
