// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCAutomation

#if canImport(FoundationModels)
final class AppleFoundationModelsProviderTests: XCTestCase {
    // Runs on the host (macOS 26): the provider must report availability without
    // crashing. The value depends on whether Apple Intelligence is set up, so we
    // only assert it returns and that the provider identifies itself.
    func test_provider_reportsAvailabilityWithoutCrashing() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("FoundationModels requires macOS 26") }
        let provider = AppleFoundationModelsProvider()
        XCTAssertEqual(provider.name, "apple-foundation-models")
        _ = await provider.isAvailable
    }

    // MARK: - Live on-device tests (opt-in: PC_AI_LIVE=1, needs Apple Intelligence)

    // Live tests run automatically when Apple Intelligence is available on the machine
    // (e.g. a developer Mac) and skip everywhere else (CI, the headless VM).
    @available(macOS 26, *)
    private func liveProviderOrSkip() async throws -> AppleFoundationModelsProvider {
        let p = AppleFoundationModelsProvider()
        guard await p.isAvailable else { throw XCTSkip("Apple Intelligence not available") }
        return p
    }

    func test_live_generatesText() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let p = try await liveProviderOrSkip()
        let reply = try await p.respond(messages: [ModelMessage(role: .user, content: "Say a one-sentence greeting.")], tools: [])
        guard case .text(let t) = reply else { return XCTFail("expected text, got \(reply)") }
        print("[live] FM text: \(t)")
        XCTAssertFalse(t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func test_live_emitsToolCall() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let p = try await liveProviderOrSkip()
        let reply = try await p.respond(
            messages: [ModelMessage(role: .user, content: "List the files in the folder /Users/tester/Documents. Use a tool to find out.")],
            tools: AutomationCatalog.tools)
        print("[live] FM reply: \(reply)")
        guard case .toolCalls(let calls) = reply else { return XCTFail("expected a tool call, got \(reply)") }
        XCTAssertEqual(calls.first?.name, "list_directory")
    }

    // Full agent loop with the REAL on-device model against an in-memory FakeBridge
    // (no real files touched) under a read-only policy — safe.
    func test_live_agentLoop_readOnly_overFakeBridge() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let p = try await liveProviderOrSkip()
        let session = AgentSession(core: DefaultAutomationCore(bridge: FakeBridge()), provider: p,
                                   policy: .readOnly,
                                   systemPrompt: "You help manage files. Use tools when needed, then answer briefly.")
        let result = try await session.send("List the files in /a using a tool, then tell me how many there are.")
        print("[live] agent result: \(result)")
        // Any non-throwing result (answer/stopped/needsConfirmation) is acceptable — even
        // an empty answer, since sanitizeAnswer may strip a fully-fabricated reply to "".
        // The point is the real model + real loop run end-to-end without touching real files.
    }
}
#endif
