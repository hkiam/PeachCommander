// SPDX-License-Identifier: Apache-2.0
// SplitCombineEngine.swift - Split a file into parts / combine them back (SPEC-016 §3).
//
// Split streams the source through the VFS into fixed-size .001/.002/… parts and
// writes a "<name>.crc" sidecar (original name, size, CRC-32). Combine reads the
// parts back in order, reassembles the original, and verifies its CRC-32 against
// the sidecar. Streaming keeps memory flat regardless of file size.

import Foundation
import PCFoundation
import PCVFS

public enum SplitCombineError: Error, Equatable { case badCRCFile, noParts }

public enum SplitCombineEngine {
    /// Split `src` into `partSize`-byte parts inside `dir`; also writes "<name>.crc".
    @discardableResult
    public static func split(_ src: VFSPath, partSize: Int64, into dir: VFSPath,
                             on fs: VirtualFileSystem) async throws -> SplitInfo {
        precondition(partSize > 0, "partSize must be positive")
        let base = src.lastComponent()
        let stream = try await fs.openRead(src)

        var crc: UInt32 = 0xFFFF_FFFF
        var total: Int64 = 0
        var partIndex = 1
        var written: Int64 = 0
        var writer = try await fs.openWrite(dir.joining(SplitInfo.partName(base, index: 1)), options: WriteOptions())

        for try await chunk in stream {
            guard let data = chunk as? Data else { continue }
            var offset = 0
            while offset < data.count {
                if written == partSize {                       // current part full → next part
                    try await writer.close()
                    partIndex += 1
                    writer = try await fs.openWrite(dir.joining(SplitInfo.partName(base, index: partIndex)),
                                                    options: WriteOptions())
                    written = 0
                }
                let take = Swift.min(Int(partSize - written), data.count - offset)
                let slice = data.subdata(in: offset..<(offset + take))
                try await writer.write(slice)
                crc = CRC32.update(crc, slice)
                total += Int64(take)
                written += Int64(take)
                offset += take
            }
        }
        try await writer.close()
        try? await stream.close()

        let info = SplitInfo(filename: base, size: total, crc32: crc ^ 0xFFFF_FFFF)
        let crcWriter = try await fs.openWrite(dir.joining(base + ".crc"), options: WriteOptions())
        try await crcWriter.write(Data(info.serialized().utf8))
        try await crcWriter.close()
        return info
    }

    /// Reassemble the parts described by `crcPath` (a "<name>.crc" file) into `dir`,
    /// returning the parsed info and whether the recomputed CRC-32 matches.
    public static func combine(crcPath: VFSPath, into dir: VFSPath,
                               on fs: VirtualFileSystem) async throws -> (info: SplitInfo, crcOK: Bool) {
        let crcData = try await readAll(crcPath, on: fs)
        guard let info = SplitInfo.parse(String(decoding: crcData, as: UTF8.self)) else {
            throw SplitCombineError.badCRCFile
        }
        let writer = try await fs.openWrite(dir.joining(info.filename), options: WriteOptions())
        var crc: UInt32 = 0xFFFF_FFFF
        var index = 1
        var wroteAny = false
        while true {
            let part = dir.joining(SplitInfo.partName(info.filename, index: index))
            // Streamed, not read whole: this used to pull each part into memory in one piece, which for
            // the part sizes people actually pick — a CD or a DVD — meant holding hundreds of megabytes
            // or several gigabytes at once, while the comment above this type claimed memory stays flat.
            guard let stream = try? await fs.openRead(part) else { break }      // no more parts
            for try await chunk in stream {
                guard let data = chunk as? Data else { continue }
                try await writer.write(data)
                crc = CRC32.update(crc, data)
            }
            try? await stream.close()
            wroteAny = true
            index += 1
        }
        try await writer.close()
        guard wroteAny else { throw SplitCombineError.noParts }
        return (info, (crc ^ 0xFFFF_FFFF) == info.crc32)
    }

    private static func readAll(_ path: VFSPath, on fs: VirtualFileSystem) async throws -> Data {
        let stream = try await fs.openRead(path)
        var data = Data()
        for try await chunk in stream { if let d = chunk as? Data { data.append(d) } }
        try? await stream.close()
        return data
    }
}
