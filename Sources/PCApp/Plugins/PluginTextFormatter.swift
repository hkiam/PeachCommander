// SPDX-License-Identifier: Apache-2.0
// PluginTextFormatter.swift - Expose a plugin's declared tool as a TextFormatter.
//
// A plugin becomes a formatter by declaring a tool with `formatsExtensions` in its
// Info.plist PCContributions:
//
//   <key>tools</key>
//   <array>
//     <dict>
//       <key>name</key>              <string>format_swift</string>
//       <key>description</key>       <string>Format Swift source</string>
//       <key>capability</key>        <string>read</string>
//       <key>formatsExtensions</key> <array><string>swift</string></array>
//     </dict>
//   </array>
//
// The host calls it through the existing PcInvokeTool path with
// {"text": …, "extension": …} and takes the returned string as the formatted text. No
// second ABI and no second invocation path: a formatter is a tool with an agreed contract.

import Foundation
import PCFoundation
import PCPluginHost

/// Bridges one plugin tool to the formatter protocol.
struct PluginTextFormatter: TextFormatter {
    let name: String
    let supportedExtensions: [String]
    /// Tool name to invoke (`ToolContribution.name`).
    private let toolName: String
    /// Resolved lazily so a formatter survives plugin reloads; nil host means unavailable.
    private let host: () -> ContributionHost?

    init(toolName: String, displayName: String, extensions: [String], host: @escaping () -> ContributionHost?) {
        self.toolName = toolName
        self.name = displayName
        self.supportedExtensions = extensions.map { $0.lowercased() }
        self.host = host
    }

    var isAvailable: Bool { host() != nil }

    func format(_ text: String) throws -> String {
        guard let host = host() else { throw FormatError.toolNotFound(name) }
        guard let payload = try? JSONSerialization.data(
                withJSONObject: ["text": text, "extension": supportedExtensions.first ?? ""]),
              let json = String(data: payload, encoding: .utf8) else {
            throw FormatError.toolFailed(tool: name, exitCode: 0, message: "could not encode the request")
        }

        // The plugin ABI is synchronous from the caller's point of view, but the registry's
        // invokeTool is async (it gathers host context first). Format runs from a menu
        // action on the main thread, so bridge with a semaphore on a background hop rather
        // than blocking the main queue on itself.
        let box = ResultBox()
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            box.value = await ContributionRegistry.shared.invokeTool(self.toolName,
                                                                     argumentsJson: json, host: host)
            done.signal()
        }
        // A plugin that hangs must not freeze the app: give up and report it instead.
        guard done.wait(timeout: .now() + 10) == .success else {
            throw FormatError.toolFailed(tool: name, exitCode: 0, message: "timed out after 10 s")
        }
        guard let result = box.value, !result.isEmpty else {
            throw FormatError.toolFailed(tool: name, exitCode: 0, message: "returned no text")
        }
        guard result != text else { throw FormatError.unchanged }
        return result
    }

    /// Minimal box so the detached task can hand a value back across the semaphore.
    private final class ResultBox: @unchecked Sendable { var value: String? }
}
