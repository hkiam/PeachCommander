// NeonEditorHighlighter.swift - Incremental tree-sitter highlighting for the
// editor's live NSTextView, driven by Neon. Neon owns the parse tree and
// re-highlights only the affected ranges as the user types (scaling to large
// documents), applying foreground colors via SyntaxCaptureColors. Marks use
// backgroundColor, so they coexist untouched.
//
// The viewer's read-only path uses the one-shot TreeSitterHighlighter instead;
// both share TreeSitterLanguages + SyntaxCaptureColors.

import AppKit
import Neon
import SwiftTreeSitter

@MainActor
final class NeonEditorHighlighter {
    private let highlighter: TextViewHighlighter

    /// Attach Neon to `textView` for the grammar matching `ext`. Returns nil when
    /// the extension isn't tree-sitter-supported or the highlighter can't be built.
    init?(textView: NSTextView, ext: String) {
        guard let config = TreeSitterLanguages.configuration(forExtension: ext) else { return nil }
        let configuration = TextViewHighlighter.Configuration(
            languageConfiguration: config,
            attributeProvider: { token in [.foregroundColor: SyntaxCaptureColors.color(for: token.name)] },
            locationTransformer: { _ in nil }
        )
        guard let hl = try? TextViewHighlighter(textView: textView, configuration: configuration) else { return nil }
        highlighter = hl
        highlighter.observeEnclosingScrollView()
    }

    /// Re-highlight everything (after the document text was replaced wholesale,
    /// e.g. reload / reformat / encoding change).
    func invalidateAll() { highlighter.invalidate(.all) }
}
