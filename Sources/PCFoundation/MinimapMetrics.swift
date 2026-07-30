// SPDX-License-Identifier: Apache-2.0
// MinimapMetrics.swift - Per-line indent/length metrics for the editor/viewer
// minimap. Pure text scanning, so it is unit-tested here; MinimapView (PCApp) draws
// a block per line from these metrics.

import Foundation

public enum MinimapMetrics {
    /// For each line: leading whitespace columns and trailing content length (both
    /// capped), plus the maximum column count seen (clamped to a drawable range).
    public static func lineMetrics(_ text: String) -> (lines: [(indent: Int, length: Int)], maxCols: Int) {
        let ns = text as NSString
        var result: [(Int, Int)] = []
        var maxLen = 60
        var i = 0
        let len = ns.length
        while i < len {
            let lineRange = ns.lineRange(for: NSRange(location: i, length: 0))
            var end = NSMaxRange(lineRange)
            while end > lineRange.location, ns.character(at: end - 1) == 0x0A || ns.character(at: end - 1) == 0x0D { end -= 1 }
            var indent = 0
            var p = lineRange.location
            while p < end, ns.character(at: p) == 0x20 || ns.character(at: p) == 0x09 { indent += 1; p += 1 }
            let contentLen = max(0, end - p)
            result.append((min(indent, 200), min(contentLen, 200)))
            maxLen = max(maxLen, indent + contentLen)
            i = NSMaxRange(lineRange)
            if lineRange.length == 0 { break }
        }
        // A trailing newline yields one more (empty) line.
        if len > 0, ns.character(at: len - 1) == 0x0A || ns.character(at: len - 1) == 0x0D { result.append((0, 0)) }
        return (result, min(max(maxLen, 40), 140))
    }
}
