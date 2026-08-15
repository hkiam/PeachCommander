// SPDX-License-Identifier: Apache-2.0
// SquashFSMetadata.swift — the compressed metadata stream SquashFS keeps its structures in.
//
// SquashFS does not store inodes, directories, fragment descriptors or id tables as
// plain arrays. It stores them as a *stream* cut into 8 KB blocks, each compressed
// independently and prefixed with a 16-bit length. A structure may begin near the
// end of one block and finish in the next, so nothing can be read by seeking to an
// offset and casting — every read has to walk the stream, decompressing blocks as it
// crosses them.
//
// That is what `MetadataCursor` is for. Blocks are cached by their absolute file
// offset, because the same block is crossed repeatedly: every inode in a directory
// lands in a handful of blocks, and re-decompressing them per lookup would make
// parsing a large image quadratic in decompression work.

import Foundation

/// A decompressed metadata block plus where the next one starts.
private struct MetadataBlock {
    let bytes: [UInt8]
    /// Absolute file offset of the block that follows this one.
    let nextOffset: Int64
}

/// Sequential reader over the SquashFS metadata stream, positioned at a
/// (block offset, offset within block) pair — which is exactly how the format's own
/// references are expressed.
final class MetadataCursor {
    private let reader: ByteSource
    private let codec: Codec
    /// Decompressed blocks, keyed by their absolute offset in the image.
    private var cache: [Int64: MetadataBlock] = [:]

    /// Absolute offset of the block currently being read from.
    private(set) var blockOffset: Int64
    /// Read position inside that block's decompressed bytes.
    private(set) var offsetInBlock: Int

    init(reader: ByteSource, codec: Codec, blockOffset: Int64, offsetInBlock: Int = 0) {
        self.reader = reader
        self.codec = codec
        self.blockOffset = blockOffset
        self.offsetInBlock = offsetInBlock
    }

    /// A second cursor over the same image, sharing nothing. Used to read a
    /// directory listing while an inode walk is positioned elsewhere.
    func branched(blockOffset: Int64, offsetInBlock: Int) -> MetadataCursor {
        let cursor = MetadataCursor(reader: reader, codec: codec,
                                    blockOffset: blockOffset, offsetInBlock: offsetInBlock)
        cursor.cache = cache   // value semantics: a copy, so the branch cannot corrupt this one
        return cursor
    }

    /// Read `count` bytes, following the stream across block boundaries.
    func read(_ count: Int) throws -> [UInt8] {
        guard count >= 0 else { throw ImageError.damaged(reason: "negative metadata read") }
        guard count <= ImageLimits.maxBlockSize else {
            throw ImageError.limitExceeded(limit: "maxBlockSize (\(ImageLimits.maxBlockSize))")
        }
        var out: [UInt8] = []
        out.reserveCapacity(count)
        while out.count < count {
            let block = try block(at: blockOffset)
            guard offsetInBlock <= block.bytes.count else {
                throw ImageError.damaged(reason: "metadata offset \(offsetInBlock) past block end")
            }
            let available = block.bytes.count - offsetInBlock
            if available == 0 {
                // Exactly at the end: step to the next block. A block that decompresses
                // to nothing would leave this looping without progress, so it is refused.
                guard block.nextOffset > blockOffset else {
                    throw ImageError.damaged(reason: "metadata block at \(blockOffset) makes no progress")
                }
                blockOffset = block.nextOffset
                offsetInBlock = 0
                continue
            }
            let take = min(available, count - out.count)
            out.append(contentsOf: block.bytes[offsetInBlock..<(offsetInBlock + take)])
            offsetInBlock += take
        }
        return out
    }

    func u16() throws -> UInt16 {
        let raw = try read(2)
        return UInt16(raw[0]) | UInt16(raw[1]) << 8
    }

    func u32() throws -> UInt32 {
        let raw = try read(4)
        return UInt32(raw[0]) | UInt32(raw[1]) << 8 | UInt32(raw[2]) << 16 | UInt32(raw[3]) << 24
    }

    func u64() throws -> UInt64 {
        let low = UInt64(try u32()), high = UInt64(try u32())
        return low | high << 32
    }

    func i16() throws -> Int16 { Int16(bitPattern: try u16()) }

    /// Skip forward without materialising the bytes.
    func skip(_ count: Int) throws { _ = try read(count) }

    /// Decompress the metadata block at `offset`, caching it.
    ///
    /// The 16-bit prefix carries the on-disk length in its low 15 bits; bit 15 means
    /// the block was stored uncompressed because compressing it did not pay. A block
    /// decompresses to at most 8192 bytes — that is a format constant, not a guess,
    /// so a block claiming more is refused rather than trusted.
    private func block(at offset: Int64) throws -> MetadataBlock {
        if let cached = cache[offset] { return cached }
        guard cache.count < Self.maxCachedBlocks else {
            // Bounded rather than unbounded: an image with a huge metadata stream
            // would otherwise pin all of it in memory at once. Dropping the whole
            // cache is crude but correct, and the access pattern refills it quickly.
            cache.removeAll(keepingCapacity: true)
            return try block(at: offset)
        }
        let header = try reader.bytes(at: offset, count: 2)
        let raw = UInt16(header[0]) | UInt16(header[1]) << 8
        let isUncompressed = raw & 0x8000 != 0
        let onDiskSize = Int(raw & 0x7FFF)
        guard onDiskSize > 0 else {
            throw ImageError.damaged(reason: "zero-length metadata block at \(offset)")
        }
        let payload = try reader.bytes(at: offset + 2, count: onDiskSize)
        let bytes: [UInt8]
        if isUncompressed {
            guard onDiskSize <= Self.blockSize else {
                throw ImageError.damaged(reason: "uncompressed metadata block at \(offset) is \(onDiskSize) bytes")
            }
            bytes = payload
        } else {
            bytes = try Decompressor.decompressVariable(payload, codec: codec, maxSize: Self.blockSize)
        }
        let block = MetadataBlock(bytes: bytes, nextOffset: offset + 2 + Int64(onDiskSize))
        cache[offset] = block
        return block
    }

    /// A metadata block decompresses to at most this — fixed by the format.
    static let blockSize = 8192
    /// 4096 blocks ≈ 32 MB of decompressed metadata held at once.
    private static let maxCachedBlocks = 4096
}

/// A SquashFS inode reference: which metadata block, and where inside it.
///
/// Packed into one 64-bit value as `(blockOffset << 16) | offsetInBlock`, where the
/// block offset is relative to the start of the table it belongs to.
struct InodeRef {
    let blockOffset: Int64
    let offsetInBlock: Int

    init(_ raw: UInt64) {
        self.blockOffset = Int64((raw >> 16) & 0xFFFF_FFFF_FFFF)
        self.offsetInBlock = Int(raw & 0xFFFF)
    }
}
