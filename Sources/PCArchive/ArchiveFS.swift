// ArchiveFS.swift - A read-only VirtualFileSystem backed by an `ArchiveSource` (I09).
//
// Archives do not have to contain explicit directory entries (many tools omit
// them entirely), so this builds an in-memory tree from every member's path,
// synthesizing intermediate directory nodes as needed. Listing, stat, and
// reads are then served from that tree plus `ArchiveSource.data(atIndex:)`
// for on-demand extraction - the archive is never mutated. The backend is a
// `ZipReader` (zip family) or `TarReader` (tar / tar.gz), chosen at open time.

import Foundation
import PCVFS

/// Presents a zip or tar archive as a read-only `VirtualFileSystem` at "/".
public final class ArchiveFS: VirtualFileSystem, @unchecked Sendable {
    public let scheme = "zip"
    public var capabilities: VFSCapabilities { [.read] }

    private let source: ArchiveSource
    private let fsID: String

    /// Password for encrypted entries (classic ZipCrypto / WinZip AES). Set by
    /// the host after prompting the user; `openRead` throws until it is provided
    /// for an encrypted entry. Ignored by formats without encryption (tar).
    public var password: String?

    /// True when any member is encrypted — the host prompts for a password once
    /// on entering such an archive and assigns `password`.
    public var hasEncryptedEntries: Bool { source.members.contains { $0.isEncrypted } }

    /// Whether the current `password` actually decrypts the archive: tries the
    /// first encrypted file entry (true when nothing is encrypted). Lets the host
    /// validate a Keychain-remembered password before relying on it (F-136).
    public func passwordIsValid() -> Bool {
        guard let idx = source.members.firstIndex(where: { $0.isEncrypted && !$0.isDirectory }) else { return true }
        return (try? source.data(atIndex: idx, password: password)) != nil
    }

    /// One node per file or directory in the archive, keyed by a normalized
    /// full path ("" for the root, otherwise "/a/b" with no trailing slash).
    private struct Node {
        let name: String
        let isDirectory: Bool
        let size: Int64
        let modified: Date
        /// Index into `source.members` for a file node; nil for directories.
        let memberIndex: Int?
    }

    private var nodes: [String: Node] = [:]
    /// Parent full path -> ordered list of child full paths.
    private var childOrder: [String: [String]] = [:]

    /// Opens `archiveFileURL` as a read-only filesystem, trying the zip reader
    /// first and then the tar / tar.gz reader. Returns `nil` if the file cannot
    /// be parsed as any supported archive. `fsID` uniquely identifies this mount
    /// and is used as the `filesystemId` for paths built via `path(_:)`.
    public init?(archiveFileURL: URL, fsID: String) {
        // For libarchive-only formats (cpio/iso/cab/lzh…) try the bsdtar shell
        // source first — the lenient TarReader would otherwise mis-claim them (F-130).
        let ext = archiveFileURL.pathExtension.lowercased()
        let source: ArchiveSource?
        if ShellArchiveSource.handledExtensions.contains(ext) {
            source = ShellArchiveSource(fileURL: archiveFileURL)
                ?? ZipReader(fileURL: archiveFileURL) ?? TarReader(fileURL: archiveFileURL)
        } else {
            source = ZipReader(fileURL: archiveFileURL)
                ?? TarReader(fileURL: archiveFileURL) ?? ShellArchiveSource(fileURL: archiveFileURL)
        }
        guard let source else { return nil }
        self.source = source
        self.fsID = fsID

        let attributes = try? FileManager.default.attributesOfItem(atPath: archiveFileURL.path)
        let fallbackModified = (attributes?[.modificationDate] as? Date) ?? Date(timeIntervalSince1970: 0)

        var nodes: [String: Node] = [
            "": Node(name: "", isDirectory: true, size: -1, modified: fallbackModified, memberIndex: nil)
        ]
        var childOrder: [String: [String]] = [:]

        func addChild(parent: String, fullPath: String) {
            var siblings = childOrder[parent] ?? []
            if !siblings.contains(fullPath) {
                siblings.append(fullPath)
                childOrder[parent] = siblings
            }
        }

        /// Ensures directory nodes exist for `components[0...upToIndex]`,
        /// creating any missing ones, and returns the full path of the last one.
        @discardableResult
        func ensureDirectory(components: [String], upToIndex: Int, modified: Date) -> String {
            var parent = ""
            var full = ""
            var index = 0
            while index <= upToIndex {
                let name = components[index]
                full = parent.isEmpty ? "/\(name)" : "\(parent)/\(name)"
                if nodes[full] == nil {
                    nodes[full] = Node(name: name, isDirectory: true, size: -1, modified: modified, memberIndex: nil)
                    addChild(parent: parent, fullPath: full)
                }
                parent = full
                index += 1
            }
            return full
        }

        for (memberIndex, member) in source.members.enumerated() {
            let components = member.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            guard let lastComponent = components.last else { continue }
            let entryModified = member.modified ?? fallbackModified

            if member.isDirectory {
                ensureDirectory(components: components, upToIndex: components.count - 1, modified: entryModified)
            } else {
                let parentPath = components.count > 1
                    ? ensureDirectory(components: components, upToIndex: components.count - 2, modified: entryModified)
                    : ""
                let full = parentPath.isEmpty ? "/\(lastComponent)" : "\(parentPath)/\(lastComponent)"
                nodes[full] = Node(
                    name: lastComponent,
                    isDirectory: false,
                    size: member.uncompressedSize,
                    modified: entryModified,
                    memberIndex: memberIndex
                )
                addChild(parent: parentPath, fullPath: full)
            }
        }

        self.nodes = nodes
        self.childOrder = childOrder
    }

    /// Builds a `zip` `VFSPath` rooted at this archive's mount.
    public func path(_ path: String) -> VFSPath { VFSPath(filesystemId: fsID, path: path) }

    public func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        AsyncThrowingStream { continuation in
            let key = Self.key(for: dir.path)
            guard let node = nodes[key], node.isDirectory else {
                continuation.finish(throwing: VFSError.notFound(dir.path))
                return
            }
            let entries: [VFSEntry] = (childOrder[key] ?? []).compactMap { childPath in
                nodes[childPath].map(Self.vfsEntry(for:))
            }
            continuation.yield(VFSEntryBatch(entries: entries, isLastBatch: true))
            continuation.finish()
        }
    }

    public func stat(_ path: VFSPath) async throws -> VFSEntry {
        let key = Self.key(for: path.path)
        guard let node = nodes[key] else { throw VFSError.notFound(path.path) }
        return Self.vfsEntry(for: node)
    }

    public func openRead(_ path: VFSPath) async throws -> VFSReadStream {
        let key = Self.key(for: path.path)
        guard let node = nodes[key], !node.isDirectory, let index = node.memberIndex else {
            throw VFSError.notFound(path.path)
        }
        let data = try source.data(atIndex: index, password: password)
        return ArchiveReadStream(data: data)
    }

    public func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream {
        throw VFSError.unsupported
    }

    public func mkdir(_ path: VFSPath) async throws {
        throw VFSError.unsupported
    }

    public func delete(_ path: VFSPath) async throws {
        throw VFSError.unsupported
    }

    public func rename(_ from: VFSPath, to: VFSPath) async throws {
        throw VFSError.unsupported
    }

    public func setAttributes(_ path: VFSPath, attributes: VFSAttributes) async throws {
        throw VFSError.unsupported
    }

    public func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>? {
        nil
    }

    public func localFileIfAvailable(_ path: VFSPath) async throws -> URL? {
        let key = Self.key(for: path.path)
        guard let node = nodes[key] else { throw VFSError.notFound(path.path) }
        guard !node.isDirectory, let index = node.memberIndex else { return nil }

        let data = try source.data(atIndex: index, password: password)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCArchive-\(fsID)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent(node.name)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// Normalizes a `VFSPath.path` ("/" for root, "/a/b", "/a/b/" all
    /// accepted) into this instance's node-table key ("" for root, "/a/b"
    /// otherwise, no trailing slash).
    private static func key(for path: String) -> String {
        var normalized = path.hasPrefix("/") ? path : "/\(path)"
        while normalized.count > 1, normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized == "/" ? "" : normalized
    }

    private static func vfsEntry(for node: Node) -> VFSEntry {
        let ext: String
        if node.isDirectory {
            ext = ""
        } else {
            let parts = node.name.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
            ext = parts.count > 1 ? String(parts[1]) : ""
        }
        return VFSEntry(
            name: node.name,
            ext: ext,
            kind: node.isDirectory ? .directory : .file,
            size: node.size,
            modified: node.modified
        )
    }
}

/// Streams a zip entry's already-decompressed bytes from memory, chunked to
/// mirror `LocalReadStream`'s shape (see `PCVFS/LocalFS.swift`).
final class ArchiveReadStream: VFSReadStream, @unchecked Sendable {
    typealias Element = Data

    private let chunks: [Data]
    private var nextIndex = 0
    private var closed = false

    init(data: Data, chunkSize: Int = 1 << 20) {
        var built: [Data] = []
        var offset = data.startIndex
        while offset < data.endIndex {
            let end = data.index(offset, offsetBy: chunkSize, limitedBy: data.endIndex) ?? data.endIndex
            built.append(data.subdata(in: offset..<end))
            offset = end
        }
        self.chunks = built
    }

    fileprivate func readChunk() -> Data? {
        guard !closed, nextIndex < chunks.count else { return nil }
        defer { nextIndex += 1 }
        return chunks[nextIndex]
    }

    func close() async throws {
        closed = true
    }

    func makeAsyncIterator() -> AsyncIterator { AsyncIterator(stream: self) }

    struct AsyncIterator: AsyncIteratorProtocol {
        let stream: ArchiveReadStream
        func next() async -> Data? { stream.readChunk() }
    }
}
