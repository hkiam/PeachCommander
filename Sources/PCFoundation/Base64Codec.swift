// SPDX-License-Identifier: Apache-2.0
// Base64Codec.swift - Base64 encode/decode for the Encode/Decode feature (SPEC-016 §5).
//
// Thin, well-defined wrapper over Foundation so callers get a stable API with
// MIME line-wrapping control. Output matches RFC 4648 / the system `base64` tool.

import Foundation

public enum Base64Codec {
    /// Encode bytes to a Base64 string. When `wrap` is true, lines are wrapped at
    /// 76 characters with LF terminators (MIME style, like `base64`).
    public static func encode(_ data: Data, wrap: Bool = true) -> String {
        if wrap {
            return data.base64EncodedString(options: [.lineLength76Characters, .endLineWithLineFeed])
        }
        return data.base64EncodedString()
    }

    /// Decode a Base64 string, ignoring whitespace/newlines. Returns nil if the
    /// input is not valid Base64.
    public static func decode(_ text: String) -> Data? {
        Data(base64Encoded: text, options: .ignoreUnknownCharacters)
    }
}

/// Encodes a file's worth of bytes without holding them.
///
/// The whole-buffer functions above are right for a clipboard and wrong for a file: encoding reads
/// everything into memory, builds a string a third larger again, and then copies that to bytes — for
/// a large file that is several times its size at once, on a path a user reaches from the panel with
/// one keystroke.
///
/// Concatenation is exact as long as each chunk handed to Foundation is a multiple of three bytes,
/// because that is when Base64 needs no padding. Wrapping falls out of the same arithmetic: 57 source
/// bytes are exactly 76 output characters, one line. The output is byte-identical to
/// `Base64Codec.encode` — pinned by a test over every length from 0 to a few hundred, because "close
/// enough" in an encoder is a file that will not decode.
public struct Base64StreamEncoder {
    /// 57 bytes → 76 characters → one wrapped line. Times 1024 so a chunk is a useful size.
    private static let group = 57 * 1024
    private let wrap: Bool
    private var carry = Data()
    private var wroteAnything = false

    public init(wrap: Bool = true) { self.wrap = wrap }

    /// The encoding of as much of the input so far as can be finished without padding.
    public mutating func encode(_ data: Data) -> String {
        carry.append(data)
        guard carry.count >= Self.group else { return "" }
        let take = (carry.count / Self.group) * Self.group
        let block = carry.prefix(take)
        carry.removeFirst(take)
        return emit(Data(block))
    }

    /// The tail: the bytes that were not a whole group, and the padding they need.
    public mutating func finish() -> String {
        let tail = carry
        carry.removeAll()
        return emit(tail)
    }

    private mutating func emit(_ block: Data) -> String {
        guard !block.isEmpty else { return "" }
        let text = wrap
            ? block.base64EncodedString(options: [.lineLength76Characters, .endLineWithLineFeed])
            : block.base64EncodedString()
        // Foundation does not end a wrapped block with a newline, so the joins between blocks are
        // this encoder's to make — and only *between* them, or the output would differ from the
        // whole-buffer version by one trailing byte.
        let separator = (wrap && wroteAnything) ? "\n" : ""
        wroteAnything = true
        return separator + text
    }
}

/// Decodes a Base64 stream without holding it.
///
/// Four characters are three bytes, so any multiple of four can be decoded and thrown away. Anything
/// outside the alphabet is skipped, which is what `.ignoreUnknownCharacters` does for the
/// whole-buffer version — a wrapped file is nothing but alphabet and newlines. Padding ends the data:
/// what follows it is not more data, and treating it as such is how a decoder invents bytes.
public struct Base64StreamDecoder {
    private var carry: [UInt8] = []
    private var sawPadding = false
    private var failed = false

    public init() {}

    /// Decode what can be decoded of `text`; nil once the input has been found invalid.
    public mutating func decode(_ text: String) -> Data? {
        guard !failed else { return nil }
        for ch in text.utf8 {
            if ch == UInt8(ascii: "=") { sawPadding = true; continue }
            guard !sawPadding else { continue }              // nothing follows the padding
            if Self.isAlphabet(ch) { carry.append(ch) }
        }
        guard carry.count >= 4096 else { return Data() }
        let take = (carry.count / 4) * 4
        let block = String(decoding: carry.prefix(take), as: UTF8.self)
        carry.removeFirst(take)
        guard let out = Data(base64Encoded: block) else { failed = true; return nil }
        return out
    }

    /// The remainder, with whatever padding it needs. Nil if the input was not valid Base64.
    public mutating func finish() -> Data? {
        guard !failed else { return nil }
        guard !carry.isEmpty else { return Data() }
        var block = String(decoding: carry, as: UTF8.self)
        carry.removeAll()
        // A stream can end mid-quantum only if it was truncated; padding it back is what the
        // whole-buffer decoder does through `.ignoreUnknownCharacters`, and refusing here would
        // reject files the old path accepted.
        while block.count % 4 != 0 { block += "=" }
        guard let out = Data(base64Encoded: block) else { return nil }
        return out
    }

    private static func isAlphabet(_ ch: UInt8) -> Bool {
        (ch >= UInt8(ascii: "A") && ch <= UInt8(ascii: "Z"))
            || (ch >= UInt8(ascii: "a") && ch <= UInt8(ascii: "z"))
            || (ch >= UInt8(ascii: "0") && ch <= UInt8(ascii: "9"))
            || ch == UInt8(ascii: "+") || ch == UInt8(ascii: "/")
    }
}

/// Decodes a hex stream without holding it. Two characters are one byte, whitespace is skipped, and
/// anything else means the payload was not hex after all.
public struct HexStreamDecoder {
    private var hi: UInt8?
    private var failed = false

    public init() {}

    public mutating func decode(_ text: String) -> Data? {
        guard !failed else { return nil }
        var out = Data()
        for ch in text.utf8 {
            if ch == 0x20 || ch == 0x09 || ch == 0x0A || ch == 0x0D { continue }
            let value: UInt8
            switch ch {
            case 0x30...0x39: value = ch - 0x30
            case 0x41...0x46: value = ch - 0x41 + 10
            case 0x61...0x66: value = ch - 0x61 + 10
            default: failed = true; return nil
            }
            if let high = hi { out.append((high << 4) | value); hi = nil } else { hi = value }
        }
        return out
    }

    /// Nil for a payload with an odd number of digits — half a byte is not a byte, and the
    /// whole-buffer `decodeHex` refuses the same input.
    public mutating func finish() -> Data? {
        guard !failed, hi == nil else { return nil }
        return Data()
    }
}
