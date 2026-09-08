// SPDX-License-Identifier: Apache-2.0
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

    /// Bytes per encoded line, which both formats fix at 45 — fifteen 3-byte groups, sixty symbols.
    static let lineBytes = 45

    /// One encoded line: the length symbol, the payload, and the newline.
    ///
    /// Lifted out of `encode` so the streaming encoder emits the same bytes rather than its own idea
    /// of them. `block` must be at most `lineBytes` long.
    static func line(_ block: Data, variant: Variant) -> String {
        let bytes = [UInt8](block)
        var line = [symbol(UInt8(bytes.count), variant)]
        var j = 0
        while j < bytes.count {
            let b0 = bytes[j]
            let b1 = j + 1 < bytes.count ? bytes[j + 1] : 0
            let b2 = j + 2 < bytes.count ? bytes[j + 2] : 0
            line.append(symbol(b0 >> 2, variant))
            line.append(symbol(((b0 << 4) | (b1 >> 4)) & 0x3f, variant))
            line.append(symbol(((b1 << 2) | (b2 >> 6)) & 0x3f, variant))
            line.append(symbol(b2 & 0x3f, variant))
            j += 3
        }
        return String(decoding: line, as: UTF8.self) + "\n"
    }

    /// The zero-length line that ends the payload, and the `end` line after it.
    static func terminator(variant: Variant) -> String {
        String(decoding: [symbol(0, variant)], as: UTF8.self) + "\nend\n"
    }

    static func header(filename: String, mode: String) -> String {
        "begin \(mode) \(filename)\n"
    }

    /// Decode one line's payload, or nil if its symbols are not in the alphabet.
    ///
    /// Also lifted out, so the whole-text and the streaming decoder cannot disagree about what a
    /// line means. Returns nil for the terminator's zero length as well — the callers treat that as
    /// the end rather than as data, which is why they check the length before asking.
    static func decodeLine(_ line: [UInt8], length: UInt8, variant: Variant) -> Data? {
        var out = [UInt8]()
        var produced = 0
        var k = 1
        while produced < Int(length) {
            guard k + 3 <= line.count,
                  let c0 = value(line[k], variant), let c1 = value(line[k + 1], variant),
                  let c2 = value(line[k + 2], variant), let c3 = value(line[k + 3], variant) else { return nil }
            let bytes = [(c0 << 2) | (c1 >> 4), (c1 << 4) | (c2 >> 2), (c2 << 6) | c3]
            for b in bytes where produced < Int(length) { out.append(b); produced += 1 }
            k += 4
        }
        return Data(out)
    }

    /// The length this line claims, or nil if its first symbol is not in the alphabet.
    static func lineLength(_ line: [UInt8], variant: Variant) -> UInt8? {
        guard let first = line.first else { return nil }
        return value(first, variant)
    }

    /// Encode `data` as a full uu/xx text with `begin <mode> <name>` / `end` frame.
    public static func encode(_ data: Data, variant: Variant,
                              filename: String = "file", mode: String = "644") -> String {
        var out = header(filename: filename, mode: mode)
        var i = 0
        while i < data.count {
            let end = min(i + lineBytes, data.count)
            out += line(data.subdata(in: i..<end), variant: variant)
            i = end
        }
        out += terminator(variant: variant)
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
            guard let lineLen = lineLength(line, variant: variant) else { continue }
            if lineLen == 0 { break }
            guard let decoded = decodeLine(line, length: lineLen, variant: variant) else { return nil }
            out.append(contentsOf: decoded)
        }
        return Data(out)
    }
}

/// Encodes a file's worth of bytes as uu/xx without holding them.
///
/// The whole-buffer `UUCodec.encode` is right for a clipboard and wrong for a file, the same way
/// `Base64Codec.encode` was: it holds the payload and a text a third larger again. These are legacy
/// formats normally used on small things — but the app offers them on whatever is selected in the
/// panel, with one keystroke, and "normally small" is not a size limit.
///
/// The format makes this easy: both variants fix 45 payload bytes per line, so any multiple of 45
/// can be emitted and forgotten. The lines themselves come from `UUCodec.line`, so the output is
/// byte-identical to the whole-buffer version — pinned by a test over every length from 0 to a few
/// hundred, because "close enough" in an encoder is a file that will not decode.
public struct UUStreamEncoder {
    private let variant: UUCodec.Variant
    private let headerText: String
    private var carry = Data()
    private var wroteHeader = false

    public init(variant: UUCodec.Variant, filename: String = "file", mode: String = "644") {
        self.variant = variant
        self.headerText = UUCodec.header(filename: filename, mode: mode)
    }

    /// The encoding of as many whole lines as the input so far allows.
    public mutating func encode(_ data: Data) -> String {
        var out = takeHeader()
        carry.append(data)
        while carry.count >= UUCodec.lineBytes {
            let block = carry.prefix(UUCodec.lineBytes)
            carry.removeFirst(UUCodec.lineBytes)
            out += UUCodec.line(Data(block), variant: variant)
        }
        return out
    }

    /// The short final line, the zero-length terminator and `end`.
    ///
    /// Emits the header too if nothing else has: an empty file still gets a valid frame, which is
    /// what the whole-buffer version produces for empty input.
    public mutating func finish() -> String {
        var out = takeHeader()
        if !carry.isEmpty {
            out += UUCodec.line(carry, variant: variant)
            carry.removeAll()
        }
        return out + UUCodec.terminator(variant: variant)
    }

    private mutating func takeHeader() -> String {
        guard !wroteHeader else { return "" }
        wroteHeader = true
        return headerText
    }
}

/// Decodes a uu/xx stream without holding it.
///
/// Line-oriented, which is what makes it possible: every line carries its own length, so a line that
/// has arrived whole can be decoded and thrown away. Text is buffered only up to the next newline.
///
/// The frame is optional in the same way `UUCodec.decode` allows: a leading `begin` is honoured if
/// present and a payload without one starts at the first data line. `end`, or a zero-length line,
/// ends the payload — and anything after it is not more data.
public struct UUStreamDecoder {
    private let variant: UUCodec.Variant
    private var pending = ""
    private var started = false
    private var done = false
    private var failed = false

    public init(variant: UUCodec.Variant) { self.variant = variant }

    /// Decode whatever whole lines `text` completes; nil once the input has been found invalid.
    public mutating func decode(_ text: String) -> Data? {
        guard !failed else { return nil }
        guard !done else { return Data() }
        pending += text
        var out = Data()
        while let newline = pending.firstIndex(of: "\n") {
            let rawLine = String(pending[pending.startIndex..<newline])
            pending = String(pending[pending.index(after: newline)...])
            guard let piece = take(rawLine) else { failed = true; return nil }
            out.append(piece)
            if done { break }
        }
        return out
    }

    /// The last line, if the input did not end with a newline.
    public mutating func finish() -> Data? {
        guard !failed else { return nil }
        guard !done, !pending.isEmpty else { return Data() }
        let rest = pending
        pending = ""
        guard let piece = take(rest) else { failed = true; return nil }
        return piece
    }

    /// One line, with the frame rules applied. Nil means the line was malformed.
    private mutating func take(_ rawLine: String) -> Data? {
        let line = [UInt8](rawLine.utf8)
        if !started {
            if rawLine.hasPrefix("begin") { started = true; return Data() }
            if line.isEmpty { return Data() }
            started = true          // no header: the payload starts here
        }
        if rawLine == "end" { done = true; return Data() }
        guard let length = UUCodec.lineLength(line, variant: variant) else { return Data() }
        if length == 0 { done = true; return Data() }
        return UUCodec.decodeLine(line, length: length, variant: variant)
    }
}
