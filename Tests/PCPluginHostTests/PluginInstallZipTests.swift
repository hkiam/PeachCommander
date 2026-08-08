// SPDX-License-Identifier: Apache-2.0
// PluginInstallZipTests.swift - Locating the plugin bundle inside an unpacked
// .zip tree, incl. pluginst.inf precedence (F-235).

import XCTest
@testable import PCPluginHost

final class PluginInstallZipTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCPluginInstall-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
    }

    /// Create a fake bundle dir "<name>" with a Contents/Info.plist.
    private func makeBundle(_ name: String, in dir: URL) throws {
        let contents = dir.appendingPathComponent(name).appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try Data("<plist/>".utf8).write(to: contents.appendingPathComponent("Info.plist"))
    }

    func test_findsSingleBundle() throws {
        try makeBundle("Cool.pdxplugin", in: tempDir)
        let found = PluginManager.locatePluginBundle(in: tempDir)
        XCTAssertEqual(found?.lastPathComponent, "Cool.pdxplugin")
    }

    func test_ignoresNonBundleDirsAndFiles() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try Data("readme".utf8).write(to: tempDir.appendingPathComponent("README.txt"))
        XCTAssertNil(PluginManager.locatePluginBundle(in: tempDir))
    }

    func test_pluginstInf_selectsNamedBundle() throws {
        try makeBundle("Alpha.ptxplugin", in: tempDir)
        try makeBundle("Beta.ptxplugin", in: tempDir)
        let inf = """
        [plugininstall]
        type=wdx
        file=Beta.ptxplugin
        description=Beta plugin
        """
        try Data(inf.utf8).write(to: tempDir.appendingPathComponent("pluginst.inf"))
        let found = PluginManager.locatePluginBundle(in: tempDir)
        XCTAssertEqual(found?.lastPathComponent, "Beta.ptxplugin")
    }

    func test_findsNestedBundle() throws {
        let sub = tempDir.appendingPathComponent("MyPlugin-1.0")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try makeBundle("Nested.pcxplugin", in: sub)
        let found = PluginManager.locatePluginBundle(in: tempDir)
        XCTAssertEqual(found?.lastPathComponent, "Nested.pcxplugin")
    }

    /// Full path: build a VALID bundle (plist + binary), zip it, installFromZip,
    /// and assert the manager then discovers it.
    func test_installFromZip_endToEnd() async throws {
        guard FileManager.default.fileExists(atPath: "/usr/bin/zip") else {
            throw XCTSkip("/usr/bin/zip not available")
        }
        // Valid pcx bundle.
        let src = tempDir.appendingPathComponent("src")
        let contents = src.appendingPathComponent("ZipMe.pcxplugin/Contents")
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("MacOS"),
                                                withIntermediateDirectories: true)
        let plist: [String: Any] = ["PCPluginType": "pcx", "PCPluginAPIVersion": 1,
                                    "PCPluginName": "ZipMe", "PCPluginExtensions": ["zme"]]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        try Data("stub".utf8).write(to: contents.appendingPathComponent("MacOS/ZipMe"))
        // Zip it.
        let zipURL = tempDir.appendingPathComponent("ZipMe.zip")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.arguments = ["-q", "-r", zipURL.path, "ZipMe.pcxplugin"]
        p.currentDirectoryURL = src
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()

        let pluginsDir = tempDir.appendingPathComponent("installed")
        let manager = PluginManager(pluginsDir: pluginsDir,
                                    configURL: tempDir.appendingPathComponent("plugins.ini"))
        let installed = try await manager.installFromZip(zipURL: zipURL)
        XCTAssertEqual(installed.manifest.name, "ZipMe")
        // The bundle now lives in the plugins dir and is discovered.
        let discovered = await manager.discovered.map { $0.manifest.name }
        XCTAssertTrue(discovered.contains("ZipMe"))
    }

    // MARK: - A failed install must not take the working plugin with it (F-235)
    //
    // `install` removes an existing bundle of the same name *before* copying the new one, and rolls back
    // by deleting the new one if it will not load. Those two together mean an upgrade that turns out to
    // be broken leaves the user with nothing where they had something that worked — and a plugin
    // distributed as a .zip is exactly the thing people upgrade.

    /// A bundle that loads, and one that does not (no Info.plist keys the host accepts).
    private func makeValidBundle(_ name: String, in dir: URL) throws -> URL {
        let bundle = dir.appendingPathComponent("\(name).pcxplugin")
        let contents = bundle.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("MacOS"),
                                                withIntermediateDirectories: true)
        let plist: [String: Any] = ["PCPluginType": "pcx", "PCPluginAPIVersion": 1,
                                    "PCPluginName": name, "PCPluginExtensions": ["zme"]]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        try Data("stub".utf8).write(to: contents.appendingPathComponent("MacOS/\(name)"))
        return bundle
    }

    private func makeBrokenBundle(_ name: String, in dir: URL) throws -> URL {
        let bundle = dir.appendingPathComponent("\(name).pcxplugin")
        let contents = bundle.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try Data("not a plist at all".utf8).write(to: contents.appendingPathComponent("Info.plist"))
        return bundle
    }

    func test_aFailedUpgradeLeavesTheWorkingPluginInPlace() async throws {
        let pluginsDir = tempDir.appendingPathComponent("installed")
        let manager = PluginManager(pluginsDir: pluginsDir,
                                    configURL: tempDir.appendingPathComponent("plugins.ini"))

        let good = try makeValidBundle("Upgrade", in: tempDir.appendingPathComponent("v1", isDirectory: true))
        _ = try await manager.install(bundleURL: good)
        let afterFirst = await manager.discovered.map(\.manifest.name)
        XCTAssertTrue(afterFirst.contains("Upgrade"), "the fixture must install in the first place")

        // Same name, broken contents — an upgrade that turns out not to load.
        let bad = try makeBrokenBundle("Upgrade", in: tempDir.appendingPathComponent("v2", isDirectory: true))
        do {
            _ = try await manager.install(bundleURL: bad)
            XCTFail("a bundle that does not load must not install")
        } catch {
            // expected
        }

        let installed = pluginsDir.appendingPathComponent("Upgrade.pcxplugin")
        XCTAssertTrue(FileManager.default.fileExists(atPath: installed.path),
                      "the working plugin was deleted to make room for one that then failed to load")
        let afterFailed = await manager.discovered.map(\.manifest.name)
        XCTAssertTrue(afterFailed.contains("Upgrade"), "…and it is no longer discovered either")
    }
}
