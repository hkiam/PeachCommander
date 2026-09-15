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

    // MARK: - A preset file outlives the build that wrote it

    private func writeRaw(_ json: String) throws {
        try Data(json.utf8).write(to: url)
    }

    /// The whole point of the hand-written decoders, and it can only be measured with literal JSON:
    /// a `SyncPreset(...)` round-trip always writes every key, so it cannot see this at all. The
    /// synthesized decoder throws on a missing key instead of using the property's default,
    /// `load()` turns any throw into `[]`, and the next save writes that over the file.
    func test_aPresetFileFromAnOlderVersionStillLoads() throws {
        try writeRaw("""
        [{"name":"Backup","fileMask":"*.txt","withSubdirs":false,
          "options":{"byContent":true,"asymmetric":true}}]
        """)
        let loaded = SyncPresetStore(url: url).load()
        XCTAssertEqual(loaded.count, 1, "a preset written by an older build was dropped")
        XCTAssertEqual(loaded.first?.name, "Backup")
        XCTAssertEqual(loaded.first?.fileMask, "*.txt")
        XCTAssertEqual(loaded.first?.withSubdirs, false)
        XCTAssertEqual(loaded.first?.options.byContent, true)
        XCTAssertEqual(loaded.first?.options.asymmetric, true)
        // The keys the old file does not have fall back to this build's defaults.
        XCTAssertEqual(loaded.first?.options.caseSensitive, false)
        XCTAssertEqual(loaded.first?.options.toleranceSeconds, 2)
        XCTAssertEqual(loaded.first?.ignoreHidden, false)
    }

    /// The nested half, which a tolerant decoder on `SyncPreset` alone does not cover:
    /// `decodeIfPresent(SyncOptions.self, …)` throws when the object is present and incomplete.
    func test_aPresetWhoseOptionsObjectIsIncompleteStillLoads() throws {
        try writeRaw("""
        [{"name":"Half","options":{"toleranceSeconds":30}}]
        """)
        let loaded = SyncPresetStore(url: url).load()
        XCTAssertEqual(loaded.count, 1, "an options object missing keys took the whole preset with it")
        XCTAssertEqual(loaded.first?.options.toleranceSeconds, 30)
        XCTAssertEqual(loaded.first?.options.ignoreDaylightHour, false)
    }

    /// And forwards: a file from a later build carries keys this one has never heard of. This one
    /// holds by `JSONDecoder`'s own behaviour — it ignores unmapped keys — rather than by the
    /// hand-written decoders; measured by turning those off, where this test still passed and the
    /// two above it failed. It is here to pin the forward direction, not to credit the decoder.
    func test_aPresetFileWithAnUnknownFutureFieldStillLoads() throws {
        try writeRaw("""
        [{"name":"Future","fileMask":"*.*","withSubdirs":true,"ignoreHidden":true,
          "somethingAddedLater":{"depth":3},
          "options":{"byContent":false,"ignoreDate":false,"asymmetric":false,
                     "ignoreDaylightHour":false,"caseSensitive":false,"toleranceSeconds":2,
                     "anOptionFromTheFuture":true}}]
        """)
        let loaded = SyncPresetStore(url: url).load()
        XCTAssertEqual(loaded.map(\.name), ["Future"])
        XCTAssertEqual(loaded.first?.ignoreHidden, true)
    }

    /// A file that genuinely cannot be read is not silently replaced. `load()` cannot tell "no
    /// presets yet" from "I could not read this" — it answers `[]` for both — so this is the check
    /// that keeps one save from becoming the only preset in a file that had a dozen.
    func test_upsert_doesNotOverwriteAnUnreadableFile() throws {
        try writeRaw("{ this is not a preset list")
        let before = try Data(contentsOf: url)
        let store = SyncPresetStore(url: url)
        let after = store.upsert(SyncPreset(name: "New", options: SyncOptions()))
        XCTAssertEqual(after, [], "the caller was told the preset had been added")
        XCTAssertEqual(try Data(contentsOf: url), before, "an unreadable preset file was overwritten")
    }

    /// An empty file is not the same case: nothing is at risk, and refusing there would mean a
    /// first-ever save could never happen after the file had been touched.
    func test_upsert_stillWritesToAnEmptyFile() throws {
        try writeRaw("")
        let after = SyncPresetStore(url: url).upsert(SyncPreset(name: "First", options: SyncOptions()))
        XCTAssertEqual(after.map(\.name), ["First"])
    }

    /// The setting the window had and the preset did not.
    func test_ignoreHidden_roundTrips() {
        let store = SyncPresetStore(url: url)
        _ = store.upsert(SyncPreset(name: "Quiet", options: SyncOptions(), ignoreHidden: true))
        XCTAssertEqual(store.load().first?.ignoreHidden, true)
    }

    // MARK: - What the grid shows, and which preset to come back to

    /// The two display controls the window had and the preset did not, which is what made a loaded
    /// preset come back with "Hide identical" unticked however it had been saved.
    func test_displaySettings_roundTrip() {
        let store = SyncPresetStore(url: url)
        _ = store.upsert(SyncPreset(name: "OneWay", options: SyncOptions(),
                                    resultFilter: .toRight, hideEqual: true))
        XCTAssertEqual(store.load().first?.resultFilter, .toRight)
        XCTAssertEqual(store.load().first?.hideEqual, true)
    }

    /// A preset written before the display settings existed keeps working, and reads as the window's
    /// own defaults rather than as something nobody chose.
    func test_aPresetWithoutDisplaySettingsReadsAsTheDefaults() throws {
        try writeRaw("""
        [{"name":"Old","options":{"byContent":true}}]
        """)
        let loaded = SyncPresetStore(url: url).load()
        XCTAssertEqual(loaded.first?.resultFilter, .all)
        XCTAssertEqual(loaded.first?.hideEqual, false)
        XCTAssertNil(loaded.first?.lastUsed)
    }

    /// The shipped default appears in an installation that has none.
    func test_seed_writesTheShippedDefaultOnce() {
        let store = SyncPresetStore(url: url)
        XCTAssertEqual(store.seedIfMissing(named: "Default").map(\.name), ["Default"])
        XCTAssertEqual(store.load().map(\.name), ["Default"])
    }

    /// …and does not come back after it has been deleted. Seeding on "the list is empty" rather than
    /// on "there is no file" would put it back for ever, which is the one thing a deletable item may
    /// not do — and the failure would look like the delete button not working.
    func test_seed_doesNotResurrectADeletedDefault() {
        let store = SyncPresetStore(url: url)
        store.seedIfMissing(named: "Default")
        _ = store.remove(name: "Default")
        XCTAssertEqual(store.seedIfMissing(named: "Default"), [])
        XCTAssertEqual(store.load(), [])
    }

    /// Nor does it touch a list somebody already has.
    func test_seed_leavesAnExistingListAlone() {
        let store = SyncPresetStore(url: url)
        _ = store.upsert(SyncPreset(name: "Mine", options: SyncOptions()))
        XCTAssertEqual(store.seedIfMissing(named: "Default").map(\.name), ["Mine"])
    }

    /// The window comes back to the preset last chosen, not to the first one in the file.
    func test_lastUsed_isTheMostRecentlyMarked() {
        let store = SyncPresetStore(url: url)
        _ = store.upsert(SyncPreset(name: "First", options: SyncOptions()))
        _ = store.upsert(SyncPreset(name: "Second", options: SyncOptions()))
        store.markUsed(name: "Second", at: Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(store.lastUsed()?.name, "Second")
        store.markUsed(name: "First", at: Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(store.lastUsed()?.name, "First")
    }

    /// With nothing ever marked, the first one is the answer — and never nil for a non-empty list,
    /// which is what makes "open on the last preset" safe to call unconditionally.
    func test_lastUsed_fallsBackToTheFirst() {
        let store = SyncPresetStore(url: url)
        _ = store.upsert(SyncPreset(name: "Only", options: SyncOptions()))
        XCTAssertEqual(store.lastUsed()?.name, "Only")
        XCTAssertNil(SyncPresetStore(url: url.appendingPathExtension("gone")).lastUsed())
    }

    /// Marking a preset used records the date and nothing else: the settings on disk are the ones
    /// that get the stamp, not whatever a window has been changed to since it was loaded.
    func test_markUsed_doesNotRewriteTheSettings() {
        let store = SyncPresetStore(url: url)
        _ = store.upsert(SyncPreset(name: "Keep", options: SyncOptions(byContent: true),
                                    fileMask: "*.log", hideEqual: true))
        store.markUsed(name: "Keep", at: Date(timeIntervalSince1970: 5_000))
        let loaded = store.load().first
        XCTAssertEqual(loaded?.options.byContent, true)
        XCTAssertEqual(loaded?.fileMask, "*.log")
        XCTAssertEqual(loaded?.hideEqual, true)
        XCTAssertEqual(loaded?.lastUsed, Date(timeIntervalSince1970: 5_000))
    }

    /// Marking one that is not there does nothing rather than creating it.
    func test_markUsed_ofAnUnknownNameIsANoOp() {
        let store = SyncPresetStore(url: url)
        _ = store.upsert(SyncPreset(name: "Real", options: SyncOptions()))
        store.markUsed(name: "Ghost")
        XCTAssertEqual(store.load().map(\.name), ["Real"])
    }
}
