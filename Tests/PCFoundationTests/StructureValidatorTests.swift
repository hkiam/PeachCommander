// SPDX-License-Identifier: Apache-2.0
// StructureValidatorTests.swift - Validation with a position (F-369).
//
// The position is the whole feature: "invalid JSON" is what the formatter already says. So every test
// that expects a problem also checks that the offset points at the character the user has to fix.

import XCTest
@testable import PCFoundation

final class StructureValidatorTests: XCTestCase {

    private func problem(_ text: String, ext: String) -> StructureValidator.Problem? {
        if case .problem(let p) = StructureValidator.validate(text, ext: ext) { return p }
        return nil
    }

    /// The character the reported offset points at — what the caret would land on.
    private func character(_ text: String, at offset: Int) -> String {
        let ns = text as NSString
        guard offset < ns.length else { return "" }
        return ns.substring(with: NSRange(location: offset, length: 1))
    }

    // MARK: - JSON

    func testValidJSONIsReportedValid() {
        XCTAssertEqual(StructureValidator.validate("{\"a\": [1, 2]}", ext: "json"),
                       .valid(parser: "JSONSerialization"))
    }

    func testJSONErrorCarriesThePositionOfTheOffendingCharacter() {
        let json = "{\n  \"a\": 1,\n  \"b\" 2\n}"
        let p = problem(json, ext: "json")
        XCTAssertEqual(p?.line, 3)
        XCTAssertEqual(character(json, at: p?.utf16Location ?? -1), "2")
    }

    func testTheJSONPositionSurvivesNonASCIIText() {
        // JSONSerialization reports a *byte* index. With three two-byte characters ahead of the error,
        // using it directly puts the caret three characters late — close enough to look correct.
        let json = "{\n  \"ä\": \"öü\",\n  \"b\" 2\n}"
        let p = problem(json, ext: "json")
        XCTAssertEqual(character(json, at: p?.utf16Location ?? -1), "2")
    }

    func testADuplicateJSONKeyIsAProblemEvenThoughItParses() {
        // JSONSerialization accepts this and keeps the last value. Nothing else in the toolchain will
        // mention it, and in a config file it is always a bug.
        let json = "{\n  \"port\": 80,\n  \"host\": \"a\",\n  \"port\": 8080\n}"
        let p = problem(json, ext: "json")
        XCTAssertEqual(p?.line, 4)
        XCTAssertEqual(p?.reason, .duplicateKey(key: "port", firstLine: 2))
    }

    func testTheSameKeyInDifferentObjectsIsNotADuplicate() {
        XCTAssertEqual(StructureValidator.validate("{\"a\": {\"x\": 1}, \"b\": {\"x\": 2}}", ext: "json"),
                       .valid(parser: "JSONSerialization"))
    }

    // MARK: - XML

    func testValidXMLIsReportedValid() {
        XCTAssertEqual(StructureValidator.validate("<a><b/></a>", ext: "xml"), .valid(parser: "XMLParser"))
    }

    func testXMLErrorCarriesALineAndAPosition() {
        let xml = "<config>\n  <server>\n    <port>80</port>\n</config>\n"
        let p = problem(xml, ext: "xml")
        XCTAssertEqual(p?.line, 4)
        XCTAssertNotNil(p?.reason)
        XCTAssertLessThanOrEqual(p?.utf16Location ?? 0, (xml as NSString).length)
    }

    func testAMismatchedTagIsFound() {
        XCTAssertNotNil(problem("<a><b></c></a>", ext: "xml"))
    }

    // MARK: - YAML

    func testCleanYAMLIsReportedAsCheckedNotValid() {
        // There is no YAML parser here, and saying "valid" would be a claim this cannot make.
        guard case .checked = StructureValidator.validate("a: 1\nb:\n  c: 2\n", ext: "yml") else {
            return XCTFail("expected .checked")
        }
    }

    func testATabInTheIndentationIsFound() {
        let yaml = "a:\n\tb: 1\n"
        let p = problem(yaml, ext: "yaml")
        XCTAssertEqual(p?.line, 2)
        XCTAssertEqual(character(yaml, at: p?.utf16Location ?? -1), "\t")
    }

    func testATabInsideAValueIsNotAnError() {
        guard case .checked = StructureValidator.validate("a: one\ttwo\n", ext: "yaml") else {
            return XCTFail("a tab in a value is legal")
        }
    }

    func testADuplicateYAMLKeyInTheSameMappingIsFound() {
        let yaml = "services:\n  web: 1\n  db: 2\n  web: 3\n"
        let p = problem(yaml, ext: "yaml")
        XCTAssertEqual(p?.line, 4)
        XCTAssertEqual(p?.reason, .duplicateKey(key: "web", firstLine: 2))
    }

    func testTheSameKeyUnderDifferentParentsIsNotADuplicate() {
        guard case .checked = StructureValidator.validate("a:\n  x: 1\nb:\n  x: 2\n", ext: "yaml") else {
            return XCTFail("different mappings, same key — legal")
        }
    }

    func testIndentationThatLinesUpWithNothingIsFound() {
        // The one-space slip. A real parser reports this several lines later, if at all.
        let yaml = "a:\n  b: 1\n   c: 2\n"
        let p = problem(yaml, ext: "yaml")
        XCTAssertEqual(p?.line, 3)
    }

    func testKeysInsideABlockScalarAreNotChecked() {
        guard case .checked = StructureValidator.validate("""
        script: |
          a: 1
          a: 2
             odd: indent
        after: 1
        """, ext: "yaml") else { return XCTFail("a block scalar is text") }
    }

    func testAnUnterminatedQuoteIsFound() {
        let yaml = "a: \"unclosed\nb: 1\n"
        XCTAssertEqual(problem(yaml, ext: "yaml")?.line, 1)
    }

    func testAQuoteInsideACommentIsNotAnError() {
        guard case .checked = StructureValidator.validate("a: 1  # it's fine\n", ext: "yaml") else {
            return XCTFail("apostrophe in a comment")
        }
    }

    func testASecondDocumentResetsTheIndentationLevels() {
        guard case .checked = StructureValidator.validate("a:\n  b: 1\n---\nc: 2\n", ext: "yaml") else {
            return XCTFail("--- starts over")
        }
    }

    // MARK: - Offsets and support

    func testAByteIndexInsideAMultiByteCharacterDoesNotThrowOffTheOffset() {
        let text = "äöü"
        // Byte 3 is the middle of "ö"; the offset must still be a valid character boundary.
        XCTAssertEqual(StructureValidator.utf16Offset(forUTF8Byte: 3, in: text), 1)
        XCTAssertEqual(StructureValidator.utf16Offset(forUTF8Byte: 999, in: text), 3)
    }

    // MARK: - Valid documents that earlier versions rejected
    //
    // Every case here comes from measuring: 400 YAML files that Ruby's Psych accepts, 300 JSON files
    // against Python's json module, and 236 deliberately broken XML files against xmllint. Each of these
    // shapes was flagged by a version of this validator that passed all the tests above it.

    func testAMultiLinePlainScalarIsNotMisindentation() {
        // docs/metadata/screenshot-index.yml: a long `alt:` text continued on the next, deeper line.
        guard case .checked = StructureValidator.validate("""
        - id: uninstaller
          alt: The Uninstaller plugin's review window listing an app and its leftover files
            with sizes
          caption: Review every file before it is removed.
        """, ext: "yml") else { return XCTFail("a plain scalar may continue on deeper lines") }
    }

    func testAnApostropheInAPlainScalarIsNotAQuote() {
        // Four of this repository's own files say "the plugin's settings window".
        guard case .checked = StructureValidator.validate("alt: the plugin's settings window\n",
                                                         ext: "yaml") else {
            return XCTFail("an apostrophe in prose is not a quoted scalar")
        }
    }

    func testAListItemsKeysLineUpAfterTheDash() {
        // Homebrew's docs/_config.yml. `- scope:` puts its mapping at the column after the dash, and
        // `values:` is a sibling of `scope`, not misindented.
        guard case .checked = StructureValidator.validate("""
        defaults:
          - scope:
              path: ""
            values:
              layout: default
        """, ext: "yml") else { return XCTFail("the item's keys line up after the dash") }
    }

    func testAWorkflowStepWithNestedKeysIsValid() {
        // Every GitHub workflow in this repository has this shape.
        guard case .checked = StructureValidator.validate("""
        jobs:
          build:
            steps:
              - uses: actions/checkout@v4
                with:
                  fetch-depth: 0
        """, ext: "yml") else { return XCTFail("a step's `with:` is not scalar text") }
    }

    func testAFlowCollectionMayRunOverSeveralLines() {
        // docs/metadata/features.yml.
        guard case .checked = StructureValidator.validate("""
        meta:
          categories: [navigation, panels, archive,
                       settings, plugins]
          audiences: [user, developer]
        """, ext: "yml") else { return XCTFail("a flow sequence may wrap") }
    }

    func testAnAnchorIsNotAValue() {
        // docs/metadata/screenshot-specs.yml: `_preamble: &main` still opens a block.
        guard case .checked = StructureValidator.validate("""
        _preamble: &main
          - left /Users/admin
          - active l
        """, ext: "yml") else { return XCTFail("an anchor is not the value") }
    }

    func testAnEscapedQuoteDoesNotEndAMultiLineQuotedScalar() {
        // Homebrew's rubydex.dep.yml carries the Apache licence as one quoted scalar containing HTML with
        // escaped quotes; closing at the first quote put this check back into the prose, where it found
        // "keys" and reported duplicates.
        guard case .checked = StructureValidator.validate("""
        notice: "a line with <li class=\\"x\\"> in it
          and a second line: with a colon in prose
          and the real end here"
        after: 1
        """, ext: "yml") else { return XCTFail("an escaped quote closes nothing") }
    }

    func testATrailingCommaIsReportedEvenThoughAppleAcceptsIt() {
        // JSONSerialization parses this; Python, Go and jq refuse it. Two files in Homebrew's own
        // .vscode directory are like this, and they are the reason this check exists.
        let json = "{\n  \"a\": [\n    \"x\",\n  ],\n}"
        let p = problem(json, ext: "json")
        XCTAssertEqual(character(json, at: p?.utf16Location ?? -1), ",")
        XCTAssertEqual(p?.line, 3)
    }

    func testATrailingCommaIsAllowedInJSONC() {
        // .jsonc allows both comments and trailing commas by design.
        guard case .problem(let p) = StructureValidator.validate("{\n  \"a\": 1,\n}", ext: "jsonc") else {
            return          // no complaint is the expected outcome
        }
        XCTAssertNotEqual(p.reason, .trailingComma, "jsonc allows a trailing comma")
    }

    func testACommaInsideAStringIsNotATrailingComma() {
        XCTAssertEqual(StructureValidator.validate("{\"a\": \"x,\"}", ext: "json"),
                       .valid(parser: "JSONSerialization"))
    }

    func testUnsupportedFormats() {
        XCTAssertEqual(StructureValidator.validate("let a = 1", ext: "swift"), .unsupported)
        XCTAssertFalse(StructureValidator.supports(ext: "swift"))
        XCTAssertTrue(StructureValidator.supports(ext: "plist"))
    }
}
