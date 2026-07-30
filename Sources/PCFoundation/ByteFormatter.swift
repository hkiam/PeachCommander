// ByteFormatter.swift - Render a byte range as text in various clipboard formats.
//
// Backs the hex viewer's "copy as…" (SPEC-005, TODOS #5): copy selected/looked-at
// bytes as decoded text, spaced hex, a C array literal, a Python bytes literal, or
// base64. Pure and IO-free so it is fully unit-testable and reusable by the planned
// hex editor.

import Foundation

public enum ByteFormat: String, CaseIterable, Sendable {
    case text, hex, cArray, pythonBytes, base64

    /// Human label for menus.
    public var label: String {
        switch self {
        case .text: return "Text"
        case .hex: return "Hex"
        case .cArray: return "C array"
        case .pythonBytes: return "Python bytes"
        case .base64: return "Base64"
        }
    }
}

public enum ByteFormatter {
    /// Render `bytes` in `format`. `encoding` applies only to `.text` (default UTF-8,
    /// falling back to a lossy decode so it never returns nil).
    public static func format(_ bytes: [UInt8], as format: ByteFormat,
                              encoding: String.Encoding = .utf8) -> String {
        switch format {
        case .text:
            let data = Data(bytes)
            return String(data: data, encoding: encoding) ?? String(decoding: data, as: UTF8.self)
        case .hex:
            return bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        case .cArray:
            let items = bytes.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
            return "{ \(items) }"
        case .pythonBytes:
            let escaped = bytes.map { String(format: "\\x%02x", $0) }.joined()
            return "b'\(escaped)'"
        case .base64:
            return Data(bytes).base64EncodedString()
        }
    }
}
