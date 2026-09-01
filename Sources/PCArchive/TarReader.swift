// SPDX-License-Identifier: Apache-2.0
// TarReader.swift - Read-only tar / tar.gz backend for ArchiveFS (native browse).
//
// Parses a POSIX ustar / GNU tar stream into members. A gzip-wrapped stream
// (.tar.gz / .tgz, magic 1f 8b) is inflated whole first: the gzip payload is
// raw DEFLATE, reused via ZipReader.inflate, sized from the gzip ISIZE trailer.
// Only reading is supported; the archive is never mutated.

import Foundation

/// A read-only `ArchiveSource` over a (optionally gzip-compressed) tar archive.
public final class TarReader: ArchiveSource {
    /// The uncompressed tar bytes; member data are slices of this.
    private let tar: Data
    public let members: [ArchiveMember]
    /// Byte range of each member's file data within `tar`, parallel to `members`.
    private let ranges: [Range<Int>]

    /// How much this reader is willing to materialise (F-463).
    ///
    /// A gzip-wrapped tar has to be inflated whole before any member can be read, so
    /// the compressed size on disk says almost nothing about the cost: 200 MB of
    /// tar.gz is routinely 2 GB of tar. A background walk that meets a folder of build
    /// artefacts needs a ceiling on the *expanded* size; a keypress does not, because
    /// somebody asked for that one archive and is waiting for it.
    public struct Limits: Sendable, Equatable {
        /// Largest uncompressed payload to inflate. 0 means no ceiling.
        public var maxExpandedBytes: Int64
        public init(maxExpandedBytes: Int64 = 0) { self.maxExpandedBytes = maxExpandedBytes }
        public static let unlimited = Limits()
    }

    /// Parses `fileURL` as tar or tar.gz. Returns `nil` if it is not a readable
    /// tar stream (no valid ustar header found).
    public convenience init?(fileURL: URL) {
        self.init(fileURL: fileURL, limits: .unlimited)
    }

    /// Parses `fileURL`, refusing a gzip payload larger than `limits` allows.
    ///
    /// Refused *before* inflating, not after: the declared size is what `inflate`
    /// preallocates, so checking it first is the difference between declining to open
    /// an archive and allocating a gigabyte to discover we should have declined.
    public init?(fileURL: URL, limits: Limits) {
        // Mapped, not read. `parse` decides from the first 512-byte block, so for a plain
        // tar only the header pages are ever touched — O(members) instead of O(bytes) —
        // and a `.xz`/`.zst`/`.7z` handed here by `ArchiveFS`'s reader ordering is now
        // rejected after one page instead of after reading the whole file into memory.
        guard let raw = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]) else { return nil }
        let tar: Data
        if Self.isGzip(raw) {
            if limits.maxExpandedBytes > 0,
               let declared = Self.declaredExpandedSize(raw),
               declared > limits.maxExpandedBytes { return nil }
            guard let inflated = Self.gunzip(raw) else { return nil }
            tar = inflated
        } else {
            tar = raw
        }
        guard let (members, ranges) = Self.parse(tar) else { return nil }
        self.tar = tar
        self.members = members
        self.ranges = ranges
    }

    /// The inflated tar, held for the reader's lifetime so members can be sliced out of it.
    public var retainedBytes: Int64 { Int64(tar.count) }

    public func data(atIndex index: Int, password: String?) throws -> Data {
        guard ranges.indices.contains(index) else { return Data() }
        let r = ranges[index]
        guard r.lowerBound <= r.upperBound, r.upperBound <= tar.count else { return Data() }
        return tar.subdata(in: r)
    }

    /// A member is a range of `tar`, so reading it in pieces is slicing in pieces (F-479).
    ///
    /// Worth having even though the tar itself is already in hand: a plain `.tar` is *mapped*, so
    /// the pieces come from the file rather than from a copy of the member, and either way the
    /// caller no longer has to hold the whole member to read the first byte of it.
    public func reader(atIndex index: Int, password: String?) throws -> ArchiveMemberReader? {
        guard ranges.indices.contains(index) else { return nil }
        let r = ranges[index]
        guard r.lowerBound <= r.upperBound, r.upperBound <= tar.count else { return nil }
        return TarMemberReader(tar: tar, range: r)
    }

    // MARK: - gzip

    /// The uncompressed size a gzip stream claims in its 4-byte ISIZE trailer.
    ///
    /// Exact up to 4 GiB; beyond that it wraps, which is why a value smaller than the
    /// compressed payload of a large file is not to be believed. Both cases end the
    /// same way — the archive is not opened — but for a stated reason.
    static func declaredExpandedSize(_ d: Data) -> Int64? {
        let n = d.count
        guard n > 18 else { return nil }
        func byte(_ i: Int) -> UInt8 { d[d.startIndex + i] }
        let isize = Int64(byte(n - 4)) | (Int64(byte(n - 3)) << 8)
                  | (Int64(byte(n - 2)) << 16) | (Int64(byte(n - 1)) << 24)
        return isize > 0 ? isize : nil
    }

    private static func isGzip(_ d: Data) -> Bool {
        d.count > 18 && d[d.startIndex] == 0x1f && d[d.startIndex + 1] == 0x8b
    }

    /// Strips the gzip header/trailer and raw-inflates the DEFLATE payload,
    /// sizing the output from the 4-byte ISIZE trailer (exact for archives up to
    /// 4 GiB uncompressed; larger ones wrap and are unsupported here).
    private static func gunzip(_ d: Data) -> Data? {
        // Indexed through `d` rather than through a `[UInt8](d)` copy: that copy was a
        // second full-size duplicate of the compressed file, made only to read a dozen
        // header bytes, and it landed on top of the inflated output.
        let n = d.count
        func byte(_ i: Int) -> UInt8 { d[d.startIndex + i] }
        guard n > 18, byte(0) == 0x1f, byte(1) == 0x8b, byte(2) == 8 else { return nil }
        let flg = byte(3)
        var idx = 10
        if flg & 0x04 != 0 {                       // FEXTRA
            guard idx + 2 <= n else { return nil }
            let xlen = Int(byte(idx)) | (Int(byte(idx + 1)) << 8)
            idx += 2 + xlen
        }
        if flg & 0x08 != 0 {                       // FNAME (NUL-terminated)
            while idx < n, byte(idx) != 0 { idx += 1 }
            idx += 1
        }
        if flg & 0x10 != 0 {                       // FCOMMENT (NUL-terminated)
            while idx < n, byte(idx) != 0 { idx += 1 }
            idx += 1
        }
        if flg & 0x02 != 0 { idx += 2 }            // FHCRC
        guard idx <= n - 8 else { return nil }
        let isize = Int(byte(n - 4)) | (Int(byte(n - 3)) << 8)
                  | (Int(byte(n - 2)) << 16) | (Int(byte(n - 1)) << 24)
        // ISIZE is what `inflate` preallocates, so a nonsense value is refused before
        // anything is allocated rather than after. Above 4 GiB it wraps — documented as
        // unsupported — and a wrapped value now fails here instead of part-way through.
        guard isize > 0 else { return nil }
        let payload = d.subdata(in: (d.startIndex + idx)..<(d.startIndex + n - 8))
        return try? ZipReader.inflate(payload, expectedSize: isize)
    }

    // MARK: - tar

    private static let blockSize = 512

    /// Parses ustar/GNU headers into members + data ranges. Returns nil if the
    /// first non-empty block is not a valid header (so callers can fall through
    /// to other formats).
    private static func parse(_ tar: Data) -> (members: [ArchiveMember], ranges: [Range<Int>])? {
        var members: [ArchiveMember] = []
        var ranges: [Range<Int>] = []
        var offset = tar.startIndex
        let end = tar.endIndex
        var pendingLongName: String?     // GNU 'L' long name for the next header
        var pendingPaxPath: String?      // pax 'x'/'g' path= override for the next header
        var sawValidHeader = false

        var blocksSeen = 0
        while offset + blockSize <= end {
            // Reading the headers of a 200,000-member tar takes long enough that a user
            // who pressed Cancel deserves to be heard. This runs synchronously on the
            // task that started the search, so its cancellation is visible right here —
            // no flag has to be threaded down through the reader to find out.
            blocksSeen += 1
            if blocksSeen % 1024 == 0, Task.isCancelled { return nil }
            let block = tar.subdata(in: offset..<(offset + blockSize))
            // Two consecutive all-zero blocks mark end-of-archive; a single zero
            // block also effectively terminates a well-formed stream.
            if block.allSatisfy({ $0 == 0 }) { break }

            guard Self.isUstarOrGNU(block) || sawValidHeader == false && Self.looksLikeHeader(block) else {
                // Not a header where one is expected — bail unless we already have
                // valid members (trailing garbage tolerated).
                if sawValidHeader { break }
                return nil
            }

            let size = octal(block, at: 124, len: 12)
            let typeflag = block[block.startIndex + 156]
            let dataStart = offset + blockSize
            let paddedSize = ((size + blockSize - 1) / blockSize) * blockSize
            let dataEnd = min(dataStart + size, end)

            switch typeflag {
            case 0x4C:  // 'L' — GNU long name: this block's data is the next entry's name
                pendingLongName = string(tar, in: dataStart..<min(dataStart + size, end))
                offset = dataStart + paddedSize
                sawValidHeader = true
                continue
            case 0x78, 0x67:  // 'x' / 'g' — pax extended header: parse a path= record
                pendingPaxPath = paxPath(tar, in: dataStart..<min(dataStart + size, end))
                offset = dataStart + paddedSize
                sawValidHeader = true
                continue
            default:
                break
            }

            sawValidHeader = true
            var name = pendingPaxPath ?? pendingLongName ?? ustarName(block)
            pendingLongName = nil
            pendingPaxPath = nil
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
            guard !name.isEmpty else {
                offset = dataStart + paddedSize
                continue
            }

            let isDir = typeflag == 0x35 /* '5' */ || name.hasSuffix("/")
            let mtime = octal(block, at: 136, len: 12)
            let modified = mtime > 0 ? Date(timeIntervalSince1970: TimeInterval(mtime)) : nil
            // Normalize like ZipReader: no leading "/" or "./", directories keep
            // a trailing "/". `tar -C dir .` prefixes members with "./".
            var normalized = name
            while normalized.hasPrefix("/") { normalized.removeFirst() }
            while normalized.hasPrefix("./") { normalized.removeFirst(2) }
            // The archive's own "." root entry carries no member.
            if normalized == "." || normalized == "./" { normalized = "" }
            guard !normalized.isEmpty else {
                offset = dataStart + paddedSize
                continue
            }
            if isDir, !normalized.hasSuffix("/") { normalized += "/" }

            members.append(ArchiveMember(path: normalized,
                                         uncompressedSize: isDir ? -1 : Int64(size),
                                         isDirectory: isDir, modified: modified))
            ranges.append(dataStart..<dataEnd)
            offset = dataStart + paddedSize
        }

        return sawValidHeader ? (members, ranges) : nil
    }

    /// ustar magic "ustar" at offset 257 (POSIX) or "ustar  " (GNU).
    private static func isUstarOrGNU(_ block: Data) -> Bool {
        let s = block.startIndex + 257
        guard block.count >= 263 else { return false }
        return block[s] == 0x75 && block[s + 1] == 0x73 && block[s + 2] == 0x74
            && block[s + 3] == 0x61 && block[s + 4] == 0x72
    }

    /// Fallback heuristic for old-style (v7) tar with no ustar magic: a plausible
    /// header has a NUL/space-terminated octal size field and a nonzero name byte.
    private static func looksLikeHeader(_ block: Data) -> Bool {
        guard block[block.startIndex] != 0 else { return false }
        // Size field at 124 must be octal digits then NUL/space.
        for i in 124..<135 {
            let c = block[block.startIndex + i]
            if !(c == 0x20 || c == 0 || (c >= 0x30 && c <= 0x37)) { return false }
        }
        return true
    }

    /// ustar name = prefix (offset 345, 155) + "/" + name (offset 0, 100).
    private static func ustarName(_ block: Data) -> String {
        let name = string(block, in: (block.startIndex)..<(block.startIndex + 100))
        let prefix = isUstarOrGNU(block)
            ? string(block, in: (block.startIndex + 345)..<(block.startIndex + 500))
            : ""
        let p = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        let n = name.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        return p.isEmpty ? n : "\(p)/\(n)"
    }

    /// Reads a NUL-trimmed string from a byte range of `data`.
    private static func string(_ data: Data, in range: Range<Int>) -> String {
        let clamped = range.clamped(to: data.startIndex..<data.endIndex)
        guard !clamped.isEmpty else { return "" }
        let sub = data.subdata(in: clamped)
        let trimmed = sub.prefix { $0 != 0 }
        return String(decoding: trimmed, as: UTF8.self)
    }

    /// Parses a numeric field as octal (tar stores sizes/mtime as ASCII octal).
    private static func octal(_ block: Data, at fieldOffset: Int, len: Int) -> Int {
        let start = block.startIndex + fieldOffset
        var value = 0
        for i in 0..<len {
            let c = block[start + i]
            if c == 0 || c == 0x20 { if value == 0 { continue } else { break } }
            guard c >= 0x30 && c <= 0x37 else { break }
            value = value * 8 + Int(c - 0x30)
        }
        return value
    }

    /// Extracts the `path=` record from a pax extended header body
    /// ("<len> path=<value>\n"), if present.
    private static func paxPath(_ tar: Data, in range: Range<Int>) -> String? {
        let clamped = range.clamped(to: tar.startIndex..<tar.endIndex)
        guard !clamped.isEmpty else { return nil }
        let text = String(decoding: tar.subdata(in: clamped), as: UTF8.self)
        for record in text.split(separator: "\n") {
            // "<length> key=value"
            guard let space = record.firstIndex(of: " ") else { continue }
            let kv = record[record.index(after: space)...]
            if kv.hasPrefix("path=") { return String(kv.dropFirst("path=".count)) }
        }
        return nil
    }
}

/// Slices of the tar the reader already holds.
private final class TarMemberReader: ArchiveMemberReader {
    private let tar: Data
    private var offset: Int
    private let end: Int

    init(tar: Data, range: Range<Int>) {
        self.tar = tar
        self.offset = range.lowerBound
        self.end = range.upperBound
    }

    func next(maxBytes: Int) throws -> Data? {
        guard offset < end else { return nil }
        let stop = Swift.min(offset + Swift.max(1, maxBytes), end)
        defer { offset = stop }
        return tar.subdata(in: offset..<stop)
    }
}
