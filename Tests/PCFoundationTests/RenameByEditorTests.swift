// SPDX-License-Identifier: Apache-2.0
// RenameByEditorTests.swift - Edit-names-in-editor round-trip (F-174).

import XCTest
@testable import PCFoundation

final class RenameByEditorTests: XCTestCase {
    func test_exportText_seedsNewColumnEqualToOld() {
        let text = RenameByEditor.exportText(["a.txt", "b.txt"])
        XCTAssertEqual(text, "a.txt\ta.txt\nb.txt\tb.txt\n")
    }

    func test_plan_returnsOnlyChangedPairs() {
        let originals = ["a.txt", "b.txt", "c.txt"]
        let edited = "a.txt\ta.txt\nb.txt\tB.txt\nc.txt\tc.txt\n"
        guard case .success(let pairs) = RenameByEditor.plan(originals: originals, editedText: edited) else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(pairs, [RenamePair(old: "b.txt", new: "B.txt")])
    }

    func test_plan_acceptsPlainNewNamesWithoutTab() {
        let pairs = try? RenameByEditor.plan(originals: ["a", "b"], editedText: "x\ny\n").get()
        XCTAssertEqual(pairs, [RenamePair(old: "a", new: "x"), RenamePair(old: "b", new: "y")])
    }

    func test_plan_countMismatch() {
        let r = RenameByEditor.plan(originals: ["a", "b"], editedText: "a\ta\n")
        XCTAssertEqual(r, .failure(.countMismatch(expected: 2, got: 1)))
    }

    func test_plan_emptyName() {
        let r = RenameByEditor.plan(originals: ["a", "b"], editedText: "a\ta\nb\t\n")
        XCTAssertEqual(r, .failure(.emptyName(line: 2)))
    }

    func test_plan_duplicateName() {
        let r = RenameByEditor.plan(originals: ["a", "b"], editedText: "a\tsame\nb\tsame\n")
        XCTAssertEqual(r, .failure(.duplicate("same")))
    }

    func test_plan_noTrailingNewline_ok() {
        guard case .success(let pairs) = RenameByEditor.plan(originals: ["a"], editedText: "a\tz") else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(pairs, [RenamePair(old: "a", new: "z")])
    }

    // MARK: - The list comes back from someone else's editor (F-175)

    func testACRLFListDoesNotPutACarriageReturnInTheFileName() {
        // The user edits this list in whatever editor they have configured, and one that writes CRLF left
        // a "\r" on the end of every line. `.whitespaces` does not contain a carriage return, so it
        // survived the trim and went into the new name — legal on macOS, so the rename succeeded and
        // produced files with an invisible character nothing else matches.
        let result = RenameByEditor.plan(originals: ["a.txt", "b.txt"],
                                         editedText: "a.txt\treport.txt\r\nb.txt\tnotes.txt\r\n")
        guard case .success(let pairs) = result else { return XCTFail("expected success, got \(result)") }
        XCTAssertEqual(pairs.map(\.new), ["report.txt", "notes.txt"])
        XCTAssertFalse(pairs.contains { $0.new.contains("\r") }, "no carriage return may reach a file name")
    }

    func testALoneCarriageReturnListIsAlsoSplit() {
        let result = RenameByEditor.plan(originals: ["a.txt", "b.txt"],
                                         editedText: "a.txt\tone.txt\rb.txt\ttwo.txt\r")
        guard case .success(let pairs) = result else { return XCTFail("expected success, got \(result)") }
        XCTAssertEqual(pairs.map(\.new), ["one.txt", "two.txt"])
    }
}
