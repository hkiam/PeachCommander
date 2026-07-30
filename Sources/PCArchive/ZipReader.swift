// SPDX-License-Identifier: Apache-2.0
// ZipReader.swift - A pure-Swift, read-only ZIP central-directory parser and
// DEFLATE/store extractor (I09).
//
// No external dependencies: parsing uses Foundation `Data` only, and
// inflation uses the system `Compression` framework (`compression_decode_buffer`
// with `COMPRESSION_ZLIB`, which despite the name implements raw DEFLATE,
// i.e. RFC 1951 with no zlib/gzip header or trailer).
//
// ZIP64 is intentionally out of scope for this MVP: sizes, counts, and
// offsets are read as plain 32-bit fields per the classic End Of Central
// Directory / central-directory-header / local-file-header layout.

import Compression
import Foundation

/// Errors raised while parsing zip metadata or inflating entry data.
public enum ZipError: Error, Sendable, Equatable {
    /// The archive's central directory (or a record within it) is malformed
    /// or truncated. The associated string is a short diagnostic, not for
    /// display to end users.
    case malformed(String)
    /// A compression method other than store (0) or deflate (8).
    case unsupportedCompression(UInt16)
    /// `compression_decode_buffer` did not produce the expected byte count.
    case inflateFailed
    /// The entry is encrypted but no password was supplied.
    case passwordRequired
    /// The supplied password failed the ZipCrypto header check.
    case wrongPassword
    /// The entry uses WinZip AES encryption, which is not yet supported.
    case encryptedAES
}

/// A single file or directory entry read from a zip's central directory.
public struct ZipEntry: Sendable {
    /// Normalized path within the zip: no leading "/", directories end with "/".
    public let path: String
    public let uncompressedSize: Int64
    public let compressedSize: Int64
    public let isDirectory: Bool
    public let modified: Date?

    /// Byte offset of this entry's local file header, used by `ZipReader.data(for:)`.
    let localHeaderOffset: UInt32
    /// Compression method from the central directory (0 = store, 8 = deflate,
    /// 99 = WinZip AES with the real method in an extra field).
    let compressionMethod: UInt16
    /// CRC-32 of the uncompressed data, from the central directory (integrity).
    let crc32: UInt32
    /// True when general-purpose bit 0 is set (the entry's data is encrypted).
    public let isEncrypted: Bool

    init(
        path: String,
        uncompressedSize: Int64,
        compressedSize: Int64,
        isDirectory: Bool,
        modified: Date?,
        localHeaderOffset: UInt32,
        compressionMethod: UInt16,
        crc32: UInt32 = 0,
        isEncrypted: Bool = false
    ) {
        self.path = path
        self.uncompressedSize = uncompressedSize
        self.compressedSize = compressedSize
        self.isDirectory = isDirectory
        self.modified = modified
        self.localHeaderOffset = localHeaderOffset
        self.compressionMethod = compressionMethod
        self.crc32 = crc32
        self.isEncrypted = isEncrypted
    }
}

extension ZipEntry: Equatable {
    /// Equality is defined over the public, user-visible fields only; the
    /// internal extraction bookkeeping (header offset, raw method code) is
    /// an implementation detail and does not participate.
    public static func == (lhs: ZipEntry, rhs: ZipEntry) -> Bool {
        lhs.path == rhs.path
            && lhs.uncompressedSize == rhs.uncompressedSize
            && lhs.compressedSize == rhs.compressedSize
            && lhs.isDirectory == rhs.isDirectory
            && lhs.modified == rhs.modified
    }
}

/// Parses a zip's central directory and extracts individual entries.
///
/// This is read-only and MVP-scoped: no ZIP64, no encryption, no multi-disk
/// archives, and filenames are decoded as UTF-8 (falling back to Latin-1)
/// rather than full IBM437/CP437 handling.
public final class ZipReader {
    private static let eocdSignature: UInt32 = 0x0605_4b50
    private static let centralDirSignature: UInt32 = 0x0201_4b50
    private static let localHeaderSignature: UInt32 = 0x0403_4b50

    private let fileData: Data

    /// All entries parsed from the central directory, in central-directory order.
    public let entries: [ZipEntry]

    /// Parses `fileURL` as a zip archive. Returns `nil` if the file cannot be
    /// read, or is not a well-formed zip (no End Of Central Directory record,
    /// or a malformed central directory).
    public init?(fileURL: URL) {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let eocdOffset = Self.findEOCD(in: data) else { return nil }
        guard let parsed = try? Self.parseCentralDirectory(data, eocdOffset: eocdOffset) else { return nil }
        self.fileData = data
        self.entries = parsed
    }

    /// Returns the decompressed bytes for `entry`. Directories yield empty
    /// data. Throws `ZipError` on malformed headers or an unsupported
    /// compression method, or `ZipError.inflateFailed` if DEFLATE inflation
    /// did not produce the expected size.
    public func data(for entry: ZipEntry, password: String? = nil) throws -> Data {
        guard !entry.isDirectory else { return Data() }

        var reader = ByteReader(data: fileData, at: Int(entry.localHeaderOffset))
        let signature = try reader.readUInt32LE()
        guard signature == Self.localHeaderSignature else {
            throw ZipError.malformed("bad local file header signature")
        }
        try reader.skip(2) // version needed to extract
        let localFlag = try reader.readUInt16LE() // general purpose bit flag (bit 3 = data descriptor)
        try reader.skip(2) // compression method (trust the central directory's copy instead)
        let localModTime = try reader.readUInt16LE() // last mod file time
        try reader.skip(2) // last mod file date
        try reader.skip(4) // crc-32
        try reader.skip(4) // compressed size (local copy)
        try reader.skip(4) // uncompressed size (local copy)
        let nameLength = try reader.readUInt16LE()
        let extraLength = try reader.readUInt16LE()
        try reader.skip(Int(nameLength))
        let extra = try reader.readBytes(Int(extraLength))

        guard entry.compressedSize >= 0, entry.compressedSize <= Int64(Int.max) else {
            throw ZipError.malformed("invalid compressed size")
        }
        var raw = try reader.readBytes(Int(entry.compressedSize))

        // Decrypt before inflating. Two schemes: classic ZipCrypto (12-byte header
        // prefix, dropped after the password check) and WinZip AES (method 99, real
        // method in the 0x9901 extra field). `effectiveMethod` is the actual
        // compression method to inflate after decryption.
        var effectiveMethod = entry.compressionMethod
        if entry.isEncrypted {
            guard let password else { throw ZipError.passwordRequired }
            if entry.compressionMethod == 99 {
                guard let aes = Self.parseAESExtra(extra) else {
                    throw ZipError.malformed("missing AES extra field")
                }
                raw = try WinZipAES.decrypt(raw, password: password, strengthCode: aes.strength)
                effectiveMethod = aes.method
            } else {
                // The header's check byte is the CRC high byte, or — when the entry
                // streams with a data descriptor (bit 3) — the mod-time high byte.
                let checkByte: UInt8 = (localFlag & 0x0008) != 0
                    ? UInt8((localModTime >> 8) & 0xff)
                    : UInt8((entry.crc32 >> 24) & 0xff)
                raw = try Self.zipCryptoDecrypt(raw, password: password, checkByte: checkByte)
            }
        }

        switch effectiveMethod {
        case 0:
            return raw
        case 8:
            return try Self.inflate(raw, expectedSize: Int(entry.uncompressedSize))
        default:
            throw ZipError.unsupportedCompression(effectiveMethod)
        }
    }

    // MARK: - Traditional ZipCrypto (PKWARE) decryption

    /// Decrypt a classic-ZipCrypto stream: derive the keystream from `password`,
    /// verify the 12-byte header's check byte against the CRC high byte, and
    /// return the decrypted compressed payload (header removed). Throws
    /// `wrongPassword` if the header check fails.
    private static func zipCryptoDecrypt(_ input: Data, password: String, checkByte: UInt8) throws -> Data {
        guard input.count >= 12 else { throw ZipError.malformed("encrypted entry too short") }
        var keys = ZipCryptoKeys(password: Array(password.utf8))
        var out = [UInt8]()
        out.reserveCapacity(input.count)
        for byte in input {
            let plain = byte ^ keys.decryptByte()
            keys.update(plain)
            out.append(plain)
        }
        guard out[11] == checkByte else { throw ZipError.wrongPassword }
        return Data(out[12...])
    }

    /// Locate the WinZip AES extra field (header id 0x9901) and return its strength
    /// code (1=128, 2=192, 3=256) and the real compression method.
    private static func parseAESExtra(_ extra: Data) -> (strength: UInt8, method: UInt16)? {
        let b = [UInt8](extra)
        var i = 0
        while i + 4 <= b.count {
            let id = UInt16(b[i]) | (UInt16(b[i + 1]) << 8)
            let size = Int(UInt16(b[i + 2]) | (UInt16(b[i + 3]) << 8))
            let dataStart = i + 4
            guard dataStart + size <= b.count else { break }
            if id == 0x9901, size >= 7 {
                let strength = b[dataStart + 4]
                let method = UInt16(b[dataStart + 5]) | (UInt16(b[dataStart + 6]) << 8)
                return (strength, method)
            }
            i = dataStart + size
        }
        return nil
    }

    /// A single integrity problem found by `verify()`.
    public struct IntegrityProblem: Sendable, Equatable {
        public let path: String
        public let reason: String
    }

    /// Decompresses every file entry and checks it against the stored size and
    /// CRC-32 (F-135). Returns an empty array when the archive is intact.
    public func verify() -> [IntegrityProblem] {
        var problems: [IntegrityProblem] = []
        for entry in entries where !entry.isDirectory {
            do {
                let data = try data(for: entry)
                if Int64(data.count) != entry.uncompressedSize {
                    problems.append(.init(path: entry.path, reason: "size mismatch"))
                } else if ZipWriter.crc32(of: data) != entry.crc32 {
                    problems.append(.init(path: entry.path, reason: "CRC mismatch"))
                }
            } catch {
                problems.append(.init(path: entry.path, reason: "\(error)"))
            }
        }
        return problems
    }

    // MARK: - End Of Central Directory

    /// Scans backwards from the end of `data` for the EOCD signature,
    /// allowing for a trailing archive comment of up to 64 KB (the maximum
    /// a 16-bit comment-length field can express).
    private static func findEOCD(in data: Data) -> Int? {
        let minSize = 22
        guard data.count >= minSize else { return nil }
        let maxCommentSize = 65_535
        let searchFloor = max(0, data.count - minSize - maxCommentSize)
        var offset = data.count - minSize
        while offset >= searchFloor {
            if data[offset] == 0x50, data[offset + 1] == 0x4b,
               data[offset + 2] == 0x05, data[offset + 3] == 0x06 {
                return offset
            }
            offset -= 1
        }
        return nil
    }

    private static func parseCentralDirectory(_ data: Data, eocdOffset: Int) throws -> [ZipEntry] {
        var eocd = ByteReader(data: data, at: eocdOffset)
        let signature = try eocd.readUInt32LE()
        guard signature == eocdSignature else { throw ZipError.malformed("bad EOCD signature") }
        try eocd.skip(2) // number of this disk
        try eocd.skip(2) // disk with the start of the central directory
        try eocd.skip(2) // entries on this disk
        let totalEntries = try eocd.readUInt16LE()
        try eocd.skip(4) // size of central directory
        let centralDirOffset = try eocd.readUInt32LE()

        var entries: [ZipEntry] = []
        entries.reserveCapacity(Int(totalEntries))
        var reader = ByteReader(data: data, at: Int(centralDirOffset))

        for _ in 0..<totalEntries {
            let entrySignature = try reader.readUInt32LE()
            guard entrySignature == centralDirSignature else {
                throw ZipError.malformed("bad central directory header signature")
            }
            try reader.skip(2) // version made by
            try reader.skip(2) // version needed to extract
            let gpFlag = try reader.readUInt16LE() // general purpose bit flag (bit 0 = encrypted)
            let method = try reader.readUInt16LE()
            let modTime = try reader.readUInt16LE()
            let modDate = try reader.readUInt16LE()
            let crc = try reader.readUInt32LE()
            let compressedSize = try reader.readUInt32LE()
            let uncompressedSize = try reader.readUInt32LE()
            let nameLength = try reader.readUInt16LE()
            let extraLength = try reader.readUInt16LE()
            let commentLength = try reader.readUInt16LE()
            try reader.skip(2) // disk number start
            try reader.skip(2) // internal file attributes
            try reader.skip(4) // external file attributes
            let localHeaderOffset = try reader.readUInt32LE()
            let nameData = try reader.readBytes(Int(nameLength))
            try reader.skip(Int(extraLength))
            try reader.skip(Int(commentLength))

            guard let rawName = String(data: nameData, encoding: .utf8)
                ?? String(data: nameData, encoding: .isoLatin1) else {
                throw ZipError.malformed("undecodable filename")
            }
            let path = normalizedPath(rawName)

            entries.append(ZipEntry(
                path: path,
                uncompressedSize: Int64(uncompressedSize),
                compressedSize: Int64(compressedSize),
                isDirectory: path.hasSuffix("/"),
                modified: dosDateTimeToDate(time: modTime, date: modDate),
                localHeaderOffset: localHeaderOffset,
                compressionMethod: method,
                crc32: crc,
                isEncrypted: (gpFlag & 0x0001) != 0
            ))
        }
        return entries
    }

    /// Converts a zip filename to the module's normalized form: forward
    /// slashes (Windows-authored zips sometimes use backslashes) and no
    /// leading slash.
    private static func normalizedPath(_ raw: String) -> String {
        var path = raw.replacingOccurrences(of: "\\", with: "/")
        while path.hasPrefix("/") { path.removeFirst() }
        return path
    }

    /// Converts an MS-DOS date/time pair (as stored in zip headers) to a
    /// `Date`, interpreted in UTC since zip carries no timezone. Returns
    /// `nil` for an out-of-range month/day (some tools emit all-zero
    /// timestamps for synthetic entries).
    private static func dosDateTimeToDate(time: UInt16, date: UInt16) -> Date? {
        let second = Int(time & 0x1F) * 2
        let minute = Int((time >> 5) & 0x3F)
        let hour = Int((time >> 11) & 0x1F)
        let day = Int(date & 0x1F)
        let month = Int((date >> 5) & 0xF)
        let year = Int((date >> 9) & 0x7F) + 1980
        guard month >= 1, month <= 12, day >= 1, day <= 31 else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar.date(from: components)
    }

    // MARK: - Inflation

    /// Inflates a raw DEFLATE (RFC 1951) byte stream using the system
    /// Compression framework. `COMPRESSION_ZLIB` is the framework's name for
    /// this raw-DEFLATE algorithm (it does not add or expect a zlib header).
    /// Raw-DEFLATE inflate (RFC 1951). Internal so `TarReader` can reuse it for
    /// gzip payloads (which are raw DEFLATE between the gzip header and trailer).
    static func inflate(_ input: Data, expectedSize: Int) throws -> Data {
        guard expectedSize > 0 else { return Data() }
        guard !input.isEmpty else { throw ZipError.inflateFailed }

        var output = Data(count: expectedSize)
        let decodedCount: Int? = output.withUnsafeMutableBytes { outRaw -> Int? in
            guard let outPtr = outRaw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            return input.withUnsafeBytes { inRaw -> Int? in
                guard let inPtr = inRaw.bindMemory(to: UInt8.self).baseAddress else { return nil }
                let count = compression_decode_buffer(
                    outPtr, expectedSize,
                    inPtr, input.count,
                    nil, COMPRESSION_ZLIB
                )
                return count
            }
        }
        guard let decodedCount, decodedCount == expectedSize else {
            throw ZipError.inflateFailed
        }
        return output
    }
}

/// A minimal, bounds-checked little-endian reader over a `Data` buffer.
/// Zip headers are read at arbitrary offsets (central directory entries are
/// scanned sequentially; local file headers are seeked to directly), so this
/// keeps every multi-byte read guarded against running off the end of the file.
private struct ByteReader {
    private let data: Data
    private var offset: Int

    init(data: Data, at offset: Int) {
        self.data = data
        self.offset = offset
    }

    mutating func readUInt16LE() throws -> UInt16 {
        guard offset >= 0, offset + 2 <= data.count else { throw ZipError.malformed("truncated read") }
        let b0 = UInt16(data[offset])
        let b1 = UInt16(data[offset + 1])
        offset += 2
        return b0 | (b1 << 8)
    }

    mutating func readUInt32LE() throws -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { throw ZipError.malformed("truncated read") }
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        offset += 4
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    mutating func readBytes(_ count: Int) throws -> Data {
        guard count >= 0, offset >= 0, offset + count <= data.count else {
            throw ZipError.malformed("truncated read")
        }
        let start = data.index(data.startIndex, offsetBy: offset)
        let end = data.index(start, offsetBy: count)
        let slice = data.subdata(in: start..<end)
        offset += count
        return slice
    }

    mutating func skip(_ count: Int) throws {
        guard count >= 0, offset >= 0, offset + count <= data.count else {
            throw ZipError.malformed("truncated read")
        }
        offset += count
    }
}

/// The three 32-bit keys of PKWARE's traditional ZipCrypto stream cipher
/// (APPNOTE.TXT §6.1), seeded from the password and advanced by each plaintext
/// byte. Reuses `ZipWriter.crcTable` for the per-byte CRC-32 update.
private struct ZipCryptoKeys {
    private var key0: UInt32 = 0x1234_5678
    private var key1: UInt32 = 0x2345_6789
    private var key2: UInt32 = 0x3456_7890

    init(password: [UInt8]) {
        for byte in password { update(byte) }
    }

    /// Fold one plaintext byte into the key state.
    mutating func update(_ byte: UInt8) {
        key0 = crc(key0, byte)
        key1 = key1 &+ (key0 & 0xff)
        key1 = key1 &* 134_775_813 &+ 1
        key2 = crc(key2, UInt8((key1 >> 24) & 0xff))
    }

    /// The next keystream byte (a function of the current key2).
    mutating func decryptByte() -> UInt8 {
        let temp = UInt16((key2 | 2) & 0xffff)
        return UInt8((temp &* (temp ^ 1)) >> 8 & 0xff)
    }

    private func crc(_ crc: UInt32, _ byte: UInt8) -> UInt32 {
        (crc >> 8) ^ ZipWriter.crcTable[Int((crc ^ UInt32(byte)) & 0xff)]
    }
}
