// SPDX-License-Identifier: Apache-2.0
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
    public var capabilities: VFSCapabilities { [.read, .localExtraction] }

    private let source: ArchiveSource
    private let fsID: String

    /// Password for encrypted entries (classic ZipCrypto / WinZip AES). Set by
    /// the host after prompting the user; `openRead` throws until it is provided
    /// for an encrypted entry. Ignored by formats without encryption (tar).
    public var password: String?

    /// True when any member is encrypted — the host prompts for a password once
    /// on entering such an archive and assigns `password`.
    public var hasEncryptedEntries: Bool { source.members.contains { $0.isEncrypted } }

    /// Bytes this mount keeps alive, forwarded from its backend — what the archive cache
    /// budgets against, so a mapped zip costs nothing and an inflated tar costs its size.
    public var retainedBytes: Int64 { source.retainedBytes }

    /// Forwarded from the backend that actually opened this archive, so a caller
    /// choosing a read strategy asks the mount rather than guessing from the name (F-463).
    public var memberAccessCost: MemberAccessCost {
        source.readsMembersByProcess ? .processPerMember : .cheapRandomAccess
    }

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

    /// Everything this mount extracted, removed when the mount goes away.
    private let tempLock = NSLock()
    private var tempRoot: URL?
    private var tempCounter = 0

    private var nodes: [String: Node] = [:]
    /// Parent full path -> ordered list of child full paths.
    private var childOrder: [String: [String]] = [:]

    /// Opens `archiveFileURL` as a read-only filesystem, trying the zip reader
    /// first and then the tar / tar.gz reader. Returns `nil` if the file cannot
    /// be parsed as any supported archive. `fsID` uniquely identifies this mount
    /// and is used as the `filesystemId` for paths built via `path(_:)`.
    public convenience init?(archiveFileURL: URL, fsID: String) {
        self.init(archiveFileURL: archiveFileURL, fsID: fsID, tarLimits: .unlimited)
    }

    /// - Parameter tarLimits: ceiling on what a gzip-wrapped tar may expand to. The
    ///   default is no ceiling, which is right for a keypress; a background walk passes
    ///   one so a folder of build artefacts cannot inflate itself into memory.
    public init?(archiveFileURL: URL, fsID: String, tarLimits: TarReader.Limits) {
        // For libarchive-only formats (cpio/iso/cab/lzh…) try the bsdtar shell
        // source first — the lenient TarReader would otherwise mis-claim them (F-130).
        let ext = archiveFileURL.pathExtension.lowercased()
        let source: ArchiveSource?
        if ShellArchiveSource.handledExtensions.contains(ext) {
            source = ShellArchiveSource(fileURL: archiveFileURL)
                ?? ZipReader(fileURL: archiveFileURL)
                ?? TarReader(fileURL: archiveFileURL, limits: tarLimits)
        } else {
            source = ZipReader(fileURL: archiveFileURL)
                ?? TarReader(fileURL: archiveFileURL, limits: tarLimits)
                ?? ShellArchiveSource(fileURL: archiveFileURL)
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
        /// Full paths already linked to a parent. A tar may legitimately carry the same
        /// member twice, and the listing must not show it twice.
        var linked = Set<String>()

        /// Two O(n) steps used to hide in here, and together they made opening an archive
        /// quadratic in the number of files in one directory. `siblings.contains(fullPath)`
        /// scanned every name already added; and reading the array out into a local before
        /// appending gave it a second reference, so `append` copied the whole thing and the
        /// copy was written back. A tar of 20,000 files in one directory — an unpacked
        /// source tree, a node_modules — took **30 seconds** to open, which was tolerable
        /// only while nothing but Enter could reach it. A search walks a folder of them.
        func addChild(parent: String, fullPath: String) {
            guard linked.insert(fullPath).inserted else { return }
            childOrder[parent, default: []].append(fullPath)
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
            // Same reason as the reader's header loop: a cancelled search must not have to
            // wait for a huge archive's tree to finish being built before it can stop.
            if memberIndex % 4096 == 4095, Task.isCancelled { return nil }
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
        // Incrementally where the backend can (F-479): the member then never exists whole, so
        // viewing, unpacking or searching a multi-gigabyte file inside an archive costs a chunk
        // rather than its size. Backends that cannot say so by returning nil — an encrypted zip
        // member, a format read through a helper process — and get the old behaviour unchanged.
        if let reader = try source.reader(atIndex: index, password: password) {
            return ArchiveMemberStream(reader: reader)
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
        let fileURL = try extractionDirectory().appendingPathComponent(node.name)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// A fresh directory to extract one member into, inside this mount's own temp root.
    ///
    /// Per member rather than one shared directory because two members in different
    /// folders may share a name, and the extracted file has to keep its own — the viewer
    /// and every "open with" downstream go by it.
    ///
    /// The root is per *mount* and is removed in `deinit`. It used to be a fresh
    /// `PCArchive-<fsID>-<uuid>` directory per call that nothing ever deleted, and since
    /// `fsID` carries the archive's path, `appendingPathComponent` quietly turned the
    /// slashes in it into more directories — so every extraction left a small tree
    /// behind in the temp directory for the OS to reap whenever it got round to it.
    private func extractionDirectory() throws -> URL {
        tempLock.lock()
        defer { tempLock.unlock() }
        let root: URL
        if let tempRoot {
            root = tempRoot
        } else {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("PCArchive-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            tempRoot = root
        }
        tempCounter += 1
        let dir = root.appendingPathComponent("\(tempCounter)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    deinit {
        if let tempRoot { try? FileManager.default.removeItem(at: tempRoot) }
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
///
/// **Sliced as it is read, not cut up in advance.** The first version built an array of chunks in
/// `init` — `subdata` copies, so the whole member existed twice for as long as the stream did, on
/// top of the copy `ArchiveSource.data(atIndex:)` had just produced. Three full copies of a 2 GB
/// member, two of them for nothing. Now one chunk at a time is materialised and the caller is
/// expected to be done with it before asking for the next, which every caller in the app is.
///
/// Used for what cannot be read incrementally — an encrypted zip member, a format read through a
/// helper process. Everything else comes through `ArchiveMemberStream` and is never held whole.
final class ArchiveReadStream: VFSReadStream, @unchecked Sendable {
    typealias Element = Data

    private let data: Data
    private let chunkSize: Int
    private var offset: Data.Index
    private var closed = false

    init(data: Data, chunkSize: Int = 1 << 20) {
        self.data = data
        self.chunkSize = Swift.max(1, chunkSize)
        self.offset = data.startIndex
    }

    fileprivate func readChunk() -> Data? {
        guard !closed, offset < data.endIndex else { return nil }
        let end = data.index(offset, offsetBy: chunkSize, limitedBy: data.endIndex) ?? data.endIndex
        defer { offset = end }
        return data.subdata(in: offset..<end)
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

/// Pulls a member out of an `ArchiveMemberReader` a chunk at a time (F-479).
///
/// The iterator throws, unlike `ArchiveReadStream`'s: a decompression that fails halfway has to be
/// an error and not an early nil, which the caller cannot tell from a member that simply ended.
final class ArchiveMemberStream: VFSReadStream, @unchecked Sendable {
    typealias Element = Data

    private let reader: ArchiveMemberReader
    private let chunkSize: Int
    private var closed = false

    init(reader: ArchiveMemberReader, chunkSize: Int = 1 << 20) {
        self.reader = reader
        self.chunkSize = Swift.max(1, chunkSize)
    }

    fileprivate func readChunk() throws -> Data? {
        guard !closed else { return nil }
        return try reader.next(maxBytes: chunkSize)
    }

    func close() async throws { closed = true }

    func makeAsyncIterator() -> AsyncIterator { AsyncIterator(stream: self) }

    struct AsyncIterator: AsyncIteratorProtocol {
        let stream: ArchiveMemberStream
        func next() async throws -> Data? { try stream.readChunk() }
    }
}
