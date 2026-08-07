// SPDX-License-Identifier: Apache-2.0
// DirectoryWatcherTests.swift - Noticing directory changes as they happen (F-361).
//
// Real directories and real FSEvents. The predecessor was a polling loop with no callback that could
// never have notified anybody, and no test noticed for months — because there was no test. The one
// property that matters is the one that was missing: a change to the directory reaches the callback.

import XCTest
@testable import PCVFS

final class DirectoryWatcherTests: XCTestCase {
    private var directory = ""

    override func setUpWithError() throws {
        directory = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("pc-watch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: directory)
    }

    /// FSEvents needs a moment to register the stream before changes are reported.
    private func settle() { Thread.sleep(forTimeInterval: 0.5) }

    private func touch(_ name: String, in dir: String? = nil) throws {
        try "x".write(toFile: ((dir ?? directory) as NSString).appendingPathComponent(name),
                      atomically: true, encoding: .utf8)
    }

    func testACreatedFileIsReported() throws {
        let fired = expectation(description: "change reported")
        // FSEvents may report one change more than once — coalescing is a property of the API, not
        // a promise about counts — so an expectation here must not police how often it fired.
        // Without this the test failed on a slower machine with "multiple calls to fulfill".
        fired.assertForOverFulfill = false
        let watcher = DirectoryWatcher(path: directory) { fired.fulfill() }
        watcher.start()
        defer { watcher.stop() }
        settle()
        try touch("new.txt")
        wait(for: [fired], timeout: 5)
    }

    func testADeletedFileIsReported() throws {
        try touch("gone.txt")
        let fired = expectation(description: "change reported")
        fired.assertForOverFulfill = false
        let watcher = DirectoryWatcher(path: directory) { fired.fulfill() }
        watcher.start()
        defer { watcher.stop() }
        settle()
        try FileManager.default.removeItem(atPath: (directory as NSString)
            .appendingPathComponent("gone.txt"))
        wait(for: [fired], timeout: 5)
    }

    func testABurstOfChangesIsThrottled() throws {
        // Unpacking an archive into the watched folder must not be four hundred re-listings. FSEvents'
        // own latency is not a rate limit — measured, 200 files still arrived in fifteen batches — so the
        // throttle is what holds this, and the bound it promises is one call per cooldown plus a tail.
        let fired = expectation(description: "change reported")
        fired.assertForOverFulfill = false
        let count = LockedCount()
        let cooldown = 0.4
        let watcher = DirectoryWatcher(path: directory, latency: 0.2, cooldown: cooldown) {
            count.increment()
            fired.fulfill()
        }
        watcher.start()
        defer { watcher.stop() }
        settle()
        let started = Date()
        for i in 0..<200 { try touch("file-\(i).txt") }
        wait(for: [fired], timeout: 5)
        Thread.sleep(forTimeInterval: 1.5)          // let the tail arrive
        let elapsed = Date().timeIntervalSince(started)
        let bound = Int(elapsed / cooldown) + 2     // +1 for the leading edge, +1 for the tail
        XCTAssertGreaterThan(count.value, 0)
        XCTAssertLessThanOrEqual(count.value, bound,
                                 "\(count.value) refreshes in \(elapsed)s exceeds one per \(cooldown)s")
    }

    func testChangesDeeperInTheTreeAreIgnored() throws {
        // A build running in a subfolder must not reload the panel on every compiled file. Measured:
        // FSEvents delivers an event for the *watched directory* as well as for the deep one, so this
        // only holds because the directory's own mtime is checked before refreshing.
        let deep = (directory as NSString).appendingPathComponent("sub/deeper")
        try FileManager.default.createDirectory(atPath: deep, withIntermediateDirectories: true)
        // Armed only after the history has drained: creating `sub` is itself a change to this listing,
        // and FSEvents' "since now" is coarse enough to report it after start(). A panel that has been
        // open for a moment is the situation being tested, not the instant it opened.
        let armed = LockedFlag()
        let unexpected = expectation(description: "must not fire for a change deeper in the tree")
        unexpected.isInverted = true
        let watcher = DirectoryWatcher(path: directory) { if armed.value { unexpected.fulfill() } }
        watcher.start()
        defer { watcher.stop() }
        Thread.sleep(forTimeInterval: 1.5)
        armed.set()
        for i in 0..<20 { try touch("buried-\(i).txt", in: deep) }
        wait(for: [unexpected], timeout: 3)
    }

    func testAModifiedFileInTheWatchedDirectoryIsReported() throws {
        // Its size and date are on screen, so the listing is stale even though no entry appeared or
        // vanished — and the directory's mtime does not move for a content change. The direct-child rule
        // is what covers this.
        try touch("existing.txt")
        let fired = expectation(description: "modification reported")
        fired.assertForOverFulfill = false
        let watcher = DirectoryWatcher(path: directory) { fired.fulfill() }
        watcher.start()
        defer { watcher.stop() }
        settle()
        try "considerably longer content".write(
            toFile: (directory as NSString).appendingPathComponent("existing.txt"),
            atomically: false, encoding: .utf8)
        wait(for: [fired], timeout: 5)
    }

    func testOpeningAFolderDoesNotRefreshItByItself() throws {
        // FSEvents' "since now" is coarse: a directory created moments ago still arrives. Without an
        // mtime baseline taken at start(), every folder would refresh once right after being opened.
        let fresh = (directory as NSString).appendingPathComponent("just-made")
        try FileManager.default.createDirectory(atPath: fresh, withIntermediateDirectories: true)
        let unexpected = expectation(description: "must not fire for its own creation")
        unexpected.isInverted = true
        let watcher = DirectoryWatcher(path: fresh) { unexpected.fulfill() }
        watcher.start()
        defer { watcher.stop() }
        wait(for: [unexpected], timeout: 2)
    }

    func testStopEndsTheNotifications() throws {
        let unexpected = expectation(description: "must not fire after stop")
        unexpected.isInverted = true
        let watcher = DirectoryWatcher(path: directory) { unexpected.fulfill() }
        watcher.start()
        settle()
        watcher.stop()
        try touch("after-stop.txt")
        wait(for: [unexpected], timeout: 2)
    }

    func testATemporaryDirectoryReportsItsChanges() throws {
        // /var is a symlink to /private/var, and NSTemporaryDirectory() hands out the /var form. This is
        // the case the first implementation failed: it "resolved" the path with a Foundation call that
        // strips /private instead of adding it, so every event was discarded as somebody else's.
        XCTAssertTrue(DirectoryWatcher.canonical(directory).hasPrefix("/private/"))
        let link = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("pc-watch-link-\(UUID().uuidString)")
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: directory)
        defer { try? FileManager.default.removeItem(atPath: link) }
        let fired = expectation(description: "change reported through the symlink")
        fired.assertForOverFulfill = false
        let watcher = DirectoryWatcher(path: link) { fired.fulfill() }
        watcher.start()
        defer { watcher.stop() }
        settle()
        try touch("through-link.txt")
        wait(for: [fired], timeout: 5)
    }

    func testTheClassificationSeparatesTheDirectoryFromItsChildren() throws {
        // Against the canonical path, which is what FSEvents reports. The first version of this test
        // compared against `URL.resolvingSymlinksInPath()` — the very function whose behaviour was the
        // bug — so it passed while nothing worked.
        let watched = (directory as NSString).appendingPathComponent("watched")
        try FileManager.default.createDirectory(atPath: watched, withIntermediateDirectories: true)
        let watcher = DirectoryWatcher(path: watched) {}
        let resolved = DirectoryWatcher.canonical(watched)
        XCTAssertTrue(resolved.hasPrefix("/private/"), "expected a canonical path, got \(resolved)")
        XCTAssertEqual(watcher.classify(resolved), .theDirectory)
        XCTAssertEqual(watcher.classify(resolved + "/"), .theDirectory)
        XCTAssertEqual(watcher.classify(resolved + "/file.txt"), .directChild)
        XCTAssertEqual(watcher.classify(resolved + "/sub/file.txt"), .elsewhere)
        XCTAssertEqual(watcher.classify(resolved + "-sibling/file.txt"), .elsewhere)
        XCTAssertEqual(watcher.classify((resolved as NSString).deletingLastPathComponent), .elsewhere)
    }
}

/// A flag safe to touch from the watcher's queue and the test thread.
private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    var value: Bool { lock.withLock { flag } }
    func set() { lock.withLock { flag = true } }
}

/// A counter safe to touch from the watcher's queue and the test thread.
private final class LockedCount: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}
