// SPDX-License-Identifier: Apache-2.0
// Tests for the MCP protocol adapter over the Automation Core (reuses FakeBridge
// from DefaultAutomationCoreTests). Verifies JSON-RPC framing, tools/list, tools/call,
// and the gated write -> pc_confirm flow.

import XCTest
@testable import PCAutomation

final class MCPServerTests: XCTestCase {

    private func req(_ dict: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: dict)
    }
    private func decode(_ data: Data?) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data ?? Data())) as? [String: Any] ?? [:]
    }
    private func makeServer(_ bridge: FakeBridge = FakeBridge()) -> MCPServer {
        MCPServer(core: DefaultAutomationCore(bridge: bridge))
    }

    func test_initialize_returnsProtocolAndServerInfo() async {
        let resp = decode(await makeServer().handle(req(["jsonrpc": "2.0", "id": 1, "method": "initialize"])))
        XCTAssertEqual(resp["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(resp["id"] as? Int, 1)
        let result = resp["result"] as? [String: Any]
        XCTAssertEqual(result?["protocolVersion"] as? String, MCPServer.protocolVersion)
        let info = result?["serverInfo"] as? [String: Any]
        XCTAssertEqual(info?["name"] as? String, "peach-commander")
    }

    func test_initializedNotification_returnsNil() async {
        let out = await makeServer().handle(req(["jsonrpc": "2.0", "method": "notifications/initialized"]))
        XCTAssertNil(out)
    }

    func test_toolsList_includesCatalogueAndConfirm() async {
        let resp = decode(await makeServer().handle(req(["jsonrpc": "2.0", "id": 2, "method": "tools/list"])))
        let tools = (resp["result"] as? [String: Any])?["tools"] as? [[String: Any]] ?? []
        let names = tools.compactMap { $0["name"] as? String }
        // The catalogue, minus what is deliberately withheld from remote clients, plus pc_confirm.
        // Written as the subtraction rather than as a number so that adding a tool does not silently
        // become "and it is offered over MCP too" — the withholding is a decision, and this is where
        // it is recorded. See MCPServer.notOfferedRemotely.
        let withheld = AutomationCatalog.tools.filter { MCPServer.notOfferedRemotely.contains($0.capability) }
        XCTAssertEqual(tools.count, AutomationCatalog.tools.count - withheld.count + 1)
        XCTAssertFalse(withheld.isEmpty, "if nothing is withheld any more, that was a decision too")
        XCTAssertTrue(names.contains("get_context"))
        XCTAssertTrue(names.contains("copy"))
        XCTAssertTrue(names.contains("pc_confirm"))
        // each tool carries an inputSchema
        XCTAssertNotNil(tools.first?["inputSchema"])
    }

    func test_toolsCall_read_returnsContent() async {
        let resp = decode(await makeServer().handle(req([
            "jsonrpc": "2.0", "id": 3, "method": "tools/call",
            "params": ["name": "get_context", "arguments": [:]]])))
        let result = resp["result"] as? [String: Any]
        XCTAssertEqual(result?["isError"] as? Bool, false)
        let content = result?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String ?? ""
        XCTAssertTrue(text.contains("activePanelPath"))
    }

    func test_toolsCall_unknownTool_isError() async {
        let resp = decode(await makeServer().handle(req([
            "jsonrpc": "2.0", "id": 4, "method": "tools/call",
            "params": ["name": "frobnicate", "arguments": [:]]])))
        let result = resp["result"] as? [String: Any]
        XCTAssertEqual(result?["isError"] as? Bool, true)
    }

    func test_gatedWrite_thenConfirm_executes() async throws {
        let bridge = FakeBridge()
        let server = MCPServer(core: DefaultAutomationCore(bridge: bridge))   // default .standard policy

        // 1) copy is gated -> confirmation text with a token, not executed
        let call = decode(await server.handle(req([
            "jsonrpc": "2.0", "id": 5, "method": "tools/call",
            "params": ["name": "copy", "arguments": ["sources": ["/a/f.txt"], "destination": "/b"]]])))
        let text = ((call["result"] as? [String: Any])?["content"] as? [[String: Any]])?.first?["text"] as? String ?? ""
        XCTAssertTrue(text.contains("Confirmation required"))
        XCTAssertTrue(text.contains("pc_confirm"))
        let copiedBefore = await bridge.copied
        XCTAssertNil(copiedBefore)

        // extract the token from: ... token "<token>" to proceed.
        let afterToken = try XCTUnwrap(text.components(separatedBy: "token \"").last)
        let token = try XCTUnwrap(afterToken.components(separatedBy: "\"").first)
        XCTAssertFalse(token.isEmpty)

        // 2) pc_confirm executes it
        let confirm = decode(await server.handle(req([
            "jsonrpc": "2.0", "id": 6, "method": "tools/call",
            "params": ["name": "pc_confirm", "arguments": ["token": token]]])))
        XCTAssertEqual((confirm["result"] as? [String: Any])?["isError"] as? Bool, false)
        let copied = await bridge.copied
        XCTAssertEqual(copied?.dest, "/b")
    }

    /// Hiding a tool and refusing it by name is a check on the *name*, and a macro is a different
    /// name for the same capability: `run_macro` is declared `.write`, so it is offered, and its steps
    /// go straight back through the Core. A macro holding a `run_shell` step was therefore reachable
    /// from a socket on any installation that had switched the shell on — past the one rule that says
    /// a remote client cannot get there. The capability is now withheld from the session, so the route
    /// does not matter.
    func test_aMacroCannotCarryAWithheldCapabilityOverMCP() async throws {
        let bridge = FakeBridge()
        let shellMacro = Macro(id: "sh", title: "Shell", steps: [
            MacroStep(tool: "run_shell", arguments: ["command": .text("echo hi")])])
        let core = DefaultAutomationCore(bridge: bridge, macros: { [shellMacro] })
        // A session whose policy grants everything, the way the host builds it when the user has
        // switched the shell on in Settings.
        let server = MCPServer(core: core, policy: PermissionPolicy(autonomy: .autonomous))
        let resp = decode(await server.handle(req([
            "jsonrpc": "2.0", "id": 9, "method": "tools/call",
            "params": ["name": "run_macro", "arguments": ["macro_id": "sh"]]])))
        let result = resp["result"] as? [String: Any]
        XCTAssertEqual(result?["isError"] as? Bool, true, "\(resp)")
        let ranShell = await bridge.ranShell
        XCTAssertNil(ranShell, "the shell must not have run")
    }

    /// A macro that asks a human cannot be run from a socket, and the refusal says so rather than the
    /// run quietly taking every default. The bridge's own answer decides this — `askForValues` returns
    /// nil where there is nobody — so it holds for any transport without a person attached.
    func test_aMacroThatAsksIsRefusedOverMCP() async throws {
        let bridge = FakeBridge()
        await bridge.setAskAnswers(nil)
        let asking = Macro(id: "ask", title: "Ask", steps: [
            MacroStep(tool: "make_directory", arguments: ["path": .text("%T/%{ask:Folder=Archive}")])])
        let core = DefaultAutomationCore(bridge: bridge, macros: { [asking] })
        let server = MCPServer(core: core, policy: PermissionPolicy(autonomy: .autonomous))
        let resp = decode(await server.handle(req([
            "jsonrpc": "2.0", "id": 11, "method": "tools/call",
            "params": ["name": "run_macro", "arguments": ["macro_id": "ask"]]])))
        let result = resp["result"] as? [String: Any]
        XCTAssertEqual(result?["isError"] as? Bool, true, "\(resp)")
        let madeDir = await bridge.madeDir
        XCTAssertNil(madeDir, "and the default was not silently taken")
    }

    func test_unknownMethod_returnsMethodNotFound() async {
        let resp = decode(await makeServer().handle(req(["jsonrpc": "2.0", "id": 7, "method": "no/such"])))
        let error = resp["error"] as? [String: Any]
        XCTAssertEqual(error?["code"] as? Int, -32601)
    }

    func test_parseError_returnsError() async {
        let resp = decode(await makeServer().handle(Data("{ not json".utf8)))
        let error = resp["error"] as? [String: Any]
        XCTAssertEqual(error?["code"] as? Int, -32700)
    }
}
