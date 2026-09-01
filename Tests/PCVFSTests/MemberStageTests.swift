// SPDX-License-Identifier: Apache-2.0
// MemberStageTests.swift - A real file for something that is not one yet (F-479).
//
// The counting filesystem below is the point of most of these: the defect being fixed is not "there
// is no extraction" — `localFileIfAvailable` has always extracted — it is that every surface asking
// paid again, and that nothing decided when the result went away.

import XCTest
@testable import PCFoundation
@testable import PCVFS

/// A filesystem of files held in memory, which counts how often each one is actually read.
private final class CountingFS: VirtualFileSystem, @unchecked Sendable {
    let scheme = "counting"
    var capabilities: VFSCapabilities { [.read, .localExtraction] }

    private let files: [String: Data]
    private let chunkDelay: Duration
    private let lock = NSLock()
    private(set) var reads: [String: Int] = [:]

    init(files: [String: Data], chunkDelay: Duration = .zero) {
        self.files = files
        self.chunkDelay = chunkDelay
    }

    func readCount(_ path: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return reads[path] ?? 0
    }

    func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func stat(_ path: VFSPath) async throws -> VFSEntry {
        guard let data = files[path.path] else { throw VFSError.notFound(path.path) }
        return VFSEntry(name: (path.path as NSString).lastPathComponent, ext: "", kind: .file,
                        size: Int64(data.count), modified: Date())
    }

    func openRead(_ path: VFSPath) async throws -> VFSReadStream {
        guard let data = files[path.path] else { throw VFSError.notFound(path.path) }
        lock.lock()
        reads[path.path, default: 0] += 1
        lock.unlock()
        return MemoryReadStream(data: data, delay: chunkDelay)
    }

    func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream {
        throw VFSError.unsupported
    }
    func mkdir(_ path: VFSPath) async throws { throw VFSError.unsupported }
    func delete(_ path: VFSPath) async throws { throw VFSError.unsupported }
    func rename(_ from: VFSPath, to: VFSPath) async throws { throw VFSError.unsupported }
    func setAttributes(_ path: VFSPath, attributes: VFSAttributes) async throws { throw VFSError.unsupported }
    func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>? { nil }
    func localFileIfAvailable(_ path: VFSPath) async throws -> URL? { nil }
}

private final class MemoryReadStream: VFSReadStream, @unchecked Sendable {
    typealias Element = Data
    private var chunks: [Data]
    fileprivate let delay: Duration
    init(data: Data, chunk: Int = 64 * 1024, delay: Duration = .zero) {
        self.delay = delay
        var built: [Data] = []
        var offset = data.startIndex
        while offset < data.endIndex {
            let end = data.index(offset, offsetBy: chunk, limitedBy: data.endIndex) ?? data.endIndex
            built.append(data.subdata(in: offset..<end))
            offset = end
        }
        chunks = built
    }
    func close() async throws {}
    func makeAsyncIterator() -> AsyncIterator { AsyncIterator(stream: self) }
    fileprivate func next() -> Data? { chunks.isEmpty ? nil : chunks.removeFirst() }
    struct AsyncIterator: AsyncIteratorProtocol {
        let stream: MemoryReadStream
        func next() async -> Data? {
            if stream.delay > .zero { try? await Task.sleep(for: stream.delay) }
            return stream.next()
        }
    }
}

final class MemberStageTests: XCTestCase {

    private var stage: MemberStage!

    override func setUp() {
        super.setUp()
        stage = MemberStage()
    }

    override func tearDown() async throws {
        await stage.removeAll()
        try await super.tearDown()
    }

    private func fs(_ files: [String: Int]) -> CountingFS {
        CountingFS(files: files.mapValues { Data(repeating: 0x41, count: $0) })
    }

    private func path(_ p: String) -> VFSPath { VFSPath(filesystemId: "counting", path: p) }

    // MARK: - The file that comes out

    func testTheStagedFileKeepsTheMembersOwnName() async throws {
        // Quick Look and NSWorkspace decide the type from the extension: a copy called "1" opens in
        // nothing, which is the whole reason for a directory per member.
        let fs = self.fs(["/xl/sheet.xlsx": 2048])
        let staged = try await stage.stage(path("/xl/sheet.xlsx"), on: fs, mountKey: "m",
                                           bytes: 2048, purpose: .preview)
        XCTAssertEqual(staged.url.lastPathComponent, "sheet.xlsx")
        XCTAssertTrue(staged.isCopy)
        XCTAssertEqual(try Data(contentsOf: staged.url).count, 2048)
    }

    func testTwoMembersOfTheSameNameDoNotCollide() async throws {
        let fs = self.fs(["/a/notes.txt": 100, "/b/notes.txt": 200])
        let first = try await stage.stage(path("/a/notes.txt"), on: fs, mountKey: "m",
                                          bytes: 100, purpose: .preview)
        let second = try await stage.stage(path("/b/notes.txt"), on: fs, mountKey: "m",
                                           bytes: 200, purpose: .preview)
        XCTAssertNotEqual(first.url, second.url)
        XCTAssertEqual(try Data(contentsOf: first.url).count, 100)
        XCTAssertEqual(try Data(contentsOf: second.url).count, 200)
    }

    // MARK: - Asking twice

    func testAskingTwiceExtractsOnce() async throws {
        // The defect: the info page and Quick View both follow the cursor, and F3 after them, and
        // each call decompressed the member again.
        let fs = self.fs(["/big.bin": 4096])
        _ = try await stage.stage(path("/big.bin"), on: fs, mountKey: "m", bytes: 4096, purpose: .preview)
        _ = try await stage.stage(path("/big.bin"), on: fs, mountKey: "m", bytes: 4096, purpose: .preview)
        XCTAssertEqual(fs.readCount("/big.bin"), 1)
    }

    func testTwoSimultaneousRequestsShareOneExtraction() async throws {
        let fs = self.fs(["/big.bin": 512 * 1024])
        async let a = stage.stage(path("/big.bin"), on: fs, mountKey: "m", bytes: 512 * 1024, purpose: .preview)
        async let b = stage.stage(path("/big.bin"), on: fs, mountKey: "m", bytes: 512 * 1024, purpose: .preview)
        let (first, second) = try await (a, b)
        XCTAssertEqual(first.url, second.url)
        XCTAssertEqual(fs.readCount("/big.bin"), 1)
    }

    func testARewrittenArchiveIsNotServedFromTheOldCache() async throws {
        // The mount key carries the archive's identity; a different one is a different file.
        let fs = self.fs(["/a.txt": 10])
        _ = try await stage.stage(path("/a.txt"), on: fs, mountKey: "stamp-1", bytes: 10, purpose: .preview)
        _ = try await stage.stage(path("/a.txt"), on: fs, mountKey: "stamp-2", bytes: 10, purpose: .preview)
        XCTAssertEqual(fs.readCount("/a.txt"), 2)
    }

    // MARK: - The ceiling

    func testAMemberOverTheLimitIsRefusedBeforeAnythingIsRead() async throws {
        let fs = self.fs(["/huge.bin": 4096])
        do {
            _ = try await stage.stage(path("/huge.bin"), on: fs, mountKey: "m", bytes: 4096,
                                      purpose: .preview, limitBytes: 1024)
            XCTFail("a member over the ceiling must be refused")
        } catch let error as MemberStageError {
            XCTAssertEqual(error, .tooLarge(bytes: 4096, limit: 1024))
        }
        XCTAssertEqual(fs.readCount("/huge.bin"), 0, "refused means not read, not read-then-discarded")
    }

    // MARK: - Names that try to leave

    func testAMemberThatWouldEscapeTheStagingRootIsRefused() async throws {
        // The oldest trick in the format, and the staging root is a directory nobody chose — so the
        // same rule the extractor applies, applied here.
        let fs = CountingFS(files: ["/sub/..": Data(repeating: 0, count: 8)])
        do {
            _ = try await stage.stage(path("/sub/.."), on: fs, mountKey: "m", bytes: 8, purpose: .preview)
            XCTFail("a name that leaves the root must be refused")
        } catch let error as MemberStageError {
            guard case .refusedName = error else { return XCTFail("wrong error: \(error)") }
        }
    }

    // MARK: - Two lifetimes

    func testLeavingTheMountDropsPreviewsAndKeepsWhatWasHandedToAnotherApp() async throws {
        let fs = self.fs(["/preview.png": 100, "/opened.xlsx": 200])
        let preview = try await stage.stage(path("/preview.png"), on: fs, mountKey: "m",
                                            bytes: 100, purpose: .preview)
        let handoff = try await stage.stage(path("/opened.xlsx"), on: fs, mountKey: "m",
                                            bytes: 200, purpose: .handoff)
        await stage.releasePreviews(mountKey: "m")
        XCTAssertFalse(FileManager.default.fileExists(atPath: preview.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: handoff.url.path),
                      "the application it was handed to still has it open")
    }

    func testAnotherMountsPreviewsAreLeftAlone() async throws {
        let fs = self.fs(["/a.txt": 10])
        let mine = try await stage.stage(path("/a.txt"), on: fs, mountKey: "mine", bytes: 10, purpose: .preview)
        await stage.releasePreviews(mountKey: "other")
        XCTAssertTrue(FileManager.default.fileExists(atPath: mine.url.path))
    }

    func testAPinnedPreviewSurvivesTheMountItCameFrom() async throws {
        // Quick Look is still showing it; deleting the file underneath an open panel is worse than
        // keeping it a moment longer.
        let fs = self.fs(["/shown.png": 100])
        let shown = try await stage.stage(path("/shown.png"), on: fs, mountKey: "m", bytes: 100, purpose: .preview)
        await stage.pin(shown.url)
        await stage.releasePreviews(mountKey: "m")
        XCTAssertTrue(FileManager.default.fileExists(atPath: shown.url.path))
        await stage.unpin(shown.url)
        await stage.releasePreviews(mountKey: "m")
        XCTAssertFalse(FileManager.default.fileExists(atPath: shown.url.path))
    }

    func testACopyTheAppWillEditSurvivesTheMountAndStaysWritable() async throws {
        // The case that made a third purpose necessary: F4 on a writable network mount writes this
        // copy and uploads it back on save (F-214). A `.preview` copy is deleted when the panel
        // leaves the mount — the editor would then be holding a path that is gone — and a
        // `.handoff` copy is 0444, so it could not be written at all.
        let fs = self.fs(["/notes.txt": 64])
        let editing = try await stage.stage(path("/notes.txt"), on: fs, mountKey: "m",
                                            bytes: 64, purpose: .editing)
        await stage.releasePreviews(mountKey: "m")
        XCTAssertTrue(FileManager.default.fileExists(atPath: editing.url.path))
        let mode = try FileManager.default.attributesOfItem(atPath: editing.url.path)[.posixPermissions] as? Int
        XCTAssertNotEqual(mode, 0o444, "the editor has to be able to write it")
        XCTAssertNoThrow(try Data("edited".utf8).write(to: editing.url))
    }

    func testACopyTheAppWillEditIsNeverEvicted() async throws {
        let fs = self.fs(["/doc.txt": 32])
        let editing = try await stage.stage(path("/doc.txt"), on: fs, mountKey: "m",
                                            bytes: 32, purpose: .editing)
        await stage.dropEvictablePreviews()
        XCTAssertTrue(FileManager.default.fileExists(atPath: editing.url.path))
    }

    func testAPreviewPromotedToAnEditIsNotDemotedAgain() async throws {
        // The preview and the editor look at the same file in that order all the time.
        let fs = self.fs(["/doc.txt": 32])
        _ = try await stage.stage(path("/doc.txt"), on: fs, mountKey: "m", bytes: 32, purpose: .preview)
        let editing = try await stage.stage(path("/doc.txt"), on: fs, mountKey: "m", bytes: 32, purpose: .editing)
        _ = try await stage.stage(path("/doc.txt"), on: fs, mountKey: "m", bytes: 32, purpose: .preview)
        await stage.releasePreviews(mountKey: "m")
        XCTAssertTrue(FileManager.default.fileExists(atPath: editing.url.path))
        XCTAssertEqual(fs.readCount("/doc.txt"), 1)
    }

    // MARK: - The budget must not undo the work it was asked for

    func testAMemberBiggerThanTheWholeBudgetIsStillHandedOver() async throws {
        // Found by driving the app: Cmd+Y on a 400 MB member reported "nothing here could be
        // unpacked" *every time*. The extraction had worked — and then the eviction that runs
        // straight after deleted the only entry there was, because one file was over the byte
        // budget by itself. The caller was handed a path to a file that no longer existed.
        let small = MemberStage(maxEntries: 64, maxRetainedBytes: 1024)
        defer { Task { await small.removeAll() } }
        let fs = self.fs(["/huge.bin": 8192])
        let staged = try await small.stage(path("/huge.bin"), on: fs, mountKey: "m",
                                           bytes: 8192, purpose: .preview)
        XCTAssertTrue(FileManager.default.fileExists(atPath: staged.url.path),
                      "the staging deleted the file it had just produced")
        XCTAssertEqual(try Data(contentsOf: staged.url).count, 8192)
    }

    func testTheOldestIsStillEvictedOnceSomethingElseIsStaged() async throws {
        // The protection is for the entry being handed over, not a general exemption: the next
        // staging must still bring the budget back down.
        let small = MemberStage(maxEntries: 64, maxRetainedBytes: 1024)
        defer { Task { await small.removeAll() } }
        let fs = self.fs(["/a.bin": 4096, "/b.bin": 4096])
        let first = try await small.stage(path("/a.bin"), on: fs, mountKey: "m", bytes: 4096, purpose: .preview)
        let second = try await small.stage(path("/b.bin"), on: fs, mountKey: "m", bytes: 4096, purpose: .preview)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.url.path))
    }

    func testTheEntryCountBudgetAlsoSparesTheFreshEntry() async throws {
        let small = MemberStage(maxEntries: 1, maxRetainedBytes: 0)
        defer { Task { await small.removeAll() } }
        let fs = self.fs(["/a.txt": 10, "/b.txt": 10])
        _ = try await small.stage(path("/a.txt"), on: fs, mountKey: "m", bytes: 10, purpose: .preview)
        let second = try await small.stage(path("/b.txt"), on: fs, mountKey: "m", bytes: 10, purpose: .preview)
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.url.path))
    }

    // MARK: - The byte budget must describe what is actually held

    func testReStagingAFileThatVanishedDoesNotCountItTwice() async throws {
        // The staged copy can go without the stage being told — the OS reaping the temp directory,
        // or a second in-flight extraction finishing after the first caller gave up. Overwriting the
        // entry without dropping it left `retained` too high for the rest of the session, so the
        // budget evicted early, and left the replaced directory behind.
        let fs = self.fs(["/a.bin": 4096])
        let first = try await stage.stage(path("/a.bin"), on: fs, mountKey: "m", bytes: 4096, purpose: .preview)
        try FileManager.default.removeItem(at: first.url)
        let second = try await stage.stage(path("/a.bin"), on: fs, mountKey: "m", bytes: 4096, purpose: .preview)
        let report = await stage.report()
        XCTAssertEqual(report.files, 1)
        XCTAssertEqual(report.bytes, 4096, "one file staged, one file's worth of budget")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: first.url.deletingLastPathComponent().path), "the replaced directory stayed behind")
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.url.path))
    }

    func testTheReportSeparatesWhatTheBudgetGovernsFromWhatItDoesNot() async throws {
        // The 256 MB budget bounds the evictable half only: a copy another application has open is
        // not the stage's to reclaim, and one number for both would have hidden that.
        let fs = self.fs(["/p.png": 100, "/h.xlsx": 200, "/e.txt": 400])
        _ = try await stage.stage(path("/p.png"), on: fs, mountKey: "m", bytes: 100, purpose: .preview)
        _ = try await stage.stage(path("/h.xlsx"), on: fs, mountKey: "m", bytes: 200, purpose: .handoff)
        _ = try await stage.stage(path("/e.txt"), on: fs, mountKey: "m", bytes: 400, purpose: .editing)
        let report = await stage.report()
        XCTAssertEqual(report.files, 3)
        XCTAssertEqual(report.bytes, 700)
        XCTAssertEqual(report.evictable, 100)
        XCTAssertEqual(report.kept, 600)
    }

    func testACopyHandedToAnotherApplicationIsReadOnly() async throws {
        // Nothing writes an edited copy back into an archive yet. An application that says "read
        // only" at the top has told the user; one that saves into a temp file has not.
        let fs = self.fs(["/opened.xlsx": 64])
        let handoff = try await stage.stage(path("/opened.xlsx"), on: fs, mountKey: "m",
                                            bytes: 64, purpose: .handoff)
        let attributes = try FileManager.default.attributesOfItem(atPath: handoff.url.path)
        XCTAssertEqual(attributes[.posixPermissions] as? Int, 0o444)
    }

    func testAPreviewPromotedToAHandoffStopsBeingEvictable() async throws {
        let fs = self.fs(["/f.pdf": 100])
        _ = try await stage.stage(path("/f.pdf"), on: fs, mountKey: "m", bytes: 100, purpose: .preview)
        let handoff = try await stage.stage(path("/f.pdf"), on: fs, mountKey: "m", bytes: 100, purpose: .handoff)
        await stage.releasePreviews(mountKey: "m")
        XCTAssertTrue(FileManager.default.fileExists(atPath: handoff.url.path))
        XCTAssertEqual(fs.readCount("/f.pdf"), 1, "promotion must not re-extract")
    }

    // MARK: - Measurement

    func testAStagedReadTeachesTheThroughputEstimator() async throws {
        // Without this the budget never learns how fast a mount is and judges every preview by the
        // conservative fallback for the whole session.
        TransferRateEstimator.shared.forget(key: "measured-mount")
        // A read that costs nothing teaches nothing (the estimator refuses it on purpose), so the
        // filesystem here takes a little time per chunk the way a real one does.
        let fs = CountingFS(files: ["/big.bin": Data(repeating: 0x41, count: 2 * 1024 * 1024)],
                            chunkDelay: .milliseconds(1))
        _ = try await stage.stage(path("/big.bin"), on: fs, mountKey: "measured-mount",
                                  bytes: 2 * 1024 * 1024, purpose: .preview)
        XCTAssertNotNil(TransferRateEstimator.shared.rate(for: "measured-mount"))
        TransferRateEstimator.shared.forget(key: "measured-mount")
    }

    // MARK: - Housekeeping

    func testEverythingIsGoneAfterRemoveAll() async throws {
        let fs = self.fs(["/a.txt": 10, "/b.txt": 10])
        let a = try await stage.stage(path("/a.txt"), on: fs, mountKey: "m", bytes: 10, purpose: .preview)
        let b = try await stage.stage(path("/b.txt"), on: fs, mountKey: "m", bytes: 10, purpose: .handoff)
        await stage.removeAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: a.url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: b.url.path))
        let report = await stage.report()
        XCTAssertEqual(report.files, 0)
        XCTAssertEqual(report.bytes, 0)
    }

    func testTheRootCarriesThisProcessId() async throws {
        // What lets a later launch tell a leftover from a live session's files without waiting a day.
        let fs = self.fs(["/a.txt": 10])
        let staged = try await stage.stage(path("/a.txt"), on: fs, mountKey: "m", bytes: 10, purpose: .preview)
        let root = staged.url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
        XCTAssertTrue(root.hasPrefix("\(MemberStage.prefix)\(getpid())-"), root)
    }
}
