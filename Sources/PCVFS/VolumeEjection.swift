// SPDX-License-Identifier: Apache-2.0
// VolumeEjection.swift - Which volume an "Eject" actually means (F-006).
//
// Ejecting was never built. `Volume.isEjectable` was read from the filesystem and then used for
// nothing, while the parity inventory counted the property as evidence for the feature — so the app
// knew which volumes could be ejected and offered no way to do it.
//
// The part worth testing is not the call to AppKit, which either works or reports why. It is *which
// volume is meant*, because that is where this goes wrong in ways a user pays for: the cursor is on
// a folder inside a stick, or on the stick itself, or on nothing in particular, or — the one that
// must never happen — the answer works out to the startup disk.

import Foundation

public enum VolumeEjection {

    /// Why there is nothing to eject. Each case is a different sentence to the user, which is the
    /// reason they are separate: "this is not on a removable volume" and "this volume cannot be
    /// ejected" are both true of a folder in your home directory, and only the first is useful.
    public enum Refusal: Error, Equatable, Sendable {
        /// Nothing here belongs to a volume the app knows about.
        case noVolume
        /// The startup disk. Not offered, not attempted.
        case bootVolume
        /// A real volume that the filesystem says cannot be ejected — a network share, a disk image
        /// the system holds, an internal partition.
        case notEjectable(name: String)
    }

    /// The volume an eject command should act on.
    ///
    /// - Parameters:
    ///   - focusedPath: the item under the cursor, if any. Checked first, because a user who has
    ///     selected a volume means *that* volume even when the panel is showing `/Volumes`.
    ///   - currentDirectory: where the panel is. Used when the cursor says nothing useful, so that
    ///     "eject" works while browsing inside a stick rather than only from one directory above it.
    ///   - volumes: what is mounted.
    public static func target(focusedPath: String?,
                              currentDirectory: String,
                              volumes: [Volume]) -> Result<Volume, Refusal> {
        if let focusedPath, let exact = volumes.first(where: { same($0.path, focusedPath) }) {
            return verdict(for: exact)
        }
        // The *deepest* containing volume, not the first match: every path is inside "/", so a
        // shallower match would answer "the startup disk" for a file on a stick — which is both
        // wrong and the one answer that must never be acted on.
        let containing = volumes
            .filter { contains(volume: $0.path, path: focusedPath ?? currentDirectory) }
            .max(by: { $0.path.count < $1.path.count })
        guard let containing else { return .failure(.noVolume) }
        return verdict(for: containing)
    }

    private static func verdict(for volume: Volume) -> Result<Volume, Refusal> {
        if same(volume.path, "/") { return .failure(.bootVolume) }
        guard volume.isEjectable else { return .failure(.notEjectable(name: volume.name)) }
        return .success(volume)
    }

    /// Two paths naming the same place. Trailing separators are noise: `/Volumes/Stick` and
    /// `/Volumes/Stick/` are one volume, and the drive bar and the panel do not agree on which form
    /// they hand out.
    static func same(_ a: String, _ b: String) -> Bool { trimmed(a) == trimmed(b) }

    /// Whether `path` is inside `volume` — on a component boundary, so `/Volumes/Backup2` is not
    /// treated as living inside `/Volumes/Backup`. The volume itself counts as inside itself.
    public static func contains(volume: String, path: String) -> Bool {
        let root = trimmed(volume), inside = trimmed(path)
        if root == inside { return true }
        if root == "" { return true }        // "/" contains everything
        return inside.hasPrefix(root + "/")
    }

    /// A path without its trailing separators; "/" becomes "" so it prefixes everything.
    private static func trimmed(_ path: String) -> String {
        var s = path
        while s.count > 1, s.hasSuffix("/") { s.removeLast() }
        return s == "/" ? "" : s
    }
}
