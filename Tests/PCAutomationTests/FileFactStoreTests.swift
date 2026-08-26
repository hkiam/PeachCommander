// SPDX-License-Identifier: Apache-2.0
// FileFactStoreTests.swift — the cache the panel column and the rename mask both read.
//
// The fingerprint is a contract between three pieces of code that never see each other: the
// action that writes the facts, the content-field plugin that reads them per row, and the rename
// engine that resolves `[=ai_column.ai_topic]`. The AI Summary column spent its whole existence
// empty because two of those disagreed on it, so the shape is pinned here.

import XCTest
@testable import PCAutomation

final class FileFactStoreTests: XCTestCase {

    private func store(cap: Int = 2000) -> FileFactStore {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("facts-\(UUID().uuidString).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return FileFactStore(url: url, cap: cap)
    }

    func testFactsSurviveTheRunThatWroteThem() {
        let s = store()
        let stamp = FileFactStore.fingerprint(path: "/a/b.pdf", size: 12, modified: 800.5)
        s.save(AIFileFacts(kind: "Rechnungen", topic: "dachreparatur", date: "2024-03-12"),
               for: stamp, path: "/a/b.pdf")
        XCTAssertEqual(FileFactStore(url: s.url).facts(for: stamp)?.topic, "dachreparatur")
    }

    func testTheFingerprintIsTheOneTheSummaryColumnUses() {
        // Both caches describe the same file, so a reader holding one fingerprint can look in
        // either. They diverged once and the column showed nothing for any file, ever.
        XCTAssertEqual(FileFactStore.fingerprint(path: "/a/b.pdf", size: 12, modified: 800.5),
                       SummaryStore.fingerprint(path: "/a/b.pdf", size: 12, modified: 800.5))
    }

    func testAnEditedFileLosesItsFacts() {
        // Keyed by size and modification time, so a file that changed under us has no facts
        // rather than stale ones — a rename mask filled from a stale topic is a wrong file name.
        let s = store()
        let before = FileFactStore.fingerprint(path: "/a/b.pdf", size: 12, modified: 800.5)
        s.save(AIFileFacts(topic: "dachreparatur"), for: before, path: "/a/b.pdf")
        let after = FileFactStore.fingerprint(path: "/a/b.pdf", size: 99, modified: 900.0)
        XCTAssertNil(s.facts(for: after))
    }

    func testNothingKnownIsNotWorthStoring() {
        let s = store()
        let stamp = FileFactStore.fingerprint(path: "/a/b.pdf", size: 12, modified: 800.5)
        s.save(AIFileFacts(), for: stamp, path: "/a/b.pdf")
        XCTAssertNil(s.facts(for: stamp))
    }

    func testTheOldestFallOutWhenTheCapIsReached() {
        let s = store(cap: 2)
        for i in 0..<4 {
            s.save(AIFileFacts(topic: "t\(i)"),
                   for: FileFactStore.fingerprint(path: "/a/\(i)", size: Int64(i), modified: 1),
                   path: "/a/\(i)")
        }
        let kept = (0..<4).filter {
            s.facts(for: FileFactStore.fingerprint(path: "/a/\($0)", size: Int64($0), modified: 1)) != nil
        }
        XCTAssertEqual(kept, [2, 3])
    }
}
