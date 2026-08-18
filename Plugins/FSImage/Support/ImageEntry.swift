// SPDX-License-Identifier: Apache-2.0
// ImageEntry.swift — the flat entry list a driver produces, and the name rules it must obey.
//
// Drivers do not hand the host a tree; they hand it a flat, already-sanitised list
// of entries in the order `ReadHeaderEx` should report them. The host builds the
// tree (`PCXArchiveFS.init` splits paths on "/" and synthesizes intermediate
// directories). That split is the reason `EntryPath` exists: the host filters
// nothing, so a path component of ".." in an image would land in its node map as a
// directory named ".." and every later path that walked through it would be wrong.
// Names are therefore cleaned here, before a driver's output can reach the host.

import Foundation

/// One file, directory, symlink or device node inside an image.
struct ImageEntry {
    /// Sanitised, '/'-separated path relative to the image root, without a leading
    /// slash. Built only through `EntryPath.make`.
    let path: String
    /// Uncompressed size in bytes; -1 for directories and anything sizeless.
    let size: Int64
    /// Modification time in Unix epoch seconds, 0 when the format does not record one.
    let mtime: Int64
    let kind: Kind
    /// POSIX mode bits, 0 when unknown. Carried for the properties dialog; the
    /// host's `PcHeaderDataEx` has no mode field, so this is informational.
    let mode: UInt32
    /// Where the driver finds this entry's data again. Opaque to everything here:
    /// a squashfs inode number, an ext4 inode, a byte offset. Keeps the entry list
    /// free of format-specific fields.
    let locator: UInt64

    enum Kind {
        case file
        case directory
        /// Target is kept so the panel can show `name -> target`; the host has no
        /// symlink concept inside an archive, so the entry itself lists as a file.
        case symlink(target: String)
        /// Block/char device, FIFO, socket. Listed with size 0 — they carry no data,
        /// and hiding them would misrepresent a rootfs, where /dev entries matter.
        case special
    }

    var isDirectory: Bool {
        if case .directory = kind { return true }
        return false
    }
}

/// Builds entry paths that are safe to hand to the host.
enum EntryPath {
    /// Join `parent` and `component` into an entry path, or return nil if the
    /// component may not appear in one.
    ///
    /// Refused components, and why each one is refused rather than repaired:
    ///
    ///   * "" — an empty name is not addressable; a repaired one would collide.
    ///   * "." and ".." — the host resolves neither, so they would become literal
    ///     directory nodes and silently redirect every path beneath them.
    ///   * anything containing "/" — the driver would be smuggling a path through
    ///     a field the host reads as a leaf.
    ///   * NUL and C0 control characters — these cross a C ABI as `char[1024]`,
    ///     where an embedded NUL truncates the name at that point and the rest of
    ///     the buffer becomes a different entry's name.
    ///
    /// Refusing rather than sanitising in place is the deliberate choice: a name
    /// that needs repair is evidence about the image, and quietly renaming it would
    /// hide that from whoever is analysing the firmware. The caller drops the entry
    /// and counts it, so the count can be reported.
    static func make(parent: String, component: String) -> String? {
        guard isValidComponent(component) else { return nil }
        return parent.isEmpty ? component : "\(parent)/\(component)"
    }

    static func isValidComponent(_ component: String) -> Bool {
        guard !component.isEmpty, component != ".", component != ".." else { return false }
        guard !component.contains("/") else { return false }
        for scalar in component.unicodeScalars where scalar.value < 0x20 || scalar.value == 0x7F {
            return false
        }
        // The C ABI's fileName buffer is 1024 bytes including its terminator. A name
        // that does not fit would be truncated on the way across, producing an entry
        // the driver cannot be asked for again.
        return component.utf8.count < 255
    }
}

/// Accumulates a driver's entries while enforcing the shared limits.
///
/// Every driver funnels its output through this rather than appending to its own
/// array, so the entry ceiling, the depth ceiling and the dropped-name count are
/// applied once and identically. A driver that grew its own array would be one
/// review away from forgetting a check that the others make.
struct EntryCollector {
    private(set) var entries: [ImageEntry] = []
    /// Entries dropped because their name was refused by `EntryPath`. Surfaced to
    /// the user, because a firmware image full of unrepresentable names is a finding.
    private(set) var droppedNames = 0

    mutating func add(_ entry: ImageEntry) throws {
        guard entries.count < ImageLimits.maxEntries else {
            throw ImageError.limitExceeded(limit: "maxEntries (\(ImageLimits.maxEntries))")
        }
        entries.append(entry)
    }

    mutating func dropName() { droppedNames += 1 }

    /// Correct the size of an entry already added.
    ///
    /// For the one case where the size is not known when the entry is created: a cpio hardlink. `newc`
    /// stores the bytes with the *last* link and writes filesize 0 in the headers of the earlier ones, so
    /// those entries are added with 0 and learn their real length when the twin turns up. Reading them
    /// already worked — the data is resolved through the inode — which is what made the wrong size so easy
    /// to miss: the file opened with its full contents and the listing said 0 bytes.
    mutating func correctSize(at index: Int, to size: Int64) {
        guard entries.indices.contains(index) else { return }
        let old = entries[index]
        entries[index] = ImageEntry(path: old.path, size: size, mtime: old.mtime, kind: old.kind,
                                    mode: old.mode, locator: old.locator)
    }

    /// Check a depth before descending. Called by drivers whose directory walk
    /// recurses; a cycle in a damaged image is otherwise unbounded.
    static func checkDepth(_ depth: Int) throws {
        guard depth <= ImageLimits.maxDepth else {
            throw ImageError.limitExceeded(limit: "maxDepth (\(ImageLimits.maxDepth))")
        }
    }
}
