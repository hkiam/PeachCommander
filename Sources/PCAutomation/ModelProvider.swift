// ModelProvider.swift - the LLM abstraction the agent talks to.
//
// A provider turns a conversation + the available tools into the model's next move:
// either a final text reply or a batch of tool calls. Keeping this provider-agnostic
// lets the same AgentSession orchestration run on Apple Foundation Models (local),
// cloud models, or a local OpenAI-compatible server — and be unit-tested with a
// scripted mock. See docs/analysis/ai-agent-plugin-plan.md §4.

import Foundation

public enum ModelRole: String, Codable, Sendable {
    case system, user, assistant, tool
}

/// One message in the conversation. Tool-result messages carry the `toolName` and
/// `toolCallId` they answer.
public struct ModelMessage: Codable, Sendable, Equatable {
    public var role: ModelRole
    public var content: String
    public var toolName: String?
    public var toolCallId: String?
    public init(role: ModelRole, content: String, toolName: String? = nil, toolCallId: String? = nil) {
        self.role = role; self.content = content; self.toolName = toolName; self.toolCallId = toolCallId
    }
}

/// A tool the model wants to call. `argumentsJSON` is the JSON object of arguments,
/// ready to pass to `AutomationCore.invoke`.
public struct ModelToolCall: Codable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var argumentsJSON: Data
    public init(id: String, name: String, argumentsJSON: Data) {
        self.id = id; self.name = name; self.argumentsJSON = argumentsJSON
    }
}

/// The model's next move.
public enum ModelReply: Sendable, Equatable {
    case text(String)
    case toolCalls([ModelToolCall])
}

public protocol ModelProvider: Sendable {
    /// A short identifier (e.g. "apple-foundation-models", "anthropic").
    var name: String { get }
    /// Whether this provider can be used right now (model available / configured).
    var isAvailable: Bool { get async }
    /// Produce the next reply given the conversation so far and the tools the model
    /// may call (advertised as the Automation Core catalogue).
    func respond(messages: [ModelMessage], tools: [ToolDefinition]) async throws -> ModelReply
}

/// A provider that can stream a final text answer token-by-token (KI-08). The loop
/// prefers this when a partial handler is set; `onPartial` receives the growing answer
/// (never a `TOOL:` tool-call line).
public protocol StreamingModelProvider: ModelProvider {
    func respondStreaming(messages: [ModelMessage], tools: [ToolDefinition],
                          onPartial: @escaping @Sendable (String) async -> Void) async throws -> ModelReply
}

public enum ModelError: Error, Sendable, Equatable {
    case unavailable(String)
    case failed(String)
}
