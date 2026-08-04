// SPDX-License-Identifier: Apache-2.0
// FTPFileSystem.swift - VirtualFileSystem adapter over an FTP session (SPEC-011 §1).
//
// Bridges the FTP command layer (FTPControlConnection) to the app's VFS so a
// panel can browse and transfer over FTP the same way it browses local disk or
// archives. Operations are serialized by the connection actor. Reads/writes are
// buffered in memory for v1 (streaming transfers are a later optimization).

import Foundation
import PCVFS

public final class FTPFileSystem: VirtualFileSystem, DisconnectableFileSystem, @unchecked Sendable {
    private let connection: FTPControlConnection
    private let fsID: String
    /// The raw protocol log for this session, if the transport was wrapped for
    /// logging (F-217). Nil when logging was not enabled.
    public let protocolLog: FTPProtocolLog?

    public let scheme = "ftp"
    public let capabilities: VFSCapabilities = [.read, .write, .rename]

    /// Wrap an already-connected, logged-in FTP session.
    public init(connection: FTPControlConnection, fsID: String = "ftp", protocolLog: FTPProtocolLog? = nil) {
        self.connection = connection
        self.fsID = fsID
        self.protocolLog = protocolLog
    }

    /// Send a user-typed raw FTP command and return the server's reply text (F-217).
    /// The command + reply are captured by the protocol log automatically.
    public func sendRawCommand(_ line: String) async throws -> String {
        let reply = try await connection.rawCommand(line)
        return "\(reply.code) \(reply.text)"
    }

    // MARK: - Listing

    public func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let remote = try await connection.list(dir.path)
                    continuation.yield(VFSEntryBatch(entries: remote.map(Self.toEntry), isLastBatch: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.mapError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func stat(_ path: VFSPath) async throws -> VFSEntry {
        if path.path.isEmpty || path.path == "/" {
            return VFSEntry(name: "/", ext: "", kind: .directory, size: -1, modified: Date(timeIntervalSince1970: 0))
        }
        let parent = path.parent()?.path ?? "/"
        let name = path.lastComponent()
        do {
            let entries = try await connection.list(parent)
            guard let match = entries.first(where: { $0.name == name }) else {
                throw VFSError.notFound(path.path)
            }
            return Self.toEntry(match)
        } catch let e as VFSError {
            throw e
        } catch {
            throw Self.mapError(error)
        }
    }

    // MARK: - Read / write

    public func openRead(_ path: VFSPath) async throws -> VFSReadStream {
        FTPReadStream(connection: connection, path: path.path)
    }

    public func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream {
        FTPUploadStream(connection: connection, path: path.path)
    }

    // MARK: - Mutations

    public func mkdir(_ path: VFSPath) async throws {
        do { try await connection.makeDirectory(path.path) } catch { throw Self.mapError(error) }
    }

    public func delete(_ path: VFSPath) async throws {
        do {
            let entry = try await stat(path)
            if entry.kind == .directory {
                try await connection.removeDirectory(path.path)
            } else {
                try await connection.delete(path.path)
            }
        } catch let e as VFSError {
            throw e
        } catch { throw Self.mapError(error) }
    }

    public func rename(_ from: VFSPath, to: VFSPath) async throws {
        do { try await connection.rename(from.path, to: to.path) } catch { throw Self.mapError(error) }
    }

    /// Change permissions via `SITE CHMOD`, and refuse the rest (F-364).
    ///
    /// Previously the reply was discarded with `try?`, so a server that does not support the command
    /// reported success to the user and changed nothing. FTP has no standard way to set an owner or a
    /// timestamp, so those are refused rather than silently dropped.
    public func setAttributes(_ path: VFSPath, attributes: VFSAttributes) async throws {
        if attributes.ownerName != nil || attributes.groupName != nil || attributes.bsdFlags != nil {
            throw VFSError.unsupported
        }
        guard let mode = attributes.posixMode else { return }
        let octal = String(mode & 0o777, radix: 8)
        do {
            _ = try await connection.rawCommand("SITE CHMOD \(octal) \(path.path)")
        } catch {
            // SITE commands are optional in the protocol; a refusal is a real answer and belongs to the
            // user, not to a swallowed error.
            throw VFSError.unsupported
        }
    }

    public func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>? { nil }

    /// Stop the keep-alive loop and close the control connection (QUIT) when the
    /// panel leaves this mount, so the connection and its task don't leak.
    public func disconnect() async {
        await connection.stopKeepAlive()
        await connection.quit()
    }

    public func localFileIfAvailable(_ path: VFSPath) async throws -> URL? {
        do {
            let data = try await connection.download(path.path)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("pc-ftp-\(UUID().uuidString)")
                .appendingPathComponent(path.lastComponent())
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
            return url
        } catch { throw Self.mapError(error) }
    }

    // MARK: - Mapping

    static func toEntry(_ r: RemoteFileEntry) -> VFSEntry {
        let ext = r.isDirectory ? "" : (r.name as NSString).pathExtension
        let kind: VFSEntry.Kind = r.isDirectory ? .directory : (r.isSymlink ? .symlinkFile : .file)
        return VFSEntry(name: r.name, ext: ext, kind: kind,
                        size: r.isDirectory ? -1 : r.size,
                        modified: r.modified ?? Date(timeIntervalSince1970: 0),
                        linkTarget: r.symlinkTarget)
    }

    static func mapError(_ error: Error) -> Error {
        switch error {
        case FTPError.connectionLost: return VFSError.connectionLost(retryable: true)
        case FTPError.notConnected: return VFSError.connectionLost(retryable: true)
        case let FTPError.unexpectedReply(_, code, _):
            if code == 550 { return VFSError.notFound("") }
            if code == 530 { return VFSError.permissionDenied(needsElevation: false) }
            return VFSError.underlying(code: Int32(code), message: "FTP \(code)")
        default: return error
        }
    }
}

/// Read stream that vends an in-memory buffer in fixed-size chunks.
final class InMemoryReadStream: VFSReadStream, @unchecked Sendable {
    private let data: Data
    private var offset = 0
    private let chunk = 64 * 1024

    init(data: Data) { self.data = data }

    func readChunk() -> Data? {
        guard offset < data.count else { return nil }
        let end = Swift.min(offset + chunk, data.count)
        defer { offset = end }
        return data.subdata(in: offset..<end)
    }

    func makeAsyncIterator() -> AsyncIterator { AsyncIterator(stream: self) }

    struct AsyncIterator: AsyncIteratorProtocol {
        let stream: InMemoryReadStream
        func next() async -> Data? { stream.readChunk() }
    }

    func close() async throws {}
}

/// Streams chunks to a STOR data channel as they arrive (constant memory). Writes
/// are awaited sequentially by the caller.
final class FTPUploadStream: VFSWriteStream, @unchecked Sendable {
    private let connection: FTPControlConnection
    private let path: String
    private var data: FTPDataTransport?
    private var started = false

    init(connection: FTPControlConnection, path: String) {
        self.connection = connection
        self.path = path
    }

    func write(_ chunk: Data) async throws {
        do {
            if !started { data = try await connection.beginUpload(path); started = true }
            if let d = data { try await d.write(chunk) }
        } catch { throw FTPFileSystem.mapError(error) }
    }

    func close() async throws {
        do {
            if !started { data = try await connection.beginUpload(path); started = true }  // empty file
            if let d = data { try await connection.finishUpload(d); data = nil }
        } catch { throw FTPFileSystem.mapError(error) }
    }
}

/// Streams a file from a RETR data channel, one chunk per iteration (constant
/// memory), reading the final completion reply when the channel ends.
final class FTPReadStream: VFSReadStream, @unchecked Sendable {
    private let connection: FTPControlConnection
    private let path: String
    private var data: FTPDataTransport?
    private var started = false
    private var finished = false

    init(connection: FTPControlConnection, path: String) {
        self.connection = connection
        self.path = path
    }

    func makeAsyncIterator() -> AsyncIterator { AsyncIterator(stream: self) }

    struct AsyncIterator: AsyncIteratorProtocol {
        let stream: FTPReadStream
        func next() async throws -> Data? { try await stream.next() }
    }

    fileprivate func next() async throws -> Data? {
        if finished { return nil }
        do {
            if !started { data = try await connection.beginDownload(path); started = true }
            guard let d = data else { finished = true; return nil }
            if let chunk = try await d.readChunk() { return chunk }
            try await connection.finishDownload(d)
            data = nil; finished = true
            return nil
        } catch {
            if let d = data { await d.close(); data = nil }
            finished = true
            throw FTPFileSystem.mapError(error)
        }
    }

    func close() async throws {
        if let d = data { await d.close(); data = nil }
        finished = true
    }
}
