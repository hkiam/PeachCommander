// SPDX-License-Identifier: Apache-2.0
// MarkdownFileType.swift — which extensions are Markdown, in one place.
//
// There were three answers to that question and no two of them agreed:
//
//   DeclarationOutline   md markdown mdown mkd mdx        (which files get an outline)
//   ExternalToolFormatter md markdown mdown              (which files the Format button reformats)
//   the Markdown plugin  md markdown mdown mkd mkdn mdwn (which files are rendered)
//
// So a `.mdx` file had an outline and could not be rendered, a `.mkdn` file was rendered and could
// not be reformatted, and nothing said any of that was intended — the sets were written at three
// different times by whoever needed one. The union is what each of them meant: `.mkdn`, `.mdwn` and
// `.mdx` are Markdown, and `.mdx` carries JSX that a Markdown reader shows as text, which is the
// behaviour the outline had already settled on.
//
// Here rather than in one of the three because it belongs to none of them, and because the plugin
// links this framework and must be able to agree with the host — a plugin that claims a file the
// host will not outline is the same disagreement one level out.

import Foundation

public enum MarkdownFileType {
    /// Every file extension treated as Markdown, lowercased and without the dot.
    public static let extensions: Set<String> = [
        "md", "markdown", "mdown", "mkd", "mkdn", "mdwn", "mdx",
    ]

    /// Whether `ext` (with or without a leading dot, any case) is one of them.
    public static func matches(_ ext: String) -> Bool {
        var e = ext.lowercased()
        if e.hasPrefix(".") { e.removeFirst() }
        return extensions.contains(e)
    }

    /// The set as a sorted list, for a manifest, a detect string or a message.
    public static var sorted: [String] { extensions.sorted() }
}
