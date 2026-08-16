// SPDX-License-Identifier: Apache-2.0
// SquashFSDriver.swift — SquashFS 4.0, read-only.
//
// The format embedded Linux actually ships in: almost every router, camera and
// set-top firmware image has a squashfs rootfs inside it. Compressed, read-only by
// design, and built by `mksquashfs` — which is also what produces the fixtures these
// are tested against, so a misreading here cannot cancel out against a matching
// miswriting.
//
// Layout: a 96-byte superblock at offset 0, then four independent regions. Inodes
// and directories live in the compressed metadata stream (see SquashFSMetadata.swift);
// file data lives in the image as compressed blocks of `blockSize`; anything smaller
// than a block is packed into shared *fragment* blocks so that a rootfs full of tiny
// config files does not waste a block each. Reading one file therefore means walking
// its block list and then, usually, pulling a tail out of a fragment shared with
// unrelated files.
//
// Scope and refusals. Version 4.0 only: 3.x has a different superblock and inode
// layout, and pretending to read it would produce plausible nonsense rather than an
// error, so it is named and refused. Big-endian images (a 1.x/2.x-era artefact) are
// likewise refused rather than guessed at. LZO is refused for licence reasons, and
// lz4/zstd until their decoders are vendored — each says which compressor it was, so
// the user can reach for `unsquashfs` instead of wondering what "damaged" meant.

import Foundation

final class SquashFSDriver: ImageFilesystemDriver {
    static let id = "squashfs"

    private let reader: ImageReader
    private let superblock: Superblock
    /// Fragment descriptors, indexed by fragment number.
    private var fragments: [Fragment] = []
    /// How to reach each regular file's data, by entry index.
    private var fileData: [Int: FileLayout] = [:]

    private(set) var entries: [ImageEntry] = []
    private(set) var droppedNames = 0
    var formatDescription: String {
        "SquashFS 4.\(superblock.minorVersion), \(superblock.codec.rawValue), "
            + "\(superblock.blockSize / 1024) KB blocks"
    }

    // MARK: - Superblock

    private static let magic: UInt32 = 0x7371_7368   // "hsqs" little-endian

    private struct Superblock {
        let inodeCount: UInt32
        let blockSize: Int
        let fragmentCount: UInt32
        let codec: Codec
        let minorVersion: UInt16
        let rootInode: InodeRef
        let bytesUsed: Int64
        let inodeTableStart: Int64
        let directoryTableStart: Int64
        let fragmentTableStart: Int64
    }

    /// Compressor ids as recorded in the superblock.
    private static func codec(for id: UInt16) throws -> Codec {
        switch id {
        case 1: return .zlib
        case 2: return .xz     // "lzma": 4.x images written with -comp lzma are xz-framed
        case 3: return .lzo
        case 4: return .xz
        case 5: return .lz4
        case 6: return .zstd
        default:
            throw ImageError.unsupported(reason: "unknown SquashFS compressor id \(id)")
        }
    }

    static func probe(_ reader: ImageReader) -> Bool {
        guard let value = try? reader.u32le(at: 0) else { return false }
        return value == magic
    }

    /// "hsqs" — the magic as the bytes read on disk, right at the front. This is the
    /// signature that matters most for carving: a SquashFS rootfs appended to a
    /// bootloader and a kernel is what a router firmware file *is*.
    static let carveSignatures = [CarveSignature("hsqs", at: 0)]

    /// `bytes_used` from the superblock. Distinct from the file's length: mksquashfs
    /// pads its output up to an erase-block boundary, and firmware appends the next
    /// blob after that padding, so the file is longer than the filesystem.
    static func byteLength(_ reader: ImageReader) -> Int64? {
        guard let used = try? reader.u64le(at: 40), used > 0, used <= Int64.max else { return nil }
        return Int64(used)
    }

    init(reader: ImageReader) throws {
        self.reader = reader
        guard try reader.u32le(at: 0) == Self.magic else { throw ImageError.notThisFormat }

        let major = try reader.u16le(at: 28)
        let minor = try reader.u16le(at: 30)
        guard major == 4 else {
            throw ImageError.unsupported(
                reason: "SquashFS \(major).\(minor) images are not supported (only 4.x)")
        }

        let blockSize = Int(try reader.u32le(at: 12))
        let blockLog = try reader.u16le(at: 22)
        // The format stores the block size twice, as a value and as its log2. They
        // must agree: a mismatch is the classic sign of a header that has been edited
        // or of a big-endian image being read as little-endian, and every offset
        // computed from a wrong block size would be silently wrong.
        guard blockLog < 32, blockSize == 1 << Int(blockLog) else {
            throw ImageError.damaged(
                reason: "block size \(blockSize) does not match block_log \(blockLog)")
        }
        guard blockSize >= 4096, blockSize <= 1 << 20 else {
            throw ImageError.damaged(reason: "implausible block size \(blockSize)")
        }

        let bytesUsed = Int64(bitPattern: try reader.u64le(at: 40))
        guard bytesUsed > 0, bytesUsed <= reader.size else {
            throw ImageError.damaged(
                reason: "superblock claims \(bytesUsed) bytes used, image is \(reader.size)")
        }

        self.superblock = Superblock(
            inodeCount: try reader.u32le(at: 4),
            blockSize: blockSize,
            fragmentCount: try reader.u32le(at: 16),
            codec: try Self.codec(for: try reader.u16le(at: 20)),
            minorVersion: minor,
            rootInode: InodeRef(try reader.u64le(at: 32)),
            bytesUsed: bytesUsed,
            inodeTableStart: Int64(bitPattern: try reader.u64le(at: 64)),
            directoryTableStart: Int64(bitPattern: try reader.u64le(at: 72)),
            fragmentTableStart: Int64(bitPattern: try reader.u64le(at: 80)))

        for (name, offset) in [("inode table", superblock.inodeTableStart),
                               ("directory table", superblock.directoryTableStart)] {
            guard offset > 0, offset < reader.size else {
                throw ImageError.damaged(reason: "\(name) starts at \(offset), outside the image")
            }
        }

        try readFragmentTable()
        try walk()
    }

    // MARK: - Fragment table
    //
    // Indirect on purpose: the table itself lives in the metadata stream, and what
    // `fragmentTableStart` points at is an array of 64-bit pointers to those metadata
    // blocks — one per 8 KB of descriptors. So the table is read in two hops.

    private struct Fragment {
        let start: Int64
        let size: Int
        let isCompressed: Bool
    }

    private func readFragmentTable() throws {
        guard superblock.fragmentCount > 0 else { return }
        let bytesOfDescriptors = Int(superblock.fragmentCount) * 16
        let indexCount = (bytesOfDescriptors + MetadataCursor.blockSize - 1) / MetadataCursor.blockSize
        guard superblock.fragmentTableStart > 0, superblock.fragmentTableStart < reader.size else {
            throw ImageError.damaged(reason: "fragment table starts outside the image")
        }

        var remaining = Int(superblock.fragmentCount)
        fragments.reserveCapacity(remaining)
        for index in 0..<indexCount {
            let pointer = Int64(bitPattern: try reader.u64le(
                at: superblock.fragmentTableStart + Int64(index) * 8))
            guard pointer > 0, pointer < reader.size else {
                throw ImageError.damaged(reason: "fragment table entry \(index) points outside the image")
            }
            let cursor = MetadataCursor(reader: reader, codec: superblock.codec, blockOffset: pointer)
            let inThisBlock = min(remaining, MetadataCursor.blockSize / 16)
            for _ in 0..<inThisBlock {
                let start = Int64(bitPattern: try cursor.u64())
                let sizeField = try cursor.u32()
                _ = try cursor.u32()   // unused
                fragments.append(Fragment(start: start,
                                          size: Int(sizeField & 0x00FF_FFFF),
                                          isCompressed: sizeField & 0x0100_0000 == 0))
            }
            remaining -= inThisBlock
        }
    }

    // MARK: - Tree walk

    /// Everything a regular file needs for extraction.
    private struct FileLayout {
        let blocksStart: Int64
        /// One entry per full block: low 24 bits are the on-disk size, bit 24 means
        /// stored uncompressed, and a size of 0 means a hole in a sparse file.
        let blockSizes: [UInt32]
        let fragmentIndex: UInt32?
        let fragmentOffset: Int
        let fileSize: Int64
    }

    private func walk() throws {
        var collector = EntryCollector()
        try walkDirectory(ref: superblock.rootInode, path: "", depth: 0, collector: &collector)
        entries = collector.entries
        droppedNames = collector.droppedNames
    }

    private func inodeCursor(_ ref: InodeRef) -> MetadataCursor {
        MetadataCursor(reader: reader, codec: superblock.codec,
                       blockOffset: superblock.inodeTableStart + ref.blockOffset,
                       offsetInBlock: ref.offsetInBlock)
    }

    /// Read the directory at `ref`, appending its entries and recursing.
    ///
    /// The recursion is depth-bounded rather than trusting the image: a damaged or
    /// hostile squashfs can point a child directory back at an ancestor, and without
    /// the bound that is an infinite descent building an infinite path.
    private func walkDirectory(ref: InodeRef, path: String, depth: Int,
                               collector: inout EntryCollector) throws {
        try EntryCollector.checkDepth(depth)
        let cursor = inodeCursor(ref)
        let header = try readInodeHeader(cursor)
        let listing: (start: Int64, size: Int, offset: Int)
        switch header.type {
        case .basicDirectory:
            let start = Int64(try cursor.u32())
            _ = try cursor.u32()                       // nlink
            let size = Int(try cursor.u16())
            let offset = Int(try cursor.u16())
            listing = (start, size, offset)
        case .extendedDirectory:
            _ = try cursor.u32()                       // nlink
            let size = Int(try cursor.u32())
            let start = Int64(try cursor.u32())
            _ = try cursor.u32()                       // parent inode
            _ = try cursor.u16()                       // index count
            let offset = Int(try cursor.u16())
            listing = (start, size, offset)
        default:
            throw ImageError.damaged(reason: "inode at \(path.isEmpty ? "/" : path) is not a directory")
        }

        // The recorded size counts three bytes of overhead the format adds; an empty
        // directory records exactly those three and has no entries at all.
        guard listing.size > 3 else { return }
        let payloadSize = listing.size - 3

        let directory = MetadataCursor(reader: reader, codec: superblock.codec,
                                       blockOffset: superblock.directoryTableStart + listing.start,
                                       offsetInBlock: listing.offset)
        var consumed = 0
        /// Children collected before recursing: the directory stream must be read to
        /// its end before descending, because a child's own listing shares the block
        /// cache and reading it invalidates nothing but the position.
        var subdirectories: [(ref: InodeRef, path: String)] = []

        while consumed < payloadSize {
            // Directory header: a run of entries that share a metadata block and a
            // base inode number.
            let count = Int(try directory.u32()) + 1
            let startBlock = Int64(try directory.u32())
            _ = try directory.u32()                    // base inode number
            consumed += 12
            guard count <= 256 else {
                throw ImageError.damaged(reason: "directory header claims \(count) entries (max 256)")
            }

            for _ in 0..<count {
                guard consumed < payloadSize else { break }
                let entryOffset = Int(try directory.u16())
                _ = try directory.i16()                // inode number delta
                let rawType = try directory.u16()
                let nameSize = Int(try directory.u16()) + 1
                let nameBytes = try directory.read(nameSize)
                consumed += 8 + nameSize

                let name = String(decoding: nameBytes, as: UTF8.self)
                guard let childPath = EntryPath.make(parent: path, component: name) else {
                    collector.dropName()
                    continue
                }
                let childRef = InodeRef(UInt64(startBlock) << 16 | UInt64(entryOffset))
                try appendEntry(ref: childRef, path: childPath, listedType: rawType,
                                collector: &collector, subdirectories: &subdirectories)
            }
        }

        for child in subdirectories {
            try walkDirectory(ref: child.ref, path: child.path, depth: depth + 1, collector: &collector)
        }
    }

    private func appendEntry(ref: InodeRef, path: String, listedType: UInt16,
                             collector: inout EntryCollector,
                             subdirectories: inout [(ref: InodeRef, path: String)]) throws {
        let cursor = inodeCursor(ref)
        let header = try readInodeHeader(cursor)

        switch header.type {
        case .basicDirectory, .extendedDirectory:
            try collector.add(ImageEntry(path: path, size: -1, mtime: header.mtime,
                                         kind: .directory, mode: UInt32(header.mode),
                                         locator: UInt64(header.inodeNumber)))
            subdirectories.append((ref, path))

        case .basicFile, .extendedFile:
            let layout = try readFileLayout(cursor, extended: header.type == .extendedFile)
            let index = collector.entries.count
            try collector.add(ImageEntry(path: path, size: layout.fileSize, mtime: header.mtime,
                                         kind: .file, mode: UInt32(header.mode),
                                         locator: UInt64(header.inodeNumber)))
            fileData[index] = layout

        case .basicSymlink, .extendedSymlink:
            _ = try cursor.u32()                       // nlink
            let targetSize = Int(try cursor.u32())
            guard targetSize <= 4096 else {
                throw ImageError.damaged(reason: "symlink target of \(targetSize) bytes at \(path)")
            }
            let target = String(decoding: try cursor.read(targetSize), as: UTF8.self)
            try collector.add(ImageEntry(path: path, size: Int64(targetSize), mtime: header.mtime,
                                         kind: .symlink(target: target), mode: UInt32(header.mode),
                                         locator: UInt64(header.inodeNumber)))

        case .basicBlockDevice, .basicCharDevice, .basicFifo, .basicSocket,
             .extendedBlockDevice, .extendedCharDevice, .extendedFifo, .extendedSocket:
            // Device nodes, FIFOs and sockets carry no data but are part of what a
            // rootfs *is* — /dev/console missing is a boot failure, so hiding them
            // would misrepresent the image being audited.
            try collector.add(ImageEntry(path: path, size: -1, mtime: header.mtime,
                                         kind: .special, mode: UInt32(header.mode),
                                         locator: UInt64(header.inodeNumber)))
        }
        _ = listedType   // the directory entry's type duplicates the inode's; the inode wins
    }

    private enum InodeType: UInt16 {
        case basicDirectory = 1, basicFile = 2, basicSymlink = 3
        case basicBlockDevice = 4, basicCharDevice = 5, basicFifo = 6, basicSocket = 7
        case extendedDirectory = 8, extendedFile = 9, extendedSymlink = 10
        case extendedBlockDevice = 11, extendedCharDevice = 12, extendedFifo = 13, extendedSocket = 14
    }

    private struct InodeHeader {
        let type: InodeType
        let mode: UInt16
        let mtime: Int64
        let inodeNumber: UInt32
    }

    private func readInodeHeader(_ cursor: MetadataCursor) throws -> InodeHeader {
        let rawType = try cursor.u16()
        guard let type = InodeType(rawValue: rawType) else {
            throw ImageError.damaged(reason: "unknown inode type \(rawType)")
        }
        let mode = try cursor.u16()
        _ = try cursor.u16()                           // uid index
        _ = try cursor.u16()                           // gid index
        let mtime = Int64(try cursor.u32())
        let inodeNumber = try cursor.u32()
        return InodeHeader(type: type, mode: mode, mtime: mtime, inodeNumber: inodeNumber)
    }

    private func readFileLayout(_ cursor: MetadataCursor, extended: Bool) throws -> FileLayout {
        let blocksStart: Int64, fileSize: Int64, rawFragment: UInt32, fragmentOffset: Int
        if extended {
            blocksStart = Int64(bitPattern: try cursor.u64())
            fileSize = Int64(bitPattern: try cursor.u64())
            _ = try cursor.u64()                       // sparse byte count
            _ = try cursor.u32()                       // nlink
            rawFragment = try cursor.u32()
            fragmentOffset = Int(try cursor.u32())
            _ = try cursor.u32()                       // xattr index
        } else {
            blocksStart = Int64(try cursor.u32())
            rawFragment = try cursor.u32()
            fragmentOffset = Int(try cursor.u32())
            fileSize = Int64(try cursor.u32())
        }
        guard fileSize >= 0, fileSize <= ImageLimits.maxEntrySize else {
            throw ImageError.limitExceeded(limit: "maxEntrySize (\(ImageLimits.maxEntrySize))")
        }

        // A file ends in a fragment unless it happens to be a whole number of blocks,
        // so the count of full blocks depends on whether there is a tail to share.
        let hasFragment = rawFragment != 0xFFFF_FFFF
        let blockSize = Int64(superblock.blockSize)
        let fullBlocks = hasFragment
            ? Int(fileSize / blockSize)
            : Int((fileSize + blockSize - 1) / blockSize)
        guard fullBlocks <= 1 << 22 else {
            throw ImageError.limitExceeded(limit: "block list of \(fullBlocks) entries")
        }
        var blockSizes: [UInt32] = []
        blockSizes.reserveCapacity(fullBlocks)
        for _ in 0..<fullBlocks { blockSizes.append(try cursor.u32()) }

        if hasFragment {
            guard Int(rawFragment) < fragments.count else {
                throw ImageError.damaged(
                    reason: "file references fragment \(rawFragment) of \(fragments.count)")
            }
        }
        return FileLayout(blocksStart: blocksStart, blockSizes: blockSizes,
                          fragmentIndex: hasFragment ? rawFragment : nil,
                          fragmentOffset: fragmentOffset, fileSize: fileSize)
    }

    // MARK: - Extraction

    func extract(at index: Int, to handle: FileHandle) throws {
        guard entries.indices.contains(index), let layout = fileData[index] else {
            throw ImageError.damaged(reason: "no file data for entry \(index)")
        }
        let entry = entries[index]

        var written: Int64 = 0
        var cursor = layout.blocksStart
        for sizeField in layout.blockSizes {
            let onDisk = Int(sizeField & 0x00FF_FFFF)
            let remaining = layout.fileSize - written
            let expanded = Int(min(remaining, Int64(superblock.blockSize)))
            if onDisk == 0 {
                // A hole. Real rootfs images contain them, and writing the zeros is
                // what keeps the extracted file the size the listing promised.
                try handle.write(contentsOf: Data(count: expanded))
            } else {
                let raw = try reader.bytes(at: cursor, count: onDisk)
                let bytes = sizeField & 0x0100_0000 != 0
                    ? raw
                    : try Decompressor.decompress(raw, codec: superblock.codec, expectedSize: expanded)
                try handle.write(contentsOf: bytes)
                cursor += Int64(onDisk)
            }
            written += Int64(expanded)
        }

        guard let fragmentIndex = layout.fragmentIndex else {
            guard written == layout.fileSize else {
                throw ImageError.damaged(
                    reason: "\(entry.path): wrote \(written) bytes, listing says \(layout.fileSize)")
            }
            return
        }
        let tail = try fragmentTail(fragmentIndex, offset: layout.fragmentOffset,
                                    length: Int(layout.fileSize - written), path: entry.path)
        try handle.write(contentsOf: tail)
    }

    /// The tail of a file, cut out of a fragment block it shares with other files.
    private func fragmentTail(_ index: UInt32, offset: Int, length: Int, path: String) throws -> [UInt8] {
        guard length >= 0 else {
            throw ImageError.damaged(reason: "\(path): negative fragment tail")
        }
        guard Int(index) < fragments.count else {
            throw ImageError.damaged(reason: "\(path): fragment \(index) of \(fragments.count)")
        }
        let fragment = fragments[Int(index)]
        let raw = try reader.bytes(at: fragment.start, count: fragment.size)
        let block = fragment.isCompressed
            ? try Decompressor.decompressVariable(raw, codec: superblock.codec,
                                                  maxSize: superblock.blockSize)
            : raw
        guard offset >= 0, offset + length <= block.count else {
            throw ImageError.damaged(
                reason: "\(path): fragment tail \(offset)..<\(offset + length) outside a \(block.count)-byte block")
        }
        return Array(block[offset..<(offset + length)])
    }
}
