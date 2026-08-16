// SPDX-License-Identifier: Apache-2.0
// LZNT1.swift — NTFS's own compression, written from the format description.
//
// The second decoder here written rather than borrowed, for the same reason as
// `LZO.swift`: the implementations are in ntfs-3g and the Linux ntfs3 driver, both
// GPL-2.0, while the format itself is documented. Decompression only.
//
// A compressed NTFS attribute is a sequence of independent *chunks*, each decompressing
// to at most 4096 bytes and prefixed by a 16-bit header giving its compressed size and
// whether it is compressed at all — a chunk that did not shrink is stored verbatim, and
// mixed chunks in one attribute are ordinary.
//
// Inside a compressed chunk the stream alternates a flag byte with the eight items it
// describes, least-significant bit first: a clear bit is one literal byte, a set bit is a
// 16-bit back-reference. The part that cannot be guessed is how that 16 bits splits
// between length and offset: **it changes as the chunk fills**. Early in a chunk few bits
// are needed to address backwards, so most go to the length; by the end the split has
// moved to 12 bits of offset and 4 of length. A decoder using a fixed split produces
// correct output for the first few items of every chunk and diverges after — which looks
// like data corruption somewhere else entirely.

import Foundation

enum LZNT1 {
    /// Decompress an NTFS compressed run to at most `maxSize` bytes.
    static func decompress(_ input: [UInt8], maxSize: Int) throws -> [UInt8] {
        guard maxSize > 0, maxSize <= ImageLimits.maxBlockSize else {
            throw ImageError.limitExceeded(limit: "maxBlockSize (\(ImageLimits.maxBlockSize))")
        }
        var out = [UInt8]()
        out.reserveCapacity(maxSize)
        var position = 0

        while position + 2 <= input.count, out.count < maxSize {
            let header = UInt16(input[position]) | UInt16(input[position + 1]) << 8
            position += 2
            if header == 0 { break }                       // end of the compressed run

            let size = Int(header & 0x0FFF) + 1
            let isCompressed = header & 0x8000 != 0
            guard position + size <= input.count else {
                throw ImageError.damaged(reason: "LZNT1 chunk of \(size) bytes runs past the run")
            }
            let chunk = Array(input[position..<(position + size)])
            position += size

            if isCompressed {
                out.append(contentsOf: try decompressChunk(chunk, limit: maxSize - out.count))
            } else {
                // Stored verbatim because compressing it did not pay.
                out.append(contentsOf: chunk.prefix(maxSize - out.count))
            }
        }
        return out
    }

    private static func decompressChunk(_ chunk: [UInt8], limit: Int) throws -> [UInt8] {
        /// A chunk never decompresses to more than this — a format constant.
        let chunkSize = 4096
        var out = [UInt8]()
        out.reserveCapacity(min(chunkSize, limit))
        var index = 0

        while index < chunk.count {
            let flags = chunk[index]
            index += 1
            for bit in 0..<8 {
                guard index < chunk.count, out.count < chunkSize else { break }
                if flags & (1 << bit) == 0 {
                    out.append(chunk[index])
                    index += 1
                    continue
                }
                guard index + 2 <= chunk.count else {
                    throw ImageError.damaged(reason: "LZNT1 back-reference is cut off")
                }
                let token = Int(chunk[index]) | Int(chunk[index + 1]) << 8
                index += 2

                // The split moves as the chunk fills: just enough bits to address
                // everything produced so far go to the offset, the rest to the length.
                var offsetBits = 4
                while offsetBits < 12, (1 << offsetBits) < out.count { offsetBits += 1 }
                let lengthBits = 16 - offsetBits
                let length = (token & ((1 << lengthBits) - 1)) + 3
                let offset = (token >> lengthBits) + 1

                guard offset <= out.count else {
                    throw ImageError.damaged(
                        reason: "LZNT1 back-reference of \(offset) with \(out.count) bytes produced")
                }
                // Byte by byte: the run may reach past its own start and re-read bytes
                // this loop is writing, which is how a repeat is encoded.
                var source = out.count - offset
                for _ in 0..<length {
                    guard out.count < chunkSize else { break }
                    out.append(out[source])
                    source += 1
                }
            }
        }
        return Array(out.prefix(limit))
    }
}
