// UUCodec.swift - uuencode / xxencode encode+decode for the Encode/Decode
// feature (SPEC-016 §5, F-096). Pure Foundation, no UI.
//
// Both formats split the payload into 45-byte lines, encode each 3-byte group
// as four 6-bit symbols, and prefix every line with a length symbol. They differ
// only in the 64-symbol alphabet: uuencode maps a 6-bit value to `value + 0x20`
// (with 0 → 0x60 '`'); xxencode uses an explicit alphabet safe for EBCDIC/mail.

import Foundation

/// Shared uuencode/xxencode implementation, parameterized by alphabet.
public enum UUCodec {
    public enum Variant { case uu, xx }

    private static let xxAlphabet = Array(
        "+-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".utf8)

    /// Map a 6-bit value (0...63) to its output symbol for `variant`.
    private static func symbol(_ v: UInt8, _ variant: Variant) -> UInt8 {
        switch variant {
        case .uu: return v == 0 ? 0x60 : (v & 0x3f) &+ 0x20
        case .xx: return xxAlphabet[Int(v & 0x3f)]
        }
    }

    /// Inverse of `symbol`; returns nil for a symbol not in the alphabet.
    private static func value(_ c: UInt8, _ variant: Variant) -> UInt8? {
        switch variant {
        case .uu:
            if c == 0x60 { return 0 }
            guard c >= 0x20, c <= 0x60 else { return nil }
            return (c &- 0x20) & 0x3f
        case .xx:
            return xxAlphabet.firstIndex(of: c).map { UInt8($0) }
        }
    }

    /// Encode `data` as a full uu/xx text with `begin <mode> <name>` / `end` frame.
    public static func encode(_ data: Data, variant: Variant,
                              filename: String = "file", mode: String = "644") -> String {
        let bytes = [UInt8](data)
        var out = "begin \(mode) \(filename)\n"
        var i = 0
        while i < bytes.count {
            let lineLen = min(45, bytes.count - i)
            var line = [symbol(UInt8(lineLen), variant)]
            var j = i
            while j < i + lineLen {
                let b0 = bytes[j]
                let b1 = j + 1 < i + lineLen ? bytes[j + 1] : 0
                let b2 = j + 2 < i + lineLen ? bytes[j + 2] : 0
                line.append(symbol(b0 >> 2, variant))
                line.append(symbol(((b0 << 4) | (b1 >> 4)) & 0x3f, variant))
                line.append(symbol(((b1 << 2) | (b2 >> 6)) & 0x3f, variant))
                line.append(symbol(b2 & 0x3f, variant))
                j += 3
            }
            out += String(decoding: line, as: UTF8.self) + "\n"
            i += lineLen
        }
        out += String(decoding: [symbol(0, variant)], as: UTF8.self) + "\n"   // zero-length terminator
        out += "end\n"
        return out
    }

    /// Decode uu/xx text (the frame is optional; a leading `begin` line and a
    /// trailing `end`/zero-length line are honored). Returns nil on malformed input.
    public static func decode(_ text: String, variant: Variant) -> Data? {
        var out = [UInt8]()
        var started = false
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = [UInt8](rawLine.utf8)
            if !started {
                if rawLine.hasPrefix("begin") { started = true }
                if rawLine.hasPrefix("begin") || line.isEmpty { continue }
                started = true   // no header: begin decoding at the first data line
            }
            if rawLine == "end" { break }
            guard let first = line.first, let lineLen = value(first, variant) else { continue }
            if lineLen == 0 { break }
            var produced = 0
            var k = 1
            while k + 3 < line.count + 1, produced < Int(lineLen) {
                guard k + 3 <= line.count,
                      let c0 = value(line[k], variant), let c1 = value(line[k + 1], variant),
                      let c2 = value(line[k + 2], variant), let c3 = value(line[k + 3], variant) else { return nil }
                let bytes = [(c0 << 2) | (c1 >> 4), (c1 << 4) | (c2 >> 2), (c2 << 6) | c3]
                for b in bytes where produced < Int(lineLen) { out.append(b); produced += 1 }
                k += 4
            }
        }
        return Data(out)
    }
}
