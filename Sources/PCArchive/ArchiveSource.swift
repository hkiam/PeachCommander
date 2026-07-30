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
