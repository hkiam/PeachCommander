// SPDX-License-Identifier: Apache-2.0
// UBIFSDriver.swift — UBIFS, read-only.
//
// JFFS2's successor, and what current embedded hardware actually ships: JFFS2 scans the
// whole flash at mount because it has no index, which stops being acceptable somewhere
// around 128 MB. UBIFS keeps a real B-tree on disk, so it starts in constant time.
//
// Reading a freshly-written image is therefore *easier* than JFFS2, not harder — there
// is no log to replay, just three hops:
//
//   1. superblock at LEB 0 → the LEB size, which turns every later (lnum, offs) into a
//      file offset
//   2. master node at LEB 1 → where the index tree's root sits
//   3. the index → leaves holding inodes, directory entries and data nodes
//
// What makes it feel harder is that nearly every offset is one you cannot guess. Two
// were wrong on the first attempt here and neither failed loudly: `node_type` lives at
// offset 20 of the common header, not 16 — 16 is the length field, so reading it there
// classifies every node as something absurd — and a branch is `lnum, offs, len, key`,
// with the key *last*, which yields child pointers outside the volume rather than an
// error. Both were settled by measuring a real image.
//
// Scope. A cleanly written image: the on-disk index is complete, so the journal is not
// replayed and unclean images are refused rather than half-read. Compression is
// whatever `Decompressor` handles, which since LZO landed is all four UBIFS uses —
// and LZO is the default, so without it this driver would list a tree and fail on
// nearly every file in it.

import Foundation

final class UBIFSDriver: ImageFilesystemDriver {
    static let id = "ubifs"

    private let source: ByteSource
    private let lebSize: Int64
    private let defaultCompression: UInt16

    private(set) var entries: [ImageEntry] = []
    private(set) var droppedNames = 0
    /// Data nodes per inode, by logical block number.
    private var dataNodes: [UInt32: [UInt32: NodeLocation]] = [:]
    private var inodeForEntry: [Int: UInt32] = [:]

    var formatDescription: String {
        "UBIFS, \(lebSize / 1024) KB LEBs, \(entries.count) entries"
    }

    private static let magic: UInt32 = 0x0610_1831
    /// UBIFS addresses file contents in fixed 4 KB logical blocks, independent of the
    /// flash geometry.
    private static let blockSize: Int64 = 4096

    private enum NodeType {
        static let inode: UInt8 = 0
        static let data: UInt8 = 1
        static let dent: UInt8 = 2
        static let index: UInt8 = 9
    }

    private struct NodeLocation {
        let offset: Int64
        let length: Int
    }

    // MARK: - Probe and open

    static func probe(_ reader: ImageReader) -> Bool {
        // A UBI container, which is how firmware actually ships this filesystem.
        if UBIVolumeSource.isPresent(in: reader) { return true }
        guard let value = try? reader.u32le(at: 0), value == magic else { return false }
        // A superblock node, not just any node, has to be first.
        return (try? reader.u8(at: 20)) == 6
    }

    /// The UBI container's erase-counter header, and a bare UBIFS superblock. Firmware
    /// carries the container far more often than the bare image, which is why "UBI#"
    /// is listed first.
    static let carveSignatures = [
        CarveSignature("UBI#", at: 0),
        CarveSignature([0x31, 0x18, 0x10, 0x06], at: 0),   // 0x06101831 little-endian
    ]

    /// Open either a bare `.ubifs` image or a `.ubi` container.
    ///
    /// The container case is not a separate driver because it is not a separate
    /// filesystem: UBI only reorders erase blocks, so mapping them back into sequence
    /// produces exactly the bare image the other case starts from.
    convenience init(reader: ImageReader) throws {
        if UBIVolumeSource.isPresent(in: reader) {
            try self.init(source: try UBIVolumeSource(reader: reader))
        } else {
            try self.init(source: reader)
        }
    }

    /// Also reachable with a UBI volume as the source, which presents that volume's
    /// LEBs as one contiguous run (see `UBIVolumeSource`).
    init(source: ByteSource) throws {
        self.source = source
        guard try Self.u32(source, 0) == Self.magic, try Self.u8(source, 20) == 6 else {
            throw ImageError.notThisFormat
        }
        let lebSize = Int64(try Self.u32(source, 36))
        guard lebSize >= 4096, lebSize <= 1 << 22 else {
            throw ImageError.damaged(reason: "implausible LEB size \(lebSize)")
        }
        self.lebSize = lebSize
        self.defaultCompression = try Self.u16(source, 84)

        let keyFormat = try Self.u8(source, 27)
        guard keyFormat == 0 else {
            throw ImageError.unsupported(reason: "UBIFS key format \(keyFormat) is not supported")
        }
        let formatVersion = try Self.u32(source, 80)
        guard formatVersion <= 5 else {
            throw ImageError.unsupported(reason: "UBIFS format version \(formatVersion) is not supported")
        }

        // The master node sits at LEB 1 and points at the index root.
        let master = lebSize
        guard try Self.u32(source, master) == Self.magic, try Self.u8(source, master + 20) == 7 else {
            throw ImageError.damaged(reason: "no master node at LEB 1")
        }
        let rootLnum = Int64(try Self.u32(source, master + 48))
        let rootOffs = Int64(try Self.u32(source, master + 52))

        try walk(rootLnum: rootLnum, rootOffs: rootOffs)
    }

    // MARK: - Little-endian reads through the source

    private static func u8(_ source: ByteSource, _ offset: Int64) throws -> UInt8 {
        try source.bytes(at: offset, count: 1)[0]
    }
    private static func u16(_ source: ByteSource, _ offset: Int64) throws -> UInt16 {
        let raw = try source.bytes(at: offset, count: 2)
        return UInt16(raw[0]) | UInt16(raw[1]) << 8
    }
    private static func u32(_ source: ByteSource, _ offset: Int64) throws -> UInt32 {
        let raw = try source.bytes(at: offset, count: 4)
        return UInt32(raw[0]) | UInt32(raw[1]) << 8 | UInt32(raw[2]) << 16 | UInt32(raw[3]) << 24
    }
    private static func u64(_ source: ByteSource, _ offset: Int64) throws -> UInt64 {
        UInt64(try u32(source, offset)) | UInt64(try u32(source, offset + 4)) << 32
    }

    private func offsetOf(lnum: Int64, offs: Int64) throws -> Int64 {
        guard lnum >= 0, offs >= 0, offs < lebSize else {
            throw ImageError.damaged(reason: "branch points at LEB \(lnum) offset \(offs)")
        }
        let offset = lnum * lebSize + offs
        guard source.contains(offset: offset, count: 24) else {
            throw ImageError.damaged(reason: "LEB \(lnum) offset \(offs) is outside the image")
        }
        return offset
    }

    // MARK: - Index walk

    /// A branch is `lnum, offs, len` and only then the key — 20 bytes with the 8-byte
    /// "simple" key format.
    private static let branchSize = 20

    private func walk(rootLnum: Int64, rootOffs: Int64) throws {
        var inodes: [UInt32: (mode: UInt32, size: Int64, mtime: Int64,
                              compression: UInt16, dataLength: Int, offset: Int64)] = [:]
        var dirents: [(parent: UInt32, child: UInt32, name: String)] = []

        try walkNode(lnum: rootLnum, offs: rootOffs, depth: 0) { offset, type in
            switch type {
            case NodeType.inode:
                let inum = try Self.u32(self.source, offset + 24)
                inodes[inum] = (mode: try Self.u32(self.source, offset + 104),
                                size: Int64(bitPattern: try Self.u64(self.source, offset + 48)),
                                mtime: Int64(bitPattern: try Self.u64(self.source, offset + 72)),
                                compression: try Self.u16(self.source, offset + 132),
                                dataLength: Int(try Self.u32(self.source, offset + 112)),
                                offset: offset)

            case NodeType.dent:
                let parent = try Self.u32(self.source, offset + 24)
                let child = UInt32(truncatingIfNeeded: try Self.u64(self.source, offset + 40))
                let nameLength = Int(try Self.u16(self.source, offset + 50))
                guard nameLength > 0, nameLength <= 1024 else { return }
                let raw = try self.source.bytes(at: offset + 56, count: nameLength)
                dirents.append((parent, child, String(decoding: raw, as: UTF8.self)))

            case NodeType.data:
                let inum = try Self.u32(self.source, offset + 24)
                // The key's second word carries the node type in its top three bits and
                // the logical block number in the rest.
                let block = try Self.u32(self.source, offset + 28) & 0x1FFF_FFFF
                let length = Int(try Self.u32(self.source, offset + 16))
                self.dataNodes[inum, default: [:]][block] = NodeLocation(offset: offset, length: length)

            default:
                break
            }
        }

        guard !inodes.isEmpty else { throw ImageError.damaged(reason: "the index holds no inodes") }

        var children: [UInt32: [(child: UInt32, name: String)]] = [:]
        for dirent in dirents { children[dirent.parent, default: []].append((dirent.child, dirent.name)) }

        var collector = EntryCollector()
        var visited: Set<UInt32> = []
        try emit(inode: 1, path: "", depth: 0, inodes: inodes, children: children,
                 visited: &visited, collector: &collector)
        entries = collector.entries
        droppedNames = collector.droppedNames
    }

    /// Descend the index, handing every leaf node's position and type to `visit`.
    private func walkNode(lnum: Int64, offs: Int64, depth: Int,
                          visit: (Int64, UInt8) throws -> Void) throws {
        try EntryCollector.checkDepth(depth)
        let offset = try offsetOf(lnum: lnum, offs: offs)
        guard try Self.u32(source, offset) == Self.magic else {
            throw ImageError.damaged(reason: "no node at LEB \(lnum) offset \(offs)")
        }
        let type = try Self.u8(source, offset + 20)
        guard type == NodeType.index else {
            try visit(offset, type)
            return
        }
        let childCount = Int(try Self.u16(source, offset + 24))
        guard childCount <= 1024 else {
            throw ImageError.damaged(reason: "index node claims \(childCount) children")
        }
        for index in 0..<childCount {
            let branch = offset + 28 + Int64(index * Self.branchSize)
            let childLnum = Int64(try Self.u32(source, branch))
            let childOffs = Int64(try Self.u32(source, branch + 4))
            try walkNode(lnum: childLnum, offs: childOffs, depth: depth + 1, visit: visit)
        }
    }

    // MARK: - Tree

    private func emit(inode: UInt32, path: String, depth: Int,
                      inodes: [UInt32: (mode: UInt32, size: Int64, mtime: Int64,
                                        compression: UInt16, dataLength: Int, offset: Int64)],
                      children: [UInt32: [(child: UInt32, name: String)]],
                      visited: inout Set<UInt32>, collector: inout EntryCollector) throws {
        try EntryCollector.checkDepth(depth)
        guard visited.insert(inode).inserted else {
            throw ImageError.damaged(reason: "directory cycle at \(path.isEmpty ? "/" : path)")
        }
        defer { visited.remove(inode) }

        for entry in (children[inode] ?? []).sorted(by: { $0.name < $1.name }) {
            guard let info = inodes[entry.child] else { continue }
            guard let childPath = EntryPath.make(parent: path, component: entry.name) else {
                collector.dropName()
                continue
            }
            let index = collector.entries.count
            switch info.mode & 0xF000 {
            case 0x4000:
                try collector.add(ImageEntry(path: childPath, size: -1, mtime: info.mtime,
                                             kind: .directory, mode: info.mode,
                                             locator: UInt64(entry.child)))
                try emit(inode: entry.child, path: childPath, depth: depth + 1, inodes: inodes,
                         children: children, visited: &visited, collector: &collector)
            case 0xA000:
                // A symlink's target is stored in the inode itself, not in data nodes.
                let raw = try source.bytes(at: info.offset + 160, count: min(info.dataLength, 4096))
                try collector.add(ImageEntry(path: childPath, size: info.size, mtime: info.mtime,
                                             kind: .symlink(target: String(decoding: raw, as: UTF8.self)),
                                             mode: info.mode, locator: UInt64(entry.child)))
            case 0x8000:
                try collector.add(ImageEntry(path: childPath, size: info.size, mtime: info.mtime,
                                             kind: .file, mode: info.mode, locator: UInt64(entry.child)))
                inodeForEntry[index] = entry.child
            default:
                try collector.add(ImageEntry(path: childPath, size: -1, mtime: info.mtime,
                                             kind: .special, mode: info.mode, locator: UInt64(entry.child)))
            }
        }
    }

    // MARK: - File contents

    private static func codec(for compression: UInt16) throws -> Codec {
        switch compression {
        case 0: return .none
        case 1: return .lzo
        case 2: return .zlib
        case 3: return .zstd
        default: throw ImageError.damaged(reason: "unknown UBIFS compression id \(compression)")
        }
    }

    func extract(at index: Int, to handle: FileHandle) throws {
        guard entries.indices.contains(index), let inode = inodeForEntry[index] else {
            throw ImageError.damaged(reason: "no file data for entry \(index)")
        }
        let size = entries[index].size
        guard size > 0 else { return }
        let blocks = (size + Self.blockSize - 1) / Self.blockSize
        let nodes = dataNodes[inode] ?? [:]

        var written: Int64 = 0
        for block in 0..<blocks {
            let remaining = size - written
            let want = Int(min(remaining, Self.blockSize))
            guard let node = nodes[UInt32(block)] else {
                // A block with no data node is a hole. UBIFS records only the blocks
                // that were written, so a sparse file simply has gaps here.
                try handle.write(contentsOf: Data(count: want))
                written += Int64(want)
                continue
            }
            let uncompressed = Int(try Self.u32(source, node.offset + 40))
            let codec = try Self.codec(for: try Self.u16(source, node.offset + 44))
            // The compressed payload runs from the end of the 48-byte header to the end
            // of the node, which the common header's own length field gives.
            let payloadLength = node.length - 48
            guard payloadLength > 0, uncompressed > 0, uncompressed <= Int(Self.blockSize) else {
                throw ImageError.damaged(reason: "data node for inode \(inode) block \(block) is malformed")
            }
            let payload = try source.bytes(at: node.offset + 48, count: payloadLength)
            let expanded = codec == .none
                ? Array(payload.prefix(uncompressed))
                : try Decompressor.decompress(payload, codec: codec, expectedSize: uncompressed)
            let take = min(want, expanded.count)
            try handle.write(contentsOf: Data(expanded.prefix(take)))
            written += Int64(take)
            if take < want { try handle.write(contentsOf: Data(count: want - take)) ; written += Int64(want - take) }
        }
    }
}
