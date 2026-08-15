// SPDX-License-Identifier: Apache-2.0
// ExtDriver.swift — ext2, ext3 and ext4, read-only.
//
// One driver for all three because they are one filesystem with feature flags, not
// three formats: the superblock magic is identical and what separates them is which
// bits are set in the feature words. Splitting them would mean three copies of the
// same superblock parser disagreeing about edge cases.
//
// Read-only means **no journal replay**, and that has a visible consequence rather
// than being a quiet simplification. An image taken from a running system, or from
// a device that lost power, can carry a dirty journal: the committed truth is in the
// journal, and the block groups still hold the older version. Reading it without
// replaying shows the older version. So `needs_recovery` is detected and reported as
// a marker entry in the root — silently showing stale data to someone auditing
// firmware is the failure worth going out of the way to avoid.
//
// Also deliberately out of scope, each refused by name rather than half-read:
// encryption (contents are not readable without keys), bigalloc (cluster sizes
// change every block calculation), and META_BG (a different group-descriptor
// layout). Directory hashing is not a gap — htree directories keep their linear
// entries, so reading them the plain way is correct and simpler.

import Foundation

final class ExtDriver: ImageFilesystemDriver {
    static let id = "ext"

    private let reader: ImageReader
    private let sb: Superblock
    private let layout: ExtLayoutResolver
    /// Per-entry inode number, so extraction can go straight back to the inode.
    private var inodeForEntry: [Int: UInt32] = [:]

    private(set) var entries: [ImageEntry] = []
    private(set) var droppedNames = 0
    var formatDescription: String {
        "\(sb.familyName), \(sb.blockSize / 1024) KB blocks, \(sb.inodeCount) inodes"
    }

    // MARK: - Superblock

    private static let magic: UInt16 = 0xEF53
    private static let superblockOffset: Int64 = 1024

    /// Feature bits this driver reads or refuses. Only the ones acted on are named;
    /// an unnamed bit is one whose presence changes nothing here.
    private enum Incompat {
        static let filetype: UInt32 = 0x0002
        static let recover: UInt32 = 0x0004
        static let metaBG: UInt32 = 0x0010
        static let extents: UInt32 = 0x0040
        static let sixtyFourBit: UInt32 = 0x0080
        static let inlineData: UInt32 = 0x8000
        static let encrypt: UInt32 = 0x1_0000
    }
    private enum RoCompat {
        static let bigalloc: UInt32 = 0x0200
    }

    private struct Superblock {
        let inodeCount: UInt32
        let blockCount: Int64
        let firstDataBlock: Int64
        let blockSize: Int64
        let blocksPerGroup: Int64
        let inodesPerGroup: UInt32
        let inodeSize: Int
        let descriptorSize: Int
        let featureIncompat: UInt32
        let featureRoCompat: UInt32
        let hasFileType: Bool
        let is64Bit: Bool
        let needsRecovery: Bool
        let familyName: String
    }

    static func probe(_ reader: ImageReader) -> Bool {
        guard let value = try? reader.u16le(at: superblockOffset + 56) else { return false }
        return value == magic
    }

    init(reader: ImageReader) throws {
        self.reader = reader
        let base = Self.superblockOffset
        guard try reader.u16le(at: base + 56) == Self.magic else { throw ImageError.notThisFormat }

        let logBlockSize = try reader.u32le(at: base + 24)
        guard logBlockSize <= 6 else {
            throw ImageError.damaged(reason: "implausible log block size \(logBlockSize)")
        }
        let blockSize = Int64(1024) << Int64(logBlockSize)

        let revision = try reader.u32le(at: base + 76)
        let featureIncompat = revision >= 1 ? try reader.u32le(at: base + 96) : 0
        let featureRoCompat = revision >= 1 ? try reader.u32le(at: base + 100) : 0

        // Refuse before parsing anything that these features would change the meaning
        // of. Each says what it is, because "this image needs a tool that handles
        // encryption" is actionable and "damaged" is not.
        if featureIncompat & Incompat.encrypt != 0 {
            throw ImageError.unsupported(reason: "the filesystem is encrypted (ext4 encryption)")
        }
        if featureIncompat & Incompat.metaBG != 0 {
            throw ImageError.unsupported(reason: "META_BG group descriptor layout is not supported")
        }
        if featureRoCompat & RoCompat.bigalloc != 0 {
            throw ImageError.unsupported(reason: "bigalloc (cluster allocation) is not supported")
        }

        let is64Bit = featureIncompat & Incompat.sixtyFourBit != 0
        let blocksLow = Int64(try reader.u32le(at: base + 4))
        let blocksHigh = is64Bit ? Int64(try reader.u32le(at: base + 336)) : 0
        let blockCount = blocksLow | blocksHigh << 32
        guard blockCount > 0 else { throw ImageError.damaged(reason: "filesystem has no blocks") }

        let inodeSize = revision >= 1 ? Int(try reader.u16le(at: base + 88)) : 128
        guard inodeSize >= 128, inodeSize <= blockSize, inodeSize.nonzeroBitCount == 1 else {
            throw ImageError.damaged(reason: "implausible inode size \(inodeSize)")
        }
        let descriptorSize = is64Bit ? Int(try reader.u16le(at: base + 254)) : 32
        guard descriptorSize >= 32, descriptorSize <= 1024 else {
            throw ImageError.damaged(reason: "implausible group descriptor size \(descriptorSize)")
        }

        let blocksPerGroup = Int64(try reader.u32le(at: base + 32))
        let inodesPerGroup = try reader.u32le(at: base + 40)
        guard blocksPerGroup > 0, inodesPerGroup > 0 else {
            throw ImageError.damaged(reason: "group has no blocks or no inodes")
        }

        let needsRecovery = featureIncompat & Incompat.recover != 0
        let featureCompat = revision >= 1 ? try reader.u32le(at: base + 92) : 0
        let hasJournal = featureCompat & 0x0004 != 0
        let family: String
        if featureIncompat & Incompat.extents != 0 || is64Bit {
            family = "ext4"
        } else if hasJournal {
            family = "ext3"
        } else {
            family = "ext2"
        }

        self.sb = Superblock(
            inodeCount: try reader.u32le(at: base + 0),
            blockCount: blockCount,
            firstDataBlock: Int64(try reader.u32le(at: base + 20)),
            blockSize: blockSize,
            blocksPerGroup: blocksPerGroup,
            inodesPerGroup: inodesPerGroup,
            inodeSize: inodeSize,
            descriptorSize: descriptorSize,
            featureIncompat: featureIncompat,
            featureRoCompat: featureRoCompat,
            hasFileType: featureIncompat & Incompat.filetype != 0,
            is64Bit: is64Bit,
            needsRecovery: needsRecovery,
            familyName: family)

        // The superblock describes a filesystem larger than the file holding it: a
        // truncated image, and every block number in it is a promise the file cannot
        // keep. Caught here rather than as a confusing failure deep in a block walk.
        guard blockCount * blockSize <= reader.size else {
            throw ImageError.damaged(
                reason: "the filesystem claims \(blockCount * blockSize) bytes, the image is \(reader.size)")
        }

        self.layout = ExtLayoutResolver(reader: reader, blockSize: blockSize, totalBlocks: blockCount)
        try walk()
    }

    // MARK: - Inodes

    private struct Inode {
        let mode: UInt16
        let size: Int64
        let mtime: Int64
        let flags: UInt32
        /// The raw 60 bytes of i_block — an extent tree root, 15 block pointers, or
        /// a short symlink target, depending on the flags and the mode.
        let blockBytes: [UInt8]
        let blockPointers: [UInt32]

        var isDirectory: Bool { mode & 0xF000 == 0x4000 }
        var isRegularFile: Bool { mode & 0xF000 == 0x8000 }
        var isSymlink: Bool { mode & 0xF000 == 0xA000 }
        var usesExtents: Bool { flags & 0x0008_0000 != 0 }
        var usesInlineData: Bool { flags & 0x1000_0000 != 0 }
    }

    /// Byte offset of the group descriptor table. It follows the superblock's block,
    /// which is block 1 on a 1 KB filesystem and block 0 otherwise — hence
    /// `firstDataBlock` rather than a constant.
    private var groupDescriptorTableOffset: Int64 {
        (sb.firstDataBlock + 1) * sb.blockSize
    }

    private func inodeTableStart(group: Int64) throws -> Int64 {
        let descriptor = groupDescriptorTableOffset + group * Int64(sb.descriptorSize)
        let low = Int64(try reader.u32le(at: descriptor + 8))
        let high = sb.is64Bit && sb.descriptorSize >= 44
            ? Int64(try reader.u32le(at: descriptor + 40)) : 0
        let block = low | high << 32
        guard block > 0, block < sb.blockCount else {
            throw ImageError.damaged(reason: "group \(group) inode table at block \(block)")
        }
        return block * sb.blockSize
    }

    private func readInode(_ number: UInt32) throws -> Inode {
        guard number >= 1, number <= sb.inodeCount else {
            throw ImageError.damaged(reason: "inode \(number) of \(sb.inodeCount)")
        }
        let group = Int64(number - 1) / Int64(sb.inodesPerGroup)
        let indexInGroup = Int64(number - 1) % Int64(sb.inodesPerGroup)
        let offset = try inodeTableStart(group: group) + indexInGroup * Int64(sb.inodeSize)

        let mode = try reader.u16le(at: offset + 0)
        let sizeLow = Int64(try reader.u32le(at: offset + 4))
        let flags = try reader.u32le(at: offset + 32)
        let blockBytes = try reader.bytes(at: offset + 40, count: 60)
        // i_size_high doubles as i_dir_acl for directories, so it is only a size for
        // regular files — reading it unconditionally gives directories absurd sizes.
        let isRegular = mode & 0xF000 == 0x8000
        let sizeHigh = isRegular ? Int64(try reader.u32le(at: offset + 108)) : 0
        let size = sizeLow | sizeHigh << 32
        guard size >= 0, size <= ImageLimits.maxEntrySize else {
            throw ImageError.limitExceeded(limit: "maxEntrySize (\(ImageLimits.maxEntrySize))")
        }

        var pointers: [UInt32] = []
        pointers.reserveCapacity(15)
        for index in 0..<15 {
            let base = index * 4
            pointers.append(UInt32(blockBytes[base]) | UInt32(blockBytes[base + 1]) << 8
                            | UInt32(blockBytes[base + 2]) << 16 | UInt32(blockBytes[base + 3]) << 24)
        }
        return Inode(mode: mode, size: size,
                     mtime: Int64(try reader.u32le(at: offset + 16)),
                     flags: flags, blockBytes: blockBytes, blockPointers: pointers)
    }

    // MARK: - Tree walk

    private static let rootInode: UInt32 = 2

    private func walk() throws {
        var collector = EntryCollector()
        if sb.needsRecovery {
            // A marker entry, not a log line: the person reading this is looking at a
            // file list, and a warning they never see is not a warning. It sorts to
            // the top of the root and says what to do about it.
            try collector.add(ImageEntry(
                path: "!! UNCLEAN FILESYSTEM - run e2fsck, contents may be stale",
                size: 0, mtime: 0, kind: .special, mode: 0, locator: 0))
        }
        var visited: Set<UInt32> = []
        try walkDirectory(inode: Self.rootInode, path: "", depth: 0,
                          visited: &visited, collector: &collector)
        entries = collector.entries
        droppedNames = collector.droppedNames
    }

    /// Read a directory's linear entries and recurse into subdirectories.
    ///
    /// `visited` guards against a directory tree that contains a cycle. Depth alone
    /// is not enough: two directories pointing at each other stay shallow while
    /// producing an unbounded number of distinct paths.
    private func walkDirectory(inode number: UInt32, path: String, depth: Int,
                               visited: inout Set<UInt32>, collector: inout EntryCollector) throws {
        try EntryCollector.checkDepth(depth)
        guard visited.insert(number).inserted else {
            throw ImageError.damaged(reason: "directory cycle at \(path.isEmpty ? "/" : path)")
        }
        let inode = try readInode(number)
        guard inode.isDirectory else {
            throw ImageError.damaged(reason: "inode \(number) at \(path) is not a directory")
        }

        // An inline directory keeps its entries in `i_block`, behind a 4-byte parent
        // inode number that stands in for the `.` and `..` records a normal directory
        // block starts with. Those two are absent here, which costs nothing: the entry
        // loop skips them by name anyway.
        let contents: Data
        if inode.usesInlineData {
            let inline = try inlineContents(of: inode)
            guard inline.count > 4 else { return }   // parent field only: an empty directory
            contents = Data(inline.dropFirst(4))
        } else {
            contents = try self.contents(of: inode)
        }
        var subdirectories: [(inode: UInt32, path: String)] = []
        var offset = 0
        while offset + 8 <= contents.count {
            let entryInode = contents.u32(offset)
            let recordLength = Int(contents.u16(offset + 4))
            // rec_len is what advances the cursor, so a zero or unaligned value would
            // either loop forever or walk into the middle of the next record.
            guard recordLength >= 8, recordLength % 4 == 0, offset + recordLength <= contents.count else {
                throw ImageError.damaged(reason: "directory record length \(recordLength) at offset \(offset)")
            }
            let nameLength = sb.hasFileType
                ? Int(contents[offset + 6])
                : Int(contents.u16(offset + 6))
            defer { offset += recordLength }

            // inode 0 marks a deleted entry whose record is kept as padding.
            guard entryInode != 0, nameLength > 0, offset + 8 + nameLength <= contents.count else { continue }
            let name = String(decoding: contents[(offset + 8)..<(offset + 8 + nameLength)], as: UTF8.self)
            if name == "." || name == ".." { continue }
            guard let childPath = EntryPath.make(parent: path, component: name) else {
                collector.dropName()
                continue
            }
            try appendEntry(inode: entryInode, path: childPath,
                            collector: &collector, subdirectories: &subdirectories)
        }

        for child in subdirectories {
            try walkDirectory(inode: child.inode, path: child.path, depth: depth + 1,
                              visited: &visited, collector: &collector)
        }
        visited.remove(number)   // a sibling may legitimately reach the same inode via a hardlink
    }

    private func appendEntry(inode number: UInt32, path: String, collector: inout EntryCollector,
                             subdirectories: inout [(inode: UInt32, path: String)]) throws {
        let inode = try readInode(number)
        let index = collector.entries.count

        if inode.isDirectory {
            try collector.add(ImageEntry(path: path, size: -1, mtime: inode.mtime,
                                         kind: .directory, mode: UInt32(inode.mode),
                                         locator: UInt64(number)))
            subdirectories.append((number, path))
        } else if inode.isSymlink {
            let target = try symlinkTarget(inode)
            try collector.add(ImageEntry(path: path, size: Int64(target.utf8.count), mtime: inode.mtime,
                                         kind: .symlink(target: target), mode: UInt32(inode.mode),
                                         locator: UInt64(number)))
        } else if inode.isRegularFile {
            try collector.add(ImageEntry(path: path, size: inode.size, mtime: inode.mtime,
                                         kind: .file, mode: UInt32(inode.mode),
                                         locator: UInt64(number)))
            inodeForEntry[index] = number
        } else {
            try collector.add(ImageEntry(path: path, size: -1, mtime: inode.mtime,
                                         kind: .special, mode: UInt32(inode.mode),
                                         locator: UInt64(number)))
        }
    }

    /// A symlink target under 60 bytes is stored in the block pointers themselves
    /// ("fast symlink") rather than costing a whole block; longer ones live in blocks.
    private func symlinkTarget(_ inode: Inode) throws -> String {
        if inode.size < 60 && !inode.usesExtents {
            return String(decoding: inode.blockBytes.prefix(Int(inode.size)), as: UTF8.self)
        }
        return String(decoding: try contents(of: inode), as: UTF8.self)
    }

    private func runs(for inode: Inode) throws -> [ExtRun] {
        let blockCount = (inode.size + sb.blockSize - 1) / sb.blockSize
        if inode.usesExtents {
            return try layout.extentRuns(inlineRoot: inode.blockBytes)
        }
        return try layout.blockMapRuns(pointers: inode.blockPointers, blockCount: blockCount)
    }

    /// The 60 bytes of `i_block`, which hold the data itself when `inline_data` is set.
    ///
    /// Small files and small directories get no blocks at all — their contents sit in
    /// the space the block pointers would have used. That is not a rare corner: with
    /// `-O inline_data`, `mke2fs` stores *directories* this way too, so a driver
    /// without it cannot walk the tree at all, never mind read a file.
    ///
    /// Anything longer than 60 bytes continues in the inode's `system.data` extended
    /// attribute. That part is refused by name rather than truncated — returning the
    /// first 60 bytes of a longer file, silently, is the failure mode worth avoiding
    /// most: it looks like a file that read correctly.
    private static let inlineCapacity: Int64 = 60

    private func inlineContents(of inode: Inode) throws -> [UInt8] {
        guard inode.size <= Self.inlineCapacity else {
            throw ImageError.unsupported(
                reason: "this file's inline data continues in the system.data attribute "
                      + "(\(inode.size) bytes, \(Self.inlineCapacity) fit in the inode)")
        }
        return Array(inode.blockBytes.prefix(Int(inode.size)))
    }

    // MARK: - Extraction

    func extract(at index: Int, to handle: FileHandle) throws {
        guard entries.indices.contains(index), let number = inodeForEntry[index] else {
            throw ImageError.damaged(reason: "no file data for entry \(index)")
        }
        try writeContents(of: try readInode(number)) { bytes in
            try handle.write(contentsOf: bytes)
        }
    }

    /// Emit an inode's contents in order, from byte 0 to its recorded size.
    ///
    /// The run list is **sparse and addressed by logical block**, not a dense
    /// sequence to concatenate. An ext4 extent tree records only the blocks that
    /// exist: a file with a 300 KB hole followed by four bytes has exactly one
    /// extent, for logical block 73. Writing the runs back to back put those four
    /// bytes at offset 0 and padded the rest with zeros — a file of the right length,
    /// full of plausible-looking zeros, with its real content in the wrong place.
    /// Nothing about the result looked wrong, which is what made it worth a helper
    /// that every reader here goes through rather than three loops repeating it.
    private func writeContents(of inode: Inode, to sink: (Data) throws -> Void) throws {
        if inode.usesInlineData {
            try sink(Data(try inlineContents(of: inode)))
            return
        }
        var position: Int64 = 0

        func writeZeros(_ count: Int64) throws {
            var remaining = count
            while remaining > 0 {
                let chunk = Int(min(remaining, Int64(ImageLimits.copyChunkSize)))
                try sink(Data(count: chunk))
                remaining -= Int64(chunk)
            }
        }

        for run in try runs(for: inode) {
            guard position < inode.size else { break }
            let runStart = run.logicalBlock * sb.blockSize
            guard runStart >= position else {
                throw ImageError.damaged(reason: "overlapping runs at logical block \(run.logicalBlock)")
            }
            // The gap before this run is a hole: no blocks are allocated for it and
            // it reads as zeros.
            if runStart > position {
                try writeZeros(min(runStart, inode.size) - position)
                position = min(runStart, inode.size)
                guard position < inode.size else { break }
            }
            // The last run overshoots the end: blocks are whole, files are not.
            let runBytes = min(run.blockCount * sb.blockSize, inode.size - position)
            guard runBytes > 0 else { continue }
            if let physical = run.physicalBlock {
                var remaining = runBytes
                var cursor = physical * sb.blockSize
                while remaining > 0 {
                    let chunk = Int(min(remaining, Int64(ImageLimits.copyChunkSize)))
                    try sink(Data(try reader.bytes(at: cursor, count: chunk)))
                    remaining -= Int64(chunk)
                    cursor += Int64(chunk)
                }
            } else {
                // An uninitialised preallocated extent: reserved, never written.
                try writeZeros(runBytes)
            }
            position += runBytes
        }

        // A file may end in a hole, which no run covers. Extending to the recorded
        // size keeps the extracted file the length the listing promised.
        if position < inode.size { try writeZeros(inode.size - position) }
    }

    /// An inode's contents in memory — for directories and symlink targets, which are
    /// small and need random access rather than streaming.
    private func contents(of inode: Inode) throws -> Data {
        var data = Data()
        data.reserveCapacity(Int(min(inode.size, 1 << 20)))
        try writeContents(of: inode) { data.append($0) }
        return data
    }
}

private extension Data {
    func u16(_ offset: Int) -> UInt16 {
        UInt16(self[self.startIndex + offset]) | UInt16(self[self.startIndex + offset + 1]) << 8
    }
    func u32(_ offset: Int) -> UInt32 {
        let base = self.startIndex + offset
        return UInt32(self[base]) | UInt32(self[base + 1]) << 8
            | UInt32(self[base + 2]) << 16 | UInt32(self[base + 3]) << 24
    }
}
