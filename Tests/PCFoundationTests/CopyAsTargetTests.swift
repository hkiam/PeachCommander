// SPDX-License-Identifier: Apache-2.0
// CopyAsTargetTests.swift - What the "copy as" target field means (F-399).
//
// The whole ambiguity lives here: with the field pre-filled with the source's own path, the last
// component has to be read as a *name*, while the same string in the ordinary F5 field means a
// directory. Getting it backwards either creates a folder named after the file or drops several
// files onto one name, and neither announces itself.

import XCTest
@testable import PCFoundation

final class CopyAsTargetTests: XCTestCase {

    private let base = "/panel/here"

    private func one(_ typed: String) -> CopyAsTarget.Resolved? {
        CopyAsTarget.resolve(typed, baseDir: base, singleItem: true)
    }
    private func many(_ typed: String) -> CopyAsTarget.Resolved? {
        CopyAsTarget.resolve(typed, baseDir: base, singleItem: false)
    }

    // MARK: - One item: the last component is a name

    func test_aBareNameCopiesIntoTheSameDirectoryUnderThatName() {
        XCTAssertEqual(one("copy.txt"), .init(directory: base, mask: "copy.txt"))
    }

    func test_theOfferedPathWithTheNameEditedStaysInPlace() {
        // What the dialog actually hands back after the user edits the pre-filled value.
        XCTAssertEqual(one("/panel/here/notes copy.txt"),
                       .init(directory: base, mask: "notes copy.txt"))
    }

    func test_aPathElsewhereCopiesThereUnderTheNewName() {
        XCTAssertEqual(one("/archive/2026/notes.txt"),
                       .init(directory: "/archive/2026", mask: "notes.txt"))
    }

    func test_aRelativePathIsResolvedAgainstThePanel() {
        XCTAssertEqual(one("sub/copy.txt"), .init(directory: "/panel/here/sub", mask: "copy.txt"))
    }

    // MARK: - The escape hatch

    func test_aTrailingSlashMeansADirectory() {
        // The only way to say "into this folder, keep the name" for a single item — and the same
        // thing it means in every shell.
        XCTAssertEqual(one("/archive/2026/"), .init(directory: "/archive/2026", mask: nil))
        XCTAssertEqual(one("sub/"), .init(directory: "/panel/here/sub", mask: nil))
    }

    // MARK: - Several items

    func test_severalItemsWithAPlainNameGoIntoADirectory() {
        // Reading it as a name would copy every one of them onto the same target in turn, leaving
        // the last one and destroying the rest — the loudest possible way to get this wrong.
        XCTAssertEqual(many("backup"), .init(directory: "/panel/here/backup", mask: nil))
    }

    func test_severalItemsWithAMaskAreRenamedByIt() {
        XCTAssertEqual(many("*.bak"), .init(directory: base, mask: "*.bak"))
        XCTAssertEqual(many("/archive/*.bak"), .init(directory: "/archive", mask: "*.bak"))
    }

    func test_aMaskIsAMaskEvenForOneItem() {
        XCTAssertEqual(one("*.bak"), .init(directory: base, mask: "*.bak"))
    }

    // MARK: - Nothing typed

    func test_anEmptyEntryIsNoTargetAtAll() {
        // Not "the current directory": that is precisely the copy-onto-itself this feature exists to
        // make easy to avoid.
        XCTAssertNil(one(""))
        XCTAssertNil(one("   "))
    }

    func test_aTildeIsExpanded() {
        let r = one("~/Desktop/copy.txt")
        XCTAssertEqual(r?.mask, "copy.txt")
        XCTAssertEqual(r?.directory, (NSHomeDirectory() as NSString).appendingPathComponent("Desktop"))
    }
}
