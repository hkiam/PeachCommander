// SPDX-License-Identifier: Apache-2.0
// StructureTransformsTests.swift - Whole-document transformations (F-370).
//
// The theme of these tests is *what must survive*: key order, number spelling, a version that happens to
// look like a float, a string that happens to spell `true`. A transformation that quietly changes one of
// those is worse than one that refuses, because it is written back to disk.

import XCTest
@testable import PCFoundation

final class StructureTransformsTests: XCTestCase {

    // MARK: - Minify

    func testMinifyRemovesWhitespaceBetweenTokens() throws {
        let json = """
        {
          "a": 1,
          "b": [1, 2]
        }
        """
        XCTAssertEqual(try StructureTransforms.minifyJSON(json), "{\"a\":1,\"b\":[1,2]}")
    }

    func testMinifyKeepsWhitespaceInsideStrings() throws {
        XCTAssertEqual(try StructureTransforms.minifyJSON("{ \"a\": \"two  words\\n\" }"),
                       "{\"a\":\"two  words\\n\"}")
    }

    func testMinifyPreservesKeyOrderAndNumberSpelling() throws {
        // Through JSONSerialization this comes back as {"b":1,"version":1} with the keys reordered — a
        // config file that no longer diffs against its neighbour, and a version that changed value.
        let json = "{\"zebra\": 1.0, \"alpha\": 12345678901234567890, \"m\": 1e3}"
        let out = try StructureTransforms.minifyJSON(json)
        XCTAssertEqual(out, "{\"zebra\":1.0,\"alpha\":12345678901234567890,\"m\":1e3}")
    }

    func testMinifyRefusesInvalidJSON() {
        XCTAssertThrowsError(try StructureTransforms.minifyJSON("{\"a\": }")) { error in
            guard case StructureTransforms.TransformError.invalid = error else {
                return XCTFail("expected .invalid, got \(error)")
            }
        }
    }

    func testMinifyDropsComments() throws {
        // .jsonc: the comments cannot survive minification (there is no newline left to end a `//`), and
        // minified output is for a machine.
        let jsonc = "{\n // a\n \"a\": 1, /* b */ \"b\": 2\n}"
        XCTAssertEqual(try StructureTransforms.minifyJSON(jsonc), "{\"a\":1,\"b\":2}")
    }

    func testMinifyKeepsASlashInsideAString() throws {
        XCTAssertEqual(try StructureTransforms.minifyJSON("{\"u\": \"http://x/y\"}"),
                       "{\"u\":\"http://x/y\"}")
    }

    // MARK: - Sort keys

    func testSortKeysSortsEveryLevel() throws {
        let out = try StructureTransforms.sortJSONKeys("{\"b\": 1, \"a\": {\"d\": 2, \"c\": 3}}")
        let lines = out.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        XCTAssertEqual(lines.filter { $0.hasPrefix("\"") }.map { String($0.prefix(3)) },
                       ["\"a\"", "\"c\"", "\"d\"", "\"b\""])
    }

    func testSortKeysDoesNotEscapeSlashes() throws {
        // `\/` is legal JSON and unreadable; a URL in a config file must stay a URL.
        let out = try StructureTransforms.sortJSONKeys("{\"u\": \"https://example.com/a\"}")
        XCTAssertTrue(out.contains("https://example.com/a"), out)
    }

    // MARK: - Escaping

    func testEscapeProducesAPastableJSONString() {
        XCTAssertEqual(StructureTransforms.escapeAsJSONString("line1\nline2\t\"quoted\""),
                       "\"line1\\nline2\\t\\\"quoted\\\"\"")
    }

    func testEscapingAWholeJSONDocumentIsTheCommonCase() {
        // A JSON document inside a JSON field — a webhook payload, a Kubernetes annotation.
        let inner = "{\"a\": 1}"
        XCTAssertEqual(StructureTransforms.escapeAsJSONString(inner), "\"{\\\"a\\\": 1}\"")
    }

    func testUnescapeIsTheInverse() throws {
        let original = "a\nb\t\"c\"\\d"
        let escaped = StructureTransforms.escapeAsJSONString(original)
        XCTAssertEqual(try StructureTransforms.unescapeJSONString(escaped), original)
    }

    func testUnescapeAcceptsTextWithoutSurroundingQuotes() throws {
        // Text copied from inside a document arrives without its quotes.
        XCTAssertEqual(try StructureTransforms.unescapeJSONString("a\\nb"), "a\nb")
    }

    func testUnescapeRefusesAnImpossibleEscape() {
        XCTAssertThrowsError(try StructureTransforms.unescapeJSONString("\"a\\qb\""))
    }

    // MARK: - JSON → YAML

    func testJSONBecomesBlockYAML() throws {
        let yaml = try StructureTransforms.jsonToYAML("""
        {"services": {"web": {"image": "nginx", "ports": [80, 443]}}}
        """)
        XCTAssertEqual(yaml, """
        services:
          web:
            image: nginx
            ports:
              - 80
              - 443

        """)
    }

    func testAStringThatLooksLikeSomethingElseIsQuoted() throws {
        // The classic: "1.10" is a version, `true` is the word, "" is a value. Emitted bare, YAML reads
        // them back as a float, a boolean and null.
        let yaml = try StructureTransforms.jsonToYAML(
            "{\"version\": \"1.10\", \"enabled\": \"true\", \"empty\": \"\", \"n\": \"no\"}")
        XCTAssertTrue(yaml.contains("version: \"1.10\""), yaml)
        XCTAssertTrue(yaml.contains("enabled: \"true\""), yaml)
        XCTAssertTrue(yaml.contains("empty: \"\""), yaml)
        XCTAssertTrue(yaml.contains("n: \"no\""), yaml)
    }

    func testRealBooleansAndNullAreNotQuoted() throws {
        let yaml = try StructureTransforms.jsonToYAML("{\"a\": true, \"b\": null, \"c\": 3}")
        XCTAssertTrue(yaml.contains("a: true"), yaml)
        XCTAssertTrue(yaml.contains("b: null"), yaml)
        XCTAssertTrue(yaml.contains("c: 3"), yaml)
    }

    func testAStringWithAColonOrHashIsQuoted() throws {
        let yaml = try StructureTransforms.jsonToYAML(
            "{\"a\": \"key: value\", \"b\": \"text # not a comment\", \"c\": \"-dash\"}")
        XCTAssertTrue(yaml.contains("a: \"key: value\""), yaml)
        XCTAssertTrue(yaml.contains("b: \"text # not a comment\""), yaml)
        XCTAssertTrue(yaml.contains("c: \"-dash\""), yaml)
    }

    func testEmptyContainersUseFlowStyle() throws {
        let yaml = try StructureTransforms.jsonToYAML("{\"o\": {}, \"a\": []}")
        XCTAssertTrue(yaml.contains("o: {}"), yaml)
        XCTAssertTrue(yaml.contains("a: []"), yaml)
    }

    func testAnArrayOfObjectsNestsUnderTheDash() throws {
        let yaml = try StructureTransforms.jsonToYAML("{\"steps\": [{\"run\": \"make\"}]}")
        XCTAssertEqual(yaml, """
        steps:
          -
            run: make

        """)
    }

    func testTheYAMLOutputSurvivesTheProjectsOwnChecks() throws {
        // Emitting YAML that the app's own validator rejects would be an embarrassing round trip.
        let yaml = try StructureTransforms.jsonToYAML("""
        {"a": {"b": [1, {"c": "x: y"}]}, "d": "1.0", "e": null}
        """)
        guard case .checked = StructureValidator.validate(yaml, ext: "yaml") else {
            return XCTFail("own validator rejects own output:\n\(yaml)")
        }
        // …and the outline can navigate it.
        XCTAssertEqual(StructureOutline.parse(yaml, ext: "yaml").map(\.name), ["a", "d", "e"])
    }

    // MARK: - Availability

    func testWhichTransformsApplyToWhichFormat() {
        XCTAssertEqual(Set(StructureTransforms.available(forExtension: "json")),
                       Set(StructureTransforms.Transform.allCases))
        // Escaping is text work and applies to anything; minifying a YAML file does not.
        XCTAssertEqual(StructureTransforms.available(forExtension: "yml"),
                       [.escapeAsJSONString, .unescapeJSONString])
        XCTAssertEqual(StructureTransforms.available(forExtension: "txt"),
                       [.escapeAsJSONString, .unescapeJSONString])
    }
}
