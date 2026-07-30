// ParamExpander - Total-Commander %-parameter expansion engine
// Expands the %P/%N/%T/%M/%S/%L/%F/%D/%W/%% parameter tokens Total Commander
// recognizes in toolbar button commands and user (Start-menu) commands, given
// the current panel/selection context.

import Foundation

/// The panel/selection state a parameter template is expanded against.
public struct ParamContext: Sendable, Equatable {
    /// %P - active panel directory (absolute path, no trailing separator added).
    public var sourceDir: String
    /// %N - file/dir name under the cursor in the active panel (leaf, no path).
    public var cursorName: String
    /// %T - the other (inactive) panel's directory.
    public var targetDir: String
    /// %M - name under the cursor in the other panel.
    public var targetName: String
    /// %S - selected leaf names in the active panel, space-joined on expansion.
    public var selectedNames: [String]

    public init(sourceDir: String = "", cursorName: String = "", targetDir: String = "",
                targetName: String = "", selectedNames: [String] = []) {
        self.sourceDir = sourceDir
        self.cursorName = cursorName
        self.targetDir = targetDir
        self.targetName = targetName
        self.selectedNames = selectedNames
    }
}

/// Kinds of temp list-file the caller can generate on demand for %L/%F/%D/%W.
public enum ListFileKind: Sendable, Equatable {
    /// %L - one absolute path per selected item.
    case fullPaths
    /// %F - one leaf name per selected item.
    case names
    /// %D - short (DOS 8.3) names; macOS has no such concept, so this is
    /// identical to `.names`.
    case dosNames
    /// %W - names without extension path; macOS has no such concept, so this
    /// is identical to `.names`.
    case withoutPath
}

/// Expands Total-Commander-style `%`-parameter templates, as used by toolbar
/// button command lines and user (Start-menu) commands.
///
/// `expand(_:context:listFile:)` is a pure function: given the same template,
/// context, and list-file results it always produces the same string. It
/// performs no I/O itself -- generating an actual temp list file is the
/// caller's responsibility, supplied lazily via the `listFile` closure.
public enum ParamExpander {

    /// Expand a TC parameter template. Recognized tokens (case-insensitive on
    /// the letter):
    ///   %P source dir, %N cursor name, %T target dir, %M target name,
    ///   %S space-joined selected names, %L/%F/%D/%W -> temp list-file path,
    ///   %% -> literal '%'. Unknown %x is passed through verbatim (including
    ///   the %).
    ///
    /// Any expanded value that contains whitespace is wrapped in double
    /// quotes; for %S each name is individually quoted if it contains
    /// whitespace, then joined by single spaces. A trailing path separator is
    /// NOT added to %P/%T.
    ///
    /// - Parameters:
    ///   - template: The raw command-line template containing `%`-tokens.
    ///   - context: The panel/selection state to substitute values from.
    ///   - listFile: Called at most once per referenced `ListFileKind` to
    ///     obtain the temp file path to substitute; the result is cached so
    ///     repeated tokens of the same kind (e.g. `%L %L`) reuse the same
    ///     path without calling the closure again. If `nil` and a list token
    ///     appears, it expands to `""`.
    /// - Returns: The expanded command-line string.
    public static func expand(_ template: String, context: ParamContext,
                              listFile: ((ListFileKind) -> String)? = nil) -> String {
        var result = ""
        result.reserveCapacity(template.count)

        // Lazily-populated, per-call cache so %L %L (etc.) only invokes the
        // caller's list-file generator once per distinct kind.
        var listFileCache: [ListFileKind: String] = [:]
        func resolvedListFile(_ kind: ListFileKind) -> String {
            if let cached = listFileCache[kind] {
                return cached
            }
            let value = listFile?(kind) ?? ""
            listFileCache[kind] = value
            return value
        }

        var index = template.startIndex
        let end = template.endIndex
        while index < end {
            let character = template[index]
            guard character == "%" else {
                result.append(character)
                index = template.index(after: index)
                continue
            }

            let next = template.index(after: index)
            guard next < end else {
                // A '%' at end-of-string is emitted verbatim.
                result.append("%")
                index = next
                continue
            }

            let token = template[next]
            switch token {
            case "P", "p":
                result += quoteIfNeeded(context.sourceDir)
            case "N", "n":
                result += quoteIfNeeded(context.cursorName)
            case "T", "t":
                result += quoteIfNeeded(context.targetDir)
            case "M", "m":
                result += quoteIfNeeded(context.targetName)
            case "S", "s":
                result += context.selectedNames.map(quoteIfNeeded).joined(separator: " ")
            case "L", "l":
                result += quoteIfNeeded(resolvedListFile(.fullPaths))
            case "F", "f":
                result += quoteIfNeeded(resolvedListFile(.names))
            case "D", "d":
                result += quoteIfNeeded(resolvedListFile(.dosNames))
            case "W", "w":
                result += quoteIfNeeded(resolvedListFile(.withoutPath))
            case "%":
                result.append("%")
            default:
                // Unrecognized %x is passed through verbatim, including the '%'.
                result.append("%")
                result.append(token)
            }
            index = template.index(after: next)
        }

        return result
    }

    /// Wraps `value` in double quotes if it contains whitespace (space or
    /// tab); otherwise returns it unchanged.
    private static func quoteIfNeeded(_ value: String) -> String {
        if value.contains(" ") || value.contains("\t") {
            return "\"\(value)\""
        }
        return value
    }
}
