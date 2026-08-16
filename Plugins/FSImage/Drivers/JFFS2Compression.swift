// SPDX-License-Identifier: Apache-2.0
// JFFS2Compression.swift — the codecs JFFS2 uses that nothing else does, plus its CRC.
//
// JFFS2 predates the general-purpose block compressors and carries two of its own.
// `rtime` is the one that matters: it is tiny, fast on the 8 MHz processors these
// filesystems were built for, and mkfs.jffs2 still picks it whenever it beats zlib on
// a given node — which on short, repetitive config files is often. A reader without
// it works on many images and then silently meets one where it does not.
//
// The Rubin coders (`rubinmips`, `dynrubin`) are the other pair. They are arithmetic
// coders that were already rare when JFFS2 was new, are not produced by any current
// mkfs.jffs2, and are refused by name rather than guessed at.
//
// LZO goes through `LZO.swift`, plain — JFFS2 puts an LZO1X stream straight in the node,
// with none of the segment framing Btrfs wraps around it. This path was dead for a while
// without anyone noticing: LZO was wired into `Decompressor` but not into this switch,
// and Ubuntu's mkfs.jffs2 is built without LZO, so no fixture reached it. Alpine's is
// built with it, which is what finally produced an image and turned the gap into a
// failing test.

import Foundation

enum JFFS2Compression {
    /// Compression ids as stored in a JFFS2 inode node.
    enum Kind: UInt8 {
        case none = 0
        case zero = 1
        case rtime = 2
        case rubinMips = 3
        case copy = 4
        case dynRubin = 5
        case zlib = 6
        case lzo = 7
    }

    static func decompress(_ input: [UInt8], kind: Kind, expectedSize: Int) throws -> [UInt8] {
        guard expectedSize >= 0, expectedSize <= ImageLimits.maxBlockSize else {
            throw ImageError.limitExceeded(limit: "maxBlockSize (\(ImageLimits.maxBlockSize))")
        }
        switch kind {
        case .zero:
            // A whole node of zeros, stored as nothing at all.
            return [UInt8](repeating: 0, count: expectedSize)
        case .none, .copy:
            guard input.count >= expectedSize else {
                throw ImageError.damaged(
                    reason: "stored node holds \(input.count) bytes, needs \(expectedSize)")
            }
            return Array(input.prefix(expectedSize))
        case .zlib:
            return try Decompressor.decompress(input, codec: .zlib, expectedSize: expectedSize)
        case .rtime:
            return try rtimeDecompress(input, expectedSize: expectedSize)
        case .rubinMips, .dynRubin:
            throw ImageError.unsupported(
                reason: "the \(kind == .rubinMips ? "rubinmips" : "dynrubin") compressor is not supported")
        case .lzo:
            // Plain LZO1X on the node payload — no framing of its own, unlike Btrfs.
            let out = try LZO.decompress(input, maxSize: expectedSize)
            guard out.count == expectedSize else {
                throw ImageError.damaged(
                    reason: "lzo node decoded to \(out.count) bytes, expected \(expectedSize)")
            }
            return out
        }
    }

    /// JFFS2's `rtime` codec.
    ///
    /// A back-reference scheme with no explicit offsets: the stream is pairs of
    /// (literal byte, repeat count), and the *source* of a repeat is wherever that
    /// same byte value last appeared in the output. A 256-entry table of last
    /// positions is all the state there is.
    ///
    /// The copy has to be byte-by-byte and must read from the output as it grows —
    /// when the run reaches past its own start it re-reads bytes this loop just
    /// wrote, which is how rtime encodes a repeating pattern. Copying the source
    /// range up front, the obvious optimisation, produces different bytes.
    private static func rtimeDecompress(_ input: [UInt8], expectedSize: Int) throws -> [UInt8] {
        var positions = [Int](repeating: 0, count: 256)
        var out = [UInt8]()
        out.reserveCapacity(expectedSize)
        var pos = 0

        while out.count < expectedSize {
            guard pos + 2 <= input.count else {
                throw ImageError.damaged(reason: "rtime stream ends after \(out.count) of \(expectedSize) bytes")
            }
            let value = input[pos]
            let repeatCount = Int(input[pos + 1])
            pos += 2

            out.append(value)
            let backOffset = positions[Int(value)]
            positions[Int(value)] = out.count

            guard repeatCount > 0 else { continue }
            guard backOffset >= 0, backOffset < out.count else {
                throw ImageError.damaged(reason: "rtime back-reference to \(backOffset), output is \(out.count)")
            }
            guard out.count + repeatCount <= expectedSize else {
                throw ImageError.damaged(
                    reason: "rtime run of \(repeatCount) overruns the \(expectedSize)-byte node")
            }
            var source = backOffset
            for _ in 0..<repeatCount {
                out.append(out[source])
                source += 1
            }
        }
        return out
    }

    /// The CRC-32 JFFS2 actually uses: Linux's `crc32_le`, which is the reflected
    /// 0xEDB88320 polynomial started at **0** with **no final inversion**.
    ///
    /// Not the standard CRC-32, which starts at 0xFFFFFFFF and inverts at the end.
    /// The two differ on every input, so using the familiar one rejects every node in
    /// a perfectly good image — 90 out of 90 in the test fixture — and the scan then
    /// reports "no JFFS2 nodes found" about a file that is entirely valid. The names
    /// are what mislead here: mtd-utils and the kernel both call this `crc32`.
    ///
    /// Needed for reading, not just for integrity: the scan has to resynchronise
    /// after erased regions by hunting for a 2-byte magic, and two bytes hit by
    /// chance inside file data all the time. The header CRC is what separates a real
    /// node from a coincidence, so without it the scan invents nodes out of file
    /// contents.
    static func crc32(_ bytes: ArraySlice<UInt8>) -> UInt32 {
        var crc: UInt32 = 0
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ (0xEDB8_8320 & (0 &- (crc & 1)))
            }
        }
        return crc
    }
}
