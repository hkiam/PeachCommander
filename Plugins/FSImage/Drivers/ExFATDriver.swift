// SPDX-License-Identifier: Apache-2.0
// ExFATDriver.swift — exFAT, read-only.
//
// Despite the name, not a wider FAT. It shares the idea of an allocation table and
// almost nothing else: the directory format is entirely different, names are UTF-16
// with no 8.3 alias anywhere, and a file that was written contiguously carries no chain
// at all. A driver built by widening `FATDriver` would be wrong in every one of those
// places, which is why this is its own file.
//
// The directory format is what takes the work. A single file is not one 32-byte record
// but a *set* of them that must be read together:
//
//   0x85  the file entry — attributes, timestamps, and how many entries follow
//   0xC0  the stream extension — size, first cluster, and whether a chain exists
//   0xC1… one or more name entries, 15 UTF-16 units each
//
// Read any of them alone and you have part of a file. The set also carries a checksum
// over all of its entries, which is the only way to tell a live set from one whose
// pieces were partially overwritten.
//
// The other thing worth naming is `NoFatChain`. When set, the file is contiguous and the
// allocation table holds nothing for it — following the table anyway lands on whatever
// the entry for that cluster last described. That flag is the normal case for anything
// written in one go, so getting it wrong does not fail rarely; it fails on almost every
// large file.

import Foundation

final class ExFATDriver: ImageFilesystemDriver {
    static let id = "exfat"

    private let reader: ImageReader
    private let bytesPerCluster: Int64
    private let clusterHeapOffset: Int64
    private let fatOffset: Int64
    private let clusterCount: UInt32
    private let rootCluster: UInt32
    private var volumeLabel = ""

    private(set) var entries: [ImageEntry] = []
    private(set) var droppedNames = 0
    private var fileData: [Int: (cluster: UInt32, size: Int64, contiguous: Bool)] = [:]

    var formatDescription: String {
        let label = volumeLabel.isEmpty ? "" : " \"\(volumeLabel)\""
        return "exFAT\(label), \(bytesPerCluster / 1024) KB clusters"
    }

    private static let signature = Array("EXFAT   ".utf8)

    static func probe(_ reader: ImageReader) -> Bool {
        (try? reader.bytes(at: 3, count: 8)) == signature
    }

    static let carveSignatures = [CarveSignature("EXFAT   ", at: 3)]

    static func byteLength(_ reader: ImageReader) -> Int64? {
        guard let shift = try? reader.u8(at: 108), shift >= 9, shift <= 12,
              let sectors = try? reader.u64le(at: 72), sectors > 0, sectors <= Int64.max
        else { return nil }
        // A shift, unlike a multiply, discards the overflow silently — the answer would
        // be a plausible-looking wrong length rather than a refusal.
        return scaledLength(Int64(sectors), by: Int64(1) << Int64(shift))
    }

    init(reader: ImageReader) throws {
        self.reader = reader
        guard try reader.bytes(at: 3, count: 8) == Self.signature else { throw ImageError.notThisFormat }

        let bytesPerSectorShift = try reader.u8(at: 108)
        let sectorsPerClusterShift = try reader.u8(at: 109)
        guard bytesPerSectorShift >= 9, bytesPerSectorShift <= 12,
              sectorsPerClusterShift <= 25 else {
            throw ImageError.damaged(reason: "implausible exFAT geometry shifts")
        }
        let bytesPerSector = Int64(1) << Int64(bytesPerSectorShift)
        bytesPerCluster = bytesPerSector << Int64(sectorsPerClusterShift)

        fatOffset = Int64(try reader.u32le(at: 80)) * bytesPerSector
        clusterHeapOffset = Int64(try reader.u32le(at: 88)) * bytesPerSector
        clusterCount = try reader.u32le(at: 92)
        rootCluster = try reader.u32le(at: 96)
        guard clusterCount > 0, rootCluster >= 2 else {
            throw ImageError.damaged(reason: "exFAT boot sector has no cluster heap or root")
        }

        // The volume label is a directory entry in the root, not a boot-sector field, so
        // it is picked up during the walk rather than read here.
        var label = ""
        var collector = EntryCollector()
        var visited = Set<UInt32>()
        try walkDirectory(cluster: rootCluster, contiguous: false, path: "", depth: 0,
                          visited: &visited, collector: &collector, volumeLabel: &label)
        volumeLabel = label
        entries = collector.entries
        droppedNames = collector.droppedNames
    }

    // MARK: - Clusters

    private func clusterOffset(_ cluster: UInt32) -> Int64 {
        clusterHeapOffset + Int64(cluster - 2) * bytesPerCluster
    }

    /// The clusters holding a run, following the allocation table only when the file
    /// actually has a chain.
    ///
    /// `contiguous` is `NoFatChain` from the stream extension. When it is set the table
    /// holds nothing for this file and the clusters simply run on from the first — the
    /// normal case for anything written in one go.
    private func clusters(from first: UInt32, count: Int64, contiguous: Bool) throws -> [UInt32] {
        guard first >= 2, first < clusterCount + 2 else { return [] }
        if contiguous {
            let needed = max(1, (count + bytesPerCluster - 1) / bytesPerCluster)
            guard UInt32(clamping: Int64(first) + needed) <= clusterCount + 2 else {
                throw ImageError.damaged(reason: "contiguous run of \(needed) clusters leaves the heap")
            }
            return (0..<needed).map { first + UInt32($0) }
        }
        var chain: [UInt32] = []
        var seen = Set<UInt32>()
        var current = first
        while current >= 2, current < clusterCount + 2 {
            guard seen.insert(current).inserted else {
                throw ImageError.damaged(reason: "cluster chain loops at \(current)")
            }
            guard chain.count <= ImageLimits.maxEntries else {
                throw ImageError.limitExceeded(limit: "cluster chain length")
            }
            chain.append(current)
            let next = try reader.u32le(at: fatOffset + Int64(current) * 4)
            if next >= 0xFFFF_FFF8 { break }
            current = next
        }
        return chain
    }

    // MARK: - Directories

    private func walkDirectory(cluster: UInt32, contiguous: Bool, path: String, depth: Int,
                               visited: inout Set<UInt32>, collector: inout EntryCollector,
                               volumeLabel: inout String) throws {
        try EntryCollector.checkDepth(depth)
        guard visited.insert(cluster).inserted else {
            throw ImageError.damaged(reason: "directory cycle at \(path.isEmpty ? "/" : path)")
        }
        defer { visited.remove(cluster) }

        var bytes = [UInt8]()
        // A directory's own length is not recorded, so it is read cluster by cluster
        // until the chain ends; the terminating 0x00 entry says where it really stops.
        for chunk in try clusters(from: cluster, count: bytesPerCluster, contiguous: false) {
            bytes.append(contentsOf: try reader.bytes(at: clusterOffset(chunk),
                                                      count: Int(bytesPerCluster)))
            guard bytes.count <= ImageLimits.maxBlockSize else { break }
        }
        _ = contiguous

        var subdirectories: [(cluster: UInt32, path: String)] = []
        var offset = 0
        while offset + 32 <= bytes.count {
            let type = bytes[offset]
            if type == 0x00 { break }                      // end of directory
            if type & 0x80 == 0 { offset += 32; continue }  // not in use

            switch type {
            case 0x83:
                // Volume label: a UTF-16 name of `bytes[offset+1]` characters.
                let length = Int(bytes[offset + 1])
                if length > 0, length <= 11 {
                    volumeLabel = Self.utf16(bytes, offset + 2, units: length)
                }
                offset += 32

            case 0x85:
                let consumed = try readFileSet(bytes, at: offset, path: path,
                                               collector: &collector,
                                               subdirectories: &subdirectories)
                offset += consumed

            default:
                offset += 32                                // bitmap, up-case table, …
            }
        }

        for child in subdirectories {
            try walkDirectory(cluster: child.cluster, contiguous: false, path: child.path,
                              depth: depth + 1, visited: &visited, collector: &collector,
                              volumeLabel: &volumeLabel)
        }
    }

    /// Read one file's entry set, returning how many bytes of the directory it used.
    ///
    /// The set is `SecondaryCount + 1` entries: the file entry, a stream extension, and
    /// enough name entries for the name. Anything short of that is a truncated set and
    /// the whole file is skipped — half a set describes a file whose size or location is
    /// missing, and guessing either would be inventing contents.
    private func readFileSet(_ bytes: [UInt8], at offset: Int, path: String,
                             collector: inout EntryCollector,
                             subdirectories: inout [(cluster: UInt32, path: String)]) throws -> Int {
        let secondaryCount = Int(bytes[offset + 1])
        let total = (secondaryCount + 1) * 32
        guard secondaryCount >= 2, offset + total <= bytes.count else { return 32 }

        let attributes = UInt16(bytes[offset + 4]) | UInt16(bytes[offset + 5]) << 8
        let mtime = Self.timestamp(Self.u32(bytes, offset + 12))

        // The stream extension always immediately follows the file entry.
        let stream = offset + 32
        guard bytes[stream] == 0xC0 else { return total }
        let flags = bytes[stream + 1]
        let nameLength = Int(bytes[stream + 3])
        let firstCluster = Self.u32(bytes, stream + 20)
        let size = Int64(bitPattern: Self.u64(bytes, stream + 24))
        let contiguous = flags & 0x02 != 0
        guard size >= 0, size <= ImageLimits.maxEntrySize else {
            throw ImageError.limitExceeded(limit: "maxEntrySize (\(ImageLimits.maxEntrySize))")
        }

        // Name entries follow, 15 UTF-16 units each.
        var units: [UInt16] = []
        var entry = stream + 32
        while entry + 32 <= offset + total, bytes[entry] == 0xC1, units.count < nameLength {
            for index in 0..<15 where units.count < nameLength {
                units.append(UInt16(bytes[entry + 2 + index * 2])
                             | UInt16(bytes[entry + 3 + index * 2]) << 8)
            }
            entry += 32
        }
        let name = String(decoding: units, as: UTF16.self)
        guard let childPath = EntryPath.make(parent: path, component: name) else {
            collector.dropName()
            return total
        }

        if attributes & 0x10 != 0 {
            try collector.add(ImageEntry(path: childPath, size: -1, mtime: mtime,
                                         kind: .directory, mode: 0o040755,
                                         locator: UInt64(firstCluster)))
            subdirectories.append((firstCluster, childPath))
        } else {
            let index = collector.entries.count
            try collector.add(ImageEntry(path: childPath, size: size, mtime: mtime,
                                         kind: .file, mode: 0o100644, locator: UInt64(firstCluster)))
            fileData[index] = (firstCluster, size, contiguous)
        }
        return total
    }

    private static func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
    }
    private static func u64(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
        UInt64(u32(bytes, offset)) | UInt64(u32(bytes, offset + 4)) << 32
    }
    private static func utf16(_ bytes: [UInt8], _ offset: Int, units: Int) -> String {
        var scalars: [UInt16] = []
        for index in 0..<units where offset + index * 2 + 1 < bytes.count {
            scalars.append(UInt16(bytes[offset + index * 2]) | UInt16(bytes[offset + index * 2 + 1]) << 8)
        }
        return String(decoding: scalars, as: UTF16.self)
    }

    /// exFAT reuses FAT's packed date and time. It also records a UTC offset per
    /// timestamp, which is deliberately ignored: reading it would shift every stamp by a
    /// zone the image's writer chose, and the panel shows local time anyway.
    private static func timestamp(_ packed: UInt32) -> Int64 {
        guard packed != 0 else { return 0 }
        var components = DateComponents()
        components.second = Int(packed & 0x1F) * 2
        components.minute = Int((packed >> 5) & 0x3F)
        components.hour = Int((packed >> 11) & 0x1F)
        components.day = Int((packed >> 16) & 0x1F)
        components.month = Int((packed >> 21) & 0x0F)
        components.year = 1980 + Int((packed >> 25) & 0x7F)
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
        for cluster in try clusters(from: file.cluster, count: file.size, contiguous: file.contiguous) {
            guard remaining > 0 else { break }
            let take = min(remaining, bytesPerCluster)
            try reader.copy(at: clusterOffset(cluster), count: take, to: handle)
            remaining -= take
        }
        guard remaining == 0 else {
            throw ImageError.damaged(
                reason: "\(entries[index].path): the allocation ends \(remaining) bytes early")
        }
    }
}
