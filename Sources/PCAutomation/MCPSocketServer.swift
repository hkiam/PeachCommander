// MCPSocketServer.swift - a loopback TCP transport for the MCP protocol adapter.
//
// A GUI app can't be an stdio MCP server (stdio is for a client-spawned subprocess),
// so we listen on 127.0.0.1 and speak newline-delimited JSON-RPC — the same framing
// MCP uses over stdio. An external client (Claude Code / Codex) connects with a
// zero-code stdio bridge:  { "command": "nc", "args": ["127.0.0.1", "<port>"] }.
//
// Loopback-only and OFF by default; the host starts it when the user enables it.
// Destructive tool calls stay gated by the Automation Core's plan-then-confirm.

import Foundation
import Network

public final class MCPSocketServer: @unchecked Sendable {
    private let mcp: MCPServer
    private let authToken: String?
    private let queue = DispatchQueue(label: "com.peachcommander.mcp.server")
    private var listener: NWListener?
    private let lock = NSLock()
    private var _port: UInt16 = 0

    /// - Parameter authToken: if non-nil/non-empty, a connection must first send
    ///   `{"jsonrpc":"2.0","id":..,"method":"authenticate","params":{"token":"…"}}`
    ///   with the matching token before any other request; otherwise it is closed.
    public init(mcp: MCPServer, authToken: String? = nil) {
        self.mcp = mcp
        self.authToken = (authToken?.isEmpty == false) ? authToken : nil
    }

    /// Per-connection state (auth gate).
    private final class ConnState { var authed: Bool; init(_ a: Bool) { authed = a } }

    /// The bound port (0 until the listener is ready).
    public var port: UInt16 { lock.lock(); defer { lock.unlock() }; return _port }

    /// Start listening on 127.0.0.1. Pass 0 to let the OS assign a port; read `port`
    /// once `onReady` fires.
    public func start(port requested: UInt16 = 0, onReady: (@Sendable (UInt16) -> Void)? = nil) throws {
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback   // loopback only
        let nwPort: NWEndpoint.Port = requested == 0 ? .any : NWEndpoint.Port(rawValue: requested)!
        let l = try NWListener(using: params, on: nwPort)
        l.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .ready = state, let p = l.port?.rawValue {
                self.lock.lock(); self._port = p; self.lock.unlock()
                onReady?(p)
            }
        }
        l.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
        l.start(queue: queue)
        self.listener = l
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private func accept(_ conn: NWConnection) {
        conn.start(queue: queue)
        receive(conn, state: ConnState(authToken == nil), buffer: Data())
    }

    private func receive(_ conn: NWConnection, state: ConnState, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }
            // Dispatch every complete newline-delimited JSON-RPC message.
            while let nl = buf.firstIndex(of: 0x0A) {
                let line = Data(buf[buf.startIndex..<nl])
                buf.removeSubrange(buf.startIndex...nl)
                guard !line.isEmpty else { continue }
                if !state.authed {
                    // Gate: the first message must authenticate with the token.
                    if let reply = self.checkAuth(line) {
                        state.authed = true
                        var out = reply; out.append(0x0A)
                        conn.send(content: out, completion: .idempotent)
                    } else {
                        let err = Data(#"{"jsonrpc":"2.0","error":{"code":-32001,"message":"authentication required"}}"#.utf8)
                        var out = err; out.append(0x0A)
                        conn.send(content: out, completion: .contentProcessed { _ in conn.cancel() })
                    }
                    continue
                }
                Task {
                    if let resp = await self.mcp.handle(line) {
                        var out = resp; out.append(0x0A)
                        conn.send(content: out, completion: .idempotent)
                    }
                }
            }
            if error == nil && !isComplete {
                self.receive(conn, state: state, buffer: buf)
            } else {
                conn.cancel()
            }
        }
    }

    /// Validate an `authenticate` request against the configured token. Returns the
    /// success reply on match, or nil to reject + close.
    func checkAuth(_ line: Data) -> Data? {
        guard let token = authToken,
              let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              obj["method"] as? String == "authenticate",
              let params = obj["params"] as? [String: Any],
              params["token"] as? String == token else { return nil }
        let id = obj["id"].map { "\($0)" } ?? "0"
        return Data(#"{"jsonrpc":"2.0","id":\#(id),"result":{"authenticated":true}}"#.utf8)
    }
}
