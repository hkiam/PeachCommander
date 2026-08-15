// SPDX-License-Identifier: Apache-2.0
// ExtLayout.swift — where an ext2/3/4 file's bytes are, given its inode.
//
// The ext family answers "which disk block holds logical block N" in two entirely
// different ways, and an image can contain both at once: a filesystem upgraded from
// ext3 keeps old files on the classic block map while new ones get extent trees.
//
//   Classic block map (ext2/ext3, and ext4 files without EXTENTS_FL)
//     The inode's 15 block pointers: 12 direct, then one singly-, one doubly- and
//     one triply-indirect block. Reaching block 100,000 means three dependent reads
//     before the data read.
//
//   Extent tree (ext4)
//     A B-tree in the inode's same 60 bytes, mapping runs of contiguous logical
//     blocks to runs of physical ones. Far better for large files, and the reason
//     ext4 exists.
//
// Both produce the same thing here: a list of runs. Resolving to runs rather than
// to individual block numbers is what keeps extraction of a large contiguous file
// a handful of reads instead of one per 4 KB.

import Foundation

/// A contiguous run of file content. `physicalBlock == nil` is a hole — a sparse
/// region that occupies no blocks and reads as zeros.
struct ExtRun {
    let logicalBlock: Int64
    let physicalBlock: Int64?
    let blockCount: Int64
}

/// Resolves an inode's block pointers into runs.
struct ExtLayoutResolver {
    let reader: ImageReader
    let blockSize: Int64
    /// Total blocks in the filesystem, used to reject a pointer outside it before it
    /// becomes a read at an arbitrary offset.
    let totalBlocks: Int64

    private func checkBlock(_ block: Int64, what: String) throws {
        guard block >= 0, block < totalBlocks else {
            throw ImageError.damaged(reason: "\(what) points at block \(block) of \(totalBlocks)")
        }
    }

    // MARK: - Extent tree

    private static let extentMagic: UInt16 = 0xF30A

    /// Walk the extent tree rooted in `inlineRoot` (the inode's 60 i_block bytes).
    func extentRuns(inlineRoot: [UInt8]) throws -> [ExtRun] {
        var runs: [ExtRun] = []
        try walkExtentNode(inlineRoot, depthBudget: ImageLimits.maxDepth, into: &runs)
        runs.sort { $0.logicalBlock < $1.logicalBlock }
        return runs
    }

    /// One extent node: a 12-byte header then 12-byte entries, which are leaf
    /// extents at depth 0 and indices into child nodes above it.
    ///
    /// `depthBudget` is decremented per level rather than trusting `eh_depth`: a
    /// damaged image can point a child back at its own parent, and the header's own
    /// depth field is exactly the thing that would be lying in that case.
    private func walkExtentNode(_ node: [UInt8], depthBudget: Int, into runs: inout [ExtRun]) throws {
        guard depthBudget > 0 else {
            throw ImageError.limitExceeded(limit: "extent tree depth (\(ImageLimits.maxDepth))")
        }
        guard node.count >= 12 else { throw ImageError.damaged(reason: "truncated extent node") }
        let magic = UInt16(node[0]) | UInt16(node[1]) << 8
        guard magic == Self.extentMagic else {
            throw ImageError.damaged(reason: "extent node magic is \(String(magic, radix: 16)), not f30a")
        }
        let entries = Int(UInt16(node[2]) | UInt16(node[3]) << 8)
        let maxEntries = Int(UInt16(node[4]) | UInt16(node[5]) << 8)
        let depth = Int(UInt16(node[6]) | UInt16(node[7]) << 8)
        guard entries <= maxEntries, 12 + entries * 12 <= node.count else {
            throw ImageError.damaged(reason: "extent node claims \(entries) entries it does not have")
        }

        for index in 0..<entries {
            let base = 12 + index * 12
            let field = { (offset: Int, width: Int) -> UInt64 in
                var value: UInt64 = 0
                for byte in stride(from: width - 1, through: 0, by: -1) {
                    value = value << 8 | UInt64(node[base + offset + byte])
                }
                return value
            }
            if depth == 0 {
                let logical = Int64(field(0, 4))
                let rawLength = Int(field(4, 2))
                let physical = Int64(field(8, 4)) | Int64(field(6, 2)) << 32
                // A length above 32768 marks an uninitialised (preallocated) extent;
                // its real length is the excess. Those blocks read as zeros — they
                // were reserved and never written, and handing back whatever the disk
                // happens to hold there would leak unrelated data into a file.
                let isUninitialised = rawLength > 32768
                let length = Int64(isUninitialised ? rawLength - 32768 : rawLength)
                guard length > 0 else { continue }
                try checkBlock(physical, what: "extent")
                try checkBlock(physical + length - 1, what: "extent end")
                runs.append(ExtRun(logicalBlock: logical,
                                   physicalBlock: isUninitialised ? nil : physical,
                                   blockCount: length))
            } else {
                let child = Int64(field(4, 4)) | Int64(field(8, 2)) << 32
                try checkBlock(child, what: "extent index")
                let childBytes = try reader.bytes(at: child * blockSize, count: Int(blockSize))
                try walkExtentNode(childBytes, depthBudget: depthBudget - 1, into: &runs)
            }
        }
    }

    // MARK: - Classic block map

    /// Resolve the 15 legacy block pointers into runs covering `blockCount` blocks.
    ///
    /// Every pointer is read, including the indirect levels, so a file whose map is
    /// damaged fails here rather than producing a file full of whatever those block
    /// numbers happened to address.
    func blockMapRuns(pointers: [UInt32], blockCount: Int64) throws -> [ExtRun] {
        guard pointers.count >= 15 else {
            throw ImageError.damaged(reason: "inode has \(pointers.count) block pointers, expected 15")
        }
        let perBlock = blockSize / 4
        var blocks: [Int64] = []
        blocks.reserveCapacity(Int(min(blockCount, 1 << 20)))

        for index in 0..<12 where Int64(blocks.count) < blockCount {
            blocks.append(Int64(pointers[index]))
        }

        // The three indirect levels, each covering perBlock^level logical blocks.
        //
        // A pointer of 0 means that whole level is a hole — and it must still consume
        // its span, not be skipped. Skipping it was a real defect: a sparse file whose
        // singly-indirect level is entirely a hole but whose doubly-indirect level
        // holds the tail had that tail appended at logical block 12 instead of 268,
        // so the file came out the right length with its content in the wrong place.
        // The same mistake as ignoring an extent's logical block, one level down.
        var span = perBlock
        for level in 1...3 {
            guard Int64(blocks.count) < blockCount else { break }
            let pointer = Int64(pointers[11 + level])
            if pointer == 0 {
                let room = blockCount - Int64(blocks.count)
                blocks.append(contentsOf: repeatElement(0, count: Int(min(span, room))))
            } else {
                try appendIndirect(pointer, level: level, limit: blockCount, into: &blocks)
            }
            span *= perBlock
        }

        // Collapse the flat block list into runs, so a contiguous file becomes one
        // read rather than thousands. A pointer of 0 is a hole, which is how sparse
        // files are stored in the classic map.
        var runs: [ExtRun] = []
        var index = 0
        while index < blocks.count, Int64(index) < blockCount {
            let start = blocks[index]
            var length: Int64 = 1
            while Int64(index) + length < min(Int64(blocks.count), blockCount),
                  blocks[index + Int(length)] == (start == 0 ? 0 : start + length) {
                length += 1
            }
            runs.append(ExtRun(logicalBlock: Int64(index),
                               physicalBlock: start == 0 ? nil : start,
                               blockCount: length))
            index += Int(length)
        }
        return runs
    }

    private func appendIndirect(_ block: Int64, level: Int, limit: Int64,
                                into blocks: inout [Int64]) throws {
        guard level > 0 else { return }
        try checkBlock(block, what: "indirect block")
        let raw = try reader.bytes(at: block * blockSize, count: Int(blockSize))
        let count = Int(blockSize / 4)
        for index in 0..<count {
            guard Int64(blocks.count) < limit else { return }
            let base = index * 4
            let pointer = Int64(UInt32(raw[base]) | UInt32(raw[base + 1]) << 8
                                | UInt32(raw[base + 2]) << 16 | UInt32(raw[base + 3]) << 24)
            if level == 1 {
                blocks.append(pointer)
            } else if pointer != 0 {
                try appendIndirect(pointer, level: level - 1, limit: limit, into: &blocks)
            } else {
                // A hole at an indirect level covers everything below it. Filling the
                // gap keeps logical block numbers aligned with file offsets; skipping
                // it would shift the rest of the file earlier by that much.
                let span = Int(pow(Double(blockSize / 4), Double(level - 1)))
                let room = Int(limit) - blocks.count
                blocks.append(contentsOf: repeatElement(0, count: min(span, max(room, 0))))
            }
        }
    }
}
