// SPDX-License-Identifier: Apache-2.0
// XMLParsing.swift - Reading an XML file that came from somewhere else.
//
// Three places parse XML with `XMLDocument`: the tree view, the XPath query, and the editor's "format
// XML" command. All three are handed a file the user opened — off a download, out of an archive, from a
// share — and `XMLDocument(data:options: [])` resolves external entities.
//
// Measured, because the opposite was assumed first. A document declaring
//
//     <!DOCTYPE d [ <!ENTITY x SYSTEM "file:///etc/passwd"> ]>  <d><v>&x;</v></d>
//
// comes back from `options: []` with the file's contents substituted for `&x;`. Merely looking at an
// XML file therefore pulled local files into the view — and a `SYSTEM "http://…"` entity makes the app
// fetch a URL of the document's choosing while the user thinks they are previewing a local file.
//
// `.nodeLoadExternalEntitiesNever` stops it; the same probe shows the entity left unexpanded. Internal
// entities (`&amp;` and friends) are unaffected, so well-formed documents read exactly as before.
// `.nodeLoadExternalEntitiesSameOriginOnly` is not usable here: it raises
// "not applicable without a URI" for the data-based initializer, which is the one all three sites use.
//
// `XMLParser` — used by StructureValidator — was measured too and needs nothing: it defaults to
// `shouldResolveExternalEntities = false` and leaves the entity alone.

import Foundation

public enum XMLParsing {

    /// The options every `XMLDocument` in this app is built with.
    public static let safeOptions: XMLNode.Options = .nodeLoadExternalEntitiesNever

    /// Parse `data` as XML without resolving anything the document points at.
    public static func document(_ data: Data) throws -> XMLDocument {
        try XMLDocument(data: data, options: safeOptions)
    }

    /// Parse `text` as XML, or nil if it is not well-formed.
    public static func document(_ text: String) -> XMLDocument? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? document(data)
    }
}
