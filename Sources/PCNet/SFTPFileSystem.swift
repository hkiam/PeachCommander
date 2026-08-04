// SPDX-License-Identifier: Apache-2.0
// SFTPFileSystem.swift - VirtualFileSystem adapter over a libssh2 SFTP session
// (F-214). Mirrors FTPFileSystem so a panel browses/transfers over SFTP exactly
// like FTP. Reads/writes are buffered in memory for v1.

import Foundation
import PCVFS

public final class SFTPFileSystem: VirtualFileSystem, DisconnectableFileSystem, @unchecked Sendable, ResumableFileDownloading {
    private let session: SFTPSession
    private let fsID: String
    /// Route file transfers (read/write) over SCP instead of SFTP, for servers where
    /// SCP is preferred/faster. Listing/mkdir/rename/delete always use SFTP (SCP has
    /// no such operations).
    private let transferViaSCP: Bool

    public let scheme = "sftp"
    public let capabilities: VFSCapabilities = [.read, .write, .rename]

    /// Wrap an already-connected, authenticated SFTP session.
    public init(session: SFTPSession, fsID: String = "sftp", transferViaSCP: Bool = false) {
        self.session = session
        self.fsID = fsID
        self.transferViaSCP = transferViaSCP
    }

    public func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let entries = try await session.listDirectory(dir.path.isEmpty ? "/" : dir.path)
                    continuation.yield(VFSEntryBatch(entries: entries.map(Self.toEntry), isLastBatch: true))
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
        do { return Self.toEntry(try await session.stat(path.path)) }
        catch { throw Self.mapError(error) }
    }

    public func openRead(_ path: VFSPath) async throws -> VFSReadStream {
        // SCP has no partial-read API here, so it stays buffered; SFTP streams chunks
        // from an open handle (constant memory, no whole-file buffer).
        if transferViaSCP {
            do { return InMemoryReadStream(data: try await session.scpDownload(path.path)) }
            catch { throw Self.mapError(error) }
        }
        return SFTPReadStream(session: session, path: path.path)
    }

    public func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream {
        SFTPUploadStream(session: session, path: path.path, useSCP: transferViaSCP)
    }

    public func mkdir(_ path: VFSPath) async throws {
        do { try await session.mkdir(path.path) } catch { throw Self.mapError(error) }
    }

    public func delete(_ path: VFSPath) async throws {
        do {
            let entry = try await stat(path)
            if entry.kind == .directory { try await session.removeDir(path.path) }
            else { try await session.removeFile(path.path) }
        } catch let e as VFSError { throw e }
        catch { throw Self.mapError(error) }
    }

    public func rename(_ from: VFSPath, to: VFSPath) async throws {
        do { try await session.rename(from.path, to: to.path) } catch { throw Self.mapError(error) }
    }

    /// Apply what SFTP can apply, and say so for what it cannot (F-364).
    ///
    /// This used to be an empty body: the Attributes dialog reported success, the server never heard
    /// about it, and the file was unchanged. Silently accepting a change is worse than refusing it —
    /// the user has no reason to look again.
    ///
    /// SFTP carries permissions and timestamps, and owner/group only as *numbers*. A user name cannot be
    /// resolved to a uid over the protocol, so a rename of the owner is refused rather than guessed at,
    /// and macOS BSD flags do not exist on the far side at all.
    public func setAttributes(_ path: VFSPath, attributes: VFSAttributes) async throws {
        if attributes.ownerName != nil || attributes.groupName != nil {
            throw VFSError.unsupported
        }
        if attributes.bsdFlags != nil {
            throw VFSError.unsupported
        }
        guard attributes.posixMode != nil || attributes.modified != nil else { return }
        try await session.setAttributes(path.path, mode: attributes.posixMode,
                                        modified: attributes.modified)
    }

    public func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>? { nil }

    /// Close the libssh2 session when the panel leaves this mount (avoids leaking
    /// the SSH session + socket).
    public func disconnect() async { await session.close() }

    /// Stream a remote file into `destination`, resuming a partial one (F-366).
    ///
    /// Same reasoning as the FTP side (F-212): copying a file went through `localFileIfAvailable`, which
    /// reads all of it into memory and writes a temp copy that is then copied again to the target. SFTP
    /// has no protocol handshake to negotiate here — a read simply starts at an offset — so resuming is
    /// a seek, and the only judgement needed is whether the local file is a prefix of the remote one.
    public func downloadFile(_ path: VFSPath, to destination: URL, resume: Bool) async throws
        -> (written: Int64, resumedAt: Int64) {
        let existing = ((try? FileManager.default
            .attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? nil) ?? 0
        var offset: Int64 = 0
        if resume, existing > 0 {
            // Only when the remote file is longer: equal or shorter means the local copy is not its
            // beginning, and appending would produce a corrupt file that looks complete.
            let remoteSize = (try? await session.stat(path.path))?.size ?? -1
            if remoteSize > existing { offset = existing }
        }
        do {
            let written = try await session.download(path.path, to: destination, from: UInt64(offset))
            return (written, offset)
        } catch { throw Self.mapError(error) }
    }

    public func localFileIfAvailable(_ path: VFSPath) async throws -> URL? {
        do {
            let data = try await session.read(path.path)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("pc-sftp-\(UUID().uuidString)")
                .appendingPathComponent(path.lastComponent())
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
            return url
        } catch { throw Self.mapError(error) }
    }

    // MARK: - Mapping

    static func toEntry(_ e: SFTPSession.Entry) -> VFSEntry {
        let ext = e.isDirectory ? "" : (e.name as NSString).pathExtension
        let kind: VFSEntry.Kind = e.isDirectory ? .directory : (e.isSymlink ? .symlinkFile : .file)
        return VFSEntry(name: e.name, ext: ext, kind: kind,
                        size: e.isDirectory ? -1 : e.size,
                        modified: e.mtime ?? Date(timeIntervalSince1970: 0))
    }

    static func mapError(_ error: Error) -> Error {
        switch error {
        case SFTPError.notFound(let p): return VFSError.notFound(p)
        case SFTPError.notConnected: return VFSError.connectionLost(retryable: true)
        case SFTPError.hostKeyMismatch, SFTPError.authFailed:
            return VFSError.permissionDenied(needsElevation: false)
        default: return error
        }
    }
}

/// Streams chunks straight to an open SFTP handle (constant memory). SCP is the
/// exception — it needs the size up front, so those writes are buffered and sent
/// on close. Writes are awaited sequentially by the caller.
final class SFTPUploadStream: VFSWriteStream, @unchecked Sendable {
    private let session: SFTPSession
    private let path: String
    private let useSCP: Bool
    private var handle: OpaquePointer?
    private var opened = false
    private var scpBuffer = Data()

    init(session: SFTPSession, path: String, useSCP: Bool = false) {
        self.session = session
        self.path = path
        self.useSCP = useSCP
    }

    func write(_ data: Data) async throws {
        if useSCP { scpBuffer.append(data); return }
        do {
            if !opened { handle = try await session.openWriteHandle(path); opened = true }
            if let h = handle { try await session.writeHandle(h, data) }
        } catch { throw SFTPFileSystem.mapError(error) }
    }

    func close() async throws {
        do {
            if useSCP { try await session.scpUpload(scpBuffer, to: path); return }
            // Ensure an empty file is still created if no bytes were written.
            if !opened { handle = try await session.openWriteHandle(path); opened = true }
            if let h = handle { await session.closeHandle(h); handle = nil }
        } catch { throw SFTPFileSystem.mapError(error) }
    }
}

/// Streams a file from an open SFTP handle, one chunk per iteration (constant
/// memory — no whole-file buffer).
final class SFTPReadStream: VFSReadStream, @unchecked Sendable {
    private let session: SFTPSession
    private let path: String
    private var handle: OpaquePointer?
    private var started = false
    private var finished = false
    private let chunk = 128 * 1024

    init(session: SFTPSession, path: String) {
        self.session = session
        self.path = path
    }

    func makeAsyncIterator() -> AsyncIterator { AsyncIterator(stream: self) }

    struct AsyncIterator: AsyncIteratorProtocol {
        let stream: SFTPReadStream
        func next() async throws -> Data? { try await stream.next() }
    }

    fileprivate func next() async throws -> Data? {
        if finished { return nil }
        do {
            if !started { handle = try await session.openReadHandle(path); started = true }
            guard let h = handle else { finished = true; return nil }
            let data = try await session.readHandle(h, max: chunk)
            if data.isEmpty { await session.closeHandle(h); handle = nil; finished = true; return nil }
            return data
        } catch {
            if let h = handle { await session.closeHandle(h); handle = nil }
            finished = true
            throw SFTPFileSystem.mapError(error)
        }
    }

    func close() async throws {
        if let h = handle { await session.closeHandle(h); handle = nil }
        finished = true
    }
}
