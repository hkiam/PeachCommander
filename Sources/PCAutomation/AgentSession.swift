// SPDX-License-Identifier: Apache-2.0
// AgentSession.swift - the agent orchestration loop.
//
// One conversation with a ModelProvider that drives the file manager through the
// Automation Core: it asks the model for the next move, runs any tool calls (under
// the session's PermissionPolicy), feeds the results back, and repeats until the
// model produces a final text answer. Gated write/delete/config calls stop the loop
// and surface a plan for the user to confirm (plan-then-confirm), after which the
// loop resumes. Provider- and UI-agnostic; unit-tested with a scripted mock.

import Foundation

/// A provider that runs a whole turn natively (model + tool loop + plan-then-confirm)
/// and returns the final answer — e.g. Apple FoundationModels native tool-calling.
/// When set on a session, it replaces the manual respond-loop for that session.
public protocol NativeTurnRunner: Sendable {
    func runTurn(_ text: String, policy: PermissionPolicy) async throws -> String
    /// Read a file and guided-generate a Markdown table from it (nil = unsupported).
    func makeTable(fromFile path: String) async throws -> String?
}

public extension NativeTurnRunner {
    func makeTable(fromFile path: String) async throws -> String? { nil }
}

public actor AgentSession {
    public let id: String
    public private(set) var title: String
    private let core: AutomationCore
    private let provider: ModelProvider
    private var policy: PermissionPolicy
    private let maxToolIterations: Int
    private let nativeRunner: (any NativeTurnRunner)?
    public private(set) var history: [ModelMessage]

    public init(id: String = UUID().uuidString, title: String = "New chat",
                core: AutomationCore, provider: ModelProvider,
                policy: PermissionPolicy = .standard, systemPrompt: String? = nil,
                maxToolIterations: Int = 8, nativeRunner: (any NativeTurnRunner)? = nil) {
        self.id = id
        self.title = title
        self.core = core
        self.provider = provider
        self.policy = policy
        self.maxToolIterations = maxToolIterations
        self.nativeRunner = nativeRunner
        self.history = systemPrompt.map { [ModelMessage(role: .system, content: $0)] } ?? []
    }

    /// Restore a saved conversation.
    public init(restoring snapshot: Snapshot, core: AutomationCore, provider: ModelProvider,
                policy: PermissionPolicy = .standard, maxToolIterations: Int = 8,
                nativeRunner: (any NativeTurnRunner)? = nil) {
        self.id = snapshot.id
        self.title = snapshot.title
        self.core = core
        self.provider = provider
        self.policy = policy
        self.maxToolIterations = maxToolIterations
        self.nativeRunner = nativeRunner
        self.history = snapshot.messages
    }

    public func setPolicy(_ p: PermissionPolicy) { policy = p }
    public func rename(_ newTitle: String) { title = newTitle }
    public var messageCount: Int { history.count }

    /// Optional progress hook: called with each tool name as the loop runs it, so a UI
    /// can show what the assistant is doing during a multi-step turn (instead of a
    /// silent spinner). Cleared automatically is the caller's responsibility.
    private var onProgress: (@Sendable (String) async -> Void)?
    public func setProgressHandler(_ handler: (@Sendable (String) async -> Void)?) { onProgress = handler }

    /// Optional streaming hook: when set and the provider supports streaming, the loop
    /// streams the growing final answer through this (KI-08).
    private var onPartial: (@Sendable (String) async -> Void)?
    public func setPartialHandler(_ handler: (@Sendable (String) async -> Void)?) { onPartial = handler }

    /// A serializable snapshot of the whole conversation (for "historisch speichern").
    public struct Snapshot: Codable, Sendable, Equatable {
        public var id: String
        public var title: String
        public var messages: [ModelMessage]
        public init(id: String, title: String, messages: [ModelMessage]) {
            self.id = id; self.title = title; self.messages = messages
        }
    }

    public func snapshot() -> Snapshot { Snapshot(id: id, title: title, messages: history) }

    /// One plan awaiting user confirmation before it runs.
    public struct PendingPlan: Sendable, Equatable {
        public let tool: String
        public let plan: String
        public let token: String
    }

    public enum Result: Sendable, Equatable {
        case answer(String)
        case needsConfirmation([PendingPlan])
        case stopped(String)
    }

    /// Send a user message and run the agent loop to a result.
    public func send(_ userText: String) async throws -> Result {
        history.append(ModelMessage(role: .user, content: userText))
        // Native path: the runner drives the model + tool loop + plan-then-confirm
        // (via its own broker) and returns the final answer; the manual loop is skipped.
        if let nativeRunner {
            let answer = try await nativeRunner.runTurn(userText, policy: policy)
            history.append(ModelMessage(role: .assistant, content: answer))
            return .answer(answer)
        }
        return try await runLoop()
    }

    /// Read a file and append a guided-generated Markdown table as the answer (KI-09).
    /// Falls back to a normal turn if the runner can't do structured generation.
    public func makeTableFromFile(_ path: String, displayName: String) async throws -> Result {
        history.append(ModelMessage(role: .user, content: "Make a table from \(displayName)."))
        if let md = try await nativeRunner?.makeTable(fromFile: path) {
            history.append(ModelMessage(role: .assistant, content: md))
            return .answer(md)
        }
        return try await runLoop()
    }

    /// Confirm previously surfaced plans (their tokens) and resume the loop.
    public func confirm(tokens: [String]) async throws -> Result {
        for token in tokens {
            let outcome = try await core.confirm(token: token)
            history.append(toolMessage(name: "pc_confirm", id: token, outcome: outcome))
        }
        return try await runLoop()
    }

    // MARK: - Loop

    private func runLoop() async throws -> Result {
        var iterations = 0
        while iterations < maxToolIterations {
            iterations += 1
            let reply: ModelReply
            if let streaming = provider as? StreamingModelProvider, let onPartial {
                reply = try await streaming.respondStreaming(messages: history, tools: core.tools, onPartial: onPartial)
            } else {
                reply = try await provider.respond(messages: history, tools: core.tools)
            }
            switch reply {
            case .text(let text):
                history.append(ModelMessage(role: .assistant, content: text))
                return .answer(text)
            case .toolCalls(let calls):
                history.append(ModelMessage(role: .assistant,
                                            content: "[tool calls: \(calls.map(\.name).joined(separator: ", "))]"))
                var plans: [PendingPlan] = []
                for call in calls {
                    await onProgress?(call.name)
                    // A hallucinated/unknown tool or bad args must not abort the session:
                    // feed the error back so the model can recover on the next turn.
                    let outcome: AutomationOutcome
                    do {
                        outcome = try await core.invoke(tool: call.name, arguments: call.argumentsJSON, policy: policy)
                    } catch {
                        history.append(toolMessage(name: call.name, id: call.id,
                                                   outcome: .failed(error: "\(error)")))
                        continue
                    }
                    if case .needsConfirmation(let plan, let token) = outcome {
                        plans.append(PendingPlan(tool: call.name, plan: plan, token: token))
                    } else {
                        history.append(toolMessage(name: call.name, id: call.id, outcome: outcome))
                    }
                }
                if !plans.isEmpty { return .needsConfirmation(plans) }
                // otherwise loop again, feeding the tool results back to the model
            }
        }
        return .stopped("Reached the tool-iteration limit (\(maxToolIterations)).")
    }

    private func toolMessage(name: String, id: String, outcome: AutomationOutcome) -> ModelMessage {
        let text: String
        switch outcome {
        case .ok(let payload):            text = payload.flatMap { String(data: $0, encoding: .utf8) } ?? "OK"
        case .needsConfirmation(let p, _): text = "Confirmation required: \(p)"
        case .refused(let reason):        text = "Refused: \(reason)"
        case .failed(let error):          text = "Failed: \(error)"
        }
        return ModelMessage(role: .tool, content: text, toolName: name, toolCallId: id)
    }
}
