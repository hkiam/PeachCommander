// SPDX-License-Identifier: Apache-2.0
// ChecksumEngine.swift - Compute/verify file checksums over the VFS (SPEC-016 §6).
//
// Streams files through a ChecksumHasher via the VirtualFileSystem, so checksums
// work uniformly on local disk, archives, and network file systems (FTP). Pure
// orchestration on top of PCFoundation's algorithms and file formats.

import Foundation
import PCFoundation
import PCVFS

public enum ChecksumEngine {
    /// Stream a file through the hasher and return its lowercase hex digest.
    public static func compute(_ path: VFSPath, on fs: VirtualFileSystem,
                               algorithm: ChecksumAlgorithm) async throws -> String {
        let hasher = ChecksumHasher(algorithm)
        let stream = try await fs.openRead(path)
        for try await chunk in stream {
            if let data = chunk as? Data { hasher.update(data) }
        }
        try? await stream.close()
        return hasher.finalizeHex()
    }

    /// Compute entries for relative filenames under `baseDir` (unreadable files
    /// are skipped). Filenames stay relative so the checksum file is portable.
    public static func create(filenames: [String], baseDir: VFSPath, on fs: VirtualFileSystem,
                              algorithm: ChecksumAlgorithm) async -> [ChecksumEntry] {
        var out: [ChecksumEntry] = []
        for name in filenames {
            if let digest = try? await compute(baseDir.joining(name), on: fs, algorithm: algorithm) {
                out.append(ChecksumEntry(digest: digest, filename: name))
            }
        }
        return out
    }

    public enum EntryStatus: Equatable, Sendable {
        case ok
        case mismatch(actual: String)
        case unreadable
    }

    public struct VerifyResult: Equatable, Sendable {
        public let filename: String
        public let status: EntryStatus
        public init(filename: String, status: EntryStatus) {
            self.filename = filename
            self.status = status
        }
    }

    /// Recompute each entry under `baseDir` and compare against its expected digest.
    public static func verify(_ entries: [ChecksumEntry], baseDir: VFSPath, on fs: VirtualFileSystem,
                              algorithm: ChecksumAlgorithm) async -> [VerifyResult] {
        var results: [VerifyResult] = []
        for e in entries {
            do {
                let actual = try await compute(baseDir.joining(e.filename), on: fs, algorithm: algorithm)
                results.append(.init(filename: e.filename,
                                     status: actual == e.digest ? .ok : .mismatch(actual: actual)))
            } catch {
                results.append(.init(filename: e.filename, status: .unreadable))
            }
        }
        return results
    }

    /// Guess the algorithm from a checksum file's extension (default sha256).
    public static func algorithm(forExtension ext: String) -> ChecksumAlgorithm {
        switch ext.lowercased() {
        case "sfv": return .crc32
        case "md5": return .md5
        case "sha1": return .sha1
        case "sha512": return .sha512
        default: return .sha256
        }
    }
}
