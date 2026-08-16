// SPDX-License-Identifier: Apache-2.0
// FATDriver.swift — FAT12, FAT16 and FAT32, read-only.
//
// One driver for all three, because they are one filesystem with three widths of the
// same allocation table. What actually differs is how many bits a table entry has and,
// for FAT32 only, that the root directory is an ordinary cluster chain rather than a
// fixed-size region before the data area. Splitting them would mean three copies of the
// same directory parser disagreeing about edge cases.
//
// Worth having even though macOS mounts FAT natively: this reads a partition *inside* a
// disk image without attaching it, needs no admin, touches nothing, and reads images
// macOS refuses. For firmware work that is the difference between looking at an EFI
// system partition and mounting a stranger's disk.
//
// Two things carry the weight:
//
//   * **Long names.** A name that is not 8.3 is stored as a chain of preceding entries
//     holding UTF-16 fragments in reverse order, tied to the real entry by a checksum of
//     its short name. Ignoring them shows `PATTER~1.DAT` where the file is called
//     `pattern.dat` — plausible, wrong, and exactly what somebody searching a firmware
//     dump for a filename would be defeated by.
//   * **FAT12's packed entries.** Two entries share three bytes, so an entry is either
//     the low or the high twelve bits of a 16-bit read depending on whether its index is
//     even. FAT12 only appears on small media, but that includes plenty of embedded
//     boot partitions.

import Foundation

final class FATDriver: ImageFilesystemDriver {
    static let id = "fat"

    private let reader: ImageReader
    private let bits: Int                 // 12, 16 or 32
    private let bytesPerCluster: Int64
    private let firstDataSector: Int64
    private let bytesPerSector: Int64
    private let fatStart: Int64
    private let rootDirectorySector: Int64   // FAT12/16 only
    private let rootDirectoryEntries: Int
    private let rootCluster: UInt32          // FAT32 only
    private let clusterCount: UInt32

    private(set) var entries: [ImageEntry] = []
    private(set) var droppedNames = 0
    /// First cluster and size for each regular file, by entry index.
    private var fileData: [Int: (cluster: UInt32, size: Int64)] = [:]

    var formatDescription: String { "FAT\(bits), \(bytesPerCluster / 1024) KB clusters" }

    // MARK: - Boot sector

    static func probe(_ reader: ImageReader) -> Bool {
        guard let boot = try? reader.bytes(at: 0, count: 512) else { return false }
        guard boot[510] == 0x55, boot[511] == 0xAA else { return false }
        // The BIOS Parameter Block has to be self-consistent. Checking it rather than a
        // magic string is the only way: FAT has no magic, and the 0x55AA signature is
        // shared with every partition table and boot sector on the planet.
        let bytesPerSector = Int(boot[11]) | Int(boot[12]) << 8
        guard [512, 1024, 2048, 4096].contains(bytesPerSector) else { return false }
        let sectorsPerCluster = Int(boot[13])
        guard sectorsPerCluster > 0, sectorsPerCluster & (sectorsPerCluster - 1) == 0,
              sectorsPerCluster <= 128 else { return false }
        let reservedSectors = Int(boot[14]) | Int(boot[15]) << 8
        guard reservedSectors > 0 else { return false }
        let fatCount = Int(boot[16])
        return fatCount >= 1 && fatCount <= 4
    }

    /// The boot-sector signature, and nothing better exists: FAT has no magic string of
    /// its own. Two bytes match by chance about once every 64 KB, so a scan produces a
    /// crowd of candidates here — all of which die in `probe` above, which checks that
    /// the BIOS Parameter Block is self-consistent. This is the signature that most
    /// depends on confirmation, and the reason confirmation is not optional.
    static let carveSignatures = [CarveSignature([0x55, 0xAA], at: 510)]

    static func byteLength(_ reader: ImageReader) -> Int64? {
        guard let bytesPerSector = try? reader.u16le(at: 11),
              [512, 1024, 2048, 4096].contains(Int(bytesPerSector)),
              let small = try? reader.u16le(at: 19),
              let large = try? reader.u32le(at: 32) else { return nil }
        // The 16-bit count is used when it fits and is zero otherwise, in which case
        // the 32-bit field at 32 carries it.
        let sectors = small != 0 ? Int64(small) : Int64(large)
        guard sectors > 0 else { return nil }
        return sectors * Int64(bytesPerSector)
    }

    init(reader: ImageReader) throws {
        self.reader = reader
        let boot = try reader.bytes(at: 0, count: 512)
        guard Self.probe(reader) else { throw ImageError.notThisFormat }

        bytesPerSector = Int64(Int(boot[11]) | Int(boot[12]) << 8)
        let sectorsPerCluster = Int64(boot[13])
        let reservedSectors = Int64(Int(boot[14]) | Int(boot[15]) << 8)
        let fatCount = Int64(boot[16])
        rootDirectoryEntries = Int(boot[17]) | Int(boot[18]) << 8

        let totalSectors16 = Int64(Int(boot[19]) | Int(boot[20]) << 8)
        let sectorsPerFAT16 = Int64(Int(boot[22]) | Int(boot[23]) << 8)
        let totalSectors32 = Int64(Self.u32(boot, 32))
        let sectorsPerFAT32 = Int64(Self.u32(boot, 36))

        let totalSectors = totalSectors16 != 0 ? totalSectors16 : totalSectors32
        let sectorsPerFAT = sectorsPerFAT16 != 0 ? sectorsPerFAT16 : sectorsPerFAT32
        guard totalSectors > 0, sectorsPerFAT > 0 else {
            throw ImageError.damaged(reason: "the BPB records no size")
        }

        bytesPerCluster = bytesPerSector * sectorsPerCluster
        fatStart = reservedSectors * bytesPerSector
        rootDirectorySector = reservedSectors + fatCount * sectorsPerFAT
        let rootDirectorySectors =
            (Int64(rootDirectoryEntries) * 32 + bytesPerSector - 1) / bytesPerSector
        firstDataSector = rootDirectorySector + rootDirectorySectors

        // The cluster count is what decides the FAT width — not the label in the boot
        // sector, which is advisory and frequently wrong. These two thresholds are the
        // definition of the format, not a heuristic.
        let dataSectors = totalSectors - firstDataSector
        guard dataSectors > 0 else { throw ImageError.damaged(reason: "no data area") }
        clusterCount = UInt32(dataSectors / sectorsPerCluster)
        bits = clusterCount < 4085 ? 12 : (clusterCount < 65525 ? 16 : 32)
        rootCluster = bits == 32 ? Self.u32(boot, 44) : 0

        var collector = EntryCollector()
        var visited = Set<UInt32>()
        if bits == 32 {
            try walkDirectory(cluster: rootCluster, path: "", depth: 0,
                              visited: &visited, collector: &collector)
        } else {
            // FAT12/16 keep the root in a fixed region before the data area, with no
            // cluster chain and a size fixed at format time.
            let bytes = try reader.bytes(at: rootDirectorySector * bytesPerSector,
                                         count: rootDirectoryEntries * 32)
            try parseDirectory(bytes, path: "", depth: 0, visited: &visited, collector: &collector)
        }
        entries = collector.entries
        droppedNames = collector.droppedNames
    }

    private static func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
    }
    private static func u16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    // MARK: - Cluster chains

    private func clusterOffset(_ cluster: UInt32) -> Int64 {
        // Clusters are numbered from 2: the first two table entries hold the media
        // descriptor and end-of-chain marker instead of mapping anything.
        firstDataSector * bytesPerSector + Int64(cluster - 2) * bytesPerCluster
    }

    /// The next cluster in a chain, or nil at its end.
    private func nextCluster(after cluster: UInt32) throws -> UInt32? {
        let value: UInt32
        switch bits {
        case 12:
            // Packed: two entries per three bytes, so the same 16-bit read serves both
            // and which half to keep depends on the index's parity.
            let offset = fatStart + Int64(cluster) + Int64(cluster / 2)
            let raw = UInt32(try reader.u16le(at: offset))
            value = cluster % 2 == 0 ? raw & 0x0FFF : raw >> 4
        case 16:
            value = UInt32(try reader.u16le(at: fatStart + Int64(cluster) * 2))
        default:
            value = try reader.u32le(at: fatStart + Int64(cluster) * 4) & 0x0FFF_FFFF
        }
        let endOfChain: UInt32 = bits == 12 ? 0x0FF8 : (bits == 16 ? 0xFFF8 : 0x0FFF_FFF8)
        guard value < endOfChain, value >= 2, value < clusterCount + 2 else { return nil }
        return value
    }

    /// Every cluster of a chain, bounded so a table with a loop in it cannot spin.
    private func chain(from first: UInt32) throws -> [UInt32] {
        guard first >= 2, first < clusterCount + 2 else { return [] }
        var clusters: [UInt32] = []
        var seen = Set<UInt32>()
        var current: UInt32? = first
        while let cluster = current {
            guard seen.insert(cluster).inserted else {
                throw ImageError.damaged(reason: "cluster chain loops at \(cluster)")
            }
            guard clusters.count <= ImageLimits.maxEntries else {
                throw ImageError.limitExceeded(limit: "cluster chain length")
            }
            clusters.append(cluster)
            current = try nextCluster(after: cluster)
        }
        return clusters
    }

    // MARK: - Directories

    private func walkDirectory(cluster: UInt32, path: String, depth: Int,
                               visited: inout Set<UInt32>, collector: inout EntryCollector) throws {
        guard visited.insert(cluster).inserted else {
            throw ImageError.damaged(reason: "directory cycle at \(path.isEmpty ? "/" : path)")
        }
        var bytes = [UInt8]()
        for chunk in try chain(from: cluster) {
            bytes.append(contentsOf: try reader.bytes(at: clusterOffset(chunk),
                                                      count: Int(bytesPerCluster)))
        }
        try parseDirectory(bytes, path: path, depth: depth, visited: &visited, collector: &collector)
    }

    private func parseDirectory(_ bytes: [UInt8], path: String, depth: Int,
                                visited: inout Set<UInt32>, collector: inout EntryCollector) throws {
        try EntryCollector.checkDepth(depth)
        var subdirectories: [(cluster: UInt32, path: String)] = []
        /// UTF-16 fragments of a long name, collected until the short entry they belong
        /// to arrives. They are stored in *reverse* order, hence the prepending.
        var longName: [UInt16] = []
        var longNameChecksum: UInt8?

        var offset = 0
        while offset + 32 <= bytes.count {
            defer { offset += 32 }
            let entry = Array(bytes[offset..<(offset + 32)])
            if entry[0] == 0x00 { break }        // no entry here or after
            if entry[0] == 0xE5 { longName = []; longNameChecksum = nil; continue }   // deleted

            let attributes = entry[11]
            if attributes & 0x0F == 0x0F {
                // A long-name fragment: 13 UTF-16 units split across three ranges.
                var units: [UInt16] = []
                for range in [(1, 5), (14, 6), (28, 2)] {
                    for unit in 0..<range.1 {
                        units.append(Self.u16(entry, range.0 + unit * 2))
                    }
                }
                longName = units + longName
                longNameChecksum = entry[13]
                continue
            }
            if attributes & 0x08 != 0 { longName = []; longNameChecksum = nil; continue }  // volume label

            let shortName = Self.shortName(entry)
            // The checksum ties the fragments to this entry. Without it, fragments left
            // behind by a deleted file would be attached to the next real one.
            var name = shortName
            if let checksum = longNameChecksum, checksum == Self.shortNameChecksum(entry),
               let decoded = Self.decodeLongName(longName) {
                name = decoded
            }
            longName = []
            longNameChecksum = nil

            if name == "." || name == ".." { continue }
            guard let childPath = EntryPath.make(parent: path, component: name) else {
                collector.dropName()
                continue
            }

            let cluster = UInt32(Self.u16(entry, 26)) | UInt32(Self.u16(entry, 20)) << 16
            let size = Int64(Self.u32(entry, 28))
            let mtime = Self.timestamp(date: Self.u16(entry, 24), time: Self.u16(entry, 22))

            if attributes & 0x10 != 0 {
                try collector.add(ImageEntry(path: childPath, size: -1, mtime: mtime,
                                             kind: .directory, mode: 0o040755,
                                             locator: UInt64(cluster)))
                subdirectories.append((cluster, childPath))
            } else {
                let index = collector.entries.count
                try collector.add(ImageEntry(path: childPath, size: size, mtime: mtime,
                                             kind: .file, mode: 0o100644, locator: UInt64(cluster)))
                fileData[index] = (cluster, size)
            }
        }

        for child in subdirectories {
            try walkDirectory(cluster: child.cluster, path: child.path, depth: depth + 1,
                              visited: &visited, collector: &collector)
        }
    }

    /// The 8.3 name, trimmed and lowercased the way every FAT tool shows it.
    private static func shortName(_ entry: [UInt8]) -> String {
        func trimmed(_ range: Range<Int>) -> String {
            let raw = entry[range].prefix { $0 != 0x20 }
            return String(decoding: raw, as: UTF8.self)
        }
        let base = trimmed(0..<8)
        let ext = trimmed(8..<11)
        let name = ext.isEmpty ? base : "\(base).\(ext)"
        return name.lowercased()
    }

    /// The checksum a long-name chain carries to identify its short entry: a rotating
    /// sum over the raw 11 bytes of the 8.3 name.
    private static func shortNameChecksum(_ entry: [UInt8]) -> UInt8 {
        var sum: UInt8 = 0
        for index in 0..<11 {
            sum = (sum >> 1) &+ (sum << 7) &+ entry[index]
        }
        return sum
    }

    private static func decodeLongName(_ units: [UInt16]) -> String? {
        guard !units.isEmpty else { return nil }
        // Unused positions are padded with 0xFFFF after a terminating NUL.
        var trimmed: [UInt16] = []
        for unit in units {
            if unit == 0 || unit == 0xFFFF { break }
            trimmed.append(unit)
        }
        guard !trimmed.isEmpty else { return nil }
        return String(decoding: trimmed, as: UTF16.self)
    }

    /// FAT's packed date and time, in local time with two-second resolution. Converted
    /// as UTC: the format records no zone, so inventing one would be a guess that shifts
    /// every timestamp in the image.
    private static func timestamp(date: UInt16, time: UInt16) -> Int64 {
        guard date != 0 else { return 0 }
        var components = DateComponents()
        components.year = 1980 + Int(date >> 9)
        components.month = Int((date >> 5) & 0x0F)
        components.day = Int(date & 0x1F)
        components.hour = Int(time >> 11)
        components.minute = Int((time >> 5) & 0x3F)
        components.second = Int(time & 0x1F) * 2
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: components).map { Int64($0.timeIntervalSince1970) } ?? 0
    }

    // MARK: - Extraction

    func extract(at index: Int, to handle: FileHandle) throws {
        guard entries.indices.contains(index), let file = fileData[index] else {
            throw ImageError.damaged(reason: "no file data for entry \(index)")
        }
        var remaining = file.size
        for cluster in try chain(from: file.cluster) {
            guard remaining > 0 else { break }
            let take = min(remaining, bytesPerCluster)
            try reader.copy(at: clusterOffset(cluster), count: take, to: handle)
            remaining -= take
        }
        // A chain shorter than the recorded size is a damaged image; padding it would
        // hand back a file of the right length with the wrong contents.
        guard remaining == 0 else {
            throw ImageError.damaged(
                reason: "\(entries[index].path): the cluster chain ends \(remaining) bytes early")
        }
    }
}
