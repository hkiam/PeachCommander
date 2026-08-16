// SPDX-License-Identifier: Apache-2.0
// CarvedDriver.swift — an image with no table and no filesystem at the front.
//
// This is the last driver tried, and the only one that finds its own offsets. Everything
// before it is handed a starting point: byte 0 for a bare filesystem, a partition entry
// for a disk image. Router and camera firmware has neither. It is a vendor header, a
// bootloader, a kernel and a rootfs written one after another at offsets recorded
// nowhere, and until this existed such a file was refused — the plugin looked at byte 0,
// found a vendor header it did not recognise, and declined a file whose rootfs it could
// have read perfectly well two megabytes in.
//
// What the user sees is one entry per region, in offset order:
//
//     0x00000000-firmware.trx
//     0x0000005c-unknown.bin
//     0x00030040-kernel.uimage
//     0x00230044-squashfs/
//
// Filesystems are directories to walk into. Everything else is a file to copy out —
// which is the point for the bootloader and the kernel, the two things nobody can browse
// but everybody wants to extract. The offset is in the name because in this format it is
// the identifying fact: there are no names on disk to use instead, two regions of the
// same type are told apart only by where they start, and anybody who moves on to
// `dd` or a disassembler needs that number anyway.
//
// **The driver refuses an image in which it found no filesystem.** Its probe accepts
// anything — it has to, since only a full scan can answer the question — so this
// refusal is what keeps the plugin from claiming every unrecognised `.bin` file it is
// ever shown. A file that is merely unknown data comes back as "not this format", the
// host falls back to its own readers, and nothing has been misreported.

import Foundation

final class CarvedDriver: ImageFilesystemDriver {
    static let id = "carved"

    private let reader: ImageReader
    private let regions: [LayoutRegion]
    /// Maps one of our entries to the region it came from, and — for a file inside a
    /// carved filesystem — to that driver's own entry index.
    private var origin: [Int: (region: Int, entry: Int?)] = [:]

    private(set) var entries: [ImageEntry] = []
    private(set) var droppedNames = 0

    var formatDescription: String {
        let found = regions.filter(\.isFilesystem).count
        return "carved image, \(regions.count) regions (\(found) filesystems)"
    }

    /// Accepts anything large enough to hold a filesystem.
    ///
    /// There is no cheap test that answers this question: whether an image carries an
    /// embedded filesystem can only be settled by looking for one, and looking for one
    /// is the expensive part. So the decision moves into `init`, which throws
    /// `.notThisFormat` when the scan comes back with nothing — the same answer the
    /// host would have got from a probe, arrived at honestly. This is safe only because
    /// the driver is registered last and therefore never sees an image another driver
    /// wanted.
    static func probe(_ reader: ImageReader) -> Bool {
        reader.size >= ImageLayout.Limits.minFilesystemLength
            && reader.size <= ImageLayout.Limits.maxCarveLength
    }

    init(reader: ImageReader) throws {
        self.reader = reader
        self.regions = try ImageLayout.scan(reader)

        // Nothing browsable found: not an image this plugin should claim. Said before
        // any entry is built, so a file that is simply not an image costs one scan and
        // produces no listing at all.
        guard regions.contains(where: \.isFilesystem) else { throw ImageError.notThisFormat }

        var collector = EntryCollector()
        for (index, region) in regions.enumerated() {
            guard let name = EntryPath.make(parent: "", component: region.entryName) else {
                collector.dropName()
                continue
            }

            guard case .filesystem(let driver) = region.kind else {
                origin[collector.entries.count] = (index, nil)
                try collector.add(ImageEntry(path: name, size: region.length, mtime: 0,
                                             kind: .file, mode: 0o100644,
                                             locator: UInt64(bitPattern: region.offset)))
                continue
            }

            try collector.add(ImageEntry(path: name, size: -1, mtime: 0, kind: .directory,
                                         mode: 0o040755, locator: UInt64(bitPattern: region.offset)))
            for (entryIndex, entry) in driver.entries.enumerated() {
                // Both halves are sanitised already — ours by `EntryPath` just above, the
                // driver's by whichever driver produced it — so this is a join, not a
                // second validation. Passing it through `EntryPath.make` would reject
                // every nested path for containing a slash.
                origin[collector.entries.count] = (index, entryIndex)
                try collector.add(ImageEntry(path: "\(name)/\(entry.path)", size: entry.size,
                                             mtime: entry.mtime, kind: entry.kind,
                                             mode: entry.mode, locator: entry.locator))
            }
            droppedNames += driver.droppedNames
        }
        entries = collector.entries
        droppedNames += collector.droppedNames
    }

    func extract(at index: Int, to handle: FileHandle) throws {
        guard let source = origin[index] else {
            throw ImageError.damaged(reason: "no file data for entry \(index)")
        }
        let region = regions[source.region]
        guard let entry = source.entry else {
            // A blob: the raw bytes of the region, copied straight out. This is how the
            // bootloader and the kernel leave the image.
            return try reader.copy(at: region.offset, count: region.length, to: handle)
        }
        guard case .filesystem(let driver) = region.kind else {
            throw ImageError.damaged(reason: "entry \(index) claims a filesystem that is not one")
        }
        try driver.extract(at: entry, to: handle)
    }
}
