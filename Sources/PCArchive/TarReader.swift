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

    /// Parses `fileURL` as tar or tar.gz. Returns `nil` if it is not a readable
    /// tar stream (no valid ustar header found).
    public init?(fileURL: URL) {
        guard let raw = try? Data(contentsOf: fileURL) else { return nil }
        let tar: Data
        if Self.isGzip(raw) {
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

    public func data(atIndex index: Int, password: String?) throws -> Data {
        guard ranges.indices.contains(index) else { return Data() }
        let r = ranges[index]
        guard r.lowerBound <= r.upperBound, r.upperBound <= tar.count else { return Data() }
        return tar.subdata(in: r)
    }

    // MARK: - gzip

    private static func isGzip(_ d: Data) -> Bool {
        d.count > 18 && d[d.startIndex] == 0x1f && d[d.startIndex + 1] == 0x8b
    }

    /// Strips the gzip header/trailer and raw-inflates the DEFLATE payload,
    /// sizing the output from the 4-byte ISIZE trailer (exact for archives up to
    /// 4 GiB uncompressed; larger ones wrap and are unsupported here).
    private static func gunzip(_ d: Data) -> Data? {
        let bytes = [UInt8](d)
        guard bytes.count > 18, bytes[0] == 0x1f, bytes[1] == 0x8b, bytes[2] == 8 else { return nil }
        let flg = bytes[3]
        var idx = 10
        if flg & 0x04 != 0 {                       // FEXTRA
            guard idx + 2 <= bytes.count else { return nil }
            let xlen = Int(bytes[idx]) | (Int(bytes[idx + 1]) << 8)
            idx += 2 + xlen
        }
        if flg & 0x08 != 0 {                       // FNAME (NUL-terminated)
            while idx < bytes.count, bytes[idx] != 0 { idx += 1 }
            idx += 1
        }
        if flg & 0x10 != 0 {                       // FCOMMENT (NUL-terminated)
            while idx < bytes.count, bytes[idx] != 0 { idx += 1 }
            idx += 1
        }
        if flg & 0x02 != 0 { idx += 2 }            // FHCRC
        let n = bytes.count
        guard idx <= n - 8 else { return nil }
        let isize = Int(bytes[n - 4]) | (Int(bytes[n - 3]) << 8)
                  | (Int(bytes[n - 2]) << 16) | (Int(bytes[n - 1]) << 24)
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

        while offset + blockSize <= end {
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
