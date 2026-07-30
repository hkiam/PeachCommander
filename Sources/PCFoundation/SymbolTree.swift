// SPDX-License-Identifier: Apache-2.0
// SymbolTree.swift - Pure (tree-sitter-independent) building and querying of a
// nested definition outline. The app's SymbolOutline runs a tree-sitter "tags"
// query to produce flat `Def`s, then uses `SymbolTree` to nest, merge, filter and
// navigate them. Kept here so the non-trivial tree logic is unit-tested.

import Foundation

/// A navigable definition node (reference type so NSOutlineView can hold it).
public final class SymbolNode {
    public let name: String
    public let kind: String          // class, interface, function, method, module, …
    public let line: Int             // 1-based
    public let utf16Location: Int    // start offset of the name (UTF-16), for selection
    public let start: Int            // definition node start (UTF-16), for containment
    public let end: Int              // definition node end (UTF-16)
    public var children: [SymbolNode] = []

    public init(name: String, kind: String, line: Int, utf16Location: Int, start: Int, end: Int) {
        self.name = name; self.kind = kind; self.line = line
        self.utf16Location = utf16Location; self.start = start; self.end = end
    }
    /// Shallow copy (children replaced by the caller) — used to build filtered trees.
    public init(copy o: SymbolNode) {
        name = o.name; kind = o.kind; line = o.line
        utf16Location = o.utf16Location; start = o.start; end = o.end
    }
}

public enum SymbolTree {
    /// A flat definition, as extracted from a tags query.
    public struct Def: Equatable, Sendable {
        public let name: String
        public let kind: String
        public let line: Int
        public let utf16Location: Int
        public let start: Int
        public let end: Int
        public init(name: String, kind: String, line: Int, utf16Location: Int, start: Int, end: Int) {
            self.name = name; self.kind = kind; self.line = line
            self.utf16Location = utf16Location; self.start = start; self.end = end
        }
    }

    /// Container kinds whose same-named siblings represent one logical symbol split
    /// across definitions (Rust `struct` + `impl`, C# `partial class`, …).
    private static let containerKinds: Set<String> =
        ["class", "struct", "enum", "union", "interface", "protocol", "trait", "module", "namespace"]

    /// Nest flat defs by source containment (dedup by start+name, sort, stack-nest),
    /// then merge same-named container siblings.
    public static func build(_ defs: [Def]) -> [SymbolNode] {
        var seen = Set<String>()
        let unique = defs.filter { seen.insert("\($0.start):\($0.name)").inserted }
        // Outer definitions first at a given start, so containers precede their members.
        let sorted = unique.sorted { $0.start == $1.start ? $0.end > $1.end : $0.start < $1.start }

        var roots: [SymbolNode] = []
        var stack: [SymbolNode] = []
        for d in sorted {
            let node = SymbolNode(name: d.name, kind: d.kind, line: d.line,
                                  utf16Location: d.utf16Location, start: d.start, end: d.end)
            while let top = stack.last, !(top.start <= node.start && top.end >= node.end && top !== node) {
                stack.removeLast()
            }
            if let parent = stack.last { parent.children.append(node) } else { roots.append(node) }
            stack.append(node)
        }
        return mergeSameName(roots)
    }

    /// Merge same-named container siblings (concatenating members) recursively.
    private static func mergeSameName(_ nodes: [SymbolNode]) -> [SymbolNode] {
        var result: [SymbolNode] = []
        var indexByName: [String: Int] = [:]
        for node in nodes {
            if containerKinds.contains(node.kind), let i = indexByName[node.name] {
                result[i].children.append(contentsOf: node.children)
            } else {
                if containerKinds.contains(node.kind) { indexByName[node.name] = result.count }
                result.append(node)
            }
        }
        for node in result {
            node.children = mergeSameName(node.children)
                .sorted { $0.start == $1.start ? $0.line < $1.line : $0.start < $1.start }
        }
        return result
    }

    /// Prune a tree to nodes matching `query` (or having a matching descendant).
    public static func filter(_ nodes: [SymbolNode], query: String) -> [SymbolNode] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return nodes }
        return nodes.compactMap { node in
            let kids = filter(node.children, query: q)
            guard node.name.lowercased().contains(q) || !kids.isEmpty else { return nil }
            let copy = SymbolNode(copy: node); copy.children = kids; return copy
        }
    }

    /// Outermost→innermost definitions whose range contains `offset`.
    public static func enclosingPath(_ roots: [SymbolNode], utf16 offset: Int) -> [SymbolNode] {
        var path: [SymbolNode] = []
        var level = roots
        while let node = level.first(where: { $0.start <= offset && offset <= $0.end }) {
            path.append(node)
            level = node.children
        }
        return path
    }

    /// First definition (depth-first) with the given name.
    public static func find(_ roots: [SymbolNode], named name: String) -> SymbolNode? {
        for n in roots {
            if n.name == name { return n }
            if let hit = find(n.children, named: name) { return hit }
        }
        return nil
    }
}
