// SPDX-License-Identifier: Apache-2.0
// PartitionTable.swift — MBR and GPT, so an image can hold more than one filesystem.
//
// Every driver here assumes the image *is* the filesystem, starting at byte 0. For a
// SquashFS rootfs or a JFFS2 flash dump that is right. For most other images it is not:
// a disk image straight off a device has a partition table, and the filesystem someone
// wants is a slice inside it. Without this, opening such an image finds nothing at
// offset 0 and the plugin declines a file it could read perfectly well one partition in.
//
// Two schemes, and a real disk carries both. GPT always writes a "protective MBR" in
// sector 0 claiming one partition of type 0xEE across the whole disk, precisely so that
// an MBR-only tool sees a full disk rather than free space and declines to help. So MBR
// is parsed *after* checking for GPT, never before — reading the protective entry as a
// real partition is the classic way to report one giant unreadable partition where four
// good ones exist.

import Foundation

/// One partition found in an image.
struct Partition {
    /// 1-based, in table order — what `fdisk` and every other tool calls it.
    let number: Int
    let offset: Int64
    let length: Int64
    /// A short name for the partition type, for the listing. Best-effort: the point is
    /// to tell an EFI system partition from a Linux root at a glance, not to be a
    /// complete type registry.
    let typeName: String
    /// GPT partition name, when the table records one.
    let label: String?

    /// What the entry is called in the panel: `1-EFI`, `2-Linux`, `3-Windows-Data`.
    var directoryName: String {
        let base = label?.isEmpty == false ? label! : typeName
        let cleaned = base.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return "\(number)-\(String(cleaned))"
    }
}

enum PartitionTable {
    /// Sector size assumed when reading a table. 512 is what both schemes use for their
    /// own structures on every image this will meet; 4Kn disks exist but their images
    /// are not what a firmware browser is handed.
    static let sectorSize: Int64 = 512

    /// Read whichever table the image carries, or nil if it carries none.
    ///
    /// Nil is the ordinary answer, not a failure: most images here really are a bare
    /// filesystem, and saying "no table" lets the caller go on to probe the drivers.
    static func read(_ reader: ImageReader) throws -> [Partition]? {
        if let gpt = try readGPT(reader) { return gpt }
        return try readMBR(reader)
    }

    // MARK: - GPT

    private static let gptSignature = Array("EFI PART".utf8)

    private static func readGPT(_ reader: ImageReader) throws -> [Partition]? {
        // The primary header is in LBA 1, immediately after the protective MBR.
        guard reader.contains(offset: sectorSize, count: 92),
              try reader.bytes(at: sectorSize, count: 8) == gptSignature else { return nil }

        let entryLBA = Int64(bitPattern: try reader.u64le(at: sectorSize + 72))
        let entryCount = Int(try reader.u32le(at: sectorSize + 80))
        let entrySize = Int(try reader.u32le(at: sectorSize + 84))
        guard entryCount > 0, entryCount <= 4096, entrySize >= 128, entrySize <= 4096 else {
            throw ImageError.damaged(reason: "GPT header claims \(entryCount) entries of \(entrySize) bytes")
        }

        var partitions: [Partition] = []
        for index in 0..<entryCount {
            let entry = entryLBA * sectorSize + Int64(index * entrySize)
            guard reader.contains(offset: entry, count: entrySize) else { break }
            let typeGUID = try reader.bytes(at: entry, count: 16)
            // An all-zero type GUID means the slot is unused. GPT tables are usually
            // 128 entries with four in use, so this is the normal case, not an error.
            guard typeGUID.contains(where: { $0 != 0 }) else { continue }

            let firstLBA = Int64(bitPattern: try reader.u64le(at: entry + 32))
            let lastLBA = Int64(bitPattern: try reader.u64le(at: entry + 40))
            guard lastLBA >= firstLBA, firstLBA >= 0 else { continue }
            // UTF-16LE, 36 code units, NUL-padded.
            let nameBytes = try reader.bytes(at: entry + 56, count: min(72, entrySize - 56))
            var scalars = [UInt16]()
            for pair in stride(from: 0, to: nameBytes.count - 1, by: 2) {
                let unit = UInt16(nameBytes[pair]) | UInt16(nameBytes[pair + 1]) << 8
                if unit == 0 { break }
                scalars.append(unit)
            }
            partitions.append(Partition(number: partitions.count + 1,
                                        offset: firstLBA * sectorSize,
                                        length: (lastLBA - firstLBA + 1) * sectorSize,
                                        typeName: gptTypeName(typeGUID),
                                        label: String(decoding: scalars, as: UTF16.self)))
        }
        return partitions.isEmpty ? nil : partitions
    }

    /// Names for the few type GUIDs worth recognising on sight — enough to tell an EFI
    /// system partition from a Linux root in the listing, not a complete registry.
    ///
    /// Matched on the leading four bytes. A GUID's first three fields are stored
    /// little-endian while the rest is big-endian, so the printed form and the on-disk
    /// form disagree; the first field alone separates these unambiguously and avoids
    /// having to get that byte-swap right for a cosmetic label.
    private static func gptTypeName(_ guid: [UInt8]) -> String {
        let hex = guid.prefix(4).map { String(format: "%02x", $0) }.joined()
        if hex.hasPrefix("28732ac1") { return "EFI" }
        if hex.hasPrefix("af3dc60f") { return "Linux" }
        if hex.hasPrefix("a2a0d0eb") { return "Windows-Data" }
        if hex.hasPrefix("0fc63daf") { return "Linux" }
        if hex.hasPrefix("0657fd6d") { return "Linux-swap" }
        if hex.hasPrefix("48465300") { return "HFS" }
        if hex.hasPrefix("7c3457ef") { return "APFS" }
        return "partition"
    }

    // MARK: - MBR

    private static func readMBR(_ reader: ImageReader) throws -> [Partition]? {
        guard reader.contains(offset: 0, count: 512) else { return nil }
        let sector = try reader.bytes(at: 0, count: 512)
        guard sector[510] == 0x55, sector[511] == 0xAA else { return nil }

        var partitions: [Partition] = []
        var extendedStart: Int64 = 0
        for slot in 0..<4 {
            let entry = 446 + slot * 16
            let type = sector[entry + 4]
            guard type != 0 else { continue }
            // 0xEE is GPT's protective entry. Reaching it means the GPT header was
            // unreadable, so reporting one disk-sized partition would be a lie about a
            // table we failed to parse.
            guard type != 0xEE else { continue }
            let firstLBA = Int64(u32(sector, entry + 8))
            let sectors = Int64(u32(sector, entry + 12))
            guard firstLBA > 0, sectors > 0 else { continue }

            if type == 0x05 || type == 0x0F || type == 0x85 {
                extendedStart = firstLBA * sectorSize
                continue    // a container, not a filesystem — walked below
            }
            partitions.append(Partition(number: partitions.count + 1,
                                        offset: firstLBA * sectorSize,
                                        length: sectors * sectorSize,
                                        typeName: mbrTypeName(type), label: nil))
        }

        if extendedStart > 0 {
            try readLogicalPartitions(reader, extendedStart: extendedStart, into: &partitions)
        }
        return partitions.isEmpty ? nil : partitions
    }

    /// Logical partitions live in a singly-linked list of extended boot records, each
    /// holding one partition and a pointer to the next. Bounded so a record pointing at
    /// itself — which a damaged table does — cannot loop forever.
    private static func readLogicalPartitions(_ reader: ImageReader, extendedStart: Int64,
                                              into partitions: inout [Partition]) throws {
        var current = extendedStart
        var visited = Set<Int64>()
        while visited.insert(current).inserted, visited.count <= 64 {
            guard reader.contains(offset: current, count: 512) else { return }
            let sector = try reader.bytes(at: current, count: 512)
            guard sector[510] == 0x55, sector[511] == 0xAA else { return }

            let type = sector[446 + 4]
            let firstLBA = Int64(u32(sector, 446 + 8))
            let sectors = Int64(u32(sector, 446 + 12))
            if type != 0, firstLBA > 0, sectors > 0 {
                partitions.append(Partition(number: partitions.count + 1,
                                            offset: current + firstLBA * sectorSize,
                                            length: sectors * sectorSize,
                                            typeName: mbrTypeName(type), label: nil))
            }
            // The second entry's start is relative to the *first* extended record, not
            // to this one — the one detail that makes extended partitions error-prone.
            let nextLBA = Int64(u32(sector, 462 + 8))
            guard sector[462 + 4] != 0, nextLBA > 0 else { return }
            current = extendedStart + nextLBA * sectorSize
        }
    }

    private static func mbrTypeName(_ type: UInt8) -> String {
        switch type {
        case 0x01, 0x04, 0x06, 0x0E: return "FAT16"
        case 0x0B, 0x0C: return "FAT32"
        case 0x07: return "NTFS-exFAT"
        case 0x83: return "Linux"
        case 0x82: return "Linux-swap"
        case 0xEF: return "EFI"
        case 0xAF: return "HFS"
        default: return String(format: "type-%02X", type)
        }
    }

    private static func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
    }
}
