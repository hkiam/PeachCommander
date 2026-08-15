// SPDX-License-Identifier: Apache-2.0
// LZO.swift — an LZO1X decompressor, written from the format description.
//
// LZO is the one compressor every format here can meet and none of them could read. It
// is the *default* in `mkfs.ubifs` — 74 of 76 data nodes in a stock image — and an
// option in SquashFS, JFFS2 and Btrfs. Refusing it meant refusing most UBIFS images
// outright, and a reader that lists a rootfs it cannot read from is worse than none.
//
// **On the licence, since that is why this file exists.** liblzo2 and minilzo are
// GPL-2.0, which this Apache-2.0 product cannot take. What is GPL is Oberhumer's
// *implementation*, not the format: the bitstream is documented, including in the Linux
// kernel's own `Documentation/staging/lzo.rst`. This is written from that description,
// the same way the six filesystem readers beside it are written from theirs rather than
// derived from e2fsprogs or squashfs-tools. Decompression only — nothing here can
// produce an LZO stream.
//
// The stream is a sequence of instructions: an opcode byte, then optional extra-length,
// distance and literal bytes. Two properties make it fiddlier than its size suggests,
// and both are load-bearing:
//
//   * **An opcode's meaning depends on how many literals the previous instruction
//     emitted.** That count (`state`, 0–3) selects between two different distance
//     encodings for the same byte value. A decoder that ignores it produces output that
//     looks fine and diverges at the first short match.
//   * **A match may overlap its own output.** `distance` is allowed to be smaller than
//     `length` — that is how a repeating run is encoded — so the copy must go byte by
//     byte, reading bytes the same loop is writing. Copying the source range up front,
//     the obvious optimisation, silently produces different bytes.
//
// Every read is bounds-checked against the input and every back-reference against what
// has actually been produced. This decodes attacker-supplied firmware, and a
// back-reference pointing before the start of the output is the cheapest way to read
// memory that is not ours.

import Foundation

enum LZO {
    /// Decompress an LZO1X stream, producing at most `maxSize` bytes.
    ///
    /// Returns what the stream actually produced rather than insisting on `maxSize`:
    /// the callers know their own truth — SquashFS states a block's exact length,
    /// UBIFS records it per data node — and a short final block is normal in both.
    static func decompress(_ input: [UInt8], maxSize: Int) throws -> [UInt8] {
        guard maxSize > 0, maxSize <= ImageLimits.maxBlockSize else {
            throw ImageError.limitExceeded(limit: "maxBlockSize (\(ImageLimits.maxBlockSize))")
        }
        guard !input.isEmpty else { throw ImageError.damaged(reason: "empty LZO stream") }

        var out = [UInt8]()
        out.reserveCapacity(maxSize)
        var ip = 0

        func require(_ count: Int) throws {
            guard count >= 0, ip + count <= input.count else {
                throw ImageError.damaged(reason: "LZO stream ends mid-instruction at \(ip)")
            }
        }
        func next() throws -> Int {
            try require(1)
            defer { ip += 1 }
            return Int(input[ip])
        }
        /// Lengths past the opcode's inline range: a run of 0x00 bytes worth 255 each,
        /// then a final non-zero byte plus `bias`. Bounded, so a corrupt run of zeros
        /// cannot spin or overflow.
        func extendedLength(bias: Int) throws -> Int {
            var length = 0
            while ip < input.count, input[ip] == 0 {
                length += 255
                ip += 1
                guard length <= ImageLimits.maxBlockSize else {
                    throw ImageError.damaged(reason: "LZO length encoding does not terminate")
                }
            }
            return length + bias + (try next())
        }
        func literals(_ count: Int) throws {
            try require(count)
            guard out.count + count <= maxSize else {
                throw ImageError.damaged(reason: "LZO literals overrun the \(maxSize)-byte block")
            }
            out.append(contentsOf: input[ip..<(ip + count)])
            ip += count
        }
        func copyMatch(distance: Int, length: Int) throws {
            guard distance > 0, distance <= out.count else {
                throw ImageError.damaged(
                    reason: "LZO back-reference of \(distance) with \(out.count) bytes produced")
            }
            guard length >= 0, out.count + length <= maxSize else {
                throw ImageError.damaged(reason: "LZO match overruns the \(maxSize)-byte block")
            }
            var source = out.count - distance
            for _ in 0..<length {          // byte by byte: the range may overlap its own output
                out.append(out[source])
                source += 1
            }
        }
        /// The trailing-literal count, in the low two bits of the byte two back. Every
        /// instruction shape leaves the right byte there: the opcode for the one-byte
        /// distance forms, the first distance byte for the two-byte ones.
        func trailingLiterals() throws -> Int {
            guard ip >= 2 else { throw ImageError.damaged(reason: "LZO instruction too short") }
            return Int(input[ip - 2]) & 3
        }

        var token = 0
        var pendingLiterals = false      // "match_next": copy `token` literals, then read an opcode
        var afterLongLiteralRun = false  // "first_literal_run": the 3-byte short-match form

        // The first byte is special: above 17 it is a literal run by itself, and the
        // stream then continues as though a long run had just been emitted.
        if input[0] > 17 {
            token = try next() - 17
            if token < 4 {
                pendingLiterals = true
            } else {
                try literals(token)
                afterLongLiteralRun = true
            }
        }

        var instructions = 0
        outer: while true {
            instructions += 1
            guard instructions <= 4 * ImageLimits.maxBlockSize else {
                throw ImageError.damaged(reason: "LZO stream does not terminate")
            }

            if !pendingLiterals {
                if !afterLongLiteralRun {
                    token = try next()
                    if token < 16 {
                        let count = token == 0 ? try extendedLength(bias: 15) : token
                        try literals(count + 3)
                        afterLongLiteralRun = true
                    }
                }
                if afterLongLiteralRun {
                    afterLongLiteralRun = false
                    token = try next()
                    if token < 16 {
                        // Short match with the 2 KB bias — only reachable straight after a
                        // long literal run, which is what makes it a distinct encoding.
                        let distance = 1 + 0x0800 + (token >> 2) + (try next() << 2)
                        try copyMatch(distance: distance, length: 3)
                        token = try trailingLiterals()
                        if token == 0 { continue outer }
                        pendingLiterals = true
                    }
                }
            }

            // The match section. Loops on itself rather than returning to the top,
            // because trailing literals are followed by another *match*, not by a new
            // literal run.
            while true {
                if pendingLiterals {
                    pendingLiterals = false
                    try literals(token)
                    token = try next()
                }

                if token >= 64 {
                    let distance = 1 + ((token >> 2) & 7) + (try next() << 3)
                    try copyMatch(distance: distance, length: (token >> 5) - 1 + 2)
                } else if token >= 32 {
                    var length = token & 31
                    if length == 0 { length = try extendedLength(bias: 31) }
                    try require(2)
                    let raw = Int(input[ip]) | Int(input[ip + 1]) << 8
                    ip += 2
                    try copyMatch(distance: 1 + (raw >> 2), length: length + 2)
                } else if token >= 16 {
                    var length = token & 7
                    if length == 0 { length = try extendedLength(bias: 7) }
                    try require(2)
                    let raw = ((token & 8) << 11) + ((Int(input[ip]) | Int(input[ip + 1]) << 8) >> 2)
                    ip += 2
                    // A distance of exactly zero here is the end-of-stream marker — the
                    // only terminator the format has.
                    if raw == 0 { return out }
                    try copyMatch(distance: raw + 0x4000, length: length + 2)
                } else {
                    let distance = 1 + (token >> 2) + (try next() << 2)
                    try copyMatch(distance: distance, length: 2)
                }

                token = try trailingLiterals()
                if token == 0 { continue outer }
                pendingLiterals = true
            }
        }
    }
}
