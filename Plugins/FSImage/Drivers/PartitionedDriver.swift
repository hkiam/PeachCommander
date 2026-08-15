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

import Foundation

final class PartitionedDriver: ImageFilesystemDriver {
    static let id = "partitions"

    private let path: String
    private let partitions: [Partition]
    /// The driver serving each partition, by partition index. Absent where nothing
    /// could open it.
    private var drivers: [Int: any ImageFilesystemDriver] = [:]
    /// Maps an entry of ours back to (partition index, that driver's own entry index).
    private var origin: [Int: (partition: Int, entry: Int)] = [:]

    private(set) var entries: [ImageEntry] = []
    private(set) var droppedNames = 0

    var formatDescription: String {
        let readable = drivers.count
        return "disk image, \(partitions.count) partitions (\(readable) readable)"
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
                  let type = DriverRegistry.driverType(for: window, excluding: Self.self),
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
        entries = collector.entries
        droppedNames += collector.droppedNames
    }

    func extract(at index: Int, to handle: FileHandle) throws {
        guard let source = origin[index], let driver = drivers[source.partition] else {
            throw ImageError.damaged(reason: "no file data for entry \(index)")
        }
        try driver.extract(at: source.entry, to: handle)
    }
}
