// SPDX-License-Identifier: Apache-2.0
// ExternalToolFormatter.swift - Format by piping through a command-line tool.
//
// This is what makes the set of supported formats open-ended: jq for JSON, yq for YAML,
// xmllint for XML, taplo for TOML, prettier for Markdown, sqlformat for SQL — and anything
// the user configures for their own extensions. A tool that is not installed reports
// isAvailable == false, so the registry simply falls through to the next candidate.
//
// Deliberately exec + argv, never a shell: ShellExecutor runs `/bin/zsh -lc <line>`, which
// is right for the command line the user typed but wrong here, because a formatter argument
// list must not be re-interpreted for quoting or globbing.

import Foundation

/// Runs one external formatter: text in on stdin, formatted text out on stdout.
public struct ExternalToolFormatter: TextFormatter {
    /// Executable name as installed (`jq`), or an absolute path.
    public let tool: String
    public let arguments: [String]
    public let supportedExtensions: [String]
    /// Overrides the displayed name; defaults to the tool's basename.
    private let displayName: String?

    public var name: String { displayName ?? (tool as NSString).lastPathComponent }

    public init(tool: String, arguments: [String], extensions: [String], name: String? = nil) {
        self.tool = tool
        self.arguments = arguments
        self.supportedExtensions = extensions.map { $0.lowercased() }
        self.displayName = name
    }

    /// Resolved path, or nil when the tool is not installed.
    public var executablePath: String? {
        tool.hasPrefix("/") ? (FileManager.default.isExecutableFile(atPath: tool) ? tool : nil)
                            : ToolLocator.path(for: tool)
    }

    public var isAvailable: Bool { executablePath != nil }

    public func format(_ text: String) throws -> String {
        guard let path = executablePath else { throw FormatError.toolNotFound(name) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        do { try process.run() } catch {
            throw FormatError.toolFailed(tool: name, exitCode: 127, message: error.localizedDescription)
        }

        // Write on a background queue and read stdout concurrently: a formatter that emits
        // more than a pipe buffer while we are still writing would otherwise deadlock.
        let input = Data(text.utf8)
        DispatchQueue.global(qos: .userInitiated).async {
            stdin.fileHandleForWriting.write(input)
            try? stdin.fileHandleForWriting.close()
        }
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: errData, encoding: .utf8) ?? ""
            throw FormatError.toolFailed(tool: name, exitCode: process.terminationStatus,
                                         message: message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let result = String(data: outData, encoding: .utf8), !result.isEmpty else {
            throw FormatError.toolFailed(tool: name, exitCode: 0, message: "produced no output")
        }
        guard result != text else { throw FormatError.unchanged }
        return result
    }
}

/// Locates executables without going through a shell.
public enum ToolLocator {
    /// Searched in order. Homebrew first (both architectures' prefixes), then the system —
    /// a user who installed a newer tool via brew means to use it. Mirrors
    /// PCArchive.PackEngine.toolPath, which resolves the packer binaries the same way.
    public static let searchPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]

    /// Absolute path for `name`, or nil when it is not installed. `PATH` is consulted as
    /// well, so a tool in a custom location is found without configuration.
    public static func path(for name: String) -> String? {
        let fm = FileManager.default
        let fromPath = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        for dir in searchPaths + fromPath {
            let candidate = "\(dir)/\(name)"
            if fm.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }
}

/// The external formatters tried before the built-ins, when their tool is installed.
///
/// Chosen for what each tool is actually good at: `yq`, `taplo` and `prettier` keep comments,
/// which is why they are preferred over a library round trip for configuration formats. The
/// order within an extension matters — the first available one wins.
public enum DefaultExternalFormatters {
    public static func all() -> [ExternalToolFormatter] {
        [
            // YAML: yq preserves comments; prettier is the common fallback.
            ExternalToolFormatter(tool: "yq", arguments: ["-P", "."], extensions: ["yml", "yaml"]),
            ExternalToolFormatter(tool: "prettier", arguments: ["--parser", "yaml"],
                                  extensions: ["yml", "yaml"]),
            // TOML: taplo is the de-facto formatter; "-" reads stdin.
            ExternalToolFormatter(tool: "taplo", arguments: ["format", "-"], extensions: ["toml"]),
            // SQL: neither has a Foundation equivalent, so an external tool is the only
            // correct option rather than a keyword-based re-indent.
            ExternalToolFormatter(tool: "sqlformat", arguments: ["--reindent", "--keywords", "upper", "-"],
                                  extensions: ["sql"]),
            ExternalToolFormatter(tool: "sql-formatter", arguments: [], extensions: ["sql"]),
            // Markdown: prettier normalises lists, tables and emphasis consistently.
            ExternalToolFormatter(tool: "prettier", arguments: ["--parser", "markdown"],
                                  extensions: ["md", "markdown", "mdown"]),
            // The remaining ones only take over from a built-in when installed, because these
            // tools are stricter and usually closer to what the ecosystem expects.
            ExternalToolFormatter(tool: "jq", arguments: ["--indent", "2", "."], extensions: ["json"]),
            ExternalToolFormatter(tool: "xmllint", arguments: ["--format", "-"], extensions: ["xml", "svg"]),
        ]
    }
}
