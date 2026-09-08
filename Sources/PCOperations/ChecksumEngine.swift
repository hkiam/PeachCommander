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

    /// Compute entries for relative filenames under `baseDir`. Filenames stay relative so the
    /// checksum file is portable.
    ///
    /// A file that could not be read is *named* in `unreadable` rather than quietly left out. It used
    /// to be dropped by a `try?`, so a checksum file could come out one line short of the selection
    /// and nothing said which line was missing — which is the one thing a checksum file must not be
    /// vague about.
    public static func create(filenames: [String], baseDir: VFSPath, on fs: VirtualFileSystem,
                              algorithm: ChecksumAlgorithm) async -> (entries: [ChecksumEntry],
                                                                      unreadable: [String]) {
        var out: [ChecksumEntry] = []
        var unreadable: [String] = []
        for name in filenames {
            guard PathContainment.isSafeRelativePath(name) else { unreadable.append(name); continue }
            if let digest = try? await compute(baseDir.joining(name), on: fs, algorithm: algorithm) {
                out.append(ChecksumEntry(digest: digest, filename: name))
            } else {
                unreadable.append(name)
            }
        }
        return (out, unreadable)
    }

    public enum EntryStatus: Equatable, Sendable {
        case ok
        case mismatch(actual: String)
        case unreadable
        /// The line named something outside the folder the checksum file sits in.
        ///
        /// Its own status and not `unreadable`, because the two mean opposite things to whoever is
        /// reading the report: one is "this file is not here", the other is "this file is not the one
        /// you were asked to check". Measured before the rule existed: a `SHA256SUMS` line naming
        /// `../something` was hashed and reported **ok**, so a download could be declared intact on
        /// the strength of a file that was never part of it.
        case outsideFolder
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
            // The name comes out of the checksum file, which arrived with whatever it describes.
            // Descending is allowed — `SHA256SUMS` legitimately lists `sub/file.txt`, and refusing
            // every separator would refuse the foreign files this format exists to read. Leaving the
            // folder is not.
            guard PathContainment.isSafeRelativePath(e.filename) else {
                results.append(.init(filename: e.filename, status: .outsideFolder))
                continue
            }
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
