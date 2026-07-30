// EncodeDecodeEngine.swift - Base64 encode/decode of files over the VFS (SPEC-016 §5).
//
// Reads a file through the VFS, transforms it, and writes the result back through
// the VFS, so it works on local disk and network locations alike.

import Foundation
import PCFoundation
import PCVFS

public enum EncodeDecodeError: Error, Equatable { case notValidBase64, notValidUUXX }

public enum EncodeDecodeEngine {
    /// Base64-encode `src` into `dst` (76-char MIME wrapping by default).
    public static func encodeBase64(_ src: VFSPath, to dst: VFSPath, on fs: VirtualFileSystem,
                                    wrap: Bool = true) async throws {
        let data = try await readAll(src, on: fs)
        let text = Base64Codec.encode(data, wrap: wrap)
        try await write(Data(text.utf8), to: dst, on: fs)
    }

    /// Decode Base64 file `src` into `dst`.
    public static func decodeBase64(_ src: VFSPath, to dst: VFSPath, on fs: VirtualFileSystem) async throws {
        let raw = try await readAll(src, on: fs)
        guard let decoded = Base64Codec.decode(String(decoding: raw, as: UTF8.self)) else {
            throw EncodeDecodeError.notValidBase64
        }
        try await write(decoded, to: dst, on: fs)
    }

    /// uuencode/xxencode `src` into `dst` (F-096).
    public static func encodeUUXX(_ src: VFSPath, to dst: VFSPath, on fs: VirtualFileSystem,
                                  variant: UUCodec.Variant) async throws {
        let data = try await readAll(src, on: fs)
        let name = (src.path as NSString).lastPathComponent
        let text = UUCodec.encode(data, variant: variant, filename: name.isEmpty ? "file" : name)
        try await write(Data(text.utf8), to: dst, on: fs)
    }

    /// Decode an encoded file, auto-detecting the scheme: a `begin ` frame → uu/xx
    /// (by alphabet); a payload of only hex digits → hex; otherwise Base64.
    public static func decodeAuto(_ src: VFSPath, to dst: VFSPath, on fs: VirtualFileSystem) async throws {
        let raw = try await readAll(src, on: fs)
        let text = String(decoding: raw, as: UTF8.self)
        if text.hasPrefix("begin ") || text.contains("\nbegin ") {
            // uu and xx share the frame; try uu first, then xx.
            if let d = UUCodec.decode(text, variant: .uu), !d.isEmpty {
                try await write(d, to: dst, on: fs); return
            }
            if let d = UUCodec.decode(text, variant: .xx), !d.isEmpty {
                try await write(d, to: dst, on: fs); return
            }
            throw EncodeDecodeError.notValidUUXX
        }
        // Hex before Base64: a pure-hex payload is unambiguous, whereas Base64
        // would happily (wrongly) decode hex text as its own alphabet.
        if let hex = decodeHex(text) {
            try await write(hex, to: dst, on: fs); return
        }
        guard let decoded = Base64Codec.decode(text) else { throw EncodeDecodeError.notValidBase64 }
        try await write(decoded, to: dst, on: fs)
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

    private static func readAll(_ path: VFSPath, on fs: VirtualFileSystem) async throws -> Data {
        let stream = try await fs.openRead(path)
        var data = Data()
        for try await chunk in stream { if let d = chunk as? Data { data.append(d) } }
        try? await stream.close()
        return data
    }

    private static func write(_ data: Data, to path: VFSPath, on fs: VirtualFileSystem) async throws {
        let writer = try await fs.openWrite(path, options: WriteOptions())
        try await writer.write(data)
        try await writer.close()
    }
}
