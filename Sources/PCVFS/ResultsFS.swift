// SPDX-License-Identifier: Apache-2.0
// ResultsFS.swift - A flat, read-only `VirtualFileSystem` over a fixed list
// of real local paths (the "Feed to Listbox" search-results target).
//
// Unlike LocalFS/ArchiveFS, entry names here ARE the real absolute paths
// rather than bare filenames: the results list is flat (everything lives
// directly under "/"), so the real path doubles as both a unique name and
// the key needed to resolve `stat`/`openRead`/`localFileIfAvailable` back
// to the underlying file.
//
// A result found *inside* an archive has no such path — `/dir/a.tar.gz/etc/app.conf`
// cannot be `lstat`ed — and used to be dropped by the `compactMap` in `list` without
// a word, so feeding ten archive hits to a panel produced an empty one and no
// explanation. Those entries now carry their own listing snapshot plus the archive
// chain they came from, and resolve through a host-supplied resolver only when
// something actually reads them (F-463).

import Foundation

/// One row of a results listing: a real file, or a member of an archive.
public enum ResultsEntrySource: Sendable {
    /// A real absolute local path, resolved by `lstat` as it always was.
    case local(String)
    /// A file inside one or more archives: the path as displayed, the listing
    /// snapshot taken during the walk, and the archive chain needed to reach it.
    case member(display: String, entry: VFSEntry, origin: SearchOrigin)

    /// The flat name this row is listed and addressed under.
    public var display: String {
        switch self {
        case .local(let path): return path
        case .member(let display, _, _): return display
        }
    }
}

/// Extracts an archive member to a local file. Supplied by the host, because
/// resolving one means opening archives — which PCVFS has no way to do.
public typealias ResultsMemberResolver = @Sendable (SearchOrigin) async -> URL?

/// Presents a fixed set of results — real local files and archive members — as a
/// single flat "/" directory listing.
public final class ResultsFS: VirtualFileSystem, @unchecked Sendable {
    public let scheme = "results"
    public var capabilities: VFSCapabilities { [.read] }

    private let sources: [ResultsEntrySource]
    private let fsID: String
    private let resolveMember: ResultsMemberResolver?

    /// - Parameters:
    ///   - paths: Real absolute local paths to expose as the root listing.
    ///   - fsID: The `VFSPath.filesystemId` this instance is mounted under.
    public convenience init(paths: [String], fsID: String) {
        self.init(sources: paths.map { .local($0) }, fsID: fsID, resolveMember: nil)
    }

    /// - Parameters:
    ///   - sources: The rows to list, real files and archive members alike.
    ///   - fsID: The `VFSPath.filesystemId` this instance is mounted under.
    ///   - resolveMember: Extracts an archive member on demand. Without it, member
    ///     rows still list — they just cannot be read, which is the honest answer
    ///     for a caller that never offered a way to reach them.
    public init(sources: [ResultsEntrySource], fsID: String,
                resolveMember: ResultsMemberResolver? = nil) {
        self.sources = sources
        self.fsID = fsID
        self.resolveMember = resolveMember
    }

    /// The member row addressed by `path`, if this filesystem has one.
    private func member(at path: String) -> (entry: VFSEntry, origin: SearchOrigin)? {
        for case .member(let display, let entry, let origin) in sources where display == path {
            return (entry, origin)
        }
        return nil
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
            let entries: [VFSEntry] = self.sources.compactMap { source in
                switch source {
                case .local(let realPath):
                    return ResultsStat.entry(atRealPath: realPath)
                case .member(let display, let entry, _):
                    // Listed from the snapshot the walk already took. Opening 90 archives
                    // to fill in a size column would make showing the results cost more
                    // than finding them did. Only the name changes: like every other row
                    // here, it is the full display path rather than a bare filename.
                    var listed = entry
                    listed.name = display
                    return listed
                }
            }
            continuation.yield(VFSEntryBatch(entries: entries, isLastBatch: true))
            continuation.finish()
        }
    }

    public func stat(_ path: VFSPath) async throws -> VFSEntry {
        if let found = member(at: path.path) {
            var listed = found.entry
            listed.name = path.path
            return listed
        }
        guard let entry = ResultsStat.entry(atRealPath: path.path) else {
            throw VFSError.notFound(path.path)
        }
        return entry
    }

    public func openRead(_ path: VFSPath) async throws -> VFSReadStream {
        if let found = member(at: path.path) {
            guard let resolveMember,
                  let url = await resolveMember(found.origin) else { throw VFSError.notFound(path.path) }
            return ResultsReadStream(data: try Data(contentsOf: url))
        }
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
        if let found = member(at: path.path) {
            return await resolveMember?(found.origin)
        }
        return FileManager.default.fileExists(atPath: path.path) ? URL(fileURLWithPath: path.path) : nil
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
