// StructuredTextFormatter.swift - Pretty-print JSON and XML for the viewer (TODOS #20/#21).
//
// Pure formatting over Foundation (JSONSerialization / XMLDocument): returns a
// re-indented string, or nil when the input is not valid JSON/XML. The viewer's
// "format" action tries these so JSON/XML files can be read structured.

import Foundation

public enum StructuredTextFormatter {
    /// Pretty-print `text` as JSON (sorted keys), or nil if it is not valid JSON.
    public static func json(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let pretty = try? JSONSerialization.data(withJSONObject: object,
                                                       options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }
        return String(data: pretty, encoding: .utf8)
    }

    /// Pretty-print `text` as XML, or nil if it is not well-formed XML.
    public static func xml(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let doc = try? XMLDocument(data: data, options: []) else { return nil }
        return String(data: doc.xmlData(options: [.nodePrettyPrint]), encoding: .utf8)
    }

    /// Try to format `text` as XML (when `preferXML`) then JSON, or JSON then XML.
    /// Returns the formatted string and which kind matched, or nil if neither parses.
    public static func autoFormat(_ text: String, preferXML: Bool) -> (text: String, kind: String)? {
        let json = { self.json(text).map { ($0, "JSON") } }
        let xml = { self.xml(text).map { ($0, "XML") } }
        if preferXML { return xml() ?? json() }
        return json() ?? xml()
    }
}
