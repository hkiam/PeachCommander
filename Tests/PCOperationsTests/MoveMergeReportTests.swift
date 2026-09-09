// SPDX-License-Identifier: Apache-2.0
// MoveMergeReportTests.swift - A move that merged says which items it merged.
//
// `run` answers the source paths it processed, and the panel reads that as "these were moved here"
// — then offers to move them back. For an `.append` (F-086) that reading is wrong in a way that
// destroys something: the source is concatenated onto an existing file and then removed, so the
// source path is *free*, the occupancy guard in the undo does not fire, and moving the target back
// puts merged content at the old path and takes the target with it. A wrong inverse is worse than
// none, which is the rule this stack already follows for a conflict auto-rename.

import XCTest
@testable import PCOperations
import PCFoundation

/// Always answers a target-exists conflict with `.append`, as the overwrite dialog's "Append"
/// button does.
private struct AlwaysAppend: OperationResolver {
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .append }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .abort }
}

/// Always overwrites, for the control: an overwrite really *is* a move, and must not be reported as
/// merged or the undo would stop being offered for the ordinary case.
private struct AlwaysOverwrite: OperationResolver {
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .overwrite }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .abort }
}

final class MoveMergeReportTests: XCTestCase {
    private var root: URL!, src: URL!, dst: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-mergerep-\(UUID().uuidString)")
        src = root.appendingPathComponent("src"); dst = root.appendingPathComponent("dst")
        for d in [src!, dst!] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    private func write(_ text: String, _ url: URL) throws {
        try Data(text.utf8).write(to: url)
    }

    /// The claim: an appended item is named, and the state that makes the wrong undo possible is
    /// asserted alongside it — the target holds merged bytes and the source path is free.
    func test_anAppendedItemIsReportedAsMerged() async throws {
        let source = src.appendingPathComponent("log.txt")
        let target = dst.appendingPathComponent("log.txt")
        try write("AAA", source)
        try write("BBB", target)

        let engine = MoveEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: AlwaysAppend(), progress: { _ in })
        let processed = try await engine.run(items: [source.path], toDirectory: dst.path)

        XCTAssertEqual(processed, [source.path], "the operation happened, so it is processed")
        XCTAssertEqual(engine.merged, [source.path], "the merge was not reported")
        // The two facts that together make the naive undo destructive.
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "BBBAAA")
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path),
                       "the source path is free, so an occupancy guard cannot catch this")
    }

    /// An **overwrite** is a move and must not be reported as merged, or the undo would stop being
    /// offered for the ordinary collision. The control that keeps the first assertion meaningful.
    func test_anOverwrittenItemIsNotReportedAsMerged() async throws {
        let source = src.appendingPathComponent("log.txt")
        let target = dst.appendingPathComponent("log.txt")
        try write("AAA", source)
        try write("BBB", target)

        let engine = MoveEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: AlwaysOverwrite(), progress: { _ in })
        let processed = try await engine.run(items: [source.path], toDirectory: dst.path)

        XCTAssertEqual(processed, [source.path])
        XCTAssertTrue(engine.merged.isEmpty, "an overwrite was reported as a merge")
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "AAA")
    }

    /// A plain move, with nothing in the way, reports no merge at all.
    func test_aPlainMoveReportsNoMerge() async throws {
        let source = src.appendingPathComponent("fresh.txt")
        try write("AAA", source)

        let engine = MoveEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: AlwaysAppend(), progress: { _ in })
        _ = try await engine.run(items: [source.path], toDirectory: dst.path)
        XCTAssertTrue(engine.merged.isEmpty)
    }

    /// And the queue hands it on, which is the half the panel depends on. Two entry points had to
    /// be threaded separately for the Trash sink; this checks the one the panel uses.
    func test_theQueueReportsTheMerge() async throws {
        let source = src.appendingPathComponent("log.txt")
        try write("AAA", source)
        try write("BBB", dst.appendingPathComponent("log.txt"))

        final class Box: @unchecked Sendable {
            private let lock = NSLock()
            private(set) var paths: [String] = []
            func add(_ p: [String]) { lock.lock(); paths += p; lock.unlock() }
        }
        let box = Box()
        let queue = TransferQueue()
        queue.mergedSink = { [box] in box.add($0) }

        for await event in queue.run(.move(items: [source.path], toDirectory: dst.path,
                                           options: CopyOptions()),
                                     resolver: AlwaysAppend()) {
            if case .failed(let error) = event { return XCTFail("\(error)") }
        }
        XCTAssertEqual(box.paths, [source.path], "the queue did not pass the merge on")
    }
}
