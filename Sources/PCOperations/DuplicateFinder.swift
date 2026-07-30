// DuplicateFinder.swift - Find byte-identical files over the VFS (SPEC-008 §4).
//
// Two-tier detection to avoid hashing everything: first group by size (cheap
// stat), then hash only the files that share a size and group by content digest.
// Files in a group of size > 1 are exact duplicates. Works over any VFS via
// ChecksumEngine, so it applies to local disk, archives, and network locations.

import Foundation
import PCFoundation
import PCVFS

public struct DuplicateGroup: Equatable, Sendable {
    public let size: Int64
    public let digest: String
    public let paths: [String]
    public init(size: Int64, digest: String, paths: [String]) {
        self.size = size
        self.digest = digest
        self.paths = paths
    }
}

public enum DuplicateFinder {
    /// Recursively collect regular-file paths under `dir` (see VFSTreeWalker).
    public static func collectFiles(under dir: VFSPath, on fs: VirtualFileSystem, maxDepth: Int = 16) async -> [VFSPath] {
        await VFSTreeWalker.collectFiles(under: dir, on: fs, maxDepth: maxDepth)
    }

    /// Group the given files into sets of byte-identical duplicates. Files smaller
    /// than `minSize` are ignored (0-byte files are rarely interesting duplicates).
    public static func find(paths: [VFSPath], on fs: VirtualFileSystem,
                            algorithm: ChecksumAlgorithm = .sha256, minSize: Int64 = 1) async -> [DuplicateGroup] {
        // Tier 1: size buckets.
        var bySize: [Int64: [VFSPath]] = [:]
        for p in paths {
            guard let entry = try? await fs.stat(p), entry.kind == .file, entry.size >= minSize else { continue }
            bySize[entry.size, default: []].append(p)
        }

        // Tier 2: hash only files that collide on size, then bucket by digest.
        var groups: [DuplicateGroup] = []
        for (size, candidates) in bySize where candidates.count > 1 {
            var byDigest: [String: [String]] = [:]
            for p in candidates {
                guard let digest = try? await ChecksumEngine.compute(p, on: fs, algorithm: algorithm) else { continue }
                byDigest[digest, default: []].append(p.path)
            }
            for (digest, dupes) in byDigest where dupes.count > 1 {
                groups.append(DuplicateGroup(size: size, digest: digest, paths: dupes.sorted()))
            }
        }
        // Largest wasted space first (size * (count-1)).
        return groups.sorted { ($0.size * Int64($0.paths.count - 1)) > ($1.size * Int64($1.paths.count - 1)) }
    }
}
