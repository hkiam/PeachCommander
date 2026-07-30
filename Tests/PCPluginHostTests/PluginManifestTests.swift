// PluginManifestTests.swift - Tests for plugin manifest model/validation and
// the pluginst.inf install-descriptor parser (SPEC-012 §1, §8; F-235).

import XCTest
@testable import PCPluginHost

final class PluginManifestTests: XCTestCase {

    // MARK: - PluginType.fromTCType

    func test_fromTCType_wcxMapsToPcx() {
        XCTAssertEqual(PluginType.fromTCType("wcx"), .pcx)
    }

    func test_fromTCType_wfxMapsToPfx() {
        XCTAssertEqual(PluginType.fromTCType("wfx"), .pfx)
    }

    func test_fromTCType_wlxMapsToPlx() {
        XCTAssertEqual(PluginType.fromTCType("wlx"), .plx)
    }

    func test_fromTCType_wdxMapsToPdx() {
        XCTAssertEqual(PluginType.fromTCType("wdx"), .pdx)
    }

    func test_fromTCType_acceptsNativeNames() {
        XCTAssertEqual(PluginType.fromTCType("pcx"), .pcx)
        XCTAssertEqual(PluginType.fromTCType("pfx"), .pfx)
        XCTAssertEqual(PluginType.fromTCType("plx"), .plx)
        XCTAssertEqual(PluginType.fromTCType("pdx"), .pdx)
    }

    func test_fromTCType_isCaseInsensitive() {
        XCTAssertEqual(PluginType.fromTCType("WCX"), .pcx)
        XCTAssertEqual(PluginType.fromTCType("WlX"), .plx)
    }

    func test_fromTCType_unknownReturnsNil() {
        XCTAssertNil(PluginType.fromTCType("xyz"))
        XCTAssertNil(PluginType.fromTCType(""))
    }

    // MARK: - PluginManifestParser.parse - valid manifest

    func test_parse_validPcxManifestWithArrayExtensions() {
        let dict: [String: Any] = [
            "PCPluginType": "pcx",
            "PCPluginName": "MyPacker",
            "PCPluginAPIVersion": 1,
            "PCPluginExtensions": ["zip", "ZIP", ".rar"],
            "PCPluginDetectString": "EXT=\"ZIP\""
        ]
        switch PluginManifestParser.parse(infoPlist: dict) {
        case .success(let manifest):
            XCTAssertEqual(manifest.type, .pcx)
            XCTAssertEqual(manifest.apiVersion, 1)
            XCTAssertEqual(manifest.name, "MyPacker")
            XCTAssertEqual(manifest.extensions, ["zip", "zip", "rar"])
            XCTAssertEqual(manifest.detectString, "EXT=\"ZIP\"")
            XCTAssertNil(manifest.minHostVersion)
        case .failure(let error):
            XCTFail("expected success, got \(error)")
        }
    }

    func test_parse_extensionsAsSemicolonSeparatedString() {
        let dict: [String: Any] = [
            "PCPluginType": "pcx",
            "PCPluginName": "MyPacker",
            "PCPluginAPIVersion": 1,
            "PCPluginExtensions": "zip;.RAR;7z"
        ]
        switch PluginManifestParser.parse(infoPlist: dict) {
        case .success(let manifest):
            XCTAssertEqual(manifest.extensions, ["zip", "rar", "7z"])
        case .failure(let error):
            XCTFail("expected success, got \(error)")
        }
    }

    func test_parse_extensionsAsCommaSeparatedString() {
        let dict: [String: Any] = [
            "PCPluginType": "pcx",
            "PCPluginName": "MyPacker",
            "PCPluginAPIVersion": 1,
            "PCPluginExtensions": "tar, gz , .bz2"
        ]
        switch PluginManifestParser.parse(infoPlist: dict) {
        case .success(let manifest):
            XCTAssertEqual(manifest.extensions, ["tar", "gz", "bz2"])
        case .failure(let error):
            XCTFail("expected success, got \(error)")
        }
    }

    func test_parse_minHostVersionAndDetectStringForPlxManifest() {
        let dict: [String: Any] = [
            "PCPluginType": "plx",
            "PCPluginName": "MyLister",
            "PCPluginAPIVersion": 1,
            "PCPluginDetectString": "EXT=\"TXT\"",
            "PCPluginMinHostVersion": 42
        ]
        switch PluginManifestParser.parse(infoPlist: dict) {
        case .success(let manifest):
            XCTAssertEqual(manifest.type, .plx)
            XCTAssertEqual(manifest.detectString, "EXT=\"TXT\"")
            XCTAssertEqual(manifest.minHostVersion, 42)
            XCTAssertEqual(manifest.extensions, [])
        case .failure(let error):
            XCTFail("expected success, got \(error)")
        }
    }

    // MARK: - PluginManifestParser.parse - errors

    func test_parse_missingTypeKey() {
        let dict: [String: Any] = [
            "PCPluginName": "MyPlugin",
            "PCPluginAPIVersion": 1
        ]
        XCTAssertEqual(PluginManifestParser.parse(infoPlist: dict), .failure(.missingType))
    }

    func test_parse_unknownTypeValue() {
        let dict: [String: Any] = [
            "PCPluginType": "bogus",
            "PCPluginName": "MyPlugin",
            "PCPluginAPIVersion": 1
        ]
        XCTAssertEqual(PluginManifestParser.parse(infoPlist: dict), .failure(.invalidType("bogus")))
    }

    func test_parse_missingName() {
        let dict: [String: Any] = [
            "PCPluginType": "pcx",
            "PCPluginAPIVersion": 1
        ]
        XCTAssertEqual(PluginManifestParser.parse(infoPlist: dict), .failure(.missingName))
    }

    func test_parse_emptyNameIsAlsoMissingName() {
        let dict: [String: Any] = [
            "PCPluginType": "pcx",
            "PCPluginName": "   ",
            "PCPluginAPIVersion": 1
        ]
        XCTAssertEqual(PluginManifestParser.parse(infoPlist: dict), .failure(.missingName))
    }

    func test_parse_missingAPIVersion() {
        let dict: [String: Any] = [
            "PCPluginType": "pcx",
            "PCPluginName": "MyPlugin"
        ]
        XCTAssertEqual(PluginManifestParser.parse(infoPlist: dict), .failure(.missingAPIVersion))
    }

    func test_parse_wrongAPIVersion() {
        let dict: [String: Any] = [
            "PCPluginType": "pcx",
            "PCPluginName": "MyPlugin",
            "PCPluginAPIVersion": 2
        ]
        XCTAssertEqual(
            PluginManifestParser.parse(infoPlist: dict),
            .failure(.unsupportedAPIVersion(2, current: 1))
        )
    }

    func test_parse_apiVersionAsNSNumber() {
        let dict: [String: Any] = [
            "PCPluginType": "pcx",
            "PCPluginName": "MyPlugin",
            "PCPluginAPIVersion": NSNumber(value: 1)
        ]
        switch PluginManifestParser.parse(infoPlist: dict) {
        case .success(let manifest):
            XCTAssertEqual(manifest.apiVersion, 1)
        case .failure(let error):
            XCTFail("expected success, got \(error)")
        }
    }

    // MARK: - PluginInstallInfoParser.parse

    func test_parseInstallInfo_sampleDescriptor() {
        let text = """
        [plugininstall]
        type=wcx
        file=myplugin.wcx64
        description=My Packer Plugin
        defaultdir=MyPlugin
        """
        let info = PluginInstallInfoParser.parse(text)
        XCTAssertEqual(info.type, .pcx)
        XCTAssertEqual(info.file, "myplugin.wcx64")
        XCTAssertEqual(info.description, "My Packer Plugin")
        XCTAssertEqual(info.defaultDir, "MyPlugin")
    }

    func test_parseInstallInfo_caseInsensitiveHeaderAndKeys() {
        let text = """
        [PluginInstall]
        TYPE=WLX
        File=mylister.wlx64
        Description=My Lister
        DefaultDir=MyLister
        """
        let info = PluginInstallInfoParser.parse(text)
        XCTAssertEqual(info.type, .plx)
        XCTAssertEqual(info.file, "mylister.wlx64")
        XCTAssertEqual(info.description, "My Lister")
        XCTAssertEqual(info.defaultDir, "MyLister")
    }

    func test_parseInstallInfo_missingSectionReturnsAllNil() {
        let text = "just some text\nwithout a section header\n"
        let info = PluginInstallInfoParser.parse(text)
        XCTAssertNil(info.type)
        XCTAssertNil(info.file)
        XCTAssertNil(info.description)
        XCTAssertNil(info.defaultDir)
    }

    func test_parseInstallInfo_unknownKeysAreIgnored() {
        let text = """
        [plugininstall]
        type=wfx
        file=myfs.wfx64
        somethingweird=42
        anotherstrangekey=hello
        """
        let info = PluginInstallInfoParser.parse(text)
        XCTAssertEqual(info.type, .pfx)
        XCTAssertEqual(info.file, "myfs.wfx64")
        XCTAssertNil(info.description)
        XCTAssertNil(info.defaultDir)
    }

    func test_parseInstallInfo_unknownTypeMapsToNil() {
        let text = """
        [plugininstall]
        type=bogus
        file=something
        """
        let info = PluginInstallInfoParser.parse(text)
        XCTAssertNil(info.type)
        XCTAssertEqual(info.file, "something")
    }
}
