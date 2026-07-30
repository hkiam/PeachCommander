// SPDX-License-Identifier: Apache-2.0
// PluginHostTests.swift - Discovery/validation tests with on-disk fixtures.

import XCTest
@testable import PCPluginHost

final class PluginHostTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pchost-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// Build a `<name>.pcxplugin` bundle. `plist` nil = omit Info.plist;
    /// `withBinary` false = omit the dylib.
    @discardableResult
    private func makeBundle(_ name: String, ext: String = "pcxplugin",
                            plist: [String: Any]?, withBinary: Bool = true) throws -> URL {
        let bundle = root.appendingPathComponent("\(name).\(ext)")
        let contents = bundle.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        if let plist {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: contents.appendingPathComponent("Info.plist"))
        }
        if withBinary {
            let macos = contents.appendingPathComponent("MacOS")
            try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
            try Data("stub".utf8).write(to: macos.appendingPathComponent(name))
        }
        return bundle
    }

    private func validPlist(name: String = "Sample") -> [String: Any] {
        ["PCPluginType": "pcx", "PCPluginAPIVersion": 1, "PCPluginName": name,
         "PCPluginExtensions": ["pak"]]
    }

    func testLoadsValidBundle() throws {
        let url = try makeBundle("Sample", plist: validPlist())
        let result = PluginHost.load(bundle: url)
        guard case .success(let plugin) = result else { return XCTFail("expected success, got \(result)") }
        XCTAssertEqual(plugin.manifest.type, .pcx)
        XCTAssertEqual(plugin.manifest.name, "Sample")
        XCTAssertEqual(plugin.manifest.extensions, ["pak"])
        XCTAssertTrue(plugin.binaryPath.hasSuffix("Contents/MacOS/Sample"))
    }

    func testMissingInfoPlist() throws {
        let url = try makeBundle("NoPlist", plist: nil)
        XCTAssertEqual(PluginHost.load(bundle: url), .failure(.missingInfoPlist))
    }

    func testMissingBinary() throws {
        let url = try makeBundle("NoBin", plist: validPlist(name: "NoBin"), withBinary: false)
        guard case .failure(.missingBinary) = PluginHost.load(bundle: url) else {
            return XCTFail("expected missingBinary")
        }
    }

    func testInvalidManifestType() throws {
        var p = validPlist(); p["PCPluginType"] = "bogus"
        let url = try makeBundle("BadType", plist: p)
        guard case .failure(.manifest(.invalidType)) = PluginHost.load(bundle: url) else {
            return XCTFail("expected manifest(.invalidType)")
        }
    }

    func testWrongApiVersionSurfaced() throws {
        var p = validPlist(); p["PCPluginAPIVersion"] = 99
        let url = try makeBundle("OldApi", plist: p)
        guard case .failure(.manifest(.unsupportedAPIVersion(99, current: 1))) = PluginHost.load(bundle: url) else {
            return XCTFail("expected unsupportedAPIVersion")
        }
    }

    func testNotABundle() {
        let url = root.appendingPathComponent("nope.pcxplugin")
        XCTAssertEqual(PluginHost.load(bundle: url), .failure(.notABundle))
    }

    func testDiscoverSeparatesGoodAndBad() throws {
        try makeBundle("Good", plist: validPlist(name: "Good"))
        var bad = validPlist(); bad["PCPluginType"] = "bogus"
        try makeBundle("Bad", plist: bad)
        try makeBundle("NoBin", plist: validPlist(name: "NoBin"), withBinary: false)
        // A non-plugin directory should be ignored.
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("random.txt"), withIntermediateDirectories: true)

        let result = PluginHost.discover(in: [root])
        XCTAssertEqual(result.discovered.count, 1)
        XCTAssertEqual(result.discovered.first?.manifest.name, "Good")
        XCTAssertEqual(result.failures.count, 2)
    }

    func testDiscoverSkipsMissingDirectory() {
        let result = PluginHost.discover(in: [root.appendingPathComponent("does-not-exist")])
        XCTAssertTrue(result.discovered.isEmpty)
        XCTAssertTrue(result.failures.isEmpty)
    }
}
