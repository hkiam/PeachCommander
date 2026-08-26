// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCAutomation

// Folding a long file into a summary costs a model generation per few kilobytes, so the result
// is kept — for a second ask, and for the panel's AI Summary column. What matters here is that
// a kept summary is only ever shown for the file it was made from.
final class SummaryStoreTests: XCTestCase {

    private func store(cap: Int = 1000) -> (SummaryStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (SummaryStore(url: dir.appendingPathComponent("summaries.json"), cap: cap), dir)
    }

    func test_savedSummary_comesBack() {
        let (store, dir) = store(); defer { try? FileManager.default.removeItem(at: dir) }
        let key = SummaryStore.fingerprint(path: "/a/bericht.txt", size: 4096, modified: 1_700_000_000)
        store.save("Ein Quartalsbericht.", for: key, path: "/a/bericht.txt")
        XCTAssertEqual(store.summary(for: key), "Ein Quartalsbericht.")
    }

    // The whole point of the fingerprint: an edited file must not show the old summary.
    func test_editedFile_hasNoSummary() {
        let (store, dir) = store(); defer { try? FileManager.default.removeItem(at: dir) }
        let before = SummaryStore.fingerprint(path: "/a/bericht.txt", size: 4096, modified: 1_700_000_000)
        store.save("Ein Quartalsbericht.", for: before, path: "/a/bericht.txt")
        let after = SummaryStore.fingerprint(path: "/a/bericht.txt", size: 5000, modified: 1_700_000_900)
        XCTAssertNil(store.summary(for: after))
    }

    func test_unknownFile_hasNoSummary() {
        let (store, dir) = store(); defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertNil(store.summary(for: SummaryStore.fingerprint(path: "/nope", size: 1, modified: 2)))
    }

    func test_missingFile_isNotAnError() {
        let store = SummaryStore(url: URL(fileURLWithPath: "/nonexistent/dir/summaries.json"))
        XCTAssertNil(store.summary(for: "anything"))
    }

    // A folder walk with the column switched on would otherwise grow the file without end.
    func test_oldestGoFirst_whenCapped() {
        let (store, dir) = store(cap: 3); defer { try? FileManager.default.removeItem(at: dir) }
        for i in 1...5 {
            store.save("summary \(i)", for: "key\(i)", path: "/a/\(i).txt")
        }
        XCTAssertEqual(store.summary(for: "key5"), "summary 5")
        XCTAssertEqual(store.summary(for: "key4"), "summary 4")
        XCTAssertNil(store.summary(for: "key1"), "the oldest is the one dropped")
    }

    func test_resavingTheSameFile_replacesTheSummary() {
        let (store, dir) = store(); defer { try? FileManager.default.removeItem(at: dir) }
        let key = SummaryStore.fingerprint(path: "/a/f.txt", size: 10, modified: 1)
        store.save("erste Fassung", for: key, path: "/a/f.txt")
        store.save("zweite Fassung", for: key, path: "/a/f.txt")
        XCTAssertEqual(store.summary(for: key), "zweite Fassung")
    }

    func testTheFingerprintShapeTwoDylibsDependOn() {
        // `Plugins/AIColumn` links nothing and re-implements this expression, so its exact shape is
        // a contract between two binaries rather than an implementation detail. It was broken in
        // both halves at once — the column used the 1970 epoch while the writer used 2001, and the
        // writer rounded the Double through `NSNumber.stringValue` while the column interpolated it
        // — so the AI Summary column had never shown a value for any file. Pinned here because
        // nothing else can see both sides.
        XCTAssertEqual(SummaryStore.fingerprint(path: "/a/b.txt", size: 77, modified: 809429740.471769),
                       "/a/b.txt|77|809429740.471769")
    }
}
