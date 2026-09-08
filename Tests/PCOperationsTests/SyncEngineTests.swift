// SPDX-License-Identifier: Apache-2.0
// SyncEngineTests.swift - What the sync will do, and what it then does (F-193).
//
// The scanner and the executor had no tests at all. They lived in SyncWindowController, and no test
// bundle imports PCApp — so the code that decides which files get copied, and the code that copies
// them, was checked only by using the window. F-193's evidence was a symbol name.
//
// These pin the behaviour that exists today, before a remote (FTP/SFTP) side is added to it: a
// refactor of code nobody is watching is a rewrite with extra steps.

import XCTest
@testable import PCArchive
@testable import PCFoundation
@testable import PCOperations
@testable import PCVFS

final class SyncEngineTests: XCTestCase {
    private var root: URL!
    private var left: URL!
    private var right: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCSync-\(UUID().uuidString)", isDirectory: true)
        left = root.appendingPathComponent("left", isDirectory: true)
        right = root.appendingPathComponent("right", isDirectory: true)
        for dir in [left!, right!] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        root = nil; left = nil; right = nil
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

    private func scanBothDirs(mask: String = "*.*", withSubdirs: Bool = true,
                              byContent: Bool = false, ignoreHidden: Bool = false) async -> [SyncItem] {
        await SyncScanner.scan(left: .localDir(left.path), right: .localDir(right.path), mask: mask,
                         withSubdirs: withSubdirs, byContent: byContent, ignoreHidden: ignoreHidden)
    }

    private func item(_ items: [SyncItem], _ rel: String) -> SyncItem? {
        items.first { $0.relativePath == rel }
    }

    // MARK: - What the scan reports

    func testAFileOnOneSideOnlyIsReportedWithNothingOnTheOther() async throws {
        try write("x", to: left, "only-left.txt")
        try write("y", to: right, "only-right.txt")
        let items = await scanBothDirs()
        XCTAssertNotNil(item(items, "only-left.txt")?.leftSize)
        XCTAssertNil(item(items, "only-left.txt")?.rightSize)
        XCTAssertNil(item(items, "only-right.txt")?.leftSize)
        XCTAssertNotNil(item(items, "only-right.txt")?.rightSize)
    }

    func testTheMaskDecidesWhichFilesAreCompared() async throws {
        try write("a", to: left, "keep.txt")
        try write("b", to: left, "skip.log")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: .localDir(right.path),
                                     mask: "*.txt", withSubdirs: true, byContent: false)
        XCTAssertNotNil(item(items, "keep.txt"))
        XCTAssertNil(item(items, "skip.log"), "a file the mask excludes must not be offered for copying")
    }

    func testWithoutSubdirectoriesTheContentsOfAFolderAreNotWalked() async throws {
        try write("deep", to: left, "sub/inner.txt")
        let flat = await scanBothDirs(withSubdirs: false)
        XCTAssertNil(item(flat, "sub/inner.txt"))
        let deep = await scanBothDirs(withSubdirs: true)
        XCTAssertNotNil(item(deep, "sub/inner.txt"))
    }

    func testHiddenItemsAreSkippedOnRequestAtEveryLevel() async throws {
        try write("a", to: left, ".hidden.txt")
        try write("b", to: left, ".hiddendir/inside.txt")
        try write("c", to: left, "visible.txt")
        let items = await scanBothDirs(ignoreHidden: true)
        XCTAssertNil(item(items, ".hidden.txt"))
        XCTAssertNil(item(items, ".hiddendir/inside.txt"), "a dot on any component hides the item")
        XCTAssertNotNil(item(items, "visible.txt"))
    }

    func testComparingByContentTellsEqualFromDifferentAtTheSameSize() async throws {
        try write("aaaa", to: left, "same.txt");  try write("aaaa", to: right, "same.txt")
        try write("aaaa", to: left, "differ.txt"); try write("bbbb", to: right, "differ.txt")
        let items = await scanBothDirs(byContent: true)
        XCTAssertEqual(item(items, "same.txt")?.contentEqual, true)
        // Same size, different bytes: the case a size comparison alone gets wrong.
        XCTAssertEqual(item(items, "differ.txt")?.contentEqual, false)
    }

    func testAZipCanBeOneSide() async throws {
        let zip = root.appendingPathComponent("side.zip")
        try ZipWriter.create(at: zip, files: [(path: "in-zip.txt", data: Data("z".utf8))])
        try write("l", to: left, "in-dir.txt")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: .zip(zip.path),
                                     mask: "*.*", withSubdirs: true, byContent: false)
        XCTAssertNotNil(item(items, "in-dir.txt")?.leftSize)
        XCTAssertNotNil(item(items, "in-zip.txt")?.rightSize)
    }

    // MARK: - What the executor actually does

    func testCopyingLeftToRightPutsTheBytesThere() async throws {
        try write("hello", to: left, "a.txt")
        let items = await scanBothDirs()
        let results = item(items, "a.txt").map { [SyncResult(action: .copyToRight, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                          right: .localDir(right.path), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try String(contentsOf: right.appendingPathComponent("a.txt"), encoding: .utf8),
                       "hello")
    }

    func testCopyingRightToLeftGoesTheOtherWay() async throws {
        try write("world", to: right, "b.txt")
        let items = await scanBothDirs()
        let results = item(items, "b.txt").map { [SyncResult(action: .copyToLeft, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                   right: .localDir(right.path), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try String(contentsOf: left.appendingPathComponent("b.txt"), encoding: .utf8),
                       "world")
    }

    func testDeletingOnTheRightRemovesTheFile() async throws {
        try write("gone", to: right, "c.txt")
        let items = await scanBothDirs()
        let results = item(items, "c.txt").map { [SyncResult(action: .deleteRight, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                   right: .localDir(right.path), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: right.appendingPathComponent("c.txt").path))
    }

    func testAnActionOnAnUntouchedFileLeavesTheOtherFilesAlone() async throws {
        try write("keep me", to: right, "untouched.txt")
        try write("copy me", to: left, "moved.txt")
        let items = await scanBothDirs()
        let results = item(items, "moved.txt").map { [SyncResult(action: .copyToRight, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                   right: .localDir(right.path), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try String(contentsOf: right.appendingPathComponent("untouched.txt"), encoding: .utf8),
                       "keep me", "a file no action named was changed")
    }

    // MARK: - A live filesystem as one side (F-193)
    //
    // Driven through LocalFS, which is a real VirtualFileSystem. The engine only ever talks to the
    // protocol — list, stat, openRead, openWrite, mkdir, delete — so this exercises the same code an
    // FTP or SFTP mount goes through, without a server in the test. That an actual server behaves is a
    // separate claim, and it belongs in the VM scenario against the guest's own sshd; this is why the
    // remote side was written against the protocol rather than against an FTP client.

    private func remoteSide(_ dir: URL) -> SyncSide {
        .remote(RemoteSyncSource(fs: LocalFS(), path: dir.path))
    }

    func testARemoteSideIsEnumeratedIncludingSubdirectories() async throws {
        try write("a", to: right, "top.txt")
        try write("b", to: right, "sub/inner.txt")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        XCTAssertNotNil(item(items, "top.txt")?.rightSize)
        XCTAssertNotNil(item(items, "sub/inner.txt")?.rightSize)
    }

    func testCopyingUpToARemoteSideWritesTheFileThere() async throws {
        try write("upload me", to: left, "up.txt")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        let results = item(items, "up.txt").map { [SyncResult(action: .copyToRight, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                right: remoteSide(right), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try String(contentsOf: right.appendingPathComponent("up.txt"), encoding: .utf8),
                       "upload me")
    }

    func testCopyingDownFromARemoteSideWritesTheFileHere() async throws {
        try write("download me", to: right, "down.txt")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        let results = item(items, "down.txt").map { [SyncResult(action: .copyToLeft, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                right: remoteSide(right), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try String(contentsOf: left.appendingPathComponent("down.txt"), encoding: .utf8),
                       "download me")
    }

    func testDeletingOnARemoteSideRemovesIt() async throws {
        try write("gone", to: right, "del.txt")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        let results = item(items, "del.txt").map { [SyncResult(action: .deleteRight, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                right: remoteSide(right), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: right.appendingPathComponent("del.txt").path))
    }

    func testTwoRemoteSidesAreRefusedRatherThanHalfDone() async throws {
        try write("x", to: right, "f.txt")
        let items = await SyncScanner.scan(left: remoteSide(left), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        let results = item(items, "f.txt").map { [SyncResult(action: .copyToLeft, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: remoteSide(left),
                                                right: remoteSide(right), toTrash: false)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].message.contains("server to another"), errors[0].message)
        XCTAssertEqual(errors[0].path, "f.txt", "the failing item's path travels separately now")
    }

    func testUploadingOnlyTheFileStillCreatesItsFolderOnTheServer() async throws {
        // The case where the folder is *not* copied as its own action: the user deselected that row, or
        // only files were chosen. A server does not create the parent on the way, so without that step
        // the write fails — and nothing else in the suite reaches it, because a folder normally arrives
        // as its own action first.
        try write("deep", to: left, "newdir/inner.txt")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        let fileOnly = item(items, "newdir/inner.txt").map { [SyncResult(action: .copyToRight, item: $0)] } ?? []
        XCTAssertEqual(fileOnly.count, 1, "the file itself must be in the comparison")
        let errors = await SyncExecutor.execute(fileOnly, left: .localDir(left.path),
                                                right: remoteSide(right), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try String(contentsOf: right.appendingPathComponent("newdir/inner.txt"),
                                  encoding: .utf8), "deep")
    }

    // MARK: - The name comes off the wire

    func testAServerCannotNameAnEntryThatEscapesTheLocalFolder() async throws {
        // The listing is the server's to write, and the relative key becomes a local path on the other
        // side — the same shape as a crafted archive member. A component that is not a name is dropped
        // by the scanner, so it is never offered as something to copy.
        let hostile = HostileListingFS()
        let items = await SyncScanner.scan(left: .localDir(left.path),
                                           right: .remote(RemoteSyncSource(fs: hostile, path: "/")),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        XCTAssertNil(item(items, ".."), "a listing entry named \"..\" was accepted as a file to sync")
        XCTAssertNotNil(item(items, "ordinary.txt"), "the honest entry beside it must still arrive")
    }

    // MARK: - What the scan says while it is running (F-192 follow-up)

    /// Collects the phases off whatever context the scan reports them from.
    private final class PhaseLog: @unchecked Sendable {
        private let lock = NSLock()
        private var phases: [SyncScanPhase] = []
        func record(_ phase: SyncScanPhase) { lock.lock(); phases.append(phase); lock.unlock() }
        var all: [SyncScanPhase] { lock.lock(); defer { lock.unlock() }; return phases }
    }

    /// More entries than the scanner's report stride, so the walk has to report *during* it and not
    /// only when it is done — a progress callback that fires once at the end is indistinguishable
    /// from no progress at all for the case it exists for.
    private static let stridingFileCount = 300

    private func writeManyFiles() throws {
        for i in 0..<Self.stridingFileCount {
            try write("x", to: left, "f\(i).txt")
            try write("x", to: right, "f\(i).txt")
        }
    }

    func testTheScanReportsBothWalksAndThenTheComparisonItIsDoing() async throws {
        try writeManyFiles()
        let log = PhaseLog()
        _ = await SyncScanner.scan(left: .localDir(left.path), right: .localDir(right.path),
                                   mask: "*.*", withSubdirs: true, byContent: false,
                                   progress: { log.record($0) })
        let phases = log.all

        // Both trees are walked, in order, and each reports before it is finished.
        let leftCounts = phases.compactMap { if case .scanningLeft(let c) = $0 { return c } else { return nil } }
        let rightCounts = phases.compactMap { if case .scanningRight(let c) = $0 { return c } else { return nil } }
        XCTAssertGreaterThan(leftCounts.count, 1, "the left walk reported only once: \(phases)")
        XCTAssertGreaterThan(rightCounts.count, 1, "the right walk reported only once: \(phases)")
        XCTAssertEqual(leftCounts.last, Self.stridingFileCount)
        XCTAssertEqual(rightCounts.last, Self.stridingFileCount)
        XCTAssertEqual(leftCounts, leftCounts.sorted(), "counts went backwards: \(leftCounts)")

        // A walk cannot be reported after the comparison has started.
        let firstCompare = phases.firstIndex { if case .comparing = $0 { return true } else { return false } }
        XCTAssertNotNil(firstCompare)
        if let firstCompare {
            let afterwards = phases[firstCompare...].contains {
                switch $0 { case .comparing: return false; default: return true }
            }
            XCTAssertFalse(afterwards, "a walk reported after the comparison began: \(phases)")
        }
    }

    /// The comparison is the phase that has a denominator, and the last thing a caller hears has to
    /// be the full one — a progress line left at 4900/5000 reads as a scan that stalled.
    func testTheComparisonFinishesOnItsOwnTotal() async throws {
        try writeManyFiles()
        let log = PhaseLog()
        _ = await SyncScanner.scan(left: .localDir(left.path), right: .localDir(right.path),
                                   mask: "*.*", withSubdirs: true, byContent: true,
                                   progress: { log.record($0) })
        let comparing = log.all.compactMap { phase -> (Int, Int)? in
            if case .comparing(let done, let total) = phase { return (done, total) } else { return nil }
        }
        XCTAssertGreaterThan(comparing.count, 2, "the comparison reported only its ends: \(comparing)")
        XCTAssertEqual(comparing.first?.0, 0)
        XCTAssertEqual(comparing.last?.0, Self.stridingFileCount)
        XCTAssertEqual(comparing.last?.1, Self.stridingFileCount)
        for (done, total) in comparing {
            XCTAssertLessThanOrEqual(done, total)
            XCTAssertEqual(total, Self.stridingFileCount)
        }
    }

    /// A cancelled scan must not hand back the part of the tree it managed to walk: shown as a
    /// result, a partial tree is a comparison that silently left files out — and every one of them
    /// would be classified as "only on the other side" and offered for copying.
    func testACancelledScanReturnsNothingRatherThanHalfATree() async throws {
        try writeManyFiles()
        let paths = (left.path, right.path)
        let task = Task.detached { () -> [SyncItem] in
            await SyncScanner.scan(left: .localDir(paths.0), right: .localDir(paths.1),
                                   mask: "*.*", withSubdirs: true, byContent: true)
        }
        task.cancel()
        let items = await task.value
        XCTAssertTrue(items.isEmpty, "a cancelled scan returned \(items.count) items")
    }

    // MARK: - A server side is not a local path, and its timestamps have to survive

    private func setModified(_ url: URL, _ date: Date) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    private func modified(_ url: URL) throws -> Date {
        try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
            ?? Date(timeIntervalSince1970: 0)
    }

    /// "By content" against a server has to read the server's bytes.
    ///
    /// `SyncSide.path` for a remote side is the path *on the server*, so a by-content branch that
    /// only asks "is either side a zip?" ends up opening `/srv/…` as a file on this machine. It finds
    /// nothing, calls every same-sized file different, and offers to re-upload the lot — measured
    /// before the fix as `contentEqual=false` and `copyToRight` for two byte-identical files.
    ///
    /// `LocalFS` cannot catch this as a stand-in server: its paths *are* local paths, so the wrong
    /// branch reads the right bytes by accident. That is why this uses a filesystem whose base path
    /// exists nowhere on disk.
    func testByContentReadsTheServersOwnBytesAndNotALocalPathOfTheSameName() async throws {
        try write("hello", to: left, "same.txt")
        let server = MemoryServerFS(base: "/srv", files: ["same.txt": Data("hello".utf8)])
        let items = await SyncScanner.scan(left: .localDir(left.path),
                                           right: .remote(RemoteSyncSource(fs: server, path: "/srv")),
                                           mask: "*.*", withSubdirs: true, byContent: true)
        let same = try XCTUnwrap(item(items, "same.txt"))
        XCTAssertEqual(same.contentEqual, true, "identical bytes on a server side reported as different")
        XCTAssertEqual(SyncModel.classify([same], options: SyncOptions(byContent: true, ignoreDate: true))[0].action,
                       .equal)
    }

    /// And it still tells a real difference apart at the same size — the check above would also pass
    /// for a branch that answered "equal" to everything.
    func testByContentAgainstAServerStillSeesADifferenceOfTheSameLength() async throws {
        try write("hello", to: left, "diff.txt")
        let server = MemoryServerFS(base: "/srv", files: ["diff.txt": Data("HELLO".utf8)])
        let items = await SyncScanner.scan(left: .localDir(left.path),
                                           right: .remote(RemoteSyncSource(fs: server, path: "/srv")),
                                           mask: "*.*", withSubdirs: true, byContent: true)
        XCTAssertEqual(try XCTUnwrap(item(items, "diff.txt")).contentEqual, false)
    }

    /// A sync must not ask to undo itself on the very next run.
    ///
    /// The upload writes bytes; if it leaves the destination stamped with the moment of the write,
    /// the file is newer on the server than the one it came from, and the next comparison answers
    /// `copyToLeft` — then `copyToRight` again, one round per run, for ever.
    func testASyncOntoAServerDoesNotAskToUndoItselfOnTheNextRun() async throws {
        let old = Date(timeIntervalSince1970: 1_600_000_000)
        try setModified(try write("payload", to: left, "p.txt"), old)

        func compare() async -> SyncAction? {
            let items = await SyncScanner.scan(left: .localDir(left.path), right: remoteSide(right),
                                               mask: "*.*", withSubdirs: true, byContent: false)
            return item(items, "p.txt").map { SyncModel.classify([$0], options: SyncOptions())[0].action }
        }

        let first = await compare()
        XCTAssertEqual(first, .copyToRight)
        let items = await SyncScanner.scan(left: .localDir(left.path), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        let plan = item(items, "p.txt").map { [SyncResult(action: .copyToRight, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                right: remoteSide(right), toTrash: false)
        XCTAssertEqual(errors, [])

        let afterwards = await compare()
        XCTAssertEqual(afterwards, .equal, "the run right after the sync wants to move the file again")
        XCTAssertEqual(try modified(right.appendingPathComponent("p.txt")).timeIntervalSince1970,
                       old.timeIntervalSince1970, accuracy: 1,
                       "the uploaded file did not keep the timestamp it was compared by")
    }

    /// The same rule in the other direction: a downloaded file keeps the date it had on the server.
    func testADownloadKeepsTheTimestampTheFileHadOnTheServer() async throws {
        let old = Date(timeIntervalSince1970: 1_600_000_000)
        try setModified(try write("payload", to: right, "d.txt"), old)
        let items = await SyncScanner.scan(left: .localDir(left.path), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        let plan = item(items, "d.txt").map { [SyncResult(action: .copyToLeft, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                right: remoteSide(right), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try modified(left.appendingPathComponent("d.txt")).timeIntervalSince1970,
                       old.timeIntervalSince1970, accuracy: 1)

        let after = await SyncScanner.scan(left: .localDir(left.path), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        XCTAssertEqual(item(after, "d.txt").map { SyncModel.classify([$0], options: SyncOptions())[0].action },
                       .equal)
    }

    // MARK: - An empty folder is content too

    /// A folder with nothing in it has no files to be created by, so before this it was never
    /// synchronized at all — the two trees kept the difference for ever.
    func testAnEmptyFolderOnOneSideIsActuallyCreatedOnTheOther() async throws {
        try FileManager.default.createDirectory(at: left.appendingPathComponent("empty"),
                                                withIntermediateDirectories: true)
        let items = await scanBothDirs()
        let plan = SyncModel.classify(items, options: SyncOptions()).filter { $0.action != .none }
        XCTAssertEqual(plan.map(\.action), [.copyToRight])
        let errors = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                right: .localDir(right.path), toTrash: false)
        XCTAssertEqual(errors, [])
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: right.appendingPathComponent("empty").path,
                                                     isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    // MARK: - Matching names by case (F-192: the option that was never read)

    /// `SyncOptions.caseSensitive` was declared, persisted in presets and ignored — matching was
    /// always exact. On a case-insensitive volume, which is what macOS formats by default, a pair
    /// differing only in case therefore showed up as two rows, each "only on one side".
    func testNamesDifferingOnlyInCaseAreOnePairWhenCaseIsIgnored() async throws {
        try write("x", to: left, "README.md")
        try write("x", to: right, "readme.md")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: .localDir(right.path),
                                           mask: "*.*", withSubdirs: true, byContent: false,
                                           caseSensitive: false)
        XCTAssertEqual(items.count, 1, "still two rows: \(items.map(\.relativePath))")
        let only = try XCTUnwrap(items.first)
        XCTAssertNotNil(only.leftSize)
        XCTAssertNotNil(only.rightSize)
        XCTAssertEqual(only.relativePath, "README.md", "the left side's spelling names the row")
    }

    func testTheSameTwoNamesStayApartWhenCaseMatters() async throws {
        try write("x", to: left, "README.md")
        try write("x", to: right, "readme.md")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: .localDir(right.path),
                                           mask: "*.*", withSubdirs: true, byContent: false,
                                           caseSensitive: true)
        XCTAssertEqual(items.count, 2)
    }

    /// The comparison has to read each side by the name *that side* has, or the folded pair reads a
    /// file that is not there and calls two identical files different.
    func testAFoldedPairIsComparedByContentUsingEachSidesOwnSpelling() async throws {
        try write("same bytes", to: left, "README.md")
        try write("same bytes", to: right, "readme.md")
        let items = await SyncScanner.scan(left: .localDir(left.path), right: .localDir(right.path),
                                           mask: "*.*", withSubdirs: true, byContent: true,
                                           caseSensitive: false)
        XCTAssertEqual(try XCTUnwrap(items.first).contentEqual, true)
    }

    // MARK: - What the executor reports while it runs

    func testExecutingReportsItsProgressAndEndsOnItsTotal() async throws {
        for i in 0..<5 { try write("x", to: left, "f\(i).txt") }
        let items = await scanBothDirs()
        let plan = SyncModel.classify(items, options: SyncOptions()).filter { $0.action != .none }
        let seen = PhaseLog()
        _ = await SyncExecutor.execute(plan, left: .localDir(left.path), right: .localDir(right.path),
                                       toTrash: false, progress: { done, total in
            seen.record(.comparing(done: done, total: total))
        })
        let reports = seen.all.compactMap { phase -> (Int, Int)? in
            if case .comparing(let d, let t) = phase { return (d, t) } else { return nil }
        }
        XCTAssertEqual(reports.first?.0, 0)
        XCTAssertEqual(reports.last?.0, plan.count)
        XCTAssertEqual(reports.last?.1, plan.count)
    }

    /// Stopping leaves a partial sync, not a partial file — and nothing at all when it is called off
    /// before the first item.
    func testACancelledExecutionStopsInsteadOfFinishing() async throws {
        for i in 0..<5 { try write("x", to: left, "f\(i).txt") }
        let items = await scanBothDirs()
        let plan = SyncModel.classify(items, options: SyncOptions()).filter { $0.action != .none }
        let paths = (left.path, right.path)
        let task = Task.detached { () -> [SyncError] in
            await SyncExecutor.execute(plan, left: .localDir(paths.0), right: .localDir(paths.1),
                                       toTrash: false)
        }
        task.cancel()
        let errors = await task.value
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: right.path), [])
    }

    /// A file extracted from an archive keeps the entry's own timestamp, not the moment it was
    /// written — otherwise the next comparison offers to put it straight back into the archive.
    func testExtractingFromAZipKeepsTheEntrysTimestamp() async throws {
        let zip = root.appendingPathComponent("side.zip")
        try ZipWriter.create(at: zip, files: [(path: "in-zip.txt", data: Data("z".utf8))])
        let items = await SyncScanner.scan(left: .localDir(left.path), right: .zip(zip.path),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        let plan = item(items, "in-zip.txt").map { [SyncResult(action: .copyToLeft, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                right: .zip(zip.path), toTrash: false)
        XCTAssertEqual(errors, [])
        let entryDate = try XCTUnwrap(item(items, "in-zip.txt")?.rightModified)
        XCTAssertEqual(try modified(left.appendingPathComponent("in-zip.txt")).timeIntervalSince1970,
                       entryDate.timeIntervalSince1970, accuracy: 0.001,
                       "the extracted file was stamped with the moment of extraction")
    }

    // MARK: - What the confirmation has to warn about

    /// Deleting locally goes to the Trash; deleting on a server does not, and `remove` has claimed
    /// since it was written that "the dialog says so before the actions run" — of no dialog that
    /// existed. This is the question that sentence assumes.
    func testDeletingOnAServerIsReportedAsPermanentAndDeletingLocallyIsNot() throws {
        let item = SyncItem(relativePath: "gone.txt", isDirectory: false,
                            leftSize: nil, leftModified: nil, rightSize: 4, rightModified: nil)
        let deleteOnRight = [SyncResult(action: .deleteRight, item: item)]
        let server = remoteSide(right)

        XCTAssertTrue(SyncExecutor.deletesPermanently(deleteOnRight,
                                                      left: .localDir(left.path), right: server))
        XCTAssertFalse(SyncExecutor.deletesPermanently(deleteOnRight,
                                                       left: .localDir(left.path), right: .localDir(right.path)))
        // The side matters, not just that a server is involved: a delete on the *left* while the
        // server is on the right takes the local file, and that one goes to the Trash.
        XCTAssertFalse(SyncExecutor.deletesPermanently([SyncResult(action: .deleteLeft, item: item)],
                                                       left: .localDir(left.path), right: server))
        // And a run with nothing to delete never warns.
        XCTAssertFalse(SyncExecutor.deletesPermanently([SyncResult(action: .copyToRight, item: item)],
                                                       left: .localDir(left.path), right: server))
    }

    /// And without a callback it behaves exactly as it did before there was one.
    func testAScanWithNoProgressCallbackStillReportsEverything() async throws {
        try write("x", to: left, "a.txt")
        try write("x", to: right, "b.txt")
        let items = await scanBothDirs()
        XCTAssertEqual(items.map(\.relativePath).sorted(), ["a.txt", "b.txt"])
    }

    // MARK: - A mirror deletes what it compared, and nothing else

    /// Mirror mode removes a folder that exists on one side only, and that removal is recursive:
    /// `fm.trashItem` on a directory takes everything under it. Whatever the mask held back is under
    /// that directory and was never a row in the plan — so it went too, after the window had shown
    /// the user that it was not part of the comparison.
    ///
    /// Measured before the guard: mask `*.txt`, mirror mode, a right-only folder holding one `.txt`
    /// and one `.jpg`, and the `.jpg` was gone. The same happens with "ignore hidden" and a dotfile.
    func test_aMirrorDoesNotDeleteAFolderHoldingFilesTheMaskHeldBack() async throws {
        try write("compared", to: right, "Old/listed.txt")
        try write("held back", to: right, "Old/kept.jpg")
        let items = await scanBothDirs(mask: "*.txt")
        let results = SyncModel.classify(items, options: SyncOptions(asymmetric: true))
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                right: .localDir(right.path), toTrash: false)

        XCTAssertTrue(FileManager.default.fileExists(atPath: right.appendingPathComponent("Old/kept.jpg").path),
                      "a file the mask excluded was deleted along with its folder")
        // What *was* compared is still deleted: this is a guard, not a retreat.
        XCTAssertFalse(FileManager.default.fileExists(atPath: right.appendingPathComponent("Old/listed.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: right.appendingPathComponent("Old").path),
                      "the folder went even though something inside it survived")
        XCTAssertEqual(errors.map(\.path), ["Old"], "the kept folder was not reported")
    }

    /// The same for "ignore hidden", which holds entries back by a different rule but leaves them in
    /// exactly the same place.
    func test_aMirrorDoesNotDeleteAFolderHoldingAHiddenFile() async throws {
        try write("compared", to: right, "Old/listed.txt")
        try write("held back", to: right, "Old/.config")
        let items = await scanBothDirs(ignoreHidden: true)
        let results = SyncModel.classify(items, options: SyncOptions(asymmetric: true))
        _ = await SyncExecutor.execute(results, left: .localDir(left.path),
                                       right: .localDir(right.path), toTrash: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: right.appendingPathComponent("Old/.config").path),
                      "a hidden file was deleted along with its folder")
    }

    /// A folder whose whole content *was* compared is still removed — otherwise the guard would turn
    /// every mirror run into a pile of half-deleted trees.
    func test_aMirrorStillDeletesAFolderItComparedEntirely() async throws {
        try write("gone", to: right, "Old/a.txt")
        try write("gone", to: right, "Old/b.txt")
        let items = await scanBothDirs()
        let results = SyncModel.classify(items, options: SyncOptions(asymmetric: true))
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                right: .localDir(right.path), toTrash: false)
        XCTAssertEqual(errors, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: right.appendingPathComponent("Old").path),
                       "a folder this comparison covered completely was left behind")
    }

    /// And a zip, where the mechanism is different and the outcome was the same: `ArchiveEditor.remove`
    /// drops every entry *under* the path it is given, so a directory delete took the held-back
    /// entries with it. The archive's own entry list is what answers the question here, because the
    /// zip's deletions are batched into one rewrite and nothing has been removed yet when the guard
    /// runs.
    func test_aMirrorDoesNotDeleteAZipFolderHoldingEntriesTheMaskHeldBack() async throws {
        let zip = root.appendingPathComponent("side.zip")
        // The folder entry has to be in the archive for this to be reproducible at all: a zip written
        // from two file paths alone carries no `Old/` entry, so the scan never sees a directory and
        // there is no recursive delete to guard against. Real archives written by Finder or by this
        // app's own packer do carry them.
        try ZipWriter.create(at: zip, files: [(path: "Old/", data: Data()),
                                              (path: "Old/listed.txt", data: Data("compared".utf8)),
                                              (path: "Old/kept.jpg", data: Data("held back".utf8))])
        let items = await SyncScanner.scan(left: .localDir(left.path), right: .zip(zip.path),
                                           mask: "*.txt", withSubdirs: true, byContent: false)
        let results = SyncModel.classify(items, options: SyncOptions(asymmetric: true))
        _ = await SyncExecutor.execute(results, left: .localDir(left.path),
                                       right: .zip(zip.path), toTrash: false)

        let remaining = ZipReader(fileURL: zip)?.entries.map(\.path) ?? []
        XCTAssertTrue(remaining.contains("Old/kept.jpg"),
                      "an entry the mask excluded was dropped along with its folder: \(remaining)")
        XCTAssertFalse(remaining.contains("Old/listed.txt"))
    }

}

/// A filesystem whose listing contains what a hostile server would send.
private final class HostileListingFS: VirtualFileSystem, @unchecked Sendable {
    let scheme = "hostile"
    var capabilities: VFSCapabilities { [.read] }

    func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        AsyncThrowingStream { continuation in
            func entry(_ name: String, _ kind: VFSEntry.Kind) -> VFSEntry {
                VFSEntry(name: name, ext: "", kind: kind, size: 1, modified: Date(timeIntervalSince1970: 0),
                         created: nil, posixMode: 0o644, bsdFlags: 0, isHidden: false)
            }
            // Only the root is listed; the "" entry would otherwise recurse forever.
            if dir.path == "/" {
                continuation.yield(VFSEntryBatch(entries: [entry("ordinary.txt", .file),
                                                           entry("..", .file)]))
            }
            continuation.finish()
        }
    }

    func stat(_ path: VFSPath) async throws -> VFSEntry { throw VFSError.notFound(path.path) }
    func openRead(_ path: VFSPath) async throws -> VFSReadStream { throw VFSError.notFound(path.path) }
    func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream {
        throw VFSError.notFound(path.path)
    }
    func mkdir(_ path: VFSPath) async throws {}
    func delete(_ path: VFSPath) async throws {}
    func rename(_ from: VFSPath, to: VFSPath) async throws {}
    func setAttributes(_ path: VFSPath, attributes: VFSAttributes) async throws {}
    func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>? { nil }
    func localFileIfAvailable(_ path: VFSPath) async throws -> URL? { nil }
}

/// A server-like filesystem whose paths are NOT paths on this machine.
///
/// `LocalFS` is the right stand-in for most of the remote tests above — it is a real
/// `VirtualFileSystem` and the engine only ever talks to the protocol. It cannot stand in for the one
/// thing this checks, though: a `LocalFS` side's path *is* a local path, so code that mistakes a
/// server for a local folder reads the right bytes by accident and the mistake stays invisible.
private final class MemoryServerFS: VirtualFileSystem, @unchecked Sendable {
    let scheme = "memsrv"
    var capabilities: VFSCapabilities { [.read] }
    private let base: String
    private let files: [String: Data]

    init(base: String, files: [String: Data]) { self.base = base; self.files = files }

    func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        AsyncThrowingStream { continuation in
            if dir.path == base {
                continuation.yield(VFSEntryBatch(entries: files.map { name, data in
                    VFSEntry(name: name, ext: "", kind: .file, size: Int64(data.count),
                             modified: Date(timeIntervalSince1970: 1_600_000_000), created: nil,
                             posixMode: 0o644, bsdFlags: 0, isHidden: false)
                }))
            }
            continuation.finish()
        }
    }

    /// The whole file in one element, which is all `SyncScanner.readAll` needs.
    private struct OneShot: VFSReadStream {
        typealias Element = Data
        let data: Data
        struct AsyncIterator: AsyncIteratorProtocol {
            var pending: Data?
            mutating func next() async throws -> Data? { defer { pending = nil }; return pending }
        }
        func makeAsyncIterator() -> AsyncIterator { AsyncIterator(pending: data) }
        func close() async throws {}
    }

    private func rel(_ path: VFSPath) -> String {
        String(path.path.dropFirst(base.count).drop(while: { $0 == "/" }))
    }

    func stat(_ path: VFSPath) async throws -> VFSEntry { throw VFSError.notFound(path.path) }
    func openRead(_ path: VFSPath) async throws -> VFSReadStream {
        guard let data = files[rel(path)] else { throw VFSError.notFound(path.path) }
        return OneShot(data: data)
    }
    func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream {
        throw VFSError.notFound(path.path)
    }
    func mkdir(_ path: VFSPath) async throws {}
    func delete(_ path: VFSPath) async throws {}
    func rename(_ from: VFSPath, to: VFSPath) async throws {}
    func setAttributes(_ path: VFSPath, attributes: VFSAttributes) async throws {}
    func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>? { nil }
    func localFileIfAvailable(_ path: VFSPath) async throws -> URL? { nil }
}
