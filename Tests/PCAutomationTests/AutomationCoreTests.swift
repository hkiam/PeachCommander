// SPDX-License-Identifier: Apache-2.0
// Tests for the Automation Core contract: the permission model, the tool catalogue,
// and its JSON-schema export. Pure-value tests, no host.

import XCTest
@testable import PCAutomation

final class AutomationCoreTests: XCTestCase {

    // MARK: Permission model

    func test_readOnly_refusesMutations_allowsReads() {
        let p = PermissionPolicy.readOnly
        XCTAssertEqual(p.decision(for: .read), .allow)
        XCTAssertEqual(p.decision(for: .navigate), .allow)
        XCTAssertEqual(p.decision(for: .runCommand), .allow)
        XCTAssertEqual(p.decision(for: .write), .refuse)
        XCTAssertEqual(p.decision(for: .delete), .refuse)
        XCTAssertEqual(p.decision(for: .config), .refuse)
    }

    func test_confirmWrites_confirmsMutations_allowsReads() {
        let p = PermissionPolicy.standard
        XCTAssertEqual(p.autonomy, .confirmWrites)
        XCTAssertEqual(p.decision(for: .read), .allow)
        XCTAssertEqual(p.decision(for: .write), .confirm)
        XCTAssertEqual(p.decision(for: .delete), .confirm)
        XCTAssertEqual(p.decision(for: .config), .confirm)
        XCTAssertTrue(p.requiresConfirmation(.write))
        XCTAssertFalse(p.requiresConfirmation(.read))
    }

    func test_autonomous_allowsMutations() {
        let p = PermissionPolicy(autonomy: .autonomous)
        XCTAssertEqual(p.decision(for: .write), .allow)
        XCTAssertEqual(p.decision(for: .delete), .allow)
    }

    func test_capabilityNotAllowed_isRefused_regardlessOfAutonomy() {
        let p = PermissionPolicy(autonomy: .autonomous, allowed: [.read])
        XCTAssertEqual(p.decision(for: .write), .refuse)
        XCTAssertEqual(p.decision(for: .network), .refuse)
        XCTAssertEqual(p.decision(for: .read), .allow)
    }

    func test_policy_isCodableRoundTrip() throws {
        let p = PermissionPolicy(autonomy: .confirmWrites, allowed: [.read, .write])
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(PermissionPolicy.self, from: data)
        XCTAssertEqual(p, back)
    }

    // MARK: Tool catalogue

    func test_catalogue_isNonEmpty_andEveryToolHasACapability() {
        XCTAssertFalse(AutomationCatalog.tools.isEmpty)
        for t in AutomationCatalog.tools {
            XCTAssertFalse(t.name.isEmpty)
            XCTAssertFalse(t.summary.isEmpty)
            XCTAssertTrue(Capability.allCases.contains(t.capability))
        }
    }

    func test_catalogue_toolNamesAreUnique() {
        let names = AutomationCatalog.tools.map(\.name)
        XCTAssertEqual(names.count, Set(names).count)
    }

    func test_lookup_findsAndMissesCorrectly() {
        XCTAssertNotNil(AutomationCatalog.tool(named: "copy"))
        XCTAssertNil(AutomationCatalog.tool(named: "no_such_tool"))
    }

    func test_destructiveTools_areGatedCapabilities() {
        // delete tools must be .delete; copy/move/mkdir/rename must be .write
        XCTAssertEqual(AutomationCatalog.tool(named: "delete_permanently")?.capability, .delete)
        XCTAssertEqual(AutomationCatalog.tool(named: "move_to_trash")?.capability, .delete)
        XCTAssertEqual(AutomationCatalog.tool(named: "copy")?.capability, .write)
        XCTAssertEqual(AutomationCatalog.tool(named: "read_file")?.capability, .read)
    }

    func test_toolsJSON_isValidToolSchema() throws {
        let data = try AutomationCatalog.toolsJSONData()
        let obj = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        let arr = try XCTUnwrap(obj)
        XCTAssertEqual(arr.count, AutomationCatalog.tools.count)
        let first = try XCTUnwrap(arr.first)
        XCTAssertNotNil(first["name"])
        XCTAssertNotNil(first["description"])
        let schema = try XCTUnwrap(first["inputSchema"] as? [String: Any])
        XCTAssertEqual(schema["type"] as? String, "object")
        XCTAssertNotNil(schema["properties"])
        XCTAssertNotNil(schema["required"])
    }

    func test_version_isSet() {
        XCTAssertGreaterThanOrEqual(PCAutomationVersion, 1)
    }

    // MARK: Events / context are Codable (they cross the MCP boundary)

    func test_hostEvent_isCodableRoundTrip() throws {
        let events: [HostEvent] = [
            .panelChanged(side: .left, path: "/tmp"),
            .selectionChanged(side: .right, count: 3),
            .operationFinished(id: "op1", ok: true),
            .configChanged(key: "Display.NaturalSort"),
        ]
        for e in events {
            let data = try JSONEncoder().encode(e)
            XCTAssertEqual(try JSONDecoder().decode(HostEvent.self, from: data), e)
        }
    }

    func test_context_isCodableRoundTrip() throws {
        let c = AutomationContext(activePanelPath: "/a", inactivePanelPath: "/b",
                                  cursorPath: "/a/f.txt", selection: ["/a/f.txt"],
                                  tabPaths: ["/a", "/c"], viewMode: "details")
        let data = try JSONEncoder().encode(c)
        XCTAssertEqual(try JSONDecoder().decode(AutomationContext.self, from: data), c)
    }
}

// A tool failure is read by a model, and it has to be able to act on it. `missingArgument("path")`
// printed as a Swift enum was observed producing a paragraph of speculation about file permissions
// and tool installation instead of a second call with the argument supplied.
final class ReadableErrorTests: XCTestCase {

    func test_missingArgument_namesTheArgumentAndWhatTheToolTakes() {
        let text = DefaultAutomationCore.readableError(.missingArgument("path"), tool: "read_file")
        XCTAssertTrue(text.contains("\"path\""), text)
        XCTAssertTrue(text.contains("read_file"), text)
        XCTAssertTrue(text.contains("max_bytes"), "the other arguments are listed too: \(text)")
        XCTAssertTrue(text.contains("optional"), "and which of them are optional: \(text)")
        XCTAssertFalse(text.contains("missingArgument"), "no Swift enum syntax: \(text)")
    }

    func test_unknownTool_saysSo_withoutEnumSyntax() {
        let text = DefaultAutomationCore.readableError(.unknownTool("read_files"), tool: "read_files")
        XCTAssertTrue(text.contains("read_files"), text)
        XCTAssertFalse(text.contains("unknownTool"), text)
    }

    func test_operationFailed_passesItsDetailThrough() {
        let text = DefaultAutomationCore.readableError(
            .operationFailed("Copy 3 item(s) did not complete — see the Transfer Manager."),
            tool: "copy")
        XCTAssertEqual(text, "Copy 3 item(s) did not complete — see the Transfer Manager.")
    }

    // A tool with no parameters must not produce "takes: ." — the sentence still has to read.
    func test_toolWithoutParameters_readsProperly() {
        let text = DefaultAutomationCore.readableError(.missingArgument("x"), tool: "get_context")
        XCTAssertTrue(text.contains("no arguments"), text)
    }

    func test_unknownToolName_stillProducesAdvice() {
        let text = DefaultAutomationCore.readableError(.missingArgument("path"), tool: "not_a_tool")
        XCTAssertTrue(text.contains("\"path\""), text)
    }
}
