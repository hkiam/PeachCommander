// SPDX-License-Identifier: Apache-2.0
// PluginIdentityTests.swift - Stable plugin identity, versions, and the plugins.ini migration (F-482).
//
// Everything the host persists about a plugin used to be keyed on its *display name*. This file
// holds the three properties that fixed:
//   * an identifier is what is written, with the name standing in when none is declared, so no
//     existing installation loses its on/off state;
//   * the migration rewrites an old file exactly once, and refuses to run when there is nothing
//     to rewrite toward;
//   * a manifest that carries a version has it read, which nothing did before.

import XCTest
import PCFoundation
@testable import PCPluginHost

final class PluginIdentityTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCPluginIdentity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    // MARK: - Manifest

    func test_identifierFallsBackToTheName() throws {
        let dict: [String: Any] = ["PCPluginType": "pcx", "PCPluginName": "Old Plugin",
                                   "PCPluginAPIVersion": 1]
        let manifest = try XCTUnwrap(PluginManifestParser.parse(infoPlist: dict).get())
        XCTAssertEqual(manifest.identifier, "Old Plugin")
    }

    func test_identifierIsReadWhenDeclared() throws {
        let dict: [String: Any] = ["PCPluginType": "pcx", "PCPluginName": "ISO Images",
                                   "PCPluginIdentifier": "com.example.iso",
                                   "PCPluginAPIVersion": 1]
        let manifest = try XCTUnwrap(PluginManifestParser.parse(infoPlist: dict).get())
        XCTAssertEqual(manifest.identifier, "com.example.iso")
    }

    /// The characters that would tear `plugins.ini` in half are refused rather than escaped.
    func test_identifierWithAListSeparatorIsRefused() {
        for bad in ["a;b", "a,b", "a=b", "[a]", "with space", ""] {
            let dict: [String: Any] = ["PCPluginType": "pcx", "PCPluginName": "N",
                                       "PCPluginIdentifier": bad, "PCPluginAPIVersion": 1]
            guard case .failure(.invalidIdentifier) = PluginManifestParser.parse(infoPlist: dict) else {
                return XCTFail("“\(bad)” must not be accepted as an identifier")
            }
        }
    }

    func test_versionPrefersItsOwnKeyThenTheBundleVersion() throws {
        var dict: [String: Any] = ["PCPluginType": "pcx", "PCPluginName": "N", "PCPluginAPIVersion": 1]
        XCTAssertEqual(try XCTUnwrap(PluginManifestParser.parse(infoPlist: dict).get()).version,
                       SemanticVersion(0, 0, 0))

        dict["CFBundleShortVersionString"] = "2.3"
        XCTAssertEqual(try XCTUnwrap(PluginManifestParser.parse(infoPlist: dict).get()).version,
                       SemanticVersion(2, 3, 0))

        dict["PCPluginVersion"] = "4.5.6"
        XCTAssertEqual(try XCTUnwrap(PluginManifestParser.parse(infoPlist: dict).get()).version,
                       SemanticVersion(4, 5, 6))
    }

    /// The architecture guide has always promised these are accepted here; until now only the
    /// `pluginst.inf` path honoured it.
    func test_totalCommanderTypeNamesAreAccepted() throws {
        for (raw, expected) in [("wcx", PluginType.pcx), ("wfx", .pfx), ("wlx", .plx), ("wdx", .pdx)] {
            let dict: [String: Any] = ["PCPluginType": raw, "PCPluginName": "N", "PCPluginAPIVersion": 1]
            let manifest = try XCTUnwrap(PluginManifestParser.parse(infoPlist: dict).get())
            XCTAssertEqual(manifest.type, expected, "PCPluginType=\(raw)")
        }
    }

    // MARK: - Minimum host version

    func test_minHostVersionAsAStringIsEnforced() throws {
        let saved = HostVersion.override
        defer { HostVersion.override = saved }
        HostVersion.override = SemanticVersion(0, 8, 2)

        let tooNew = try makeBundle("Future", extra: ["PCPluginMinHostVersion": "99.0.0"])
        guard case .failure(.hostTooOld(let required, let current)) = PluginHost.load(bundle: tooNew) else {
            return XCTFail("a plugin demanding a newer host must be refused")
        }
        XCTAssertEqual(required, SemanticVersion(99, 0, 0))
        XCTAssertEqual(current, SemanticVersion(0, 8, 2))

        let fine = try makeBundle("Present", extra: ["PCPluginMinHostVersion": "0.8.0"])
        guard case .success = PluginHost.load(bundle: fine) else {
            return XCTFail("a plugin whose requirement this host meets must load")
        }
    }

    /// The integer form keeps its old meaning — an API level — so every shipped manifest, all of
    /// which say `1`, keeps loading.
    func test_minHostVersionAsAnIntegerIsAnAPILevel() throws {
        let fine = try makeBundle("Legacy", extra: ["PCPluginMinHostVersion": 1])
        guard case .success = PluginHost.load(bundle: fine) else {
            return XCTFail("PCPluginMinHostVersion=1 is what every shipped plugin declares")
        }
        let tooNew = try makeBundle("LegacyFuture", extra: ["PCPluginMinHostVersion": 42])
        guard case .failure(.hostAPITooOld(42, _)) = PluginHost.load(bundle: tooNew) else {
            return XCTFail("an API level this host does not implement must be refused")
        }
    }

    // MARK: - plugins.ini migration

    func test_migrationRewritesNameKeyedEntriesOnce() {
        let config = PluginConfig(disabled: ["Old Name"], enabled: [],
                                  packerAssoc: ["iso": "Old Name"])
        let migrated = config.migratedKeys(nameToIdentifier: ["Old Name": "com.example.iso"])
        XCTAssertEqual(migrated?.disabled, ["com.example.iso"])
        XCTAssertEqual(migrated?.packerAssoc, ["iso": "com.example.iso"])
        // Idempotent: a second pass over the result has nothing to do.
        XCTAssertNil(migrated?.migratedKeys(nameToIdentifier: ["Old Name": "com.example.iso"]),
                     "a migrated config must not be rewritten again on every launch")
    }

    func test_migrationLeavesAnEntryAloneWhenTheIdentifierIsAlreadyThere() {
        let config = PluginConfig(disabled: ["Old Name", "com.example.iso"], enabled: [], packerAssoc: [:])
        // Both present: rewriting would silently merge two settings into one.
        XCTAssertNil(config.migratedKeys(nameToIdentifier: ["Old Name": "com.example.iso"]))
    }

    /// The migration must not depend on the order a Dictionary happens to hand back its pairs.
    ///
    /// The shape that broke it: one plugin named "X" whose identifier is "Y", and a second actually
    /// named "Y". The first version rewrote a set while iterating the map and so read its own
    /// writes — "X" became "Y", and then the "Y" pair fired on the entry that had just been created
    /// and turned it into "Z". Which of the two answers came out depended on iteration order, and a
    /// migration that runs once and writes the result back is the last place to leave that.
    func test_migrationIsIndependentOfDictionaryOrder() {
        let map = ["X": "Y", "Y": "Z"]
        let config = PluginConfig(disabled: ["X"], enabled: [], packerAssoc: [:])
        // Repeated because the hash seed — and so the iteration order — differs per process, but
        // not within one: the loop guards against a rewrite that is order-dependent *and* against
        // one that is merely unstable.
        for _ in 0..<50 {
            XCTAssertEqual(config.migratedKeys(nameToIdentifier: map)?.disabled, ["Y"],
                           "“X” is named by the map and must become exactly its identifier")
        }
    }

    func test_migrationDoesNothingWithNoMapping() {
        let config = PluginConfig(disabled: ["Something"], enabled: [], packerAssoc: [:])
        XCTAssertNil(config.migratedKeys(nameToIdentifier: [:]))
    }

    /// The trap this guard exists for: on a first launch — or with the plugins directory not yet
    /// created — discovery is empty, so there is nothing to migrate *toward*. A migration that
    /// ran anyway could only misread a perfectly good configuration.
    func test_managerDoesNotTouchTheConfigWhenNothingIsDiscovered() async throws {
        let configURL = root.appendingPathComponent("plugins.ini")
        let original = "[Plugins]\nDisabled=Some Plugin\n"
        try Data(original.utf8).write(to: configURL)

        let manager = PluginManager(pluginsDir: root.appendingPathComponent("no-such-dir"),
                                    configURL: configURL)
        await manager.reload()

        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), original,
                       "an empty discovery must leave plugins.ini exactly as it was")
        let stillDisabled = await manager.isEnabled("Some Plugin")
        XCTAssertFalse(stillDisabled, "…and the setting it holds must still be in force")
    }

    /// End to end: an installation written before identifiers existed keeps its on/off state.
    func test_managerMigratesADiscoveredPluginAndKeepsItsState() async throws {
        let pluginsDir = root.appendingPathComponent("plugins", isDirectory: true)
        try FileManager.default.createDirectory(at: pluginsDir, withIntermediateDirectories: true)
        _ = try makeBundle("Disc", in: pluginsDir,
                           extra: ["PCPluginName": "ISO Images",
                                   "PCPluginIdentifier": "com.example.iso",
                                   "PCPluginExtensions": ["iso"]])

        let configURL = root.appendingPathComponent("plugins.ini")
        try Data("[Plugins]\nDisabled=ISO Images\n[PackerAssoc]\niso=ISO Images\n".utf8).write(to: configURL)

        let manager = PluginManager(pluginsDir: pluginsDir, configURL: configURL)
        await manager.reload()

        let onDisk = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(onDisk.contains("com.example.iso"), "the file should now speak identifiers: \(onDisk)")
        XCTAssertFalse(onDisk.contains("ISO Images"), "…and no longer the display name: \(onDisk)")

        let enabled = await manager.isEnabled("com.example.iso")
        XCTAssertFalse(enabled, "the plugin was switched off before the migration and must stay off")
    }

    // MARK: - Fixtures

    private func makeBundle(_ name: String, in dir: URL? = nil,
                            extra: [String: Any] = [:]) throws -> URL {
        let parent = dir ?? root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let bundle = parent.appendingPathComponent("\(name).pcxplugin")
        let contents = bundle.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("MacOS"),
                                                withIntermediateDirectories: true)
        var plist: [String: Any] = ["PCPluginType": "pcx", "PCPluginName": name, "PCPluginAPIVersion": 1]
        plist.merge(extra) { _, new in new }
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        try Data("stub".utf8).write(to: contents.appendingPathComponent("MacOS/\(name)"))
        return bundle
    }
}
