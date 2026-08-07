// SPDX-License-Identifier: Apache-2.0
// MkDirEngineTests.swift - What F7 does with what a user types into it (F-082).
//
// Two existing tests covered "a/b/c" and "one|two|three" — the two shapes the feature was written for.
// What a dialog actually receives is everything else: trailing separators, stray spaces, empty groups
// between bars, a leading "/", and "..". The last one matters most, because a folder created somewhere
// other than where the panel is showing is a folder the user cannot find.

import XCTest
@testable import PCOperations

final class MkDirEngineTests: XCTestCase {
    private var parent: URL!

    override func setUpWithError() throws {
        parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-mkdir-\(UUID().uuidString)")
            .appendingPathComponent("parent")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: parent.deletingLastPathComponent())
    }

    private func exists(_ relative: String) -> Bool {
        var isDir: ObjCBool = false
        let ok = FileManager.default.fileExists(
            atPath: parent.appendingPathComponent(relative).path, isDirectory: &isDir)
        return ok && isDir.boolValue
    }

    // MARK: - The shapes a dialog really receives

    func testATrailingSeparatorDoesNotCreateAnUnnamedChild() throws {
        _ = try MkDirEngine.create(spec: "reports/", in: parent.path)
        XCTAssertTrue(exists("reports"))
        let children = try FileManager.default.contentsOfDirectory(atPath: parent.appendingPathComponent("reports").path)
        XCTAssertTrue(children.isEmpty, "a trailing slash must not leave an empty folder inside")
    }

    func testSpacesAroundNamesAreTrimmedButNotInsideThem() throws {
        let made = try MkDirEngine.create(spec: " first | second name ", in: parent.path)
        XCTAssertEqual(made.map { ($0 as NSString).lastPathComponent }, ["first", "second name"])
        XCTAssertTrue(exists("first"))
        XCTAssertTrue(exists("second name"))
    }

    func testEmptyGroupsBetweenBarsAreIgnored() throws {
        let made = try MkDirEngine.create(spec: "a||b|  |c", in: parent.path)
        XCTAssertEqual(made.map { ($0 as NSString).lastPathComponent }, ["a", "b", "c"])
    }

    func testAnEmptySpecIsRefusedRatherThanCreatingTheParentAgain() {
        XCTAssertThrowsError(try MkDirEngine.create(spec: "", in: parent.path))
        XCTAssertThrowsError(try MkDirEngine.create(spec: "   ", in: parent.path))
    }

    func testANameWithNonASCIICharactersWorks() throws {
        _ = try MkDirEngine.create(spec: "Grüße|日本語", in: parent.path)
        XCTAssertTrue(exists("Grüße"))
        XCTAssertTrue(exists("日本語"))
    }

    func testCreatingSomethingThatIsAlreadyThereIsNotAnError() throws {
        _ = try MkDirEngine.create(spec: "twice", in: parent.path)
        XCTAssertNoThrow(try MkDirEngine.create(spec: "twice", in: parent.path))
    }

    // MARK: - Where the folder ends up

    func testALeadingSlashStaysInsideTheParent() throws {
        // Typed by anyone used to a shell. It must mean "here", not "/": a folder created at the root of
        // the disk is not what the panel is showing and is not what was asked for.
        let made = try MkDirEngine.create(spec: "/absolute", in: parent.path)
        XCTAssertTrue(exists("absolute"))
        XCTAssertTrue(made.allSatisfy { $0.hasPrefix(parent.path) }, "created outside the parent: \(made)")
    }

    func testDotDotIsRefusedRatherThanCreatingAFolderElsewhere() throws {
        // "../elsewhere" resolves outside the folder the panel is showing, so the folder appears
        // somewhere the user is not looking and the panel refreshes to show nothing new. Whatever the
        // right answer is, it must not be "create it silently in another directory".
        let outside = parent.deletingLastPathComponent().appendingPathComponent("escaped")
        let result = Result { try MkDirEngine.create(spec: "../escaped", in: parent.path) }
        switch result {
        case .failure:
            XCTAssertFalse(FileManager.default.fileExists(atPath: outside.path))
        case .success(let made):
            XCTFail("created \(made) — outside the parent, where the user cannot see it")
        }
    }

    func testADotComponentDoesNotSilentlyMeanTheParentItself() throws {
        // "." would "succeed" by finding the parent already there and report it as created, so the panel
        // says a folder was made when none was.
        let result = Result { try MkDirEngine.create(spec: ".", in: parent.path) }
        if case .success(let made) = result {
            XCTAssertTrue(made.isEmpty || !made.contains { ($0 as NSString).standardizingPath == parent.path },
                          "reported the parent itself as a newly created folder: \(made)")
        }
    }

    // MARK: - Not a separator on this platform

    func testABackslashIsPartOfTheNameAndNotAPathSeparator() throws {
        // On Windows "\" separates path components, and the parity note for this row mentions it. On
        // macOS it is an ordinary character in a file name, so treating it as a separator would make it
        // impossible to create a folder whose name contains one.
        _ = try MkDirEngine.create(spec: "back\\slash", in: parent.path)
        XCTAssertTrue(exists("back\\slash"))
        XCTAssertFalse(exists("back"))
    }
}
