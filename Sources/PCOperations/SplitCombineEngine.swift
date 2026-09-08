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

public enum SplitCombineError: Error, Equatable {
    case badCRCFile
    case noParts
    /// The parts do not add up to the size the sidecar records — one is missing from the middle of
    /// the set, or one was truncated on the way. Reported rather than reassembled, because the
    /// result would be a file of the right name and the wrong content, caught only by the CRC and
    /// left on disk either way. The number is the first index that could not be read.
    case missingPart(Int)
    /// Something with that name is already there. The engine cannot ask; the caller can.
    case targetExists(String)
    /// A part size of zero or less. Was a `precondition`, which crashes the process: the dialog
    /// happens to check first, so only a plugin or a script could reach it — and they would have
    /// taken the app down with them.
    case badPartSize
}

public enum SplitCombineEngine {
    /// Split `src` into `partSize`-byte parts inside `dir`; also writes "<name>.crc".
    ///
    /// - Parameter overwrite: When false (the default) an existing first part or sidecar stops the
    ///   split with `.targetExists` instead of writing over it. Splitting the same file twice is
    ///   ordinary; writing over somebody else's `.001` without a word is not.
    @discardableResult
    public static func split(_ src: VFSPath, partSize: Int64, into dir: VFSPath,
                             on fs: VirtualFileSystem, overwrite: Bool = false) async throws -> SplitInfo {
        guard partSize > 0 else { throw SplitCombineError.badPartSize }
        let base = src.lastComponent()
        if !overwrite {
            for candidate in [SplitInfo.partName(base, index: 1), base + ".crc"] {
                if (try? await fs.stat(dir.joining(candidate))) != nil {
                    throw SplitCombineError.targetExists(candidate)
                }
            }
        }
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
    /// - Parameter overwrite: When false (the default) an existing file of the sidecar's name stops
    ///   the reassembly with `.targetExists` rather than replacing it. Measured before this: an
    ///   unrelated file with the original name was destroyed without a word, on the one write path in
    ///   the app that had no conflict question at all.
    ///
    /// The parts are looked for **next to the sidecar**, not in `dir`. They were looked for in `dir`,
    /// which made combining into any other directory impossible — it reported "no parts" — and which
    /// is the wrong question anyway: the sidecar describes the set it sits in.
    public static func combine(crcPath: VFSPath, into dir: VFSPath,
                               on fs: VirtualFileSystem,
                               overwrite: Bool = false) async throws -> (info: SplitInfo, crcOK: Bool) {
        let crcData = try await readAll(crcPath, on: fs)
        guard let info = SplitInfo.parse(String(decoding: crcData, as: UTF8.self)) else {
            throw SplitCombineError.badCRCFile
        }
        let partsDir = crcPath.parent() ?? dir
        let target = dir.joining(info.filename)
        if !overwrite, (try? await fs.stat(target)) != nil {
            throw SplitCombineError.targetExists(info.filename)
        }

        // Counted, and weighed, before a byte is written.
        //
        // The old loop stopped at the first part it could not open, so a missing `.003` with `.004`
        // present became a file of the right name and the wrong content — left on disk, with only the
        // CRC afterwards to say so. The sidecar records the original size, so the question "is the
        // whole set here" has an answer before anything is written: what the parts weigh has to be
        // what the sidecar says. That catches a hole of any width and a part that was truncated on
        // the way, and it cannot refuse a set that used to reassemble correctly — bytes that do not
        // add up would not have matched the CRC either.
        var count = 0
        var bytes: Int64 = 0
        while let part = try? await fs.stat(partsDir.joining(SplitInfo.partName(info.filename, index: count + 1))) {
            count += 1
            bytes += part.size
        }
        guard count > 0 else { throw SplitCombineError.noParts }
        guard bytes == info.size else { throw SplitCombineError.missingPart(count + 1) }

        let writer = try await fs.openWrite(target, options: WriteOptions())
        var crc: UInt32 = 0xFFFF_FFFF
        for index in 1...count {
            let part = partsDir.joining(SplitInfo.partName(info.filename, index: index))
            // Streamed, not read whole: this used to pull each part into memory in one piece, which for
            // the part sizes people actually pick — a CD or a DVD — meant holding hundreds of megabytes
            // or several gigabytes at once, while the comment above this type claimed memory stays flat.
            let stream = try await fs.openRead(part)
            for try await chunk in stream {
                guard let data = chunk as? Data else { continue }
                try await writer.write(data)
                crc = CRC32.update(crc, data)
            }
            try? await stream.close()
        }
        try await writer.close()
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
