// SPDX-License-Identifier: Apache-2.0
// TextFormatter.swift - The formatting extension point (replaces StructuredTextFormatter's
// hardcoded JSON/XML pair).
//
// One protocol, many implementations, resolved by file extension through
// FormatterRegistry. Built-ins wrap what the platform already parses; external
// formatters shell out to a command-line tool; a plugin formatter routes to the
// contrib `PcInvokeTool` ABI. Adding a format means adding a type, not editing a switch.

import Foundation

/// Why a formatter could not produce output. Distinguishing these matters: the UI should
/// say "not valid JSON" differently from "jq is not installed", and `unchanged` must not
/// look like a failure.
public enum FormatError: Error, Equatable, Sendable {
    /// The input is not valid for this format (the analogue of the old `nil`).
    case invalidInput(String)
    /// Formatting would not change anything, so there is nothing to apply.
    case unchanged
    /// An external tool is required but not installed.
    case toolNotFound(String)
    /// The external tool ran but failed; carries its diagnostics.
    case toolFailed(tool: String, exitCode: Int32, message: String)
    /// The format is recognised but no formatter is available for it.
    case noFormatterAvailable(extension: String)

    /// A message suitable for a status line — short, and specific about the cause.
    public var userMessage: String {
        switch self {
        case .invalidInput(let kind):
            return "Not valid \(kind)"
        case .unchanged:
            return "Already formatted"
        case .toolNotFound(let tool):
            return "\(tool) is not installed"
        case .toolFailed(let tool, let code, let message):
            let detail = message.split(separator: "\n").first.map(String.init) ?? ""
            return detail.isEmpty ? "\(tool) failed (exit \(code))" : "\(tool): \(detail)"
        case .noFormatterAvailable(let ext):
            return "No formatter for .\(ext)"
        }
    }
}

/// A formatter for one or more file types.
///
/// `format` returns the formatted text or throws. Throwing `.unchanged` when the input is
/// already canonical lets callers avoid pointlessly replacing the view's contents.
public protocol TextFormatter: Sendable {
    /// Human-readable name, shown in the status line and in errors ("JSON", "yq").
    var name: String { get }
    /// Lowercased extensions this formatter handles, without the dot.
    var supportedExtensions: [String] { get }
    /// Whether this formatter can run right now — false for an external tool that is not
    /// installed, so the registry can fall through to the next candidate.
    var isAvailable: Bool { get }

    func format(_ text: String) throws -> String
}

public extension TextFormatter {
    /// Most formatters are always available; external ones override this.
    var isAvailable: Bool { true }

    func handles(extension ext: String) -> Bool {
        supportedExtensions.contains(ext.lowercased())
    }
}
