// SPDX-License-Identifier: Apache-2.0
// StructurePath.swift - The path of the caret through a JSON, YAML or XML document, in the notation the
// tools for that format actually take (F-369).
//
// The breadcrumb in the status line answers "where am I" for a human: `services › web › ports`. This
// answers the same question for a machine, which is the form people need far more often — to paste into
// a `jq` filter, a `yq` expression, an XPath query, a bug report, or a config-management template:
//
//     .services.web.ports[0]                  jq / yq
//     //server[@id='web-1']/port              XPath
//
// The steps are recorded by the parser (`SymbolNode.pathComponent`), not recovered from the label: the
// label is shortened for the sidebar and decorated for people (`server #web-1`, `[0] name`), and guessing
// a query back out of it would be wrong exactly where it matters — keys with dots, spaces or quotes.
//
// Keys that are not identifiers are bracketed and quoted, because `.a-b` is a subtraction in jq and
// `."a-b"` is the key. That distinction is the whole reason this is not string concatenation at the call
// site.

import Foundation

public enum StructurePath {

    /// Notation to produce, chosen by the document's format.
    public enum Style {
        /// `jq`/`yq`: dotted keys, bracketed indices — `.services.web.ports[0]`.
        case query
        /// XPath, relative from anywhere — `//server[@id='web-1']/port`. Relative because the outline
        /// unwraps a single document element, so the root's own name is not in the tree.
        case xpath
    }

    /// The style to use for a file extension, or nil when the format has no path notation.
    public static func style(forExtension ext: String) -> Style? {
        let e = ext.lowercased()
        if ["xml", "svg", "plist", "xsd", "xsl", "xslt", "storyboard", "xib", "rss", "atom", "pom",
            "xhtml", "resx", "csproj", "vcxproj", "nuspec", "wsdl"].contains(e) { return .xpath }
        if ["json", "jsonc", "geojson", "webmanifest", "jsonl", "ndjson",
            "yaml", "yml"].contains(e) { return .query }
        return nil
    }

    /// One jq/yq step for an object key: `.name`, or `."odd key"` when it is not an identifier.
    ///
    /// `(root)` and `(document 2)` are the outline's own labels for whole documents, not keys, so they
    /// contribute nothing to a path.
    public static func jsonStep(for key: String) -> String? {
        if key.hasPrefix("("), key.hasSuffix(")") { return nil }
        if key.hasPrefix("["), key.hasSuffix("]") { return key }          // an array element label
        let unquoted = unquote(key)
        let isIdentifier = !unquoted.isEmpty
            && unquoted.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
            && !(unquoted.first?.isNumber ?? true)
        if isIdentifier { return "." + unquoted }
        return ".\"" + unquoted.replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// One XPath step for an element: `server[@id='web-1']` when it can be identified by an attribute,
    /// else the bare tag (the caller adds a positional predicate if the tag repeats among its siblings).
    public static func xmlStep(tag: String, attributes: [(String, String)]) -> String {
        for wanted in ["id", "name", "key"] {
            if let value = attributes.first(where: { $0.0.lowercased() == wanted })?.1, !value.isEmpty,
               !value.contains("'") {
                return "\(tag)[@\(wanted)='\(value)']"
            }
        }
        return tag
    }

    /// The path to the innermost node containing `offset`, or nil when there is none.
    ///
    /// Positional predicates are added here rather than in the parser: whether `port` needs to be
    /// `port[2]` depends on its siblings, and the parser sees a node before it has met them.
    public static func path(_ roots: [SymbolNode], utf16 offset: Int, style: Style) -> String? {
        // Walk first, join second: a node contributes one step when the path ends at it and possibly
        // another when the path continues through it (see `SymbolNode.childPathComponent`), and that is
        // only known once the end of the chain is known.
        var chain: [(node: SymbolNode, siblings: [SymbolNode])] = []
        var level = roots
        while let node = level.first(where: { $0.start <= offset && offset <= $0.end }) {
            chain.append((node, level))
            level = node.children
        }
        var steps: [String] = []
        for (i, entry) in chain.enumerated() {
            let isDestination = i == chain.count - 1
            let raw = isDestination ? entry.node.pathComponent
                                    : (entry.node.childPathComponent ?? entry.node.pathComponent)
            guard let step = raw else { continue }
            steps.append(style == .xpath ? positional(step, among: entry.siblings, node: entry.node) : step)
        }
        guard !steps.isEmpty else { return nil }
        return style == .xpath ? "//" + steps.joined(separator: "/") : steps.joined()
    }

    /// The path for a node the user picked in the sidebar (rather than for a caret position).
    public static func path(to node: SymbolNode, in roots: [SymbolNode], style: Style) -> String? {
        path(roots, utf16: node.utf16Location, style: style)
    }

    /// `host` → `host[2]` when it is the second `host` among its siblings.
    ///
    /// Counting must be per *tag*, not per step: `<a id="it's">` gets no predicate (a quote cannot go into
    /// one) while its sibling `<a id="x">` does, and comparing whole steps then found each of them unique
    /// and produced the bare `//a/b` — a path that selects the children of *both*.
    ///
    /// An attribute predicate that is unique among the siblings needs no index; one that is not (two
    /// elements with the same id, which happens in generated files) is disambiguated by position instead,
    /// since `a[@id='x'][2]` is legal XPath and reads like a puzzle.
    private static func positional(_ step: String, among siblings: [SymbolNode],
                                   node: SymbolNode) -> String {
        let tag = String(step.prefix(while: { $0 != "[" }))
        let sameTag = siblings.filter { ($0.pathComponent ?? "").prefix(while: { $0 != "[" }) == tag }
        guard sameTag.count > 1 else { return step }
        if step.contains("["), siblings.filter({ $0.pathComponent == step }).count == 1 { return step }
        guard let i = sameTag.firstIndex(where: { $0 === node }) else { return step }
        return "\(tag)[\(i + 1)]"
    }

    /// Strip one layer of YAML quoting from a key: `"a:b"` and `'a:b'` are both the key `a:b`.
    private static func unquote(_ s: String) -> String {
        for q in ["\"", "'"] where s.hasPrefix(q) && s.hasSuffix(q) && s.count >= 2 {
            return String(s.dropFirst().dropLast())
        }
        return s
    }
}
