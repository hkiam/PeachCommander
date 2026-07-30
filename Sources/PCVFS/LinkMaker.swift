// LinkMaker.swift - Create symbolic links, hard links, and Finder aliases (F-093).
//
// Link creation is inherently local (it does not apply to archives or network
// file systems), so it lives in PCVFS and uses FileManager / URL bookmark APIs
// directly rather than going through the VirtualFileSystem protocol.

import Foundation

public enum LinkKind: String, CaseIterable, Sendable {
    case symbolic   // POSIX symlink
    case hard       // POSIX hard link (same-volume, files only)
    case alias      // macOS Finder alias (bookmark file)
}

public enum LinkMaker {
    /// Create a link of `kind` at `linkPath` pointing at `targetPath`.
    public static func createLink(kind: LinkKind, at linkPath: String, target targetPath: String) throws {
        switch kind {
        case .symbolic:
            try FileManager.default.createSymbolicLink(atPath: linkPath, withDestinationPath: targetPath)
        case .hard:
            try FileManager.default.linkItem(atPath: targetPath, toPath: linkPath)
        case .alias:
            let targetURL = URL(fileURLWithPath: targetPath)
            let data = try targetURL.bookmarkData(options: .suitableForBookmarkFile,
                                                  includingResourceValuesForKeys: nil, relativeTo: nil)
            try URL.writeBookmarkData(data, to: URL(fileURLWithPath: linkPath))
        }
    }
}
