// SPDX-License-Identifier: Apache-2.0
// PrivilegedRunner.swift - Run a shell command as administrator (F-099)
//
// The TC-style "as administrator" flow. When a file operation fails because the
// user lacks permission (EPERM on a root-owned file/folder), the app can offer
// to retry the equivalent shell command with administrator privileges. This uses
// AppleScript's `do shell script … with administrator privileges`, which shows
// the standard macOS authorization dialog — no privileged helper tool to install
// or maintain. It runs synchronously (blocking on the auth prompt), so callers
// invoke it from a modal/menu context, not the operation queue.

import AppKit
import PCFoundation

@MainActor
enum PrivilegedRunner {
    private static let logger = PCFoundationLogger.logger

    /// Runs `command` via `/bin/sh` with administrator privileges. Returns nil on
    /// success, or a human-readable error message on failure / cancellation.
    @discardableResult
    static func runShell(_ command: String) -> String? {
        // Escape for embedding inside the AppleScript string literal.
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        guard let script = NSAppleScript(source: source) else {
            return String(localized: "Could not build the privileged command.")
        }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let msg = (errorInfo[NSAppleScript.errorMessage] as? String)
                ?? String(localized: "The administrator operation was cancelled or failed.")
            logger.error("Privileged command failed: \(msg, privacy: .public)")
            return msg
        }
        logger.info("Privileged command completed")
        return nil
    }

    /// Quotes a POSIX path for safe inclusion in a `/bin/sh` command line.
    static func shellQuote(_ path: String) -> String { ShellQuoting.quote(path) }
}
