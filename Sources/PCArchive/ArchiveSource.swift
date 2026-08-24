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
}
