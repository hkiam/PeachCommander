// SPDX-License-Identifier: Apache-2.0
// PluginSyntax.swift - Shared syntax highlighter for plugins that show code (F-346).
//
// Add this file to a plugin's swiftc sources. It exists because the host's highlighter is not
// reachable from a plugin: a plugin that renders source would otherwise either show flat text or
// invent its own palette, and inventing one is how a themed app ends up looking un-themed.
//
// Colours arrive as a `PluginSyntaxPalette`. A contribution view can build one from `PluginTheme` so the
// code matches the host's theme; a lister plugin, which gets no host-services table, uses the
// dynamic system colours instead. The highlighter itself is indifferent.
//
// The tokeniser is deliberately a lexer and not a parser. Decompiler output is *usually* valid
// source but not reliably so: an engine that fails halfway leaves a truncated method, and a parser
// would give up where a lexer keeps colouring. It is also language-agnostic in shape — the keyword
// set and the comment syntax are parameters — so the next language is a table, not a rewrite.

import AppKit

// Every type here carries the `Plugin` prefix on purpose. This file is compiled *into* plugins,
// so a bare `SyntaxLanguage` collides with anything of that name the plugin already has — and it
// did: PCFoundation has its own `SyntaxLanguage` for the host highlighter, which broke the moment
// this file was added to a test target that imports it.

/// What a run of characters is, so the caller can colour it.
enum PluginSyntaxRole {
    case plain, comment, string, number, keyword, type, annotation
}

/// A language, as data: what its keywords are and how it writes comments and strings.
struct PluginSyntaxLanguage {
    let keywords: Set<String>
    /// Types and other capitalised identifiers get their own colour when true.
    let capitalisedIdentifiersAreTypes: Bool
    let lineComment: String
    let blockCommentOpen: String
    let blockCommentClose: String
    /// `@Annotation` in Java, `#[attr]` elsewhere; nil for languages without them.
    let annotationPrefix: Character?

    /// Java, plus the words `javap` prints — the two things this plugin shows.
    ///
    /// The bytecode mnemonics are included on purpose: javap output is not Java, and leaving it
    /// entirely unhighlighted made the bytecode view look like the highlighter had failed.
    static let java = PluginSyntaxLanguage(
        keywords: [
            "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class",
            "const", "continue", "default", "do", "double", "else", "enum", "extends", "final",
            "finally", "float", "for", "goto", "if", "implements", "import", "instanceof", "int",
            "interface", "long", "native", "new", "package", "private", "protected", "public",
            "return", "short", "static", "strictfp", "super", "switch", "synchronized", "this",
            "throw", "throws", "transient", "try", "void", "volatile", "while",
            "true", "false", "null", "var", "record", "sealed", "permits", "yield", "non-sealed",
            // javap
            "Code", "Compiled", "descriptor", "flags", "LineNumberTable", "LocalVariableTable",
            "Constant", "pool", "Exception", "table", "StackMapTable",
        ],
        capitalisedIdentifiersAreTypes: true,
        lineComment: "//", blockCommentOpen: "/*", blockCommentClose: "*/",
        annotationPrefix: "@")
}

/// The six colours the highlighter needs.
///
/// A plain struct rather than a dependency on `PluginTheme`, because the two are reachable in
/// different places: a *contribution* view gets PcHostServices and can build this from the host's
/// theme, while a *lister* plugin gets no services at all and has to use the system defaults. The
/// highlighter should not care which — it needs colours, not their provenance.
struct PluginSyntaxPalette {
    let comment, string, number, keyword, type, annotation: NSColor

    /// Dynamic system colours, so highlighting still follows light and dark even where the host's
    /// palette cannot be read. These are the same roles the host's own light palette uses.
    static let system = PluginSyntaxPalette(
        comment: .systemGreen, string: .systemRed, number: .systemBlue,
        keyword: .systemPurple, type: .systemIndigo, annotation: .systemBrown)
}

enum PluginSyntax {
    /// Above this many characters the text is shown unhighlighted.
    ///
    /// Not an arbitrary cap: a whole decompiled JAR can be megabytes, and building one attributed
    /// string over that costs seconds and a great deal of memory for a view the user is scrolling.
    /// Flat text now beats coloured text later, and the caller says so in the status line.
    static let maximumLength = 400_000

    /// Colour `text` for `language`, or return it unhighlighted when it is too large.
    ///
    /// Runs a single pass with no backtracking, so cost is linear in the input.
    static func highlight(_ text: String, language: PluginSyntaxLanguage = .java,
                          palette: PluginSyntaxPalette = .system, textColor: NSColor = .labelColor,
                          font: NSFont) -> NSAttributedString {
        let base: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        guard text.utf16.count <= maximumLength else {
            return NSAttributedString(string: text, attributes: base)
        }
        let result = NSMutableAttributedString(string: text, attributes: base)
        for (range, role) in runs(in: text, language: language) {
            guard let colour = colour(for: role, palette: palette) else { continue }
            result.addAttribute(.foregroundColor, value: colour, range: range)
        }
        return result
    }

    private static func colour(for role: PluginSyntaxRole, palette: PluginSyntaxPalette) -> NSColor? {
        switch role {
        case .plain: return nil
        case .comment: return palette.comment
        case .string: return palette.string
        case .number: return palette.number
        case .keyword: return palette.keyword
        case .type: return palette.type
        case .annotation: return palette.annotation
        }
    }

    /// The coloured runs, as UTF-16 ranges so they can be applied to an NSAttributedString.
    ///
    /// Internal rather than private so it can be tested without building an attributed string —
    /// the interesting behaviour is where the runs fall, not what colour they end up.
    static func runs(in text: String, language: PluginSyntaxLanguage) -> [(NSRange, PluginSyntaxRole)] {
        var out: [(NSRange, PluginSyntaxRole)] = []
        let chars = Array(text.utf16)
        // UTF-16 code units throughout: NSRange is in UTF-16, and converting per token would turn
        // a linear pass into a quadratic one on a large file.
        func unit(_ i: Int) -> Character? {
            guard i < chars.count, let scalar = Unicode.Scalar(chars[i]) else { return nil }
            return Character(scalar)
        }
        let line = Array(language.lineComment.utf16)
        let open = Array(language.blockCommentOpen.utf16)
        let close = Array(language.blockCommentClose.utf16)
        func matches(_ pattern: [UInt16], at i: Int) -> Bool {
            guard i + pattern.count <= chars.count else { return false }
            for (k, u) in pattern.enumerated() where chars[i + k] != u { return false }
            return true
        }

        var i = 0
        while i < chars.count {
            // Comments first: everything inside one is a comment, keywords included.
            if matches(line, at: i) {
                let start = i
                while i < chars.count, unit(i) != "\n" { i += 1 }
                out.append((NSRange(location: start, length: i - start), .comment))
                continue
            }
            if matches(open, at: i) {
                let start = i
                i += open.count
                while i < chars.count, !matches(close, at: i) { i += 1 }
                i = min(chars.count, i + close.count)
                out.append((NSRange(location: start, length: i - start), .comment))
                continue
            }
            // Strings and char literals, honouring backslash escapes so `"\""` does not end early.
            if let c = unit(i), c == "\"" || c == "'" {
                let quote = c
                let start = i
                i += 1
                while i < chars.count {
                    if unit(i) == "\\" { i += 2; continue }
                    if unit(i) == quote { i += 1; break }
                    if unit(i) == "\n" { break }   // an unterminated literal must not eat the file
                    i += 1
                }
                out.append((NSRange(location: start, length: min(i, chars.count) - start), .string))
                continue
            }
            if let prefix = language.annotationPrefix, unit(i) == prefix {
                let start = i
                i += 1
                while let c = unit(i), c.isLetter || c.isNumber || c == "_" || c == "." { i += 1 }
                if i > start + 1 { out.append((NSRange(location: start, length: i - start), .annotation)) }
                continue
            }
            if let c = unit(i), c.isNumber {
                let start = i
                // Covers 0x1F, 1_000, 3.14f, 1e-9 — javap prints plenty of these.
                while let d = unit(i), d.isHexDigit || d == "." || d == "_" || d == "x" || d == "X"
                        || d == "L" || d == "l" || d == "f" || d == "F" || d == "d" || d == "D" { i += 1 }
                out.append((NSRange(location: start, length: i - start), .number))
                continue
            }
            if let c = unit(i), c.isLetter || c == "_" {
                let start = i
                while let d = unit(i), d.isLetter || d.isNumber || d == "_" { i += 1 }
                let word = String(decoding: chars[start..<i])
                if language.keywords.contains(word) {
                    out.append((NSRange(location: start, length: i - start), .keyword))
                } else if language.capitalisedIdentifiersAreTypes,
                          let first = word.first, first.isUppercase {
                    out.append((NSRange(location: start, length: i - start), .type))
                }
                continue
            }
            i += 1
        }
        return out
    }
}

private extension String {
    /// Rebuild a token from a UTF-16 slice without going through String.Index arithmetic.
    init(decoding units: ArraySlice<UInt16>) {
        self = String(decoding: Array(units), as: UTF16.self)
    }
}
