// SPDX-License-Identifier: Apache-2.0
// SyncPresetStoreTests.swift - Directory-sync preset persistence (F-194).

import XCTest
@testable import PCFoundation

final class SyncPresetStoreTests: XCTestCase {
    private var url: URL!

    override func setUpWithError() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-presets-\(UUID().uuidString).json")
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: url) }

    func test_roundTrip_preservesOptions() {
        let store = SyncPresetStore(url: url)
        let opts = SyncOptions(byContent: true, ignoreDate: true, asymmetric: true,
                               ignoreDaylightHour: false, caseSensitive: true, toleranceSeconds: 10)
        let preset = SyncPreset(name: "Backup", options: opts, fileMask: "*.txt", withSubdirs: false)
        XCTAssertTrue(store.save([preset]))
        let reloaded = store.load()
        XCTAssertEqual(reloaded, [preset])
        XCTAssertEqual(reloaded.first?.options, opts)
    }

    func test_upsert_replacesSameName() {
        let store = SyncPresetStore(url: url)
        _ = store.upsert(SyncPreset(name: "A", options: SyncOptions(byContent: false)))
        let after = store.upsert(SyncPreset(name: "A", options: SyncOptions(byContent: true)))
        XCTAssertEqual(after.count, 1)
        XCTAssertEqual(after.first?.options.byContent, true)
    }

    func test_upsert_appendsDistinctNames_and_remove() {
        let store = SyncPresetStore(url: url)
        _ = store.upsert(SyncPreset(name: "A", options: SyncOptions()))
        _ = store.upsert(SyncPreset(name: "B", options: SyncOptions()))
        XCTAssertEqual(store.load().map(\.name), ["A", "B"])
        let after = store.remove(name: "A")
        XCTAssertEqual(after.map(\.name), ["B"])
    }

    func test_load_missingFile_returnsEmpty() {
        XCTAssertEqual(SyncPresetStore(url: url).load(), [])
    }
}
