// ZipWriter.swift - A pure-Swift, dependency-free ZIP writer producing the
// classic (non-zip64) local-file-header / central-directory / EOCD layout
// that `ZipReader` in this module understands (I09 counterpart).
//
// No external dependencies: assembly uses Foundation `Data` only, and
// compression uses the system `Compression` framework
// (`compression_encode_buffer` with `COMPRESSION_ZLIB`, which despite the
// name produces raw DEFLATE, i.e. RFC 1951 with no zlib/gzip header or
// trailer - the same format `ZipReader.inflate` expects).

import Compression
import Foundation

/// Errors raised while assembling or writing a zip archive.
public enum ZipWriteError: Error, Sendable, Equatable {
    /// Attempted to write an entry whose path-within-zip is empty.
    case emptyEntryPath
    /// A regular entry's path cannot be represented as UTF-8 bytes.
    case undecodablePath(String)
    /// `compression_encode_buffer` failed and the store fallback was not
    /// applicable (this should not occur in practice, since store is always
    /// a valid fallback; retained for completeness).
    case compressionFailed
}

/// Writes standard (non-zip64), read-only-friendly zip archives from an
/// in-memory list of (path, data) pairs.
///
/// This is an MVP-scoped writer: no zip64, no encryption, no multi-disk
/// archives, no archive comment, and every filename is written as UTF-8 with
/// the corresponding general-purpose bit flag set. Entries are compressed
/// with DEFLATE when that is smaller than storing the raw bytes, matching
/// what `ZipReader.data(for:)` can inflate.
public enum ZipWriter {
    private static let localHeaderSignature: UInt32 = 0x0403_4b50
    private static let centralDirSignature: UInt32 = 0x0201_4b50
    private static let eocdSignature: UInt32 = 0x0605_4b50

    /// General-purpose bit flag: bit 11 (0x0800) marks the filename/comment
    /// as UTF-8, per the "Language encoding flag (EFS)" appendix of the zip
    /// spec. `ZipReader` decodes filenames as UTF-8 regardless, but setting
    /// this flag is the well-behaved thing for a writer to do.
    private static let utf8Flag: UInt16 = 0x0800

    private static let versionNeeded: UInt16 = 20
    private static let methodStore: UInt16 = 0
    private static let methodDeflate: UInt16 = 8

    /// One fully-assembled entry, staged in memory before the two passes
    /// (local headers + data, then central directory) are written out.
    private struct StagedEntry {
        let nameBytes: [UInt8]
        let method: UInt16
        let crc32: UInt32
        let compressedData: Data
        let uncompressedSize: UInt32
        let dosTime: UInt16
        let dosDate: UInt16
        var localHeaderOffset: UInt32 = 0
    }

    /// Write a standard (non-zip64) zip to `url`. Each entry is
    /// (path-within-zip, data). A path ending in "/" (with empty data) is
    /// stored as a directory entry. Regular entries are DEFLATE-compressed
    /// when that is smaller, else stored. Sets the UTF-8 filename flag
    /// (general-purpose bit 11). Throws on compression/IO failure.
    public static func create(at url: URL, files: [(path: String, data: Data)]) throws {
        let now = Date()
        let (dosTime, dosDate) = dosDateTime(from: now)

        var staged: [StagedEntry] = []
        staged.reserveCapacity(files.count)

        for file in files {
            guard !file.path.isEmpty else { throw ZipWriteError.emptyEntryPath }
            guard let nameBytes = file.path.data(using: .utf8) else {
                throw ZipWriteError.undecodablePath(file.path)
            }
            let isDirectory = file.path.hasSuffix("/")
            let uncompressedData = isDirectory ? Data() : file.data
            let crc = crc32(of: uncompressedData)

            let (method, payload): (UInt16, Data)
            if isDirectory || uncompressedData.isEmpty {
                (method, payload) = (methodStore, uncompressedData)
            } else if let deflated = deflate(uncompressedData), deflated.count < uncompressedData.count {
                (method, payload) = (methodDeflate, deflated)
            } else {
                (method, payload) = (methodStore, uncompressedData)
            }

            staged.append(StagedEntry(
                nameBytes: [UInt8](nameBytes),
                method: method,
                crc32: crc,
                compressedData: payload,
                uncompressedSize: UInt32(uncompressedData.count),
                dosTime: dosTime,
                dosDate: dosDate
            ))
        }

        var output = Data()

        // Pass 1: local file headers + entry data, recording each entry's
        // local-header offset for the central directory that follows.
        for index in staged.indices {
            staged[index].localHeaderOffset = UInt32(output.count)
            appendLocalFileHeader(&output, entry: staged[index])
            output.append(staged[index].compressedData)
        }

        let centralDirOffset = UInt32(output.count)
        for entry in staged {
            appendCentralDirectoryHeader(&output, entry: entry)
        }
        let centralDirSize = UInt32(output.count) - centralDirOffset

        appendEOCD(
            &output,
            entryCount: UInt16(staged.count),
            centralDirSize: centralDirSize,
            centralDirOffset: centralDirOffset
        )

        try output.write(to: url, options: .atomic)
    }

    // MARK: - Header assembly

    private static func appendLocalFileHeader(_ output: inout Data, entry: StagedEntry) {
        appendUInt32LE(&output, localHeaderSignature)
        appendUInt16LE(&output, versionNeeded)
        appendUInt16LE(&output, utf8Flag)
        appendUInt16LE(&output, entry.method)
        appendUInt16LE(&output, entry.dosTime)
        appendUInt16LE(&output, entry.dosDate)
        appendUInt32LE(&output, entry.crc32)
        appendUInt32LE(&output, UInt32(entry.compressedData.count))
        appendUInt32LE(&output, entry.uncompressedSize)
        appendUInt16LE(&output, UInt16(entry.nameBytes.count))
        appendUInt16LE(&output, 0) // extra length
        output.append(contentsOf: entry.nameBytes)
    }

    private static func appendCentralDirectoryHeader(_ output: inout Data, entry: StagedEntry) {
        appendUInt32LE(&output, centralDirSignature)
        appendUInt16LE(&output, versionNeeded) // version made by
        appendUInt16LE(&output, versionNeeded) // version needed to extract
        appendUInt16LE(&output, utf8Flag)
        appendUInt16LE(&output, entry.method)
        appendUInt16LE(&output, entry.dosTime)
        appendUInt16LE(&output, entry.dosDate)
        appendUInt32LE(&output, entry.crc32)
        appendUInt32LE(&output, UInt32(entry.compressedData.count))
        appendUInt32LE(&output, entry.uncompressedSize)
        appendUInt16LE(&output, UInt16(entry.nameBytes.count))
        appendUInt16LE(&output, 0) // extra length
        appendUInt16LE(&output, 0) // comment length
        appendUInt16LE(&output, 0) // disk number start
        appendUInt16LE(&output, 0) // internal file attributes
        appendUInt32LE(&output, 0) // external file attributes
        appendUInt32LE(&output, entry.localHeaderOffset)
        output.append(contentsOf: entry.nameBytes)
    }

    private static func appendEOCD(
        _ output: inout Data,
        entryCount: UInt16,
        centralDirSize: UInt32,
        centralDirOffset: UInt32
    ) {
        appendUInt32LE(&output, eocdSignature)
        appendUInt16LE(&output, 0) // number of this disk
        appendUInt16LE(&output, 0) // disk with the start of the central directory
        appendUInt16LE(&output, entryCount) // entries on this disk
        appendUInt16LE(&output, entryCount) // total entries
        appendUInt32LE(&output, centralDirSize)
        appendUInt32LE(&output, centralDirOffset)
        appendUInt16LE(&output, 0) // archive comment length
    }

    // MARK: - Little-endian field writing

    private static func appendUInt16LE(_ output: inout Data, _ value: UInt16) {
        output.append(UInt8(value & 0xFF))
        output.append(UInt8((value >> 8) & 0xFF))
    }

    private static func appendUInt32LE(_ output: inout Data, _ value: UInt32) {
        output.append(UInt8(value & 0xFF))
        output.append(UInt8((value >> 8) & 0xFF))
        output.append(UInt8((value >> 16) & 0xFF))
        output.append(UInt8((value >> 24) & 0xFF))
    }

    // MARK: - DOS date/time

    /// Converts a `Date` to the MS-DOS date/time pair zip headers store,
    /// interpreted in UTC (matching `ZipReader.dosDateTimeToDate`, which
    /// also assumes UTC since zip carries no timezone).
    private static func dosDateTime(from date: Date) -> (time: UInt16, date: UInt16) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let year = max(1980, components.year ?? 1980)
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0

        let dosTime = UInt16((hour << 11) | (minute << 5) | (second / 2))
        let dosDate = UInt16(((year - 1980) << 9) | (month << 5) | day)
        return (dosTime, dosDate)
    }

    // MARK: - CRC-32

    /// Standard CRC-32 lookup table (IEEE 802.3 polynomial, reflected form
    /// 0xEDB88320), built once and reused for every `crc32(of:)` call.
    static let crcTable: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var value = UInt32(i)
            for _ in 0..<8 {
                if value & 1 == 1 {
                    value = (value >> 1) ^ 0xEDB8_8320
                } else {
                    value >>= 1
                }
            }
            table[i] = value
        }
        return table
    }()

    /// Computes the CRC-32 (IEEE polynomial, as zip requires) of `data`'s
    /// uncompressed bytes.
    static func crc32(of data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            for byte in raw.bindMemory(to: UInt8.self) {
                let index = Int((crc ^ UInt32(byte)) & 0xFF)
                crc = crcTable[index] ^ (crc >> 8)
            }
        }
        return crc ^ 0xFFFF_FFFF
    }

    // MARK: - Deflation

    /// Compresses `input` with raw DEFLATE via the system Compression
    /// framework. Returns `nil` if compression fails or does not fit in a
    /// destination buffer sized to the input (the caller falls back to
    /// storing the raw bytes in either case, since store is always valid).
    private static func deflate(_ input: Data) -> Data? {
        guard !input.isEmpty else { return nil }

        // Deflate output can, in the worst case, slightly exceed the input
        // size (incompressible data plus block overhead); pad generously so
        // a "compressed" result that would end up >= the input size is
        // simply reported honestly rather than silently truncated, letting
        // the caller's size comparison fall back to store.
        let capacity = input.count + max(64, input.count / 8)
        var destination = [UInt8](repeating: 0, count: capacity)

        let encodedCount: Int = destination.withUnsafeMutableBufferPointer { destBuffer -> Int in
            guard let destPtr = destBuffer.baseAddress else { return 0 }
            return input.withUnsafeBytes { (srcRaw: UnsafeRawBufferPointer) -> Int in
                guard let srcPtr = srcRaw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_encode_buffer(
                    destPtr, capacity,
                    srcPtr, input.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }

        guard encodedCount > 0 else { return nil }
        return Data(destination[0..<encodedCount])
    }
}
