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

    // MARK: - YAML (a whitespace tidy, not a re-indent — see StructuredTextFormatter.yaml)

    func testYAMLStripsTrailingWhitespaceAndCollapsesBlankLines() throws {
        let input = "name: peach   \n\n\n\nport: 8080\t\n"
        let out = try XCTUnwrap(StructuredTextFormatter.yaml(input))
        XCTAssertEqual(out, "name: peach\n\nport: 8080\n")
    }

    func testYAMLConvertsIndentationTabsOnly() throws {
        // A tab in indentation makes YAML unparseable, so converting it is a repair.
        // A tab elsewhere is left alone: it is invalid as separation but legal *content*
        // inside quoted and block scalars, and only a parser could tell those apart.
        let out = try XCTUnwrap(StructuredTextFormatter.yaml("root:\n\tchild:\tvalue\n"))
        XCTAssertEqual(out, "root:\n  child:\tvalue\n")
    }

    func testYAMLKeepsTabsInsideQuotedScalars() {
        // Legal content — must survive untouched, and there is nothing else to tidy here.
        XCTAssertNil(StructuredTextFormatter.yaml("k: \"a\tb\"\n"))
    }

    func testYAMLEndsWithExactlyOneNewline() throws {
        let out = try XCTUnwrap(StructuredTextFormatter.yaml("a: 1\n\n\n"))
        XCTAssertEqual(out, "a: 1\n")
    }

    func testYAMLReturnsNilWhenAlreadyTidy() {
        XCTAssertNil(StructuredTextFormatter.yaml("name: peach\nport: 8080\n"))
    }

    /// The safety-critical case: inside a block scalar, leading and trailing whitespace is
    /// content, so tidying it would corrupt data.
    func testYAMLPreservesBlockScalarContentVerbatim() throws {
        let input = """
        script: |
          line one   
            indented deeper

          after a blank line
        next: 1   

        """
        let out = try XCTUnwrap(StructuredTextFormatter.yaml(input))
        XCTAssertTrue(out.contains("  line one   \n"), "trailing spaces inside | must survive:\n\(out)")
        XCTAssertTrue(out.contains("    indented deeper\n"), "inner indentation must survive:\n\(out)")
        XCTAssertTrue(out.contains("\n\n  after a blank line\n"), "blank line inside | must survive:\n\(out)")
        XCTAssertTrue(out.contains("next: 1\n"), "the line after the block must still be tidied:\n\(out)")
    }

    func testYAMLBlockScalarIndicatorVariantsAreRecognised() {
        for indicator in ["|", "|-", "|+", ">", ">-", "|2"] {
            let input = "s: \(indicator)\n  keep me   \nafter: 1   \n"
            guard let out = StructuredTextFormatter.yaml(input) else {
                return XCTFail("expected a change for indicator \(indicator)")
            }
            XCTAssertTrue(out.contains("  keep me   \n"),
                          "indicator \(indicator) should open a block scalar:\n\(out)")
        }
    }

    func testYAMLTrailingCommentIsNotMistakenForBlockScalar() throws {
        // "value # |" ends in "|" only as comment text — the next line must still be tidied.
        let out = try XCTUnwrap(StructuredTextFormatter.yaml("a: value # |\n  b: 1   \n"))
        XCTAssertFalse(out.contains("  b: 1   \n"), "should have been tidied:\n\(out)")
    }

    func testAutoFormatByExtensionRoutesYAML() throws {
        let result = try XCTUnwrap(StructuredTextFormatter.autoFormat("a: 1   \n", extension: "yml"))
        XCTAssertEqual(result.kind, "YAML")
        XCTAssertEqual(result.text, "a: 1\n")
    }

    func testAutoFormatByExtensionStillPrefersXMLForXML() throws {
        let result = try XCTUnwrap(StructuredTextFormatter.autoFormat("<a><b/></a>", extension: "xml"))
        XCTAssertEqual(result.kind, "XML")
    }

    func testAutoFormatByExtensionDoesNotTidyNonYAMLText() {
        // Plain text is "valid YAML", so YAML must be chosen by extension only.
        XCTAssertNil(StructuredTextFormatter.autoFormat("just some prose   \n", extension: "txt"))
    }
}
