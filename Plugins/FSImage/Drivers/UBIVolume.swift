// SPDX-License-Identifier: Apache-2.0
// UBIVolume.swift — presenting a volume inside a UBI image as one contiguous run of bytes.
//
// UBIFS does not sit on flash directly. It sits on UBI, a layer that hands out *logical*
// erase blocks and quietly moves them between physical ones for wear levelling. So the
// file a vendor ships is usually a `.ubi` container, and the blocks inside it are in
// whatever order the writer happened to use — LEB 7 can be the second physical block
// and LEB 0 the ninetieth.
//
// Each physical block carries two 64-bit-aligned headers, both big-endian: an erase
// counter header at offset 0 saying where the other two regions begin, and a volume
// identifier header saying which volume and which logical block this physical one holds.
// Reading them in order builds the map, and this type then presents the chosen volume as
// if its blocks had been written in sequence — which is exactly what the bare `.ubifs`
// image is, so the same driver reads both.
//
// Blocks with no valid volume header are free or bad and are skipped; that is normal in
// a real dump rather than a sign of damage.

import Foundation

/// A single volume inside a UBI image, addressed as a flat sequence of LEBs.
final class UBIVolumeSource: ByteSource {
    private let reader: ImageReader
    /// Physical byte offset of each logical erase block's *data* region, by LEB number.
    private let blockOffset: [Int64]
    let logicalEraseBlockSize: Int64

    var count: Int64 { Int64(blockOffset.count) * logicalEraseBlockSize }

    /// "UBI#" and "UBI!", stored big-endian.
    private static let ecMagic: UInt32 = 0x5542_4923
    private static let vidMagic: UInt32 = 0x5542_4921

    static func isPresent(in reader: ImageReader) -> Bool {
        (try? reader.u32be(at: 0)) == ecMagic
    }

    /// Build the map for the volume `preferring`, or for the lowest volume id present.
    init(reader: ImageReader, preferring volumeID: UInt32? = nil) throws {
        self.reader = reader
        guard try reader.u32be(at: 0) == Self.ecMagic else { throw ImageError.notThisFormat }

        // The physical block size is not recorded anywhere; it is the distance between
        // consecutive erase-counter headers. Measuring it is the only way in, so the
        // scan looks for the next header at each plausible power-of-two stride rather
        // than assuming one.
        let vidHeaderOffset = Int64(try reader.u32be(at: 16))
        let dataOffset = Int64(try reader.u32be(at: 20))
        guard vidHeaderOffset >= 64, dataOffset > vidHeaderOffset, dataOffset < 1 << 20 else {
            throw ImageError.damaged(reason: "UBI header offsets are implausible")
        }
        let candidates: [Int64] = [16_384, 32_768, 65_536, 131_072, 262_144, 524_288, 1_048_576]
        var physicalBlockSize: Int64 = 0
        for candidate in candidates where candidate > dataOffset {
            if (try? reader.u32be(at: candidate)) == Self.ecMagic {
                physicalBlockSize = candidate
                break
            }
        }
        if physicalBlockSize == 0 {
            // A one-block image is legal and leaves nothing to measure against.
            physicalBlockSize = reader.size
        }
        guard physicalBlockSize > dataOffset else {
            throw ImageError.damaged(reason: "cannot determine the UBI physical block size")
        }
        self.logicalEraseBlockSize = physicalBlockSize - dataOffset

        // Walk every physical block and record where each logical one landed.
        var byVolume: [UInt32: [UInt32: Int64]] = [:]
        var physical: Int64 = 0
        while physical + dataOffset <= reader.size {
            defer { physical += physicalBlockSize }
            guard (try? reader.u32be(at: physical)) == Self.ecMagic else { continue }
            guard (try? reader.u32be(at: physical + vidHeaderOffset)) == Self.vidMagic else {
                continue   // erased or bad block: no volume claims it
            }
            let volume = try reader.u32be(at: physical + vidHeaderOffset + 8)
            let logical = try reader.u32be(at: physical + vidHeaderOffset + 12)
            guard logical < 1 << 20 else {
                throw ImageError.damaged(reason: "UBI block claims logical number \(logical)")
            }
            byVolume[volume, default: [:]][logical] = physical + dataOffset
        }

        let chosen: UInt32
        if let volumeID, byVolume[volumeID] != nil {
            chosen = volumeID
        } else if let lowest = byVolume.keys.min() {
            chosen = lowest
        } else {
            throw ImageError.damaged(reason: "the UBI image holds no volumes")
        }
        // The layout volume (id 0x7FFFEFFF) holds UBI's own volume table, not a
        // filesystem, and is never what someone opened the file to see.
        guard chosen != 0x7FFF_EFFF else {
            throw ImageError.unsupported(reason: "this UBI image holds only its layout volume")
        }
        guard let blocks = byVolume[chosen], let highest = blocks.keys.max() else {
            throw ImageError.damaged(reason: "UBI volume \(chosen) has no blocks")
        }

        // Gaps are filled with -1: a volume may legitimately have unwritten blocks, and
        // reading one has to fail rather than silently return a neighbour's contents.
        var offsets = [Int64](repeating: -1, count: Int(highest) + 1)
        for (logical, offset) in blocks { offsets[Int(logical)] = offset }
        self.blockOffset = offsets
    }

    // MARK: - ByteSource

    func contains(offset: Int64, count: Int) -> Bool {
        guard offset >= 0, count >= 0 else { return false }
        return Int64(count) <= self.count - offset
    }

    func bytes(at offset: Int64, count: Int) throws -> [UInt8] {
        guard contains(offset: offset, count: count) else {
            throw ImageError.outOfBounds(offset: offset, count: count)
        }
        var out = [UInt8]()
        out.reserveCapacity(count)
        var cursor = offset
        var remaining = count
        while remaining > 0 {
            let block = Int(cursor / logicalEraseBlockSize)
            let within = cursor % logicalEraseBlockSize
            let take = Int(min(Int64(remaining), logicalEraseBlockSize - within))
            guard block < blockOffset.count, blockOffset[block] >= 0 else {
                throw ImageError.damaged(reason: "UBI logical block \(block) was never written")
            }
            out.append(contentsOf: try reader.bytes(at: blockOffset[block] + within, count: take))
            cursor += Int64(take)
            remaining -= take
        }
        return out
    }

    func copy(at offset: Int64, count: Int64, to handle: FileHandle) throws {
        var remaining = count
        var cursor = offset
        while remaining > 0 {
            let chunk = Int(min(remaining, Int64(ImageLimits.copyChunkSize)))
            try handle.write(contentsOf: bytes(at: cursor, count: chunk))
            remaining -= Int64(chunk)
            cursor += Int64(chunk)
        }
    }
}
