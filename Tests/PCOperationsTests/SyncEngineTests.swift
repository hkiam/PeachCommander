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

    private func scanBothDirsDetailed(mask: String = "*.*", withSubdirs: Bool = true,
                                      byContent: Bool = false) async -> SyncScanOutcome {
        await SyncScanner.scanDetailed(left: .localDir(left.path), right: .localDir(right.path),
                                       mask: mask, withSubdirs: withSubdirs, byContent: byContent)
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
                                          right: .localDir(right.path), toTrash: false).errors
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try String(contentsOf: right.appendingPathComponent("a.txt"), encoding: .utf8),
                       "hello")
    }

    func testCopyingRightToLeftGoesTheOtherWay() async throws {
        try write("world", to: right, "b.txt")
        let items = await scanBothDirs()
        let results = item(items, "b.txt").map { [SyncResult(action: .copyToLeft, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                   right: .localDir(right.path), toTrash: false).errors
        XCTAssertEqual(errors, [])
        XCTAssertEqual(try String(contentsOf: left.appendingPathComponent("b.txt"), encoding: .utf8),
                       "world")
    }

    func testDeletingOnTheRightRemovesTheFile() async throws {
        try write("gone", to: right, "c.txt")
        let items = await scanBothDirs()
        let results = item(items, "c.txt").map { [SyncResult(action: .deleteRight, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                   right: .localDir(right.path), toTrash: false).errors
        XCTAssertEqual(errors, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: right.appendingPathComponent("c.txt").path))
    }

    func testAnActionOnAnUntouchedFileLeavesTheOtherFilesAlone() async throws {
        try write("keep me", to: right, "untouched.txt")
        try write("copy me", to: left, "moved.txt")
        let items = await scanBothDirs()
        let results = item(items, "moved.txt").map { [SyncResult(action: .copyToRight, item: $0)] } ?? []
        let errors = await SyncExecutor.execute(results, left: .localDir(left.path),
                                                   right: .localDir(right.path), toTrash: false).errors
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
                                                right: remoteSide(right), toTrash: false).errors
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
                                                right: remoteSide(right), toTrash: false).errors
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
                                                right: remoteSide(right), toTrash: false).errors
        XCTAssertEqual(errors, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: right.appendingPathComponent("del.txt").path))
    }

    func testTwoRemoteSidesAreRefusedRatherThanHalfDone() async throws {
        try write("x", to: right, "f.txt")
        let items = await SyncScanner.scan(left: remoteSide(left), right: remoteSide(right),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        let results = item(items, "f.txt").map { [SyncResult(action: .copyToLeft, item: $0)] } ?? []
        let report = await SyncExecutor.execute(results, left: remoteSide(left),
                                                right: remoteSide(right), toTrash: false)
        // A refusal, not a failure: nothing broke, the engine declines this pair of sides. Reported
        // as an error it was indistinguishable from a copy that went wrong.
        XCTAssertEqual(report.errors, [])
        XCTAssertEqual(report.refusals.count, 1)
        XCTAssertTrue(report.refusals[0].message.contains("server to another"),
                      report.refusals[0].message)
        XCTAssertEqual(report.refusals[0].path, "f.txt", "the refused item's path travels with it")
        XCTAssertFalse(report.completedEverything, "a refused plan reported as fully done")
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
                                                right: remoteSide(right), toTrash: false).errors
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

    /// Dropping the entry is right; letting its folder look fully compared afterwards is not.
    ///
    /// The name is refused, so it never becomes something to copy — but the folder it was in was
    /// then recorded as completely accounted for, and a mirror deletes a folder recursively. On a
    /// server that is permanent: there is no Trash to fish it back out of. So the folder is marked
    /// as holding something the comparison did not include, exactly as an excluded path marks its
    /// ancestors.
    func test_aFolderHoldingARefusedNameIsNotTreatedAsFullyCompared() async throws {
        let hostile = HostileListingFS()
        let outcome = await SyncScanner.scanDetailed(
            left: .localDir(left.path),
            right: .remote(RemoteSyncSource(fs: hostile, path: "/")),
            mask: "*.*", withSubdirs: true, byContent: false)

        // The premise: the honest neighbour arrived and the refused name did not.
        XCTAssertNotNil(item(outcome.items, "sub/honest.txt"))
        XCTAssertNil(item(outcome.items, "sub/.."))

        XCTAssertEqual(item(outcome.items, "sub")?.hasHeldBackContent, true,
                       "a folder whose listing had an entry dropped was offered for recursive deletion")
        XCTAssertFalse(outcome.rightScope.provesAbsence(of: "sub/anything.txt"),
                       "the walk claims to know what is not in a folder it could not fully read")
        // And the rest of the side is unaffected, or one hostile name would disable the whole walk.
        XCTAssertTrue(outcome.rightScope.provesAbsence(of: "not-there-at-all.txt"))
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
                                                right: remoteSide(right), toTrash: false).errors
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
                                                right: remoteSide(right), toTrash: false).errors
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
                                                right: .localDir(right.path), toTrash: false).errors
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
        let task = Task.detached { () -> SyncRunReport in
            await SyncExecutor.execute(plan, left: .localDir(paths.0), right: .localDir(paths.1),
                                       toTrash: false)
        }
        task.cancel()
        let report = await task.value
        XCTAssertEqual(report.errors, [])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: right.path), [])
        // The run says it stopped, rather than the caller having to ask `Task.isCancelled` a second
        // time — and it still accounts for every planned row, as "not attempted".
        XCTAssertTrue(report.stopped)
        XCTAssertEqual(report.outcomes.count, plan.count)
        XCTAssertEqual(report.applied, 0)
        XCTAssertFalse(report.completedEverything)
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
                                                right: .zip(zip.path), toTrash: false).errors
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
                                                right: .localDir(right.path), toTrash: false).errors

        XCTAssertTrue(FileManager.default.fileExists(atPath: right.appendingPathComponent("Old/kept.jpg").path),
                      "a file the mask excluded was deleted along with its folder")
        // What *was* compared is still deleted: this is a guard, not a retreat.
        XCTAssertFalse(FileManager.default.fileExists(atPath: right.appendingPathComponent("Old/listed.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: right.appendingPathComponent("Old").path),
                      "the folder went even though something inside it survived")
        // And silently: the scanner marks the folder as holding something the comparison left out,
        // so it is never classified as a delete in the first place and the executor's guard — which
        // does report — is not reached. Without that marking an ordinary `node_modules/` exclusion
        // would put a line in the error list on every single run.
        XCTAssertEqual(errors, [], "the kept folder was reported as a problem")
        XCTAssertFalse(results.contains { $0.item.relativePath == "Old" && $0.action == .deleteRight },
                       "the folder was still planned for deletion")
    }

    /// The executor's guard on its own, reached by handing it a delete the model would not have
    /// produced. It is the last line of defence — for a folder that gained a file between the scan
    /// and the run, or a caller that classified elsewhere — and it does report what it kept.
    func test_theExecutorRefusesADirectoryDeleteThatWouldTakeUncomparedContent() async throws {
        try write("never compared", to: right, "Stray/inside.txt")
        let item = SyncItem(relativePath: "Stray", isDirectory: true,
                            leftSize: nil, leftModified: nil,
                            rightSize: nil, rightModified: nil)
        let errors = await SyncExecutor.execute([SyncResult(action: .deleteRight, item: item)],
                                                left: .localDir(left.path),
                                                right: .localDir(right.path), toTrash: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: right.appendingPathComponent("Stray/inside.txt").path),
                      "a file that was never compared was deleted with its folder")
        // Kept back on purpose, and said so as a refusal rather than as a fault: with an ordinary
        // `node_modules/` exclusion this fires on every mirror run, and as an error it made a
        // wholly successful run report failures.
        XCTAssertEqual(errors.errors, [], "a deliberate refusal was reported as a failure")
        XCTAssertEqual(errors.refusals.map(\.path), ["Stray"], "the kept folder was not reported")
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
                                                right: .localDir(right.path), toTrash: false).errors
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


    // MARK: - The filter decides what is part of the comparison

    /// The case the two-place design exists for, and the one that would be a silent data loss if it
    /// were got wrong. Applied per side inside the walk, "nothing over this size" drops the large
    /// half of a mismatched pair; the pair then reads as "only on the right" and the small file is
    /// copied over the large one. The sizes stand in for 3 GB and 1 KB — the arithmetic is the same
    /// and the test does not have to write three gigabytes to make the point.
    func test_anExclusionBySizeNeverTurnsIntoACopy() async throws {
        try write(String(repeating: "x", count: 500), to: left, "report.dat")
        try write("tiny", to: right, "report.dat")
        let outcome = await SyncScanner.scanDetailed(
            left: .localDir(left.path), right: .localDir(right.path), mask: "*.*",
            withSubdirs: true, byContent: false, filter: SyncFilter(maxSize: 100))

        XCTAssertFalse(outcome.items.contains { $0.relativePath == "report.dat" },
                       "a pair excluded by size produced a row, and that row would be a copy")
        // Specifically not this, which is what the per-side version produces:
        let results = SyncModel.classify(outcome.items, options: SyncOptions())
        XCTAssertFalse(results.contains { $0.item.relativePath == "report.dat" && $0.action == .copyToLeft },
                       "an exclusion turned into a copy onto the excluded side")
        XCTAssertEqual(outcome.heldBack, 1)
    }

    func test_anExcludedFolderIsNotWalkedOnEitherSide() async throws {
        try write("a", to: left, "src/main.swift")
        try write("b", to: left, "node_modules/left-pad/index.js")
        try write("c", to: right, "node_modules/right-pad/index.js")
        let outcome = await SyncScanner.scanDetailed(
            left: .localDir(left.path), right: .localDir(right.path), mask: "*.*",
            withSubdirs: true, byContent: false,
            filter: SyncFilter(excludePatterns: "node_modules/"))
        XCTAssertEqual(outcome.items.map(\.relativePath).sorted(), ["src", "src/main.swift"])
    }

    /// Cutting off the descent must be a speed-up and nothing else. A zip walk cannot prune at all —
    /// its entry list is flat — so the same tree, once as folders and once as an archive, is the
    /// measurement: same rule, one walk pruning and one not, same answer.
    func test_notPruningReachesTheSameAnswerAsPruning() async throws {
        try write("a", to: left, "keep.txt")
        try write("b", to: left, "build/app.o")
        try write("c", to: left, "build/deep/more.o")
        let zip = root.appendingPathComponent("same.zip")
        try ZipWriter.create(at: zip, files: [(path: "keep.txt", data: Data("a".utf8)),
                                              (path: "build/", data: Data()),
                                              (path: "build/app.o", data: Data("b".utf8)),
                                              (path: "build/deep/", data: Data()),
                                              (path: "build/deep/more.o", data: Data("c".utf8))])
        let filter = SyncFilter(excludePatterns: "build/")
        let pruned = await SyncScanner.scanDetailed(left: .localDir(left.path), right: .localDir(right.path),
                                                    mask: "*.*", withSubdirs: true, byContent: false,
                                                    filter: filter)
        let unpruned = await SyncScanner.scanDetailed(left: .zip(zip.path), right: .localDir(right.path),
                                                      mask: "*.*", withSubdirs: true, byContent: false,
                                                      filter: filter)
        XCTAssertEqual(pruned.items.map(\.relativePath).sorted(),
                       unpruned.items.map(\.relativePath).sorted(),
                       "the walk that prunes and the walk that cannot disagreed")
        XCTAssertEqual(pruned.items.map(\.relativePath), ["keep.txt"])
    }

    /// Distinct paths, so an excluded folder is one entry and not one per file inside it — both to
    /// bound what the scan has to remember and because "held back: 1" is the honest report for one
    /// folder somebody excluded on purpose.
    func test_theScanReportsHowManyEntriesTheFilterHeldBack() async throws {
        try write("a", to: left, "keep.txt")
        try write("b", to: left, "build/one.o")
        try write("c", to: left, "build/two.o")
        try write("d", to: left, "notes.tmp")
        try write("e", to: right, "notes.tmp")
        let outcome = await SyncScanner.scanDetailed(
            left: .localDir(left.path), right: .localDir(right.path), mask: "*.*",
            withSubdirs: true, byContent: false,
            filter: SyncFilter(excludePatterns: "build/;*.tmp"))
        // `build` counts once, and `notes.tmp` once even though both sides dropped it.
        XCTAssertEqual(outcome.heldBack, 2)
        XCTAssertEqual(outcome.items.map(\.relativePath), ["keep.txt"])
    }

    /// The mask's exclusions stay out of that number: the mask is on screen and always has been,
    /// while the filter lives behind a button, and a count that moved for every masked file would
    /// say nothing about the thing worth noticing.
    func test_theMaskDoesNotCountTowardsTheHeldBackNumber() async throws {
        try write("a", to: left, "keep.txt")
        try write("b", to: left, "one.jpg")
        try write("c", to: left, "two.jpg")
        let outcome = await SyncScanner.scanDetailed(
            left: .localDir(left.path), right: .localDir(right.path), mask: "*.txt",
            withSubdirs: true, byContent: false)
        XCTAssertEqual(outcome.heldBack, 0)
        XCTAssertEqual(outcome.items.map(\.relativePath), ["keep.txt"])
    }

    func test_theMaskAndTheFilterBothApply() async throws {
        try write("a", to: left, "keep.txt")
        try write("b", to: left, "draft.txt")
        try write("c", to: left, "photo.jpg")
        let outcome = await SyncScanner.scanDetailed(
            left: .localDir(left.path), right: .localDir(right.path), mask: "*.txt",
            withSubdirs: true, byContent: false, filter: SyncFilter(excludePatterns: "draft.*"))
        XCTAssertEqual(outcome.items.map(\.relativePath), ["keep.txt"],
                       "the mask kept the jpg out and the filter the draft")
    }

    /// The quiet half of the mirror fix, at the level the scanner works on: a folder holding an
    /// entry the filter excluded is marked, and the model then declines to delete it.
    func test_aMirrorDoesNotPlanToDeleteAFolderHoldingFilteredContent() async throws {
        try write("compared", to: right, "Old/listed.txt")
        try write("excluded", to: right, "Old/notes.tmp")
        let outcome = await SyncScanner.scanDetailed(
            left: .localDir(left.path), right: .localDir(right.path), mask: "*.*",
            withSubdirs: true, byContent: false, filter: SyncFilter(excludePatterns: "*.tmp"))
        let folder = outcome.items.first { $0.relativePath == "Old" }
        XCTAssertEqual(folder?.hasHeldBackContent, true, "the folder was not marked as incomplete")
        let results = SyncModel.classify(outcome.items, options: SyncOptions(asymmetric: true))
        XCTAssertEqual(results.first { $0.item.relativePath == "Old" }?.action, SyncAction.none)
        // The file inside it that *was* compared is still planned for deletion.
        XCTAssertEqual(results.first { $0.item.relativePath == "Old/listed.txt" }?.action,
                       SyncAction.deleteRight)
    }

    /// And with subdirectories switched off, where nothing below the top level was looked at at all.
    func test_aMirrorDoesNotPlanToDeleteAFolderItNeverLookedInside() async throws {
        try write("never seen", to: right, "Stray/inside.txt")
        let outcome = await SyncScanner.scanDetailed(
            left: .localDir(left.path), right: .localDir(right.path), mask: "*.*",
            withSubdirs: false, byContent: false)
        XCTAssertEqual(outcome.items.first { $0.relativePath == "Stray" }?.hasHeldBackContent, true)
        let results = SyncModel.classify(outcome.items, options: SyncOptions(asymmetric: true))
        XCTAssertEqual(results.first { $0.item.relativePath == "Stray" }?.action, SyncAction.none)
    }

    /// A relative date window is resolved against the run, which is what makes a saved filter a
    /// repeatable job rather than a snapshot of the day it was saved.
    func test_theDateWindowIsMeasuredFromTheRun() async throws {
        let file = try write("x", to: left, "old.txt")
        let stamp = Date(timeIntervalSince1970: 1_000_000_000)
        try FileManager.default.setAttributes([.modificationDate: stamp], ofItemAtPath: file.path)

        let soon = await SyncScanner.scanDetailed(
            left: .localDir(left.path), right: .localDir(right.path), mask: "*.*",
            withSubdirs: true, byContent: false, filter: SyncFilter(modifiedWithinDays: 30),
            now: stamp.addingTimeInterval(10 * 86_400))
        XCTAssertEqual(soon.items.map(\.relativePath), ["old.txt"])

        let later = await SyncScanner.scanDetailed(
            left: .localDir(left.path), right: .localDir(right.path), mask: "*.*",
            withSubdirs: true, byContent: false, filter: SyncFilter(modifiedWithinDays: 30),
            now: stamp.addingTimeInterval(400 * 86_400))
        XCTAssertEqual(later.items, [], "the same filter kept the file at a later run")
        XCTAssertEqual(later.heldBack, 1)
    }


    // MARK: - Bytes that could not be read are not a verdict

    /// "By content" on a pair neither side of which can be read used to report **equal**.
    ///
    /// `loadData` answers `Data?`, and `leftData == rightData` on two `nil`s is `true` — so a pair
    /// the comparison never managed to look at came out as identical, in the grid and in the plan.
    /// Not compared and identical are opposite statements.
    ///
    /// Verified by putting the claim back — and the first attempt at that proved the test was not
    /// yet measuring it: injecting "equal" only where the comparison *finishes* left this passing,
    /// because an unreadable side never gets that far. It is the early returns, one per way of
    /// failing to open a side, that carry it.
    func test_aPairNeitherSideOfWhichCanBeReadIsNotCalledEqual() async throws {
        let file = try write("secret", to: left, "secret.bin")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644],
                                                       ofItemAtPath: file.path) }
        let server = RefusingReadFS(base: "/srv", names: ["secret.bin": 6])
        let items = await SyncScanner.scan(left: .localDir(left.path),
                                           right: .remote(RemoteSyncSource(fs: server, path: "/srv")),
                                           mask: "*.*", withSubdirs: true, byContent: true)
        let entry = item(items, "secret.bin")
        XCTAssertNotNil(entry, "the pair was dropped rather than reported")
        XCTAssertNotEqual(entry?.contentEqual, true,
                          "two files that could not be read were reported as identical")
    }


    // MARK: - Comparing by content does not hold the files

    private func serverSide(_ fs: VirtualFileSystem) -> SyncSide {
        .remote(RemoteSyncSource(fs: fs, path: "/srv"))
    }

    /// The claim worth measuring: a difference near the start stops the download.
    ///
    /// Before this, both files were read whole into memory and the two buffers compared — so a large
    /// pair over a share was fetched in full even when the first block already differed, and both
    /// copies were resident at once. The server counts what it actually handed over.
    func test_aDifferenceEarlyOnStopsTheDownload() async throws {
        let size = 400_000
        var mine = Data(repeating: 0x41, count: size)
        var theirs = Data(repeating: 0x41, count: size)
        theirs[100] = 0x42                               // differs inside the first 64 KB block
        try mine.write(to: left.appendingPathComponent("big.bin"))
        let server = ChunkedServerFS(base: "/srv", files: ["big.bin": theirs], pieceSize: 1 << 16)

        let items = await SyncScanner.scan(left: .localDir(left.path), right: serverSide(server),
                                           mask: "*.*", withSubdirs: true, byContent: true)
        XCTAssertEqual(item(items, "big.bin")?.contentEqual, false)
        XCTAssertLessThan(server.served, size,
                          "the whole file was downloaded although the first block already differed")
        XCTAssertLessThanOrEqual(server.served, 1 << 16,
                                 "more than the one block that settled it was fetched")
        mine.removeAll(); theirs.removeAll()
    }

    /// And an equal pair is still read to the end, because that is the only way to know.
    func test_anEqualPairIsComparedToTheEnd() async throws {
        let bytes = Data((0..<300_000).map { UInt8($0 & 0xFF) })
        try bytes.write(to: left.appendingPathComponent("same.bin"))
        let server = ChunkedServerFS(base: "/srv", files: ["same.bin": bytes], pieceSize: 1 << 16)
        let items = await SyncScanner.scan(left: .localDir(left.path), right: serverSide(server),
                                           mask: "*.*", withSubdirs: true, byContent: true)
        XCTAssertEqual(item(items, "same.bin")?.contentEqual, true)
        XCTAssertEqual(server.served, bytes.count)
    }

    /// A difference in the *last* byte of a multi-block file: the loop has to keep going, and a
    /// comparison that stopped after one block would call this pair identical.
    func test_aDifferenceInTheLastByteIsStillFound() async throws {
        let size = 200_000
        var mine = Data(repeating: 0x41, count: size)
        var theirs = mine
        theirs[size - 1] = 0x42
        try mine.write(to: left.appendingPathComponent("tail.bin"))
        let server = ChunkedServerFS(base: "/srv", files: ["tail.bin": theirs], pieceSize: 1 << 16)
        let items = await SyncScanner.scan(left: .localDir(left.path), right: serverSide(server),
                                           mask: "*.*", withSubdirs: true, byContent: true)
        XCTAssertEqual(item(items, "tail.bin")?.contentEqual, false)
        mine.removeAll(); theirs.removeAll()
    }

    /// A server hands out whatever piece sizes it likes, and they do not line up with the blocks
    /// this side reads. The pieces here are 7 bytes — deliberately coprime with everything — so a
    /// comparison that assumed matching block boundaries would report a difference that is not there.
    func test_aServersOwnPieceSizesDoNotAffectTheVerdict() async throws {
        let bytes = Data((0..<5_000).map { UInt8($0 & 0xFF) })
        try bytes.write(to: left.appendingPathComponent("odd.bin"))
        let server = ChunkedServerFS(base: "/srv", files: ["odd.bin": bytes], pieceSize: 7)
        let items = await SyncScanner.scan(left: .localDir(left.path), right: serverSide(server),
                                           mask: "*.*", withSubdirs: true, byContent: true)
        XCTAssertEqual(item(items, "odd.bin")?.contentEqual, true,
                       "mismatched piece boundaries were reported as a difference")
    }

    /// A zip member is streamed too, not decompressed whole. Equal and different, because a
    /// comparison that answered nil for an archive would pass a test that only checked "not true".
    func test_aZipMemberIsComparedInBlocks() async throws {
        let same = Data((0..<200_000).map { UInt8($0 & 0xFF) })
        var other = same
        other[199_999] ^= 0xFF
        try same.write(to: left.appendingPathComponent("a.bin"))
        try same.write(to: left.appendingPathComponent("b.bin"))
        let zip = root.appendingPathComponent("members.zip")
        try ZipWriter.create(at: zip, files: [(path: "a.bin", data: same),
                                              (path: "b.bin", data: other)])
        let items = await SyncScanner.scan(left: .localDir(left.path), right: .zip(zip.path),
                                           mask: "*.*", withSubdirs: true, byContent: true)
        XCTAssertEqual(item(items, "a.bin")?.contentEqual, true)
        XCTAssertEqual(item(items, "b.bin")?.contentEqual, false)
    }

    /// Two local folders still get the same answer they always did — the special case for them was
    /// removed, and one comparison now serves all three kinds of side.
    func test_twoLocalFoldersAreStillComparedByteForByte() async throws {
        try write("aaaa", to: left, "same.txt");  try write("aaaa", to: right, "same.txt")
        try write("aaaa", to: left, "differ.txt"); try write("bbbb", to: right, "differ.txt")
        let items = await scanBothDirs(byContent: true)
        XCTAssertEqual(item(items, "same.txt")?.contentEqual, true)
        XCTAssertEqual(item(items, "differ.txt")?.contentEqual, false)
    }


    // MARK: - The scan says what it was able to see

    /// A root that is not there answered an empty walk with no error and no mark. In mirror mode
    /// that empty walk classifies every file on the *other* side as "delete it", pre-ticked, one
    /// confirmation away — a mistyped path, an unmounted volume, and the target is wiped. This is
    /// the fact the guard is built on, so it is measured at its source first.
    func test_theScopeSaysSoWhenARootIsNotThere() async throws {
        try write("keep", to: right, "a.txt")
        let outcome = await SyncScanner.scanDetailed(
            left: .localDir(root.appendingPathComponent("does-not-exist").path),
            right: .localDir(right.path), mask: "*.*", withSubdirs: true, byContent: false)
        XCTAssertFalse(outcome.leftScope.rootEnumerable, "a missing root read as an empty folder")
        XCTAssertFalse(outcome.leftScope.isReliable)
        XCTAssertFalse(outcome.leftScope.provesAbsence(of: "a.txt"),
                       "absence on an unreadable side was taken as evidence")
        // The other side is fine, and says so.
        XCTAssertTrue(outcome.rightScope.isReliable)
        XCTAssertTrue(outcome.rightScope.provesAbsence(of: "not-there.txt"))
    }

    /// An empty folder is a perfectly good answer and must stay trustworthy — otherwise a mirror
    /// could never clear a target whose source really is empty.
    func test_anEmptyRootIsStillReliable() async throws {
        let outcome = await scanBothDirsDetailed()
        XCTAssertTrue(outcome.leftScope.isReliable)
        XCTAssertEqual(outcome.leftScope.entriesVisited, 0)
        XCTAssertFalse(outcome.leftScope.rootObservedNonEmpty)
    }

    /// And so is a mask that happens to exclude everything — which is why the reliability test
    /// counts what the walk was *handed*, not what it kept. Measured against the kept count this
    /// case reads as a failure and would refuse deletions a mirror is right to make.
    func test_aMaskThatExcludesEverythingDoesNotMakeASideUnreliable() async throws {
        try write("x", to: left, "photo.jpg")
        try write("x", to: left, "other.jpg")
        let outcome = await SyncScanner.scanDetailed(left: .localDir(left.path),
                                                    right: .localDir(right.path),
                                                    mask: "*.txt", withSubdirs: true, byContent: false)
        XCTAssertEqual(outcome.leftScope.entriesFound, 0, "the mask should have kept nothing")
        XCTAssertEqual(outcome.leftScope.entriesVisited, 2)
        XCTAssertTrue(outcome.leftScope.isReliable, "a mask that keeps nothing was read as a failure")
    }

    /// A root this process cannot read.
    ///
    /// Measured: `chmod 000` does **not** make `FileManager.enumerator(atPath:)` answer nil — it
    /// hands back an enumerator that yields nothing at all. So this case is carried entirely by the
    /// plain listing failing, not by the root being un-enumerable, and that is why the root check on
    /// its own is not sufficient. Verified by disabling each mechanism separately: only the listing
    /// one fails this test.
    func test_anUnreadableRootIsNotReliable() async throws {
        let locked = root.appendingPathComponent("locked", isDirectory: true)
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try "x".write(to: locked.appendingPathComponent("inside.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                       ofItemAtPath: locked.path) }
        let outcome = await SyncScanner.scanDetailed(left: .localDir(locked.path),
                                                    right: .localDir(right.path),
                                                    mask: "*.*", withSubdirs: true, byContent: false)
        XCTAssertFalse(outcome.leftScope.isReliable, "an unreadable root read as an empty folder")
    }

    /// An archive that will not open is not an empty archive — same defect, third shape.
    func test_aCorruptArchiveSideIsUnreliableRatherThanEmpty() async throws {
        let broken = root.appendingPathComponent("broken.zip")
        try Data("this is not a zip file".utf8).write(to: broken)
        try write("keep", to: right, "a.txt")
        let outcome = await SyncScanner.scanDetailed(left: .zip(broken.path),
                                                    right: .localDir(right.path),
                                                    mask: "*.*", withSubdirs: true, byContent: false)
        XCTAssertFalse(outcome.leftScope.rootEnumerable)
        XCTAssertFalse(outcome.leftScope.provesAbsence(of: "a.txt"))
    }

    /// A folder whose inside was not fully seen cannot prove that something under it is gone —
    /// which is the half a root check does not cover, because the path-based enumerator has no
    /// error handler and an unreadable subtree is simply missing.
    func test_anIncompleteFolderProvesNothingAboutItsContents() async throws {
        try write("a", to: left, "keep.txt")
        try write("b", to: left, "build/one.o")
        let outcome = await SyncScanner.scanDetailed(
            left: .localDir(left.path), right: .localDir(right.path), mask: "*.*",
            withSubdirs: true, byContent: false, filter: SyncFilter(excludePatterns: "build/"))
        XCTAssertTrue(outcome.leftScope.isReliable, "the walk itself was fine")
        XCTAssertTrue(outcome.leftScope.provesAbsence(of: "elsewhere.txt"))
        XCTAssertFalse(outcome.leftScope.provesAbsence(of: "build/one.o"),
                       "a held-back folder was taken as proof its contents are gone")
        XCTAssertFalse(outcome.leftScope.provesAbsence(of: "build"),
                       "the excluded folder itself was taken as absent")
    }

    /// Without subdirs, nothing below the top level was looked at at all.
    func test_withoutSubdirsNothingBelowTheTopLevelIsProven() async throws {
        try write("x", to: left, "Stray/inside.txt")
        let outcome = await SyncScanner.scanDetailed(left: .localDir(left.path),
                                                    right: .localDir(right.path),
                                                    mask: "*.*", withSubdirs: false, byContent: false)
        XCTAssertFalse(outcome.leftScope.provesAbsence(of: "Stray/inside.txt"))
    }

    /// A caller handed no scope at all must not be able to justify anything — the default is
    /// "nothing was established", not "everything was fine".
    func test_anOutcomeBuiltWithoutAScopeProvesNothing() {
        let outcome = SyncScanOutcome(items: [], heldBack: 0)
        XCTAssertFalse(outcome.leftScope.isReliable)
        XCTAssertFalse(outcome.leftScope.provesAbsence(of: "anything"))
        XCTAssertFalse(outcome.rightScope.provesAbsence(of: "anything"))
    }


    // MARK: - The run says what it did

    /// The invariant the whole report rests on, and the one that kills every unsound case at once:
    /// a planned row that produced no outcome is a row nobody can say anything about. "It is not in
    /// the error list" was never the same as "it happened".
    func test_everyPlannedItemProducesExactlyOneOutcome() async throws {
        try write("a", to: left, "one.txt")
        try write("b", to: left, "sub/two.txt")
        try write("c", to: right, "stray.txt")
        let items = await scanBothDirs()
        let plan = SyncModel.classify(items, options: SyncOptions(asymmetric: true))
            .filter { $0.action != .none }
        let report = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                right: .localDir(right.path), toTrash: false)
        XCTAssertEqual(report.outcomes.count, plan.count)
        XCTAssertEqual(Set(report.outcomes.map(\.relativePath)),
                       Set(plan.map(\.item.relativePath)))
        XCTAssertTrue(report.completedEverything)
        XCTAssertFalse(report.stopped)
        XCTAssertEqual(report.applied, plan.count)
    }

    /// A local failure is reported against the relative path. It used to arrive as the leaf name, so
    /// a failure at `a/b/x.txt` came back as `x.txt` and could not be matched to its row at all.
    ///
    /// Structural now rather than a rule each helper has to remember: the path travels on the
    /// outcome, and a helper only supplies the message. Measured — putting the leaf name back into
    /// `copyLocalToLocal` does not make this fail, because it can only spoil the message. That is
    /// the point of the change, and the reason this test cannot be a live control for it.
    func test_aLocalFailureReportsTheRelativePathAndNotTheLeafName() async throws {
        try write("payload", to: left, "deep/inner/file.txt")
        // A file where the destination's parent folder has to go: the copy cannot create it.
        try "blocker".write(to: right.appendingPathComponent("deep"), atomically: true, encoding: .utf8)
        let items = await scanBothDirs()
        let plan = SyncModel.classify(items, options: SyncOptions()).filter { $0.action != .none }
        let report = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                right: .localDir(right.path), toTrash: false)
        let failed = report.errors.map(\.path)
        XCTAssertFalse(failed.isEmpty, "the blocked copy was not reported at all")
        XCTAssertTrue(failed.allSatisfy { $0.contains("/") || $0 == "deep" },
                      "a failure came back as a leaf name: \(failed)")
    }

    /// Cancelling used to skip the archive rewrite entirely, so every file staged for the zip was
    /// neither written nor mentioned — the run reported nothing about them at all. The flush runs
    /// whatever happens, and each staged entry gets its own outcome.
    func test_cancellingStillFlushesTheArchiveAndAccountsForEveryStagedEntry() async throws {
        for i in 0..<6 { try write("x\(i)", to: left, "f\(i).txt") }
        let zip = root.appendingPathComponent("target.zip")
        try ZipWriter.create(at: zip, files: [(path: "placeholder.txt", data: Data("p".utf8))])
        let items = await SyncScanner.scan(left: .localDir(left.path), right: .zip(zip.path),
                                           mask: "*.*", withSubdirs: true, byContent: false)
        let plan = items.filter { $0.leftSize != nil && $0.rightSize == nil }
            .map { SyncResult(action: .copyToRight, item: $0) }
        XCTAssertEqual(plan.count, 6)
        let paths = (left.path, zip.path)
        let task = Task.detached { () -> SyncRunReport in
            await SyncExecutor.execute(plan, left: .localDir(paths.0), right: .zip(paths.1),
                                       toTrash: false)
        }
        task.cancel()
        let report = await task.value
        XCTAssertEqual(report.outcomes.count, plan.count,
                       "a cancelled run left planned rows unaccounted for")
        // Whatever the cancellation caught, no row may be left saying it was staged: either it went
        // into the archive or it is named as not attempted.
        XCTAssertFalse(report.outcomes.contains {
            if case .notAttempted(let reason) = $0.status { return reason.contains("staged") }
            return false
        }, "a staged entry was never resolved")
    }

    /// A failed archive rewrite names every entry in the batch. It used to be one error with an
    /// empty path, however many files were in it.
    func test_aFailedArchiveRewriteNamesEveryEntryInTheBatch() async throws {
        for i in 0..<4 { try write("x\(i)", to: left, "f\(i).txt") }
        // A "zip" that is a directory: ZipWriter cannot write over it, so the rewrite fails.
        let notAZip = root.appendingPathComponent("target.zip", isDirectory: true)
        try FileManager.default.createDirectory(at: notAZip, withIntermediateDirectories: true)
        let plan = (0..<4).map { i in
            SyncResult(action: .copyToRight,
                       item: SyncItem(relativePath: "f\(i).txt", isDirectory: false,
                                      leftSize: 2, leftModified: Date(),
                                      rightSize: nil, rightModified: nil))
        }
        let report = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                right: .zip(notAZip.path), toTrash: false)
        XCTAssertEqual(report.outcomes.count, 4)
        XCTAssertEqual(Set(report.errors.map(\.path)),
                       Set((0..<4).map { "f\($0).txt" }),
                       "the batch failure did not name its entries: \(report.errors.map(\.path))")
        XCTAssertFalse(report.errors.contains { $0.path.isEmpty },
                       "an error came back with no path at all")
    }

    /// A folder "copied" into an archive is neither a success nor a failure — it is nothing to do,
    /// and it used to be reported as neither, so a caller counting either was wrong.
    func test_aFolderCopiedIntoAnArchiveIsReportedAsNothingToDo() async throws {
        let zip = root.appendingPathComponent("t.zip")
        try ZipWriter.create(at: zip, files: [(path: "p.txt", data: Data("p".utf8))])
        let plan = [SyncResult(action: .copyToRight,
                               item: SyncItem(relativePath: "Folder", isDirectory: true,
                                              leftSize: 0, leftModified: Date(),
                                              rightSize: nil, rightModified: nil))]
        let report = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                right: .zip(zip.path), toTrash: false)
        XCTAssertEqual(report.outcomes.count, 1)
        guard case .noOp = report.outcomes[0].status else {
            return XCTFail("expected nothing-to-do, got \(report.outcomes[0].status)")
        }
        XCTAssertTrue(report.completedEverything, "nothing to do is not a failure")
    }

    /// What a caller recording the two sides needs, and cannot take from the source:
    /// `copyLocalToLocal` sets no timestamp at all, so the destination's date is the moment of the
    /// write.
    ///
    /// A **local** destination is read back whether or not anybody asked, and that is the claim this
    /// test exists for. `observeDestinations` used to guard this read as well, which meant a one-way
    /// or mirror run — the two modes that do the most copying — reported nothing at all about what
    /// it had left behind. The two reads are not the same cost: this one is `attributesOfItem` on a
    /// file written milliseconds earlier, out of the page cache; the flag now guards only the
    /// server's `stat`, which is a network round trip per file.
    func test_aLocalCopyCarriesTheDestinationsOwnSizeAndTimestampUnasked() async throws {
        try write("hello there", to: left, "a.txt")
        let items = await scanBothDirs()
        let plan = SyncModel.classify(items, options: SyncOptions()).filter { $0.action != .none }

        // No `observeDestinations`, and the destination is still described.
        let report = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                right: .localDir(right.path), toTrash: false)
        guard case .copied(let destination) = report.outcomes[0].status else {
            return XCTFail("expected a copy, got \(report.outcomes[0].status)")
        }
        XCTAssertEqual(destination.size, 11, "a local copy reported no size")
        let onDisk = try FileManager.default
            .attributesOfItem(atPath: right.appendingPathComponent("a.txt").path)[.modificationDate] as? Date
        XCTAssertEqual(destination.modified?.timeIntervalSince1970 ?? -1,
                       onDisk?.timeIntervalSince1970 ?? -2,
                       accuracy: 0.001, "the timestamp reported was not the destination's own")
    }

    /// Created or replaced, answered by the write and not by the scan.
    ///
    /// The scan's view is the wrong source: minutes pass between it and the copy — the comparison,
    /// the confirmation dialog, the run — and the item still says the destination was empty. Here
    /// the file is put at the destination *after* the plan was classified, which is exactly that
    /// race, and the outcome has to say it was replaced anyway.
    func test_aCopySaysWhetherItReplacedSomething() async throws {
        try write("new bytes", to: left, "a.txt")
        let items = await scanBothDirs()          // right/a.txt does not exist yet
        let plan = SyncModel.classify(items, options: SyncOptions()).filter { $0.action != .none }
        XCTAssertNil(item(items, "a.txt")?.rightSize, "the fixture must classify a.txt as absent")

        try write("older bytes", to: right, "a.txt")   // appears between the scan and the run
        let report = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                right: .localDir(right.path), toTrash: false)
        guard case .copied(let destination) = report.outcomes[0].status else {
            return XCTFail("expected a copy, got \(report.outcomes[0].status)")
        }
        XCTAssertEqual(destination.existed, true,
                       "the copy claimed to have created a file that was already there")

        // And the other direction, so `existed` is not simply always true.
        try write("only here", to: left, "b.txt")
        let items2 = await scanBothDirs()
        let plan2 = SyncModel.classify(items2, options: SyncOptions())
            .filter { $0.action != .none && $0.item.relativePath == "b.txt" }
        let report2 = await SyncExecutor.execute(plan2, left: .localDir(left.path),
                                                 right: .localDir(right.path), toTrash: false)
        guard case .copied(let fresh) = report2.outcomes[0].status else {
            return XCTFail("expected a copy, got \(report2.outcomes[0].status)")
        }
        XCTAssertEqual(fresh.existed, false)
    }

    /// A delete says whether it went to the Trash, which is the difference between recoverable and
    /// not — and the only place the app can state it per item.
    func test_aDeleteSaysWhetherItWentToTheTrash() async throws {
        try write("gone", to: right, "c.txt")
        let items = await scanBothDirs()
        let plan = item(items, "c.txt").map { [SyncResult(action: .deleteRight, item: $0)] } ?? []
        let report = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                right: .localDir(right.path), toTrash: false)
        XCTAssertEqual(report.outcomes.map(\.status), [.deleted(toTrash: false, trashedPath: nil)])
    }

    /// And where it went, which is what makes "it is in the Trash" an answer instead of a sentence.
    ///
    /// Asserted by reading the bytes back out of the Trash, not by `fileExists`: a path that exists
    /// proves only that *something* is there, and the whole use of this field is finding the file
    /// this run put down among everything else in there.
    ///
    /// Really deletes into the user's Trash, because that is the thing being tested and a fake
    /// cannot report a resulting URL. It cleans up after itself.
    func test_aTrashedDeleteSaysWhereTheFileWent() async throws {
        let payload = "the bytes that have to be findable again"
        try write(payload, to: right, "trashed-by-test.txt")
        let items = await scanBothDirs()
        let plan = item(items, "trashed-by-test.txt")
            .map { [SyncResult(action: .deleteRight, item: $0)] } ?? []
        XCTAssertEqual(plan.count, 1, "the fixture produced no delete row")

        let report = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                right: .localDir(right.path), toTrash: true)
        guard case .deleted(let toTrash, let trashedPath) = report.outcomes[0].status else {
            return XCTFail("expected a deletion, got \(report.outcomes[0].status)")
        }
        XCTAssertTrue(toTrash)
        guard let trashedPath else {
            return XCTFail("the deletion did not say where the file went")
        }
        defer { try? FileManager.default.removeItem(atPath: trashedPath) }
        XCTAssertEqual(try String(contentsOfFile: trashedPath, encoding: .utf8), payload,
                       "the path reported does not hold the file that was deleted")
        XCTAssertFalse(FileManager.default
            .fileExists(atPath: right.appendingPathComponent("trashed-by-test.txt").path))
    }


    /// The recorded path is the **real** one, even when the Trash already holds that name.
    ///
    /// This is the assertion that makes the field worth having rather than a convenience. macOS
    /// renames on collision — a second `gone.txt` lands as `gone.txt 11-17-15-028.txt` — so anything
    /// derived from `~/.Trash` plus the file's name points at *the earlier file*, and a put-back
    /// built on that guess would restore the wrong bytes and then delete somebody else's file from
    /// the Trash. Found by reading a screenshot of the real window, where exactly that rename showed
    /// up because an earlier test run had left a `gone.txt` in there.
    func test_theTrashedPathIsTheRealOneEvenWhenTheNameIsAlreadyTaken() async throws {
        var recorded: [String] = []
        for round in 0..<2 {
            let payload = "round \(round) — these bytes must stay with this path"
            try write(payload, to: right, "collides-in-trash.txt")
            let items = await scanBothDirs()
            let plan = item(items, "collides-in-trash.txt")
                .map { [SyncResult(action: .deleteRight, item: $0)] } ?? []
            XCTAssertEqual(plan.count, 1, "the fixture produced no delete row in round \(round)")

            let report = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                    right: .localDir(right.path), toTrash: true)
            guard case .deleted(_, .some(let trashedPath)) = report.outcomes[0].status else {
                return XCTFail("round \(round) did not say where the file went")
            }
            recorded.append(trashedPath)
            XCTAssertEqual(try String(contentsOfFile: trashedPath, encoding: .utf8), payload,
                           "round \(round): the recorded path does not hold that round's bytes")
        }
        defer { for path in recorded { try? FileManager.default.removeItem(atPath: path) } }

        XCTAssertEqual(Set(recorded).count, 2,
                       "both deletions reported the same path, so one of them is wrong")
        // And the guess a caller would otherwise have made is wrong for at least one of them.
        let guessed = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".Trash/collides-in-trash.txt")
        XCTAssertNotEqual(recorded[1], guessed,
                          "the second deletion happened to keep its name, so this run proves nothing")
    }

    /// An overwrite keeps the version it displaced, where a deletion keeps its file.
    ///
    /// The run used to contradict itself: its delete rows went to the Trash, and it warned in
    /// advance when they could not — while every file it replaced was destroyed with `removeItem`,
    /// no warning and no trace. Whichever of those two promises is right, they cannot both be.
    func test_anOverwriteKeepsTheVersionItDisplaced() async throws {
        try write("the new bytes", to: left, "replaced.txt")
        try write("THE PREVIOUS VERSION", to: right, "replaced.txt")
        let items = await scanBothDirs()
        // The row is built rather than classified. `classify` decides the *direction* from the
        // timestamps, and the fixture's right-hand file is the one written last — so asking for
        // `.copyToRight` out of the classification returned nothing and the test crashed on an
        // empty array instead of failing. What is under test is the overwrite, not the direction.
        guard let row = item(items, "replaced.txt") else {
            return XCTFail("the fixture produced no pair for replaced.txt")
        }
        XCTAssertNotNil(row.rightSize, "the destination must already exist for this to be an overwrite")
        let plan = [SyncResult(action: .copyToRight, item: row)]

        let report = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                right: .localDir(right.path), toTrash: true)
        guard case .copied(let destination) = report.outcomes.first?.status else {
            return XCTFail("expected a copy, got \(String(describing: report.outcomes.first))")
        }
        XCTAssertEqual(destination.existed, true)
        guard let displaced = destination.replacedTrashedPath else {
            return XCTFail("the overwrite did not say where the previous version went")
        }
        defer { try? FileManager.default.removeItem(atPath: displaced) }
        XCTAssertEqual(try String(contentsOfFile: displaced, encoding: .utf8),
                       "THE PREVIOUS VERSION",
                       "the path reported does not hold the version that was replaced")
        XCTAssertEqual(try String(contentsOf: right.appendingPathComponent("replaced.txt"),
                                  encoding: .utf8), "the new bytes")
    }

    /// …and with the Trash switched off it stays permanent, reported as nothing rather than as
    /// somewhere. A path for a version that was destroyed would be worse than none.
    func test_anOverwriteWithoutTheTrashKeepsNothingAndSaysSo() async throws {
        try write("the new bytes", to: left, "hard.txt")
        try write("gone for good", to: right, "hard.txt")
        let items = await scanBothDirs()
        guard let row = item(items, "hard.txt") else {
            return XCTFail("the fixture produced no pair for hard.txt")
        }
        let plan = [SyncResult(action: .copyToRight, item: row)]

        let report = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                right: .localDir(right.path), toTrash: false)
        guard case .copied(let destination) = report.outcomes.first?.status else {
            return XCTFail("expected a copy, got \(String(describing: report.outcomes.first))")
        }
        XCTAssertEqual(destination.existed, true)
        XCTAssertNil(destination.replacedTrashedPath)
    }

    /// A fresh copy displaces nothing, so there is nothing to report. Nil rather than an empty
    /// string, for the same reason `created` is nil where the write cannot answer.
    func test_aFreshCopyReportsNoDisplacedVersion() async throws {
        try write("brand new", to: left, "fresh-copy.txt")
        let items = await scanBothDirs()
        guard let row = item(items, "fresh-copy.txt") else {
            return XCTFail("the fixture produced no pair for fresh-copy.txt")
        }
        XCTAssertNil(row.rightSize, "the destination must not exist for this to be a fresh copy")
        let plan = [SyncResult(action: .copyToRight, item: row)]

        let report = await SyncExecutor.execute(plan, left: .localDir(left.path),
                                                right: .localDir(right.path), toTrash: true)
        guard case .copied(let destination) = report.outcomes.first?.status else {
            return XCTFail("expected a copy, got \(String(describing: report.outcomes.first))")
        }
        XCTAssertEqual(destination.existed, false)
        XCTAssertNil(destination.replacedTrashedPath)
    }

    // MARK: - Which deletions cannot be taken back

    /// Deleting an entry from an archive is a whole-file rewrite: there is no Trash to fish it out
    /// of, and the old bytes are gone. The warning asked `isRemote` only, so a zip side was treated
    /// as though its deletions were recoverable — measured, and it is the one case the confirmation
    /// most needed to mention, because a mistake there costs an archive rather than a file.
    func test_deletingInsideAnArchiveIsReportedAsPermanent() throws {
        let zip = root.appendingPathComponent("side.zip")
        try ZipWriter.create(at: zip, files: [(path: "a.txt", data: Data("a".utf8))])
        let item = SyncItem(relativePath: "a.txt", isDirectory: false,
                            leftSize: nil, leftModified: nil, rightSize: 1, rightModified: Date())
        XCTAssertTrue(SyncExecutor.deletesPermanently([SyncResult(action: .deleteRight, item: item)],
                                                      left: .localDir(left.path),
                                                      right: .zip(zip.path)))
        // And the side matters, as it does for a server: a delete on the *left* while the archive is
        // on the right takes a local file, and that one goes to the Trash.
        XCTAssertFalse(SyncExecutor.deletesPermanently([SyncResult(action: .deleteLeft, item: item)],
                                                       left: .localDir(left.path),
                                                       right: .zip(zip.path)))
    }

    /// And a run with nothing to delete never warns, whatever the sides are.
    func test_aRunWithNothingToDeleteNeverWarnsAboutAnArchive() throws {
        let zip = root.appendingPathComponent("side.zip")
        try ZipWriter.create(at: zip, files: [(path: "a.txt", data: Data("a".utf8))])
        let item = SyncItem(relativePath: "a.txt", isDirectory: false,
                            leftSize: 1, leftModified: Date(), rightSize: nil, rightModified: nil)
        XCTAssertFalse(SyncExecutor.deletesPermanently([SyncResult(action: .copyToRight, item: item)],
                                                       left: .localDir(left.path),
                                                       right: .zip(zip.path)))
    }

    /// A folder on this Mac keeps its Trash, so an ordinary local pair is not warned about — the
    /// warning has to stay rare enough to be read.
    func test_anOrdinaryLocalPairIsNotWarnedAbout() async throws {
        try write("gone", to: right, "c.txt")
        let items = await scanBothDirs()
        let plan = item(items, "c.txt").map { [SyncResult(action: .deleteRight, item: $0)] } ?? []
        XCTAssertFalse(SyncExecutor.deletesPermanently(plan, left: .localDir(left.path),
                                                       right: .localDir(right.path)))
    }

    // MARK: - A folder the walk could not look inside

    /// A folder this process cannot list must not be reported as looked-inside.
    ///
    /// `FileManager.enumerator(atPath:)` has no error handler: for a `chmod 000` directory it yields
    /// the folder's own name and then nothing beneath it, with no error anywhere. Measured. Unmarked,
    /// that is the walk claiming to have seen the inside of it — and `SyncSideScope.provesAbsence`
    /// then answers "this path is gone" for every file in there, which in two-way mode is the
    /// permission to carry a deletion across for a file that is really present.
    ///
    /// The remote walk has always marked a failed listing. The local one did not, while
    /// `SyncSideScope`'s own header said `incompleteDirs` covered exactly this case — a safeguard
    /// asserted in a comment and absent from the code.
    func test_aFolderThatCannotBeListedIsNotReportedAsLookedInside() async throws {
        _ = try write("really here", to: left, "secret/present.txt")
        try write("elsewhere", to: left, "plain.txt")
        let locked = left.appendingPathComponent("secret")
        try FileManager.default.setAttributes([.posixPermissions: 0o000],
                                              ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                        ofItemAtPath: locked.path) }

        let outcome = await scanBothDirsDetailed()
        // The premise: the walk really did not see the file. If it did, this test proves nothing.
        XCTAssertNil(item(outcome.items, "secret/present.txt"),
                     "the walk read the locked folder, so there is nothing here to guard against")
        XCTAssertNotNil(item(outcome.items, "secret"), "the folder itself was not even recorded")

        // The claim: the scope refuses to prove that anything inside it is gone.
        XCTAssertFalse(outcome.leftScope.provesAbsence(of: "secret/present.txt"),
                       "the walk claims a file it never looked for is absent")
        XCTAssertFalse(outcome.leftScope.provesAbsence(of: "secret/never-existed.txt"),
                       "…for any path under it, not only the one that happens to be there")
        // …and says nothing about the rest of the tree, or the guard would be useless.
        XCTAssertTrue(outcome.leftScope.provesAbsence(of: "plain-gone.txt"))
        XCTAssertTrue(outcome.leftScope.isReliable,
                      "one unreadable folder is not a reason to distrust the whole walk")
    }

    /// The mark is on the folder that could not be listed, not on the tree above it.
    ///
    /// The other way round would be worse than the defect: one unreadable folder deep in a project
    /// would stop every deletion anywhere in that project from being carried across, and the mode
    /// would quietly do nothing for the whole pair. So `a/` stays trustworthy while `a/b/` does not.
    func test_theMarkIsOnTheFolderThatCouldNotBeListedAndNotItsParents() async throws {
        _ = try write("visible", to: left, "outer/seen.txt")
        _ = try write("hidden away", to: left, "outer/inner/unseen.txt")
        let locked = left.appendingPathComponent("outer/inner")
        try FileManager.default.setAttributes([.posixPermissions: 0o000],
                                              ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                        ofItemAtPath: locked.path) }

        let outcome = await scanBothDirsDetailed()
        XCTAssertNotNil(item(outcome.items, "outer/seen.txt"), "the readable half was not walked")
        XCTAssertNil(item(outcome.items, "outer/inner/unseen.txt"), "the fixture is not locked")

        XCTAssertFalse(outcome.leftScope.provesAbsence(of: "outer/inner/unseen.txt"))
        XCTAssertFalse(outcome.leftScope.provesAbsence(of: "outer/inner/anything.txt"))
        // The branch above it cannot prove an absence either, and that is the deliberate price: an
        // *excluded* path has always marked its whole ancestor chain here, and both err towards not
        // carrying a deletion across.
        XCTAssertFalse(outcome.leftScope.provesAbsence(of: "outer/never-there.txt"))
        // Outside that branch nothing changes, or one locked folder would switch the mode off for
        // the whole pair.
        XCTAssertTrue(outcome.leftScope.provesAbsence(of: "top-level-gone.txt"))

        // Both folders are protected from a recursive delete, and the parent is the one that
        // matters: marking only `inner` left `outer` looking fully compared, so a mirror could
        // remove it and take `unseen.txt` along. The flat case cannot show that.
        XCTAssertEqual(item(outcome.items, "outer/inner")?.hasHeldBackContent, true)
        XCTAssertEqual(item(outcome.items, "outer")?.hasHeldBackContent, true,
                       "a folder holding an unlisted folder still holds something uncompared")
    }

    /// And the folder is one a mirror must not delete either, for the reason that guard already
    /// exists: deleting a folder is recursive and would take what the comparison never saw.
    func test_aFolderThatCannotBeListedCountsAsHoldingHeldBackContent() async throws {
        _ = try write("really here", to: right, "vault/present.txt")
        let locked = right.appendingPathComponent("vault")
        try FileManager.default.setAttributes([.posixPermissions: 0o000],
                                              ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                        ofItemAtPath: locked.path) }

        let outcome = await scanBothDirsDetailed()
        guard let folder = item(outcome.items, "vault") else {
            return XCTFail("the folder itself was not recorded")
        }
        XCTAssertTrue(folder.hasHeldBackContent,
                      "a folder nobody could look inside was offered for recursive deletion")
    }

    // MARK: - Which overwrites cannot be taken back

    /// The companion warning, and the reason it exists: `deletesPermanently` only ever looked at
    /// delete rows, so a copy into an archive destroyed the entry it replaced with nothing said
    /// beforehand and no trace afterwards.
    func test_replacingAnEntryInAnArchiveIsReportedAsPermanent() throws {
        let zip = root.appendingPathComponent("side.zip")
        try ZipWriter.create(at: zip, files: [(path: "a.txt", data: Data("a".utf8))])
        // Present on both sides, so the copy replaces something.
        let existing = SyncItem(relativePath: "a.txt", isDirectory: false,
                                leftSize: 2, leftModified: Date(),
                                rightSize: 1, rightModified: Date())
        XCTAssertTrue(SyncExecutor.overwritesPermanently(
            [SyncResult(action: .copyToRight, item: existing)],
            left: .localDir(left.path), right: .zip(zip.path)))
        // The other direction lands on this Mac, which keeps what it replaces.
        XCTAssertFalse(SyncExecutor.overwritesPermanently(
            [SyncResult(action: .copyToLeft, item: existing)],
            left: .localDir(left.path), right: .zip(zip.path)))
    }

    /// A copy that replaces nothing is not warned about, however unrecoverable the side is. That
    /// distinction is the whole reason this asks the item and not just the side — otherwise filling
    /// an empty archive would carry a warning about destroying something.
    func test_aCopyThatReplacesNothingIsNotWarnedAbout() throws {
        let zip = root.appendingPathComponent("side.zip")
        try ZipWriter.create(at: zip, files: [(path: "a.txt", data: Data("a".utf8))])
        let fresh = SyncItem(relativePath: "new.txt", isDirectory: false,
                            leftSize: 2, leftModified: Date(), rightSize: nil, rightModified: nil)
        XCTAssertFalse(SyncExecutor.overwritesPermanently(
            [SyncResult(action: .copyToRight, item: fresh)],
            left: .localDir(left.path), right: .zip(zip.path)))
    }

    /// And an ordinary local overwrite is not warned about, because the run now keeps the version
    /// it replaces. If that ever stopped being true this assertion would be the one that noticed.
    func test_anOrdinaryLocalOverwriteIsNotWarnedAbout() async throws {
        try write("new", to: left, "both.txt")
        try write("old", to: right, "both.txt")
        let items = await scanBothDirs()
        let plan = item(items, "both.txt").map { [SyncResult(action: .copyToRight, item: $0)] } ?? []
        XCTAssertEqual(plan.count, 1)
        XCTAssertFalse(SyncExecutor.overwritesPermanently(plan, left: .localDir(left.path),
                                                          right: .localDir(right.path)))
    }

    /// A deletion is not an overwrite. The two warnings say different things and must not both fire
    /// for one row, or the confirmation grows a paragraph nobody reads.
    func test_aDeletionDoesNotTriggerTheOverwriteWarning() throws {
        let zip = root.appendingPathComponent("side.zip")
        try ZipWriter.create(at: zip, files: [(path: "a.txt", data: Data("a".utf8))])
        let item = SyncItem(relativePath: "a.txt", isDirectory: false,
                            leftSize: nil, leftModified: nil, rightSize: 1, rightModified: Date())
        XCTAssertFalse(SyncExecutor.overwritesPermanently(
            [SyncResult(action: .deleteRight, item: item)],
            left: .localDir(left.path), right: .zip(zip.path)))
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
                                                           entry("..", .file),
                                                           entry("sub", .directory)]))
            }
            // …and a bad name *inside a folder*, which is the only place the folder-marking below
            // can be observed: an entry dropped at the root has no folder above it to account for.
            if dir.path == "/sub" {
                continuation.yield(VFSEntryBatch(entries: [entry("honest.txt", .file),
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

/// Lists files with a size and refuses every read — a share that grants listing and not reading.
private final class RefusingReadFS: VirtualFileSystem, @unchecked Sendable {
    let scheme = "refuse"
    var capabilities: VFSCapabilities { [.read] }
    private let base: String
    private let names: [String: Int]

    init(base: String, names: [String: Int]) { self.base = base; self.names = names }

    func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        AsyncThrowingStream { continuation in
            if dir.path == base {
                continuation.yield(VFSEntryBatch(entries: names.map { name, size in
                    VFSEntry(name: name, ext: "", kind: .file, size: Int64(size),
                             modified: Date(timeIntervalSince1970: 1_600_000_000), created: nil,
                             posixMode: 0o000, bsdFlags: 0, isHidden: false)
                }))
            }
            continuation.finish()
        }
    }

    func stat(_ path: VFSPath) async throws -> VFSEntry { throw VFSError.notFound(path.path) }
    func openRead(_ path: VFSPath) async throws -> VFSReadStream {
        throw VFSError.notFound(path.path)
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

/// Serves files in pieces of a chosen size and counts the bytes it actually handed over.
///
/// The count is the whole point: "did it stop early" is not answerable from the verdict, and a
/// comparison that reads both files whole gives the same verdict as one that stops at the first
/// difference.
private final class ChunkedServerFS: VirtualFileSystem, @unchecked Sendable {
    let scheme = "chunked"
    var capabilities: VFSCapabilities { [.read] }
    private let base: String
    private let files: [String: Data]
    private let pieceSize: Int
    private let lock = NSLock()
    private var _served = 0
    var served: Int { lock.lock(); defer { lock.unlock() }; return _served }

    init(base: String, files: [String: Data], pieceSize: Int) {
        self.base = base; self.files = files; self.pieceSize = pieceSize
    }

    private func count(_ n: Int) { lock.lock(); _served += n; lock.unlock() }

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

    private struct Pieces: VFSReadStream {
        typealias Element = Data
        let data: Data
        let pieceSize: Int
        let tally: @Sendable (Int) -> Void
        struct AsyncIterator: AsyncIteratorProtocol {
            let data: Data
            let pieceSize: Int
            let tally: @Sendable (Int) -> Void
            var offset = 0
            mutating func next() async throws -> Data? {
                guard offset < data.count else { return nil }
                let end = Swift.min(offset + pieceSize, data.count)
                let piece = data.subdata(in: offset..<end)
                offset = end
                tally(piece.count)
                return piece
            }
        }
        func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(data: data, pieceSize: pieceSize, tally: tally)
        }
        func close() async throws {}
    }

    private func rel(_ path: VFSPath) -> String {
        String(path.path.dropFirst(base.count).drop(while: { $0 == "/" }))
    }

    func stat(_ path: VFSPath) async throws -> VFSEntry { throw VFSError.notFound(path.path) }
    func openRead(_ path: VFSPath) async throws -> VFSReadStream {
        guard let data = files[rel(path)] else { throw VFSError.notFound(path.path) }
        return Pieces(data: data, pieceSize: pieceSize, tally: { [weak self] in self?.count($0) })
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
