// SPDX-License-Identifier: Apache-2.0
// VolumeKind.swift - What sort of thing a volume is (F-386).
//
// The drive bar drew three icons in total: a screen for the boot disk, whatever emoji a plugin
// supplied, and one floppy for everything else — so a network share, a USB stick and a mounted disk
// image were indistinguishable in the one place they are listed side by side. Finder answers this
// with the volume's own icon, and so does the bar now; this enum is the part that has to be said in
// words rather than drawn: the VoiceOver label, and the glyph shown for a volume the system gives no
// icon for.
//
// Classification lives here, away from the view, because it is a rule about data and the interesting
// part of it is the *order* of the questions — see `of(_:)`.

import Foundation

public enum VolumeKind: String, Sendable, Equatable, CaseIterable {
    case startupDisk
    case internalDisk
    case externalDisk
    case networkShare
    /// A live FTP/SFTP session the app itself opened, as opposed to a share the system mounted.
    case networkConnection
    case cloudFolder
    case pluginDrive

    /// What `volume` is, decided from what the system actually told us about it.
    ///
    /// The order is the whole of it, because the categories overlap in the data:
    ///
    /// * A plugin drive is asked about first: its "path" is the `pfxmount:` sentinel, not a place, so
    ///   every question below it would be answered about a path that does not exist.
    /// * A cloud folder next: it *is* a local directory on the startup disk, so every later question
    ///   would call it an internal volume.
    /// * A share before the startup disk is a matter of taste, but "/" is never remote, and asking
    ///   `isLocal` first keeps the one case that must never be got wrong — the boot disk — reading as
    ///   a single, obvious line.
    ///
    /// Note what is *not* decided here: an external disk and a mounted disk image both report
    /// "ejectable", and nothing in `Volume` separates them. Rather than guess, the bar draws the
    /// system's own icon, which knows the difference; this enum only claims what it can defend.
    public static func of(_ volume: Volume) -> VolumeKind {
        if volume.path.hasPrefix("pfxmount:") { return .pluginDrive }
        // Same reason as the plugin drive above, and asked before `isLocal`: a connection is not
        // local either, and calling it a network *share* would promise a mount the system knows
        // about — one Finder can see and the user can unmount from anywhere but here.
        if volume.path.hasPrefix("netmount:") { return .networkConnection }
        if volume.fsType == "Cloud" { return .cloudFolder }
        if !volume.isLocal { return .networkShare }
        if volume.path == "/" { return .startupDisk }
        if volume.isRemovable || volume.isEjectable { return .externalDisk }
        return .internalDisk
    }

    /// Whether asking the system for this volume's icon is worth doing.
    ///
    /// A cloud folder is a *directory* on the startup disk, so what comes back is the generic blue
    /// folder — which says less than the glyph does, and says the same thing as every other folder
    /// on screen. A plugin drive has no path to ask about at all. For the rest the system's icon is
    /// the whole point: it knows a share from a stick from a mounted image, and it carries the
    /// custom icon a branded drive ships with.
    public var hasSystemIcon: Bool {
        switch self {
        case .startupDisk, .internalDisk, .externalDisk, .networkShare: return true
        // A connection's "path" is the `netmount:` sentinel — there is nothing to ask about.
        case .cloudFolder, .pluginDrive, .networkConnection: return false
        }
    }

    /// The glyph to draw when there is no icon to draw instead — a plugin drive that supplied none,
    /// or a volume whose icon has not been read yet. Deliberately distinct per kind: this is the
    /// state a user sees for the first fraction of a second, and a placeholder that says "some
    /// volume" would flicker into something else and teach nothing in the meantime.
    public var glyph: String {
        switch self {
        case .startupDisk: return "🖥"
        case .internalDisk: return "💽"
        case .externalDisk: return "💾"
        case .networkShare: return "🌐"
        // Distinct from the share's globe on purpose: this one can be hung up from its chip and
        // is gone when the app quits, which is not true of anything else in the bar.
        case .networkConnection: return "🔌"
        case .cloudFolder: return "☁️"
        case .pluginDrive: return "🧩"
        }
    }
}
