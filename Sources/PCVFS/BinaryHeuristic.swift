// SPDX-License-Identifier: Apache-2.0
// BinaryHeuristic.swift - Decide whether a byte sample looks binary vs text.
//
// Shared by the Lister's text/hex auto-mode and the Compare-by-Content auto pick:
// a sample counts as binary when more than 5% of its bytes are NULs or control
// bytes below TAB (0x09). Pure and unit-testable.

import Foundation

public enum BinaryHeuristic {
    /// Fraction threshold of non-text bytes above which a sample is "binary".
    public static let threshold = 0.05

    public static func isProbablyBinary(_ sample: [UInt8]) -> Bool {
        guard !sample.isEmpty else { return false }
        let nonText = sample.filter { $0 == 0 || $0 < 9 }.count
        return Double(nonText) / Double(sample.count) > threshold
    }
}
