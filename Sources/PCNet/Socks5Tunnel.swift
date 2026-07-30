// SPDX-License-Identifier: Apache-2.0
// Socks5Tunnel.swift - SOCKS5 CONNECT tunneling over NWConnection (F-212).
//
// NWConnection has no native proxy support, so this performs the SOCKS5 handshake
// (RFC 1928, no-auth or username/password) to a target host:port over a plain TCP
// connection to the proxy, and hands back the ready NWConnection carrying the
// tunneled stream. Used by the FTP transport for both the control channel and each
// passive data channel. (Plain TCP only — implicit FTPS through a proxy is not
// supported, since TLS to the target can't be established after the handshake.)

import Foundation
import Network

public enum Socks5Error: Error, Equatable, Sendable {
    case handshakeFailed
    case authFailed
    case connectFailed(UInt8)
    case tlsThroughProxyUnsupported
}

public enum Socks5Tunnel {
    /// Connect to the proxy and CONNECT-tunnel to `targetHost:targetPort`, returning
    /// the ready NWConnection (its stateUpdateHandler is cleared for the caller).
    public static func connect(proxy: ProxyConfig, targetHost: String, targetPort: Int,
                               queue: DispatchQueue) async throws -> NWConnection {
        let conn = NWConnection(host: NWEndpoint.Host(proxy.host),
                                port: NWEndpoint.Port(rawValue: UInt16(proxy.port))!, using: .tcp)
        try await waitReady(conn, queue: queue)

        // Greeting: offer no-auth (and user/pass when credentials are set).
        let hasAuth = proxy.username != nil
        try await send(conn, Data(hasAuth ? [0x05, 0x02, 0x00, 0x02] : [0x05, 0x01, 0x00]))
        let sel = try await recvExact(conn, 2)
        guard sel[0] == 0x05 else { conn.cancel(); throw Socks5Error.handshakeFailed }
        if sel[1] == 0x02 {
            guard let user = proxy.username else { conn.cancel(); throw Socks5Error.authFailed }
            let pass = proxy.password ?? ""
            var req = Data([0x01, UInt8(user.utf8.count)]); req.append(contentsOf: user.utf8)
            req.append(UInt8(pass.utf8.count)); req.append(contentsOf: pass.utf8)
            try await send(conn, req)
            let ar = try await recvExact(conn, 2)
            guard ar.count == 2, ar[1] == 0x00 else { conn.cancel(); throw Socks5Error.authFailed }
        } else if sel[1] != 0x00 {
            conn.cancel(); throw Socks5Error.handshakeFailed
        }

        // CONNECT request: IPv4 literal when possible, else a domain name.
        var req = Data([0x05, 0x01, 0x00])
        if let ip = IPv4Address(targetHost) {
            req.append(0x01); req.append(ip.rawValue)
        } else {
            let host = Array(targetHost.utf8)
            req.append(0x03); req.append(UInt8(host.count)); req.append(contentsOf: host)
        }
        req.append(UInt8((targetPort >> 8) & 0xff)); req.append(UInt8(targetPort & 0xff))
        try await send(conn, req)

        // Reply: VER REP RSV ATYP BND.ADDR BND.PORT — drain the bound address.
        let head = try await recvExact(conn, 4)
        guard head.count == 4, head[1] == 0x00 else { conn.cancel(); throw Socks5Error.connectFailed(head.count >= 2 ? head[1] : 0xFF) }
        let addrLen: Int
        switch head[3] {
        case 0x01: addrLen = 4
        case 0x04: addrLen = 16
        case 0x03: addrLen = Int(try await recvExact(conn, 1)[0])
        default: conn.cancel(); throw Socks5Error.handshakeFailed
        }
        _ = try await recvExact(conn, addrLen + 2)
        conn.stateUpdateHandler = nil
        return conn
    }

    private static func waitReady(_ conn: NWConnection, queue: DispatchQueue) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let once = ResumeOnce()
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready: if once.fire() { cont.resume() }
                case .failed(let e), .waiting(let e): if once.fire() { cont.resume(throwing: e) }
                default: break
                }
            }
            conn.start(queue: queue)
        }
    }

    private static func send(_ conn: NWConnection, _ data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            })
        }
    }

    /// Read exactly `n` bytes (SOCKS replies are fixed-size), else throw on EOF.
    private static func recvExact(_ conn: NWConnection, _ n: Int) async throws -> Data {
        var out = Data()
        while out.count < n {
            let need = n - out.count
            let chunk: Data = try await withCheckedThrowingContinuation { cont in
                conn.receive(minimumIncompleteLength: 1, maximumLength: need) { data, _, isComplete, error in
                    if let error { cont.resume(throwing: error); return }
                    if let data, !data.isEmpty { cont.resume(returning: data) }
                    else if isComplete { cont.resume(throwing: FTPError.connectionLost) }
                    else { cont.resume(returning: Data()) }
                }
            }
            if chunk.isEmpty { throw FTPError.connectionLost }
            out.append(chunk)
        }
        return out
    }
}
