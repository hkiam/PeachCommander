// SPDX-License-Identifier: Apache-2.0
// StructurePathTests.swift - The caret's path as jq/yq and XPath (F-369).
//
// Each test goes through the real outline, because that is what supplies the steps: a path built from
// hand-made nodes would prove the joining and nothing about the parsers.

import XCTest
@testable import PCFoundation

final class StructurePathTests: XCTestCase {

    /// The path at the offset of `needle`'s first occurrence in `source`.
    private func path(_ source: String, ext: String, at needle: String) -> String? {
        let roots = StructureOutline.parse(source, ext: ext)
        let style = StructurePath.style(forExtension: ext)!
        let offset = (source as NSString).range(of: needle).location
        XCTAssertNotEqual(offset, NSNotFound, "fixture does not contain \(needle)")
        return StructurePath.path(roots, utf16: offset, style: style)
    }

    func testJSONPathIsAJqFilter() {
        let json = """
        {
          "services": {
            "web": { "ports": [{ "host": 80 }] }
          }
        }
        """
        XCTAssertEqual(path(json, ext: "json", at: "\"host\""), ".services.web.ports[0].host")
        XCTAssertEqual(path(json, ext: "json", at: "\"web\""), ".services.web")
    }

    func testKeysThatAreNotIdentifiersAreQuoted() {
        // `.content-type` is a subtraction in jq, `."content-type"` is the key. Copying the first one
        // gives an expression that runs and answers the wrong question, which is worse than an error.
        let json = "{\"content-type\": 1, \"a b\": 2, \"ok_1\": 3}"
        XCTAssertEqual(path(json, ext: "json", at: "\"content-type\""), ".\"content-type\"")
        XCTAssertEqual(path(json, ext: "json", at: "\"a b\""), ".\"a b\"")
        XCTAssertEqual(path(json, ext: "json", at: "\"ok_1\""), ".ok_1")
    }

    func testYAMLPathUsesTheSameNotationAsYq() {
        let yaml = """
        services:
          web:
            ports:
              - "80:80"
        """
        XCTAssertEqual(path(yaml, ext: "yml", at: "ports"), ".services.web.ports")
        XCTAssertEqual(path(yaml, ext: "yml", at: "- \"80"), ".services.web.ports[0]")
    }

    func testAYAMLListItemContributesBothItsIndexAndItsKey() {
        // `- name: build` is one line and two steps.
        let yaml = """
        steps:
          - name: build
            run: make
          - name: test
        """
        XCTAssertEqual(path(yaml, ext: "yaml", at: "name: build"), ".steps[0].name")
        XCTAssertEqual(path(yaml, ext: "yaml", at: "run: make"), ".steps[0].run")
        XCTAssertEqual(path(yaml, ext: "yaml", at: "name: test"), ".steps[1].name")
    }

    func testQuotedYAMLKeysLoseTheirQuotesAndGainJqQuoting() {
        XCTAssertEqual(path("\"a:b\": v\n", ext: "yaml", at: "\"a:b\""), ".\"a:b\"")
    }

    func testXMLPathPrefersAnIdentifyingAttribute() {
        let xml = """
        <config>
          <server id="web-1">
            <port>8080</port>
          </server>
        </config>
        """
        XCTAssertEqual(path(xml, ext: "xml", at: "<port>"), "//server[@id='web-1']/port")
    }

    func testXMLPathFallsBackToAPositionalPredicate() {
        // Without an attribute to go by, the index among same-named siblings is the only way to say
        // *which* host — and an XPath without it silently selects all of them.
        let xml = "<config><host><ip>1</ip></host><host><ip>2</ip></host></config>"
        XCTAssertEqual(path(xml, ext: "xml", at: "<ip>2"), "//host[2]/ip")
        XCTAssertEqual(path(xml, ext: "xml", at: "<ip>1"), "//host[1]/ip")
    }

    func testAnAttributeValueWithAQuoteFallsBackRatherThanBreakTheExpression() {
        // `id="it's"` cannot go into a single-quoted predicate; a positional one is still correct.
        let xml = "<r><a id=\"it's\"><b/></a><a id=\"x\"><b/></a></r>"
        XCTAssertEqual(path(xml, ext: "xml", at: "<b/>"), "//a[1]/b")
    }

    func testDocumentLabelsAreNotPathSteps() {
        // "(document 2)" is the outline's word for a second document in one file, not a key.
        let roots = StructureOutline.parse("{\"a\":1}\n{\"b\":2}\n", ext: "ndjson")
        let offset = ("{\"a\":1}\n{\"b\":2}\n" as NSString).range(of: "\"b\"").location
        XCTAssertEqual(StructurePath.path(roots, utf16: offset, style: .query), ".b")
    }

    func testFormatsWithoutAPathNotationSaySo() {
        XCTAssertNil(StructurePath.style(forExtension: "swift"))
        XCTAssertNil(StructurePath.style(forExtension: "txt"))
    }

    func testAnOffsetInsideNothingHasNoPath() {
        let roots = StructureOutline.parse("{\"a\": 1}", ext: "json")
        XCTAssertNil(StructurePath.path(roots, utf16: 9_999, style: .query))
    }
}
