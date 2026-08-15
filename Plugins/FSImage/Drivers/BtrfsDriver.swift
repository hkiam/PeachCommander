// SPDX-License-Identifier: Apache-2.0
// BtrfsDriver.swift — Btrfs, read-only.
//
// Everything in btrfs is a B-tree, and every B-tree has the same shape: a 101-byte
// header, then either key pointers (an internal node) or items (a leaf). What a tree
// *means* is decided entirely by the key types its leaves carry. So one node walker
// serves the chunk tree, the root tree and the filesystem tree, and the differences
// live in what each caller does with the items it is handed.
//
// The read order is forced by the format:
//   1. superblock → the bootstrap chunk records
//   2. chunk tree → the full logical→physical map (BtrfsChunkMap)
//   3. root tree  → where each subvolume's filesystem tree begins
//   4. fs tree    → inodes, directory entries and file extents
//
// Scope. Single-device images with SINGLE, DUP or RAID1-family profiles; zlib and
// zstd compression; the default subvolume plus every other subvolume, listed under its
// own name. Refused by name rather than half-read: multi-device, RAID0/10/5/6
// striping, zoned and extent-tree-v2 filesystems, and LZO compressed extents. Each
// refusal says what it is, because "this image needs a tool that handles RAID0" is
// actionable where "damaged" is not.

import Foundation

final class BtrfsDriver: ImageFilesystemDriver {
    static let id = "btrfs"

    private let reader: ImageReader
    private let sb: BtrfsSuperblock
    private var chunkMap: BtrfsChunkMap

    private(set) var entries: [ImageEntry] = []
    private(set) var droppedNames = 0
    /// Extents per (tree root, inode), assembled at extraction time.
    private var extents: [EntryKey: [FileExtent]] = [:]
    private var entryKeys: [Int: EntryKey] = [:]

    var formatDescription: String {
        let name = sb.label.isEmpty ? "" : " \"\(sb.label)\""
        return "Btrfs\(name), \(sb.nodeSize / 1024) KB nodes"
    }

    /// Identifies a file uniquely: the same inode number exists in every subvolume.
    private struct EntryKey: Hashable {
        let treeRoot: Int64
        let inode: UInt64
    }

    // MARK: - Node and item primitives

    /// Size of `btrfs_header`, which prefixes every tree block.
    private static let headerSize = 101
    /// An item entry in a leaf: 17-byte key, then data offset and size.
    private static let itemSize = 25
    /// A key pointer in an internal node: 17-byte key, block address, generation.
    private static let keyPointerSize = 33

    private struct Key {
        let objectID: UInt64
        let type: UInt8
        let offset: UInt64
    }

    private enum KeyType {
        static let inodeItem: UInt8 = 1
        static let inodeRef: UInt8 = 12
        static let dirItem: UInt8 = 84
        static let extentData: UInt8 = 108
        static let rootItem: UInt8 = 132
        static let chunkItem: UInt8 = 228
    }

    private func readNode(logical: Int64) throws -> [UInt8] {
        let offset = try chunkMap.physical(for: logical)
        return try reader.bytes(at: offset, count: Int(sb.nodeSize))
    }

    private static func key(_ raw: [UInt8], at offset: Int) -> Key {
        Key(objectID: raw.u64(offset), type: raw[offset + 8], offset: raw.u64(offset + 9))
    }

    /// Visit every leaf item in the tree rooted at `logical`, in key order.
    ///
    /// Depth is bounded rather than trusting the node's own level field: a damaged
    /// image can point a child back at an ancestor, and the level is exactly the
    /// value that would be lying in that case.
    private func walkTree(logical: Int64, depth: Int = 0,
                          visit: (Key, ArraySlice<UInt8>) throws -> Void) throws {
        try EntryCollector.checkDepth(depth)
        let node = try readNode(logical: logical)
        guard node.count >= Self.headerSize else {
            throw ImageError.damaged(reason: "tree block at \(logical) is short")
        }
        let itemCount = Int(node.u32(96))
        let level = node[100]

        if level == 0 {
            let dataBase = Self.headerSize
            for index in 0..<itemCount {
                let itemOffset = Self.headerSize + index * Self.itemSize
                guard itemOffset + Self.itemSize <= node.count else {
                    throw ImageError.damaged(reason: "leaf at \(logical) claims \(itemCount) items")
                }
                let dataOffset = dataBase + Int(node.u32(itemOffset + 17))
                let dataSize = Int(node.u32(itemOffset + 21))
                guard dataSize >= 0, dataOffset >= 0, dataOffset + dataSize <= node.count else {
                    throw ImageError.damaged(reason: "leaf item \(index) at \(logical) runs past the node")
                }
                try visit(Self.key(node, at: itemOffset), node[dataOffset..<(dataOffset + dataSize)])
            }
            return
        }

        for index in 0..<itemCount {
            let pointerOffset = Self.headerSize + index * Self.keyPointerSize
            guard pointerOffset + Self.keyPointerSize <= node.count else {
                throw ImageError.damaged(reason: "node at \(logical) claims \(itemCount) pointers")
            }
            let child = Int64(bitPattern: node.u64(pointerOffset + 17))
            try walkTree(logical: child, depth: depth + 1, visit: visit)
        }
    }

    // MARK: - Open

    static func probe(_ reader: ImageReader) -> Bool {
        BtrfsSuperblock.isPresent(in: reader)
    }

    init(reader: ImageReader) throws {
        self.reader = reader
        self.sb = try BtrfsSuperblock(reader: reader)
        self.chunkMap = try BtrfsChunkMap(bootstrapping: reader)

        // Step 2: the chunk tree, reachable only through the bootstrap map, replaces
        // that map with the complete one.
        var allChunks: [BtrfsChunk] = []
        try walkTree(logical: sb.chunkTreeLogical) { key, data in
            guard key.type == KeyType.chunkItem else { return }
            allChunks.append(try BtrfsChunkMap.parseChunk(Array(data), at: 0,
                                                          logicalStart: Int64(bitPattern: key.offset)))
        }
        guard !allChunks.isEmpty else {
            throw ImageError.damaged(reason: "the chunk tree holds no chunks")
        }
        chunkMap.replace(with: allChunks)

        try walkSubvolumes()
    }

    // MARK: - Subvolumes

    /// The default subvolume, always present, always object id 5.
    private static let fsTreeObjectID: UInt64 = 5
    /// The first inode number a subvolume's own root directory uses.
    private static let firstFreeObjectID: UInt64 = 256
    /// The last id a user subvolume can have — `(u64)-256`.
    ///
    /// Btrfs numbers its reserved trees *downward* from the top of the range, so they
    /// arrive as enormous unsigned values: the data relocation tree is `(u64)-9`, or
    /// 18446744073709551607. A lower bound alone therefore lets every reserved tree
    /// through, and the listing sprouts a "subvolume-18446744073709551607" that is
    /// btrfs's own bookkeeping rather than anything a user put there.
    private static let lastFreeObjectID: UInt64 = ~UInt64(0) - 255

    /// Step 3: find every filesystem tree, then walk each one.
    ///
    /// Subvolumes and snapshots are separate trees, and each is listed under its own
    /// name at the top level. Showing only the default subvolume would hide most of
    /// what is on a NAS or a rooted device — snapshots are where the older copies of
    /// the files someone is looking for actually live.
    private func walkSubvolumes() throws {
        var roots: [(objectID: UInt64, logical: Int64)] = []
        try walkTree(logical: sb.rootTreeLogical) { key, data in
            guard key.type == KeyType.rootItem, data.count >= 239 else { return }
            let bytes = Array(data)
            let logical = Int64(bitPattern: bytes.u64(176))
            guard logical > 0 else { return }
            // Object ids below the first free one are btrfs's own bookkeeping trees
            // (extent, device, checksum, …) and ids above the last free one are more
            // of the same, counted down from the top. Real data lives in FS_TREE and
            // in the range between them.
            let isUserSubvolume = key.objectID >= Self.firstFreeObjectID
                               && key.objectID <= Self.lastFreeObjectID
            guard key.objectID == Self.fsTreeObjectID || isUserSubvolume else { return }
            roots.append((key.objectID, logical))
        }
        guard !roots.isEmpty else {
            throw ImageError.damaged(reason: "the root tree holds no filesystem trees")
        }

        var collector = EntryCollector()
        // The default subvolume is presented at the top level; any others hang under
        // a name of their own so their paths cannot collide with it.
        for root in roots.sorted(by: { $0.objectID < $1.objectID }) {
            let prefix = root.objectID == Self.fsTreeObjectID ? "" : "subvolume-\(root.objectID)"
            if !prefix.isEmpty {
                try collector.add(ImageEntry(path: prefix, size: -1, mtime: 0, kind: .directory,
                                             mode: 0o040755, locator: root.objectID))
            }
            try walkFilesystemTree(root.logical, prefix: prefix, collector: &collector)
        }
        entries = collector.entries
        droppedNames = collector.droppedNames
    }

    // MARK: - Filesystem tree

    private struct Inode {
        var size: Int64 = 0
        var mode: UInt32 = 0
        var mtime: Int64 = 0
    }

    private struct FileExtent {
        let fileOffset: Int64
        let kind: UInt8            // 0 inline, 1 regular, 2 prealloc
        let compression: UInt8
        let ramBytes: Int64
        let diskBytenr: Int64
        let diskNumBytes: Int64
        let dataOffset: Int64      // offset into the decompressed extent
        let numBytes: Int64
        /// For an inline extent, its bytes straight out of the leaf.
        let inlineData: [UInt8]
    }

    /// Step 4: collect inodes, names and extents from one filesystem tree, then join
    /// them into paths.
    private func walkFilesystemTree(_ logical: Int64, prefix: String,
                                    collector: inout EntryCollector) throws {
        var inodes: [UInt64: Inode] = [:]
        /// child inode → (parent inode, name), from DIR_ITEM entries.
        var parents: [UInt64: (parent: UInt64, name: String)] = [:]
        var children: [UInt64: [UInt64]] = [:]

        try walkTree(logical: logical) { key, data in
            let bytes = Array(data)
            switch key.type {
            case KeyType.inodeItem:
                guard bytes.count >= 160 else { return }
                inodes[key.objectID] = Inode(
                    size: Int64(bitPattern: bytes.u64(16)),
                    mode: bytes.u32(52),
                    // mtime is a btrfs_timespec (u64 seconds, u32 nanoseconds) at 136.
                    mtime: Int64(bitPattern: bytes.u64(136)))

            case KeyType.dirItem:
                // One item can hold several entries when names collide in the hash.
                var offset = 0
                while offset + 30 <= bytes.count {
                    let childInode = bytes.u64(offset)          // location key's objectid
                    let locationType = bytes[offset + 8]
                    let dataLength = Int(bytes.u16(offset + 25))
                    let nameLength = Int(bytes.u16(offset + 27))
                    guard nameLength > 0, offset + 30 + nameLength + dataLength <= bytes.count else { return }
                    let name = String(decoding: bytes[(offset + 30)..<(offset + 30 + nameLength)],
                                      as: UTF8.self)
                    // locationType 1 is an inode in this tree; 132 points at another
                    // subvolume's root, which is listed on its own rather than here.
                    if locationType == KeyType.inodeItem {
                        parents[childInode] = (key.objectID, name)
                        children[key.objectID, default: []].append(childInode)
                    }
                    offset += 30 + nameLength + dataLength
                }

            case KeyType.extentData:
                guard bytes.count >= 21 else { return }
                let kind = bytes[20]
                let compression = bytes[16]
                let ramBytes = Int64(bitPattern: bytes.u64(8))
                let entryKey = EntryKey(treeRoot: logical, inode: key.objectID)
                if kind == 0 {
                    extents[entryKey, default: []].append(FileExtent(
                        fileOffset: Int64(bitPattern: key.offset), kind: kind,
                        compression: compression, ramBytes: ramBytes,
                        diskBytenr: 0, diskNumBytes: 0, dataOffset: 0, numBytes: ramBytes,
                        inlineData: Array(bytes[21...])))
                } else {
                    guard bytes.count >= 53 else { return }
                    extents[entryKey, default: []].append(FileExtent(
                        fileOffset: Int64(bitPattern: key.offset), kind: kind,
                        compression: compression, ramBytes: ramBytes,
                        diskBytenr: Int64(bitPattern: bytes.u64(21)),
                        diskNumBytes: Int64(bitPattern: bytes.u64(29)),
                        dataOffset: Int64(bitPattern: bytes.u64(37)),
                        numBytes: Int64(bitPattern: bytes.u64(45)),
                        inlineData: []))
                }

            default:
                break
            }
        }

        try emit(root: logical, prefix: prefix, inode: Self.firstFreeObjectID, path: prefix,
                 depth: 0, inodes: inodes, children: children, parents: parents,
                 collector: &collector)
    }

    /// Walk from a directory inode outward, emitting entries in parent-before-child order.
    private func emit(root: Int64, prefix: String, inode: UInt64, path: String, depth: Int,
                      inodes: [UInt64: Inode], children: [UInt64: [UInt64]],
                      parents: [UInt64: (parent: UInt64, name: String)],
                      collector: inout EntryCollector) throws {
        try EntryCollector.checkDepth(depth)
        for child in (children[inode] ?? []).sorted() {
            guard let name = parents[child]?.name else { continue }
            guard let childPath = EntryPath.make(parent: path, component: name) else {
                collector.dropName()
                continue
            }
            let info = inodes[child] ?? Inode()
            let format = info.mode & 0xF000
            let index = collector.entries.count

            switch format {
            case 0x4000:
                try collector.add(ImageEntry(path: childPath, size: -1, mtime: info.mtime,
                                             kind: .directory, mode: info.mode, locator: child))
                try emit(root: root, prefix: prefix, inode: child, path: childPath, depth: depth + 1,
                         inodes: inodes, children: children, parents: parents, collector: &collector)
            case 0xA000:
                let key = EntryKey(treeRoot: root, inode: child)
                let target = String(decoding: try assemble(key: key, size: info.size), as: UTF8.self)
                try collector.add(ImageEntry(path: childPath, size: info.size, mtime: info.mtime,
                                             kind: .symlink(target: target), mode: info.mode,
                                             locator: child))
            case 0x8000:
                try collector.add(ImageEntry(path: childPath, size: info.size, mtime: info.mtime,
                                             kind: .file, mode: info.mode, locator: child))
                entryKeys[index] = EntryKey(treeRoot: root, inode: child)
            default:
                try collector.add(ImageEntry(path: childPath, size: -1, mtime: info.mtime,
                                             kind: .special, mode: info.mode, locator: child))
            }
        }
    }

    // MARK: - File contents

    /// Assemble a file from its extents.
    ///
    /// Anything no extent covers is a hole: with the NO_HOLES feature — set by every
    /// current mkfs.btrfs — a gap is simply not recorded, so zero-filling the gaps is
    /// how holes are read rather than a fallback for damage.
    private func assemble(key: EntryKey, size: Int64) throws -> [UInt8] {
        guard size > 0 else { return [] }
        guard size <= Int64(ImageLimits.maxInMemoryImage) else {
            throw ImageError.limitExceeded(limit: "maxInMemoryImage (\(ImageLimits.maxInMemoryImage))")
        }
        var out = [UInt8](repeating: 0, count: Int(size))

        for extent in (extents[key] ?? []).sorted(by: { $0.fileOffset < $1.fileOffset }) {
            guard extent.fileOffset < size else { continue }
            let codec = try Self.codec(for: extent.compression)

            let payload: [UInt8]
            switch extent.kind {
            case 0:   // inline: the bytes are in the leaf itself
                payload = codec == .none
                    ? extent.inlineData
                    : try Decompressor.decompressVariable(extent.inlineData, codec: codec,
                                                          maxSize: Int(extent.ramBytes))
            case 2:   // preallocated but never written: reads as zeros
                continue
            default:
                guard extent.diskBytenr != 0 else { continue }   // an explicit hole
                let physical = try chunkMap.physical(for: extent.diskBytenr)
                let raw = try reader.bytes(at: physical, count: Int(extent.diskNumBytes))
                if codec == .none {
                    // Uncompressed: `dataOffset` indexes into the extent on disk.
                    let start = Int(extent.dataOffset)
                    let count = Int(min(extent.numBytes, Int64(raw.count) - extent.dataOffset))
                    guard start >= 0, count > 0, start + count <= raw.count else { continue }
                    payload = Array(raw[start..<(start + count)])
                } else {
                    // Compressed: the whole extent decompresses first, and only then
                    // does `dataOffset` mean anything — it indexes the *uncompressed*
                    // bytes. Slicing before decompressing reads the wrong region.
                    //
                    // `ram_bytes` is an upper bound, not the exact output length: it
                    // is the extent's uncompressed span rounded up to the sector size.
                    // A file's final extent is short — 300 KB of data ends in an
                    // extent claiming 40960 whose stream yields 37856 — so demanding
                    // an exact match rejects the tail of every file that is not a
                    // whole number of sectors, while every full 128 KB extent before
                    // it decodes cleanly. That is why this only shows up on files
                    // larger than one extent.
                    let expanded = try Decompressor.decompressVariable(raw, codec: codec,
                                                                       maxSize: Int(extent.ramBytes))
                    let start = Int(extent.dataOffset)
                    let count = Int(min(extent.numBytes, Int64(expanded.count) - extent.dataOffset))
                    guard start >= 0, count > 0, start + count <= expanded.count else { continue }
                    payload = Array(expanded[start..<(start + count)])
                }
            }

            let start = Int(extent.fileOffset)
            let count = min(payload.count, Int(size) - start)
            guard count > 0 else { continue }
            out.replaceSubrange(start..<(start + count), with: payload[0..<count])
        }
        return out
    }

    private static func codec(for compression: UInt8) throws -> Codec {
        switch compression {
        case 0: return .none
        case 1: return .zlib
        case 2: throw ImageError.unsupported(
            reason: "LZO-compressed extents are not supported (no licence-compatible decoder)")
        case 3: return .zstd
        default: throw ImageError.damaged(reason: "unknown Btrfs compression id \(compression)")
        }
    }

    func extract(at index: Int, to handle: FileHandle) throws {
        guard entries.indices.contains(index), let key = entryKeys[index] else {
            throw ImageError.damaged(reason: "no file data for entry \(index)")
        }
        try handle.write(contentsOf: Data(try assemble(key: key, size: entries[index].size)))
    }
}
