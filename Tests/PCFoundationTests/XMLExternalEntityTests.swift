// SPDX-License-Identifier: Apache-2.0
// XMLExternalEntityTests.swift - An XML file must not be able to read other files (F-368, F-356).
//
// `XMLDocument(data:options: [])` resolves external entities. That was measured, not assumed — the
// first reading of this was "Foundation does not do that by default", and a probe said otherwise. So a
// document declaring
//
//     <!DOCTYPE d [ <!ENTITY x SYSTEM "file:///etc/passwd"> ]>
//
// had the file's contents substituted wherever it wrote `&x;`, and the app showed them: in the XML tree
// view, in the result of an XPath query, and in the editor after "format XML". The file only has to be
// opened. With a `SYSTEM "http://…"` entity the same document makes the app fetch a URL of its choosing.
//
// The canary is a real file in this test's own temp directory, so a pass means the entity was not
// resolved rather than that the path happened not to exist.

import XCTest
@testable import PCFoundation

final class XMLExternalEntityTests: XCTestCase {
    private var dir: URL!
    private var canary: URL!
    private static let secret = "CANARY-a4f1-must-not-appear"

    override func setUpWithError() throws {
        try super.setUpWithError()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCXXE-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        canary = dir.appendingPathComponent("secret.txt")
        try Self.secret.write(to: canary, atomically: true, encoding: .utf8)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
        dir = nil; canary = nil
        try super.tearDownWithError()
    }

    /// A document that reads `canary` if external entities are resolved.
    private var hostileXML: String {
        """
        <?xml version="1.0"?>
        <!DOCTYPE d [ <!ENTITY x SYSTEM "file://\(canary.path)"> ]>
        <d><v>&x;</v></d>
        """
    }

    private func assertNoLeak(_ text: String?, _ what: String) {
        guard let text else { return }   // refusing the document outright is also fine
        XCTAssertFalse(text.contains(Self.secret), "\(what) disclosed the contents of another file")
    }

    // MARK: - The three places that parse XML

    /// Everything the tree holds, as one string: names, attribute values and leaf text.
    ///
    /// Not `String(describing:)` — XMLTreeNode is a class with no custom description, so that prints an
    /// address and the assertion would pass on any input whatsoever.
    private func flatten(_ node: XMLTreeNode) -> String {
        ([node.name, node.text ?? ""] + node.attributes.map(\.value) + node.children.map(flatten))
            .joined(separator: " ")
    }

    func testTheTreeViewDoesNotResolveAnExternalEntity() {
        assertNoLeak(XMLTreeParser.parse(hostileXML).map(flatten), "the XML tree")
    }

    func testAnXPathQueryDoesNotResolveAnExternalEntity() throws {
        let results = (try? XPathQuery.evaluate(xml: hostileXML, query: "//v")) ?? []
        assertNoLeak(results.joined(separator: "\n"), "the XPath result")
    }

    func testFormattingDoesNotResolveAnExternalEntity() {
        let formatted = try? XMLFormatter().format(hostileXML)
        assertNoLeak(formatted, "the formatted document")
    }

    func testTheParserItselfLeavesTheEntityUnresolved() throws {
        let doc = try XCTUnwrap(XMLParsing.document(hostileXML))
        assertNoLeak(doc.rootElement()?.stringValue, "XMLParsing.document")
    }

    // MARK: - …and ordinary XML still reads exactly as before

    func testAnInternalEntityStillWorks() throws {
        // The fix must not cost `&amp;` and friends, which are resolved by the parser itself and have
        // nothing to do with loading anything.
        let doc = try XCTUnwrap(XMLParsing.document("<d><v>a &amp; b</v></d>"))
        XCTAssertEqual(doc.rootElement()?.stringValue, "a & b")
    }

    func testAnOrdinaryDocumentStillParses() throws {
        let root = try XCTUnwrap(XMLTreeParser.parse("<config><host>alpha</host></config>"))
        XCTAssertTrue(flatten(root).contains("config"))
        XCTAssertTrue(flatten(root).contains("alpha"))
    }
}
