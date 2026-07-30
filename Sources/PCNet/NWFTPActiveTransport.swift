// NWFTPActiveTransport.swift - Active-mode FTP data channel (F-212).
//
// In active mode the *client* listens and the server connects back (PORT/EPRT),
// the reverse of passive mode. This provides an NWListener-backed FTPDataTransport:
// it opens a listening socket, exposes the local port to advertise via EPRT, and
// lazily accepts the server's inbound connection on first read/write.

import Foundation
import Network

/// Hands the first inbound connection from an NWListener callback to an awaiting
/// consumer (thread-safe; buffers if the connection arrives before `next()`).
final class ConnectionInbox: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: NWConnection?
    private var waiter: CheckedContinuation<NWConnection, Never>?

    func deliver(_ conn: NWConnection) {
        lock.lock()
        if let w = waiter { waiter = nil; lock.unlock(); w.resume(returning: conn) }
        else { pending = conn; lock.unlock() }
    }

    func next() async -> NWConnection {
        await withCheckedContinuation { cont in
            lock.lock()
            if let p = pending { pending = nil; lock.unlock(); cont.resume(returning: p) }
            else { waiter = cont; lock.unlock() }
        }
    }
}

/// Active-mode data channel: a listening socket the server connects back to.
public actor NWFTPActiveDataTransport: FTPDataTransport {
    private let listener: NWListener
    private let inbox: ConnectionInbox
    private let queue: DispatchQueue
    private var connection: NWConnection?
    private var finished = false
    /// The local TCP port the server should connect back to (advertise via EPRT).
    public let localPort: Int

    private init(listener: NWListener, port: Int, inbox: ConnectionInbox, queue: DispatchQueue) {
        self.listener = listener
        self.localPort = port
        self.inbox = inbox
        self.queue = queue
    }

    /// Start listening on an ephemeral port and resolve it. The server will connect
    /// back here after the control connection sends EPRT/PORT + the transfer command.
    static func make(useTLS: Bool, allowInsecureTLS: Bool) async throws -> NWFTPActiveDataTransport {
        let queue = DispatchQueue(label: "pcnet.ftp.activedata")
        let params = NWFTPControlTransport.makeParameters(useTLS: useTLS, allowInsecureTLS: allowInsecureTLS, queue: queue)
        let listener = try NWListener(using: params)
        let inbox = ConnectionInbox()
        listener.newConnectionHandler = { conn in inbox.deliver(conn) }

        let port: Int = try await withCheckedThrowingContinuation { cont in
            let once = ResumeOnce()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let p = listener.port, once.fire() { cont.resume(returning: Int(p.rawValue)) }
                case .failed(let e):
                    if once.fire() { cont.resume(throwing: e) }
                default: break
                }
            }
            listener.start(queue: queue)
        }
        return NWFTPActiveDataTransport(listener: listener, port: port, inbox: inbox, queue: queue)
    }

    /// Accept the server's inbound connection (bounded by a timeout) and start it.
    private func ensureConnection() async throws {
        if connection != nil { return }
        let inbox = self.inbox
        let conn: NWConnection = try await withThrowingTaskGroup(of: NWConnection?.self) { group in
            group.addTask { await inbox.next() }
            group.addTask { try? await Task.sleep(nanoseconds: 15_000_000_000); return nil }
            let first = try await group.next() ?? nil
            group.cancelAll()
            guard let c = first else { throw FTPError.connectionLost }
            return c
        }
        connection = conn
        listener.cancel()   // one transfer per active channel
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

    public func readAll() async throws -> Data {
        var out = Data()
        while let chunk = try await readChunk() { out.append(chunk) }
        return out
    }

    public func readChunk() async throws -> Data? {
        if finished { return nil }
        try await ensureConnection()
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
        try await ensureConnection()
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
        listener.cancel()
    }
}
