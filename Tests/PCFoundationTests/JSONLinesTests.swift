// SPDX-License-Identifier: Apache-2.0
// JSONLinesTests.swift - JSON Lines is not one JSON document (F-412).
//
// `.jsonl` / `.ndjson` hold one complete JSON value per line. Highlighting, the outline and the path
// queries already read the format that way; the validator did not — it handed the whole file to
// JSONSerialization, which reports the *second record* as garbage after the end of the first, so every
// valid JSON Lines file was marked broken. And formatting was simply absent for it, which is the safer
// half of the same story: the JSON formatter would have pretty-printed the file into one that is no
// longer JSON Lines at all.

import XCTest
@testable import PCFoundation

final class JSONLinesTests: XCTestCase {

    private let sample = """
    {"id":1,"name":"alpha"}
    {"id":2,"name":"beta"}
    {"id":3,"name":"gamma"}
    """

    // MARK: - Validation

    func testAValidJSONLinesFileIsValid() {
        guard case .valid = StructureValidator.validate(sample, ext: "jsonl") else {
            return XCTFail("a valid .jsonl must not be reported as a problem")
        }
        guard case .valid = StructureValidator.validate(sample, ext: "ndjson") else {
            return XCTFail(".ndjson is the same format")
        }
    }

    /// The same text as `.json` *is* invalid — one document, two values — which is what the old code
    /// reported for the `.jsonl` above.
    func testTheSameTextAsPlainJSONIsStillAProblem() {
        guard case .problem = StructureValidator.validate(sample, ext: "json") else {
            return XCTFail("two documents in one .json file is a problem")
        }
    }

    func testTheBadRecordIsNamedByItsOwnLine() {
        let text = """
        {"id":1}
        {"id":2,}
        {"id":3}
        """
        guard case .problem(let problem) = StructureValidator.validate(text, ext: "jsonl") else {
            return XCTFail("expected a problem")
        }
        XCTAssertEqual(problem.line, 2)
        // The caret belongs in the document, not at the offset within the line.
        XCTAssertGreaterThan(problem.utf16Location, 9)
    }

    func testBlankLinesAndATrailingNewlineAreFine() {
        guard case .valid = StructureValidator.validate("{\"a\":1}\n\n{\"a\":2}\n", ext: "jsonl") else {
            return XCTFail("blank lines are not records")
        }
    }

    /// A pretty-printed object spanning several lines is exactly the mistake the format has, and it is
    /// reported on the line where the incomplete record starts.
    func testAMultiLineRecordIsAProblem() {
        let text = """
        {"id":1}
        {
          "id": 2
        }
        """
        guard case .problem(let problem) = StructureValidator.validate(text, ext: "jsonl") else {
            return XCTFail("a record split across lines is not JSON Lines")
        }
        XCTAssertEqual(problem.line, 2)
    }

    func testScalarRecordsAreValid() {
        guard case .valid = StructureValidator.validate("42\n\"text\"\ntrue\nnull", ext: "jsonl") else {
            return XCTFail("a record may be any JSON value")
        }
    }

    // MARK: - Formatting

    func testFormattingNormalisesEachRecordAndKeepsOnePerLine() throws {
        let formatted = try JSONLinesFormatter().format("""
        {  "b" : 2,  "a" : 1 }
        {"c":[1,   2]}
        """)
        XCTAssertEqual(formatted, "{\"a\":1,\"b\":2}\n{\"c\":[1,2]}\n")
        // The result is still JSON Lines — the property the JSON formatter would have destroyed.
        guard case .valid = StructureValidator.validate(formatted, ext: "jsonl") else {
            return XCTFail("formatting must not break the format")
        }
    }

    func testFormattingRefusesTheWholeFileForOneBadRecordAndNamesIt() {
        do {
            _ = try JSONLinesFormatter().format("{\"a\":1}\n{oops}\n{\"b\":2}")
            XCTFail("expected a failure")
        } catch let error as FormatError {
            // The line number is in the message: a half-formatted file is worse than none.
            XCTAssertTrue("\(error)".contains("line 2"), "the failure names the record: \(error)")
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testAlreadyFormattedContentReportsUnchanged() {
        XCTAssertThrowsError(try JSONLinesFormatter().format("{\"a\":1}\n")) { error in
            XCTAssertEqual(error as? FormatError, .unchanged)
        }
    }

    func testTheRegistryPicksItForJSONLines() {
        let registry = FormatterRegistry()
        XCTAssertEqual(registry.formatter(for: "jsonl")?.name, "JSON Lines")
        XCTAssertEqual(registry.formatter(for: "ndjson")?.name, "JSON Lines")
        // …and plain JSON still gets the JSON one (or an external tool, if installed).
        XCTAssertNotEqual(registry.formatter(for: "json")?.name, "JSON Lines")
    }

    // MARK: - Outline

    /// One entry per record, named by the line it starts on — "(document 4207)" is a number the reader
    /// would have to count out.
    func testTheOutlineNamesRecordsByLine() {
        let roots = StructureOutline.parse(sample, ext: "jsonl")
        XCTAssertEqual(roots.map(\.name), ["(line 1)", "(line 2)", "(line 3)"])
        XCTAssertEqual(roots.map(\.line), [1, 2, 3])
        // The members are there to expand into.
        XCTAssertEqual(roots.first?.children.map(\.name), ["id", "name"])
    }

    /// A single-record file shows its members directly, as a .json file does — one root adds a level
    /// without adding information.
    func testASingleRecordShowsItsMembers() {
        let roots = StructureOutline.parse("{\"id\":1,\"name\":\"alpha\"}", ext: "jsonl")
        XCTAssertEqual(roots.map(\.name), ["id", "name"])
    }
}
