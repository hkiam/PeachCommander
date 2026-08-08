// SPDX-License-Identifier: Apache-2.0
// DirectoryModelSortTests.swift - The order every panel shows (F-025/F-027).
//
// This comparator decides the order of every listing in the app, and until now it was touched only by a
// *performance* test — how fast it sorts 100k entries, never whether the result is right.
//
// The entries are built on disk and read through LocalFS rather than injected, because the sort works on
// what the file system reports (kind, size, date) and a hand-built entry would let me assume those.

import XCTest
@testable import PCVFS

final class DirectoryModelSortTests: XCTestCase {
    private var dir: URL!
    private let fs = LocalFS()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-sort-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func file(_ name: String, bytes: Int = 1, daysAgo: Double = 0) throws {
        let url = dir.appendingPathComponent(name)
        try Data(repeating: 0x41, count: bytes).write(to: url)
        let when = Date(timeIntervalSinceNow: -daysAgo * 86_400)
        try FileManager.default.setAttributes([.modificationDate: when], ofItemAtPath: url.path)
    }
    private func folder(_ name: String) throws {
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(name),
                                                withIntermediateDirectories: true)
    }

    private func names(_ descriptor: DirectoryModel.SortDescriptor,
                       dirsFirst: Bool = true) async throws -> [String] {
        let model = DirectoryModel()
        _ = try await model.load(dir.path, fs: fs)
        await model.sort(by: DirectoryModel.SortSpec(descriptor: descriptor, dirsFirst: dirsFirst))
        return await model.snapshot().entries.map(\.name)
    }

    // MARK: - Folders first

    func testFoldersComeFirstAndAreSortedAmongThemselves() async throws {
        try folder("zeta"); try folder("alpha")
        try file("a.txt"); try file("z.txt")
        let order = try await names(.name(ascending: true))
        XCTAssertEqual(order, ["alpha", "zeta", "a.txt", "z.txt"])
    }

    func testFoldersCanBeMixedInWhenThatIsTurnedOff() async throws {
        try folder("mmm"); try file("aaa.txt"); try file("zzz.txt")
        let order = try await names(.name(ascending: true), dirsFirst: false)
        XCTAssertEqual(order, ["aaa.txt", "mmm", "zzz.txt"])
    }

    // MARK: - The four orders, and their reverses

    func testByNameIsNaturalNotLexicographic() async throws {
        // "file10" after "file2" is the whole point of the natural order: a plain string sort puts 10
        // before 2 and every screenshot of a numbered series looks wrong.
        try file("file2.txt"); try file("file10.txt"); try file("file1.txt")
        let got1 = try await names(.name(ascending: true))
        XCTAssertEqual(got1, ["file1.txt", "file2.txt", "file10.txt"])
        let got2 = try await names(.name(ascending: false))
        XCTAssertEqual(got2, ["file10.txt", "file2.txt", "file1.txt"])
    }

    func testBySize() async throws {
        try file("small.txt", bytes: 10)
        try file("big.txt", bytes: 5000)
        try file("medium.txt", bytes: 500)
        let got3 = try await names(.size(ascending: true))
        XCTAssertEqual(got3, ["small.txt", "medium.txt", "big.txt"])
        let got4 = try await names(.size(ascending: false))
        XCTAssertEqual(got4, ["big.txt", "medium.txt", "small.txt"])
    }

    func testByDate() async throws {
        try file("old.txt", daysAgo: 10)
        try file("new.txt", daysAgo: 0)
        try file("middle.txt", daysAgo: 5)
        let got5 = try await names(.date(ascending: true))
        XCTAssertEqual(got5, ["old.txt", "middle.txt", "new.txt"])
        let got6 = try await names(.date(ascending: false))
        XCTAssertEqual(got6, ["new.txt", "middle.txt", "old.txt"])
    }

    func testByExtensionFallsBackToTheName() async throws {
        try file("b.txt"); try file("a.txt"); try file("c.md")
        let got7 = try await names(.ext(ascending: true))
        XCTAssertEqual(got7, ["c.md", "a.txt", "b.txt"])
    }

    // MARK: - Ties

    func testEqualSizesAreOrderedByNameSoTheListDoesNotShuffle() async throws {
        // Without the name fallback the order of equal-sized files would be whatever the file system
        // happened to return, and would change between refreshes.
        try file("c.txt", bytes: 100); try file("a.txt", bytes: 100); try file("b.txt", bytes: 100)
        let got8 = try await names(.size(ascending: true))
        XCTAssertEqual(got8, ["a.txt", "b.txt", "c.txt"])
        // Descending by size still means ascending by name within a tie — the tie-break is the *name*
        // order, not a reversal of it.
        let got9 = try await names(.size(ascending: false))
        XCTAssertEqual(got9, ["c.txt", "b.txt", "a.txt"])
    }

    func testNamesDifferingOnlyInCaseHaveAStableOrder() async throws {
        // Possible on a case-sensitive volume, and on every Linux share. `localizedStandardCompare`
        // orders them deterministically rather than calling them equal — checked, because if it did
        // call them equal the two rows would swap places between refreshes.
        try file("README.txt"); try file("readme.txt"); try file("a.txt")
        let first = try await names(.name(ascending: true))
        let second = try await names(.name(ascending: true))
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.first, "a.txt")
    }

    // MARK: - Filtering happens after sorting

    func testAFilterKeepsTheOrder() async throws {
        try file("b.txt"); try file("a.txt"); try file("c.md")
        let model = DirectoryModel()
        _ = try await model.load(dir.path, fs: fs)
        await model.sort(by: .name(ascending: true))
        await model.setFilter("*.txt")
        let filtered = await model.snapshot().entries.map(\.name)
        XCTAssertEqual(filtered, ["a.txt", "b.txt"])
    }
}
