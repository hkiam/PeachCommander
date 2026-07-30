// SPDX-License-Identifier: Apache-2.0
// OpenAICompatibleProvider.swift - a cloud / local-server model provider.
//
// Talks to any OpenAI-compatible /chat/completions endpoint (OpenAI, Anthropic via a
// gateway, Ollama, LM Studio, llama.cpp, …), so the agent works without Apple
// Intelligence. It reuses the uniform ToolCallProtocol (the model drives tools via
// the AgentSession loop), so no provider-specific function-calling is needed. The
// HTTP transport is injectable, making the provider fully unit-testable without a
// real network. API keys come from the environment, never from config files.

import Foundation

public struct OpenAICompatibleProvider: ModelProvider {
    public let name: String
    private let baseURL: URL
    private let model: String
    private let apiKey: String?
    private let transport: @Sendable (URLRequest) async throws -> (Data, URLResponse)
    public typealias StreamTransport = @Sendable (URLRequest) async throws -> AsyncThrowingStream<Data, Error>
    private let streamTransport: StreamTransport?

    public init(baseURL: URL, model: String, apiKey: String? = nil, name: String = "openai-compatible",
                transport: (@Sendable (URLRequest) async throws -> (Data, URLResponse))? = nil,
                streamTransport: StreamTransport? = nil) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.name = name
        self.transport = transport ?? { try await URLSession.shared.data(for: $0) }
        self.streamTransport = streamTransport ?? OpenAICompatibleProvider.urlSessionStream
    }

    /// Default streaming transport: newline-delimited SSE lines from URLSession.
    private static let urlSessionStream: StreamTransport = { request in
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ModelError.failed("HTTP \(http.statusCode)")
        }
        return AsyncThrowingStream { continuation in
            Task {
                do { for try await line in bytes.lines { continuation.yield(Data((line + "\n").utf8)) }
                     continuation.finish() }
                catch { continuation.finish(throwing: error) }
            }
        }
    }

    public var isAvailable: Bool { get async { true } }

    public func respond(messages: [ModelMessage], tools: [ToolDefinition]) async throws -> ModelReply {
        var payloadMessages: [[String: String]] = []
        if !tools.isEmpty {
            payloadMessages.append(["role": "system", "content": ToolCallProtocol.instructions(for: tools)])
        }
        payloadMessages += messages.map(Self.toChatMessage)

        let body: [String: Any] = ["model": model, "messages": payloadMessages, "stream": false]
        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do { (data, response) = try await transport(request) }
        catch { throw ModelError.failed(error.localizedDescription) }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ModelError.failed("HTTP \(http.statusCode)")
        }
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = (((obj?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String)
        guard let content else { throw ModelError.failed("malformed response") }
        return ToolCallProtocol.parse(content)
    }

    /// Concatenate the streamed content deltas from a Server-Sent-Events body
    /// (`data: {json}` lines, `data: [DONE]` terminator) — the reusable core of cloud
    /// streaming (KI-08). Wiring a streaming transport + forwarding partials to the UI
    /// is the remaining integration step (the text-convention loop must still buffer
    /// the whole reply to detect a `TOOL:` tool call vs. a final answer).
    public static func parseSSEContent(_ sse: String) -> String {
        var out = ""
        for rawLine in sse.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let d = payload.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let choices = obj["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else { continue }
            out += content
        }
        return out
    }

    private func chatRequest(messages: [ModelMessage], tools: [ToolDefinition], stream: Bool) throws -> URLRequest {
        var payloadMessages: [[String: String]] = []
        if !tools.isEmpty {
            payloadMessages.append(["role": "system", "content": ToolCallProtocol.instructions(for: tools)])
        }
        payloadMessages += messages.map(Self.toChatMessage)
        let body: [String: Any] = ["model": model, "messages": payloadMessages, "stream": stream]
        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private static func toChatMessage(_ m: ModelMessage) -> [String: String] {
        switch m.role {
        case .system:    return ["role": "system", "content": m.content]
        case .user:      return ["role": "user", "content": m.content]
        case .assistant: return ["role": "assistant", "content": m.content]
        case .tool:      return ["role": "user", "content": "[Tool \(m.toolName ?? "") result] \(m.content)"]
        }
    }
}

extension OpenAICompatibleProvider: StreamingModelProvider {
    /// Stream the reply: forward the growing answer via `onPartial` (unless it turns out
    /// to be a `TOOL:` tool call, which must be buffered whole), then parse the final.
    public func respondStreaming(messages: [ModelMessage], tools: [ToolDefinition],
                                 onPartial: @escaping @Sendable (String) async -> Void) async throws -> ModelReply {
        guard let streamTransport else { return try await respond(messages: messages, tools: tools) }
        let request = try chatRequest(messages: messages, tools: tools, stream: true)
        var sse = ""
        do {
            for try await chunk in try await streamTransport(request) {
                sse += String(decoding: chunk, as: UTF8.self)
                let content = Self.parseSSEContent(sse)
                if !content.isEmpty, !content.trimmingCharacters(in: .whitespaces).hasPrefix("TOOL:") {
                    await onPartial(content)
                }
            }
        } catch { throw ModelError.failed(error.localizedDescription) }
        return ToolCallProtocol.parse(Self.parseSSEContent(sse))
    }
}
