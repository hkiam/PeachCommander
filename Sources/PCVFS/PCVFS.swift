// SPDX-License-Identifier: Apache-2.0
// PCVFS - Virtual File System protocol and local FS implementation
// This module defines the VFS protocol and a concrete LocalDirectoryLister

import Foundation
import PCFoundation

/// Represents a single entry in a directory listing
public struct VFSEntry: Sendable {
    public var name: String               // NFC-normalized for display
    public var ext: String                // display extension ("" for dirs)
    public var kind: Kind                 // dir, file, symlinkDir, symlinkFile, appBundle, package
    public var size: Int64                // -1 unknown (dirs until calculated)
    public var modified: Date
    public var created: Date?
    public var posixMode: UInt16
    public var bsdFlags: UInt32
    public var isHidden: Bool
    public var linkTarget: String?        // lazy
    public var extra: ContentFieldsRef?   // plugin columns, lazy

    public enum Kind: Sendable {
        case directory
        case file
        case symlinkDir
        case symlinkFile
        case appBundle
        case package
    }

    public init(
        name: String,
        ext: String,
        kind: Kind,
        size: Int64,
        modified: Date,
        created: Date? = nil,
        posixMode: UInt16 = 0,
        bsdFlags: UInt32 = 0,
        isHidden: Bool = false,
        linkTarget: String? = nil
    ) {
        self.name = name
        self.ext = ext
        self.kind = kind
        self.size = size
        self.modified = modified
        self.created = created
        self.posixMode = posixMode
        self.bsdFlags = bsdFlags
        self.isHidden = isHidden
        self.linkTarget = linkTarget
    }
}

public extension VFSEntry {
    /// The panel "Attr" column string: a type char + rwxrwxrwx, plus a BSD-flags
    /// suffix (F-038) — u=uchg (user-immutable), s=schg (system-immutable),
    /// h=hidden, a=append-only. macOS-mapped from st_flags carried on the entry.
    var attrColumnString: String { Self.attrString(kind: kind, mode: posixMode, bsdFlags: bsdFlags) }

    static func attrString(kind: Kind, mode: UInt16, bsdFlags: UInt32) -> String {
        let dirLike: Bool
        let symlink: Bool
        switch kind {
        case .directory, .symlinkDir, .package: dirLike = true
        case .file, .symlinkFile, .appBundle: dirLike = false
        }
        symlink = (kind == .symlinkDir || kind == .symlinkFile)
        var chars: [Character] = [dirLike ? "d" : (symlink ? "l" : "-")]
        let bits: [(UInt16, Character)] = [
            (0o400, "r"), (0o200, "w"), (0o100, "x"),
            (0o040, "r"), (0o020, "w"), (0o010, "x"),
            (0o004, "r"), (0o002, "w"), (0o001, "x")]
        for (bit, ch) in bits { chars.append((mode & bit) != 0 ? ch : "-") }
        var flags = ""
        if bsdFlags & UInt32(UF_IMMUTABLE) != 0 { flags += "u" }
        if bsdFlags & UInt32(SF_IMMUTABLE) != 0 { flags += "s" }
        if bsdFlags & UInt32(UF_HIDDEN)    != 0 { flags += "h" }
        if bsdFlags & UInt32(UF_APPEND)    != 0 { flags += "a" }
        if !flags.isEmpty { chars.append(" "); chars.append(contentsOf: flags) }
        return String(chars)
    }
}

/// A batch of VFSEntries from a directory listing
public struct VFSEntryBatch: Sendable {
    public let entries: [VFSEntry]
    public let isLastBatch: Bool

    public init(entries: [VFSEntry], isLastBatch: Bool = true) {
        self.entries = entries
        self.isLastBatch = isLastBatch
    }
}

/// Content fields reference for plugin columns
public typealias ContentFieldsRef = [String: String]

/// Protocol for virtual file systems
public protocol VirtualFileSystem: AnyObject, Sendable {
    var scheme: String { get }                   // "file", "zip", "ftp", etc.
    var capabilities: VFSCapabilities { get }    // read, write, rename, watch, execute, seekableStreams

    func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error>
    func stat(_ path: VFSPath) async throws -> VFSEntry
    func openRead(_ path: VFSPath) async throws -> VFSReadStream
    func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream
    func mkdir(_ path: VFSPath) async throws
    func delete(_ path: VFSPath) async throws
    func rename(_ from: VFSPath, to: VFSPath) async throws
    func setAttributes(_ path: VFSPath, attributes: VFSAttributes) async throws

    func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>?
    func localFileIfAvailable(_ path: VFSPath) async throws -> URL?
}

/// A file system backed by a live connection (FTP/SFTP/…) that must be torn down
/// when the panel leaves the mount, so control connections, keep-alive tasks and
/// SSH sessions don't leak. Local/archive filesystems don't conform.
public protocol DisconnectableFileSystem: AnyObject {
    func disconnect() async
}

/// Capabilities a file system may support
public struct VFSCapabilities: Sendable, OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let read = VFSCapabilities(rawValue: 1 << 0)
    public static let write = VFSCapabilities(rawValue: 1 << 1)
    public static let rename = VFSCapabilities(rawValue: 1 << 2)
    public static let watch = VFSCapabilities(rawValue: 1 << 3)
    public static let execute = VFSCapabilities(rawValue: 1 << 4)
    public static let seekableStreams = VFSCapabilities(rawValue: 1 << 5)
    /// `localFileIfAvailable` produces a real file cheaply, from data already at hand (F-463).
    ///
    /// Declared by the archive filesystems and deliberately not by the network ones: for
    /// FTP, SFTP, S3 and WebDAV the same call downloads the whole file, so a caller that
    /// escalates to it to avoid a size cap would turn a bounded read into an unbounded
    /// transfer. Extracting a member from an archive that is already open is not that.
    public static let localExtraction = VFSCapabilities(rawValue: 1 << 6)
}

/// Path within a virtual file system
public struct VFSPath: Sendable, Hashable {
    public let filesystemId: String
    public let path: String

    public init(filesystemId: String, path: String) {
        self.filesystemId = filesystemId
        self.path = path
    }

    public static func == (lhs: VFSPath, rhs: VFSPath) -> Bool {
        lhs.filesystemId == rhs.filesystemId && lhs.path == rhs.path
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(filesystemId)
        hasher.combine(path)
    }

    /// Get the parent path
    public func parent() -> VFSPath? {
        guard !path.isEmpty, path != "/" else { return nil }
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        guard !components.isEmpty else { return nil }
        let newPath = "/" + components.dropLast().joined(separator: "/")
        return VFSPath(filesystemId: filesystemId, path: newPath.isEmpty ? "/" : newPath)
    }

    /// Get the last component
    public func lastComponent() -> String {
        guard !path.isEmpty else { return "" }
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        return components.last ?? ""
    }

    /// Join with a relative path
    public func joining(_ relative: String) -> VFSPath {
        guard !relative.isEmpty else { return self }
        let newPath = path == "/" ? "/\(relative)" : "\(path)/\(relative)"
        return VFSPath(filesystemId: filesystemId, path: newPath)
    }
}

/// Read stream from a VFS
public protocol VFSReadStream: AsyncSequence, Sendable {
    associatedtype Element = Data

    func close() async throws
}

/// Write stream to a VFS
public protocol VFSWriteStream: Sendable {
    func write(_ data: Data) async throws
    func close() async throws
}

/// Options for opening a write stream
public struct WriteOptions: Sendable {
    public var create: Bool
    public var truncate: Bool
    public var append: Bool

    public init(create: Bool = true, truncate: Bool = true, append: Bool = false) {
        self.create = create
        self.truncate = truncate
        self.append = append
    }
}

/// Attributes that can be set on a file system entry. A nil field is left
/// unchanged; only the provided ones are applied.
public struct VFSAttributes: Sendable {
    public var posixMode: UInt16?
    public var modified: Date?
    /// BSD file flags (st_flags), applied via chflags (F-094): e.g. UF_IMMUTABLE.
    public var bsdFlags: UInt32?
    /// New owner user name (chown). Requires privileges for most changes.
    public var ownerName: String?
    /// New owner group name (chgrp).
    public var groupName: String?

    public init(posixMode: UInt16? = nil, modified: Date? = nil,
                bsdFlags: UInt32? = nil, ownerName: String? = nil, groupName: String? = nil) {
        self.posixMode = posixMode
        self.modified = modified
        self.bsdFlags = bsdFlags
        self.ownerName = ownerName
        self.groupName = groupName
    }
}

/// A filesystem that can write a remote file straight to a local destination, resuming a partial one.
///
/// The generic path fetches a whole file into memory and hands back a temp copy — fine for opening a file
/// in the viewer, wasteful for copying one, and impossible to resume (F-212). A backend that can do
/// better adopts this; callers ask with `as?` and fall back when it is absent.
public protocol ResumableFileDownloading {
    /// Stream `path` into `destination`.
    ///
    /// With `resume` and an existing shorter file, the transfer continues where it stopped and the bytes
    /// are appended. Returns how many bytes were written *in this call*, so a caller can tell a resumed
    /// transfer from a fresh one, and whether the server allowed the restart at all.
    func downloadFile(_ path: VFSPath, to destination: URL, resume: Bool) async throws
        -> (written: Int64, resumedAt: Int64)
}

/// A filesystem that can take a local file and write it to a remote path, resuming a partial one.
///
/// The counterpart to ``ResumableFileDownloading``, and the reason it exists is worse than convenience:
/// copying into a network panel used to hand the *remote* path to the local copy engine, which either
/// failed or wrote to a same-named local path while reporting success (F-367).
public protocol ResumableFileUploading {
    /// Send `source` to `path`. With `resume` and a remote file that is shorter, only the tail is sent.
    /// Returns the bytes written in this call and the offset it started at.
    func uploadFile(_ source: URL, to path: VFSPath, resume: Bool) async throws
        -> (written: Int64, resumedAt: Int64)
}

/// File system change event for watching
public struct VFSChangeEvent: Sendable {
    public enum ChangeType {
        case added
        case modified
        case removed
    }

    public let path: VFSPath
    public let type: ChangeType

    public init(path: VFSPath, type: ChangeType) {
        self.path = path
        self.type = type
    }
}

/// Concrete local directory lister using getattrlistbulk(2)
public actor LocalDirectoryLister {
    private let logger = PCFoundationLogger.logger

    public init() {
        logger.info("LocalDirectoryLister initialized")
    }

    /// List entries in a directory, streaming in batches
    public func list(_ path: String) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let entries = try await readDirectory(at: path)
                    continuation.yield(VFSEntryBatch(entries: entries))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// List entries in a directory, returning a single batch (convenience for non-streaming use)
    public func listDirectory(_ path: String) async throws -> VFSEntryBatch {
        let entries = try await readDirectory(at: path)
        return VFSEntryBatch(entries: entries)
    }

    private func readDirectory(at path: String) async throws -> [VFSEntry] {
        // Using FileManager for now - will be replaced with getattrlistbulk(2) in T03
        let url = URL(fileURLWithPath: path)
        let resourceKeys: [URLResourceKey] = [.nameKey, .isDirectoryKey,
                                               .contentModificationDateKey, .creationDateKey,
                                               .fileResourceTypeKey, .fileSizeKey]

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return []
        }

        var entries: [VFSEntry] = []

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)) else {
                continue
            }

            let name = resourceValues.name ?? ""
            let isDir = resourceValues.isDirectory ?? false
            let size = Int64(resourceValues.fileSize ?? 0)
            let modified = resourceValues.contentModificationDate ?? Date()
            let created = resourceValues.creationDate

            // Determine kind - simplified for now (no appBundle detection)
            let kind: VFSEntry.Kind
            if isDir {
                kind = .directory
            } else {
                kind = .file
            }

            // Extension rule: last dot; leading-dot files have empty ext
            let ext: String
            if isDir {
                ext = ""
            } else {
                let components = name.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
                if components.count > 1 {
                    ext = String(components.last!)
                } else {
                    ext = ""
                }
            }

            entries.append(VFSEntry(
                name: name,
                ext: ext,
                kind: kind,
                size: size,
                modified: modified,
                created: created,
                posixMode: 0,
                bsdFlags: 0,
                isHidden: PathUtils.isHidden(name)
            ))
        }

        return entries
    }

    /// Get stat information for a single path
    public func stat(_ path: String) async throws -> VFSEntry {
        let url = URL(fileURLWithPath: path)
        let resourceKeys: [URLResourceKey] = [.nameKey, .isDirectoryKey,
                                               .contentModificationDateKey, .creationDateKey,
                                               .fileResourceTypeKey, .fileSizeKey]

        guard let resourceValues = try? url.resourceValues(forKeys: Set(resourceKeys)) else {
            throw NSError(domain: "PCVFS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot stat path"])
        }

        let name = resourceValues.name ?? ""
        let isDir = resourceValues.isDirectory ?? false
        let size = Int64(resourceValues.fileSize ?? 0)
        let modified = resourceValues.contentModificationDate ?? Date()
        let created = resourceValues.creationDate

        let kind: VFSEntry.Kind
        if isDir {
            kind = .directory
        } else {
            kind = .file
        }

        let ext: String
        if isDir {
            ext = ""
        } else {
            let components = name.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
            if components.count > 1 {
                ext = String(components.last!)
            } else {
                ext = ""
            }
        }

        return VFSEntry(
            name: name,
            ext: ext,
            kind: kind,
            size: size,
            modified: modified,
            created: created,
            posixMode: 0,
            bsdFlags: 0,
            isHidden: PathUtils.isHidden(name)
        )
    }
}
