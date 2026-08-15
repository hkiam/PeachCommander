// SPDX-License-Identifier: Apache-2.0
// BtrfsChunkMap.swift — the Btrfs superblock, and turning logical addresses into offsets.
//
// Btrfs is the only format here where an address in a structure is not an offset in
// the file. Everything — tree roots, extents, the chunk tree itself — is addressed in
// a *logical* space, and a separate mapping says which device and which physical
// offset each logical range lives at. That indirection is what lets btrfs span
// devices and change RAID profile while mounted; the cost is that nothing at all can
// be read until the mapping is built.
//
// And the mapping lives in the chunk tree, which is itself at a logical address. The
// format resolves that chicken-and-egg with `sys_chunk_array`, a copy of just enough
// chunk records, embedded in the superblock, to reach the chunk tree. So bootstrapping
// is: read the superblock, parse the embedded array, use it to read the chunk tree,
// and replace the bootstrap map with the full one.

import Foundation

/// One logical→physical mapping, as recorded by a CHUNK_ITEM.
struct BtrfsChunk {
    let logicalStart: Int64
    let length: Int64
    /// Physical offset of the first stripe. Single-device only — see `profileIsReadable`.
    let physicalStart: Int64
    let type: UInt64
    let stripeCount: Int

    var logicalEnd: Int64 { logicalStart + length }

    /// Block-group profile bits. Anything that spreads one logical range across
    /// several stripes needs striping arithmetic this driver does not do.
    private enum Profile {
        static let raid0: UInt64 = 8
        static let raid10: UInt64 = 64
        static let raid5: UInt64 = 128
        static let raid6: UInt64 = 256
    }

    /// Whether stripe 0 alone holds the data.
    ///
    /// True for SINGLE, DUP, RAID1 and RAID1C3/C4 — all of which store complete
    /// copies, so the first one answers every read. False for RAID0/10/5/6, where a
    /// logical range is *split* across stripes and reading only the first returns
    /// every other chunk of the file as whatever happened to be at that offset.
    /// Silently wrong data is the reason this is a refusal rather than a best effort.
    var profileIsReadable: Bool {
        type & (Profile.raid0 | Profile.raid10 | Profile.raid5 | Profile.raid6) == 0
    }

    var profileName: String {
        if type & Profile.raid0 != 0 { return "RAID0" }
        if type & Profile.raid10 != 0 { return "RAID10" }
        if type & Profile.raid5 != 0 { return "RAID5" }
        if type & Profile.raid6 != 0 { return "RAID6" }
        return "single"
    }
}

/// The fields of the Btrfs superblock this driver needs.
struct BtrfsSuperblock {
    /// The primary superblock sits 64 KB in, past whatever bootloader is at the front.
    static let offset: Int64 = 65536
    /// "_BHRfS_M", at offset 64 in the superblock.
    static let magic: [UInt8] = Array("_BHRfS_M".utf8)

    let nodeSize: Int64
    let sectorSize: Int64
    let totalBytes: Int64
    let rootTreeLogical: Int64
    let chunkTreeLogical: Int64
    let deviceCount: UInt64
    let incompatFlags: UInt64
    let label: String

    /// Incompat bits that change how the image must be read.
    enum Incompat {
        static let mixedGroups: UInt64 = 0x0004
        static let compressLzo: UInt64 = 0x0008
        static let compressZstd: UInt64 = 0x0010
        static let raid56: UInt64 = 0x0080
        static let raid1c34: UInt64 = 0x0800
        static let zoned: UInt64 = 0x0200_0000
        static let extentTreeV2: UInt64 = 0x0400_0000
    }

    static func isPresent(in reader: ImageReader) -> Bool {
        guard let bytes = try? reader.bytes(at: offset + 64, count: 8) else { return false }
        return bytes == magic
    }

    init(reader: ImageReader) throws {
        let base = Self.offset
        guard try reader.bytes(at: base + 64, count: 8) == Self.magic else {
            throw ImageError.notThisFormat
        }
        totalBytes = Int64(bitPattern: try reader.u64le(at: base + 112))
        sectorSize = Int64(try reader.u32le(at: base + 144))
        nodeSize = Int64(try reader.u32le(at: base + 148))
        rootTreeLogical = Int64(bitPattern: try reader.u64le(at: base + 80))
        chunkTreeLogical = Int64(bitPattern: try reader.u64le(at: base + 88))
        deviceCount = try reader.u64le(at: base + 136)
        incompatFlags = try reader.u64le(at: base + 188)
        label = try reader.name(at: base + 299, maxLength: 256)

        guard nodeSize >= 4096, nodeSize <= 65536, nodeSize % sectorSize == 0 else {
            throw ImageError.damaged(reason: "implausible node size \(nodeSize)")
        }
        guard sectorSize >= 512, sectorSize <= 65536 else {
            throw ImageError.damaged(reason: "implausible sector size \(sectorSize)")
        }
        // A single-device filesystem is the only shape this driver can serve: with
        // more devices, most of the data is in a file that is not this one, and the
        // listing would be a tree whose contents cannot be read.
        guard deviceCount == 1 else {
            throw ImageError.unsupported(
                reason: "this filesystem spans \(deviceCount) devices; only single-device images can be read")
        }
        if incompatFlags & Incompat.zoned != 0 {
            throw ImageError.unsupported(reason: "zoned Btrfs filesystems are not supported")
        }
        if incompatFlags & Incompat.extentTreeV2 != 0 {
            throw ImageError.unsupported(reason: "extent-tree-v2 filesystems are not supported")
        }
    }
}

/// Logical→physical translation for a single-device image.
struct BtrfsChunkMap {
    private var chunks: [BtrfsChunk] = []

    /// The bootstrap map: the chunk records copied into the superblock, which is
    /// exactly enough to reach the chunk tree and no more.
    ///
    /// `sys_chunk_array` is a packed sequence of (key, chunk) pairs at offset 811,
    /// `sys_chunk_array_size` bytes long. The key's `offset` field is the logical
    /// start — the chunk record itself does not repeat it.
    init(bootstrapping reader: ImageReader) throws {
        let base = BtrfsSuperblock.offset
        let arraySize = Int(try reader.u32le(at: base + 160))
        guard arraySize > 0, arraySize <= 2048 else {
            throw ImageError.damaged(reason: "sys_chunk_array is \(arraySize) bytes")
        }
        let raw = try reader.bytes(at: base + 811, count: arraySize)

        var offset = 0
        while offset + 17 + 48 <= raw.count {
            let logicalStart = Int64(bitPattern: raw.u64(offset + 9))   // key.offset
            offset += 17
            let chunk = try Self.parseChunk(raw, at: offset, logicalStart: logicalStart)
            chunks.append(chunk)
            offset += 48 + chunk.stripeCount * 32
        }
        guard !chunks.isEmpty else {
            throw ImageError.damaged(reason: "the superblock carries no bootstrap chunks")
        }
    }

    /// Replace the bootstrap chunks with the full set from the chunk tree.
    mutating func replace(with chunks: [BtrfsChunk]) {
        self.chunks = chunks.sorted { $0.logicalStart < $1.logicalStart }
    }

    static func parseChunk(_ raw: [UInt8], at offset: Int, logicalStart: Int64) throws -> BtrfsChunk {
        guard offset + 48 <= raw.count else {
            throw ImageError.damaged(reason: "truncated chunk record")
        }
        let length = Int64(bitPattern: raw.u64(offset))
        let type = raw.u64(offset + 24)
        let stripeCount = Int(raw.u16(offset + 44))
        guard stripeCount > 0, stripeCount <= 64, offset + 48 + stripeCount * 32 <= raw.count else {
            throw ImageError.damaged(reason: "chunk claims \(stripeCount) stripes")
        }
        // Stripe layout: devid u64, physical offset u64, uuid[16].
        let physical = Int64(bitPattern: raw.u64(offset + 48 + 8))
        guard length > 0 else { throw ImageError.damaged(reason: "zero-length chunk") }
        return BtrfsChunk(logicalStart: logicalStart, length: length,
                          physicalStart: physical, type: type, stripeCount: stripeCount)
    }

    /// The file offset holding `logical`, or a failure naming why it cannot be reached.
    func physical(for logical: Int64) throws -> Int64 {
        guard let chunk = chunks.first(where: { logical >= $0.logicalStart && logical < $0.logicalEnd })
        else {
            throw ImageError.damaged(reason: "logical address \(logical) is in no chunk")
        }
        guard chunk.profileIsReadable else {
            throw ImageError.unsupported(
                reason: "the \(chunk.profileName) profile stripes data across devices, which is not supported")
        }
        return chunk.physicalStart + (logical - chunk.logicalStart)
    }
}

extension Array where Element == UInt8 {
    func u16(_ offset: Int) -> UInt16 {
        UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }
    func u32(_ offset: Int) -> UInt32 {
        UInt32(self[offset]) | UInt32(self[offset + 1]) << 8
            | UInt32(self[offset + 2]) << 16 | UInt32(self[offset + 3]) << 24
    }
    func u64(_ offset: Int) -> UInt64 {
        UInt64(u32(offset)) | UInt64(u32(offset + 4)) << 32
    }
}
