// SPDX-License-Identifier: Apache-2.0
// LocalFS.swift - The local-disk VirtualFileSystem (SPEC-006 §3).
//
// This is the reference VFS implementation and the first consumer of the
// conformance battery. It is intentionally self-contained (its own FS access) so
// PCVFS remains the single place that touches the file system directly.

import Foundation

/// Streams a local file's bytes in chunks (seekable via the backing fd).
public final class LocalReadStream: VFSReadStream, @unchecked Sendable {
    public typealias Element = Data

    private let fd: Int32
    private let chunkSize: Int
    private var closed = false

    init(fd: Int32, chunkSize: Int = 1 << 20) {
        self.fd = fd
        self.chunkSize = chunkSize
    }

    fileprivate func readChunk() -> Data? {
        guard !closed else { return nil }
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        let n = buffer.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, chunkSize) }
        guard n > 0 else { return nil }
        return Data(buffer[0..<n])
    }

    public func close() async throws {
        if !closed { Darwin.close(fd); closed = true }
    }

    deinit { if !closed { Darwin.close(fd) } }

    public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(stream: self) }

    public struct AsyncIterator: AsyncIteratorProtocol {
        let stream: LocalReadStream
        public func next() async -> Data? { stream.readChunk() }
    }
}

/// Writes bytes to a local file via a backing fd.
public final class LocalWriteStream: VFSWriteStream, @unchecked Sendable {
    private let fd: Int32
    private var closed = false

    init(fd: Int32) { self.fd = fd }

    public func write(_ data: Data) async throws {
        var thrown: Error?
        data.withUnsafeBytes { raw in
            var off = 0
            let base = raw.baseAddress
            while off < data.count {
                let n = Darwin.write(fd, base?.advanced(by: off), data.count - off)
                if n <= 0 { thrown = VFSError.fromErrno(errno); return }
                off += n
            }
        }
        if let thrown { throw thrown }
    }

    public func close() async throws {
        if !closed { Darwin.close(fd); closed = true }
    }

    deinit { if !closed { Darwin.close(fd) } }
}

/// The local-disk file system.
public final class LocalFS: VirtualFileSystem, @unchecked Sendable {
    public let scheme = "file"
    public var capabilities: VFSCapabilities {
        [.read, .write, .rename, .watch, .execute, .seekableStreams]
    }

    public init() {}

    /// Build a `file` VFSPath from a local path.
    public static func path(_ local: String) -> VFSPath { VFSPath(filesystemId: "file", path: local) }

    public func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        AsyncThrowingStream { continuation in
            let dirPath = dir.path
            do {
                let names = try FileManager.default.contentsOfDirectory(atPath: dirPath)
                var batch: [VFSEntry] = []
                batch.reserveCapacity(min(names.count, 4096))
                for name in names {
                    let full = (dirPath as NSString).appendingPathComponent(name)
                    if let entry = Self.entry(atPath: full, name: name) { batch.append(entry) }
                    if batch.count >= 4096 {
                        continuation.yield(VFSEntryBatch(entries: batch, isLastBatch: false))
                        batch.removeAll(keepingCapacity: true)
                    }
                }
                continuation.yield(VFSEntryBatch(entries: batch, isLastBatch: true))
                continuation.finish()
            } catch {
                continuation.finish(throwing: VFSError.fromErrno(errno, path: dirPath))
            }
        }
    }

    public func stat(_ path: VFSPath) async throws -> VFSEntry {
        guard let entry = Self.entry(atPath: path.path, name: (path.path as NSString).lastPathComponent) else {
            throw VFSError.notFound(path.path)
        }
        return entry
    }

    public func openRead(_ path: VFSPath) async throws -> VFSReadStream {
        let fd = path.path.withCString { open($0, O_RDONLY) }
        guard fd >= 0 else { throw VFSError.fromErrno(errno, path: path.path) }
        return LocalReadStream(fd: fd)
    }

    public func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream {
        var flags: Int32 = O_WRONLY
        if options.create { flags |= O_CREAT }
        if options.append { flags |= O_APPEND } else if options.truncate { flags |= O_TRUNC }
        let fd = path.path.withCString { open($0, flags, 0o644) }
        guard fd >= 0 else { throw VFSError.fromErrno(errno, path: path.path) }
        return LocalWriteStream(fd: fd)
    }

    public func mkdir(_ path: VFSPath) async throws {
        do {
            try FileManager.default.createDirectory(atPath: path.path, withIntermediateDirectories: true)
        } catch {
            throw VFSError.fromErrno(errno, path: path.path)
        }
    }

    public func delete(_ path: VFSPath) async throws {
        do { try FileManager.default.removeItem(atPath: path.path) }
        catch { throw VFSError.fromErrno(errno, path: path.path) }
    }

    public func rename(_ from: VFSPath, to: VFSPath) async throws {
        let rc = from.path.withCString { f in to.path.withCString { t in Darwin.rename(f, t) } }
        if rc != 0 { throw VFSError.fromErrno(errno, path: from.path) }
    }

    public func setAttributes(_ path: VFSPath, attributes: VFSAttributes) async throws {
        // BSD flags (e.g. user-immutable) block permission/owner changes, so clear
        // them first, apply everything else, then set the requested flags last.
        if attributes.bsdFlags != nil { _ = path.path.withCString { chflags($0, 0) } }

        var attrs: [FileAttributeKey: Any] = [:]
        if let mode = attributes.posixMode { attrs[.posixPermissions] = NSNumber(value: mode) }
        if let modified = attributes.modified { attrs[.modificationDate] = modified }
        if let owner = attributes.ownerName, !owner.isEmpty { attrs[.ownerAccountName] = owner }
        if let group = attributes.groupName, !group.isEmpty { attrs[.groupOwnerAccountName] = group }
        if !attrs.isEmpty {
            do { try FileManager.default.setAttributes(attrs, ofItemAtPath: path.path) }
            catch { throw VFSError.fromErrno(errno, path: path.path) }
        }

        if let flags = attributes.bsdFlags {
            let rc = path.path.withCString { chflags($0, flags) }
            if rc != 0 { throw VFSError.fromErrno(errno, path: path.path) }
        }
    }

    public func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>? {
        // FSEvents-backed watching is wired during the panel migration (I08-T03).
        nil
    }

    public func localFileIfAvailable(_ path: VFSPath) async throws -> URL? {
        FileManager.default.fileExists(atPath: path.path) ? URL(fileURLWithPath: path.path) : nil
    }

    static func entry(atPath full: String, name: String) -> VFSEntry? {
        LocalStat.entry(atPath: full, name: name)
    }
}

/// lstat-based entry construction, kept out of `LocalFS` so the C `stat` type is
/// not shadowed by the protocol's `stat(_:)` method.
private enum LocalStat {
    static func entry(atPath full: String, name: String) -> VFSEntry? {
        var info = stat()
        guard lstat(full, &info) == 0 else { return nil }
        let fmt = info.st_mode & S_IFMT
        let isSymlink = fmt == S_IFLNK
        var kind: VFSEntry.Kind
        var aliasTarget: String?
        if isSymlink {
            var target = stat()
            let targetIsDir = stat(full, &target) == 0 && (target.st_mode & S_IFMT) == S_IFDIR
            kind = targetIsDir ? .symlinkDir : .symlinkFile
        } else if fmt == S_IFDIR {
            kind = name.hasSuffix(".app") ? .appBundle : .directory
        } else {
            kind = .file
            // F-036: a macOS Finder alias is a regular file with the kIsAlias
            // Finder flag. Treat it like a symlink (arrow badge, follow on Enter).
            // The flag check is a cheap getattrlist; the (costly) target resolve
            // runs only for the rare files that are actually aliases.
            if hasAliasFlag(full), let resolved = resolveAlias(full) {
                if resolved.isDir {
                    // An alias to an .app launches it; to a folder, navigates in.
                    kind = resolved.target.hasSuffix(".app") ? .appBundle : .symlinkDir
                } else {
                    kind = .symlinkFile
                }
                aliasTarget = resolved.target
            }
        }
        let ext = (kind == .directory || kind == .symlinkDir) ? "" : (name as NSString).pathExtension
        let modified = Date(timeIntervalSince1970: TimeInterval(info.st_mtimespec.tv_sec))
        let created = Date(timeIntervalSince1970: TimeInterval(info.st_ctimespec.tv_sec))
        return VFSEntry(
            name: name,
            ext: ext,
            kind: kind,
            size: Int64(info.st_size),
            modified: modified,
            created: created,
            posixMode: UInt16(info.st_mode & 0o7777),
            bsdFlags: UInt32(info.st_flags),
            isHidden: name.hasPrefix("."),
            linkTarget: isSymlink ? readlink(full) : aliasTarget
        )
    }

    /// True if `path`'s Finder info has the kIsAlias bit set (i.e. it is a macOS
    /// alias file), via a single getattrlist. Cheap enough to run per regular file.
    private static func hasAliasFlag(_ path: String) -> Bool {
        var attrList = attrlist()
        attrList.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        attrList.commonattr = attrgroup_t(ATTR_CMN_FNDRINFO)
        // Layout: 4-byte length prefix, then 32 bytes of Finder info; the file's
        // finderFlags are a big-endian UInt16 at offset 8 within the Finder info.
        var buffer = [UInt8](repeating: 0, count: 36)
        let rc = path.withCString { getattrlist($0, &attrList, &buffer, buffer.count, 0) }
        guard rc == 0 else { return false }
        let flags = (UInt16(buffer[4 + 8]) << 8) | UInt16(buffer[4 + 9])
        return (flags & 0x8000) != 0   // kIsAlias
    }

    /// Resolve a Finder alias file to its target (no UI, no mounting). Returns the
    /// target path and whether it is a directory, or nil for a broken alias.
    private static func resolveAlias(_ path: String) -> (isDir: Bool, target: String)? {
        let url = URL(fileURLWithPath: path)
        guard let resolved = try? URL(resolvingAliasFileAt: url, options: [.withoutUI, .withoutMounting])
        else { return nil }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDir)
        return (isDir.boolValue, resolved.path)
    }

    private static func readlink(_ path: String) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let n = path.withCString { Foundation.readlink($0, &buffer, buffer.count - 1) }
        guard n >= 0 else { return nil }
        buffer[n] = 0
        return String(cString: buffer)
    }
}
