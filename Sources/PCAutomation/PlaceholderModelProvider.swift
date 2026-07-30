// PlaceholderModelProvider.swift - the "no model configured yet" provider.
//
// Used when no real model is available (Apple Intelligence not set up and no cloud
// provider configured) so the chat UI is still usable and self-explanatory. It never
// calls tools; it just echoes guidance plus the user's message.

import Foundation

public struct PlaceholderModelProvider: ModelProvider {
    public let name = "placeholder"
    public init() {}
    public var isAvailable: Bool { get async { true } }

    public func respond(messages: [ModelMessage], tools: [ToolDefinition]) async throws -> ModelReply {
        let lastUser = messages.last { $0.role == .user }?.content ?? ""
        return .text("""
        No language model is configured yet. Enable Apple Intelligence (macOS 26) or add a \
        provider in Settings, then this assistant can act on \(tools.count) file-manager tools.

        You said: "\(lastUser)"
        """)
    }
}
