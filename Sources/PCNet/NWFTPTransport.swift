// SPDX-License-Identifier: Apache-2.0
// NWFTPTransport.swift - Live FTP transport over Network.framework (SPEC-011 §1).
//
// Implements the FTPControlTransport / FTPDataTransport seam with real TCP
// connections. The control transport buffers incoming bytes and hands complete
// replies (FTPReplyParser framing) to FTPControlConnection; data connections
// stream a whole transfer. TLS (FTPS) and proxies are future work; this is the
// plain-FTP path. Verified with an in-process loopback server (opt-in test).

import Foundation
import Network

/// Control connection over a live TCP socket.
public actor NWFTPControlTransport: FTPControlTransport {
    private let host: String
    private let port: Int
    private let useTLS: Bool
    private let allowInsecureTLS: Bool
    private let proxy: ProxyConfig?
    /// Encoding for outgoing command lines — UTF-8 unless the site says `encoding=latin-1`.
    private var commandEncoding: String.Encoding = .utf8
    private let queue = DispatchQueue(label: "pcnet.ftp.control")
    private var connection: NWConnection?
    private var buffer = Data()

    /// - Parameters:
    ///   - useTLS: true for implicit FTPS (TLS from the first byte).
    ///   - allowInsecureTLS: accept a self-signed/untrusted server certificate
    ///     (like curl's `-k`). Off by default; opt-in per site for private servers.
    ///   - proxy: route control + data channels through a SOCKS5 proxy (F-212;
    ///     plain FTP only — TLS through the proxy is unsupported).
    public init(host: String, port: Int, useTLS: Bool = false, allowInsecureTLS: Bool = false,
                proxy: ProxyConfig? = nil) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.allowInsecureTLS = allowInsecureTLS
        self.proxy = proxy
    }

    /// Network parameters for this connection: plain TCP, default-verified TLS, or
    /// TLS with certificate verification disabled (self-signed servers).
    static func makeParameters(useTLS: Bool, allowInsecureTLS: Bool, queue: DispatchQueue) -> NWParameters {
        guard useTLS else { return .tcp }
        guard allowInsecureTLS else { return .tls }
        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, _, complete in
            complete(true)   // accept any certificate (opt-in insecure)
        }, queue)
        return NWParameters(tls: tls)
    }

    public func start() async throws -> FTPReply {
        if let proxy {
            // SOCKS5-tunnelled control channel (F-212). TLS through the proxy isn't
            // supported (can't upgrade the tunnel to TLS-to-target).
            guard !useTLS else { throw Socks5Error.tlsThroughProxyUnsupported }
            self.connection = try await Socks5Tunnel.connect(proxy: proxy, targetHost: host,
                                                             targetPort: port, queue: queue)
        } else {
            let conn = NWConnection(host: NWEndpoint.Host(host),
                                    port: NWEndpoint.Port(rawValue: UInt16(port))!,
                                    using: Self.makeParameters(useTLS: useTLS, allowInsecureTLS: allowInsecureTLS, queue: queue))
            self.connection = conn
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                let once = ResumeOnce()
                conn.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        if once.fire() { cont.resume() }
                    case .failed(let error), .waiting(let error):
                        if once.fire() { cont.resume(throwing: error) }
                    default: break
                    }
                }
                conn.start(queue: queue)
            }
        }
        return try await readReply()
    }

    public func setCommandEncoding(_ encoding: String.Encoding) { commandEncoding = encoding }

    public func send(_ line: String) async throws {
        guard let conn = connection else { throw FTPError.notConnected }
        // A name with a non-ASCII character has to leave in the encoding the *server* reads. Sent
        // as UTF-8 to a latin-1 server, a file the listing showed correctly cannot then be opened,
        // renamed or deleted — the command names a path the server does not have. Falls back to
        // UTF-8 when the text has no representation in the chosen encoding, which is still the
        // best-effort thing to send and better than sending nothing.
        let text = line + "\r\n"
        let data = text.data(using: commandEncoding) ?? Data(text.utf8)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            })
        }
    }

    public func readReply() async throws -> FTPReply {
        while true {
            if let text = String(data: buffer, encoding: .utf8) ?? String(data: buffer, encoding: .isoLatin1),
               !text.isEmpty, FTPReplyParser.isComplete(text), let reply = FTPReplyParser.parse(text) {
                buffer.removeAll(keepingCapacity: true)
                return reply
            }
            let (chunk, closed) = try await receiveChunk(on: connection)
            if let chunk { buffer.append(chunk) }
            if closed && !FTPReplyParser.isComplete(String(decoding: buffer, as: UTF8.self)) {
                throw FTPError.connectionLost
            }
        }
    }

    public func makeData(host: String, port: Int) async throws -> FTPDataTransport {
        let dt = NWFTPDataTransport(host: host, port: port, useTLS: useTLS,
                                   allowInsecureTLS: allowInsecureTLS, proxy: proxy)
        try await dt.connect()
        return dt
    }

    public func makeActiveData() async throws -> (data: FTPDataTransport, host: String, port: Int, isIPv6: Bool) {
        let listener = try await NWFTPActiveDataTransport.make(useTLS: useTLS, allowInsecureTLS: allowInsecureTLS)
        let port = await listener.localPort
        let (advertHost, isV6) = localDataAddress()
        return (listener, advertHost, port, isV6)
    }

    /// The local IP the server should connect back to for an active-mode transfer:
    /// taken from the control connection's local endpoint, falling back to the
    /// control host. (F-212)
    private func localDataAddress() -> (host: String, isIPv6: Bool) {
        if case let .hostPort(host, _)? = connection?.currentPath?.localEndpoint {
            switch host {
            case .ipv4(let a): return (Self.ipString(a), false)
            case .ipv6(let a): return (Self.ipString(a), true)
            case .name(let n, _): return (n, false)
            @unknown default: break
            }
        }
        return (self.host, self.host.contains(":"))
    }

    private static func ipString(_ addr: IPv4Address) -> String { "\(addr)" }
    private static func ipString(_ addr: IPv6Address) -> String {
        // Strip any zone id ("%en0") — EPRT wants the bare address.
        "\(addr)".split(separator: "%").first.map(String.init) ?? "\(addr)"
    }

    public func close() async {
        connection?.cancel()
        connection = nil
    }

    /// Receive one chunk; returns (bytes?, isConnectionClosed).
    private func receiveChunk(on conn: NWConnection?) async throws -> (Data?, Bool) {
        guard let conn else { throw FTPError.notConnected }
        return try await withCheckedThrowingContinuation { cont in
            conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: (data, isComplete))
            }
        }
    }
}

/// A single data-channel connection over a live TCP socket.
public actor NWFTPDataTransport: FTPDataTransport {
    private let host: String
    private let port: Int
    private let useTLS: Bool
    private let allowInsecureTLS: Bool
    private let proxy: ProxyConfig?
    private let queue = DispatchQueue(label: "pcnet.ftp.data")
    private var connection: NWConnection?

    init(host: String, port: Int, useTLS: Bool = false, allowInsecureTLS: Bool = false, proxy: ProxyConfig? = nil) {
        self.host = host; self.port = port; self.useTLS = useTLS
        self.allowInsecureTLS = allowInsecureTLS; self.proxy = proxy
    }

    func connect() async throws {
        // Tunnel the passive data channel through the same SOCKS5 proxy (F-212).
        if let proxy {
            self.connection = try await Socks5Tunnel.connect(proxy: proxy, targetHost: host,
                                                             targetPort: port, queue: queue)
            return
        }
        let conn = NWConnection(host: NWEndpoint.Host(host),
                                port: NWEndpoint.Port(rawValue: UInt16(port))!,
                                using: NWFTPControlTransport.makeParameters(useTLS: useTLS, allowInsecureTLS: allowInsecureTLS, queue: queue))
        self.connection = conn
        // Bound the setup: a data channel that never becomes ready (e.g. an FTPS
        // server requiring TLS session reuse, which Network.framework can't provide,
        // or a dead passive port) must fail fast instead of hanging.
        let timeout = Task { [queue] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            if !Task.isCancelled { conn.cancel() }
            _ = queue
        }
        defer { timeout.cancel() }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let once = ResumeOnce()
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready: if once.fire() { cont.resume() }
                case .failed(let e), .waiting(let e): if once.fire() { cont.resume(throwing: e) }
                case .cancelled: if once.fire() { cont.resume(throwing: FTPError.connectionLost) }
                default: break
                }
            }
            conn.start(queue: queue)
        }
    }

    private var finished = false

    public func readAll() async throws -> Data {
        var out = Data()
        while let chunk = try await readChunk() { out.append(chunk) }
        return out
    }

    /// Receive the next chunk from the data channel; nil once the server closes it.
    public func readChunk() async throws -> Data? {
        if finished { return nil }
        guard let conn = connection else { throw FTPError.notConnected }
        let (chunk, closed): (Data?, Bool) = try await withCheckedThrowingContinuation { cont in
            conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { data, _, isComplete, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: (data, isComplete))
            }
        }
        if closed { finished = true }
        if let chunk, !chunk.isEmpty { return chunk }
        return finished ? nil : Data()
    }

    public func write(_ data: Data) async throws {
        guard let conn = connection else { throw FTPError.notConnected }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            })
        }
    }

    public func close() async {
        connection?.cancel()
        connection = nil
    }
}
