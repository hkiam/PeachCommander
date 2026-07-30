// SPDX-License-Identifier: Apache-2.0
// FTPTransport.swift - Transport seam for the FTP client (SPEC-011 §3).
//
// The FTP command choreography (FTPControlConnection) is written against these
// protocols, not against sockets directly, so it can be driven deterministically
// by a scripted transport in tests (SPEC-011 §7 "canned dialogs") while the real
// implementation talks to a server over Network.framework.

import Foundation

/// One-shot guard so a continuation is resumed at most once from a callback that
/// may fire repeatedly (e.g. NWConnection.stateUpdateHandler).
final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    func fire() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if fired { return false }
        fired = true
        return true
    }
}

public enum FTPError: Error, Equatable, Sendable {
    /// The server returned an unexpected reply for the given command.
    case unexpectedReply(command: String, code: Int, text: String)
    /// A passive-mode reply could not be decoded into a data address.
    case badPassiveReply(String)
    /// The control or data connection was lost (retryable per SPEC-004 §6).
    case connectionLost
    case notConnected
}

/// A single data-channel connection (one transfer).
public protocol FTPDataTransport: Sendable {
    /// Read the whole data channel until the server closes it.
    func readAll() async throws -> Data
    /// Read the next chunk, or nil at end-of-transfer (streaming reads).
    func readChunk() async throws -> Data?
    /// Write bytes to the data channel.
    func write(_ data: Data) async throws
    /// Close the data channel (signals end-of-file for uploads).
    func close() async
}

/// The FTP control channel plus a factory for data channels.
public protocol FTPControlTransport: Sendable {
    /// Open the control connection and return the server greeting reply.
    func start() async throws -> FTPReply
    /// Send one command line (CRLF is appended by the transport).
    func send(_ line: String) async throws
    /// Read exactly one complete control reply (handles multiline framing).
    func readReply() async throws -> FTPReply
    /// Open a data channel to the given passive-mode address.
    func makeData(host: String, port: Int) async throws -> FTPDataTransport
    /// Open an active-mode data channel: a local listening socket the server will
    /// connect back to. Returns the transport plus the local address/port to
    /// advertise (EPRT/PORT) and whether that address is IPv6 (F-212).
    func makeActiveData() async throws -> (data: FTPDataTransport, host: String, port: Int, isIPv6: Bool)
    /// Close the control connection.
    func close() async
}

public extension FTPControlTransport {
    /// Default: transports that don't support active mode (e.g. scripted mocks).
    func makeActiveData() async throws -> (data: FTPDataTransport, host: String, port: Int, isIPv6: Bool) {
        throw FTPError.notConnected
    }
}
