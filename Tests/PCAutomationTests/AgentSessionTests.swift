// Tests for the agent orchestration loop, using a scripted mock provider and a
// DefaultAutomationCore over the FakeBridge (from DefaultAutomationCoreTests).

import XCTest
@testable import PCAutomation

/// A provider that returns pre-scripted replies in order.
actor ScriptedProvider: ModelProvider {
    nonisolated let name = "mock"
    var isAvailable: Bool { true }
    private let script: [ModelReply]
    private var index = 0
    init(_ script: [ModelReply]) { self.script = script }
    func respond(messages: [ModelMessage], tools: [ToolDefinition]) -> ModelReply {
        defer { index += 1 }
        return index < script.count ? script[index] : .text("done")
    }
}

/// A provider that always asks to call the same read tool (to hit the iteration cap).
actor LoopingProvider: ModelProvider {
    nonisolated let name = "loop"
    var isAvailable: Bool { true }
    func respond(messages: [ModelMessage], tools: [ToolDefinition]) -> ModelReply {
        .toolCalls([AgentSessionTests.call("list_directory", ["path": "/a"])])
    }
}

final class AgentSessionTests: XCTestCase {

    static func call(_ name: String, _ args: [String: Any] = [:]) -> ModelToolCall {
        ModelToolCall(id: "c-\(name)", name: name,
                      argumentsJSON: try! JSONSerialization.data(withJSONObject: args))
    }

    func test_plainTextReply_returnsAnswer() async throws {
        let session = AgentSession(core: DefaultAutomationCore(bridge: FakeBridge()),
                                   provider: ScriptedProvider([.text("Hello!")]))
        let result = try await session.send("hi")
        XCTAssertEqual(result, .answer("Hello!"))
    }

    func test_readToolCall_thenAnswer_executesToolAndLoops() async throws {
        let bridge = FakeBridge()
        let session = AgentSession(core: DefaultAutomationCore(bridge: bridge),
                                   provider: ScriptedProvider([
                                        .toolCalls([Self.call("list_directory", ["path": "/a"])]),
                                        .text("There is one file."),
                                   ]))
        let result = try await session.send("what is in /a?")
        XCTAssertEqual(result, .answer("There is one file."))
        let listed = await bridge.listed
        XCTAssertEqual(listed, "/a")   // the tool actually ran via the core
    }

    func test_gatedWrite_surfacesPlan_thenConfirmExecutes() async throws {
        let bridge = FakeBridge()
        let session = AgentSession(core: DefaultAutomationCore(bridge: bridge),
                                   provider: ScriptedProvider([
                                        .toolCalls([Self.call("copy", ["sources": ["/a/f.txt"], "destination": "/b"])]),
                                        .text("Copied."),
                                   ]))   // default policy = confirm-writes

        let first = try await session.send("copy f.txt to /b")
        guard case .needsConfirmation(let plans) = first else { return XCTFail("expected needsConfirmation, got \(first)") }
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans.first?.tool, "copy")
        let before = await bridge.copied
        XCTAssertNil(before, "must not copy before confirmation")

        let after = try await session.confirm(tokens: plans.map(\.token))
        XCTAssertEqual(after, .answer("Copied."))
        let copied = await bridge.copied
        XCTAssertEqual(copied?.dest, "/b")
    }

    func test_readOnlyPolicy_refusesWrite_loopContinues() async throws {
        let bridge = FakeBridge()
        let session = AgentSession(core: DefaultAutomationCore(bridge: bridge),
                                   provider: ScriptedProvider([
                                        .toolCalls([Self.call("copy", ["sources": ["/a"], "destination": "/b"])]),
                                        .text("I could not copy (read-only)."),
                                   ]),
                                   policy: .readOnly)
        let result = try await session.send("copy it")
        // refused is fed back to the model as a tool result; the model then answers
        XCTAssertEqual(result, .answer("I could not copy (read-only)."))
        let copied = await bridge.copied
        XCTAssertNil(copied)
    }

    func test_unknownToolFromModel_isFedBack_notThrown() async throws {
        // The model hallucinates a bad tool name on turn 1, then answers on turn 2.
        let session = AgentSession(core: DefaultAutomationCore(bridge: FakeBridge()),
                                   provider: ScriptedProvider([
                                        .toolCalls([Self.call("no_such_tool", ["x": 1])]),
                                        .text("Sorry, I used a wrong tool; here is the answer."),
                                   ]))
        let result = try await session.send("do something")   // must not throw
        XCTAssertEqual(result, .answer("Sorry, I used a wrong tool; here is the answer."))
    }

    func test_semanticSearchTool_isDispatchedAsRead() async throws {
        let core = DefaultAutomationCore(bridge: FakeBridge())
        let outcome = try await core.invoke(tool: "semantic_search",
                                            arguments: Data(#"{"query":"budget report"}"#.utf8),
                                            policy: .readOnly)   // read capability → allowed
        guard case .ok = outcome else { return XCTFail("expected .ok, got \(outcome)") }
    }

    func test_nativeRunner_delegatesWholeTurn() async throws {
        struct MockNative: NativeTurnRunner {
            func runTurn(_ text: String, policy: PermissionPolicy) async throws -> String { "native: \(text)" }
        }
        let session = AgentSession(core: DefaultAutomationCore(bridge: FakeBridge()),
                                   provider: ScriptedProvider([]), nativeRunner: MockNative())
        let result = try await session.send("hello")
        XCTAssertEqual(result, .answer("native: hello"))
        let count = await session.messageCount
        XCTAssertEqual(count, 2)   // user + assistant, loop skipped
    }

    func test_progressHandler_reportsToolNames() async throws {
        let session = AgentSession(core: DefaultAutomationCore(bridge: FakeBridge()),
                                   provider: ScriptedProvider([
                                        .toolCalls([Self.call("list_directory", ["path": "/a"])]),
                                        .text("Done."),
                                   ]))
        let box = ToolNameBox()
        await session.setProgressHandler { name in await box.add(name) }
        _ = try await session.send("what is in /a?")
        let names = await box.names
        XCTAssertEqual(names, ["list_directory"])
    }

    /// Sendable sink for progress-handler names.
    private actor ToolNameBox {
        private(set) var names: [String] = []
        func add(_ n: String) { names.append(n) }
    }

    func test_iterationCap_stops() async throws {
        let session = AgentSession(core: DefaultAutomationCore(bridge: FakeBridge()),
                                   provider: LoopingProvider(), maxToolIterations: 3)
        let result = try await session.send("loop forever")
        guard case .stopped = result else { return XCTFail("expected stopped, got \(result)") }
    }

    func test_systemPrompt_isRecorded() async throws {
        let session = AgentSession(core: DefaultAutomationCore(bridge: FakeBridge()),
                                   provider: ScriptedProvider([.text("ok")]),
                                   systemPrompt: "You are helpful.")
        _ = try await session.send("hi")
        let count = await session.messageCount
        XCTAssertGreaterThanOrEqual(count, 3)   // system + user + assistant
    }
}
