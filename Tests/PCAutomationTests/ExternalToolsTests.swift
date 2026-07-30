import XCTest
@testable import PCAutomation

// KI-06: the core can host plugin-contributed tools (extra catalogue entries routed
// to an external handler), still under the permission policy.
final class ExternalToolsTests: XCTestCase {
    private let echoTool = ToolDefinition("plugin.echo", .read, "Echo the text back.",
                                          [ToolParameter("text", .string, "text")])

    func test_externalTool_appearsInCatalogue_andRoutes() async throws {
        let core = DefaultAutomationCore(
            bridge: FakeBridge(),
            externalTools: [echoTool],
            externalRouter: { name, args in
                guard name == "plugin.echo" else { return nil }
                let obj = (try? JSONSerialization.jsonObject(with: args ?? Data())) as? [String: Any]
                let text = obj?["text"] as? String ?? ""
                return .ok(payload: Data(#"{"echo":"\#(text)"}"#.utf8))
            })
        XCTAssertTrue(core.tools.contains { $0.name == "plugin.echo" })   // merged into the catalogue
        let outcome = try await core.invoke(tool: "plugin.echo",
                                            arguments: Data(#"{"text":"hi"}"#.utf8), policy: .readOnly)
        guard case .ok(let payload) = outcome,
              let s = payload.flatMap({ String(data: $0, encoding: .utf8) }) else {
            return XCTFail("expected ok, got \(outcome)")
        }
        XCTAssertTrue(s.contains("\"echo\":\"hi\""), s)
    }

    func test_externalWriteTool_isPolicyGated() async throws {
        let writeTool = ToolDefinition("plugin.zap", .write, "Delete stuff.")
        let core = DefaultAutomationCore(bridge: FakeBridge(), externalTools: [writeTool],
                                         externalRouter: { _, _ in .ok(payload: nil) })
        // Under confirm-writes a contributed WRITE tool must be gated, not run.
        let outcome = try await core.invoke(tool: "plugin.zap", arguments: nil, policy: .standard)
        guard case .needsConfirmation = outcome else { return XCTFail("expected needsConfirmation, got \(outcome)") }
    }
}
