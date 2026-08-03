// SPDX-License-Identifier: Apache-2.0
// EditorLineIndex.swift - Where each line starts, in the units the layout manager speaks (F-355).
//
// Deliberately *not* PCVFS's `LineIndexer`, which is the right tool for a file on disk and the wrong
// one here: it returns **byte** offsets, while NSLayoutManager and NSRange work in UTF-16 code units.
// The two agree exactly as long as the text is ASCII and diverge on the first umlaut — the kind of bug
// that shows up in one language's config file and nowhere else. Hence a second, small index rather
// than a conversion layer over the first.

import Foundation

/// The start offset of every line, and the line a given offset belongs to.
struct EditorLineIndex {
    /// UTF-16 offsets of each line's first character; always starts with 0.
    private(set) var starts: [Int] = [0]

    var count: Int { starts.count }

    init() {}

    init(text: NSString) { rebuild(from: text) }

    /// Rescan `text`. Called on edit rather than per draw: scanning a large file once costs
    /// milliseconds, and scrolling repaints many times a second.
    mutating func rebuild(from text: NSString) {
        var result = [0]
        var index = 0
        while index < text.length {
            index = NSMaxRange(text.lineRange(for: NSRange(location: index, length: 0)))
            if index < text.length { result.append(index) }
        }
        starts = result
    }

    /// The 1-based line containing `offset`, by binary search.
    ///
    /// Clamped rather than trapping: callers pass a selection offset, and a selection at the very end
    /// of the text is one past the last character.
    func line(containing offset: Int) -> Int {
        var low = 0, high = starts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if starts[mid] <= offset { low = mid } else { high = mid - 1 }
        }
        return low + 1
    }
}
