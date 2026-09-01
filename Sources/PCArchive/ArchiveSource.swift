// SPDX-License-Identifier: Apache-2.0
// ArchiveSource.swift - Format-agnostic archive backend for ArchiveFS.
//
// ArchiveFS builds one in-memory tree model over any backend that can enumerate
// members and hand back their decompressed bytes. ZipReader conforms via an
// adapter (below); TarReader (tar / tar.gz) conforms directly. This keeps the
// tree-building, listing, stat and read paths in ArchiveFS shared across formats.

import Foundation

/// A single archive member (metadata only). Byte access goes through the owning
/// `ArchiveSource` by index.
public struct ArchiveMember: Sendable {
    /// Normalized path within the archive: no leading "/", directories end "/".
    public let path: String
    public let uncompressedSize: Int64
    public let isDirectory: Bool
    public let modified: Date?
    /// True for formats that encrypt individual members (zip); always false for tar.
    public let isEncrypted: Bool

    public init(path: String, uncompressedSize: Int64, isDirectory: Bool,
                modified: Date?, isEncrypted: Bool = false) {
        self.path = path
        self.uncompressedSize = uncompressedSize
        self.isDirectory = isDirectory
        self.modified = modified
        self.isEncrypted = isEncrypted
    }
}

/// A read-only archive backend supplying members and their bytes.
public protocol ArchiveSource: AnyObject {
    /// All members in archive order; index into this array is the handle used by
    /// `data(atIndex:password:)`.
    var members: [ArchiveMember] { get }
    /// Decompressed bytes for the member at `index`. `password` is consulted only
    /// by formats that support per-member encryption (zip). Directories yield
    /// empty data.
    func data(atIndex index: Int, password: String?) throws -> Data

    /// An incremental reader for the member at `index`, or nil when this backend has to produce it
    /// whole. See `ArchiveMemberReader`.
    ///
    /// **A requirement and not only a default.** Declared solely in the extension below, this is
    /// dispatched statically: a caller holding an `ArchiveSource` gets the extension's `nil` even
    /// when the concrete backend implements it, so `openRead` silently kept materialising every
    /// member while the incremental readers sat there fully working and never called.
    func reader(atIndex index: Int, password: String?) throws -> ArchiveMemberReader?

    /// Whether reading one member costs a subprocess (F-463).
    ///
    /// False for both native readers: the zip reader seeks to a member through a
    /// mapped central directory, and the tar reader already holds the stream, so a
    /// member is a slice. A backend that shells out per member is the exception and
    /// says so, because a caller with a content filter must then read the archive
    /// once instead of member by member.
    ///
    /// A plain `Bool` rather than PCVFS's `MemberAccessCost`: these files are compiled
    /// on their own by `Tools/check-archive-listing.sh`, which checks this app's
    /// reading of an archive against an independent one, and an import of a sibling
    /// framework would put that check out of reach. `ArchiveFS` does the mapping.
    var readsMembersByProcess: Bool { get }

    /// Bytes this backend keeps alive for as long as it exists (F-463).
    ///
    /// Zero for the readers that map or that only hold a listing; the whole payload for
    /// the tar reader, which has to inflate a gzip stream before any member can be read.
    /// A cache of open archives needs the number: 32 mapped zips cost nothing, and 32
    /// inflated tars would turn a passing memory spike into a permanent one.
    var retainedBytes: Int64 { get }
}

public extension ArchiveSource {
    var readsMembersByProcess: Bool { false }
    var retainedBytes: Int64 { 0 }

    /// No incremental reader: the caller falls back to `data(atIndex:password:)`.
    func reader(atIndex index: Int, password: String?) throws -> ArchiveMemberReader? { nil }
}

/// Pulls one member's decompressed bytes out a piece at a time.
///
/// `data(atIndex:password:)` produces the whole member, which is what every caller used to work
/// from — so a 4 GB file inside an archive cost 4 GB of memory to view, to search or to unpack, and
/// there was no way to stop halfway. A backend that can decompress incrementally offers this
/// instead; `ArchiveFS.openRead` prefers it and falls back where it is not offered, so backends
/// adopt it one at a time and nothing has to change at once.
///
/// **Pull and not push.** A closure taking each chunk is the easier thing to write and the wrong
/// shape here: `VFSReadStream` is an `AsyncSequence`, and bridging a push producer into one needs
/// either a thread to block or a buffer to grow — and a buffer that grows is the whole problem
/// again, wearing a different hat.
public protocol ArchiveMemberReader: AnyObject {
    /// The next piece, or nil at the end. Never empty before the end.
    func next(maxBytes: Int) throws -> Data?
}

/// Adapts `ZipReader` to `ArchiveSource`. Member order mirrors `entries`, so an
/// index is valid for both `members` and `entries`.
extension ZipReader: ArchiveSource {
    public var members: [ArchiveMember] {
        entries.map {
            ArchiveMember(path: $0.path, uncompressedSize: $0.uncompressedSize,
                          isDirectory: $0.isDirectory, modified: $0.modified,
                          isEncrypted: $0.isEncrypted)
        }
    }

    public func data(atIndex index: Int, password: String?) throws -> Data {
        guard entries.indices.contains(index) else { return Data() }
        return try data(for: entries[index], password: password)
    }

    public func reader(atIndex index: Int, password: String?) throws -> ArchiveMemberReader? {
        guard entries.indices.contains(index) else { return nil }
        return try reader(for: entries[index], password: password)
    }
}
