// SPDX-License-Identifier: Apache-2.0
// ShellExecutor - runs shell command lines and handles `cd` specially.
import Foundation

/// Result of running a shell command line.
public struct ShellResult: Sendable, Equatable {
    /// Merged stdout+stderr, trailing newline trimmed.
    public let output: String
    /// Process termination status (or a synthesized code for `cd` handling).
    public let exitCode: Int32
    /// Non-nil when the line was a `cd` command; the resolved target directory.
    public let changedDirectory: String?

    public init(output: String, exitCode: Int32, changedDirectory: String?) {
        self.output = output
        self.exitCode = exitCode
        self.changedDirectory = changedDirectory
    }
}

/// Executes shell command lines via `/bin/zsh`, with built-in `cd` handling.
public enum ShellExecutor {
    /// If `line` is a `cd` command, resolve+validate the target and return a
    /// `ShellResult` with `changedDirectory` set (no process spawned). Otherwise
    /// run `line` via `/bin/zsh -lc` with the current directory set to
    /// `workingDirectory`, capturing merged stdout+stderr.
    public static func run(_ line: String,
                            workingDirectory: String,
                            environment: [String: String] = ProcessInfo.processInfo.environment) async -> ShellResult {
        if let target = resolveCdTarget(line, workingDirectory: workingDirectory, environment: environment) {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: target, isDirectory: &isDirectory)
            guard exists, isDirectory.boolValue else {
                return ShellResult(
                    output: "cd: no such file or directory: \(target)",
                    exitCode: 1,
                    changedDirectory: nil
                )
            }
            return ShellResult(output: "", exitCode: 0, changedDirectory: target)
        }

        return runProcess(line, workingDirectory: workingDirectory, environment: environment)
    }

    /// Resolve a `cd` target path, or `nil` if `line` is not a `cd` command. This
    /// is pure string resolution and does not check whether the target exists.
    public static func resolveCdTarget(_ line: String,
                                        workingDirectory: String,
                                        environment: [String: String]) -> String? {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        guard let argument = cdArgument(from: trimmedLine) else {
            return nil
        }

        let home = environment["HOME"] ?? NSHomeDirectory()
        let expanded = expandVariables(in: argument, environment: environment)

        if expanded.isEmpty {
            return home
        }
        if expanded == "~" {
            return home
        }
        if expanded.hasPrefix("~/") {
            return standardizedPath(home + expanded.dropFirst(1))
        }
        if expanded.hasPrefix("/") {
            return standardizedPath(expanded)
        }

        let base = URL(fileURLWithPath: workingDirectory, isDirectory: true)
        let resolved = URL(fileURLWithPath: expanded, relativeTo: base).standardizedFileURL
        return resolved.path
    }

    // MARK: - Private helpers

    /// Extracts the argument following a `cd` token, or nil if `line` is not `cd`.
    private static func cdArgument(from trimmedLine: String) -> String? {
        if trimmedLine == "cd" {
            return ""
        }
        guard trimmedLine.hasPrefix("cd ") else {
            return nil
        }
        let rest = trimmedLine.dropFirst("cd ".count).trimmingCharacters(in: .whitespaces)
        return unquoted(rest)
    }

    /// Strip one matching pair of surrounding quotes, the way a shell would.
    ///
    /// `cd "Zwei Wörter"` used to resolve to a path containing the quote characters and therefore found
    /// nothing, while the unquoted `cd Zwei Wörter` worked — backwards from every shell a user has met,
    /// where quoting is the form that is *supposed* to handle a space. Only a matching outer pair is
    /// removed, so a folder whose name really contains a quote is still reachable by not quoting it.
    private static func unquoted(_ value: String) -> String {
        guard value.count >= 2, let first = value.first, let last = value.last,
              first == last, first == "\"" || first == "'" else { return value }
        return String(value.dropFirst().dropLast())
    }

    /// Expands `$VAR` and `${VAR}` tokens using the provided environment.
    private static func expandVariables(in string: String, environment: [String: String]) -> String {
        var result = ""
        let chars = Array(string)
        var index = 0

        while index < chars.count {
            let char = chars[index]
            guard char == "$" else {
                result.append(char)
                index += 1
                continue
            }

            let afterDollar = index + 1
            if afterDollar < chars.count, chars[afterDollar] == "{" {
                if let closeOffset = chars[afterDollar...].firstIndex(of: "}") {
                    let name = String(chars[(afterDollar + 1)..<closeOffset])
                    result.append(environment[name] ?? "")
                    index = closeOffset + 1
                    continue
                }
            }

            var nameEnd = afterDollar
            while nameEnd < chars.count, isValidVariableCharacter(chars[nameEnd]) {
                nameEnd += 1
            }

            if nameEnd > afterDollar {
                let name = String(chars[afterDollar..<nameEnd])
                result.append(environment[name] ?? "")
                index = nameEnd
            } else {
                result.append(char)
                index += 1
            }
        }

        return result
    }

    private static func isValidVariableCharacter(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_"
    }

    /// Standardizes a raw path string, resolving `..`/`.` components.
    private static func standardizedPath(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    /// Runs `line` via `/bin/zsh -lc`, capturing merged stdout+stderr.
    private static func runProcess(_ line: String,
                                    workingDirectory: String,
                                    environment: [String: String]) -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", line]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let rawOutput = String(data: data, encoding: .utf8) ?? ""
            let trimmedOutput = trimTrailingNewline(rawOutput)
            return ShellResult(output: trimmedOutput, exitCode: process.terminationStatus, changedDirectory: nil)
        } catch {
            PCFoundationLogger.error("ShellExecutor failed to run line: \(error.localizedDescription)")
            return ShellResult(
                output: "Failed to execute command: \(error.localizedDescription)",
                exitCode: 127,
                changedDirectory: nil
            )
        }
    }

    /// Trims a single trailing newline (and any trailing whitespace) from process output.
    private static func trimTrailingNewline(_ string: String) -> String {
        var result = string
        while let last = result.last, last == "\n" || last == "\r" {
            result.removeLast()
        }
        return result
    }
}
