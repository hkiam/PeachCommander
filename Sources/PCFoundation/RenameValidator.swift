// SPDX-License-Identifier: Apache-2.0
// RenameValidator.swift - Validate a single new file name for in-place rename (TODOS #40).
//
// Pure checks for the Shift+F6 rename dialog: a name must be non-empty, must not be
// "." or "..", and must not contain a path separator or NUL. Unit-testable.

import Foundation

public enum RenameValidator {
    public enum Result: Equatable {
        case valid
        case empty
        case reserved            // "." or ".."
        case containsSeparator   // "/" or NUL
    }

    public static func validate(_ name: String) -> Result {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .empty }
        if trimmed == "." || trimmed == ".." { return .reserved }
        if trimmed.contains("/") || trimmed.contains("\0") { return .containsSeparator }
        return .valid
    }

    public static func isValid(_ name: String) -> Bool { validate(name) == .valid }
}
