// SPDX-License-Identifier: Apache-2.0
// SourceLocalityProbe.swift - Where a path's bytes really are (F-479).
//
// `isInArchive` — defined in the panel as `!(fs is LocalFS)` — is the app's only notion of "not
// simply a file on the disk", and it is wrong in both directions for the question
// `ImplicitWorkBudget` asks:
//
//   * `/Volumes/team/film.mov` on an SMB share is `LocalFS`, passes every `fileExists` test, and
//     costs the whole file over the wire.
//   * `~/Library/Mobile Documents/…/big.psd` that iCloud has evicted is on the startup disk and
//     costs a download of the entire file the moment anything opens it.
//
// Two questions answer both, and they are asked in this order for the same reason `VolumeKind.of`
// orders its own: a dataless file on a share is both, and the download is the expensive half.
//
// Cost: the dataless question is one `lstat` per file — no network, no materialisation, and it is
// only asked inside a directory that a sync provider manages. The volume question is one
// `resourceValues` per *directory*, which is why it is a separate call the caller caches.

import Foundation
import PCFoundation

public enum SourceLocalityProbe {

    /// `SF_DATALESS` from `sys/stat.h` — "file is dataless object", set by the kernel for any File
    /// Provider item whose contents are not on this machine. Spelled out rather than imported: it is
    /// a `#define` whose import Swift does not guarantee, and getting it wrong here would silently
    /// classify every file as materialised.
    public static let datalessFlag: UInt32 = 0x4000_0000

    /// True when the file at `path` is managed by a sync provider and its bytes are not here.
    ///
    /// `lstat` rather than `stat`: following a symlink into a dataless target would materialise the
    /// target to answer a question about the link.
    public static func isDataless(_ path: String) -> Bool {
        var info = stat()
        guard lstat(path, &info) == 0 else { return false }
        return info.st_flags & datalessFlag != 0
    }

    /// Whether the volume `path` sits on is attached to this machine.
    ///
    /// From `.volumeIsLocalKey` for the same reason `Volume.isLocal` uses it: `fsType` is a
    /// *localized* description, so matching it for "network" works in English and quietly stops
    /// working in the other eighteen languages. An unanswerable path counts as local — refusing a
    /// preview because a resource key was unavailable would be the worse failure.
    public static func volumeIsLocal(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let values = try? url.resourceValues(forKeys: [.volumeIsLocalKey]),
              let isLocal = values.volumeIsLocal else { return true }
        return isLocal
    }

    /// Whether `path` is inside a directory some sync provider manages, and so worth `lstat`-ing per
    /// file at all. Cheap and string-only.
    public static func mayBeDormant(_ path: String) -> Bool {
        for root in CloudProviderRegistry.available() where path.hasPrefix(root.localPath) { return true }
        // Everything a File Provider mounts lives under this one directory, whoever the provider is —
        // Dropbox, OneDrive and Google Drive all land there on a current macOS.
        return path.hasPrefix(Self.fileProviderRoot)
    }

    /// `~/Library/CloudStorage`, where every non-Apple File Provider is mounted.
    public static var fileProviderRoot: String {
        (NSHomeDirectory() as NSString).appendingPathComponent("Library/CloudStorage")
    }

    /// The classification for one local file.
    ///
    /// - Parameter volumeIsLocal: the answer for the *directory*, asked once by the caller and
    ///   passed in — a per-file `resourceValues` on a share is a round trip per row.
    public static func of(localPath: String, volumeIsLocal: Bool) -> SourceLocality {
        if mayBeDormant(localPath), isDataless(localPath) { return .dormant }
        return volumeIsLocal ? .fast : .remote
    }

    /// The classification for a whole directory, for a caller that has no file in hand yet.
    ///
    /// A directory is never dormant in the sense that matters — its *listing* is materialised or the
    /// panel could not have drawn it — so this answers the volume question alone.
    public static func ofDirectory(_ path: String) -> SourceLocality {
        volumeIsLocal(path) ? .fast : .remote
    }
}
