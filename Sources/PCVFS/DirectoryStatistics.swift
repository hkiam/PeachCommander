// DirectoryStatistics.swift - Recursive directory summary for the Lister (F3 on a dir).
//
// Pressing F3 on a directory should show a summary (name, file/folder counts, total
// size), not some unrelated file's content. This engine walks a local directory tree
// without following symlinks (a symlink counts as one file and is not descended into),
// mirroring DirectorySizeCalculator's policy, and reports the totals.

import Foundation

public struct DirectoryStats: Equatable, Sendable {
    public let path: String
    public let name: String
    public let files: Int
    public let folders: Int      // sub-folders, excluding the top directory itself
    public let totalBytes: Int64

    public init(path: String, name: String, files: Int, folders: Int, totalBytes: Int64) {
        self.path = path
        self.name = name
        self.files = files
        self.folders = folders
        self.totalBytes = totalBytes
    }
}

public actor DirectoryStatistics {
    public init() {}

    /// Recursively summarise `path`. Returns zeros for a missing/unreadable directory.
    public func measure(_ path: String) async -> DirectoryStats {
        var files = 0, folders = 0
        var bytes: Int64 = 0
        walk(URL(fileURLWithPath: path), &files, &folders, &bytes)
        return DirectoryStats(path: path, name: (path as NSString).lastPathComponent,
                              files: files, folders: folders, totalBytes: bytes)
    }

    private func walk(_ dir: URL, _ files: inout Int, _ folders: inout Int, _ bytes: inout Int64) {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: keys, options: []) else { return }
        for url in entries {
            let v = try? url.resourceValues(forKeys: Set(keys))
            if v?.isSymbolicLink == true {
                files += 1           // count the link itself, never follow it
            } else if v?.isDirectory == true {
                folders += 1
                walk(url, &files, &folders, &bytes)
            } else {
                files += 1
                bytes += Int64(v?.fileSize ?? 0)
            }
        }
    }
}
