// SPDX-License-Identifier: Apache-2.0
// TrashSinkTests.swift - The queue hands over where each trashed item went.
//
// Delete was the one operation with no undo anywhere in this app, and the reason was that the
// information needed for one was thrown away twice: `trashItem`'s resulting URL, and then the
// queue's own result, which reduced everything to source paths. This pins the second half.
//
// Real trashing, into the user's Trash, because that is the thing under test and a fake cannot
// report a resulting URL. Each test cleans up after itself.

import XCTest
@testable import PCOperations
import PCFoundation

private final class Collector: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var items: [TrashedItem] = []
    func sink() -> @Sendable ([TrashedItem]) -> Void {
        { [self] batch in lock.lock(); items.append(contentsOf: batch); lock.unlock() }
    }
}

final class TrashSinkTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-trashsink-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func file(_ name: String, _ text: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url
    }

    /// The pairs come out, and the reported path really holds that file — compared as bytes,
    /// because a path that exists proves only that something is there, and the Trash renames on
    /// collision so the name cannot answer it.
    func test_theQueueReportsWhereEachTrashedItemWent() async throws {
        let one = try file("sink-one.txt", "first")
        let two = try file("sink-two.txt", "second")
        let collector = Collector()
        let queue = TransferQueue()
        queue.trashSink = collector.sink()

        let processed = try await queue.runToCompletion(.trash(items: [one.path, two.path]))

        XCTAssertEqual(Set(processed), [one.path, two.path])
        XCTAssertEqual(collector.items.count, 2)
        defer {
            for item in collector.items {
                if let path = item.trashedPath { try? FileManager.default.removeItem(atPath: path) }
            }
        }
        for item in collector.items {
            guard let landed = item.trashedPath else {
                return XCTFail("\(item.originalPath) reported no destination")
            }
            let expected = item.originalPath == one.path ? "first" : "second"
            XCTAssertEqual(try String(contentsOfFile: landed, encoding: .utf8), expected,
                           "the reported path does not hold that item")
            XCTAssertFalse(FileManager.default.fileExists(atPath: item.originalPath))
        }
    }

    /// A permanent delete reports nothing, because there is nowhere it could have gone. A pair for
    /// something that was destroyed would be worse than none: an undo built on it would find
    /// nothing and say it had restored a file.
    func test_aPermanentDeleteReportsNothing() async throws {
        let gone = try file("sink-gone.txt", "destroyed")
        let collector = Collector()
        let queue = TransferQueue()
        queue.trashSink = collector.sink()

        _ = try await queue.runToCompletion(.delete(items: [gone.path]))

        XCTAssertTrue(collector.items.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: gone.path))
    }

    /// And a caller that does not ask pays nothing — the ordinary delete is unchanged.
    func test_nothingIsReportedWhenNobodyAsked() async throws {
        let one = try file("sink-quiet.txt", "quiet")
        let processed = try await TransferQueue().runToCompletion(.trash(items: [one.path]))
        XCTAssertEqual(processed, [one.path])
        // Clean up by name; without a sink this test cannot know where it went, which is the whole
        // point of the sink existing.
        let byName = (NSHomeDirectory() as NSString).appendingPathComponent(".Trash/sink-quiet.txt")
        try? FileManager.default.removeItem(atPath: byName)
    }

    /// The stream path reports too, not only `runToCompletion`. Two entry points, one of which had
    /// to be threaded separately — and the panel uses this one.
    func test_theStreamingPathReportsAsWell() async throws {
        let one = try file("sink-stream.txt", "streamed")
        let collector = Collector()
        let queue = TransferQueue()
        queue.trashSink = collector.sink()

        for await event in queue.run(.trash(items: [one.path])) {
            if case .failed(let error) = event { return XCTFail("\(error)") }
        }
        XCTAssertEqual(collector.items.count, 1, "the streaming path reported nothing")
        if let path = collector.items.first?.trashedPath {
            defer { try? FileManager.default.removeItem(atPath: path) }
            XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "streamed")
        } else {
            XCTFail("no destination reported")
        }
    }
}
