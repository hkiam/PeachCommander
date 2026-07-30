// CloudProvider.swift - Cloud / network "places" surfaced as volumes.
//
// This is the host-side seam for mounting cloud storage as a drive, mirroring
// Total Commander's WFX ("Network Neighborhood") model. Today it carries
// local-folder-backed providers (iCloud Drive syncs to a local path, so it is
// navigable and fully operable like any folder). The design is forward-
// compatible: future providers that are NOT local (Dropbox/WebDAV/SFTP, or a
// C-ABI PFX plugin per SPEC-012 §4) will supply a VirtualFileSystem factory
// instead of a localPath and mount the same way FTP does. Adding a cloud then
// means registering one more provider here (or, later, dropping in a plugin).

import Foundation

/// A mountable cloud/network location shown to the user as a volume.
public struct CloudProvider: Sendable, Identifiable {
    public let id: String
    public let name: String
    /// Local path a cloud provider syncs into (e.g. iCloud Drive). Non-local
    /// providers (future) would instead carry a VFS factory; see file header.
    public let localPath: String

    public init(id: String, name: String, localPath: String) {
        self.id = id
        self.name = name
        self.localPath = localPath
    }

    /// True when the backing folder exists (e.g. iCloud is enabled on this Mac).
    public var isAvailable: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: localPath, isDirectory: &isDir) && isDir.boolValue
    }
}

/// Registry of cloud providers surfaced as drives. Extensible: additional clouds
/// (and eventually PFX plugins) append their providers here.
public enum CloudProviderRegistry {
    /// The iCloud Drive local mobile-documents path for the current user.
    public static var iCloudDrivePath: String {
        (NSHomeDirectory() as NSString).appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
    }

    /// All built-in providers whose backing is currently available.
    public static func available() -> [CloudProvider] {
        let candidates = [
            CloudProvider(id: "icloud", name: "iCloud Drive", localPath: iCloudDrivePath),
        ]
        return candidates.filter { $0.isAvailable }
    }
}
