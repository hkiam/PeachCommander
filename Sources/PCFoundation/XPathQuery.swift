// SPDX-License-Identifier: Apache-2.0
// XPathQuery.swift - Evaluate an XPath expression against XML for the viewer (TODOS #21).
//
// Thin wrapper over Foundation's XMLDocument.nodes(forXPath:) that returns each
// matched node rendered as text (element markup, or the string value for text and
// attribute nodes). Pure and unit-testable; the viewer surfaces it as an XPath box.

import Foundation

public enum XPathQuery {
    public enum QueryError: Error, Equatable {
        case invalidXML
        case invalidQuery
    }

    /// Evaluate `query` against `xml`. Throws `.invalidXML` if the document does not
    /// parse, `.invalidQuery` if the XPath is malformed. Returns matched nodes as text.
    public static func evaluate(xml: String, query: String) throws -> [String] {
        guard let doc = XMLParsing.document(xml) else {
            throw QueryError.invalidXML
        }
        let nodes: [XMLNode]
        do {
            nodes = try doc.nodes(forXPath: query)
        } catch {
            throw QueryError.invalidQuery
        }
        return nodes.map { node in
            switch node.kind {
            case .text, .attribute:
                return node.stringValue ?? ""
            default:
                return node.xmlString
            }
        }
    }
}
