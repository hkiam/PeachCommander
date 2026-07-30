// HexFormatter.swift - Hex-dump row rendering for the Lister hex mode
// (I07). Pure formatting: given a chunk of bytes and its file offset,
// produces one classic hex-dump line (offset, hex columns, ASCII gutter).

import Foundation

/// Formats rows for the hex-mode viewer.
public enum HexFormatter {
    private static let asciiPrintableRange: ClosedRange<UInt8> = 0x20...0x7e

    /// Format a single hex row.
    ///
    /// The layout is: an 8-hex-digit (minimum width, lowercase) offset, two
    /// spaces, `bytesPerRow` space-separated lowercase hex byte columns
    /// (a missing column, when `bytes.count < bytesPerRow`, is rendered as
    /// two spaces so all rows stay aligned), two more spaces, then an ASCII
    /// gutter of exactly `bytesPerRow` characters: a printable byte
    /// (`0x20...0x7e`) renders as itself, a non-printable byte renders as
    /// `.`, and a missing column renders as a space.
    public static func row(bytes: [UInt8], offset: Int64, bytesPerRow: Int = 16) -> String {
        let offsetHex = hexString(for: offset, minDigits: 8)

        var hexColumns: [String] = []
        var asciiChars: [Character] = []
        hexColumns.reserveCapacity(bytesPerRow)
        asciiChars.reserveCapacity(bytesPerRow)

        for i in 0..<bytesPerRow {
            if i < bytes.count {
                let byte = bytes[i]
                hexColumns.append(hexString(for: byte))
                if asciiPrintableRange.contains(byte) {
                    asciiChars.append(Character(UnicodeScalar(byte)))
                } else {
                    asciiChars.append(".")
                }
            } else {
                hexColumns.append("  ")
                asciiChars.append(" ")
            }
        }

        let hexPart = hexColumns.joined(separator: " ")
        let asciiPart = String(asciiChars)

        return "\(offsetHex)  \(hexPart)  \(asciiPart)"
    }

    private static func hexString(for byte: UInt8) -> String {
        let digits = "0123456789abcdef"
        let hi = digits.index(digits.startIndex, offsetBy: Int(byte >> 4))
        let lo = digits.index(digits.startIndex, offsetBy: Int(byte & 0x0f))
        return String([digits[hi], digits[lo]])
    }

    private static func hexString(for value: Int64, minDigits: Int) -> String {
        var hex = String(value, radix: 16)
        if hex.count < minDigits {
            hex = String(repeating: "0", count: minDigits - hex.count) + hex
        }
        return hex
    }
}
