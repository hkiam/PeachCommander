// SPDX-License-Identifier: Apache-2.0
// CramFSDriver.swift — cramfs (Compressed ROM File System), read-only.
//
// The oldest of the formats here and the simplest: a superblock, then inodes and
// their names packed end to end, then zlib-compressed 4 KB blocks. It predates
// SquashFS and has no fragments, no xattrs and no extended inodes. It is still worth
// reading because it is still out there — long-lived embedded devices and older
// bootloaders ship cramfs root filesystems, and those are exactly the images someone
// reaches for a firmware browser to look inside.
//
// Two things make it fiddlier than its size suggests.
//
// **Bitfields.** An inode is three 32-bit words carrying seven fields at
// non-byte-aligned widths (mode 16, uid 16, size 24, gid 8, namelen 6, offset 26).
// They are C bitfields, so how they sit inside the word depends on the endianness of
// the machine `mkfs.cramfs` targeted — not just the byte order of the word, but which
// end the fields are packed from. Both layouts are handled explicitly.
//
// **Big-endian images are real.** `mkfs.cramfs -N big` produces images for MIPS and
// PowerPC devices, and plenty of firmware contains them. A reader that assumes
// little-endian does not fail on one; it reads a plausible-looking superblock with
// absurd numbers in it. The magic is checked in both orders and the order that
// matches decides how everything else is read.

import Foundation

final class CramFSDriver: ImageFilesystemDriver {
    static let id = "cramfs"

    private let reader: ImageReader
    private let isBigEndian: Bool
    private(set) var entries: [ImageEntry] = []
    private(set) var droppedNames = 0
    /// Where each regular file's data starts, by entry index, with its size.
    private var fileData: [Int: (offset: Int64, size: Int64)] = [:]

    var formatDescription: String {
        "cramfs\(isBigEndian ? " (big-endian)" : ""), \(entries.count) entries"
    }

    private static let magic: UInt32 = 0x28CD_3D45
    /// cramfs compresses in fixed 4 KB blocks — a page on the platforms it was
    /// written for. Not configurable, unlike every later format here.
    private static let blockSize: Int64 = 4096

    static func probe(_ reader: ImageReader) -> Bool {
        if let le = try? reader.u32le(at: 0), le == magic { return true }
        if let be = try? reader.u32be(at: 0), be == magic { return true }
        return false
    }

    init(reader: ImageReader) throws {
        self.reader = reader
        if let le = try? reader.u32le(at: 0), le == Self.magic {
            self.isBigEndian = false
        } else if let be = try? reader.u32be(at: 0), be == Self.magic {
            self.isBigEndian = true
        } else {
            throw ImageError.notThisFormat
        }

        // The superblock records the whole image size; a file shorter than that is a
        // truncated image and every offset in it is a promise the file cannot keep.
        let declaredSize = Int64(try word(at: 4))
        guard declaredSize > 0, declaredSize <= reader.size else {
            throw ImageError.damaged(
                reason: "the superblock claims \(declaredSize) bytes, the image is \(reader.size)")
        }

        var collector = EntryCollector()
        // The root inode sits at offset 64, inline in the superblock.
        let root = try readInode(at: 64)
        guard root.isDirectory else { throw ImageError.damaged(reason: "the root inode is not a directory") }
        try walkDirectory(root, path: "", depth: 0, collector: &collector)
        entries = collector.entries
        droppedNames = collector.droppedNames
    }

    private func word(at offset: Int64) throws -> UInt32 {
        isBigEndian ? try reader.u32be(at: offset) : try reader.u32le(at: offset)
    }

    // MARK: - Inodes

    private struct Inode {
        let mode: UInt16
        let size: Int64
        /// Byte offset of this inode's payload — file data, or the first child inode
        /// for a directory. Zero for anything with no payload.
        let payloadOffset: Int64
        let nameLength: Int
        /// Where the name begins: immediately after the 12-byte inode.
        let nameOffset: Int64
        /// Offset just past this inode and its name — where the next one starts.
        let end: Int64

        var isDirectory: Bool { mode & 0xF000 == 0x4000 }
        var isRegularFile: Bool { mode & 0xF000 == 0x8000 }
        var isSymlink: Bool { mode & 0xF000 == 0xA000 }
    }

    /// Read the 12-byte inode at `offset`.
    ///
    /// The three words hold seven bitfields. On a little-endian target the compiler
    /// packs them from the least significant bit up; on a big-endian target, from the
    /// most significant bit down. So it is not enough to byte-swap the word — the
    /// shifts and masks are mirrored too, which is the part that is easy to get wrong
    /// and produces sizes in the gigabytes rather than an obvious failure.
    private func readInode(at offset: Int64) throws -> Inode {
        let w0 = try word(at: offset)
        let w1 = try word(at: offset + 4)
        let w2 = try word(at: offset + 8)

        let mode: UInt16, size: Int64, nameLengthUnits: Int, offsetUnits: Int64
        if isBigEndian {
            mode            = UInt16(truncatingIfNeeded: w0 >> 16)
            size            = Int64(w1 >> 8)
            nameLengthUnits = Int(w2 >> 26)
            offsetUnits     = Int64(w2 & 0x03FF_FFFF)
        } else {
            mode            = UInt16(truncatingIfNeeded: w0 & 0xFFFF)
            size            = Int64(w1 & 0x00FF_FFFF)
            nameLengthUnits = Int(w2 & 0x3F)
            offsetUnits     = Int64(w2 >> 6)
        }

        // Both counts are in 4-byte units — that is how 26 bits address a 256 MB image.
        let nameLength = nameLengthUnits * 4
        guard size >= 0, size <= ImageLimits.maxEntrySize else {
            throw ImageError.limitExceeded(limit: "maxEntrySize (\(ImageLimits.maxEntrySize))")
        }
        return Inode(mode: mode, size: size,
                     payloadOffset: offsetUnits * 4,
                     nameLength: nameLength,
                     nameOffset: offset + 12,
                     end: offset + 12 + Int64(nameLength))
    }

    /// An inode's name. Names are padded with NULs to a 4-byte boundary, so the
    /// padding has to come off — keeping it would put NULs into a path that then
    /// crosses a C ABI, where the first one truncates the rest of the name away.
    private func name(of inode: Inode) throws -> String {
        guard inode.nameLength > 0 else { return "" }
        let raw = try reader.bytes(at: inode.nameOffset, count: inode.nameLength)
        let end = raw.firstIndex(of: 0) ?? raw.count
        return String(decoding: raw[0..<end], as: UTF8.self)
    }

    // MARK: - Tree walk

    /// A directory's `size` is the total byte length of its children's inodes and
    /// names, laid end to end starting at `payloadOffset`.
    private func walkDirectory(_ directory: Inode, path: String, depth: Int,
                               collector: inout EntryCollector) throws {
        try EntryCollector.checkDepth(depth)
        guard directory.size > 0 else { return }
        let start = directory.payloadOffset
        let end = start + directory.size
        guard reader.contains(offset: start, count: Int(directory.size)) else {
            throw ImageError.damaged(
                reason: "directory at \(path.isEmpty ? "/" : path) runs past the end of the image")
        }

        var subdirectories: [(inode: Inode, path: String)] = []
        var cursor = start
        while cursor < end {
            let child = try readInode(at: cursor)
            // Every child must move the cursor forward, or a zero-length record turns
            // this into an endless loop over the same twelve bytes.
            guard child.end > cursor, child.end <= end else {
                throw ImageError.damaged(reason: "directory record at \(cursor) does not advance")
            }
            defer { cursor = child.end }

            let leaf = try name(of: child)
            guard let childPath = EntryPath.make(parent: path, component: leaf) else {
                collector.dropName()
                continue
            }
            try append(child, path: childPath, collector: &collector, subdirectories: &subdirectories)
        }

        for child in subdirectories {
            try walkDirectory(child.inode, path: child.path, depth: depth + 1, collector: &collector)
        }
    }

    private func append(_ inode: Inode, path: String, collector: inout EntryCollector,
                        subdirectories: inout [(inode: Inode, path: String)]) throws {
        let index = collector.entries.count
        if inode.isDirectory {
            try collector.add(ImageEntry(path: path, size: -1, mtime: 0, kind: .directory,
                                         mode: UInt32(inode.mode), locator: UInt64(inode.payloadOffset)))
            subdirectories.append((inode, path))
        } else if inode.isSymlink {
            let target = String(decoding: try contents(of: inode), as: UTF8.self)
            try collector.add(ImageEntry(path: path, size: inode.size, mtime: 0,
                                         kind: .symlink(target: target), mode: UInt32(inode.mode),
                                         locator: UInt64(inode.payloadOffset)))
        } else if inode.isRegularFile {
            try collector.add(ImageEntry(path: path, size: inode.size, mtime: 0, kind: .file,
                                         mode: UInt32(inode.mode), locator: UInt64(inode.payloadOffset)))
            fileData[index] = (inode.payloadOffset, inode.size)
        } else {
            // Device nodes, FIFOs and sockets: `size` holds the device number rather
            // than a length, so it is not reported as one.
            try collector.add(ImageEntry(path: path, size: -1, mtime: 0, kind: .special,
                                         mode: UInt32(inode.mode), locator: 0))
        }
        // cramfs records no timestamps at all — the format has no field for them. The
        // host shows the epoch, which is honest: there is nothing to show.
    }

    // MARK: - Data

    /// Decompress a file's blocks.
    ///
    /// The layout is an array of `blocks` 32-bit *end* offsets, then the compressed
    /// data. Block i runs from where block i-1 ended to where block i ends, with the
    /// first starting just after the pointer array. Every block decompresses to 4 KB
    /// except the last, which holds the remainder.
    private func contents(of inode: Inode) throws -> [UInt8] {
        guard inode.size > 0 else { return [] }
        let blockCount = Int((inode.size + Self.blockSize - 1) / Self.blockSize)
        guard blockCount <= 1 << 20 else {
            throw ImageError.limitExceeded(limit: "block count (\(blockCount))")
        }
        var pointers: [Int64] = []
        pointers.reserveCapacity(blockCount)
        for index in 0..<blockCount {
            pointers.append(Int64(try word(at: inode.payloadOffset + Int64(index) * 4)))
        }

        var out: [UInt8] = []
        out.reserveCapacity(Int(inode.size))
        var blockStart = inode.payloadOffset + Int64(blockCount) * 4
        for (index, blockEnd) in pointers.enumerated() {
            guard blockEnd >= blockStart else {
                throw ImageError.damaged(reason: "block \(index) ends at \(blockEnd), before it starts")
            }
            let compressedSize = Int(blockEnd - blockStart)
            let expanded = Int(min(Self.blockSize, inode.size - Int64(out.count)))
            let raw = try reader.bytes(at: blockStart, count: compressedSize)
            out.append(contentsOf: try Decompressor.decompress(raw, codec: .zlib, expectedSize: expanded))
            blockStart = blockEnd
        }
        guard Int64(out.count) == inode.size else {
            throw ImageError.damaged(reason: "decoded \(out.count) bytes, the inode says \(inode.size)")
        }
        return out
    }

    func extract(at index: Int, to handle: FileHandle) throws {
        guard entries.indices.contains(index), let data = fileData[index] else {
            throw ImageError.damaged(reason: "no file data for entry \(index)")
        }
        let inode = Inode(mode: 0x8000, size: data.size, payloadOffset: data.offset,
                          nameLength: 0, nameOffset: 0, end: 0)
        try handle.write(contentsOf: Data(try contents(of: inode)))
    }
}
