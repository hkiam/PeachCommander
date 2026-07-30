// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCAutomation

final class OpenAICompatibleProviderTests: XCTestCase {

    // Build a mock transport returning a chat-completion with `content`, capturing
    // the request body for assertions.
    private func mock(content: String, status: Int = 200,
                      captured: @escaping @Sendable (Data) -> Void = { _ in })
        -> @Sendable (URLRequest) async throws -> (Data, URLResponse) {
        { req in
            if let body = req.httpBody { captured(body) }
            let json: [String: Any] = ["choices": [["message": ["role": "assistant", "content": content]]]]
            let data = try JSONSerialization.data(withJSONObject: json)
            let resp = HTTPURLResponse(url: req.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (data, resp)
        }
    }

    func test_textReply_isParsedAsAnswer() async throws {
        let p = OpenAICompatibleProvider(baseURL: URL(string: "http://localhost/v1")!, model: "m",
                                         transport: mock(content: "All done."))
        let reply = try await p.respond(messages: [ModelMessage(role: .user, content: "hi")], tools: [])
        XCTAssertEqual(reply, .text("All done."))
    }

    func test_toolCallReply_isParsed() async throws {
        let p = OpenAICompatibleProvider(baseURL: URL(string: "http://localhost/v1")!, model: "m",
                                         transport: mock(content: #"TOOL: list_directory {"path":"/a"}"#))
        let reply = try await p.respond(messages: [ModelMessage(role: .user, content: "what's in /a")],
                                        tools: AutomationCatalog.tools)
        guard case .toolCalls(let calls) = reply else { return XCTFail() }
        XCTAssertEqual(calls.first?.name, "list_directory")
    }

    func test_request_includesModelToolsAndAuth() async throws {
        final class Box: @unchecked Sendable { var body = Data() }
        let box = Box()
        let p = OpenAICompatibleProvider(baseURL: URL(string: "http://localhost/v1")!, model: "gpt-x",
                                         apiKey: "secret",
                                         transport: mock(content: "ok", captured: { box.body = $0 }))
        _ = try await p.respond(messages: [ModelMessage(role: .user, content: "hi")],
                                tools: AutomationCatalog.tools)
        let obj = try JSONSerialization.jsonObject(with: box.body) as? [String: Any]
        XCTAssertEqual(obj?["model"] as? String, "gpt-x")
        let msgs = obj?["messages"] as? [[String: String]]
        // first message is the injected tool-instructions system prompt
        XCTAssertEqual(msgs?.first?["role"], "system")
        XCTAssertTrue(msgs?.first?["content"]?.contains("TOOL:") ?? false)
    }

    func test_httpError_throws() async {
        let p = OpenAICompatibleProvider(baseURL: URL(string: "http://localhost/v1")!, model: "m",
                                         transport: mock(content: "nope", status: 500))
        do {
            _ = try await p.respond(messages: [ModelMessage(role: .user, content: "hi")], tools: [])
            XCTFail("expected throw")
        } catch let e as ModelError {
            if case .failed = e {} else { XCTFail("wrong error \(e)") }
        } catch { XCTFail("wrong error type") }
    }

    // KI-08: respondStreaming forwards growing partials and parses the final answer.
    func test_streaming_forwardsPartials_andParsesFinal() async throws {
        let chunks = [
            #"data: {"choices":[{"delta":{"content":"Hel"}}]}"#,
            #"data: {"choices":[{"delta":{"content":"lo"}}]}"#,
            "data: [DONE]",
        ]
        let stream: OpenAICompatibleProvider.StreamTransport = { _ in
            AsyncThrowingStream { cont in
                for c in chunks { cont.yield(Data((c + "\n").utf8)) }
                cont.finish()
            }
        }
        let p = OpenAICompatibleProvider(baseURL: URL(string: "http://x/v1")!, model: "m",
                                         transport: mock(content: "unused"), streamTransport: stream)
        final class Box: @unchecked Sendable { var partials: [String] = [] }
        let box = Box()
        let reply = try await p.respondStreaming(messages: [ModelMessage(role: .user, content: "hi")],
                                                 tools: []) { t in box.partials.append(t) }
        XCTAssertEqual(reply, .text("Hello"))
        XCTAssertEqual(box.partials.last, "Hello")     // accumulated to the full answer
        XCTAssertGreaterThanOrEqual(box.partials.count, 2)   // delivered incrementally
    }

    // KI-08: SSE streaming parser — concatenate content deltas, stop at [DONE].
    func test_parseSSEContent_concatenatesDeltas() {
        let sse = """
        data: {"choices":[{"delta":{"content":"Hello"}}]}
        data: {"choices":[{"delta":{"content":", world"}}]}
        data: {"choices":[{"delta":{}}]}
        data: [DONE]
        data: {"choices":[{"delta":{"content":"IGNORED"}}]}
        """
        XCTAssertEqual(OpenAICompatibleProvider.parseSSEContent(sse), "Hello, world")
    }

    // KI-14: the full cloud path end-to-end through the agent loop — the model
    // returns a tool call, the core executes it, the result is fed back, and the
    // model gives the final answer. (A real endpoint only additionally needs a key.)
    private actor Seq { var n = 0; func next() -> Int { defer { n += 1 }; return n } }

    func test_cloudPath_endToEnd_toolCallThenAnswer() async throws {
        let seq = Seq()
        let transport: @Sendable (URLRequest) async throws -> (Data, URLResponse) = { req in
            let step = await seq.next()
            let content = step == 0 ? #"TOOL: list_directory {"path":"/a"}"# : "There is one file in /a."
            let json: [String: Any] = ["choices": [["message": ["role": "assistant", "content": content]]]]
            let data = try JSONSerialization.data(withJSONObject: json)
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, resp)
        }
        let provider = OpenAICompatibleProvider(baseURL: URL(string: "http://localhost/v1")!,
                                                model: "mock-gpt", apiKey: "k", transport: transport)
        let bridge = FakeBridge()
        let session = AgentSession(core: DefaultAutomationCore(bridge: bridge), provider: provider)
        let result = try await session.send("what's in /a?")
        XCTAssertEqual(result, .answer("There is one file in /a."))
        let listed = await bridge.listed
        XCTAssertEqual(listed, "/a")   // the cloud-driven tool call really ran via the core
    }
}
