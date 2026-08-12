// SPDX-License-Identifier: Apache-2.0
// PanelFilterQueryTests.swift — the quick filter's grammar (F-397).
//
// Two promises are worth pinning here, because breaking either is invisible until somebody's filter
// quietly stops finding things: text that names no column keeps its old meaning (ONE substring,
// spaces and colons included), and a term that does name one is aimed at that column alone.

import XCTest
import PCFoundation

final class PanelFilterQueryTests: XCTestCase {
    private let fields = ["taskman.pid", "taskman.cpu", "taskman.user", "taskman.state", "taskman.command"]

    private func matches(_ text: String, row: [String: String], name: String = "") -> Bool {
        let q = PanelFilterQuery.parse(text, fieldIDs: fields)
        return q.matches(value: { row[$0] ?? "" }, anywhere: { [name] + Array(row.values) })
    }

    // MARK: - Plain text behaves exactly as it did

    func testPlainTextIsOneSubstringIncludingSpaces() {
        let q = PanelFilterQuery.parse("Google Chrome", fieldIDs: fields)
        XCTAssertFalse(q.isScoped)
        XCTAssertEqual(q.terms.count, 1, "a space must not split plain text into two terms")
        XCTAssertEqual(q.terms.first?.needle, "google chrome")
        XCTAssertNil(q.terms.first?.fieldID)
    }

    func testPlainTextMatchesTheNameOrAnyShownValue() {
        XCTAssertTrue(matches("chrome", row: [:], name: "Google Chrome (42)"))
        XCTAssertTrue(matches("root", row: ["taskman.user": "root"], name: "mds (77)"))
        XCTAssertFalse(matches("nobody", row: ["taskman.user": "root"], name: "mds (77)"))
    }

    /// A colon that is not a field name must stay text — file names contain them, and so do times.
    func testAColonThatNamesNoFieldIsStillText() {
        let q = PanelFilterQuery.parse("notes: draft", fieldIDs: fields)
        XCTAssertFalse(q.isScoped)
        XCTAssertEqual(q.terms.first?.needle, "notes: draft")
        XCTAssertTrue(matches("12:30", row: [:], name: "backup 12:30.txt"))
    }

    /// "user:" with nothing after it filters nothing — it is half-typed, not a request for empties.
    func testAFieldPrefixWithoutAValueIsPlainText() {
        let q = PanelFilterQuery.parse("user:", fieldIDs: fields)
        XCTAssertFalse(q.isScoped)
        XCTAssertEqual(q.terms.first?.needle, "user:")
    }

    // MARK: - Aimed terms

    func testATermCanNameAColumnByItsLeafOrItsFullID() {
        for text in ["user:root", "taskman.user:root", "User:ROOT"] {
            let q = PanelFilterQuery.parse(text, fieldIDs: fields)
            XCTAssertTrue(q.isScoped, text)
            XCTAssertEqual(q.terms.first?.fieldID, "taskman.user", text)
            XCTAssertEqual(q.terms.first?.needle, "root", text)
        }
    }

    func testAnAimedTermIgnoresEveryOtherColumn() {
        // The command line contains "root" and the owner is not root: aiming at the user must miss.
        XCTAssertFalse(matches("user:root",
                               row: ["taskman.user": "maik", "taskman.command": "/Users/root/bin/x"]))
        XCTAssertTrue(matches("command:root",
                              row: ["taskman.user": "maik", "taskman.command": "/Users/root/bin/x"]))
    }

    func testEveryTermMustMatch() {
        let row = ["taskman.user": "root", "taskman.state": "R", "taskman.command": "/usr/sbin/mDNSResponder"]
        XCTAssertTrue(matches("user:root state:R", row: row))
        XCTAssertFalse(matches("user:root state:Z", row: row))
        // A bare word next to an aimed term still narrows, over the row's shown values.
        XCTAssertTrue(matches("user:root mDNS", row: row))
        XCTAssertFalse(matches("user:root nginx", row: row))
    }

    func testWildcardsWorkInBothKinds() {
        XCTAssertTrue(matches("command:*mDNS*", row: ["taskman.command": "/usr/sbin/mDNSResponder"]))
        XCTAssertFalse(matches("command:*nginx*", row: ["taskman.command": "/usr/sbin/mDNSResponder"]))
        XCTAssertTrue(matches("mDNS*", row: [:], name: "mDNSResponder (1)"))
    }

    func testAnUnknownFieldNameIsNotAnAimedTerm() {
        let q = PanelFilterQuery.parse("size:100", fieldIDs: fields)   // no such column on this mount
        XCTAssertFalse(q.isScoped)
        XCTAssertEqual(q.terms.first?.needle, "size:100")
    }

    func testEmptyTextMatchesNothingToDo() {
        XCTAssertTrue(PanelFilterQuery.parse("", fieldIDs: fields).isEmpty)
        XCTAssertTrue(PanelFilterQuery.parse("   ", fieldIDs: fields).isEmpty)
    }

    /// Without a mount there are no field ids, so nothing can be aimed and everything stays text —
    /// which is exactly how a local directory behaved before any of this existed.
    func testWithoutColumnsEverythingIsPlainText() {
        let q = PanelFilterQuery.parse("user:root", fieldIDs: [])
        XCTAssertFalse(q.isScoped)
        XCTAssertEqual(q.terms.first?.needle, "user:root")
    }
}
