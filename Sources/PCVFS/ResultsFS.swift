// SPDX-License-Identifier: Apache-2.0
// ResultsFS.swift - A flat, read-only `VirtualFileSystem` over a fixed list
// of real local paths (the "Feed to Listbox" search-results target).
//
// Unlike LocalFS/ArchiveFS, entry names here ARE the real absolute paths
// rather than bare filenames: the results list is flat (everything lives
// directly under "/"), so the real path doubles as both a unique name and
// the key needed to resolve `stat`/`openRead`/`localFileIfAvailable` back
// to the underlying file.

import Foundation

/// Presents a fixed set of real local file paths as a single flat "/"
/// directory listing.
public final class ResultsFS: VirtualFileSystem, @unchecked Sendable {
    public let scheme = "results"
    public var capabilities: VFSCapabilities { [.read] }

    private let paths: [String]
    private let fsID: String

    /// - Parameters:
    ///   - paths: Real absolute local paths to expose as the root listing.
    ///   - fsID: The `VFSPath.filesystemId` this instance is mounted under.
    public init(paths: [String], fsID: String) {
        self.paths = paths
        self.fsID = fsID
    }

    /// Builds a `results` `VFSPath` rooted at this instance's mount.
    public func path(_ path: String) -> VFSPath { VFSPath(filesystemId: fsID, path: path) }

    public func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        AsyncThrowingStream { continuation in
            guard Self.isRoot(dir.path) else {
                continuation.yield(VFSEntryBatch(entries: [], isLastBatch: true))
                continuation.finish()
                return
            }
            let entries = paths.compactMap(ResultsStat.entry(atRealPath:))
            continuation.yield(VFSEntryBatch(entries: entries, isLastBatch: true))
            continuation.finish()
        }
    }

    public func stat(_ path: VFSPath) async throws -> VFSEntry {
        guard let entry = ResultsStat.entry(atRealPath: path.path) else {
            throw VFSError.notFound(path.path)
        }
        return entry
    }

    public func openRead(_ path: VFSPath) async throws -> VFSReadStream {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw VFSError.notFound(path.path)
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path.path))
            return ResultsReadStream(data: data)
        } catch {
            throw VFSError.fromErrno(errno, path: path.path)
        }
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
        FileManager.default.fileExists(atPath: path.path) ? URL(fileURLWithPath: path.path) : nil
    }

    /// Whether `path` refers to this filesystem's single flat root ("/",
    /// with or without a trailing slash).
    private static func isRoot(_ path: String) -> Bool {
        var normalized = path
        while normalized.count > 1, normalized.hasSuffix("/") { normalized.removeLast() }
        return normalized.isEmpty || normalized == "/"
    }
}

/// lstat-based `VFSEntry` construction, kept out of `ResultsFS` so the C
/// `stat` type is not shadowed by the protocol's `stat(_:)` method (mirrors
/// `LocalStat` in `PCVFS/LocalFS.swift`).
private enum ResultsStat {
    /// Builds a `VFSEntry` for `realPath`, keyed by the real absolute path
    /// (used both as `name` and, by the caller, as the resolvable path).
    static func entry(atRealPath realPath: String) -> VFSEntry? {
        var info = stat()
        guard lstat(realPath, &info) == 0 else { return nil }
        let isDirectory = (info.st_mode & S_IFMT) == S_IFDIR
        let lastComponent = (realPath as NSString).lastPathComponent

        let ext: String
        if isDirectory {
            ext = ""
        } else {
            let components = lastComponent.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
            ext = components.count > 1 ? components.last.map(String.init) ?? "" : ""
        }

        return VFSEntry(
            name: realPath,
            ext: ext,
            kind: isDirectory ? .directory : .file,
            size: Int64(info.st_size),
            modified: Date(timeIntervalSince1970: TimeInterval(info.st_mtimespec.tv_sec)),
            created: Date(timeIntervalSince1970: TimeInterval(info.st_ctimespec.tv_sec)),
            posixMode: UInt16(info.st_mode & 0o7777),
            bsdFlags: UInt32(info.st_flags),
            isHidden: lastComponent.hasPrefix(".")
        )
    }
}

/// Streams an already-loaded file's bytes from memory, chunked to mirror
/// `LocalReadStream`'s shape (see `PCVFS/LocalFS.swift`).
final class ResultsReadStream: VFSReadStream, @unchecked Sendable {
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
        let stream: ResultsReadStream
        func next() async -> Data? { stream.readChunk() }
    }
}
