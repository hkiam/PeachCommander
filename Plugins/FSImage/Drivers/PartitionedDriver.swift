// SPDX-License-Identifier: Apache-2.0
// PartitionedDriver.swift — a disk image with a partition table, listed one directory per partition.
//
// This is not a filesystem reader. It is the one driver that reads no format of its own:
// it finds the partitions, opens each with whichever driver claims it, and presents them
// side by side. A disk image with an EFI system partition and a Linux root lists as
// `1-EFI/` and `2-Linux/`, each holding that partition's tree.
//
// Two decisions worth stating.
//
// **Partitions this build cannot read still appear.** An unrecognised or unsupported
// partition is listed as an empty directory with its type in the name, not omitted.
// Somebody auditing a device needs to see that a third partition exists even when its
// contents are out of reach — a silently shortened partition list is a wrong answer
// about the hardware, not just about the file.
//
// **The recursion is one level deep.** A partition containing another partition table is
// not walked. That combination is vanishingly rare in practice and unbounded in
// principle, and one level covers every real disk image.
//
// **What is outside every partition is listed too.** A partition table describes only
// the partitions, and on an embedded device the interesting part is often not in one:
// a Raspberry Pi image keeps its bootloader in the four megabytes ahead of partition 1,
// and U-Boot on most ARM boards lives at a fixed sector offset in the same unclaimed
// space. Listing only the partitions means an image that plainly contains a bootloader
// appears not to, which is the wrong answer about the device. Those runs appear
// alongside the partitions as extractable blobs, named and sized like the ones a carved
// image produces.

import Foundation

final class PartitionedDriver: ImageFilesystemDriver {
    static let id = "partitions"

    /// Unclaimed runs shorter than this are not reported.
    ///
    /// Every partitioned image has small structural gaps that are not content: the MBR
    /// itself is one sector, GPT reserves 34 at the front and 33 at the back, and a
    /// partition aligned to a megabyte boundary leaves slack behind it. Listing those
    /// would put two or three meaningless entries in the root of every disk image and
    /// bury the one gap that matters. A bootloader region is measured in megabytes;
    /// nothing real is lost at this threshold.
    private static let minimumGap: Int64 = 64 << 10

    private let path: String
    private let partitions: [Partition]
    /// The driver serving each partition, by partition index. Absent where nothing
    /// could open it.
    private var drivers: [Int: any ImageFilesystemDriver] = [:]
    /// Maps an entry of ours back to (partition index, that driver's own entry index).
    private var origin: [Int: (partition: Int, entry: Int)] = [:]
    /// Entries that are raw runs of the image rather than anything inside a partition.
    private var blobs: [Int: LayoutRegion] = [:]
    /// The reader for the whole image, kept so those runs can be copied out.
    private let reader: ImageReader

    private(set) var entries: [ImageEntry] = []
    private(set) var droppedNames = 0

    var formatDescription: String {
        let readable = drivers.count
        var text = "disk image, \(partitions.count) partitions (\(readable) readable)"
        if !blobs.isEmpty { text += ", \(blobs.count) unallocated" }
        return text
    }

    static func probe(_ reader: ImageReader) -> Bool {
        // Only claim an image that has a table *and* is not itself a filesystem some
        // other driver would rather read. A filesystem's own first sector can end in
        // 0x55AA by coincidence — FAT boot sectors do, deliberately — so this driver
        // is registered last and only sees images nothing else wanted.
        ((try? PartitionTable.read(reader)) ?? nil)?.isEmpty == false
    }

    init(reader: ImageReader) throws {
        self.path = reader.path
        self.reader = reader
        guard let partitions = try PartitionTable.read(reader), !partitions.isEmpty else {
            throw ImageError.notThisFormat
        }
        self.partitions = partitions

        var collector = EntryCollector()
        for (index, partition) in partitions.enumerated() {
            guard let name = EntryPath.make(parent: "", component: partition.directoryName) else {
                collector.dropName()
                continue
            }
            try collector.add(ImageEntry(path: name, size: -1, mtime: 0, kind: .directory,
                                         mode: 0o040755, locator: UInt64(partition.number)))

            // A partition that cannot be opened is still listed — see the note above —
            // so a failure here is recorded by omission of its contents, not by
            // dropping the partition.
            guard partition.length > 0,
                  let window = try? ImageReader(path: reader.path,
                                                windowOffset: partition.offset,
                                                windowLength: partition.length),
                  let type = DriverRegistry.driverType(for: window,
                                                       excluding: [Self.self, CarvedDriver.self]),
                  let driver = try? type.init(reader: window) else { continue }

            drivers[index] = driver
            for (entryIndex, entry) in driver.entries.enumerated() {
                // Both halves are already sanitised — the partition name by `EntryPath`
                // just above, the entry path by the driver that produced it — so this is
                // a join, not another validation. Running `EntryPath.make` on it would
                // reject every nested path for containing a slash.
                origin[collector.entries.count] = (index, entryIndex)
                try collector.add(ImageEntry(path: "\(name)/\(entry.path)", size: entry.size,
                                             mtime: entry.mtime, kind: entry.kind,
                                             mode: entry.mode, locator: entry.locator))
            }
            droppedNames += driver.droppedNames
        }

        for region in try Self.unallocatedRegions(reader, partitions: partitions) {
            guard let name = EntryPath.make(parent: "", component: region.entryName) else {
                collector.dropName()
                continue
            }
            blobs[collector.entries.count] = region
            try collector.add(ImageEntry(path: name, size: region.length, mtime: 0,
                                         kind: .file, mode: 0o100644,
                                         locator: UInt64(bitPattern: region.offset)))
        }

        entries = collector.entries
        droppedNames += collector.droppedNames
    }

    /// The runs of the image no partition covers, identified where possible.
    ///
    /// Partitions are sorted by offset first rather than taken in table order: MBR
    /// entries may be written in any order, logical partitions are appended after the
    /// primaries regardless of where they sit on the disk, and computing gaps from an
    /// unsorted list produces negative-length nonsense. Overlapping partitions — which a
    /// damaged table does describe — are absorbed by carrying the cursor forward with
    /// `max`, never backwards.
    private static func unallocatedRegions(_ reader: ImageReader,
                                           partitions: [Partition]) throws -> [LayoutRegion] {
        var result: [LayoutRegion] = []
        var cursor: Int64 = 0
        for partition in partitions.sorted(by: { $0.offset < $1.offset }) {
            let end = min(partition.offset, reader.count)
            if end - cursor >= minimumGap {
                result += try ImageLayout.describe(reader, from: cursor, to: end)
            }
            cursor = max(cursor, partition.offset + partition.length)
        }
        if reader.count - cursor >= minimumGap {
            result += try ImageLayout.describe(reader, from: cursor, to: reader.count)
        }
        return result
    }

    func extract(at index: Int, to handle: FileHandle) throws {
        if let region = blobs[index] {
            return try reader.copy(at: region.offset, count: region.length, to: handle)
        }
        guard let source = origin[index], let driver = drivers[source.partition] else {
            throw ImageError.damaged(reason: "no file data for entry \(index)")
        }
        try driver.extract(at: source.entry, to: handle)
    }
}
