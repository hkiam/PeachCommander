// SPDX-License-Identifier: Apache-2.0
// GutterAnnotations.swift — per-line annotations for the editor's gutter (F-426).
//
// A plugin knows something about each line — who last touched it, whether a test covered it — and cannot
// draw it: the gutter belongs to the host's editor, and a plugin shipping its own text view would be a
// second editor in the same application. So the plugin sends text and the host draws it, which makes the
// wire format the whole interface: one record per source line, in order from line 1, `text` or
// `text\ttooltip`.
//
// The parsing lives here rather than in the bridge because it is the part that can be wrong in ways worth
// a test: a record count that disagrees with the file, a stray carriage return from a plugin that built
// its buffer on Windows line endings, a tab inside a tooltip.

import Foundation

/// One line's annotation: what the gutter shows, and what a hover explains.
public struct GutterAnnotation: Sendable, Equatable {
    public let text: String
    public let tooltip: String

    public init(text: String, tooltip: String = "") {
        self.text = text
        self.tooltip = tooltip
    }

    public var isEmpty: Bool { text.isEmpty && tooltip.isEmpty }
}

public enum GutterAnnotations {
    /// More than this many lines is refused rather than allocated: it is a plugin sending a buffer for a
    /// file nobody reads line by line, and the gutter can only ever draw the few dozen lines in view.
    public static let lineLimit = 100_000

    /// Parse the wire format. Index 0 is line 1; a record with no text leaves that line blank.
    ///
    /// `"\r\n"` is normalized first: it is a *single* Character in Swift, so splitting on `"\n"` never sees
    /// it and a buffer built with Windows line endings would arrive as one enormous annotation (the F-257
    /// trap, which has now cost this project four parsers).
    public static func parse(_ raw: String) -> [GutterAnnotation] {
        guard !raw.isEmpty else { return [] }
        let normalized = raw.contains("\r\n") ? raw.replacingOccurrences(of: "\r\n", with: "\n") : raw
        var records = normalized.components(separatedBy: "\n")
        // A trailing newline is a terminator, not an empty last line.
        if records.last == "" { records.removeLast() }
        if records.count > lineLimit { records = Array(records.prefix(lineLimit)) }
        return records.map { record in
            guard let tab = record.firstIndex(of: "\t") else {
                return GutterAnnotation(text: record.trimmingCharacters(in: .whitespaces))
            }
            // Only the first tab separates: a tooltip may contain tabs, and cutting at the last one would
            // move part of the tooltip into the visible column.
            return GutterAnnotation(text: String(record[record.startIndex..<tab])
                                        .trimmingCharacters(in: .whitespaces),
                                    tooltip: String(record[record.index(after: tab)...]))
        }
    }

    /// The annotation for a 1-based line number, or nil.
    public static func annotation(_ annotations: [GutterAnnotation], line: Int) -> GutterAnnotation? {
        guard line >= 1, line <= annotations.count else { return nil }
        let annotation = annotations[line - 1]
        return annotation.isEmpty ? nil : annotation
    }

    /// The width the gutter needs for these annotations, measured on the widest one rather than assumed.
    ///
    /// Capped, because one pathological line must not push the text out of the window; the rest is
    /// truncated when drawn.
    public static func columnWidth(_ annotations: [GutterAnnotation],
                                   measure: (String) -> CGFloat,
                                   cap: CGFloat = 260) -> CGFloat {
        let widest = annotations.reduce(CGFloat(0)) { max($0, $1.text.isEmpty ? 0 : measure($1.text)) }
        return min(cap, widest)
    }
}
