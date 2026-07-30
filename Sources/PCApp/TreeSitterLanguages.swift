// SPDX-License-Identifier: Apache-2.0
// TreeSitterLanguages.swift - Registry mapping a file extension to a tree-sitter
// LanguageConfiguration (grammar + highlight query), shared by the one-shot
// highlighter (viewer) and Neon's incremental highlighter (editor).
//
// Two grammar sources:
//  • SPM grammar packages that bundle their queries (JSON, C, Java) — loaded via
//    SwiftTreeSitter's `LanguageConfiguration(_:name:)` bundle convention.
//  • Vendored grammars (JavaScript, Python) compiled locally as CTreeSitter*
//    targets so their `scanner.c` links (upstream SwiftPM manifests drop it);
//    their `highlights.scm` ships as a PCApp resource and is loaded explicitly.
//
// Adding a language: add the grammar (SPM package or vendored C target), import
// it here, and add its extensions to `specs`.

import AppKit
import SwiftTreeSitter
import TreeSitterJSON
import TreeSitterC
import TreeSitterJava
import CTreeSitterJS
import CTreeSitterPython
import CTreeSitterRust
import CTreeSitterCSharp
import CTreeSitterTypeScript

@MainActor
enum TreeSitterLanguages {
    private struct Spec {
        let name: String
        let language: () -> OpaquePointer
        /// Resource base name of the `.scm` highlights query for vendored
        /// grammars; nil means load the SPM grammar's own bundled queries.
        let queryResource: String?
        /// Resource base name of the `.tags.scm` definitions query (for the symbol
        /// outline); nil when the language has no meaningful definitions (e.g. JSON).
        let tagsResource: String?
    }

    private static let specs: [String: Spec] = [
        "json": Spec(name: "JSON", language: { tree_sitter_json() }, queryResource: nil, tagsResource: nil),
        "c":    Spec(name: "C", language: { tree_sitter_c() }, queryResource: nil, tagsResource: "c.tags"),
        "h":    Spec(name: "C", language: { tree_sitter_c() }, queryResource: nil, tagsResource: "c.tags"),
        "java": Spec(name: "Java", language: { tree_sitter_java() }, queryResource: nil, tagsResource: "java.tags"),
        "js":   Spec(name: "JavaScript", language: { tree_sitter_javascript() }, queryResource: "javascript", tagsResource: "javascript.tags"),
        "mjs":  Spec(name: "JavaScript", language: { tree_sitter_javascript() }, queryResource: "javascript", tagsResource: "javascript.tags"),
        "cjs":  Spec(name: "JavaScript", language: { tree_sitter_javascript() }, queryResource: "javascript", tagsResource: "javascript.tags"),
        "jsx":  Spec(name: "JavaScript", language: { tree_sitter_javascript() }, queryResource: "javascript", tagsResource: "javascript.tags"),
        "py":   Spec(name: "Python", language: { tree_sitter_python() }, queryResource: "python", tagsResource: "python.tags"),
        "pyw":  Spec(name: "Python", language: { tree_sitter_python() }, queryResource: "python", tagsResource: "python.tags"),
        "rs":   Spec(name: "Rust", language: { tree_sitter_rust() }, queryResource: "rust", tagsResource: "rust.tags"),
        "cs":   Spec(name: "C#", language: { tree_sitter_c_sharp() }, queryResource: "csharp", tagsResource: "csharp.tags"),
        // TypeScript grammar (no JSX); .tsx would need the separate tsx grammar.
        "ts":   Spec(name: "TypeScript", language: { tree_sitter_typescript() }, queryResource: "typescript", tagsResource: "typescript.tags"),
        "mts":  Spec(name: "TypeScript", language: { tree_sitter_typescript() }, queryResource: "typescript", tagsResource: "typescript.tags"),
        "cts":  Spec(name: "TypeScript", language: { tree_sitter_typescript() }, queryResource: "typescript", tagsResource: "typescript.tags"),
    ]

    private static var cache: [String: LanguageConfiguration] = [:]
    private static var tagsCache: [String: Query?] = [:]

    /// Whether tree-sitter handles this extension (vs. the built-in lexer).
    static func canHighlight(ext: String) -> Bool { specs[ext.lowercased()] != nil }

    /// The tree-sitter Language for an extension (grammar pointer), or nil.
    static func language(forExtension ext: String) -> Language? {
        specs[ext.lowercased()].map { Language(language: $0.language()) }
    }

    /// Human-readable language name for an extension (e.g. "C#", "Rust"), or nil.
    static func displayName(forExtension ext: String) -> String? { specs[ext.lowercased()]?.name }

    /// The compiled `tags` (definitions) query for an extension, cached; nil when the
    /// language has no tags query or it fails to compile.
    static func tagsQuery(forExtension ext: String) -> Query? {
        guard let spec = specs[ext.lowercased()], let res = spec.tagsResource else { return nil }
        if let cached = tagsCache[spec.name] { return cached }
        var query: Query?
        if let url = Bundle.main.url(forResource: res, withExtension: "scm"),
           let data = try? Data(contentsOf: url) {
            query = try? Query(language: Language(language: spec.language()), data: data)
        }
        tagsCache[spec.name] = query
        return query
    }

    /// A cached LanguageConfiguration (grammar + queries) for the extension, or
    /// nil when unsupported or the query can't be loaded.
    static func configuration(forExtension ext: String) -> LanguageConfiguration? {
        guard let spec = specs[ext.lowercased()] else { return nil }
        if let cached = cache[spec.name] { return cached }
        let config = build(spec)
        if let config { cache[spec.name] = config }
        return config
    }

    private static func build(_ spec: Spec) -> LanguageConfiguration? {
        guard let res = spec.queryResource else {
            // SPM grammar with a bundled query directory.
            return try? LanguageConfiguration(spec.language(), name: spec.name)
        }
        // Vendored grammar: load the highlights query shipped as an app resource.
        guard let url = Bundle.main.url(forResource: res, withExtension: "scm"),
              let data = try? Data(contentsOf: url) else { return nil }
        let language = Language(language: spec.language())
        guard let query = try? Query(language: language, data: data) else { return nil }
        return LanguageConfiguration(language, name: spec.name, queries: [.highlights: query])
    }
}
