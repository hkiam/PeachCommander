// SPDX-License-Identifier: Apache-2.0
// EncodeDecodeEngine.swift - Base64 encode/decode of files over the VFS (SPEC-016 §5).
//
// Reads a file through the VFS, transforms it, and writes the result back through
// the VFS, so it works on local disk and network locations alike.

import Foundation
import PCFoundation
import PCVFS

public enum EncodeDecodeError: Error, Equatable {
    case notValidBase64
    case notValidUUXX
    /// Something with the output's name is already there. The engine cannot ask; the caller can.
    ///
    /// Decoding is where this bites, and the panel makes it the ordinary case rather than an unlucky
    /// one: the command drops a known encoded extension, so `report.pdf.b64` targets `report.pdf` —
    /// the file still sitting next to it. Measured before this existed: it was replaced without a
    /// word. Encoding never had the problem, because that side goes through a save panel, which asks.
    case targetExists(String)
}

public enum EncodeDecodeEngine {
    /// Base64-encode `src` into `dst` (76-char MIME wrapping by default).
    /// Base64-encode `src` into `dst` (76-char MIME wrapping by default).
    ///
    /// Streamed. It used to read the file whole, build a string a third larger again and copy that to
    /// bytes — several times the file's size in memory at once, on a path one keystroke away in the
    /// panel. `Base64StreamEncoder` produces byte-identical output; that is what its test is for.
    public static func encodeBase64(_ src: VFSPath, to dst: VFSPath, on fs: VirtualFileSystem,
                                    wrap: Bool = true, overwrite: Bool = false) async throws {
        try await guardTarget(dst, on: fs, overwrite: overwrite)
        var encoder = Base64StreamEncoder(wrap: wrap)
        try await stream(src, to: dst, on: fs) { chunk in
            Data(encoder.encode(chunk).utf8)
        } finish: {
            Data(encoder.finish().utf8)
        }
    }

    /// Decode Base64 file `src` into `dst`.
    /// Decode Base64 file `src` into `dst`. Streamed, for the same reason as the encoder.
    public static func decodeBase64(_ src: VFSPath, to dst: VFSPath, on fs: VirtualFileSystem,
                                    overwrite: Bool = false) async throws {
        try await guardTarget(dst, on: fs, overwrite: overwrite)
        var decoder = Base64StreamDecoder()
        var invalid = false
        try await stream(src, to: dst, on: fs) { chunk in
            guard let out = decoder.decode(String(decoding: chunk, as: UTF8.self)) else {
                invalid = true; return Data()
            }
            return out
        } finish: {
            decoder.finish() ?? { invalid = true; return Data() }()
        }
        if invalid { throw EncodeDecodeError.notValidBase64 }
    }

    /// uuencode/xxencode `src` into `dst` (F-096).
    ///
    /// Streamed, like the other three. It was read whole with the reasoning that the frame carries a
    /// length byte per line and these are legacy formats used on small payloads — true, and not a
    /// size limit: the app offers this on whatever is selected in the panel. The format turns out to
    /// make it easy, because both variants fix 45 payload bytes per line, so whole lines can be
    /// emitted and forgotten.
    public static func encodeUUXX(_ src: VFSPath, to dst: VFSPath, on fs: VirtualFileSystem,
                                  variant: UUCodec.Variant, overwrite: Bool = false) async throws {
        try await guardTarget(dst, on: fs, overwrite: overwrite)
        let name = (src.path as NSString).lastPathComponent
        var encoder = UUStreamEncoder(variant: variant, filename: name.isEmpty ? "file" : name)
        try await stream(src, to: dst, on: fs) { chunk in
            Data(encoder.encode(chunk).utf8)
        } finish: {
            Data(encoder.finish().utf8)
        }
    }

    /// Decode an encoded file, auto-detecting the scheme: a `begin ` frame → uu/xx
    /// (by alphabet); a payload of only hex digits → hex; otherwise Base64.
    public static func decodeAuto(_ src: VFSPath, to dst: VFSPath, on fs: VirtualFileSystem,
                                  overwrite: Bool = false) async throws {
        // Asked once, up front: the branches below each write, and a question per branch would be
        // four chances to forget one.
        try await guardTarget(dst, on: fs, overwrite: overwrite)

        // The scheme is decided from the head of the file, then the file is read again by whichever
        // decoder that picked. Reading twice costs a second open; reading once cost the whole file in
        // memory, which for the schemes that can stream is the thing worth avoiding.
        let head = try await readPrefix(src, on: fs, bytes: 8 * 1024)
        let headText = String(decoding: head, as: UTF8.self)
        if !(headText.hasPrefix("begin ") || headText.contains("\nbegin ")) {
            if isHexPayload(headText) {
                var decoder = HexStreamDecoder()
                var invalid = false
                try await stream(src, to: dst, on: fs) { chunk in
                    guard let out = decoder.decode(String(decoding: chunk, as: UTF8.self)) else {
                        invalid = true; return Data()
                    }
                    return out
                } finish: {
                    decoder.finish() ?? { invalid = true; return Data() }()
                }
                if invalid { throw EncodeDecodeError.notValidBase64 }
                return
            }
            try await decodeBase64(src, to: dst, on: fs, overwrite: true)
            return
        }

        // uu/xx. The two share the frame and differ only in the alphabet, so the variant has to be
        // settled before a streaming decoder can start — it cannot try one and fall back to the
        // other halfway through a file. Decided from the head that was already read, cut at its last
        // newline so every line in it is whole: uu first, then xx, which is the precedence the
        // whole-text version had.
        let whole = headText.hasSuffix("\n") ? headText : String(headText[..<(headText.lastIndex(of: "\n") ?? headText.startIndex)])
        let variant: UUCodec.Variant
        if let probe = UUCodec.decode(whole, variant: .uu), !probe.isEmpty {
            variant = .uu
        } else if let probe = UUCodec.decode(whole, variant: .xx), !probe.isEmpty {
            variant = .xx
        } else {
            throw EncodeDecodeError.notValidUUXX
        }
        var decoder = UUStreamDecoder(variant: variant)
        var invalid = false
        try await stream(src, to: dst, on: fs) { chunk in
            guard let out = decoder.decode(String(decoding: chunk, as: UTF8.self)) else {
                invalid = true; return Data()
            }
            return out
        } finish: {
            decoder.finish() ?? { invalid = true; return Data() }()
        }
        if invalid { throw EncodeDecodeError.notValidUUXX }
    }

    /// Whether a payload is nothing but hex digits — the test that used to be `decodeHex` returning
    /// non-nil over the whole file, asked of its head instead.
    ///
    /// Hex before Base64: a pure-hex payload is unambiguous, whereas Base64 would happily (wrongly)
    /// decode hex text as its own alphabet.
    static func isHexPayload(_ text: String) -> Bool {
        var digits = 0
        for ch in text.utf8 {
            if ch == 0x20 || ch == 0x09 || ch == 0x0A || ch == 0x0D { continue }
            switch ch {
            case 0x30...0x39, 0x41...0x46, 0x61...0x66: digits += 1
            default: return false
            }
        }
        return digits > 0
    }

    private static func readPrefix(_ path: VFSPath, on fs: VirtualFileSystem, bytes: Int) async throws -> Data {
        let stream = try await fs.openRead(path)
        var data = Data()
        for try await chunk in stream {
            if let d = chunk as? Data { data.append(d) }
            if data.count >= bytes { break }
        }
        try? await stream.close()
        return data.prefix(bytes)
    }

    /// Decode a hex string (whitespace ignored). Returns nil unless the whole
    /// payload is hex digits and an even count — so non-hex input falls through
    /// to Base64 rather than being mis-decoded.
    static func decodeHex(_ text: String) -> Data? {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(text.utf8.count / 2)
        var hi: UInt8? = nil
        for ch in text.utf8 {
            if ch == 0x20 || ch == 0x09 || ch == 0x0A || ch == 0x0D { continue }   // whitespace
            let v: UInt8
            switch ch {
            case 0x30...0x39: v = ch - 0x30           // 0-9
            case 0x41...0x46: v = ch - 0x41 + 10      // A-F
            case 0x61...0x66: v = ch - 0x61 + 10      // a-f
            default: return nil                       // not hex → not applicable
            }
            if let h = hi { bytes.append((h << 4) | v); hi = nil } else { hi = v }
        }
        guard hi == nil, !bytes.isEmpty else { return nil }
        return Data(bytes)
    }

    /// Refuse a target that is already there, unless told otherwise. Pulled out because every entry
    /// point has to ask the same question and the streaming ones ask it before opening anything.
    private static func guardTarget(_ dst: VFSPath, on fs: VirtualFileSystem, overwrite: Bool) async throws {
        if !overwrite, (try? await fs.stat(dst)) != nil {
            throw EncodeDecodeError.targetExists(dst.lastComponent())
        }
    }

    /// Read `src` chunk by chunk, transform each, write it out, then write whatever `finish` has left.
    ///
    /// The transform is synchronous and stateful — an encoder carrying a few bytes between calls — so
    /// nothing here needs to hold more than one chunk of either side.
    private static func stream(_ src: VFSPath, to dst: VFSPath, on fs: VirtualFileSystem,
                               _ transform: (Data) -> Data,
                               finish: () -> Data) async throws {
        let reader = try await fs.openRead(src)
        let writer = try await fs.openWrite(dst, options: WriteOptions())
        do {
            for try await chunk in reader {
                guard let data = chunk as? Data else { continue }
                let out = transform(data)
                if !out.isEmpty { try await writer.write(out) }
            }
            let tail = finish()
            if !tail.isEmpty { try await writer.write(tail) }
        } catch {
            try? await writer.close()
            try? await reader.close()
            throw error
        }
        try await writer.close()
        try? await reader.close()
    }

    private static func readAll(_ path: VFSPath, on fs: VirtualFileSystem) async throws -> Data {
        let stream = try await fs.openRead(path)
        var data = Data()
        for try await chunk in stream { if let d = chunk as? Data { data.append(d) } }
        try? await stream.close()
        return data
    }

    private static func write(_ data: Data, to path: VFSPath, on fs: VirtualFileSystem,
                              overwrite: Bool) async throws {
        if !overwrite, (try? await fs.stat(path)) != nil {
            throw EncodeDecodeError.targetExists(path.lastComponent())
        }
        let writer = try await fs.openWrite(path, options: WriteOptions())
        try await writer.write(data)
        try await writer.close()
    }
}
