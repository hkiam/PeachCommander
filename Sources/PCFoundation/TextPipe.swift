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

/// Run a command with a deadline and hand back both streams.
///
/// Split out of `TextPipe` below rather than copied next to its one caller: a watchdog that has to
/// SIGTERM, then SIGKILL, while two pipes are drained on their own queues is too much subtle
/// machinery to have twice, and here it can be tested — which the copy in `ACLStore` could not be,
/// PCApp having no test target.
///
/// `TextPipe` keeps its own loop and does not call this: it writes the selection to stdin, and needs
/// `F_SETNOSIGPIPE` on that descriptor for a filter like `head -1` that stops reading. Nothing here
/// has a stdin, so none of that applies — and no shell either, which matters for the callers that
/// pass a *file path* as an argument: through `zsh -lc` a name with a quote in it is an injection.
public enum BoundedProcess {
    /// Launch `executable` with `arguments` and return its output, or nil when it could not be
    /// started or outlived `timeout` seconds.
    ///
    /// Nil for both, deliberately: a caller that cannot tell "it failed" from "it said nothing" is
    /// how an unreadable ACL came to look like a file without one.
    public static func run(_ executable: String, _ arguments: [String],
                           timeout: Int) -> (out: String, err: String)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stdout = Pipe(), stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do { try process.run() } catch { return nil }

        // Both streams on their own queue, not one after the other: reading stdout to EOF while the
        // process fills stderr is a deadlock. The watchdog would turn that into a timeout, but it is
        // cheaper not to have the shape at all.
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
            // SIGTERM first, then the backstop for something that ignores it.
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(timeout), execute: watchdog)
        process.waitUntilExit()
        watchdog.cancel()
        group.wait()

        if timedOut { return nil }
        return (String(decoding: outData, as: UTF8.self), String(decoding: errData, as: UTF8.self))
    }
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
        // A filter may stop reading before it has taken everything. `head -1` does it by design, and
        // so does any command that fails early — at which point writing the rest hits a pipe with no
        // reader, and the default answer to that is SIGPIPE, which kills the whole application.
        //
        // `F_SETNOSIGPIPE` turns that into a plain EPIPE on this one descriptor, which is what the
        // situation actually is: the tool did not want the rest. Set on the descriptor rather than by
        // ignoring the signal process-wide, because a library has no business changing how the whole
        // application answers a signal.
        //
        // Found through a test that failed once in CI and never locally — on a fast machine the text
        // fits in the pipe buffer before the tool exits, so nobody notices. The bug was never the
        // test's: piping a selection through `head -1` crashed the app.
        var nosigpipe: Int32 = 1
        _ = fcntl(stdin.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, nosigpipe)
        nosigpipe = 0
        DispatchQueue.global(qos: .userInitiated).async {
            try? stdin.fileHandleForWriting.write(contentsOf: input)
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
