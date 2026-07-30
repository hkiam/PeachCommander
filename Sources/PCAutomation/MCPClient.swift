// MCPClient.swift — a client for EXTERNAL MCP servers (KI-01).
//
// The mirror of MCPServer: instead of exposing our tools to other agents, this lets
// the assistant consume tools from another MCP server (e.g. a filesystem or web tool
// provider). Speaks JSON-RPC 2.0 over a line transport (newline-delimited, the same
// framing MCPSocketServer uses); the transport is injectable so it's unit-testable
// and works over a loopback socket or an `nc`/stdio bridge in production.
//
// This is the protocol core. Surfacing an external server's tools inside the agent's
// callable set (dynamic tool merging) is a separate integration step.

import Foundation
import Network

public struct MCPToolInfo: Sendable, Equatable {
    public let name: String
    public let description: String
    public init(name: String, description: String) { self.name = name; self.description = description }
}

public enum MCPClientError: Error, Equatable {
    case rpc(String)
    case malformed
}

public actor MCPClient {
    /// Send one JSON-RPC request line, receive one response line.
    public typealias Transport = @Sendable (Data) async throws -> Data

    private let transport: Transport
    private var nextId = 0

    public init(transport: @escaping Transport) { self.transport = transport }

    /// Connect to an MCP server over loopback TCP (newline-delimited JSON-RPC — the
    /// framing MCPSocketServer speaks). One persistent connection; requests are
    /// serialized by this actor, so send-then-read-one-line pairs correctly.
    public init(host: String, port: UInt16) {
        let sock = SocketLine(host: host, port: port)
        self.transport = { req in try await sock.request(req) }
    }

    private func rpc(_ method: String, _ params: [String: Any]) async throws -> [String: Any] {
        nextId += 1
        var req: [String: Any] = ["jsonrpc": "2.0", "id": nextId, "method": method]
        if !params.isEmpty { req["params"] = params }
        let reqData = try JSONSerialization.data(withJSONObject: req)
        let respData = try await transport(reqData)
        guard let obj = (try? JSONSerialization.jsonObject(with: respData)) as? [String: Any] else {
            throw MCPClientError.malformed
        }
        if let err = obj["error"] as? [String: Any] {
            throw MCPClientError.rpc((err["message"] as? String) ?? "error")
        }
        return (obj["result"] as? [String: Any]) ?? [:]
    }

    /// MCP handshake.
    @discardableResult
    public func initialize() async throws -> [String: Any] {
        try await rpc("initialize", ["protocolVersion": "2024-11-05", "capabilities": [:],
                                      "clientInfo": ["name": "PeachCommander", "version": "1.0"]])
    }

    /// The external server's advertised tools.
    public func listTools() async throws -> [MCPToolInfo] {
        let r = try await rpc("tools/list", [:])
        let tools = (r["tools"] as? [[String: Any]]) ?? []
        return tools.compactMap { t in
            (t["name"] as? String).map { MCPToolInfo(name: $0, description: (t["description"] as? String) ?? "") }
        }
    }

    /// Invoke a tool on the external server, returning its text content.
    public func callTool(name: String, arguments: [String: Any]) async throws -> String {
        let r = try await rpc("tools/call", ["name": name, "arguments": arguments])
        if let content = r["content"] as? [[String: Any]] {
            let text = content.compactMap { $0["text"] as? String }.joined(separator: "\n")
            if !text.isEmpty { return text }
        }
        return (try? String(data: JSONSerialization.data(withJSONObject: r), encoding: .utf8)) ?? ""
    }
}

/// A persistent loopback TCP connection speaking newline-delimited JSON-RPC. Requests
/// are issued one at a time (the MCPClient actor serializes them), so each request
/// reads exactly the next response line.
private final class SocketLine: @unchecked Sendable {
    private let conn: NWConnection
    private let queue = DispatchQueue(label: "com.peachcommander.mcp.client")
    private let lock = NSLock()
    private var buffer = Data()

    init(host: String, port: UInt16) {
        conn = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        conn.start(queue: queue)
    }
    deinit { conn.cancel() }

    func request(_ line: Data) async throws -> Data {
        var msg = line
        msg.append(0x0A)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: msg, completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            })
        }
        return try await readLine()
    }

    private func takeBufferedLine() -> Data? {
        lock.lock(); defer { lock.unlock() }
        guard let nl = buffer.firstIndex(of: 0x0A) else { return nil }
        let line = Data(buffer[buffer.startIndex..<nl])
        buffer.removeSubrange(buffer.startIndex...nl)
        return line
    }

    private func readLine() async throws -> Data {
        if let line = takeBufferedLine() { return line }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            receiveUntilLine(cont)
        }
    }

    private func receiveUntilLine(_ cont: CheckedContinuation<Data, Error>) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error { cont.resume(throwing: error); return }
            if let data { self.lock.lock(); self.buffer.append(data); self.lock.unlock() }
            if let line = self.takeBufferedLine() { cont.resume(returning: line); return }
            if isComplete { cont.resume(throwing: MCPClientError.malformed); return }
            self.receiveUntilLine(cont)
        }
    }
}
