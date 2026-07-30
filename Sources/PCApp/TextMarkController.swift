// TextMarkController.swift - Notepad++-style "mark all" for an NSTextView
// (viewer + editor). Highlights every occurrence of a term in a palette color
// (cycled so different terms get different colors), counts them, lets you jump
// between marks, and clear them (all or by color). Marks are display-only and
// session-only — they never change the file and are not persisted. Because the
// editor re-runs syntax highlighting, `reapply()` must be called afterwards.

import AppKit
import PCFoundation

@MainActor
final class TextMarkController {
    struct Mark { let range: NSRange; let colorIndex: Int; let groupID: Int; let term: String }
    /// One "Mark All" search, in insertion order (drives the panel's tabs).
    struct Group { let id: Int; let term: String; let colorIndex: Int }

    /// Shared, user-extensible highlight palette (index 0 used first, then
    /// cycled). Backed by ``MarkPalette`` so custom colors are available to both
    /// the editor and the viewer.
    static var palette: [NSColor] { MarkPalette.colors }

    private weak var textView: NSTextView?
    private(set) var marks: [Mark] = []
    /// The color index that would be used next when no explicit color is chosen
    /// (read by the Mark dialog to pre-select a sensible default).
    private(set) var nextColorIndex = 0
    private var nextGroupID = 0

    /// Searches in insertion order (one tab each).
    var groups: [Group] {
        var seen = Set<Int>(); var out: [Group] = []
        for m in marks where !seen.contains(m.groupID) {
            seen.insert(m.groupID)
            out.append(Group(id: m.groupID, term: m.term, colorIndex: m.colorIndex))
        }
        return out
    }

    /// Occurrences of one search, in document order.
    func occurrences(groupID: Int) -> [Mark] {
        marks.filter { $0.groupID == groupID }.sorted { $0.range.location < $1.range.location }
    }

    /// Remove all marks of one search.
    func removeGroup(_ id: Int) {
        let matching = marks.filter { $0.groupID == id }
        guard !matching.isEmpty else { return }
        removeAttributes(for: matching)
        marks.removeAll { $0.groupID == id }
    }

    /// Remove a single occurrence (by its position among that search's marks).
    func removeOccurrence(groupID: Int, at index: Int) {
        let occ = occurrences(groupID: groupID)
        guard occ.indices.contains(index) else { return }
        let target = occ[index].range
        removeAttributes(for: [occ[index]])
        if let i = marks.firstIndex(where: { $0.groupID == groupID && NSEqualRanges($0.range, target) }) {
            marks.remove(at: i)
        }
    }

    init(textView: NSTextView) { self.textView = textView }

    // MARK: - Marks-panel adapter (shared by editor + viewer NSTextView path)

    /// Build the docked marks panel's view models from the current groups.
    func panelGroups() -> [MarksGroupVM] {
        let palette = Self.palette
        return groups.map { g in
            let occ = occurrences(groupID: g.id).map { m in
                MarksOccurrenceVM(line: lineNumber(of: m.range.location), text: snippet(for: m.range))
            }
            return MarksGroupVM(id: g.id, term: g.term,
                                color: palette[min(g.colorIndex, palette.count - 1)], occurrences: occ)
        }
    }

    /// Reveal an occurrence addressed by (group, index) — for the panel.
    func reveal(groupID: Int, occurrenceIndex: Int) {
        let occ = occurrences(groupID: groupID)
        guard occ.indices.contains(occurrenceIndex) else { return }
        reveal(occ[occurrenceIndex].range)
    }

    /// Whether any color currently has marks (drives menu enablement).
    var hasMarks: Bool { !marks.isEmpty }

    /// Human names for palette colors (for the "Clear by color" menu).
    static func colorName(_ i: Int) -> String { MarkPalette.name(i) }

    /// Distinct color indices that currently have marks (sorted).
    var colorsInUse: [Int] { Array(Set(marks.map(\.colorIndex))).sorted() }
    /// Marks in document order (for the marks/bookmark list).
    var sortedMarks: [Mark] { marks.sorted { $0.range.location < $1.range.location } }

    /// Count occurrences of `term` without marking (for a "Count" action).
    func count(of term: String) -> Int {
        guard let tv = textView, !term.isEmpty else { return 0 }
        return OccurrenceFinder.ranges(of: term, in: tv.string).count
    }

    /// Select + scroll to a mark's range (used by the marks list to jump).
    func reveal(_ range: NSRange) {
        guard let tv = textView, NSMaxRange(range) <= (tv.textStorage?.length ?? 0) else { return }
        tv.setSelectedRange(range)
        tv.scrollRangeToVisible(range)
        tv.window?.makeFirstResponder(tv)
    }

    /// A short single-line snippet of the text at `range` (for the list).
    func snippet(for range: NSRange) -> String {
        guard let s = textView?.string as NSString?, NSMaxRange(range) <= s.length else { return "" }
        let line = s.lineRange(for: range)
        return s.substring(with: line).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 1-based line number of a location (for the list).
    func lineNumber(of location: Int) -> Int {
        guard let s = textView?.string as NSString?, location <= s.length else { return 0 }
        // 1-based line = 1 + number of newlines strictly before `location`.
        var newlines = 0
        var i = 0
        while i < location { if s.character(at: i) == 10 { newlines += 1 }; i += 1 }
        return newlines + 1
    }

    /// Marks every occurrence of `term` (case-insensitive). Uses `colorIndex`
    /// when given, otherwise the next palette color (cycled). Returns the number
    /// of occurrences found.
    @discardableResult
    func markAll(of term: String, colorIndex: Int? = nil) -> Int {
        guard let tv = textView, !term.isEmpty else { return 0 }
        let index = (colorIndex ?? nextColorIndex) % Self.palette.count
        let ranges = OccurrenceFinder.ranges(of: term, in: tv.string)
        guard !ranges.isEmpty else { return 0 }
        let gid = nextGroupID; nextGroupID += 1
        for r in ranges { marks.append(Mark(range: r, colorIndex: index, groupID: gid, term: term)) }
        if colorIndex == nil { nextColorIndex += 1 }
        reapply()
        return ranges.count
    }

    /// Re-apply the background color of every mark (call after re-highlighting).
    func reapply() {
        guard let storage = textView?.textStorage else { return }
        let length = storage.length
        for mark in marks where NSMaxRange(mark.range) <= length {
            storage.addAttribute(.backgroundColor, value: Self.palette[mark.colorIndex], range: mark.range)
        }
    }

    /// Remove all marks (any color).
    func clearAll() {
        removeAttributes(for: marks)
        marks.removeAll()
    }

    /// Remove only the marks drawn in the given palette color index.
    func clear(colorIndex: Int) {
        let (matching, rest) = marks.reduce(into: ([Mark](), [Mark]())) {
            $1.colorIndex == colorIndex ? $0.0.append($1) : $0.1.append($1)
        }
        removeAttributes(for: matching)
        marks = rest
    }

    /// The next mark range at or after `location` (wraps around), or nil.
    func nextMark(after location: Int) -> NSRange? {
        let sorted = marks.map(\.range).sorted { $0.location < $1.location }
        return sorted.first { $0.location > location } ?? sorted.first
    }

    /// The previous mark range before `location` (wraps around), or nil.
    func previousMark(before location: Int) -> NSRange? {
        let sorted = marks.map(\.range).sorted { $0.location < $1.location }
        return sorted.last { $0.location < location } ?? sorted.last
    }

    private func removeAttributes(for marks: [Mark]) {
        guard let storage = textView?.textStorage else { return }
        let length = storage.length
        for mark in marks where NSMaxRange(mark.range) <= length {
            storage.removeAttribute(.backgroundColor, range: mark.range)
        }
    }
}
