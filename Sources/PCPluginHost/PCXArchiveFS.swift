// PCXArchiveFS.swift - Read-only VirtualFileSystem backed by a PCX plugin (I14 T03).
//
// Mirrors PCArchive.ArchiveFS but serves listing/stat/reads from a plugin-driven
// PCXArchive: the flat entry list is turned into an in-memory tree (synthesizing
// intermediate directories), and reads extract the entry to a temp file through
// the plugin's ProcessFile. This lets plugin archives (e.g. `.pak`) be browsed by
// panels, the lister, and operations exactly like the built-in zip support.

import Foundation
import PCVFS

public final class PCXArchiveFS: VirtualFileSystem, @unchecked Sendable {
    public let scheme = "pcx"
    public var capabilities: VFSCapabilities { [.read] }

    private let archive: PCXArchive
    private let archivePath: String
    private let fsID: String

    private struct Node {
        let name: String
        let isDirectory: Bool
        let size: Int64
        let modified: Date
        let entryPath: String?   // the plugin's original entry path (files only)
    }

    private var nodes: [String: Node] = [:]
    private var childOrder: [String: [String]] = [:]

    /// Build the tree by listing the archive through the plugin. Returns nil if
    /// the plugin cannot open/list the archive.
    public init?(archivePath: String, library: PluginLibrary, fsID: String) {
        self.archive = PCXArchive(library: library)
        self.archivePath = archivePath
        self.fsID = fsID
        guard let entries = try? archive.list(archivePath: archivePath) else { return nil }

        let fallback = (try? FileManager.default.attributesOfItem(atPath: archivePath)[.modificationDate] as? Date)
            .flatMap { $0 } ?? Date(timeIntervalSince1970: 0)
        var nodes: [String: Node] = [
            "": Node(name: "", isDirectory: true, size: -1, modified: fallback, entryPath: nil)
        ]
        var childOrder: [String: [String]] = [:]

        func addChild(_ parent: String, _ full: String) {
            var s = childOrder[parent] ?? []
            if !s.contains(full) { s.append(full); childOrder[parent] = s }
        }
        @discardableResult
        func ensureDir(_ comps: [String], upTo: Int, modified: Date) -> String {
            var parent = "", full = ""
            var i = 0
            while i <= upTo {
                full = parent.isEmpty ? "/\(comps[i])" : "\(parent)/\(comps[i])"
                if nodes[full] == nil {
                    nodes[full] = Node(name: comps[i], isDirectory: true, size: -1, modified: modified, entryPath: nil)
                    addChild(parent, full)
                }
                parent = full; i += 1
            }
            return full
        }

        for entry in entries {
            let comps = entry.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            guard let last = comps.last else { continue }
            if entry.isDirectory {
                ensureDir(comps, upTo: comps.count - 1, modified: entry.modified)
            } else {
                let parent = comps.count > 1 ? ensureDir(comps, upTo: comps.count - 2, modified: entry.modified) : ""
                let full = parent.isEmpty ? "/\(last)" : "\(parent)/\(last)"
                nodes[full] = Node(name: last, isDirectory: false, size: entry.size,
                                   modified: entry.modified, entryPath: entry.path)
                addChild(parent, full)
            }
        }
        self.nodes = nodes
        self.childOrder = childOrder
    }

    public func path(_ p: String) -> VFSPath { VFSPath(filesystemId: fsID, path: p) }

    public func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        AsyncThrowingStream { continuation in
            let key = Self.key(for: dir.path)
            guard let node = nodes[key], node.isDirectory else {
                continuation.finish(throwing: VFSError.notFound(dir.path)); return
            }
            let entries = (childOrder[key] ?? []).compactMap { nodes[$0].map(Self.vfsEntry(for:)) }
            continuation.yield(VFSEntryBatch(entries: entries, isLastBatch: true))
            continuation.finish()
        }
    }

    public func stat(_ path: VFSPath) async throws -> VFSEntry {
        guard let node = nodes[Self.key(for: path.path)] else { throw VFSError.notFound(path.path) }
        return Self.vfsEntry(for: node)
    }

    public func openRead(_ path: VFSPath) async throws -> VFSReadStream {
        let url = try extractToTemp(path)
        let data = (try? Data(contentsOf: url)) ?? Data()
        return PCXReadStream(data: data)
    }

    public func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream { throw VFSError.unsupported }
    public func mkdir(_ path: VFSPath) async throws { throw VFSError.unsupported }
    public func delete(_ path: VFSPath) async throws { throw VFSError.unsupported }
    public func rename(_ from: VFSPath, to: VFSPath) async throws { throw VFSError.unsupported }
    public func setAttributes(_ path: VFSPath, attributes: VFSAttributes) async throws { throw VFSError.unsupported }
    public func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>? { nil }

    public func localFileIfAvailable(_ path: VFSPath) async throws -> URL? {
        let key = Self.key(for: path.path)
        guard let node = nodes[key] else { throw VFSError.notFound(path.path) }
        guard !node.isDirectory else { return nil }
        return try extractToTemp(path)
    }

    // MARK: - Internals

    private func extractToTemp(_ path: VFSPath) throws -> URL {
        let key = Self.key(for: path.path)
        guard let node = nodes[key], !node.isDirectory, let entryPath = node.entryPath else {
            throw VFSError.notFound(path.path)
        }
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCX-\(fsID)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let out = tempDir.appendingPathComponent(node.name)
        try archive.extract(archivePath: archivePath, entryPath: entryPath, to: out.path)
        return out
    }

    private static func key(for path: String) -> String {
        var n = path.hasPrefix("/") ? path : "/\(path)"
        while n.count > 1, n.hasSuffix("/") { n.removeLast() }
        return n == "/" ? "" : n
    }

    private static func vfsEntry(for node: Node) -> VFSEntry {
        let ext: String
        if node.isDirectory { ext = "" } else {
            let parts = node.name.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
            ext = parts.count > 1 ? String(parts[1]) : ""
        }
        return VFSEntry(name: node.name, ext: ext, kind: node.isDirectory ? .directory : .file,
                        size: node.size, modified: node.modified)
    }
}

/// Chunked in-memory read stream (mirrors PCArchive.ArchiveReadStream).
final class PCXReadStream: VFSReadStream, @unchecked Sendable {
    typealias Element = Data
    private let chunks: [Data]
    private var idx = 0
    private var closed = false

    init(data: Data, chunkSize: Int = 1 << 20) {
        var built: [Data] = []
        var off = data.startIndex
        while off < data.endIndex {
            let end = data.index(off, offsetBy: chunkSize, limitedBy: data.endIndex) ?? data.endIndex
            built.append(data.subdata(in: off..<end)); off = end
        }
        self.chunks = built
    }
    func close() async throws { closed = true }
    func makeAsyncIterator() -> AsyncIterator { AsyncIterator(stream: self) }
    fileprivate func readChunk() -> Data? {
        guard !closed, idx < chunks.count else { return nil }
        defer { idx += 1 }
        return chunks[idx]
    }
    struct AsyncIterator: AsyncIteratorProtocol {
        let stream: PCXReadStream
        func next() async -> Data? { stream.readChunk() }
    }
}
