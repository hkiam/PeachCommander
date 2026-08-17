// SPDX-License-Identifier: Apache-2.0
// ViewerSearchSeed.swift - The search a viewer should open with, taken from the search that found the
// file (F-407).
//
// Opening a hit from a content search used to lose the one thing the reader was after: the viewer came
// up at byte 0 with an empty search box, and the term had to be typed a second time into a window that
// only exists because that term matched. This carries it across.
//
// A value type in PCVFS rather than a handful of parameters on the viewer's initialiser, because the
// interesting part is a *translation* — a `SearchTemplate` describes a file-search (masks, hex, regex,
// whole word, encodings), a viewer search is a term plus bytes plus two flags — and translations are
// worth testing without a window. What is deliberately dropped is named in `init`: the viewer has no
// whole-word search, so claiming one would find hits the file-search would not have reported.

import Foundation
import PCFoundation

/// What a viewer's own search should start out as.
public struct ViewerSearchSeed: Equatable, Sendable {
    /// The term as the user typed it in the Find dialog — what a search field should show.
    public let term: String
    /// The bytes to look for: the term's UTF-8, or the parsed bytes of a hex search.
    public let needle: [UInt8]
    public let caseSensitive: Bool
    /// The term is an ICU pattern rather than literal text.
    public let isRegex: Bool
    /// The term is a hex byte sequence ("48 65 6C") and `needle` is what it parsed to.
    public let isHex: Bool

    public init(term: String, needle: [UInt8], caseSensitive: Bool,
                isRegex: Bool = false, isHex: Bool = false) {
        self.term = term
        self.needle = needle
        self.caseSensitive = caseSensitive
        self.isRegex = isRegex
        self.isHex = isHex
    }

    /// The seed a completed search hands to a viewer, or nil when there is nothing to seed with.
    ///
    /// Nil rather than an empty seed for a name-only search (no content term at all) and for a hex
    /// search whose bytes do not parse: in both cases no content was looked for, so there is no hit to
    /// jump to and prefilling a search field with something that found nothing would be a lie.
    ///
    /// `wholeWord` is not carried: the viewer's search has no word boundaries, and a seed that quietly
    /// matched more than the file-search did would point at a line the search never counted. The term is
    /// still seeded — it is the pattern the reader is looking for — it just may stop somewhere the
    /// search would not have.
    public init?(template: SearchTemplate) {
        if let hex = template.hexContent, !hex.isEmpty {
            guard let bytes = ByteSearch.parseHex(hex), !bytes.isEmpty else { return nil }
            self.init(term: hex, needle: bytes, caseSensitive: template.caseSensitive,
                      isRegex: false, isHex: true)
            return
        }
        guard let text = template.contentText, !text.isEmpty else { return nil }
        self.init(term: text, needle: Array(text.utf8), caseSensitive: template.caseSensitive,
                  isRegex: template.useRegex, isHex: false)
    }
}
