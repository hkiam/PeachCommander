// SPDX-License-Identifier: Apache-2.0
// UTF16OffsetTable.swift - Grapheme index → UTF-16 offset, in one pass.
//
// Attributed text is addressed in UTF-16 units; a tokenizer, a diff and a search all address the same
// text in *characters* (grapheme clusters). Mapping between them is one line of Swift —
// `String(chars[0..<i]).utf16.count` — and that line is quadratic: it builds a copy of everything before
// the position, for every position asked about.
//
// It froze the viewer. A 2 MB JSON Lines file has thirty records of ~68,000 characters each; syntax
// highlighting produces thousands of tokens per line, and the code view asked for the offset of every one
// of them while drawing — about 10^8 character copies per drawn line, on the main thread, for as long as
// the reader kept scrolling. Measured in a live sample of the hung app: 80% of it inside
// `String.append(contentsOf:)` under `CodeListerView.attributedLine`.
//
// One pass over the line builds the table; each lookup is then an array read. The common case is cheaper
// still: a line whose characters are all one UTF-16 unit needs no table at all, because the offset *is*
// the index — which is every ASCII line, i.e. most code and most logs.

import Foundation

/// Maps character (grapheme) indices of one string to UTF-16 offsets.
public struct UTF16OffsetTable {
    /// `prefix[i]` is the UTF-16 length of the first `i` characters; nil when every character is a single
    /// UTF-16 unit, in which case index and offset are the same number.
    private let prefix: [Int]?
    private let count: Int

    public init(_ characters: [Character]) {
        count = characters.count
        var needsTable = false
        for character in characters where character.utf16.count != 1 {
            needsTable = true
            break
        }
        guard needsTable else { prefix = nil; return }
        var table = [Int](repeating: 0, count: characters.count + 1)
        var total = 0
        for (index, character) in characters.enumerated() {
            table[index] = total
            total += character.utf16.count
        }
        table[characters.count] = total
        prefix = table
    }

    public init(_ string: String) { self.init(Array(string)) }

    /// The UTF-16 offset of character `index` (0…count). Out-of-range indices clamp, so a caller working
    /// from a token range that has drifted cannot produce an NSRange outside the string.
    public func offset(at index: Int) -> Int {
        let clamped = max(0, min(index, count))
        guard let prefix else { return clamped }
        return prefix[clamped]
    }

    /// The UTF-16 range for the character range `lower..<upper`.
    public func range(_ lower: Int, _ upper: Int) -> NSRange {
        let start = offset(at: lower)
        let end = offset(at: max(lower, upper))
        return NSRange(location: start, length: end - start)
    }
}
