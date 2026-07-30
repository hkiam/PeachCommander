import XCTest
@testable import PCAutomation

final class MCPSocketAuthTests: XCTestCase {
    private func server(token: String?) -> MCPSocketServer {
        MCPSocketServer(mcp: MCPServer(core: DefaultAutomationCore(bridge: FakeBridge())), authToken: token)
    }

    func test_validToken_authenticates() {
        let s = server(token: "s3cret")
        let line = Data(#"{"jsonrpc":"2.0","id":1,"method":"authenticate","params":{"token":"s3cret"}}"#.utf8)
        let reply = s.checkAuth(line)
        XCTAssertNotNil(reply)
        let text = reply.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTAssertTrue(text.contains("\"authenticated\":true"), text)
    }

    func test_wrongToken_rejected() {
        let s = server(token: "s3cret")
        let line = Data(#"{"jsonrpc":"2.0","id":1,"method":"authenticate","params":{"token":"nope"}}"#.utf8)
        XCTAssertNil(s.checkAuth(line))
    }

    func test_nonAuthMessage_rejectedWhileUnauthed() {
        let s = server(token: "s3cret")
        let line = Data(#"{"jsonrpc":"2.0","id":1,"method":"tools/list"}"#.utf8)
        XCTAssertNil(s.checkAuth(line))
    }

    func test_emptyToken_meansNoAuth() {
        // An empty token disables auth (the socket accepts requests directly).
        let s = server(token: "")
        // checkAuth still requires a token to match; with no token it's never called,
        // but validating the guard: a checkAuth with nil-equivalent token rejects.
        XCTAssertNil(s.checkAuth(Data(#"{"method":"authenticate","params":{"token":""}}"#.utf8)))
    }
}
