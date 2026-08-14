// SPDX-License-Identifier: Apache-2.0
// HexAddress.swift - Parse a user-entered address/offset for the viewer's "Go To".
//
// Accepts hex with a 0x / $ prefix or an `h` suffix, binary 0b, octal 0o, otherwise
// decimal — and arithmetic over any mix of those (F-400). Used by the Lister's Ctrl+G
// in hex mode (offset) and as a line number in text mode. Pure and IO-free so it is
// unit-testable.

import Foundation

public enum HexAddress {
    /// Parse `input` to a non-negative offset, or nil if malformed.
    /// "0x1A" / "$1a" / "1Ah" → 26 (hex); "26" → 26 (decimal);
    /// "0x1000 + 15 + 1" → 4112 (an expression, see ``OffsetExpression``).
    ///
    /// Kept as the entry point every Go To dialog already called, so the whole feature is one
    /// delegation rather than three call sites learning a new name.
    public static func parse(_ input: String) -> Int64? {
        OffsetExpression.evaluate(input)
    }
}
