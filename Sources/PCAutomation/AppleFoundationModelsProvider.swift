// SPDX-License-Identifier: Apache-2.0
// AppleFoundationModelsProvider.swift - the on-device (local) model provider.
//
// Uses Apple's FoundationModels framework (macOS 26+, Apple Silicon) so the default
// agent experience is fully local, private, offline and free — the ki.md default.
// The whole type is @available(macOS 26, *); on older systems the host simply offers
// a different provider (the framework is weak-linked, so the app still runs on 13+).
//
// v1 is text-only: it feeds the conversation to the on-device model and returns the
// text answer. Native tool-calling via the FoundationModels `Tool` protocol (so the
// local model can drive the Automation Core directly) is a documented follow-up; the
// AgentSession loop already works with any provider that emits tool calls.

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
@available(macOS 26, *)
public struct AppleFoundationModelsProvider: ModelProvider {
    public let name = "apple-foundation-models"

    public init() {}

    public var isAvailable: Bool {
        get async {
            if case .available = SystemLanguageModel.default.availability { return true }
            return false
        }
    }

    public func respond(messages: [ModelMessage], tools: [ToolDefinition]) async throws -> ModelReply {
        guard case .available = SystemLanguageModel.default.availability else {
            throw ModelError.unavailable("Apple Intelligence is not available on this Mac.")
        }
        // Teach the on-device model our tool-call convention so it can actually drive
        // the file manager (read/search/etc.), then parse its reply back into a move.
        var system = messages.first { $0.role == .system }?.content ?? ""
        if !tools.isEmpty {
            system += (system.isEmpty ? "" : "\n\n") + ToolCallProtocol.instructions(for: tools)
        }
        let prompt = messages
            .filter { $0.role != .system }
            .map { "\($0.role.rawValue.uppercased()): \($0.content)" }
            .joined(separator: "\n")
        do {
            let session = LanguageModelSession(instructions: system.isEmpty ? nil : system)
            session.prewarm()   // warm the on-device model to cut first-token latency
            let response = try await session.respond(to: prompt)
            return ToolCallProtocol.parse(response.content)
        } catch {
            throw ModelError.failed(error.localizedDescription)
        }
    }
}
#endif
