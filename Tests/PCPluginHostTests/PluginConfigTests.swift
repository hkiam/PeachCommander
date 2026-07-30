// SPDX-License-Identifier: Apache-2.0
// PluginConfigTests.swift - plugins.ini model + PluginManager integration.

import XCTest
@testable import PCPluginHost

final class PluginConfigTests: XCTestCase {
    func testParseDisabledAndAssoc() {
        let cfg = PluginConfig(parsing: """
        [Plugins]
        Disabled=OldPacker;Broken
        [PackerAssoc]
        pak=SamplePacker
        .CBZ=SamplePacker
        """)
        XCTAssertFalse(cfg.isEnabled("OldPacker"))
        XCTAssertFalse(cfg.isEnabled("Broken"))
        XCTAssertTrue(cfg.isEnabled("SamplePacker"))
        XCTAssertEqual(cfg.plugin(forExtension: "pak"), "SamplePacker")
        XCTAssertEqual(cfg.plugin(forExtension: ".PAK"), "SamplePacker")   // case/dot-insensitive
        XCTAssertEqual(cfg.plugin(forExtension: "cbz"), "SamplePacker")
        XCTAssertNil(cfg.plugin(forExtension: "zip"))
    }

    func testEnabledByDefault() {
        let cfg = PluginConfig()
        XCTAssertTrue(cfg.isEnabled("Anything"))
    }

    func testMutationAndRoundTrip() {
        var cfg = PluginConfig()
        cfg.setEnabled("Foo", false)
        cfg.setAssociation(ext: ".PAK", plugin: "Foo")
        cfg.setAssociation(ext: "tmp", plugin: "Bar")
        cfg.setAssociation(ext: "tmp", plugin: nil)   // removed
        let round = PluginConfig(parsing: cfg.serialized())
        XCTAssertEqual(round, cfg)
        XCTAssertFalse(round.isEnabled("Foo"))
        XCTAssertEqual(round.plugin(forExtension: "pak"), "Foo")
        XCTAssertNil(round.plugin(forExtension: "tmp"))
    }

    func testReEnableRemovesFromDisabled() {
        var cfg = PluginConfig(parsing: "[Plugins]\nDisabled=Foo\n")
        XCTAssertFalse(cfg.isEnabled("Foo"))
        cfg.setEnabled("Foo", true)
        XCTAssertTrue(cfg.isEnabled("Foo"))
        XCTAssertFalse(cfg.serialized().contains("Disabled"))
    }

    // MARK: - PluginManager integration (temp dirs)

    private func makePlugin(in dir: URL, name: String, exts: [String]) throws {
        let bundle = dir.appendingPathComponent("\(name).pcxplugin")
        let macos = bundle.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
        let plist: [String: Any] = ["PCPluginType": "pcx", "PCPluginAPIVersion": 1,
                                    "PCPluginName": name, "PCPluginExtensions": exts]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: bundle.appendingPathComponent("Contents/Info.plist"))
        try Data("stub".utf8).write(to: macos.appendingPathComponent(name))
    }

    func testManagerAssociationAndEnableDisable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pcmgr-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try makePlugin(in: root, name: "SamplePacker", exts: ["pak"])
        let cfgURL = root.appendingPathComponent("plugins.ini")

        let mgr = PluginManager(pluginsDir: root, configURL: cfgURL)
        await mgr.reload()
        var enabled = await mgr.enabledPlugins()
        XCTAssertEqual(enabled.count, 1)

        // Extension declared by the plugin resolves it.
        var byExt = await mgr.packerPlugin(forExtension: "PAK")
        XCTAssertEqual(byExt?.manifest.name, "SamplePacker")

        // Disable it → no longer enabled or resolvable, and persisted.
        await mgr.setEnabled("SamplePacker", false)
        enabled = await mgr.enabledPlugins()
        XCTAssertTrue(enabled.isEmpty)
        byExt = await mgr.packerPlugin(forExtension: "pak")
        XCTAssertNil(byExt)
        XCTAssertTrue(try String(contentsOf: cfgURL, encoding: .utf8).contains("SamplePacker"))

        // A fresh manager reading the same config keeps it disabled.
        let mgr2 = PluginManager(pluginsDir: root, configURL: cfgURL)
        await mgr2.reload()
        let stillDisabled = await mgr2.isEnabled("SamplePacker")
        XCTAssertFalse(stillDisabled)
    }
}
