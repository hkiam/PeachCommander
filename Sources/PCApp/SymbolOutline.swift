// SPDX-License-Identifier: Apache-2.0
// SymbolOutline.swift - Extracts a file's definitions (classes / functions /
// methods / …) via tree-sitter "tags" queries, then nests/queries them with the
// tree-sitter-independent SymbolTree (in PCFoundation, where it is unit-tested).
// Uses the same parser as highlighting; languages without a tags query yield none.

import AppKit
import PCFoundation
import SwiftTreeSitter

enum SymbolOutline {
    /// Whether the file's language exposes a definitions (tags) query.
    @MainActor static func supports(ext: String) -> Bool {
        TreeSitterLanguages.tagsQuery(forExtension: ext) != nil
    }

    /// Grab the (cached) query + grammar on the main actor so the heavy parse can then
    /// run on a background queue with these handles.
    @MainActor static func handles(ext: String) -> (query: Query, language: Language)? {
        guard let query = TreeSitterLanguages.tagsQuery(forExtension: ext),
              let language = TreeSitterLanguages.language(forExtension: ext) else { return nil }
        return (query, language)
    }

    /// Parse `text` and build the nested definition tree. Pure/thread-safe: callers
    /// serialize calls (one Parser per call; the shared Query is used single-threaded).
    static func parse(_ text: String, query: Query, language: Language) -> [SymbolNode] {
        let parser = Parser()
        do { try parser.setLanguage(language) } catch { return [] }
        guard let tree = parser.parse(text) else { return [] }
        let ns = text as NSString

        var defs: [SymbolTree.Def] = []
        let cursor = query.execute(in: tree)
        while let match = cursor.next() {
            guard let def = match.captures.first(where: { ($0.name ?? "").hasPrefix("definition.") }),
                  let nameCap = match.captures.first(where: { $0.name == "name" }) else { continue }
            let nr = nameCap.node.range, dr = def.node.range
            guard nr.location >= 0, NSMaxRange(nr) <= ns.length, nr.length > 0 else { continue }
            defs.append(SymbolTree.Def(
                name: ns.substring(with: nr),
                kind: String((def.name ?? "definition.").dropFirst("definition.".count)),
                line: Int(nameCap.node.pointRange.lowerBound.row) + 1,
                utf16Location: nr.location,
                start: dr.location, end: NSMaxRange(dr)))
        }
        return SymbolTree.build(defs)
    }
}
