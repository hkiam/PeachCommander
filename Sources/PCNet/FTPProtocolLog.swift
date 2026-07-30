// FTPProtocolLog.swift - Raw FTP protocol log + logging transport decorator (F-217).
//
// Captures every control command sent and reply received so the app can show a
// live "FTP console"/protocol log and let the user send custom raw commands. The
// decorator wraps any FTPControlTransport, so the command choreography
// (FTPControlConnection) needs no changes — all control traffic flows through it.

import Foundation

/// A thread-safe, bounded log of FTP control-channel lines.
public final class FTPProtocolLog: @unchecked Sendable {
    public struct Entry: Sendable, Equatable {
        /// True for a command the client sent, false for a server reply.
        public let outgoing: Bool
        public let text: String
        public init(outgoing: Bool, text: String) {
            self.outgoing = outgoing
            self.text = text
        }
    }

    private let lock = NSLock()
    private var entries: [Entry] = []
    private let maxEntries = 2000
    /// Observer invoked when a line is appended (on an arbitrary thread — the UI
    /// hops to the main thread itself).
    public var onAppend: (@Sendable (Entry) -> Void)?

    public init() {}

    public func append(outgoing: Bool, _ text: String) {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }
        let entry = Entry(outgoing: outgoing, text: line)
        lock.lock()
        entries.append(entry)
        if entries.count > maxEntries { entries.removeFirst(entries.count - maxEntries) }
        let observer = onAppend
        lock.unlock()
        observer?(entry)
    }

    public func snapshot() -> [Entry] {
        lock.lock(); defer { lock.unlock() }
        return entries
    }

    public func clear() {
        lock.lock(); entries.removeAll(); lock.unlock()
    }

    /// Mask credentials so a password never lands in the log.
    public static func mask(_ line: String) -> String {
        line.uppercased().hasPrefix("PASS ") ? "PASS ******" : line
    }
}

/// Wraps another control transport, logging every command/reply to an
/// `FTPProtocolLog` (F-217). Data-channel bytes are not logged — only the control
/// protocol, which is what a protocol console shows.
public final class LoggingFTPControlTransport: FTPControlTransport, @unchecked Sendable {
    private let inner: FTPControlTransport
    private let log: FTPProtocolLog

    public init(_ inner: FTPControlTransport, log: FTPProtocolLog) {
        self.inner = inner
        self.log = log
    }

    public func start() async throws -> FTPReply {
        let reply = try await inner.start()
        log.append(outgoing: false, "\(reply.code) \(reply.text)")
        return reply
    }

    public func send(_ line: String) async throws {
        log.append(outgoing: true, FTPProtocolLog.mask(line))
        try await inner.send(line)
    }

    public func readReply() async throws -> FTPReply {
        let reply = try await inner.readReply()
        log.append(outgoing: false, "\(reply.code) \(reply.text)")
        return reply
    }

    public func makeData(host: String, port: Int) async throws -> FTPDataTransport {
        try await inner.makeData(host: host, port: port)
    }

    public func makeActiveData() async throws -> (data: FTPDataTransport, host: String, port: Int, isIPv6: Bool) {
        try await inner.makeActiveData()
    }

    public func close() async { await inner.close() }
}
