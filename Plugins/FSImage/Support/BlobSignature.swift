// SPDX-License-Identifier: Apache-2.0
// BlobSignature.swift — naming the parts of a firmware image that are not filesystems.
//
// A router image is mostly not filesystems. Ahead of the rootfs there is a vendor
// header, a bootloader and a kernel, and those three are usually the reason somebody
// opened the file. They cannot be browsed — they are not directories — but they can be
// *named* and copied out, and a name is most of the value: "kernel.uimage at 0x40000,
// 2.1 MB" answers the question this plugin is being asked, while "1.9 MB of unknown
// data" does not.
//
// The list is deliberately short. binwalk carries hundreds of vendor signatures and a
// person to maintain them; that is its job, not this one. What is here is the handful
// that appear in nearly every embedded image, each recognised by a magic long enough
// not to fire on ordinary data. Everything else stays honestly unnamed.
//
// Where a header records its own length, that length is read. It is what separates one
// blob from the next in a file that has no table of contents, and it is why a uImage
// followed by padding does not swallow the padding.

import Foundation

/// A named, non-filesystem region of an image.
struct IdentifiedBlob {
    /// Filename stem for the listing, with an extension that suggests what to do with
    /// it — `uboot.elf` opens in a disassembler, `kernel.uimage` in `dumpimage`.
    let name: String
    /// One line for the layout report, carrying whatever the header revealed.
    let description: String
    /// Total length including the header, when the header records one.
    let length: Int64?
}

enum BlobSignature {
    /// The magics worth *searching* for, as opposed to merely checking at a known
    /// boundary.
    ///
    /// Only the structured headers are here — the ones that carry enough of their own
    /// shape to be validated once found. A kernel behind a vendor header of unknown
    /// length is the ordinary layout, so these have to be findable anywhere in a run.
    ///
    /// The bare compressed streams are deliberately absent. `1f 8b 08` occurs about
    /// once per sixteen megabytes of arbitrary data and far more often than that inside
    /// data that is already compressed, which is most of a firmware image; searching for
    /// it would chop a bootloader into invented pieces. Those magics are still honoured
    /// where a region begins, which is where a real payload boundary is.
    static let scanPatterns: [[UInt8]] = [
        [0x27, 0x05, 0x19, 0x56],       // U-Boot legacy image
        [0xD0, 0x0D, 0xFE, 0xED],       // flattened device tree
        Array("ANDROID!".utf8),
        Array("HDR0".utf8),             // Broadcom TRX
        [0x7F, 0x45, 0x4C, 0x46],       // ELF
    ]

    /// Identify whatever begins at `offset`, or nil if nothing here is recognised.
    ///
    /// Cheap by construction: reads one 64-byte header and compares prefixes. Called
    /// once per gap in a layout scan, not per byte.
    static func identify(_ reader: ImageReader, at offset: Int64) -> IdentifiedBlob? {
        let available = reader.count - offset
        guard available >= 8 else { return nil }
        guard let head = try? reader.bytes(at: offset, count: Int(min(64, available))) else {
            return nil
        }

        if starts(head, with: [0x27, 0x05, 0x19, 0x56]) { return uImage(reader, at: offset, head) }
        if starts(head, with: [0xD0, 0x0D, 0xFE, 0xED]) { return deviceTree(reader, at: offset) }
        if starts(head, with: Array("ANDROID!".utf8)) { return androidBoot(reader, at: offset) }
        if starts(head, with: Array("HDR0".utf8)) { return trx(reader, at: offset) }
        if starts(head, with: [0x7F, 0x45, 0x4C, 0x46]) {
            // The class byte distinguishes 32- from 64-bit, which on an embedded image
            // tells you which architecture family you are looking at.
            let bits = head.count > 4 && head[4] == 2 ? 64 : 32
            return IdentifiedBlob(name: "binary.elf",
                                  description: "ELF \(bits)-bit executable", length: nil)
        }
        return compressedStream(head)
    }

    /// A U-Boot legacy image: the wrapper almost every non-UEFI embedded kernel ships in.
    private static func uImage(_ reader: ImageReader, at offset: Int64,
                               _ head: [UInt8]) -> IdentifiedBlob {
        // Every field is big-endian regardless of the target's own byte order — the
        // header is defined that way so the bootloader can read it before it knows.
        let dataSize = head.count >= 16 ? Int64(be32(head, 12)) : 0
        let type = head.count >= 31 ? head[30] : 0
        let compression = head.count >= 32 ? head[31] : 0
        // ih_name: 32 bytes, NUL-padded, and usually the only human-written string in
        // the whole image ("Linux-5.10.0-rt").
        var label = ""
        if head.count >= 64 {
            let raw = Array(head[32..<64])
            label = printable(raw[0..<(raw.firstIndex(of: 0) ?? raw.count)])
        }

        let kind = uImageType(type)
        let squeeze = uImageCompression(compression)
        var description = "U-Boot \(kind)"
        if squeeze != "none" { description += ", \(squeeze)" }
        if !label.isEmpty { description += " — \(label)" }

        // 64 bytes of header, then the payload. Trust it only as far as the file goes.
        let total = 64 + dataSize
        let sane = dataSize > 0 && total <= reader.count - offset
        return IdentifiedBlob(name: kind == "kernel" ? "kernel.uimage" : "\(kind).uimage",
                              description: description, length: sane ? total : nil)
    }

    private static func uImageType(_ value: UInt8) -> String {
        switch value {
        case 2: return "kernel"
        case 3: return "ramdisk"
        case 5: return "firmware"
        case 7: return "flat-dt"
        case 8: return "kernel"        // kernel_noload
        default: return "image"
        }
    }

    private static func uImageCompression(_ value: UInt8) -> String {
        switch value {
        case 1: return "gzip"
        case 2: return "bzip2"
        case 3: return "lzma"
        case 4: return "lzo"
        case 5: return "lz4"
        case 6: return "zstd"
        default: return "none"
        }
    }

    /// A flattened device tree — the hardware description, and often the fastest way to
    /// learn what board an image belongs to.
    private static func deviceTree(_ reader: ImageReader, at offset: Int64) -> IdentifiedBlob {
        let total = (try? reader.u32be(at: offset + 4)).map(Int64.init)
        let sane = (total ?? 0) > 0 && (total ?? 0) <= reader.count - offset
        return IdentifiedBlob(name: "device-tree.dtb", description: "flattened device tree",
                              length: sane ? total : nil)
    }

    /// An Android boot image: header page, then kernel, ramdisk and second stage, each
    /// padded up to a page. The sizes are all in the header, so the total is exact.
    private static func androidBoot(_ reader: ImageReader, at offset: Int64) -> IdentifiedBlob {
        guard let pageSize = try? reader.u32le(at: offset + 36), pageSize >= 512,
              pageSize <= 65536, pageSize.nonzeroBitCount == 1,
              let kernel = try? reader.u32le(at: offset + 8),
              let ramdisk = try? reader.u32le(at: offset + 16),
              let second = try? reader.u32le(at: offset + 24) else {
            return IdentifiedBlob(name: "boot.img", description: "Android boot image", length: nil)
        }
        let page = Int64(pageSize)
        let rounded = { (size: UInt32) -> Int64 in (Int64(size) + page - 1) / page * page }
        let total = page + rounded(kernel) + rounded(ramdisk) + rounded(second)
        let sane = total > 0 && total <= reader.count - offset
        return IdentifiedBlob(name: "boot.img", description: "Android boot image",
                              length: sane ? total : nil)
    }

    /// Broadcom's TRX container, the outermost wrapper on a very large share of consumer
    /// router firmware — which is exactly the file this whole scan exists for.
    private static func trx(_ reader: ImageReader, at offset: Int64) -> IdentifiedBlob {
        let total = (try? reader.u32le(at: offset + 4)).map(Int64.init)
        let sane = (total ?? 0) > 0 && (total ?? 0) <= reader.count - offset
        return IdentifiedBlob(name: "firmware.trx", description: "TRX firmware container",
                              length: sane ? total : nil)
    }

    /// A bare compressed stream. None of these frame their own total length in a way
    /// that can be read without decompressing, so the extent is left to the caller —
    /// which reports it as running to whatever comes next.
    private static func compressedStream(_ head: [UInt8]) -> IdentifiedBlob? {
        if starts(head, with: [0x1F, 0x8B, 0x08]) {
            return IdentifiedBlob(name: "data.gz", description: "gzip stream", length: nil)
        }
        if starts(head, with: [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]) {
            return IdentifiedBlob(name: "data.xz", description: "xz stream", length: nil)
        }
        if starts(head, with: [0x28, 0xB5, 0x2F, 0xFD]) {
            return IdentifiedBlob(name: "data.zst", description: "zstd stream", length: nil)
        }
        if starts(head, with: [0x04, 0x22, 0x4D, 0x18]) {
            return IdentifiedBlob(name: "data.lz4", description: "lz4 frame", length: nil)
        }
        // "BZh" then the block-size digit 1-9, which is what separates it from the many
        // other things that begin with two upper-case letters.
        if starts(head, with: Array("BZh".utf8)), head.count > 3, (0x31...0x39).contains(head[3]) {
            return IdentifiedBlob(name: "data.bz2", description: "bzip2 stream", length: nil)
        }
        return nil
    }

    /// A name field out of an image, or "" if it does not read as text.
    ///
    /// The only place in this plugin where bytes from an image become part of a document
    /// the user keeps, so it is the only place that needs this. A uImage's name field is
    /// 32 bytes with no obligation to be text at all: a header the scan found at a chance
    /// offset has 32 random bytes there, and a real image with a truncated build script
    /// has half a string and half whatever was in the buffer. Either way the bytes end up
    /// in a report somebody pastes into a ticket, so control characters and invalid UTF-8
    /// must not survive the trip.
    ///
    /// Rejected wholesale rather than repaired: a name that is not text is not a name, and
    /// a scrubbed version of one is worse than none — it looks like a finding.
    private static func printable(_ bytes: ArraySlice<UInt8>) -> String {
        guard !bytes.isEmpty, bytes.count <= 32 else { return "" }
        // Decoded strictly: a lossy decode would turn each bad byte into U+FFFD and
        // produce exactly the row of replacement characters this exists to prevent.
        guard let text = String(bytes: bytes, encoding: .utf8) else { return "" }
        guard text.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }) else {
            return ""
        }
        return text
    }

    private static func starts(_ bytes: [UInt8], with prefix: [UInt8]) -> Bool {
        bytes.count >= prefix.count && Array(bytes[0..<prefix.count]) == prefix
    }

    private static func be32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
    }
}
