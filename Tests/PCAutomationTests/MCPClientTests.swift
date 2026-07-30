import XCTest
@testable import PCAutomation

final class MCPClientTests: XCTestCase {
    /// A scripted external MCP server: answers initialize / tools/list / tools/call.
    private func scripted() -> MCPClient.Transport {
        { reqData in
            let req = (try? JSONSerialization.jsonObject(with: reqData)) as? [String: Any] ?? [:]
            let id = req["id"] ?? 0
            var result: [String: Any] = [:]
            switch req["method"] as? String {
            case "initialize": result = ["protocolVersion": "2024-11-05"]
            case "tools/list": result = ["tools": [["name": "echo", "description": "Echo text"]]]
            case "tools/call":
                let args = (req["params"] as? [String: Any])?["arguments"] as? [String: Any] ?? [:]
                result = ["content": [["type": "text", "text": "echo: \(args["text"] as? String ?? "")"]]]
            default: break
            }
            return try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": id, "result": result])
        }
    }

    func test_initializeAndListTools() async throws {
        let c = MCPClient(transport: scripted())
        try await c.initialize()
        let tools = try await c.listTools()
        XCTAssertEqual(tools, [MCPToolInfo(name: "echo", description: "Echo text")])
    }

    func test_callTool_returnsTextContent() async throws {
        let c = MCPClient(transport: scripted())
        let out = try await c.callTool(name: "echo", arguments: ["text": "hi"])
        XCTAssertEqual(out, "echo: hi")
    }

    // Full round-trip over a real loopback socket against our own MCPSocketServer.
    func test_endToEnd_overLoopbackSocket() async throws {
        final class PortBox: @unchecked Sendable { var port: UInt16 = 0 }
        let server = MCPSocketServer(mcp: MCPServer(core: DefaultAutomationCore(bridge: FakeBridge())))
        let box = PortBox()
        try server.start(port: 0) { box.port = $0 }
        defer { server.stop() }
        for _ in 0..<50 where box.port == 0 { try await Task.sleep(nanoseconds: 100_000_000) }
        XCTAssertNotEqual(box.port, 0, "server did not bind")

        let client = MCPClient(host: "127.0.0.1", port: box.port)
        try await client.initialize()
        let tools = try await client.listTools()
        XCTAssertTrue(tools.contains { $0.name == "get_context" }, "expected the automation tools")
        let ctx = try await client.callTool(name: "get_context", arguments: [:])
        XCTAssertFalse(ctx.isEmpty, "get_context should return the UI context")
    }

    func test_rpcError_isThrown() async {
        let t: MCPClient.Transport = { _ in
            try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": 1, "error": ["message": "boom"]])
        }
        let c = MCPClient(transport: t)
        do { _ = try await c.listTools(); XCTFail("expected throw") }
        catch MCPClientError.rpc(let m) { XCTAssertEqual(m, "boom") }
        catch { XCTFail("wrong error \(error)") }
    }
}
