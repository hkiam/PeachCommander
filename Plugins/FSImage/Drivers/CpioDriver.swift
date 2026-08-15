// SPDX-License-Identifier: Apache-2.0
// CpioDriver.swift — initramfs / initrd images (cpio "newc"), optionally compressed.
//
// This is what "ramfs" means as a file. ramfs itself has no on-disk format — it is
// a mount of the page cache — so the thing on disk that holds an early userspace is
// an initramfs: a cpio archive in the SVR4 "newc" variant, usually wrapped in one
// compression stream (gzip, xz, lz4 or zstd), which the kernel unpacks into a
// tmpfs at boot.
//
// The format is deliberately trivial: a 110-byte ASCII header of 8-digit hex
// fields, the NUL-terminated name padded to a 4-byte boundary, then the file data
// padded the same way, repeated until an entry named "TRAILER!!!". Being trivial is
// exactly why this driver came first — it exercises the whole chain (probe, parse,
// entry sanitising, extraction, and the decompressor layer for the wrapped case)
// against archives produced by a third-party tool rather than by this plugin.
//
// Two real-world wrinkles are handled and worth naming:
//
//   * Concatenated archives. Boot images routinely staple several cpio archives
//     together — CPU microcode first, then the real initramfs — separated by NUL
//     padding. Stopping at the first TRAILER!!! would show the user the microcode
//     blob and hide the filesystem they were looking for. So the parse skips
//     padding after a trailer and continues if another header follows.
//   * Hardlinks. newc gives every link the same inode and stores the data with the
//     last one, the earlier ones having filesize 0. They are listed as the separate
//     files they are; a zero-length listing for the earlier links would be wrong,
//     so the data is resolved through the inode.

import Foundation

final class CpioDriver: ImageFilesystemDriver {
    static let id = "cpio"

    private let source: ByteSource
    private(set) var entries: [ImageEntry] = []
    private(set) var droppedNames = 0
    let formatDescription: String

    /// Where an entry's data lives in `source`, by entry index. Kept out of
    /// `ImageEntry` because `locator` is a single UInt64 and this needs a length too.
    private var dataRange: [Int: (offset: Int64, length: Int64)] = [:]

    // MARK: - Probe

    /// The newc magic, at offset 0 or behind a compression wrapper.
    ///
    /// A compressed image cannot be confirmed from its magic alone — gzip is gzip,
    /// whether it wraps a cpio or a tarball. So a compressed candidate is accepted
    /// here only tentatively and `init` decides for real, which is the one place a
    /// probe is allowed to be optimistic: a wrong guess costs a failed open and the
    /// host moves on to its own readers.
    static func probe(_ reader: ImageReader) -> Bool {
        guard let header = try? reader.bytes(at: 0, count: min(8, Int(reader.size))) else { return false }
        if isNewcMagic(header) { return true }
        return Decompressor.detectStreamCodec(header) != .none
    }

    private static func isNewcMagic(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 6 else { return false }
        // "070701" (newc) and "070702" (newc with CRC) are the two the kernel accepts.
        // The older "070707" (odc) and the binary variants are not initramfs formats.
        return bytes[0] == 0x30 && bytes[1] == 0x37 && bytes[2] == 0x30 && bytes[3] == 0x37
            && bytes[4] == 0x30 && (bytes[5] == 0x31 || bytes[5] == 0x32)
    }

    // MARK: - Parse

    init(reader: ImageReader) throws {
        let header = try reader.bytes(at: 0, count: min(8, Int(reader.size)))
        if Self.isNewcMagic(header) {
            // Uncompressed: parse straight out of the file, so a large initramfs
            // never has to be held in memory.
            self.source = reader
            self.formatDescription = "initramfs (cpio newc)"
        } else {
            let codec = Decompressor.detectStreamCodec(header)
            guard codec != .none else { throw ImageError.notThisFormat }
            guard reader.size <= Int64(ImageLimits.maxInMemoryImage) else {
                throw ImageError.limitExceeded(limit: "maxInMemoryImage (\(ImageLimits.maxInMemoryImage))")
            }
            let compressed = try reader.bytes(at: 0, count: Int(reader.size))
            let expanded = try Decompressor.decompressStream(compressed, codec: codec)
            // Decompressing succeeded, but that only proves it was a valid stream of
            // that codec — not that a cpio came out. This is where a gzipped tarball
            // is turned away, and it must be `.notThisFormat` so the host still falls
            // back rather than reporting a broken archive.
            guard Self.isNewcMagic(Array(expanded.prefix(8))) else { throw ImageError.notThisFormat }
            self.source = MemoryByteSource(expanded)
            self.formatDescription = "initramfs (cpio newc, \(codec.rawValue))"
        }
        try parse()
    }

    /// newc header layout: a 6-byte magic then 13 fields of 8 ASCII hex digits each.
    private struct Header {
        let ino: UInt64
        let mode: UInt32
        let mtime: Int64
        let fileSize: Int64
        let nameSize: Int
        /// Total header + name length, rounded up to the 4-byte boundary the data starts on.
        let dataOffset: Int64
    }

    private static let headerLength: Int64 = 110

    private func parse() throws {
        var collector = EntryCollector()
        var offset: Int64 = 0
        /// Whether a TRAILER!!! record has been seen. An archive that simply stops —
        /// no trailer, no padding, just an end — is truncated, and reporting the
        /// entries that happened to survive would present a partial tree as a whole
        /// one. That is the worst outcome available here: someone auditing firmware
        /// concludes a file is absent when it is only unread.
        var sawTrailer = false
        /// Data location per inode, so a hardlink whose own record carries no bytes
        /// still extracts the content its earlier or later twin holds.
        var dataByInode: [UInt64: (offset: Int64, length: Int64)] = [:]
        /// Entries still waiting for their inode's data to show up.
        var pendingLinks: [(index: Int, ino: UInt64)] = []

        while offset < source.count {
            guard let header = try readHeader(at: offset) else {
                // Not a header here. After a trailer this is the NUL padding between
                // concatenated archives, so step over it and look again; if nothing
                // follows, we are simply done.
                guard let next = try skipPadding(from: offset), next > offset else { break }
                offset = next
                continue
            }
            let nameOffset = offset + Self.headerLength
            let rawName = try source.bytes(at: nameOffset, count: header.nameSize)
            let name = String(decoding: rawName.prefix(while: { $0 != 0 }), as: UTF8.self)

            if name == "TRAILER!!!" {
                // End of this archive. Another may be stapled on after the padding.
                // `next > offset` is the loop's own progress invariant: every path
                // through this body either advances the cursor or leaves. Nothing
                // downstream may rely on the callee to guarantee that.
                sawTrailer = true
                guard let next = try skipPadding(from: offset + header.dataOffset),
                      next > offset else { break }
                sawTrailer = false   // another archive follows; it needs its own trailer
                offset = next
                continue
            }

            let dataStart = offset + header.dataOffset
            try appendEntry(header: header, name: name, dataStart: dataStart,
                            collector: &collector, dataByInode: &dataByInode,
                            pendingLinks: &pendingLinks)
            offset = dataStart + align4(header.fileSize)
        }

        guard sawTrailer else {
            throw ImageError.damaged(
                reason: "the archive ends after \(collector.entries.count) entries with no TRAILER!!! record"
                      + " — the image is truncated")
        }

        // Resolve hardlinks whose data-carrying twin appeared after them.
        for link in pendingLinks {
            guard let data = dataByInode[link.ino] else { continue }
            dataRange[link.index] = data
        }

        entries = collector.entries
        droppedNames = collector.droppedNames
    }

    private func appendEntry(header: Header, name: String, dataStart: Int64,
                             collector: inout EntryCollector,
                             dataByInode: inout [UInt64: (offset: Int64, length: Int64)],
                             pendingLinks: inout [(index: Int, ino: UInt64)]) throws {
        guard let path = Self.entryPath(from: name) else {
            // "." is the archive root, not an entry — skipping it is normal and is
            // not a dropped name.
            if name != "." && name != "./" { collector.dropName() }
            return
        }
        guard source.contains(offset: dataStart, count: Int(clamping: header.fileSize)) else {
            throw ImageError.damaged(reason: "entry \"\(path)\" claims \(header.fileSize) bytes past the end")
        }

        let format = header.mode & 0o170000
        let kind: ImageEntry.Kind
        switch format {
        case 0o040000:
            kind = .directory
        case 0o120000:
            let target = try source.bytes(at: dataStart, count: Int(header.fileSize))
            kind = .symlink(target: String(decoding: target, as: UTF8.self))
        case 0o100000:
            kind = .file
        default:
            kind = .special   // device node, FIFO, socket
        }

        let index = collector.entries.count
        try collector.add(ImageEntry(path: path,
                                     size: kind.isSized ? header.fileSize : -1,
                                     mtime: header.mtime,
                                     kind: kind,
                                     mode: header.mode,
                                     locator: header.ino))
        guard case .file = kind else { return }
        if header.fileSize > 0 {
            dataRange[index] = (dataStart, header.fileSize)
            dataByInode[header.ino] = (dataStart, header.fileSize)
        } else if let existing = dataByInode[header.ino] {
            dataRange[index] = existing                      // earlier twin held the data
        } else {
            pendingLinks.append((index, header.ino))         // a later twin may
        }
    }

    /// Normalise a cpio name ("./etc/motd") into an entry path ("etc/motd"), or nil
    /// if any component is one the host must not be handed.
    private static func entryPath(from name: String) -> String? {
        var path = ""
        for component in name.split(separator: "/", omittingEmptySubsequences: true) {
            if component == "." { continue }   // the "./" prefix every cpio name carries
            guard let next = EntryPath.make(parent: path, component: String(component)) else { return nil }
            path = next
        }
        return path.isEmpty ? nil : path
    }

    /// Read a header at `offset`, or nil if there is no newc magic there.
    ///
    /// The two ways this can come up short are not the same answer, and conflating
    /// them was a real defect: "no magic here" is the ordinary end of an archive,
    /// while "magic here but the header runs off the end of the image" is a
    /// truncated file. Returning nil for both made the caller treat a cut-off
    /// header as padding, look for the next header at the same offset, and spin
    /// there forever — a hang on exactly the damaged input this is supposed to
    /// reject. So the magic is checked first, and once it matches, anything less
    /// than a whole header is `.damaged`.
    private func readHeader(at offset: Int64) throws -> Header? {
        let magicLength = 6
        guard source.contains(offset: offset, count: magicLength) else { return nil }
        guard Self.isNewcMagic(try source.bytes(at: offset, count: magicLength)) else { return nil }
        guard source.contains(offset: offset, count: Int(Self.headerLength)) else {
            throw ImageError.damaged(reason: "header at offset \(offset) is cut off by the end of the image")
        }
        let raw = try source.bytes(at: offset, count: Int(Self.headerLength))

        func field(_ index: Int) throws -> UInt64 {
            let start = 6 + index * 8
            var value: UInt64 = 0
            for byte in raw[start..<(start + 8)] {
                guard let digit = Self.hexDigit(byte) else {
                    throw ImageError.damaged(reason: "non-hex header field at offset \(offset)")
                }
                value = value << 4 | UInt64(digit)
            }
            return value
        }

        let nameSize = try field(11)
        // 8 hex digits cap every field at 0xFFFFFFFF, so these cannot overflow Int64;
        // they can still be absurd, and a name longer than the buffer it must cross
        // is refused here rather than truncated later.
        guard nameSize > 0, nameSize <= 4096 else {
            throw ImageError.damaged(reason: "implausible name length \(nameSize) at offset \(offset)")
        }
        let fileSize = Int64(try field(6))
        return Header(ino: try field(0),
                      mode: UInt32(truncatingIfNeeded: try field(1)),
                      mtime: Int64(try field(5)),
                      fileSize: fileSize,
                      nameSize: Int(nameSize),
                      dataOffset: align4(Self.headerLength + Int64(nameSize)))
    }

    /// From `offset`, skip NUL padding to the next newc header. Returns nil when
    /// only padding (or nothing) is left — the normal end of an image.
    ///
    /// Bounded by `maxTrailingPadding` rather than scanning to the end: a corrupt
    /// image is otherwise a full linear scan of however many gigabytes it claims to
    /// be, on the main path, with the panel waiting.
    private func skipPadding(from offset: Int64) throws -> Int64? {
        let maxTrailingPadding: Int64 = 1 << 20
        var cursor = offset
        let limit = min(source.count, offset + maxTrailingPadding)
        while cursor < limit {
            guard source.contains(offset: cursor, count: 4) else { return nil }
            let probe = try source.bytes(at: cursor, count: 4)
            if probe != [0, 0, 0, 0] {
                return Self.isNewcMagic(try source.bytes(at: cursor, count: min(6, Int(source.count - cursor))))
                    ? cursor : nil
            }
            cursor += 4
        }
        return nil
    }

    private func align4(_ value: Int64) -> Int64 { (value + 3) & ~3 }

    private static func hexDigit(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 0x30...0x39: return byte - 0x30            // 0-9
        case 0x41...0x46: return byte - 0x41 + 10       // A-F
        case 0x61...0x66: return byte - 0x61 + 10       // a-f (cpio writes upper, be lenient)
        default: return nil
        }
    }

    // MARK: - Extract

    func extract(at index: Int, to handle: FileHandle) throws {
        guard entries.indices.contains(index) else {
            throw ImageError.damaged(reason: "no such entry: \(index)")
        }
        guard let range = dataRange[index] else { return }   // empty file, or a link with no data anywhere
        try source.copy(at: range.offset, count: range.length, to: handle)
    }
}

private extension ImageEntry.Kind {
    /// Whether a size should be reported. Directories and device nodes have none;
    /// showing 0 for them reads as "empty file" in a panel.
    var isSized: Bool {
        switch self {
        case .file, .symlink: return true
        case .directory, .special: return false
        }
    }
}
