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
        let source = "do shell script \"\(appleScriptEscaped(command))\" with administrator privileges"
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
    nonisolated static func shellQuote(_ path: String) -> String { ShellQuoting.quote(path) }

    /// `command` escaped for embedding inside an AppleScript string literal.
    ///
    /// A name reaching this point has already been through `shellQuote`, so it is wrapped in single
    /// quotes — which AppleScript does not treat specially. What is left is the two characters an
    /// AppleScript literal itself reads: the backslash and the double quote. The backslash must be
    /// doubled *first*, or the escapes added for the quotes get escaped in turn.
    ///
    /// This is its own function so the test can run the real rule rather than a copy of it. The
    /// escaping and the quoting were written apart from each other, and this is the one path in the
    /// app where getting their composition wrong hands a file name to a root shell.
    nonisolated static func appleScriptEscaped(_ command: String) -> String {
        command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
