// SPDX-License-Identifier: Apache-2.0
// TreeSitterHighlighter.swift - One-shot tree-sitter highlighting for read-only
// NSTextView content (the viewer's text/code path, and the editor's fallback
// when Neon isn't driving). Languages come from TreeSitterLanguages; the editor
// uses Neon's incremental highlighter instead (see NeonEditorHighlighter).
//
// Note: SwiftTreeSitter's parse(_:) uses UTF-16LE, so NamedRange.range is already
// a UTF-16 NSRange — directly usable against the UTF-16 NSTextStorage.

import AppKit
import SwiftTreeSitter

enum TreeSitterHighlighter {
    /// Whether a file extension is handled by tree-sitter (vs. the built-in lexer).
    @MainActor static func canHighlight(ext: String) -> Bool {
        TreeSitterLanguages.canHighlight(ext: ext)
    }

    /// Apply tree-sitter highlighting to `storage`. Returns false (untouched) when
    /// the extension isn't handled or parsing fails, so the caller can fall back.
    @MainActor @discardableResult
    static func apply(_ text: String, ext: String, to storage: NSTextStorage) -> Bool {
        guard let config = TreeSitterLanguages.configuration(forExtension: ext),
              let query = config.queries[.highlights] else { return false }
        let parser = Parser()
        do { try parser.setLanguage(config.language) } catch { return false }
        guard let tree = parser.parse(text) else { return false }

        let length = storage.length
        storage.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: length))
        storage.addAttribute(.foregroundColor, value: NSColor.textColor,
                             range: NSRange(location: 0, length: length))

        let cursor = query.execute(in: tree)
        for named in cursor.resolve(with: .init(string: text)).highlights() {
            let r = named.range
            guard r.location >= 0, NSMaxRange(r) <= length else { continue }
            storage.addAttribute(.foregroundColor, value: SyntaxCaptureColors.color(for: named.name), range: r)
        }
        return true
    }
}

/// Maps tree-sitter highlight capture names to colors. Shared by the one-shot
/// highlighter and the Neon-driven editor highlighter.
enum SyntaxCaptureColors {
    static func color(for name: String) -> NSColor {
        let p = Theme.currentSyntax
        switch name.split(separator: ".").first.map(String.init) ?? name {
        case "comment": return p.comment
        case "string": return name.contains("special.key") ? p.property : p.string
        case "number", "float": return p.number
        case "constant", "boolean": return p.constant
        case "escape": return p.escape
        case "keyword", "conditional", "repeat", "include", "operator": return p.keyword
        case "function", "method": return p.function
        case "type", "constructor": return p.type
        case "property", "attribute", "field": return p.property
        default: return Theme.current.listText
        }
    }
}
