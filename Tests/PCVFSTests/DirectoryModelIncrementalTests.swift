// SPDX-License-Identifier: Apache-2.0
// DirectoryModelIncrementalTests.swift - Partial listings, and the two ways they can go wrong.
//
// `VirtualFileSystem.list` has yielded batches since I08 — 4096 at a time from LocalFS, 128 from a
// plugin mount — and `DirectoryModel.load` collected every one of them before answering, so a bucket
// with fifty thousand objects showed an empty panel until the last page arrived. The streaming was
// there; only the middle threw it away.
//
// Tested here rather than through a panel because the interesting cases are about *ordering and
// state*, not about drawing: that a partial is sorted like the real thing, that the model does not
// commit until the end, and that two overlapping loads cannot appear as one list.

import XCTest
@testable import PCVFS

/// A filesystem that yields exactly the batches a test asks for.
private final class ScriptedFS: VirtualFileSystem, @unchecked Sendable {
    let scheme = "scripted"
    let capabilities: VFSCapabilities = [.read]

    private let batches: [[String]]
    private let failAfter: Int?
    /// Lets a test interleave a second load between two batches.
    private let betweenBatches: (@Sendable (Int) async -> Void)?

    init(batches: [[String]], failAfter: Int? = nil,
         betweenBatches: (@Sendable (Int) async -> Void)? = nil) {
        self.batches = batches
        self.failAfter = failAfter
        self.betweenBatches = betweenBatches
    }

    func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        AsyncThrowingStream { continuation in
            Task { [batches, failAfter, betweenBatches] in
                for (index, names) in batches.enumerated() {
                    if let failAfter, index == failAfter {
                        continuation.finish(throwing: VFSError.connectionLost(retryable: false))
                        return
                    }
                    let entries = names.map {
                        VFSEntry(name: $0, ext: "", kind: .file, size: 1, modified: Date())
                    }
                    continuation.yield(VFSEntryBatch(entries: entries,
                                                     isLastBatch: index == batches.count - 1))
                    await betweenBatches?(index)
                }
                continuation.finish()
            }
        }
    }

    func stat(_ path: VFSPath) async throws -> VFSEntry { throw VFSError.unsupported }
    func openRead(_ path: VFSPath) async throws -> VFSReadStream { throw VFSError.unsupported }
    func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream {
        throw VFSError.unsupported
    }
    func mkdir(_ path: VFSPath) async throws { throw VFSError.unsupported }
    func delete(_ path: VFSPath) async throws { throw VFSError.unsupported }
    func rename(_ from: VFSPath, to: VFSPath) async throws { throw VFSError.unsupported }
    func setAttributes(_ path: VFSPath, attributes: VFSAttributes) async throws {
        throw VFSError.unsupported
    }
    func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>? { nil }
    func localFileIfAvailable(_ path: VFSPath) async throws -> URL? { nil }
}

/// Collects partial snapshots. Locked: they arrive on the model's actor, the test reads on its own.
private final class PartialLog: @unchecked Sendable {
    private let lock = NSLock()
    private var seen: [[String]] = []
    func record(_ snapshot: DirectorySnapshot) {
        lock.lock(); seen.append(snapshot.entries.map(\.name)); lock.unlock()
    }
    var counts: [Int] { lock.lock(); defer { lock.unlock() }; return seen.map(\.count) }
    var all: [[String]] { lock.lock(); defer { lock.unlock() }; return seen }
}

final class DirectoryModelIncrementalTests: XCTestCase {

    /// `n` names in a fixed order, wide enough to sort unambiguously.
    private func names(_ range: Range<Int>) -> [String] {
        range.map { String(format: "file-%05d.txt", $0) }
    }

    func test_aLongListingIsOfferedBeforeItFinishes() async throws {
        // The whole point. Three batches of 150 crosses the 200-entry threshold on the second.
        let fs = ScriptedFS(batches: [names(0..<150), names(150..<300), names(300..<450)])
        let model = DirectoryModel()
        let log = PartialLog()

        let final = try await model.load("/big", fs: fs) { log.record($0) }

        XCTAssertEqual(final.entries.count, 450)
        XCTAssertFalse(log.counts.isEmpty, "nothing was offered before the listing finished")
        // Monotonic, and never the whole thing: the last batch is `isLastBatch`, and the complete
        // listing is the return value rather than a partial.
        XCTAssertEqual(log.counts, log.counts.sorted())
        XCTAssertFalse(log.counts.contains(450), "a partial claimed to be the finished listing")
    }

    func test_aShortListingIsNotOfferedInPieces() async throws {
        // Below the threshold a listing is over before anybody could look at it, and two table reloads
        // instead of one is cost without benefit.
        let fs = ScriptedFS(batches: [names(0..<10), names(10..<20)])
        let model = DirectoryModel()
        let log = PartialLog()
        let final = try await model.load("/small", fs: fs) { log.record($0) }
        XCTAssertEqual(final.entries.count, 20)
        XCTAssertEqual(log.counts, [], "a twenty-entry directory was painted twice")
    }

    func test_aPartialIsSortedLikeTheRealThing() async throws {
        // A partial is what the panel draws, so it has to go through the same sort and filter. Fed in
        // reverse so an unsorted partial is obvious.
        let fs = ScriptedFS(batches: [names(0..<250).reversed(), names(250..<300)])
        let model = DirectoryModel()
        await model.sort(by: .name(ascending: true))
        let log = PartialLog()
        _ = try await model.load("/sorted", fs: fs) { log.record($0) }
        let first = try XCTUnwrap(log.all.first)
        XCTAssertEqual(first, first.sorted(), "a partial was handed over in arrival order")
    }

    func test_aPartialRespectsTheFilter() async throws {
        var mixed = names(0..<250)
        mixed += ["keep-me.log", "keep-you.log"]
        let fs = ScriptedFS(batches: [mixed, ["keep-third.log"]])
        let model = DirectoryModel()
        await model.setFilter("*.log")
        let log = PartialLog()
        let final = try await model.load("/filtered", fs: fs) { log.record($0) }
        XCTAssertEqual(final.entries.count, 3)
        for partial in log.all {
            XCTAssertTrue(partial.allSatisfy { $0.hasSuffix(".log") },
                          "a partial ignored the filter: \(partial)")
        }
    }

    func test_theModelDoesNotCommitUntilTheListingFinishes() async throws {
        // F-445's invariant, which partials must not break: `getPath()` has twenty-odd callers, and a
        // path that moved before its entries did is how a panel came to name one folder and list
        // another. Asked from inside a partial callback — actors are re-entrant, so this is a state
        // the app really can observe.
        let fs = ScriptedFS(batches: [names(0..<250), names(250..<300)])
        let model = DirectoryModel()
        _ = try await model.load("/first", fs: fs)

        let observed = PartialLog()
        let paths = LockedPaths()
        _ = try await model.load("/second", fs: fs) { snapshot in
            observed.record(snapshot)
            // The partial names the directory being loaded…
            paths.recordPartial(snapshot.path)
        }
        for partial in observed.all where !partial.isEmpty {
            XCTAssertFalse(partial.isEmpty)
        }
        XCTAssertEqual(paths.partials.filter { $0 != "/second" }, [],
                       "a partial named a directory other than the one being loaded")
        // …and after the load, the model has moved.
        let committedPath = await model.getPath()
        XCTAssertEqual(committedPath, "/second")
    }

    func test_aFailedListingLeavesThePreviousOneCommitted() async throws {
        // The panel repaints from `snapshot()` when a load it painted partials for then fails, so this
        // is the value that repaint depends on: the model must still be holding the old directory.
        let good = ScriptedFS(batches: [names(0..<5)])
        let model = DirectoryModel()
        _ = try await model.load("/good", fs: good)

        let bad = ScriptedFS(batches: [names(100..<350), names(350..<400)], failAfter: 1)
        let log = PartialLog()
        do {
            _ = try await model.load("/bad", fs: bad) { log.record($0) }
            XCTFail("the scripted failure did not surface")
        } catch let error as VFSError {
            guard case .connectionLost = error else { return XCTFail("got \(error)") }
        }
        XCTAssertFalse(log.counts.isEmpty, "this proves nothing unless a partial was offered first")
        let after = await model.snapshot()
        XCTAssertEqual(after.path, "/good")
        XCTAssertEqual(after.entries.count, 5, "a failed listing overwrote the committed one")
    }

    func test_anOvertakenLoadStopsInsteadOfMixingTwoDirectories() async throws {
        // Actors are re-entrant at every `await`, so a second load really can start while the first is
        // waiting for a batch. Before partials it did not matter much — whichever committed last won.
        // Now it does: two listings appending into one array would show one directory's files under
        // another's name.
        let model = DirectoryModel()
        let secondFinished = expectation(description: "the overtaking load finished")

        let slow = ScriptedFS(batches: [names(0..<250), names(250..<500), names(500..<750)]) { index in
            guard index == 0 else { return }
            // Start a second load and let it complete, from between the first load's batches.
            let quick = ScriptedFS(batches: [["only-me.txt"]])
            _ = try? await model.load("/quick", fs: quick)
            secondFinished.fulfill()
        }

        do {
            _ = try await model.load("/slow", fs: slow)
            XCTFail("the overtaken load returned a listing")
        } catch is DirectoryLoadSuperseded {
            // Exactly this: not an error about the directory, which is why the panel does not report it.
        }
        await fulfillment(of: [secondFinished], timeout: 5)

        let after = await model.snapshot()
        XCTAssertEqual(after.path, "/quick")
        XCTAssertEqual(after.entries.map(\.name), ["only-me.txt"],
                       "the overtaken listing's entries reached the committed snapshot")
    }
}

/// Paths seen in partial callbacks.
private final class LockedPaths: @unchecked Sendable {
    private let lock = NSLock()
    private var seen: [String] = []
    func recordPartial(_ path: String) { lock.lock(); seen.append(path); lock.unlock() }
    var partials: [String] { lock.lock(); defer { lock.unlock() }; return seen }
}
