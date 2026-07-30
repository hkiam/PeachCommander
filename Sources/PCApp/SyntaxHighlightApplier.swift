// SyntaxHighlightApplier.swift - Applies syntax-highlight token colors to an
// NSTextStorage, shared by the editor and the viewer's read-only text/code view.
// Centralizes the char-index → UTF-16 offset remapping so token ranges land on
// the right glyphs regardless of multi-byte characters.

import AppKit
import PCFoundation

enum SyntaxHighlightApplier {
    /// Reset the foreground to the default text color, then color every token of
    /// `string` in `language`. No-op coloring for very large storages (kept cheap).
    static func apply(_ string: String, language: SyntaxLanguage?, to storage: NSTextStorage) {
        let full = NSRange(location: 0, length: storage.length)
        storage.removeAttribute(.foregroundColor, range: full)
        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: full)
        guard let language, storage.length <= 2_000_000 else { return }

        let chars = Array(string)
        // char index → UTF-16 offset (prefix sums), so token ranges map in O(1).
        var utf16Offset = [Int](repeating: 0, count: chars.count + 1)
        var acc = 0
        for i in 0..<chars.count { utf16Offset[i] = acc; acc += String(chars[i]).utf16.count }
        utf16Offset[chars.count] = acc

        for token in SyntaxHighlighter.tokens(string, language: language) {
            let lo = utf16Offset[token.range.lowerBound]
            let hi = utf16Offset[token.range.upperBound]
            if hi > lo {
                storage.addAttribute(.foregroundColor, value: SyntaxTheme.color(token.kind),
                                     range: NSRange(location: lo, length: hi - lo))
            }
        }
    }
}
