// SPDX-License-Identifier: Apache-2.0
// SyncPluginFilterTests.swift - The sync filter's plugin criterion.
//
// A stub provider rather than a real plugin: what is worth pinning is which rows get asked, which
// side of a row is asked about, and what happens to a row that cannot be asked at all. The provider
// also counts its calls, because "how often is this called" is half the design.

import XCTest
@testable import PCFoundation
@testable import PCOperations
@testable import PCVFS

final class SyncPluginFilterTests: XCTestCase {
    private var root: URL!
    private var left: URL!
    private var right: URL!
    private var registry: ContentFieldRegistry!
    private var provider: CountingProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCSyncPlugin-\(UUID().uuidString)", isDirectory: true)
        left = root.appendingPathComponent("left", isDirectory: true)
        right = root.appendingPathComponent("right", isDirectory: true)
        for dir in [left!, right!] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        provider = CountingProvider()
        registry = ContentFieldRegistry()
        registry.register(provider)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        root = nil; left = nil; right = nil; registry = nil; provider = nil
        try super.tearDownWithError()
    }

    @discardableResult
    private func write(_ text: String, to dir: URL, _ rel: String) throws -> URL {
        let url = dir.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func row(_ action: SyncAction, _ rel: String,
                     leftSize: Int64? = nil, rightSize: Int64? = nil,
                     isDirectory: Bool = false) -> SyncResult {
        SyncResult(action: action,
                   item: SyncItem(relativePath: rel, isDirectory: isDirectory,
                                  leftSize: leftSize, leftModified: leftSize == nil ? nil : Date(),
                                  rightSize: rightSize, rightModified: rightSize == nil ? nil : Date()))
    }

    private func apply(_ rows: [SyncResult], _ predicate: String) async -> (kept: [SyncResult], heldBack: Int) {
        await SyncPluginFilter.apply(to: rows, predicate: predicate,
                                     left: .localDir(left.path), right: .localDir(right.path),
                                     registry: registry)
    }

    // MARK: - Which rows are judged, and on which side

    /// The case that would sink the feature if the criterion acted on the pair: a file that exists on
    /// one side only has no file at all on the other, `ContentValue.none` does not satisfy a
    /// predicate, and "either side fails and the pair is out" would therefore exclude every one-sided
    /// file the moment a plugin criterion was set.
    func test_aOneSidedFileIsJudgedOnTheSideThatHasIt() async throws {
        try write(String(repeating: "x", count: 1000), to: left, "big.img")
        try write(String(repeating: "x", count: 100), to: left, "small.img")
        let rows = [row(.copyToRight, "big.img", leftSize: 1000),
                    row(.copyToRight, "small.img", leftSize: 100)]
        let out = await apply(rows, "stub.width > 500")
        XCTAssertEqual(out.kept.map(\.item.relativePath), ["big.img"],
                       "a one-sided file was excluded although the side that exists satisfies it")
        XCTAssertEqual(out.heldBack, 1)
    }

    /// The side asked is the side the action reads from, not whichever one comes first. A copy to the
    /// left reads the *right* file, and here the two sides disagree.
    func test_theSideAskedIsTheSideTheActionReadsFrom() async throws {
        // The same name on both sides with different contents: the only fixture that can tell
        // "asked the right side" from "asked either side".
        try write(String(repeating: "x", count: 100), to: left, "big.img")
        try write(String(repeating: "x", count: 1000), to: right, "big.img")
        // Copy right → left: the right file is the wide one, so this is kept.
        let toLeft = await apply([row(.copyToLeft, "big.img", leftSize: 100, rightSize: 1000)],
                                 "stub.width > 500")
        XCTAssertEqual(toLeft.kept.count, 1, "the row was judged on the side it writes to")
        // Copy left → right: the left file is the narrow one, so this is dropped.
        let toRight = await apply([row(.copyToRight, "big.img", leftSize: 100, rightSize: 1000)],
                                  "stub.width > 500")
        XCTAssertEqual(toRight.kept.count, 0, "the row was judged on the side it reads from")
        XCTAssertEqual(toRight.heldBack, 1)
    }

    /// One call per judged row. Asking about both sides of every entry would be twice this, and a
    /// provider that has to decompile or decode makes that the difference between a wait and a hang.
    func test_eachJudgedRowCostsExactlyOnePluginCall() async throws {
        try write(String(repeating: "x", count: 1000), to: left, "big.img")
        try write(String(repeating: "x", count: 100), to: left, "small.img")
        _ = await apply([row(.copyToRight, "big.img", leftSize: 1000),
                         row(.copyToRight, "small.img", leftSize: 100)], "stub.width > 500")
        XCTAssertEqual(provider.calls, 2)
    }

    /// Rows that are not going to do anything are not worth a plugin call.
    func test_rowsWithNothingToDoAreNotAsked() async throws {
        try write(String(repeating: "x", count: 1000), to: left, "big.img")
        let rows = [row(.equal, "big.img", leftSize: 1000, rightSize: 1000),
                    row(SyncAction.none, "big.img", leftSize: 1000, rightSize: 1000)]
        let out = await apply(rows, "stub.width > 500")
        XCTAssertEqual(out.kept.count, 2)
        XCTAssertEqual(provider.calls, 0)
    }

    /// A folder has no content to read, and dropping one would take everything under it.
    func test_aFolderIsNeverJudged() async throws {
        let out = await apply([row(.copyToRight, "Pictures", leftSize: 0, isDirectory: true)],
                              "stub.width > 500")
        XCTAssertEqual(out.kept.count, 1)
        XCTAssertEqual(out.heldBack, 0)
        XCTAssertEqual(provider.calls, 0)
    }

    // MARK: - When it cannot be answered

    /// `.none` does not satisfy — the search window's rule — so a file the provider knows nothing
    /// about is held back. That is a real exclusion and it is why the count is reported: the user
    /// asked for "only files where X", and a file with no X is not one of them.
    func test_aFileTheProviderCannotAnswerAboutIsHeldBack() async throws {
        try write("x", to: left, "notes.txt")            // the stub answers .none for anything else
        let out = await apply([row(.copyToRight, "notes.txt", leftSize: 4)], "stub.width > 500")
        XCTAssertEqual(out.kept.count, 0)
        XCTAssertEqual(out.heldBack, 1)
    }

    func test_anUnknownFieldHoldsEverythingBackRatherThanNothing() async throws {
        try write(String(repeating: "x", count: 1000), to: left, "big.img")
        let out = await apply([row(.copyToRight, "big.img", leftSize: 1000)], "nosuch.field > 1")
        XCTAssertEqual(out.heldBack, 1, "an unresolvable field quietly satisfied the criterion")
    }

    /// A criterion that does not parse holds nothing back. The sheet refuses to close on one, so this
    /// is a preset written by hand — and excluding the whole comparison because a line of text was
    /// malformed is the one outcome nobody could work out from the result.
    func test_aPredicateThatDoesNotParseHoldsNothingBack() async throws {
        try write(String(repeating: "x", count: 1000), to: left, "big.img")
        let rows = [row(.copyToRight, "big.img", leftSize: 1000)]
        for text in ["", "   ", "not a predicate", "stub.width >", "> 500"] {
            let out = await apply(rows, text)
            XCTAssertEqual(out.kept.count, 1, "\"\(text)\" excluded a row")
            XCTAssertEqual(out.heldBack, 0)
        }
        XCTAssertEqual(provider.calls, 0)
    }

    /// Both sides or neither. With one local side and one archive, the rows copying out of the local
    /// side could be judged and the rows copying into it could not — a filter applied to half a
    /// comparison is harder to explain than one not applied at all, so it is not applied.
    func test_aComparisonAgainstAnArchiveIsNotJudgedAtAll() async throws {
        try write(String(repeating: "x", count: 1000), to: left, "big.img")
        let rows = [row(.copyToRight, "big.img", leftSize: 1000)]
        let out = await SyncPluginFilter.apply(to: rows, predicate: "stub.width > 500",
                                               left: .localDir(left.path),
                                               right: .zip(root.appendingPathComponent("a.zip").path),
                                               registry: registry)
        XCTAssertEqual(out.kept.count, 1)
        XCTAssertEqual(out.heldBack, 0)
        XCTAssertEqual(provider.calls, 0)
        XCTAssertFalse(SyncPluginFilter.canEvaluate(left: .localDir(left.path),
                                                    right: .zip("a.zip")))
        XCTAssertTrue(SyncPluginFilter.canEvaluate(left: .localDir(left.path),
                                                   right: .localDir(right.path)))
    }

    /// A row whose read side is not actually there is not one this criterion can judge — and asking
    /// about a file that does not exist would hold it back for the wrong reason.
    func test_aRowWhoseReadSideIsAbsentIsLeftAlone() async throws {
        let out = await apply([row(.copyToRight, "ghost.img", rightSize: 4)], "stub.width > 500")
        XCTAssertEqual(out.kept.count, 1)
        XCTAssertEqual(provider.calls, 0)
    }
}

/// Reports a file's byte count as its "width", `.none` for a type it does not handle, and counts the
/// questions.
///
/// Deliberately answered from the file's *contents* and not from its name. The first version keyed on
/// `lastPathComponent`, and it made the test for which side gets asked unable to fail: both sides use
/// the same name, so asking the wrong one gave the same answer. Measured — with the "judge the left
/// side regardless" defect put back, only one of the ten tests noticed. A stub that does not have to
/// open the right file cannot tell you that you opened the wrong one.
///
/// `.none` for anything that is not an `.img` is what a real provider does too: `ImageInfoContentProvider`
/// has nothing to say about a text file.
private final class CountingProvider: ContentFieldProvider, @unchecked Sendable {
    let providerName = "stub"
    let fields = [ContentField(id: "width", title: "Width", unit: "px")]
    private let lock = NSLock()
    private var _calls = 0
    var calls: Int { lock.lock(); defer { lock.unlock() }; return _calls }

    func value(fieldID: String, forFileAt url: URL) async -> ContentValue {
        lock.lock(); _calls += 1; lock.unlock()
        guard fieldID == "width", url.pathExtension == "img" else { return .none }
        guard let data = try? Data(contentsOf: url) else { return .none }
        return .integer(Int64(data.count))
    }
}
