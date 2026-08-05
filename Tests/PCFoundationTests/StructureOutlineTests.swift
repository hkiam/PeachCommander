// SPDX-License-Identifier: Apache-2.0
// StructureOutlineTests.swift - An outline for JSON, YAML and XML (F-368).
//
// The offsets are the point: an outline entry that cannot be jumped to is decoration, and both
// `JSONSerialization` and `XMLDocument` throw positions away. So every test that checks a name also
// checks that the recorded offset really points at that name in the text.

import XCTest
@testable import PCFoundation

final class StructureOutlineTests: XCTestCase {

    /// The text at a node's recorded location — what the editor would select when you click the entry.
    private func text(_ source: String, at node: SymbolNode, length: Int) -> String {
        let ns = source as NSString
        return ns.substring(with: NSRange(location: node.utf16Location, length: length))
    }

    // MARK: - JSON

    func testJSONKeysBecomeNodesWithUsableOffsets() {
        let json = """
        {
          "name": "peach",
          "server": { "port": 8080 }
        }
        """
        let roots = StructureOutline.parse(json, ext: "json")
        XCTAssertEqual(roots.map(\.name), ["name", "server"])
        XCTAssertEqual(roots[1].children.map(\.name), ["port"])
        // The location must point at the key, quote included, or clicking the entry lands elsewhere.
        XCTAssertEqual(text(json, at: roots[0], length: 6), "\"name\"")
        XCTAssertEqual(text(json, at: roots[1].children[0], length: 6), "\"port\"")
        XCTAssertEqual(roots[1].line, 3)
    }

    func testASingleRootObjectIsUnwrapped() {
        // One "(root)" entry above everything adds a level and no information.
        XCTAssertEqual(StructureOutline.parse("{\"a\": 1}", ext: "json").map(\.name), ["a"])
    }

    func testObjectAndValueKindsAreDistinguished() {
        let roots = StructureOutline.parse("{\"o\":{},\"a\":[],\"v\":3}", ext: "json")
        XCTAssertEqual(roots.map(\.kind), ["object", "array", "value"])
    }

    func testArrayScalarsGetNoNodesButContainersDo() {
        // A list of numbers must not bury the structure around it; a list of objects is what people
        // navigate, so each element is an entry.
        let scalars = StructureOutline.parse("{\"xs\":[1,2,3,4]}", ext: "json")
        XCTAssertEqual(scalars[0].children.count, 0)
        let objects = StructureOutline.parse("{\"xs\":[{\"a\":1},{\"b\":2}]}", ext: "json")
        XCTAssertEqual(objects[0].children.map(\.name), ["[0]", "[1]"])
        XCTAssertEqual(objects[0].children[1].children.map(\.name), ["b"])
    }

    func testABrokenDocumentStillOutlinesUpToTheBreak() {
        // The case where an outline matters most: a missing brace. A parser gives nothing here.
        let roots = StructureOutline.parse("{\"a\": 1, \"b\": { \"c\": 2", ext: "json")
        XCTAssertEqual(roots.map(\.name), ["a", "b"])
        XCTAssertEqual(roots[1].children.map(\.name), ["c"])
    }

    func testJSONCommentsAreSkipped() {
        let roots = StructureOutline.parse("""
        {
          // a line comment
          "a": 1,
          /* and a block one */
          "b": 2
        }
        """, ext: "jsonc")
        XCTAssertEqual(roots.map(\.name), ["a", "b"])
    }

    func testEscapedQuotesInsideAKeyDoNotEndIt() {
        let roots = StructureOutline.parse("{\"a\\\"b\": 1}", ext: "json")
        XCTAssertEqual(roots.map(\.name), ["a\\\"b"])
    }

    func testSeveralDocumentsInOneFile() {
        let roots = StructureOutline.parse("{\"a\":1}\n{\"b\":2}\n", ext: "ndjson")
        XCTAssertEqual(roots.map(\.name), ["(root)", "(document 2)"])
    }

    // MARK: - YAML

    func testYAMLNestsByIndentation() {
        let yaml = """
        version: "3"
        services:
          web:
            image: nginx
            ports:
              - "80:80"
        """
        let roots = StructureOutline.parse(yaml, ext: "yml")
        XCTAssertEqual(roots.map(\.name), ["version", "services"])
        XCTAssertEqual(roots[1].children.map(\.name), ["web"])
        XCTAssertEqual(roots[1].children[0].children.map(\.name), ["image", "ports"])
        XCTAssertEqual(text(yaml, at: roots[1].children[0], length: 3), "web")
    }

    func testYAMLListItemsAreLabelledByTheirFirstKey() {
        // "[0]", "[1]" says nothing about a list of jobs; "[0] name" does.
        let roots = StructureOutline.parse("""
        steps:
          - name: build
            run: make
          - name: test
            run: make test
        """, ext: "yaml")
        XCTAssertEqual(roots[0].children.map(\.name), ["[0] name", "[1] name"])
    }

    func testYAMLColonWithoutSpaceIsNotAKeySeparator() {
        // Found on screen, not here: a compose file's port list showed up as `[0] "80`. In YAML a colon
        // only separates a key from a value when a space or the line end follows it — and never inside
        // quotes, or `"a:b": v` loses half its key.
        let roots = StructureOutline.parse("""
        ports:
          - "80:80"
          - 443:443
        image: nginx:1.25
        "a:b": v
        """, ext: "yaml")
        XCTAssertEqual(roots.map(\.name), ["ports", "image", "\"a:b\""])
        XCTAssertEqual(roots[0].children.map(\.name), ["[0] \"80:80\"", "[1] 443:443"])
    }

    func testYAMLBlockScalarsAreNotMistakenForKeys() {
        // `key: value` inside a literal block is text, not structure.
        let roots = StructureOutline.parse("""
        script: |
          echo "not: a key"
          also: not a key
        after: 1
        """, ext: "yaml")
        XCTAssertEqual(roots.map(\.name), ["script", "after"])
    }

    func testYAMLCommentsAndBlankLinesAreIgnored() {
        let roots = StructureOutline.parse("# top\n\na: 1\n\n# mid\nb: 2\n", ext: "yaml")
        XCTAssertEqual(roots.map(\.name), ["a", "b"])
    }

    func testYAMLMultipleDocuments() {
        let roots = StructureOutline.parse("a: 1\n---\nb: 2\n", ext: "yaml")
        XCTAssertEqual(roots.map(\.name), ["a", "(document 2)"])
        XCTAssertEqual(roots[1].children.map(\.name), ["b"])
    }

    // MARK: - XML

    func testXMLElementsNestAndCarryTheirIdentifyingAttribute() {
        let xml = """
        <config>
          <server id="web-1"><port>8080</port></server>
          <server id="web-2"/>
        </config>
        """
        let roots = StructureOutline.parse(xml, ext: "xml")
        XCTAssertEqual(roots.map(\.name), ["server #web-1", "server #web-2"])
        XCTAssertEqual(roots[0].children.map(\.name), ["port"])
        XCTAssertEqual(text(xml, at: roots[0], length: 6), "server")
    }

    func testXMLDeclarationsCommentsAndCDATAAreSkipped() {
        let roots = StructureOutline.parse("""
        <?xml version="1.0"?>
        <!-- a comment with <fake> in it -->
        <root><a><![CDATA[<not a tag>]]></a></root>
        """, ext: "xml")
        XCTAssertEqual(roots.map(\.name), ["a"])
    }

    func testXMLSelfClosingElementsDoNotSwallowTheirSiblings() {
        let roots = StructureOutline.parse("<r><a/><b/><c/></r>", ext: "xml")
        XCTAssertEqual(roots.map(\.name), ["a", "b", "c"])
    }

    func testAnUnclosedXMLTagStillOutlines() {
        let roots = StructureOutline.parse("<r><a><b>text", ext: "xml")
        XCTAssertEqual(roots.map(\.name), ["a"])
        XCTAssertEqual(roots[0].children.map(\.name), ["b"])
    }

    // MARK: - Limits and containment

    func testTheNodeCountIsCapped() {
        // A vast document must not build an outline out of memory nobody has.
        let many = "{" + (0..<20_000).map { "\"k\($0)\":\($0)" }.joined(separator: ",") + "}"
        let roots = StructureOutline.parse(many, ext: "json")
        XCTAssertLessThanOrEqual(roots.count, StructureOutline.nodeLimit)
        XCTAssertGreaterThan(roots.count, 100, "it should still produce a useful outline")
    }

    func testANodeSpansItsContentsSoTheBreadcrumbCanFindIt() {
        // The breadcrumb asks which nodes enclose the caret, which needs start…end to cover the value.
        let json = "{\"outer\": {\"inner\": 1}}"
        let roots = StructureOutline.parse(json, ext: "json")
        let outer = roots[0]
        let inner = outer.children[0]
        XCTAssertLessThan(outer.start, inner.start)
        XCTAssertGreaterThanOrEqual(outer.end, inner.end)
        XCTAssertGreaterThan(outer.end, outer.start)
    }

    func testUnknownExtensionsProduceNothing() {
        XCTAssertFalse(StructureOutline.supports(ext: "swift"))
        XCTAssertTrue(StructureOutline.parse("{\"a\":1}", ext: "swift").isEmpty)
    }

    func testADocumentPastTheNodeLimitStillReturns() {
        // This spun a CPU forever. Past the limit, `value` returned nil, the loops above it broke out
        // *without consuming their container*, and the array loop then sat on a `}` in element position —
        // a character the scalar skipper refuses to move past. Every JSON file with more than 5000 nodes
        // did this, on a background thread, silently. Found by validating this repository's own vendored
        // tree-sitter grammars, not by a test.
        let objects = (0..<3_000).map { "{\"key\(  $0 )\": {\"a\": 1, \"b\": 2}}" }.joined(separator: ",")
        let roots = StructureOutline.parse("[\(objects)]", ext: "json")
        XCTAssertFalse(roots.isEmpty)
        XCTAssertLessThanOrEqual(countNodes(roots), StructureOutline.nodeLimit)
    }

    private func countNodes(_ nodes: [SymbolNode]) -> Int {
        nodes.reduce(0) { $0 + 1 + countNodes($1.children) }
    }

    func testAStrayCloserInsideAnArrayDoesNotStall() {
        // Malformed input is the normal case for this parser, so a scanner that cannot advance has to
        // stop rather than loop.
        let roots = StructureOutline.parse("{\"xs\": [1, }, 2]}", ext: "json")
        XCTAssertEqual(roots.map(\.name), ["xs"])
    }
}
