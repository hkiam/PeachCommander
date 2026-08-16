// SPDX-License-Identifier: Apache-2.0
// JFFS2Driver.swift — JFFS2 (Journalling Flash File System 2), read-only.
//
// Unlike every other format here, JFFS2 has no superblock, no inode table and no
// directory tree on disk. It is a **log**: a flat sequence of nodes written wherever
// the flash had room, each carrying a version number. A file's current contents are
// whatever remains after replaying every node that mentions it, newest version
// winning; a directory entry exists if its newest dirent still points at an inode.
// Reading one therefore means scanning the entire image and reconstructing the
// filesystem, which is what the kernel does at mount time too.
//
// That shape drives three things this driver has to get right:
//
//   * **Resynchronising.** Erased flash reads as 0xFF, and a node can begin at any
//     4-byte boundary after a gap. So the scan hunts for a 2-byte magic — which hits
//     by coincidence inside file data constantly. The header CRC is what separates a
//     node from a coincidence, and without checking it the scan invents nodes out of
//     file contents.
//   * **Both byte orders.** JFFS2 images from big-endian MIPS and PowerPC devices are
//     common in firmware. The magic decides which, and everything follows from that.
//   * **NAND dumps are not JFFS2 images.** A raw dump off NAND has out-of-band ECC
//     bytes interleaved every 512 or 2048 bytes, so the nodes are chopped up by data
//     that is not part of the filesystem. That is refused with an explanation rather
//     than reported as corruption, because the user needs to know to strip the OOB
//     data, not that their image is broken.

import Foundation

final class JFFS2Driver: ImageFilesystemDriver {
    static let id = "jffs2"

    private let reader: ImageReader
    private let isBigEndian: Bool
    private(set) var entries: [ImageEntry] = []
    private(set) var droppedNames = 0
    /// The inode each entry resolves to, so extraction can replay that inode's nodes.
    private var inodeForEntry: [Int: UInt32] = [:]
    /// Data nodes per inode, in the order found; replayed by version at extraction.
    private var dataNodes: [UInt32: [DataNode]] = [:]
    private var nodeCount = 0

    var formatDescription: String {
        "JFFS2\(isBigEndian ? " (big-endian)" : ""), \(nodeCount) nodes"
    }

    private static let magic: UInt16 = 0x1985
    /// Node types, with their feature bits as the format stores them.
    private enum NodeType {
        static let dirent: UInt16 = 0xE001
        static let inode: UInt16 = 0xE002
        static let cleanmarker: UInt16 = 0x2003
        static let padding: UInt16 = 0x2004
        static let summary: UInt16 = 0x2006
    }

    static func probe(_ reader: ImageReader) -> Bool {
        // A JFFS2 image starts with a node — usually a cleanmarker — at offset 0.
        // Some dumps begin with erased flash, so a short run of 0xFF is tolerated
        // before giving up; scanning the whole file here would make probing a foreign
        // 4 GB file expensive.
        guard let head = try? reader.bytes(at: 0, count: min(4096, Int(reader.size))) else { return false }
        var offset = 0
        while offset + 4 <= head.count {
            let le = UInt16(head[offset]) | UInt16(head[offset + 1]) << 8
            let be = UInt16(head[offset]) << 8 | UInt16(head[offset + 1])
            if le == magic || be == magic { return true }
            guard head[offset] == 0xFF, head[offset + 1] == 0xFF else { return false }
            offset += 4
        }
        return false
    }

    /// Magic plus node type, in both byte orders.
    ///
    /// The magic alone is two bytes, which occurs by chance roughly every 64 KB of
    /// arbitrary data — far too often to scan a whole image for. Pairing it with the
    /// three node types that can legitimately open a filesystem makes the pattern four
    /// bytes, and the CRC check inside the driver rejects whatever still gets through.
    static let carveSignatures: [CarveSignature] = [
        CarveSignature([0x85, 0x19, 0x03, 0x20], at: 0),   // cleanmarker, little-endian
        CarveSignature([0x85, 0x19, 0x01, 0xE0], at: 0),   // dirent
        CarveSignature([0x85, 0x19, 0x02, 0xE0], at: 0),   // inode
        CarveSignature([0x19, 0x85, 0x20, 0x03], at: 0),   // and the same three big-endian
        CarveSignature([0x19, 0x85, 0xE0, 0x01], at: 0),
        CarveSignature([0x19, 0x85, 0xE0, 0x02], at: 0),
    ]

    init(reader: ImageReader) throws {
        self.reader = reader
        guard let head = try? reader.bytes(at: 0, count: min(4096, Int(reader.size))) else {
            throw ImageError.notThisFormat
        }
        var probeOffset = 0
        var bigEndian: Bool?
        while probeOffset + 4 <= head.count {
            let le = UInt16(head[probeOffset]) | UInt16(head[probeOffset + 1]) << 8
            let be = UInt16(head[probeOffset]) << 8 | UInt16(head[probeOffset + 1])
            if le == Self.magic { bigEndian = false; break }
            if be == Self.magic { bigEndian = true; break }
            guard head[probeOffset] == 0xFF, head[probeOffset + 1] == 0xFF else { break }
            probeOffset += 4
        }
        guard let bigEndian else { throw ImageError.notThisFormat }
        self.isBigEndian = bigEndian
        try scanAndBuild()
    }

    // MARK: - Node records

    private struct Dirent {
        let parentInode: UInt32
        let version: UInt32
        let inode: UInt32     // 0 means the entry was deleted
        let mtime: Int64
        let name: String
    }

    private struct DataNode {
        let version: UInt32
        /// Where this node's bytes go in the file.
        let fileOffset: Int64
        let compressedSize: Int
        let uncompressedSize: Int
        let compression: UInt8
        /// Where the payload sits in the image.
        let dataOffset: Int64
    }

    private struct InodeState {
        var version: UInt32 = 0
        var size: Int64 = 0
        var mode: UInt32 = 0
        var mtime: Int64 = 0
    }

    // MARK: - Scan

    private func u16(_ raw: [UInt8], _ offset: Int) -> UInt16 {
        isBigEndian ? UInt16(raw[offset]) << 8 | UInt16(raw[offset + 1])
                    : UInt16(raw[offset]) | UInt16(raw[offset + 1]) << 8
    }
    private func u32(_ raw: [UInt8], _ offset: Int) -> UInt32 {
        if isBigEndian {
            return UInt32(raw[offset]) << 24 | UInt32(raw[offset + 1]) << 16
                 | UInt32(raw[offset + 2]) << 8 | UInt32(raw[offset + 3])
        }
        return UInt32(raw[offset]) | UInt32(raw[offset + 1]) << 8
             | UInt32(raw[offset + 2]) << 16 | UInt32(raw[offset + 3]) << 24
    }

    /// Walk every node in the image, collecting dirents and data nodes.
    ///
    /// The image is read once into memory. JFFS2 images are flash images — megabytes,
    /// not gigabytes — and the scan touches nearly all of it anyway, so streaming it
    /// would buy nothing and cost a read syscall per node.
    private func scanAndBuild() throws {
        guard reader.size <= Int64(ImageLimits.maxInMemoryImage) else {
            throw ImageError.limitExceeded(limit: "maxInMemoryImage (\(ImageLimits.maxInMemoryImage))")
        }
        let raw = try reader.bytes(at: 0, count: Int(reader.size))

        var dirents: [Dirent] = []
        var inodes: [UInt32: InodeState] = [:]
        var offset = 0
        var badPayloads = 0
        var totalPayloads = 0

        while offset + 12 <= raw.count {
            guard u16(raw, offset) == Self.magic, isHeaderValid(raw, at: offset) else {
                offset += 4
                continue
            }
            let nodeType = u16(raw, offset + 2)
            let totalLength = Int(u32(raw, offset + 4))
            // A node shorter than its own header, or one running past the image, is
            // where a corrupt scan would otherwise loop or read out of bounds.
            guard totalLength >= 12, offset + totalLength <= raw.count else {
                offset += 4
                continue
            }
            nodeCount += 1

            switch nodeType {
            case NodeType.dirent:
                try readDirent(raw, at: offset, totalLength: totalLength, into: &dirents)
            case NodeType.inode:
                try readInode(raw, at: offset, totalLength: totalLength, into: &inodes,
                              badPayloads: &badPayloads, totalPayloads: &totalPayloads)
            case NodeType.cleanmarker, NodeType.padding, NodeType.summary:
                break   // structural, no filesystem content
            default:
                break   // xattr/xref and anything newer: skipped, not fatal
            }
            offset += (totalLength + 3) & ~3
        }

        guard nodeCount > 0 else {
            throw ImageError.damaged(reason: "no JFFS2 nodes found in the image")
        }
        try rejectIfPayloadsFailTheirChecksums(badPayloads: badPayloads, totalPayloads: totalPayloads)
        try buildTree(dirents: dirents, inodes: inodes)
    }

    /// The header CRC covers the first 8 bytes: magic, node type and total length.
    private func isHeaderValid(_ raw: [UInt8], at offset: Int) -> Bool {
        guard offset + 12 <= raw.count else { return false }
        let stored = u32(raw, offset + 8)
        return JFFS2Compression.crc32(raw[offset..<(offset + 8)]) == stored
    }

    /// Refuse an image whose node payloads do not match their own checksums.
    ///
    /// The first attempt at this counted how often the scan had to resynchronise, on
    /// the theory that an out-of-band-interleaved NAND dump would break constantly.
    /// It does not: the scan hunts for magic and finds every node anyway, so the
    /// count was identical for a clean image and a dump with 64 spare bytes after
    /// every page. What actually differs is the *data* CRC — the spare bytes land in
    /// the middle of node payloads, and those nodes then fail their own checksum
    /// while everything else reads fine.
    ///
    /// So this is a data-integrity check that happens to diagnose the common cause,
    /// rather than a heuristic pretending to recognise a layout. Refusing matters
    /// more than the diagnosis: using a payload that fails its checksum would put
    /// wrong bytes into a file the user then treats as the firmware's contents.
    private func rejectIfPayloadsFailTheirChecksums(badPayloads: Int, totalPayloads: Int) throws {
        guard badPayloads > 0 else { return }
        throw ImageError.damaged(
            reason: "\(badPayloads) of \(totalPayloads) data nodes fail their own CRC. The usual "
                  + "cause is a raw NAND dump that still has its out-of-band (ECC) area "
                  + "interleaved — re-dump it with `nanddump --omitoob`. Otherwise the image is "
                  + "damaged.")
    }

    private func readDirent(_ raw: [UInt8], at offset: Int, totalLength: Int,
                            into dirents: inout [Dirent]) throws {
        guard offset + 40 <= raw.count else { return }
        let nameSize = Int(raw[offset + 28])
        guard nameSize > 0, offset + 40 + nameSize <= raw.count, 40 + nameSize <= totalLength else { return }
        // `node_crc` covers the first 32 bytes: everything before it and `name_crc`.
        guard JFFS2Compression.crc32(raw[offset..<(offset + 32)]) == u32(raw, offset + 32) else { return }
        let nameBytes = raw[(offset + 40)..<(offset + 40 + nameSize)]
        dirents.append(Dirent(parentInode: u32(raw, offset + 12),
                              version: u32(raw, offset + 16),
                              inode: u32(raw, offset + 20),
                              mtime: Int64(u32(raw, offset + 24)),
                              name: String(decoding: nameBytes, as: UTF8.self)))
    }

    private func readInode(_ raw: [UInt8], at offset: Int, totalLength: Int,
                           into inodes: inout [UInt32: InodeState],
                           badPayloads: inout Int, totalPayloads: inout Int) throws {
        guard offset + 68 <= raw.count else { return }
        // `node_crc` covers the first 60 bytes — the header up to but excluding
        // `data_crc` and `node_crc` themselves. Not 64: that reading rejects every
        // inode in a perfectly good image, which is how the length was pinned down.
        guard JFFS2Compression.crc32(raw[offset..<(offset + 60)]) == u32(raw, offset + 64) else { return }

        let inode = u32(raw, offset + 12)
        let version = u32(raw, offset + 16)
        let compressedSize = Int(u32(raw, offset + 48))
        let uncompressedSize = Int(u32(raw, offset + 52))
        guard 68 + compressedSize <= totalLength, offset + 68 + compressedSize <= raw.count else { return }

        if compressedSize > 0 {
            totalPayloads += 1
            let payload = raw[(offset + 68)..<(offset + 68 + compressedSize)]
            if JFFS2Compression.crc32(payload) != u32(raw, offset + 60) { badPayloads += 1 }
        }

        // Highest version wins for the metadata: size, mode and time are whatever the
        // newest node that mentioned this inode said they were.
        var state = inodes[inode] ?? InodeState()
        if version >= state.version {
            state.version = version
            state.size = Int64(u32(raw, offset + 28))
            state.mode = u32(raw, offset + 20)
            state.mtime = Int64(u32(raw, offset + 36))
            inodes[inode] = state
        } else {
            inodes[inode] = state
        }

        guard uncompressedSize > 0 else { return }   // a metadata-only node carries no data
        dataNodes[inode, default: []].append(DataNode(
            version: version,
            fileOffset: Int64(u32(raw, offset + 44)),
            compressedSize: compressedSize,
            uncompressedSize: uncompressedSize,
            compression: raw[offset + 56],
            dataOffset: Int64(offset + 68)))
    }

    // MARK: - Reconstruct the tree

    /// JFFS2's root directory is always inode 1.
    private static let rootInode: UInt32 = 1

    private func buildTree(dirents: [Dirent], inodes: [UInt32: InodeState]) throws {
        // One surviving entry per (parent, name): the highest version wins, and if
        // that one points at inode 0 the name was deleted and no entry survives. This
        // is the whole reason a log-structured filesystem needs replaying rather than
        // reading — an older, still-present dirent for a deleted file is normal.
        var surviving: [UInt32: [String: Dirent]] = [:]
        for dirent in dirents {
            let existing = surviving[dirent.parentInode]?[dirent.name]
            if existing == nil || dirent.version > existing!.version {
                surviving[dirent.parentInode, default: [:]][dirent.name] = dirent
            }
        }

        var collector = EntryCollector()
        var visited: Set<UInt32> = []
        try walk(parent: Self.rootInode, path: "", depth: 0, surviving: surviving,
                 inodes: inodes, visited: &visited, collector: &collector)
        entries = collector.entries
        droppedNames = collector.droppedNames
    }

    private func walk(parent: UInt32, path: String, depth: Int,
                      surviving: [UInt32: [String: Dirent]], inodes: [UInt32: InodeState],
                      visited: inout Set<UInt32>, collector: inout EntryCollector) throws {
        try EntryCollector.checkDepth(depth)
        guard visited.insert(parent).inserted else {
            throw ImageError.damaged(reason: "directory cycle at \(path.isEmpty ? "/" : path)")
        }
        defer { visited.remove(parent) }
        guard let children = surviving[parent] else { return }

        var subdirectories: [(inode: UInt32, path: String)] = []
        for name in children.keys.sorted() {
            guard let dirent = children[name], dirent.inode != 0 else { continue }   // deleted
            guard let childPath = EntryPath.make(parent: path, component: name) else {
                collector.dropName()
                continue
            }
            let state = inodes[dirent.inode] ?? InodeState()
            let format = state.mode & 0xF000
            let index = collector.entries.count
            let mtime = state.mtime != 0 ? state.mtime : dirent.mtime

            switch format {
            case 0x4000:
                try collector.add(ImageEntry(path: childPath, size: -1, mtime: mtime,
                                             kind: .directory, mode: state.mode,
                                             locator: UInt64(dirent.inode)))
                subdirectories.append((dirent.inode, childPath))
            case 0xA000:
                // A symlink's target is its file content, so it has to be assembled
                // like any other file rather than read from a field.
                let target = String(decoding: try assemble(inode: dirent.inode, size: state.size),
                                    as: UTF8.self)
                try collector.add(ImageEntry(path: childPath, size: state.size, mtime: mtime,
                                             kind: .symlink(target: target), mode: state.mode,
                                             locator: UInt64(dirent.inode)))
            case 0x8000:
                try collector.add(ImageEntry(path: childPath, size: state.size, mtime: mtime,
                                             kind: .file, mode: state.mode,
                                             locator: UInt64(dirent.inode)))
                inodeForEntry[index] = dirent.inode
            default:
                try collector.add(ImageEntry(path: childPath, size: -1, mtime: mtime,
                                             kind: .special, mode: state.mode,
                                             locator: UInt64(dirent.inode)))
            }
        }

        for child in subdirectories {
            try walk(parent: child.inode, path: child.path, depth: depth + 1, surviving: surviving,
                     inodes: inodes, visited: &visited, collector: &collector)
        }
    }

    // MARK: - Assembling file contents

    /// Replay an inode's data nodes into its current contents.
    ///
    /// Applied in version order, each node overwriting the range it covers. Later
    /// writes to the same offset are exactly how a log-structured filesystem records
    /// an edit, so "last version wins per byte" is the file, not an optimisation.
    /// Anything no node covers is a hole and reads as zeros.
    private func assemble(inode: UInt32, size: Int64) throws -> [UInt8] {
        guard size > 0 else { return [] }
        guard size <= Int64(ImageLimits.maxInMemoryImage) else {
            throw ImageError.limitExceeded(limit: "maxInMemoryImage (\(ImageLimits.maxInMemoryImage))")
        }
        var out = [UInt8](repeating: 0, count: Int(size))
        let nodes = (dataNodes[inode] ?? []).sorted { $0.version < $1.version }

        for node in nodes {
            guard let kind = JFFS2Compression.Kind(rawValue: node.compression) else {
                throw ImageError.unsupported(reason: "unknown JFFS2 compressor id \(node.compression)")
            }
            let compressed = try reader.bytes(at: node.dataOffset, count: node.compressedSize)
            let expanded = try JFFS2Compression.decompress(compressed, kind: kind,
                                                          expectedSize: node.uncompressedSize)
            // A node may describe bytes past the file's current size: an earlier,
            // larger version of a file that was later truncated leaves its nodes
            // behind. Those are clipped rather than treated as an error.
            guard node.fileOffset < size else { continue }
            let count = min(expanded.count, Int(size - node.fileOffset))
            guard count > 0 else { continue }
            let start = Int(node.fileOffset)
            out.replaceSubrange(start..<(start + count), with: expanded[0..<count])
        }
        return out
    }

    func extract(at index: Int, to handle: FileHandle) throws {
        guard entries.indices.contains(index), let inode = inodeForEntry[index] else {
            throw ImageError.damaged(reason: "no file data for entry \(index)")
        }
        try handle.write(contentsOf: Data(try assemble(inode: inode, size: entries[index].size)))
    }
}
