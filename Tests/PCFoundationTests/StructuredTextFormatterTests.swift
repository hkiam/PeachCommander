// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class StructuredTextFormatterTests: XCTestCase {
    func testJSONPrettyPrintsAndSortsKeys() {
        let out = StructuredTextFormatter.json(#"{"b":1,"a":2}"#)
        let text = try? XCTUnwrap(out)
        XCTAssertNotNil(text)
        guard let text else { return }
        XCTAssertTrue(text.contains("\n"), "should be multi-line")
        let aIdx = text.range(of: "\"a\"")!.lowerBound
        let bIdx = text.range(of: "\"b\"")!.lowerBound
        XCTAssertTrue(aIdx < bIdx, "keys should be sorted a before b")
    }

    func testJSONArray() {
        let out = StructuredTextFormatter.json("[1,2,3]")
        XCTAssertNotNil(out)
        XCTAssertTrue(out!.contains("\n"))
    }

    func testInvalidJSONReturnsNil() {
        XCTAssertNil(StructuredTextFormatter.json("{not json"))
        XCTAssertNil(StructuredTextFormatter.json("hello"))
    }

    func testXMLPrettyPrints() {
        let out = StructuredTextFormatter.xml("<a><b>1</b><c>2</c></a>")
        XCTAssertNotNil(out)
        XCTAssertTrue(out!.contains("\n"), "should be re-indented onto multiple lines")
        XCTAssertTrue(out!.contains("<b>1</b>"))
    }

    func testInvalidXMLReturnsNil() {
        XCTAssertNil(StructuredTextFormatter.xml("<a><b></a>"))   // mismatched tags
        XCTAssertNil(StructuredTextFormatter.xml("not xml at all {"))
    }

    func testAutoFormatPrefersRequestedKind() {
        // A string that is valid JSON but not XML → JSON regardless of preference.
        let r = StructuredTextFormatter.autoFormat(#"{"x":1}"#, preferXML: true)
        XCTAssertEqual(r?.kind, "JSON")
        // A string valid as XML only.
        let x = StructuredTextFormatter.autoFormat("<r><i>1</i></r>", preferXML: false)
        XCTAssertEqual(x?.kind, "XML")
        // Neither.
        XCTAssertNil(StructuredTextFormatter.autoFormat("plain text", preferXML: false))
    }
}
