// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCAutomation

final class MemoryStoreTests: XCTestCase {
    private func tempStore() -> MemoryStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("memory.json")
        return MemoryStore(url: url)
    }

    func test_addAndRecall_matchesSubstring_newestFirst() {
        let s = tempStore()
        defer { try? FileManager.default.removeItem(at: s.url.deletingLastPathComponent()) }
        s.add("User prefers dark mode", at: 1)
        s.add("Project deadline is Friday", at: 2)
        s.add("User prefers tabs over spaces", at: 3)

        let prefs = s.recall("prefers", limit: 10)
        XCTAssertEqual(prefs, ["User prefers tabs over spaces", "User prefers dark mode"])  // newest first
        XCTAssertEqual(s.recall("deadline", limit: 10), ["Project deadline is Friday"])
        XCTAssertEqual(s.recall("", limit: 2).count, 2)   // empty query = most recent
    }

    func test_dedupesIdenticalConsecutive_andPersists() {
        let s = tempStore()
        defer { try? FileManager.default.removeItem(at: s.url.deletingLastPathComponent()) }
        s.add("remember this", at: 1)
        s.add("remember this", at: 2)   // dup — ignored
        // A fresh instance reads the same file (persistence).
        XCTAssertEqual(MemoryStore(url: s.url).recall("", limit: 10), ["remember this"])
    }
}
