// HexAddress.swift - Parse a user-entered address/offset for the viewer's "Go To".
//
// Accepts hex with a 0x / $ prefix or an `h` suffix, otherwise decimal. Used by the
// Lister's Ctrl+G in hex mode (offset) and, for plain decimals, as a line number in
// text mode. Pure and IO-free so it is unit-testable.

import Foundation

public enum HexAddress {
    /// Parse `input` to a non-negative offset, or nil if malformed.
    /// "0x1A" / "$1a" / "1Ah" → 26 (hex); "26" → 26 (decimal).
    public static func parse(_ input: String) -> Int64? {
        var s = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !s.isEmpty else { return nil }
        var radix = 10
        if s.hasPrefix("0x") { s = String(s.dropFirst(2)); radix = 16 }
        else if s.hasPrefix("$") { s = String(s.dropFirst()); radix = 16 }
        else if s.hasSuffix("h") { s = String(s.dropLast()); radix = 16 }
        guard !s.isEmpty, let value = Int64(s, radix: radix), value >= 0 else { return nil }
        return value
    }
}
