// SPDX-License-Identifier: Apache-2.0
// DirectoryModelFailureTests.swift - What the model holds after a listing that failed (F-445).
//
// The model owns two things that have to agree: the path it is showing and the entries in it. They were
// assigned around the enumeration rather than after it, so a listing that threw left the new path with
// the previous directory's entries — and `getPath()` has twenty-odd callers that then described a folder
// whose contents were not on screen. In the app that showed up as a tab and a breadcrumb naming
// different folders, and as a path written to the session that the next launch could not list.
//
// Read through LocalFS on a real unreadable directory rather than a stub, because the failure being
// guarded against is the one the file system actually produces.

import XCTest
@testable import PCVFS

final class DirectoryModelFailureTests: XCTestCase {
    private var root: URL!
    private let fs = LocalFS()

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("pc-fail-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("reachable"),
                                                withIntermediateDirectories: true)
        try Data("x".utf8).write(to: root.appendingPathComponent("reachable/a.txt"))
        try Data("x".utf8).write(to: root.appendingPathComponent("reachable/b.txt"))
        let locked = root.appendingPathComponent("locked")
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
    }

    override func tearDownWithError() throws {
        // Readable again first, or the directory cannot be removed.
        try? FileManager.default.setAttributes([.posixPermissions: 0o700],
                                               ofItemAtPath: root.appendingPathComponent("locked").path)
        try? FileManager.default.removeItem(at: root)
    }

    func testAFailedListingLeavesThePathAndTheEntriesAsTheyWere() async throws {
        let model = DirectoryModel()
        let good = root.appendingPathComponent("reachable").path
        _ = try await model.load(good, fs: fs)
        let pathBefore = await model.getPath()
        let namesBefore = await model.snapshot().entries.map(\.name).sorted()
        XCTAssertEqual(pathBefore, good)
        XCTAssertEqual(namesBefore, ["a.txt", "b.txt"])

        do {
            _ = try await model.load(root.appendingPathComponent("locked").path, fs: fs)
            XCTFail("listing an unreadable directory should throw")
        } catch {
            // Expected. What matters is what the model kept.
        }

        let after = await model.snapshot()
        let pathAfter = await model.getPath()
        // Both, not either: the path with the other directory's entries is the defect, and so is the
        // reverse.
        XCTAssertEqual(pathAfter, good, "the model took the path of a directory it never listed")
        XCTAssertEqual(after.entries.map(\.name).sorted(), ["a.txt", "b.txt"],
                       "the entries changed although the listing failed")
        XCTAssertEqual(after.path, good,
                       "the snapshot names a folder whose entries it is not carrying")
    }

    func testAFailedFirstListingLeavesTheModelEmptyRatherThanNamingAFolder() async throws {
        // A fresh model that fails on its first load must not claim to be showing anything: an empty
        // path is honest, a path with no entries is the same contradiction one step smaller.
        let model = DirectoryModel()
        do {
            _ = try await model.load(root.appendingPathComponent("locked").path, fs: fs)
            XCTFail("listing an unreadable directory should throw")
        } catch {}
        let path = await model.getPath()
        let snapshot = await model.snapshot()
        XCTAssertEqual(path, "")
        XCTAssertTrue(snapshot.entries.isEmpty)
    }
}
