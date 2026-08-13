// SPDX-License-Identifier: Apache-2.0
// NetworkMountRegistry.swift - Open FTP/SFTP connections as their own drives (SPEC-011 §2).
//
// An open connection used to be invisible: `enterNetwork` was called with no drive volume,
// so the drive bar fell back to matching the panel's path by prefix — and inside a mount the
// path is the server's own "/", which by prefix belongs to the startup disk. The bar therefore
// highlighted the boot drive while the panel was showing a remote server, the tab was titled
// "/", and the only way to hang up was a menu command aimed at whichever panel happened to be
// active.
//
// A connection is registered here the moment it is established and gets a chip of its own,
// exactly like a plugin drive: clicking it goes back to that server (from either panel), and
// the chip's Eject — the place a user looks for "get rid of this drive" — hangs it up.
//
// The `netmount:` path is a sentinel, not a place, and is what tells the drive bar, the tab
// title and `VolumeKind` that this chip is a connection rather than a directory.

import Foundation
import PCVFS

@MainActor
final class NetworkMountRegistry {
    static let shared = NetworkMountRegistry()

    /// Prefix of a connection volume's sentinel path. Mirrors "pfxmount:" for plugin drives.
    static let sentinelPrefix = "netmount:"

    struct Entry {
        let volume: Volume
        let fs: VirtualFileSystem
        /// Where the connection was opened at — where its chip returns to.
        let startPath: String
    }

    /// Called whenever the set of connections changes, so both drive bars rebuild.
    var onChange: (() -> Void)?

    private var entries: [Entry] = []
    private var nextID = 1

    private init() {}

    /// Register a live connection and return the volume that now stands for it.
    ///
    /// `name` is what the chip says. It is made unique because `DriveBarModel.display`
    /// collapses volumes sharing a display name — two sessions on the same host would
    /// otherwise leave one of them with no chip and no way to be hung up.
    @discardableResult
    func register(_ fs: VirtualFileSystem, name: String, fsType: String,
                  startPath: String) -> Volume {
        let id = nextID
        nextID += 1
        let volume = Volume(
            id: "\(Self.sentinelPrefix)\(id)",
            name: uniqueName(from: name),
            path: "\(Self.sentinelPrefix)\(id)",
            isRemovable: true,
            // Ejectable is what puts the ⏏ on the chip and enables its context menu — for a
            // connection that action is "disconnect", routed by the sentinel prefix.
            isEjectable: true,
            isHidden: false,
            capacity: 0, freeSpace: 0,
            fsType: fsType,
            // Pinned just after the boot drive and the plugin drives: a session the user opened
            // seconds ago should not have to be hunted for among the disks.
            sortOrder: 900,
            isLocal: false)
        entries.append(Entry(volume: volume, fs: fs, startPath: startPath))
        onChange?()
        return volume
    }

    /// Register a connection a file-system plugin opened, named from the id the plugin gave it.
    ///
    /// A PFX plugin's connect is interactive and the host learns nothing about the server beyond
    /// that id — "webdav:files.example.org" — which is also what qualifies the mount's saved
    /// columns. Split rather than shown whole: the chip has room for the host, and "webdav:" in
    /// front of it repeats what the kind already says.
    @discardableResult
    func register(_ fs: VirtualFileSystem, connectionID: String, startPath: String) -> Volume {
        let split = NetworkConnectionID.split(connectionID)
        return register(fs, name: split.name,
                        fsType: split.kind ?? String(localized: "Connection"),
                        startPath: startPath)
    }

    /// Drive-bar volumes for every open connection.
    func volumes() -> [Volume] { entries.map(\.volume) }

    var isEmpty: Bool { entries.isEmpty }

    func entry(sentinel: String) -> Entry? { entries.first { $0.volume.path == sentinel } }

    /// The volume standing for `fs`, if it is a registered connection.
    func volume(for fs: VirtualFileSystem) -> Volume? {
        entries.first { $0.fs === fs }?.volume
    }

    /// Forget the connection with this sentinel and hand it back so the caller can hang it up.
    @discardableResult
    func remove(sentinel: String) -> Entry? {
        guard let index = entries.firstIndex(where: { $0.volume.path == sentinel }) else { return nil }
        let entry = entries.remove(at: index)
        onChange?()
        return entry
    }

    /// Forget a connection the panel already tore down on its own (Ctrl+Shift+F, walking up
    /// out of the mount, switching tabs). Without this its chip would outlive the session it
    /// stands for and offer to return to a socket that is closed.
    func remove(fs: VirtualFileSystem) {
        let before = entries.count
        entries.removeAll { $0.fs === fs }
        if entries.count != before { onChange?() }
    }

    /// The display name of a registered connection, for a tab titled with its drive.
    func name(forSentinel sentinel: String) -> String? {
        entry(sentinel: sentinel)?.volume.name
    }

    /// `name`, or "name (2)", "name (3)"… when chips already carry it.
    private func uniqueName(from name: String) -> String {
        let base = name.trimmingCharacters(in: .whitespaces).isEmpty
            ? String(localized: "Connection") : name
        let taken = Set(entries.map { $0.volume.name.lowercased() })
        guard taken.contains(base.lowercased()) else { return base }
        var n = 2
        while taken.contains("\(base) (\(n))".lowercased()) { n += 1 }
        return "\(base) (\(n))"
    }
}
