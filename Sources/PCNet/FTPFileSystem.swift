// SPDX-License-Identifier: Apache-2.0
// FTPFileSystem.swift - VirtualFileSystem adapter over an FTP session (SPEC-011 §1).
//
// Bridges the FTP command layer (FTPControlConnection) to the app's VFS so a
// panel can browse and transfer over FTP the same way it browses local disk or
// archives. Operations are serialized by the connection actor. Reads/writes are
// buffered in memory for v1 (streaming transfers are a later optimization).

import Foundation
import PCVFS

public final class FTPFileSystem: VirtualFileSystem, DisconnectableFileSystem, @unchecked Sendable, ResumableFileDownloading, ResumableFileUploading {
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

    /// Send a local file to `path`, resuming a partial upload (F-212).
    ///
    /// `REST` before `STOR`, exactly as for the download side, and the same judgement: continue only when
    /// the remote file is *shorter* than the local one. A longer or equal remote file is not a prefix of
    /// what we are sending, so appending would corrupt it — it is replaced instead.
    public func uploadFile(_ source: URL, to path: VFSPath, resume: Bool) async throws
        -> (written: Int64, resumedAt: Int64) {
        let localSize = ((try? FileManager.default
            .attributesOfItem(atPath: source.path)[.size] as? Int64) ?? nil) ?? 0
        var offset: Int64 = 0
        if resume, localSize > 0 {
            let remoteSize = (try? await connection.size(path.path)) ?? nil ?? -1
            if remoteSize > 0 && remoteSize < localSize { offset = remoteSize }
        }
        do {
            return try await send(source, to: path.path, from: offset)
        } catch let error as FTPError where offset > 0 && Self.isRestartRefusal(error) {
            return try await send(source, to: path.path, from: 0)
        } catch { throw Self.mapError(error) }
    }

    /// Read `source` from `offset` and write it to the data channel in chunks.
    private func send(_ source: URL, to remotePath: String, from offset: Int64)
        async throws -> (written: Int64, resumedAt: Int64) {
        let handle = try FileHandle(forReadingFrom: source)
        defer { try? handle.close() }
        if offset > 0 { try handle.seek(toOffset: UInt64(offset)) }

        let data = try await connection.beginUpload(remotePath, restartAt: offset)
        var written: Int64 = 0
        do {
            // 64 KB at a time: the same size the download path uses, and it keeps a large file off the
            // heap — the point of streaming rather than handing over one Data.
            while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
                try await data.write(chunk)
                written += Int64(chunk.count)
            }
        } catch {
            await data.close()
            throw error
        }
        try await connection.finishUpload(data)
        return (written, offset)
    }

    /// Stream a remote file into `destination`, resuming a partial download (F-212).
    ///
    /// `REST` was implemented in the control connection from the start and never called with an offset —
    /// the plumbing was there, the tap was not, so a 4 GB download that dropped at 99 % started again from
    /// zero. This is also the path that avoids `localFileIfAvailable`'s whole-file-in-memory copy for a
    /// plain file copy: chunks go straight to disk.
    ///
    /// A server that refuses `REST` (not every one supports it, and `FEAT` is not always honest) is not an
    /// error: the partial file is discarded and the transfer starts over, which is what the user wanted
    /// anyway. The return value says what happened, so the caller can report a resume rather than imply it.
    public func downloadFile(_ path: VFSPath, to destination: URL, resume: Bool) async throws
        -> (written: Int64, resumedAt: Int64) {
        let existing = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int64)
            ?? nil ?? 0
        var offset: Int64 = 0
        if resume, existing > 0 {
            // Only when the remote file is *longer*: an equal or shorter one means the local copy is not a
            // prefix of it, and appending would silently produce a corrupt file.
            //
            // `SIZE`, not `stat`: stat lists the whole parent directory to find one entry, which is a
            // data connection and a full listing for a number the server will hand over in one reply.
            // A server without SIZE answers nil, and then there is nothing to resume against.
            let remoteSize = (try? await connection.size(path.path)) ?? nil ?? -1
            if remoteSize > existing { offset = existing }
        }
        do {
            return try await stream(path.path, to: destination, from: offset)
        } catch let error as FTPError where offset > 0 && Self.isRestartRefusal(error) {
            // Start over rather than fail: the file is what the user asked for, not the resume.
            return try await stream(path.path, to: destination, from: 0)
        } catch { throw Self.mapError(error) }
    }

    /// Whether an error is the server declining `REST` rather than a transfer failure.
    private static func isRestartRefusal(_ error: FTPError) -> Bool {
        if case .unexpectedReply(let command, _, _) = error { return command == "REST" }
        return false
    }

    /// Open the data channel at `offset` and write every chunk to `destination`.
    private func stream(_ remotePath: String, to destination: URL, from offset: Int64) async throws
        -> (written: Int64, resumedAt: Int64) {
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        if offset == 0 { try? fm.removeItem(at: destination) }
        if !fm.fileExists(atPath: destination.path) {
            fm.createFile(atPath: destination.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: destination)
        // Truncate or seek *before* the first byte arrives: a resumed transfer must append to exactly the
        // bytes that were counted, and a restarted one must not leave the old tail behind.
        try handle.truncate(atOffset: UInt64(offset))
        defer { try? handle.close() }

        let data = try await connection.beginDownload(remotePath, restartAt: offset)
        var written: Int64 = 0
        do {
            while let chunk = try await data.readChunk() {
                try handle.write(contentsOf: chunk)
                written += Int64(chunk.count)
            }
        } catch {
            await data.close()
            throw error
        }
        try await connection.finishDownload(data)
        return (written, offset)
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
            if code == 530 { return VFSError.permissionDenied(.modeBits) }
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
