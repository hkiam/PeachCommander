// SPDX-License-Identifier: Apache-2.0
// NameInPathTests.swift - which part of a path the rename prompts highlight (F-399).
//
// The rule had two copies before this — the in-cell rename's and, once Shift+F5 stopped selecting
// the whole path, the dialog's — so these cases are as much about the two agreeing as about the
// arithmetic. The "position" assertions matter as much as the lengths: the range is applied to the
// *whole* value, and a length measured from the last component but located from the start of the
// string highlights the wrong text without ever being out of bounds.

import XCTest
@testable import PCFoundation

final class NameInPathTests: XCTestCase {

    private func selected(_ value: String) -> String {
        (value as NSString).substring(with: NameInPath.range(in: value))
    }

    func testNameOfAPathIsTheLastComponentWithoutItsExtension() {
        XCTAssertEqual(selected("/Users/me/Documents/notes.txt"), "notes")
        XCTAssertEqual(NameInPath.range(in: "/a/notes.txt"), NSRange(location: 3, length: 5))
    }

    func testBareNameNeedsNoSeparator() {
        XCTAssertEqual(selected("notes.txt"), "notes")
        XCTAssertEqual(NameInPath.range(in: "notes.txt"), NSRange(location: 0, length: 5))
    }

    func testOnlyTheLastDotCounts() {
        XCTAssertEqual(selected("/a/archive.tar.gz"), "archive.tar")
    }

    func testALeadingDotIsPartOfTheName() {
        XCTAssertEqual(selected("/a/.profile"), ".profile")
    }

    func testNoExtensionSelectsTheWholeName() {
        XCTAssertEqual(selected("/a/README"), "README")
    }

    /// What a copy of several items offers. Selecting "*" and leaving ".*" behind would make the
    /// one thing typed into this prompt — a different mask — a two-step edit.
    func testAMaskIsSelectedWhole() {
        XCTAssertEqual(selected("/a/*.*"), "*.*")
        XCTAssertEqual(selected("/a/*.bak"), "*.bak")
        XCTAssertEqual(selected("/a/file?.txt"), "file?.txt")
    }

    /// A directory target has no name to replace, and an empty range is a caret rather than a
    /// selection — which is the one case where the reader sees an insertion point at all.
    func testAPathEndingInASeparatorSelectsNothingAtTheEnd() {
        XCTAssertEqual(NameInPath.range(in: "/a/b/"), NSRange(location: 5, length: 0))
        XCTAssertEqual(selected("/a/b/"), "")
    }

    func testEmptyValue() {
        XCTAssertEqual(NameInPath.range(in: ""), NSRange(location: 0, length: 0))
    }

    /// The panel's in-cell rename asks the same question about a bare name, and answers it about a
    /// folder differently: `my.stuff` is a folder with a dot in its name, not a name with an
    /// extension, so all of it is offered.
    func testDirectoriesKeepTheirDots() {
        XCTAssertEqual(NameInPath.basenameLength("my.stuff", isDirectory: true), 8)
        XCTAssertEqual(NameInPath.basenameLength("my.stuff", isDirectory: false), 2)
    }

    /// A folder is offered whole through `range` too, not only through `basenameLength`: the dialogs
    /// that rename a folder pass what the listing says it is, and `Backup 2026.01` is the name a
    /// backup folder actually has — splitting it at the dot would have typing produce `New.01`.
    func testAFolderNameIsOfferedWhole() {
        let value = "/Users/me/Backup 2026.01"
        XCTAssertEqual((value as NSString).substring(with: NameInPath.range(in: value, isDirectory: true)),
                       "Backup 2026.01")
        XCTAssertEqual((value as NSString).substring(with: NameInPath.range(in: value)),
                       "Backup 2026")
    }

    /// And the mask rule stops at the prompt. A *file* can legitimately be called `report*.txt` on
    /// this file system, and renaming it in place must keep its extension like any other name — so
    /// the rule that takes `*.*` whole must not reach the panel's editor.
    func testTheMaskRuleIsThePromptsAloneAndNotTheCellEditors() {
        XCTAssertEqual(selected("/a/report*.txt"), "report*.txt")
        XCTAssertEqual(NameInPath.basenameLength("report*.txt", isDirectory: false), 7)
    }

    /// Composed characters count as what NSString counts, because that is what the field editor's
    /// range is measured in — a length in Characters would cut an emoji name in half.
    func testLengthIsInUTF16Units() {
        let value = "/a/🎧sound.mp3"
        let range = NameInPath.range(in: value)
        XCTAssertEqual((value as NSString).substring(with: range), "🎧sound")
    }
}
