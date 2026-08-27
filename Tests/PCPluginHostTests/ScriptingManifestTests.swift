// SPDX-License-Identifier: Apache-2.0
// The Scripting plugin's manifest (F-477), read by the same parser the host uses.
//
// Against the file that actually ships, not a literal copied into the test: a manifest is only useful
// if the host can read *it*, and a copy would keep passing after the real one was edited.

import XCTest
@testable import PCPluginHost

final class ScriptingManifestTests: XCTestCase {

    private func infoPlist(_ plugin: String) throws -> [String: Any] {
        // Tests/PCPluginHostTests/… → repo root.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Plugins/\(plugin)/Info.plist")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(try PropertyListSerialization.propertyList(
            from: data, options: [], format: nil) as? [String: Any])
    }

    func test_itIsAnOptInToolPlugin() throws {
        let dict = try infoPlist("Scripting")
        guard case .success(let manifest) = PluginManifestParser.parse(infoPlist: dict) else {
            return XCTFail("the manifest did not parse: \(PluginManifestParser.parse(infoPlist: dict))")
        }
        XCTAssertEqual(manifest.type, .ptx)
        XCTAssertEqual(manifest.name, "Scripting")
        // Running a program of somebody's choosing is not a thing to switch on for them.
        XCTAssertFalse(manifest.enabledByDefault)
    }

    func test_theContributionsParseAndAreNotEmpty() throws {
        let parsed = ContributionParser.parse(infoPlist: try infoPlist("Scripting"))
        XCTAssertTrue(parsed.warnings.isEmpty, "\(parsed.warnings)")
        XCTAssertFalse(parsed.contributions.isEmpty,
                       "an empty parse is why the host would register nothing at all")
    }

    /// One declaration covers every saved script, which is what `acceptsSuffix` is for.
    ///
    /// The declared id carries a final component that means nothing (`…run.any`) because the family is
    /// the id truncated at its *last* dot: declaring `plugin.script.run` opens `plugin.script.` and
    /// every real script id is then two components deep and refused. This test is the one that caught
    /// it, and it is why the id looks odd.
    func test_oneCommandAnswersForEveryScript() throws {
        let c = ContributionParser.parse(infoPlist: try infoPlist("Scripting")).contributions
        let run = try XCTUnwrap(c.commands.first { $0.id.hasPrefix("plugin.script.run") })
        XCTAssertTrue(run.acceptsSuffix)
        XCTAssertEqual(run.id, "plugin.script.run.any",
                       "the family must come out as plugin.script.run.")
        XCTAssertTrue(run.answers("plugin.script.run.Tidy-Downloads"))
        XCTAssertFalse(run.answers("plugin.script.run.a.b"), "one more component, and a real one")
        XCTAssertFalse(run.answers("plugin.other.run.x"))
    }

    /// The whole point of making this a plugin: its run tools carry a capability the default policy
    /// withholds, so they exist for a session only after somebody switched it on in Settings.
    func test_theRunToolsCarryTheScriptCapability() throws {
        let c = ContributionParser.parse(infoPlist: try infoPlist("Scripting")).contributions
        let byName = Dictionary(c.tools.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        XCTAssertEqual(byName["run_applescript"]?.capability, "script")
        XCTAssertEqual(byName["run_jxa"]?.capability, "script")
        // Checking a script runs nothing, so it is a read and needs no such grant.
        XCTAssertEqual(byName["check_script"]?.capability, "read")
        XCTAssertEqual(byName["list_scripts"]?.capability, "read")
    }

    func test_everyToolsRequiredArgumentsAreDeclared() throws {
        let c = ContributionParser.parse(infoPlist: try infoPlist("Scripting")).contributions
        for name in ["run_applescript", "run_jxa", "check_script"] {
            let tool = try XCTUnwrap(c.tools.first { $0.name == name })
            XCTAssertTrue(tool.params.contains { $0.name == "source" && $0.required },
                          "\(name) must declare its source argument")
            XCTAssertFalse(tool.description.isEmpty, "\(name) needs a description a model can use")
        }
    }
}
