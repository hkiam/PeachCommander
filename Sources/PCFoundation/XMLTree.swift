// XMLTree.swift - Parse XML into a display tree for the collapsible viewer (TODOS #21).
//
// Builds an element tree (name, ordered attributes, leaf text, children) from XML via
// Foundation's XMLDocument. A reference type used directly as NSOutlineView items, so it
// deliberately uses object *identity* (no Equatable/Hashable — structurally-identical
// siblings must remain distinct outline items). `structurallyEquals` is for tests.

import Foundation

public final class XMLTreeNode {
    public let name: String
    public let attributes: [(name: String, value: String)]
    public let text: String?             // trimmed leaf text (only when there are no element children)
    public let children: [XMLTreeNode]

    public init(name: String, attributes: [(name: String, value: String)] = [], text: String? = nil,
                children: [XMLTreeNode] = []) {
        self.name = name
        self.attributes = attributes
        self.text = text
        self.children = children
    }

    /// One-line label: `name attr="v" … = text`.
    public var label: String {
        var s = name
        for a in attributes { s += " \(a.name)=\"\(a.value)\"" }
        if let text, !text.isEmpty { s += " = \(text)" }
        return s
    }

    /// Deep structural comparison (name, attributes, text, children) — for tests.
    public func structurallyEquals(_ other: XMLTreeNode) -> Bool {
        name == other.name && text == other.text
            && attributes.map { "\($0.name)=\($0.value)" } == other.attributes.map { "\($0.name)=\($0.value)" }
            && children.count == other.children.count
            && zip(children, other.children).allSatisfy { $0.structurallyEquals($1) }
    }
}

public enum XMLTreeParser {
    /// Parse `xml` into a tree rooted at the document element, or nil if it is not well-formed.
    public static func parse(_ xml: String) -> XMLTreeNode? {
        guard let data = xml.data(using: .utf8),
              let doc = try? XMLDocument(data: data, options: []),
              let root = doc.rootElement() else { return nil }
        return node(from: root)
    }

    private static func node(from element: XMLElement) -> XMLTreeNode {
        let attributes: [(name: String, value: String)] = (element.attributes ?? []).compactMap {
            guard let n = $0.name else { return nil }
            return (n, $0.stringValue ?? "")
        }
        let childElements = (element.children ?? []).compactMap { $0 as? XMLElement }
        let children = childElements.map(node(from:))
        let text: String?
        if children.isEmpty {
            let trimmed = (element.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            text = trimmed.isEmpty ? nil : trimmed
        } else {
            text = nil
        }
        return XMLTreeNode(name: element.name ?? "", attributes: attributes, text: text, children: children)
    }
}
