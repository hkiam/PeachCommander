// SPDX-License-Identifier: Apache-2.0
// ScriptRunner.swift — running AppleScript and JXA (F-477).
//
// Two paths, and one rule rather than a choice, because two paths with no rule means two failure modes
// and no answer to "which one ran?":
//
//   Running a script      →  a SUBPROCESS (`osascript -l <language>`), always, unless the script says
//                            otherwise. A subprocess can be given a hard timeout, cancelled and killed.
//                            A script that loops then costs one dead child process instead of a frozen
//                            file manager.
//   Checking a script     →  OSAKit, always. `OSAScript.compileAndReturnError` reports a syntax error
//                            *with its position* and runs nothing. A subprocess cannot do that usefully:
//                            `osascript` would have to run the script to find out.
//   A structured result   →  OSAKit, opt-in per script (`"mode": "in-process"`). Native descriptor
//                            values instead of text, and a compiled script cached between runs. The
//                            price is that there is no timeout, which the editor says out loud.
//
// **Measured, because it decided the design.** JXA in-process needs JavaScriptCore, loaded through
// `/System/Library/Components/JavaScript.component`. The app runs under the hardened runtime *without*
// `com.apple.security.cs.allow-jit`, so the question was whether that even loads. It does: an ad-hoc
// binary signed with `--options runtime` and this app's exact entitlements compiled and ran both
// AppleScript and JavaScript through OSAKit and returned 42. `disable-library-validation` — already
// present, for third-party plugin dylibs — is what lets the component in. So in-process is offered for
// both languages, and no new entitlement is needed.
//
// The panel state arrives as environment variables, so the common case needs no Apple events and
// therefore no Automation permission prompt. A script that wants more talks to the application, which
// is scriptable in its own right (`Resources/PeachCommander.sdef`); the two halves compose and the
// outbound one needed no extension.

import Foundation
import OSAKit
import PCAutomation   // ScriptRunMode — the model lives where it can be tested

struct ScriptContext {
    var activeDirectory = ""
    var inactiveDirectory = ""
    var cursorName = ""
    var selection: [String] = []

    /// The environment a script is handed. Names spelled out rather than abbreviated: this is read in
    /// somebody's AppleScript a year later, where `PC_ACTIVE_DIR` has to explain itself.
    func environment(selectionFile: String?) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PC_ACTIVE_DIR"] = activeDirectory
        env["PC_TARGET_DIR"] = inactiveDirectory
        env["PC_CURSOR_NAME"] = cursorName
        env["PC_SELECTION_COUNT"] = String(selection.count)
        if let selectionFile { env["PC_SELECTION_FILE"] = selectionFile }
        return env
    }

    /// One selected path per line, in a temp file — the same shape the button bar's `%L` produces, so a
    /// script and a toolbar button read the selection the same way. Nil when nothing is selected, so a
    /// script can tell "no selection" from "an empty file".
    func writeSelectionFile() -> String? {
        guard !selection.isEmpty else { return nil }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-script-selection-\(UUID().uuidString).txt")
        guard (try? selection.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8))
                != nil else { return nil }
        return url.path
    }
}

struct ScriptResult {
    var output = ""
    var error: String?
    var timedOut = false

    var isFailure: Bool { error != nil || timedOut }
}

enum ScriptRunner {

    /// Compile `source` without running it. Nil when it compiles; the error with its position otherwise.
    static func check(source: String, language: String) -> String? {
        guard let osa = OSALanguage(forName: language) else {
            return "This machine has no scripting language called “\(language)”."
        }
        let script = OSAScript(source: source, language: osa)
        var error: NSDictionary?
        guard !script.compileAndReturnError(&error) else { return nil }
        return describe(error) ?? "The script could not be compiled."
    }

    /// Every OSA language installed on this machine, so the editor offers what actually exists rather
    /// than the two this file happens to name.
    static var availableLanguages: [String] {
        OSALanguage.availableLanguages().compactMap(\.name).sorted()
    }

    /// Run a script and return what it produced.
    static func run(source: String, language: String, mode: ScriptRunMode,
                    timeoutSeconds: Int, context: ScriptContext) -> ScriptResult {
        switch mode {
        case .inProcess: return runInProcess(source: source, language: language, context: context)
        case .subprocess: return runSubprocess(source: source, language: language,
                                               timeoutSeconds: timeoutSeconds, context: context)
        }
    }

    // MARK: - In-process (OSAKit)

    private static func runInProcess(source: String, language: String,
                                     context: ScriptContext) -> ScriptResult {
        guard let osa = OSALanguage(forName: language) else {
            return ScriptResult(error: "This machine has no scripting language called “\(language)”.")
        }
        // `setenv`, because an in-process script inherits *this* process's environment and there is
        // nowhere else to put the context. Restored afterwards so a script cannot leave the app with
        // variables the next one would read as its own.
        let selectionFile = context.writeSelectionFile()
        let injected = context.environment(selectionFile: selectionFile)
        let names = ["PC_ACTIVE_DIR", "PC_TARGET_DIR", "PC_CURSOR_NAME",
                     "PC_SELECTION_COUNT", "PC_SELECTION_FILE"]
        let previous = names.map { ($0, ProcessInfo.processInfo.environment[$0]) }
        for name in names {
            if let value = injected[name] { setenv(name, value, 1) } else { unsetenv(name) }
        }
        defer {
            for (name, value) in previous {
                if let value { setenv(name, value, 1) } else { unsetenv(name) }
            }
        }

        let script = OSAScript(source: source, language: osa)
        var error: NSDictionary?
        guard let descriptor = script.executeAndReturnError(&error) else {
            return ScriptResult(error: describe(error) ?? "The script failed.")
        }
        return ScriptResult(output: descriptor.stringValue ?? "")
    }

    // MARK: - Subprocess (osascript)

    private static func runSubprocess(source: String, language: String, timeoutSeconds: Int,
                                      context: ScriptContext) -> ScriptResult {
        let selectionFile = context.writeSelectionFile()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        // The source on stdin, not as an argument. A script is a document and an argument list is not
        // where a document goes: `-e` has a length limit, and a script containing a newline would have
        // to be broken into one `-e` per line.
        process.arguments = ["-l", language, "-"]
        process.environment = context.environment(selectionFile: selectionFile)
        // The active folder, so a script's relative paths mean what a reader would expect.
        if !context.activeDirectory.isEmpty {
            process.currentDirectoryURL = URL(fileURLWithPath: context.activeDirectory)
        }

        let input = Pipe(), output = Pipe(), errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors

        do { try process.run() } catch {
            return ScriptResult(error: "osascript could not be started: \(error.localizedDescription)")
        }
        input.fileHandleForWriting.write(Data(source.utf8))
        try? input.fileHandleForWriting.close()

        // Read both pipes on their own threads *before* waiting. A script that writes more than a pipe
        // buffer holds while nobody drains it, and waiting first would deadlock on exactly the scripts
        // that produce enough output to be worth reading.
        var outData = Data(), errData = Data()
        let group = DispatchGroup()
        for (handle, sink) in [(output.fileHandleForReading, { outData = $0 }),
                               (errors.fileHandleForReading, { errData = $0 })]
                              as [(FileHandle, (Data) -> Void)] {
            group.enter()
            DispatchQueue.global().async {
                sink(handle.readDataToEndOfFile())
                group.leave()
            }
        }

        var timedOut = false
        if timeoutSeconds > 0 {
            let deadline = DispatchTime.now() + .seconds(timeoutSeconds)
            let waiter = DispatchGroup()
            waiter.enter()
            DispatchQueue.global().async { process.waitUntilExit(); waiter.leave() }
            if waiter.wait(timeout: deadline) == .timedOut {
                timedOut = true
                process.terminate()
                // SIGTERM is a request. A script sitting in a `display dialog` does not answer it, and a
                // timeout that leaves the process running is not a timeout.
                if waiter.wait(timeout: .now() + .seconds(2)) == .timedOut { kill(process.processIdentifier, SIGKILL) }
            }
        } else {
            process.waitUntilExit()
        }
        group.wait()

        let out = String(decoding: outData, as: UTF8.self).trimmingCharacters(in: .newlines)
        let err = String(decoding: errData, as: UTF8.self).trimmingCharacters(in: .newlines)
        if timedOut {
            return ScriptResult(output: out,
                                error: "The script was still running after \(timeoutSeconds) seconds "
                                     + "and was stopped.", timedOut: true)
        }
        guard process.terminationStatus == 0 else {
            return ScriptResult(output: out, error: err.isEmpty
                ? "osascript exited with status \(process.terminationStatus)." : err)
        }
        // A successful `osascript` still writes to stderr for a `log` statement — which is how somebody
        // debugs a script. Kept, and marked, rather than dropped: discarding it makes `log` look broken.
        guard !err.isEmpty else { return ScriptResult(output: out) }
        return ScriptResult(output: out.isEmpty ? err : out + "\n--- log ---\n" + err)
    }

    /// An OSAKit error dictionary as one line, with the position when there is one.
    private static func describe(_ error: NSDictionary?) -> String? {
        guard let error else { return nil }
        guard let message = error[OSAScriptErrorMessage] as? String else { return nil }
        if let range = error[OSAScriptErrorRange] as? NSValue {
            let r = range.rangeValue
            return "\(message) (at character \(r.location + 1))"
        }
        if let number = error[OSAScriptErrorNumber] as? NSNumber {
            return "\(message) (error \(number.intValue))"
        }
        return message
    }
}
