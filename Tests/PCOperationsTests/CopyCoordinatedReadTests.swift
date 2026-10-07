// SPDX-License-Identifier: Apache-2.0
// CopyCoordinatedReadTests.swift - A source whose bytes arrive only when a reader coordinates.
//
// The Windows App puts files copied in a remote session on the pasteboard as placeholders: the right
// size, all zeros, and a file presenter that fetches the content over RDP when somebody asks with a
// coordinated read. Finder asks; the paste did not, cloned the placeholder in no time and left files
// of the right size with nothing in them. The presenter here stands in for the Windows App's.

import XCTest
@testable import PCOperations
import PCFoundation

private struct AbortResolver: OperationResolver {
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .overwrite }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .abort }
}

/// Fills `files` with `content` when a reader of `presentedItemURL` — the item, something inside it or
/// a folder above it — coordinates, and not before. `answers: false` is a session that has gone away.
private final class FillingPresenter: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    let presentedItemOperationQueue = OperationQueue()
    private let files: [URL], content: Data, answers: Bool
    private let lock = NSLock()
    private var asked = 0
    var timesAsked: Int { lock.lock(); defer { lock.unlock() }; return asked }

    init(presenting url: URL, fills files: [URL], with content: Data, answers: Bool = true) {
        presentedItemURL = url; self.files = files; self.content = content; self.answers = answers
    }

    func relinquishPresentedItem(toReader reader: @escaping ((() -> Void)?) -> Void) {
        lock.lock(); asked += 1; lock.unlock()
        guard answers else { return }
        for file in files { try? content.write(to: file) }
        reader(nil)
    }
}

/// Writes `content` into the placeholder in `chunks`, in place, pausing between them — a download.
/// No `fsync` between chunks: on APFS that allocates the whole sparse file at once, and the measure
/// would see everything arrive with the first chunk.
private final class TricklingPresenter: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    let presentedItemOperationQueue = OperationQueue()
    private let content: Data, chunks: Int, pause: TimeInterval

    init(file: URL, content: Data, chunks: Int, pause: TimeInterval) {
        presentedItemURL = file; self.content = content; self.chunks = chunks; self.pause = pause
    }

    func relinquishPresentedItem(toReader reader: @escaping ((() -> Void)?) -> Void) {
        guard let url = presentedItemURL, let h = try? FileHandle(forWritingTo: url) else { reader(nil); return }
        let step = content.count / chunks
        for i in 0..<chunks {
            try? h.seek(toOffset: UInt64(i * step))
            try? h.write(contentsOf: content[(i * step)..<(i == chunks - 1 ? content.count : (i + 1) * step)])
            Thread.sleep(forTimeInterval: pause)
        }
        try? h.close()
        reader(nil)
    }
}

final class CopyCoordinatedReadTests: XCTestCase {
    private var root: URL!, src: URL!, dst: URL!
    private var presenters: [FillingPresenter] = []
    private let content = Data((0..<200_000).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) })

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-cpcoord-\(UUID().uuidString)")
        src = root.appendingPathComponent("src"); dst = root.appendingPathComponent("dst")
        for d in [src!, dst!] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
    }
    override func tearDownWithError() throws {
        presenters.forEach(NSFileCoordinator.removeFilePresenter)
        try? FileManager.default.removeItem(at: root)
    }

    /// A placeholder of the content's size, all zeros, the way the Windows App leaves one.
    private func placeholder(_ url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let h = try FileHandle(forWritingTo: url)
        try h.truncate(atOffset: UInt64(content.count))
        try h.close()
    }

    @discardableResult
    private func present(_ url: URL, fills files: URL..., answers: Bool = true) -> FillingPresenter {
        let p = FillingPresenter(presenting: url, fills: files, with: content, answers: answers)
        NSFileCoordinator.addFilePresenter(p)
        presenters.append(p)
        return p
    }

    /// Clone left on: on the same volume that is the path the paste took, and the instant one.
    private func copy(_ item: URL, coordinate: Bool, control: OperationControl = OperationControl()) async throws {
        var o = CopyOptions()
        o.coordinateSourceReads = coordinate
        let engine = CopyEngine(options: o, control: control, resolver: AbortResolver(), progress: { _ in })
        try await engine.run(items: [item.path], toDirectory: dst.path)
    }

    /// The defect as it was: an uncoordinated copy takes the placeholder for the file.
    func testUncoordinatedCopyGetsThePlaceholder() async throws {
        let file = src.appendingPathComponent("remote.bin")
        try placeholder(file)
        present(file, fills: file)
        try await copy(file, coordinate: false)
        let copied = try Data(contentsOf: dst.appendingPathComponent("remote.bin"))
        XCTAssertEqual(copied.count, content.count)
        XCTAssertTrue(copied.allSatisfy { $0 == 0 })
    }

    func testCoordinatedCopyWaitsForThePresenter() async throws {
        let file = src.appendingPathComponent("remote.bin")
        try placeholder(file)
        present(file, fills: file)
        try await copy(file, coordinate: true)
        XCTAssertEqual(try Data(contentsOf: dst.appendingPathComponent("remote.bin")), content)
    }

    /// A presenter of the folder only — the pasted item is the folder, the placeholder is inside it.
    func testCoordinatedCopyAsksThePresenterOfTheFolder() async throws {
        let folder = src.appendingPathComponent("Ordner")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("remote.bin")
        try placeholder(file)
        present(folder, fills: file)
        try await copy(folder, coordinate: true)
        XCTAssertEqual(try Data(contentsOf: dst.appendingPathComponent("Ordner/remote.bin")), content)
    }

    /// A presenter of each file and none of the folder — the pasted item is the folder. A read of the
    /// folder does not reach the presenters inside it, so each file has to be read coordinated.
    func testCoordinatedCopyOfAFolderReachesThePresentersInsideIt() async throws {
        let folder = src.appendingPathComponent("Ordner")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let names = ["a.bin", "b.bin"]
        for name in names {
            let file = folder.appendingPathComponent(name)
            try placeholder(file)
            present(file, fills: file)
        }
        try await copy(folder, coordinate: true)
        for name in names {
            XCTAssertEqual(try Data(contentsOf: dst.appendingPathComponent("Ordner/\(name)")), content, name)
        }
    }

    /// A presenter that fetches on every request must be asked once for a folder, not once per file
    /// in it: the reads of the files inside must not ask the folder's presenter again.
    func testThePresenterOfAPastedFolderIsAskedOnce() async throws {
        let folder = src.appendingPathComponent("Ordner")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let files = (0..<20).map { folder.appendingPathComponent("f\($0).bin") }
        for file in files { try placeholder(file) }
        let p = FillingPresenter(presenting: folder, fills: files, with: content)
        NSFileCoordinator.addFilePresenter(p)
        presenters.append(p)
        try await copy(folder, coordinate: true)
        XCTAssertEqual(p.timesAsked, 1)
        for file in files {
            XCTAssertEqual(try Data(contentsOf: dst.appendingPathComponent("Ordner/\(file.lastPathComponent)")), content)
        }
    }

    /// A remote session that has gone away never answers. Stop has to end the copy anyway.
    func testStopEndsACopyWhosePresenterNeverAnswers() async throws {
        let file = src.appendingPathComponent("remote.bin")
        try placeholder(file)
        present(file, fills: file, answers: false)
        let control = OperationControl()
        Task { try? await Task.sleep(nanoseconds: 300_000_000); await control.cancel() }
        let started = Date()
        do {
            try await copy(file, coordinate: true, control: control)
            XCTFail("a copy that was stopped must not finish")
        } catch let error as OperationError {
            XCTAssertEqual(error, .cancelled)
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dst.appendingPathComponent("remote.bin").path))
    }

    /// The wait is where a paste from a remote session spends its time, and the copy after it is a
    /// clone — so a bar fed only by bytes stood at 0 % and jumped to 100 %. The wait is reported as one,
    /// with what the placeholder lacks as the part of the bar it fills.
    func testTheWaitForAPresenterIsReportedAsAWait() async throws {
        let file = src.appendingPathComponent("remote.bin")
        try placeholder(file)
        present(file, fills: file)
        let lock = NSLock()
        var reports: [OpProgress] = []
        var o = CopyOptions()
        o.coordinateSourceReads = true
        let engine = CopyEngine(options: o, control: OperationControl(), resolver: AbortResolver(),
                                progress: { p in lock.lock(); reports.append(p); lock.unlock() })
        try await engine.run(items: [file.path], toDirectory: dst.path)
        lock.lock(); defer { lock.unlock() }
        XCTAssertTrue(reports.contains {
            $0.isWaitingForSource && $0.currentItem == "remote.bin" && $0.bytesToReceive == Int64(content.count)
        })
        XCTAssertEqual(reports.last?.isWaitingForSource, false)
        XCTAssertEqual(reports.last?.isIndeterminate, false)
        XCTAssertEqual(reports.last?.fraction, 1)
    }

    /// A presenter that takes its time and writes into the placeholder as the content arrives, the
    /// way the Windows App was measured to. The bar has to move during the wait, and never backwards.
    func testTheBarFollowsTheDeliveryAndNeverRunsBackwards() async throws {
        let file = src.appendingPathComponent("remote.bin")
        let big = Data((0..<(4 << 20)).map { UInt8(truncatingIfNeeded: $0 &* 13) })
        FileManager.default.createFile(atPath: file.path, contents: nil)
        let h = try FileHandle(forWritingTo: file)
        try h.truncate(atOffset: UInt64(big.count))
        try h.close()
        let p = TricklingPresenter(file: file, content: big, chunks: 8, pause: 0.25)
        NSFileCoordinator.addFilePresenter(p)
        defer { NSFileCoordinator.removeFilePresenter(p) }

        let lock = NSLock()
        var reports: [OpProgress] = []
        var o = CopyOptions()
        o.coordinateSourceReads = true
        let engine = CopyEngine(options: o, control: OperationControl(), resolver: AbortResolver(),
                                progress: { p in lock.lock(); reports.append(p); lock.unlock() })
        try await engine.run(items: [file.path], toDirectory: dst.path)

        XCTAssertEqual(try Data(contentsOf: dst.appendingPathComponent("remote.bin")), big)
        lock.lock(); defer { lock.unlock() }
        let waiting = reports.filter(\.isWaitingForSource)
        XCTAssertTrue(waiting.contains { $0.bytesReceived > 0 && $0.bytesReceived < $0.bytesToReceive },
                      "the bar did not move while the content arrived")
        let fractions = reports.filter { !$0.isIndeterminate }.map(\.fraction)
        XCTAssertEqual(fractions, fractions.sorted(), "the bar ran backwards")
        XCTAssertEqual(reports.last?.fraction, 1)
    }
}
