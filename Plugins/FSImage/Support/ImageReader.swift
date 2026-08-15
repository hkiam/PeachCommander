// SPDX-License-Identifier: Apache-2.0
// ImageReader.swift — bounds-checked random access to a filesystem image.
//
// Every driver in this plugin reads its image through here and nowhere else. A
// firmware image is untrusted input: its own header fields decide where the next
// read lands, so an offset or length taken from the image must never be used to
// index memory without being checked against the file first. Doing that check in
// one place is the whole point of this type — a driver cannot forget it, because
// there is no unchecked accessor to reach for.
//
// `pread` rather than `mmap` deliberately. mmap would be faster for the random
// access that metadata parsing does, but a mapped file that is truncated or
// rewritten underneath the process raises SIGBUS on the next touch, which takes
// the app down rather than failing the read. Images live on removable media and
// get re-flashed in place while a panel still has them open. Drivers read their
// metadata tables once at open and cache them, so the difference does not show.

import Foundation

/// Why reading or parsing an image failed. Mapped to PC_E_* codes by the caller.
enum ImageError: Error, Equatable {
    /// A read ran past the end of the image, or an offset/length was negative.
    /// `offset`/`count` are what was asked for, for diagnostics.
    case outOfBounds(offset: Int64, count: Int)
    case cannotOpen(String)
    case readFailed(errno: Int32)
    /// The image is not the format this driver claims (bad magic, impossible superblock).
    case notThisFormat
    /// The format is recognised but this build cannot read it — an unsupported
    /// compressor, a future revision. `reason` is shown to the user, so it says
    /// what is missing rather than "corrupt".
    case unsupported(reason: String)
    /// The image is this format, and it is damaged.
    case damaged(reason: String)
    /// A structural limit was hit (entry count, recursion depth, decompressed size).
    /// See `ImageLimits` — these guard against images built to exhaust memory.
    case limitExceeded(limit: String)
}

/// Bounds-checked random access to a run of bytes.
///
/// Exists because one driver needs both backings. An uncompressed initramfs is
/// parsed straight out of the file, while a gzip/xz one has to be decompressed
/// into memory first — and the parser should not care which it got, or the second
/// case becomes a duplicate of the first with its bounds checks rewritten.
protocol ByteSource: AnyObject {
    /// Total length in bytes.
    var count: Int64 { get }
    func contains(offset: Int64, count: Int) -> Bool
    func bytes(at offset: Int64, count: Int) throws -> [UInt8]
    /// Copy a run straight to `handle` in bounded chunks, without materialising it.
    func copy(at offset: Int64, count: Int64, to handle: FileHandle) throws
}

/// A `ByteSource` over bytes already in memory — a decompressed stream.
final class MemoryByteSource: ByteSource {
    private let storage: [UInt8]
    var count: Int64 { Int64(storage.count) }

    init(_ storage: [UInt8]) { self.storage = storage }

    func contains(offset: Int64, count: Int) -> Bool {
        guard offset >= 0, count >= 0, offset <= self.count else { return false }
        return Int64(count) <= self.count - offset
    }

    func bytes(at offset: Int64, count: Int) throws -> [UInt8] {
        guard contains(offset: offset, count: count) else {
            throw ImageError.outOfBounds(offset: offset, count: count)
        }
        let start = Int(offset)
        return Array(storage[start..<(start + count)])
    }

    func copy(at offset: Int64, count: Int64, to handle: FileHandle) throws {
        var remaining = count
        var cursor = offset
        while remaining > 0 {
            let chunk = Int(min(remaining, Int64(ImageLimits.copyChunkSize)))
            try handle.write(contentsOf: bytes(at: cursor, count: chunk))
            remaining -= Int64(chunk)
            cursor += Int64(chunk)
        }
    }
}

/// Read-only random access to an image file, checked against its real length.
final class ImageReader: ByteSource {
    /// Length of the image in bytes. Every read is checked against this.
    let size: Int64
    var count: Int64 { size }
    let path: String
    private let fd: Int32

    /// Byte offset in the file that this reader's offset 0 refers to.
    ///
    /// Non-zero for a partition: the whole point is that a driver written for a bare
    /// image needs no idea it is looking at a slice of a larger disk. Every read adds
    /// this, and `size` is the window's length, so the existing bounds checks confine a
    /// partition's driver to its own partition for free.
    private let base: Int64

    /// The whole file.
    convenience init(path: String) throws {
        try self.init(path: path, windowOffset: 0, windowLength: nil)
    }

    /// A window into the file, for reading one partition of a disk image.
    init(path: String, windowOffset: Int64, windowLength: Int64?) throws {
        self.path = path
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { throw ImageError.cannotOpen(path) }
        var st = stat()
        guard fstat(fd, &st) == 0 else {
            close(fd)
            throw ImageError.cannotOpen(path)
        }
        let fileSize = Int64(st.st_size)
        guard windowOffset >= 0, windowOffset <= fileSize else {
            close(fd)
            throw ImageError.damaged(reason: "window starts at \(windowOffset), file is \(fileSize) bytes")
        }
        self.fd = fd
        self.base = windowOffset
        // A partition may claim more than the image actually holds — a truncated dump is
        // the usual reason — so the window is clamped to what is there rather than
        // trusted. Reads past the end then fail as out-of-bounds, which is the truth.
        self.size = min(windowLength ?? (fileSize - windowOffset), fileSize - windowOffset)
    }

    deinit { close(fd) }

    /// Whether `count` bytes at `offset` lie inside the image. Public so a driver
    /// can probe a candidate offset without provoking an error it has to catch.
    func contains(offset: Int64, count: Int) -> Bool {
        guard offset >= 0, count >= 0 else { return false }
        // Int64 addition cannot overflow here: offset <= size and count <= Int32.max
        // are both enforced before this is reached, but the check is written so that
        // it holds even if a caller passes a value straight out of an image header.
        guard count <= Int.max, offset <= size else { return false }
        return Int64(count) <= size - offset
    }

    /// `count` bytes at `offset`, or `.outOfBounds`.
    func bytes(at offset: Int64, count: Int) throws -> [UInt8] {
        guard contains(offset: offset, count: count) else {
            throw ImageError.outOfBounds(offset: offset, count: count)
        }
        guard count > 0 else { return [] }
        var buffer = [UInt8](repeating: 0, count: count)
        var done = 0
        while done < count {
            let n = buffer.withUnsafeMutableBytes { raw -> Int in
                guard let destination = raw.baseAddress else { return -1 }
                // `base` is what makes a partition transparent: the caller's offset 0 is
                // the partition's first byte, not the disk's.
                return pread(fd, destination.advanced(by: done), count - done,
                             off_t(self.base + offset) + off_t(done))
            }
            if n < 0 {
                if errno == EINTR { continue }
                throw ImageError.readFailed(errno: errno)
            }
            // A short read inside a region we already know is within st_size means
            // the file shrank under us. That is a damaged read, not a clean EOF.
            if n == 0 { throw ImageError.outOfBounds(offset: offset, count: count) }
            done += n
        }
        return buffer
    }

    /// Copy `count` bytes at `offset` straight into `handle` in bounded chunks,
    /// so extracting a large file never holds the whole file in memory.
    func copy(at offset: Int64, count: Int64, to handle: FileHandle) throws {
        guard contains(offset: offset, count: Int(clamping: count)) else {
            throw ImageError.outOfBounds(offset: offset, count: Int(clamping: count))
        }
        var remaining = count
        var cursor = offset
        while remaining > 0 {
            let chunk = Int(min(remaining, Int64(ImageLimits.copyChunkSize)))
            let data = try bytes(at: cursor, count: chunk)
            try handle.write(contentsOf: data)
            remaining -= Int64(chunk)
            cursor += Int64(chunk)
        }
    }

    // MARK: - Integers
    //
    // Filesystem headers are little-endian on the platforms that matter, but not
    // all: JFFS2 and cramfs images from big-endian MIPS/PowerPC devices are real
    // and turn up in firmware. Each accessor names its endianness so a driver can
    // read both without a mode flag that could be wrong for one field.

    func u8(at offset: Int64) throws -> UInt8 {
        try bytes(at: offset, count: 1)[0]
    }

    func u16le(at offset: Int64) throws -> UInt16 { try le(at: offset, count: 2, as: UInt16.self) }
    func u32le(at offset: Int64) throws -> UInt32 { try le(at: offset, count: 4, as: UInt32.self) }
    func u64le(at offset: Int64) throws -> UInt64 { try le(at: offset, count: 8, as: UInt64.self) }
    func u16be(at offset: Int64) throws -> UInt16 { try be(at: offset, count: 2, as: UInt16.self) }
    func u32be(at offset: Int64) throws -> UInt32 { try be(at: offset, count: 4, as: UInt32.self) }
    func u64be(at offset: Int64) throws -> UInt64 { try be(at: offset, count: 8, as: UInt64.self) }

    private func le<T: FixedWidthInteger & UnsignedInteger>(at offset: Int64, count: Int, as _: T.Type) throws -> T {
        let raw = try bytes(at: offset, count: count)
        var value: T = 0
        for i in stride(from: count - 1, through: 0, by: -1) {
            value = (value << 8) | T(raw[i])
        }
        return value
    }

    private func be<T: FixedWidthInteger & UnsignedInteger>(at offset: Int64, count: Int, as _: T.Type) throws -> T {
        let raw = try bytes(at: offset, count: count)
        var value: T = 0
        for i in 0..<count {
            value = (value << 8) | T(raw[i])
        }
        return value
    }

    /// A NUL-terminated (or `maxLength`-bounded) name from the image, decoded as
    /// UTF-8 with a lossy fallback. Linux filenames are bytes, not text: a name
    /// that is not valid UTF-8 is legal on disk and must still be listable, so
    /// invalid sequences become U+FFFD rather than dropping the entry.
    func name(at offset: Int64, maxLength: Int) throws -> String {
        let raw = try bytes(at: offset, count: maxLength)
        let end = raw.firstIndex(of: 0) ?? raw.count
        return String(decoding: raw[0..<end], as: UTF8.self)
    }
}

/// Structural ceilings applied to every driver.
///
/// These are not tuning knobs. An image is an attacker-controlled description of
/// a tree, and each of these numbers is the point past which believing it costs
/// more than refusing it: a directory that claims to hold four billion children,
/// an extent tree that points at itself, a 40-byte block that decompresses to a
/// gigabyte. Hitting one is `.limitExceeded`, which the user sees as a refusal
/// naming the limit — not a hang and not a crash.
enum ImageLimits {
    /// Entries in one image. Above this the host's own in-memory tree
    /// (`PCXArchiveFS` holds a node per entry) is the next thing to fall over.
    static let maxEntries = 2_000_000
    /// Nesting depth for directories, extent/B-tree walks and symlink chains.
    static let maxDepth = 128
    /// Bytes one entry may decompress to. Larger real files exist; larger
    /// *claims* from a 4 KB image do not.
    static let maxEntrySize: Int64 = 64 << 30
    /// Output ceiling for a single compressed block — the decompression-bomb guard.
    static let maxBlockSize = 16 << 20
    /// Chunk used when copying image bytes to a destination file.
    static let copyChunkSize = 1 << 20
    /// Ceiling for an image that must be decompressed into memory before it can be
    /// parsed — a compressed initramfs, which is one stream with no seekable index.
    /// Real ones are a few tens of MB; this is generous enough not to refuse a
    /// legitimate one and small enough that a bomb cannot exhaust the app.
    static let maxInMemoryImage = 1 << 29   // 512 MB
}
