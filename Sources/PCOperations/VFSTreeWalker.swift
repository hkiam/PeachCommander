// VFSTreeWalker.swift - Recursively collect files in a VFS subtree.
//
// Shared by the duplicate finder and the branch view (SPEC-016 §-, SPEC-008 §4).
// Descends directories, never follows symlinks (avoids cycles / escaping the
// tree), and is depth-guarded.

import Foundation
import PCVFS

public enum VFSTreeWalker {
    /// All regular-file paths under `dir` (directories descended, symlinks skipped).
    public static func collectFiles(under dir: VFSPath, on fs: VirtualFileSystem, maxDepth: Int = 16) async -> [VFSPath] {
        guard maxDepth >= 0 else { return [] }
        var files: [VFSPath] = []
        do {
            for try await batch in fs.list(dir) {
                for entry in batch.entries {
                    let child = dir.joining(entry.name)
                    switch entry.kind {
                    case .directory:
                        files += await collectFiles(under: child, on: fs, maxDepth: maxDepth - 1)
                    case .file, .appBundle, .package:
                        files.append(child)
                    case .symlinkDir, .symlinkFile:
                        break
                    }
                }
            }
        } catch { /* partial results are acceptable */ }
        return files
    }
}
