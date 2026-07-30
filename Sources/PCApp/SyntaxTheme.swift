// SPDX-License-Identifier: Apache-2.0
// SyntaxTheme.swift - The single source of truth for syntax-highlight token
// colors, shared by the editor (NSTextView) and the viewer's code view
// (CodeListerView), which previously each carried an identical copy.

import AppKit
import PCFoundation

enum SyntaxTheme {
    /// Foreground color for a syntax token kind (theme-aware).
    static func color(_ kind: TokenKind) -> NSColor {
        let p = Theme.currentSyntax
        switch kind {
        case .comment: return p.comment
        case .string: return p.string
        case .number: return p.number
        case .keyword: return p.keyword
        }
    }
}
