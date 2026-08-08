// SPDX-License-Identifier: Apache-2.0
// PathContainmentTests.swift - A name from a listing must not write above the chosen folder (F-131).
//
// The archive extractor already refused this. The panel's own extract walk, which builds local paths
// the same way out of the same `fs.list()` entries, did not — it called `appendingPathComponent` with
// whatever the listing said. Measured before the fix: listing a zip containing "../escaped.txt"
// through ArchiveFS yields an entry named exactly ".." of kind `.directory`, so the walk created
// `<destination>/..` — the parent folder — and wrote the payload into it.
//
// These tests are on the shared rule rather than on either walk, because the point of moving it into
// PCFoundation was that both consult one implementation. The extractor's own end-to-end tests
// (ArchiveExtractorTests) keep covering the composed behaviour.

import XCTest
@testable import PCFoundation

final class PathContainmentTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCContain-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        root = nil
        try super.tearDownWithError()
    }

    // MARK: - The names that must be refused

    func testATraversalComponentIsRefused() {
        for name in ["..", ".", "", "../escaped.txt", "a/b", "/etc/passwd"] {
            XCTAssertNil(PathContainment.childURL(name, under: root, root: root),
                         "\(name.debugDescription) was accepted as a child name")
        }
    }

    func testTheNameThatWasActuallyObservedInAListing() {
        // Not a constructed example: this is the entry ArchiveFS produces for a member "../escaped.txt".
        XCTAssertNil(PathContainment.childURL("..", under: root, root: root))
    }

    func testATraversalIsRefusedDeeperInTheWalkToo() {
        // The walk recurses, so the level being written is below the folder the user chose. ".." there
        // is still inside `root` — and must still be refused, because the next level down is not.
        let deep = root.appendingPathComponent("a/b", isDirectory: true)
        XCTAssertNil(PathContainment.childURL("..", under: deep, root: root))
    }

    // MARK: - The names that must still work

    func testAnOrdinaryNameIsAccepted() throws {
        let url = try XCTUnwrap(PathContainment.childURL("readme.txt", under: root, root: root))
        XCTAssertEqual(url.lastPathComponent, "readme.txt")
    }

    func testNamesThatMerelyLookAlarmingAreAccepted() throws {
        // Refusing too much is its own defect: these are legal file names and must extract.
        for name in ["..hidden", "...", "a..b", ".gitignore", "file with space.txt", "ü.txt"] {
            XCTAssertNotNil(PathContainment.childURL(name, under: root, root: root),
                            "\(name) is a legal name and was refused")
        }
    }

    func testANestedDestinationIsStillInsideTheRoot() throws {
        let deep = root.appendingPathComponent("docs/notes", isDirectory: true)
        XCTAssertNotNil(PathContainment.childURL("detail.txt", under: deep, root: root))
    }

    // MARK: - isInside

    func testTheRootCountsAsInsideItself() {
        XCTAssertTrue(PathContainment.isInside(root, root: root))
    }

    func testASymlinkedDestinationIsNotReportedAsOutside() throws {
        // macOS hands out /var/folders/… for the temp directory, which is a symlink to /private/var.
        // A textual prefix test on the unresolved paths says "outside" and refuses every member —
        // the reason the rule resolves both sides before comparing.
        let real = root.resolvingSymlinksInPath()
        XCTAssertTrue(PathContainment.isInside(real.appendingPathComponent("x.txt"), root: root))
        XCTAssertTrue(PathContainment.isInside(root.appendingPathComponent("x.txt"), root: real))
    }

    func testASiblingWhoseNameStartsWithTheRootIsOutside() {
        // "/tmp/out" and "/tmp/outside" — a prefix test without the separator calls the second one
        // inside the first.
        let sibling = root.deletingLastPathComponent()
            .appendingPathComponent(root.lastPathComponent + "side", isDirectory: true)
        XCTAssertFalse(PathContainment.isInside(sibling.appendingPathComponent("f.txt"), root: root))
    }

    func testTheStringFormAgreesWithTheURLForm() {
        XCTAssertNil(PathContainment.childPath("..", under: root.path, root: root.path))
        XCTAssertEqual(PathContainment.childPath("a.txt", under: root.path, root: root.path),
                       root.appendingPathComponent("a.txt").path)
    }
}
