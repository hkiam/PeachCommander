// SPDX-License-Identifier: Apache-2.0
// TextScanning.swift - Small, language-agnostic text helpers for the editor/viewer:
// bracket matching and identifier extraction. Pure Foundation, so they are unit-tested
// here (used by PCApp's editor and viewer text views).

import Foundation

/// Extract the identifier (letters, digits, `_`, non-ASCII letters) around an index.
public enum IdentifierScanner {
    private static func isIdent(_ c: unichar) -> Bool {
        (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) ||   // A–Z a–z
        (c >= 0x30 && c <= 0x39) || c == 0x5F || c > 0x7F         // 0–9 _ (and non-ASCII letters)
    }

    /// The identifier at `index`, stepping back one if the index is just past a word.
    public static func word(in text: NSString, at index: Int) -> String? {
        let len = text.length
        guard len > 0 else { return nil }
        var i = min(max(index, 0), len - 1)
        if i == len || (i < len && !isIdent(text.character(at: i))), i > 0, isIdent(text.character(at: i - 1)) { i -= 1 }
        guard i < len, isIdent(text.character(at: i)) else { return nil }
        var lo = i, hi = i
        while lo > 0, isIdent(text.character(at: lo - 1)) { lo -= 1 }
        while hi + 1 < len, isIdent(text.character(at: hi + 1)) { hi += 1 }
        return text.substring(with: NSRange(location: lo, length: hi - lo + 1))
    }
}

/// Match (), [], {} by per-type depth counting (correct for well-formed code, cheap).
public enum BracketMatcher {
    private static let openToClose: [unichar: unichar] = [0x28: 0x29, 0x5B: 0x5D, 0x7B: 0x7D]
    private static let closeToOpen: [unichar: unichar] = [0x29: 0x28, 0x5D: 0x5B, 0x7D: 0x7B]

    /// The bracket next to `caret` and its partner, or nil. Prefers the bracket just
    /// *before* the caret (as after typing one), else the one just after it.
    public static func match(in text: NSString, caret: Int) -> (bracket: NSRange, partner: NSRange)? {
        let len = text.length
        for pos in [caret - 1, caret] where pos >= 0 && pos < len {
            let ch = text.character(at: pos)
            if let close = openToClose[ch], let m = scanForward(text, from: pos, open: ch, close: close) {
                return (NSRange(location: pos, length: 1), NSRange(location: m, length: 1))
            }
            if let open = closeToOpen[ch], let m = scanBackward(text, from: pos, open: open, close: ch) {
                return (NSRange(location: pos, length: 1), NSRange(location: m, length: 1))
            }
        }
        return nil
    }

    private static func scanForward(_ text: NSString, from: Int, open: unichar, close: unichar) -> Int? {
        var depth = 0, i = from
        let len = text.length
        while i < len {
            let c = text.character(at: i)
            if c == open { depth += 1 } else if c == close { depth -= 1; if depth == 0 { return i } }
            i += 1
        }
        return nil
    }

    private static func scanBackward(_ text: NSString, from: Int, open: unichar, close: unichar) -> Int? {
        var depth = 0, i = from
        while i >= 0 {
            let c = text.character(at: i)
            if c == close { depth += 1 } else if c == open { depth -= 1; if depth == 0 { return i } }
            i -= 1
        }
        return nil
    }
}
