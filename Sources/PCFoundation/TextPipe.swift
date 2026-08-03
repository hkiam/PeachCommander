// SPDX-License-Identifier: Apache-2.0
// TextPipe.swift - Send text through a shell command and take the result back (F-356).
//
// The editor's most useful power feature is the one it does not have to write: `sort -u`, `jq .`,
// `column -t`, `base64 -d`, `openssl x509 -noout -text`, `awk '{print $2}'`. An administrator already
// knows those commands, and the editor's job is to hand them a selection and accept what comes back.
//
// Neither of the two runners already in the app fits:
//
//   * `ExternalToolFormatter` is exec + argv on purpose — a formatter's arguments must not be
//     re-interpreted for quoting or globbing. But here the user *types a command line*, and `awk
//     '{print $2}' | sort` has to mean what it says.
//   * `ShellExecutor` runs a line through zsh, but merges stdout and stderr and offers no stdin. Both
//     matter here: stdout becomes the replacement text, stderr is the message shown when it fails, and
//     confusing the two would paste a warning into the document.
//
// So: a shell, separate streams, text in, and a deadline — a filter that reads forever must not take
// the editor with it.

import Foundation

/// What piping text through a command produced.
public enum TextPipeResult: Equatable, Sendable {
    /// The command succeeded; this is what it wrote to stdout.
    case output(String)
    /// The command ran and failed. `message` is its stderr, which is the useful part.
    case failed(exitCode: Int32, message: String)
    /// The command did not finish in time and was stopped.
    case timedOut(seconds: Int)
}

public enum TextPipe {
    /// Seconds a command may take before it is stopped.
    ///
    /// Generous enough for a real filter over a large file, short enough that a command waiting on
    /// something that will never come does not look like a hung editor.
    public static let defaultTimeout = 20

    /// Run `command` with `text` on stdin and return what it wrote.
    ///
    /// Synchronous: the caller is a menu action that already blocks, and threading here would only
    /// move the problem while making the undo grouping harder to get right.
    public static func run(_ command: String, over text: String,
                          workingDirectory: String? = nil,
                          timeout: Int = defaultTimeout) -> TextPipeResult {
        let process = Process()
        // `zsh -lc`, matching the app's command line, so the user's aliases, functions and PATH work
        // the way they do in their own terminal. An administrator's `alias k=kubectl` should apply.
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        if let workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        do { try process.run() } catch {
            return .failed(exitCode: 127, message: error.localizedDescription)
        }

        // Write and read concurrently. A filter that emits more than a pipe buffer while we are still
        // writing deadlocks otherwise — and that is exactly the large-selection case this is for.
        let input = Data(text.utf8)
        DispatchQueue.global(qos: .userInitiated).async {
            stdin.fileHandleForWriting.write(input)
            try? stdin.fileHandleForWriting.close()
        }
        var outData = Data(), errData = Data()
        let group = DispatchGroup()
        for (pipe, sink) in [(stdout, { outData.append($0) }), (stderr, { errData.append($0) })] {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                sink(pipe.fileHandleForReading.readDataToEndOfFile())
                group.leave()
            }
        }

        var timedOut = false
        let watchdog = DispatchWorkItem {
            guard process.isRunning else { return }
            timedOut = true
            process.terminate()
            // SIGTERM first, then the backstop for a command that ignores it.
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(timeout), execute: watchdog)
        process.waitUntilExit()
        watchdog.cancel()
        group.wait()

        if timedOut { return .timedOut(seconds: timeout) }
        let message = String(data: errData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            return .failed(exitCode: process.terminationStatus,
                           message: message.isEmpty ? "exit \(process.terminationStatus)" : message)
        }
        // Invalid UTF-8 is a failure rather than a silent replacement: a command that emits binary
        // would otherwise put replacement characters into the user's file.
        guard let result = String(data: outData, encoding: .utf8) else {
            return .failed(exitCode: 0, message: "the command produced output that is not text")
        }
        return .output(result)
    }
}
