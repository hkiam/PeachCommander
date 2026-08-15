// SPDX-License-Identifier: Apache-2.0
// Decompressors.swift — the block codecs the image formats use.
//
// Every format here compresses in independent blocks (squashfs 128 KB, jffs2 per
// node, btrfs per extent), so this is a block-in/block-out interface, not a
// stream: the caller knows the uncompressed length from the format's own metadata
// and passes it in. That length is a *claim from the image*, so it is capped
// (`ImageLimits.maxBlockSize`) before anything is allocated — a 40-byte block
// claiming a gigabyte of output is the cheapest denial-of-service an image can
// attempt.
//
// What backs each codec, and why:
//
//   deflate/zlib  Apple `compression` (COMPRESSION_ZLIB is raw deflate, so the
//                 2-byte zlib header the formats include is stripped by hand).
//   xz / lzma     Apple `compression` (COMPRESSION_LZMA). Measured, not assumed:
//                 it decodes the .xz container, the legacy .lzma alone format, and
//                 xz streams carrying BCJ filters (x86/arm/armthumb) — which is
//                 what `mksquashfs -Xbcj` produces and what firmware actually
//                 ships. Raw headerless LZMA1 is the one thing it will not take,
//                 and no format here emits that. This is why no xz library is
//                 vendored.
//   lz4           Apple `compression`, via COMPRESSION_LZ4_**RAW**. The distinction
//                 matters: plain COMPRESSION_LZ4 is Apple's own framing with "bv41"
//                 block headers, which is not what squashfs writes. Squashfs stores
//                 bare LZ4 blocks, which is exactly LZ4_RAW.
//   zstd          Vendored: `Vendor/zstddeclib.c`, zstd's own single-file *decoder*
//                 amalgamation. macOS offers no zstd at all — not in the SDK, not as
//                 a system dylib — and it is not optional to skip: current mksquashfs
//                 and btrfs both reach for zstd by default now. The decode-only
//                 amalgamation is one file under BSD-3 with no build system of its
//                 own, which is the smallest obligation that closes the gap.
//   lzo           Deliberately absent. liblzo2 and minilzo are GPL-2.0, which this
//                 Apache-2.0 product cannot take, and there is no permissive
//                 implementation to use instead. A squashfs or jffs2 image using
//                 LZO therefore reports `.unsupported` naming LZO, which tells the
//                 user what to do (unsquashfs it elsewhere) instead of "damaged".

import Foundation
import Compression

enum Codec: String {
    case none
    /// A zlib stream (RFC 1950): 2-byte header, deflate, Adler-32. What squashfs,
    /// jffs2, cramfs and btrfs put in their blocks.
    case zlib
    /// A gzip stream (RFC 1952): variable-length header with optional filename and
    /// comment fields, deflate, CRC-32 + length trailer. Distinct from `.zlib`
    /// because the header is not a fixed two bytes — an initramfs is gzip, and
    /// treating it as zlib decodes garbage or nothing at all.
    case gzip
    case xz
    case lz4
    case zstd
    case lzo
}

enum Decompressor {
    /// Decompress `input` to exactly `expectedSize` bytes.
    ///
    /// `expectedSize` comes from the image's own metadata, so it is validated
    /// against `ImageLimits.maxBlockSize` first and against the actual output
    /// afterwards. A block that decodes to a different length than the filesystem
    /// says it should is a damaged image, not a short read to be padded — padding
    /// it would hand the user plausible-looking wrong file contents.
    static func decompress(_ input: [UInt8], codec: Codec, expectedSize: Int) throws -> [UInt8] {
        guard expectedSize >= 0, expectedSize <= ImageLimits.maxBlockSize else {
            throw ImageError.limitExceeded(limit: "maxBlockSize (\(ImageLimits.maxBlockSize))")
        }
        guard expectedSize > 0 else { return [] }

        switch codec {
        case .none:
            guard input.count == expectedSize else {
                throw ImageError.damaged(reason: "stored block is \(input.count) bytes, expected \(expectedSize)")
            }
            return input

        case .zlib, .gzip:
            // The formats wrap deflate in a container; Apple's COMPRESSION_ZLIB is
            // raw deflate (RFC 1951), so the container has to come off first.
            let payload = try strippingDeflateContainer(input, codec: codec)
            return try appleDecode(payload, algorithm: COMPRESSION_ZLIB, expectedSize: expectedSize, codec: codec)

        case .xz:
            return try appleDecode(input, algorithm: COMPRESSION_LZMA, expectedSize: expectedSize, codec: codec)

        case .lz4:
            return try appleDecode(input, algorithm: COMPRESSION_LZ4_RAW,
                                   expectedSize: expectedSize, codec: codec)

        case .zstd:
            return try zstdDecode(input, maxSize: expectedSize, exact: true)

        case .lzo:
            throw ImageError.unsupported(
                reason: "LZO compression is not supported (no licence-compatible decoder)")
        }
    }

    /// Strip whichever deflate container `input` carries, leaving raw deflate.
    ///
    /// Driven by the bytes rather than by `codec` alone: a format's metadata says
    /// "zlib" while the block on disk may be either a zlib stream or bare deflate
    /// (jffs2 emits both), and an initramfs declared gzip really is gzip. Checking
    /// what is actually there costs two comparisons and removes a whole class of
    /// "decodes to nothing" bug.
    private static func strippingDeflateContainer(_ input: [UInt8], codec: Codec) throws -> [UInt8] {
        if isGzip(input) { return try strippingGzipHeader(input) }
        if isZlib(input) { return Array(input.dropFirst(2)) }
        guard codec != .gzip else {
            throw ImageError.damaged(reason: "gzip stream does not start with a gzip header")
        }
        return input   // already raw deflate
    }

    /// A zlib stream begins CMF/FLG: the low nibble of CMF is 8 (deflate) and the
    /// 16-bit big-endian CMF·FLG is a multiple of 31. Both together are a strong
    /// enough signal; either alone is not.
    private static func isZlib(_ input: [UInt8]) -> Bool {
        guard input.count > 2, input[0] & 0x0F == 8 else { return false }
        return (UInt16(input[0]) << 8 | UInt16(input[1])) % 31 == 0
    }

    private static func isGzip(_ input: [UInt8]) -> Bool {
        input.count > 2 && input[0] == 0x1F && input[1] == 0x8B && input[2] == 0x08
    }

    /// Skip an RFC 1952 header: the fixed 10 bytes, then whichever of the optional
    /// EXTRA / NAME / COMMENT / HCRC fields FLG advertises. Every length read here
    /// comes from the stream, so each step is bounds-checked against what is left —
    /// a truncated header must fail, not walk off the end of the buffer.
    private static func strippingGzipHeader(_ input: [UInt8]) throws -> [UInt8] {
        func truncated() -> ImageError { .damaged(reason: "truncated gzip header") }
        guard input.count > 10 else { throw truncated() }
        let flags = input[3]
        var index = 10

        if flags & 0x04 != 0 {                        // FEXTRA: 2-byte length, then that many bytes
            guard index + 2 <= input.count else { throw truncated() }
            let extraLength = Int(input[index]) | Int(input[index + 1]) << 8
            index += 2
            guard index + extraLength <= input.count else { throw truncated() }
            index += extraLength
        }
        for flag in [UInt8(0x08), UInt8(0x10)] where flags & flag != 0 {   // FNAME, FCOMMENT
            guard let end = input[index...].firstIndex(of: 0) else { throw truncated() }
            index = end + 1
        }
        if flags & 0x02 != 0 {                        // FHCRC
            guard index + 2 <= input.count else { throw truncated() }
            index += 2
        }
        guard index < input.count else { throw truncated() }
        return Array(input[index...])
    }

    private static func appleDecode(_ input: [UInt8], algorithm: compression_algorithm,
                                    expectedSize: Int, codec: Codec) throws -> [UInt8] {
        guard !input.isEmpty else {
            throw ImageError.damaged(reason: "empty \(codec.rawValue) block")
        }
        // The output length is known, so decode into exactly that. compression_decode_buffer
        // returns 0 both for "failed" and for "produced nothing"; expectedSize > 0 is
        // guaranteed by the caller, so 0 is unambiguously a failure here.
        var output = [UInt8](repeating: 0, count: expectedSize)
        let produced = output.withUnsafeMutableBufferPointer { dst -> Int in
            guard let dstBase = dst.baseAddress else { return 0 }
            return input.withUnsafeBufferPointer { src -> Int in
                guard let srcBase = src.baseAddress else { return 0 }
                return compression_decode_buffer(dstBase, expectedSize, srcBase, src.count, nil, algorithm)
            }
        }
        guard produced == expectedSize else {
            if produced == 0 {
                throw ImageError.damaged(reason: "\(codec.rawValue) block failed to decode")
            }
            throw ImageError.damaged(
                reason: "\(codec.rawValue) block decoded to \(produced) bytes, expected \(expectedSize)")
        }
        return output
    }

    /// Decompress a block whose exact output length is unknown but bounded.
    ///
    /// SquashFS metadata blocks are like this: the format guarantees at most 8 KB out
    /// and stores only the *compressed* length, so the caller knows a ceiling and not
    /// a size. Because the ceiling is a format constant rather than a guess, a decode
    /// that fills the buffer exactly is complete rather than truncated, and a decode
    /// that produces nothing is unambiguously a failure.
    static func decompressVariable(_ input: [UInt8], codec: Codec, maxSize: Int) throws -> [UInt8] {
        guard maxSize > 0, maxSize <= ImageLimits.maxBlockSize else {
            throw ImageError.limitExceeded(limit: "maxBlockSize (\(ImageLimits.maxBlockSize))")
        }
        let algorithm: compression_algorithm
        switch codec {
        case .none: return input
        case .zlib, .gzip: algorithm = COMPRESSION_ZLIB
        case .xz:          algorithm = COMPRESSION_LZMA
        case .lz4:         algorithm = COMPRESSION_LZ4_RAW
        case .zstd:
            return try zstdDecode(input, maxSize: maxSize, exact: false)
        case .lzo:
            throw ImageError.unsupported(
                reason: "LZO compression is not supported (no licence-compatible decoder)")
        }
        let payload = algorithm == COMPRESSION_ZLIB ? try strippingDeflateContainer(input, codec: codec) : input
        guard !payload.isEmpty else { throw ImageError.damaged(reason: "empty \(codec.rawValue) block") }

        var output = [UInt8](repeating: 0, count: maxSize)
        let produced = output.withUnsafeMutableBufferPointer { dst -> Int in
            guard let dstBase = dst.baseAddress else { return 0 }
            return payload.withUnsafeBufferPointer { src -> Int in
                guard let srcBase = src.baseAddress else { return 0 }
                return compression_decode_buffer(dstBase, maxSize, srcBase, src.count, nil, algorithm)
            }
        }
        guard produced > 0 else {
            throw ImageError.damaged(reason: "\(codec.rawValue) block failed to decode")
        }
        output.removeLast(maxSize - produced)
        return output
    }

    /// Decompress a whole stream whose uncompressed length is *not* known up front
    /// — an initramfs is one gzip/xz stream wrapping the entire cpio archive, so
    /// there is no metadata to ask. Grows the output buffer until the codec is
    /// done, bounded by `ImageLimits.maxEntrySize`.
    static func decompressStream(_ input: [UInt8], codec: Codec) throws -> [UInt8] {
        let algorithm: compression_algorithm
        switch codec {
        case .zlib, .gzip: algorithm = COMPRESSION_ZLIB
        case .xz:          algorithm = COMPRESSION_LZMA
        case .none:        return input
        case .lz4, .zstd, .lzo:
            throw ImageError.unsupported(reason: "\(codec.rawValue) compression is not supported yet")
        }
        let payload = algorithm == COMPRESSION_ZLIB ? try strippingDeflateContainer(input, codec: codec) : input

        let bufferSize = 256 * 1024
        var output = [UInt8]()
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { dst.deallocate() }
        let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { stream.deallocate() }
        guard compression_stream_init(stream, COMPRESSION_STREAM_DECODE, algorithm) == COMPRESSION_STATUS_OK else {
            throw ImageError.damaged(reason: "cannot start \(codec.rawValue) decoder")
        }
        defer { compression_stream_destroy(stream) }

        return try payload.withUnsafeBufferPointer { src -> [UInt8] in
            guard let srcBase = src.baseAddress else {
                throw ImageError.damaged(reason: "empty \(codec.rawValue) stream")
            }
            stream.pointee.src_ptr = srcBase
            stream.pointee.src_size = src.count
            while true {
                stream.pointee.dst_ptr = dst
                stream.pointee.dst_size = bufferSize
                let status = compression_stream_process(stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                output.append(contentsOf: UnsafeBufferPointer(start: dst, count: bufferSize - stream.pointee.dst_size))
                guard Int64(output.count) <= ImageLimits.maxEntrySize else {
                    throw ImageError.limitExceeded(limit: "maxEntrySize (\(ImageLimits.maxEntrySize))")
                }
                switch status {
                case COMPRESSION_STATUS_END: return output
                case COMPRESSION_STATUS_OK: continue
                default: throw ImageError.damaged(reason: "\(codec.rawValue) stream failed to decode")
                }
            }
        }
    }

    /// Decode a Zstandard frame through the vendored decoder.
    ///
    /// `exact` distinguishes the two ways a caller knows the output size. A squashfs
    /// data block knows it precisely from the filesystem's own metadata, and a frame
    /// that decodes to a different length there is a damaged image. A metadata block
    /// or a btrfs extent knows only a ceiling — `ram_bytes` is rounded up to the
    /// sector size — so demanding an exact match would reject the short final extent
    /// of every file that is not a whole number of sectors.
    private static func zstdDecode(_ input: [UInt8], maxSize: Int, exact: Bool) throws -> [UInt8] {
        guard !input.isEmpty else { throw ImageError.damaged(reason: "empty zstd frame") }
        var output = [UInt8](repeating: 0, count: maxSize)
        let produced = output.withUnsafeMutableBytes { dst -> Int in
            input.withUnsafeBytes { src -> Int in
                guard let dstBase = dst.baseAddress, let srcBase = src.baseAddress else { return -1 }
                return ZSTD_decompress(dstBase, maxSize, srcBase, src.count)
            }
        }
        // zstd reports failure as a sentinel *size*, not a negative number, which is
        // exactly what ZSTD_isError exists to recognise. Range-checking the value alone
        // would read an error code as a length.
        if ZSTD_isError(produced) != 0 {
            let message = String(cString: ZSTD_getErrorName(produced))
            throw ImageError.damaged(reason: "zstd frame failed to decode (\(message))")
        }
        guard produced >= 0, produced <= maxSize else {
            throw ImageError.damaged(reason: "zstd frame decoded to \(produced) bytes, cap is \(maxSize)")
        }
        if exact, produced != maxSize {
            throw ImageError.damaged(reason: "zstd block decoded to \(produced) bytes, expected \(maxSize)")
        }
        output.removeLast(maxSize - produced)
        return output
    }

    /// Identify a whole-stream wrapper by its magic — how an initramfs announces
    /// which of the kernel's supported compressors produced it.
    static func detectStreamCodec(_ header: [UInt8]) -> Codec {
        if header.count >= 2, header[0] == 0x1F, header[1] == 0x8B { return .gzip }
        if header.count >= 6, header[0] == 0xFD, header[1] == 0x37, header[2] == 0x7A,
           header[3] == 0x58, header[4] == 0x5A, header[5] == 0x00 { return .xz }          // xz
        if header.count >= 3, header[0] == 0x5D, header[1] == 0x00, header[2] == 0x00 { return .xz }  // .lzma alone
        if header.count >= 4, header[0] == 0x04, header[1] == 0x22,
           header[2] == 0x4D, header[3] == 0x18 { return .lz4 }
        if header.count >= 4, header[0] == 0x28, header[1] == 0xB5,
           header[2] == 0x2F, header[3] == 0xFD { return .zstd }
        return .none
    }
}
