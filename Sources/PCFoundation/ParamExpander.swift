// SPDX-License-Identifier: Apache-2.0
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
    /// Every expanded value is wrapped in single quotes (see `quoteIfNeeded`); for %S each name is
    /// quoted individually and the results joined by single spaces. A trailing path separator is
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
    /// - Parameter quoting: whether each substituted value is quoted as a shell word.
    ///
    ///   `true` (the default) is for anything that becomes part of a command line. `false` is for the
    ///   two places whose result is a *path* rather than a shell word — the program to run and the
    ///   working directory — where a value wrapped in quotes names a directory that does not exist.
    ///   Adding the quoting without this distinction broke both, which is what a `%P` working directory
    ///   turning into `'/Users/me/docs'` looks like.
    /// - Parameter brace: handles a `%{…}` token, receiving what stands between the braces and
    ///   returning the text to put in its place.
    ///
    ///   Without it — the default, and what every button-bar caller does — `%{` is an unrecognised
    ///   token and passes through verbatim, exactly as before. With it, the brace family is expanded
    ///   **in this same single pass**, and that is the whole reason it lives here rather than in a
    ///   second pass at the caller: a value substituted by either family is appended to the result and
    ///   never looked at again. Macros expanded braces first and then called this method on the
    ///   outcome, so a step result containing a `%` was read as a template — `/tmp/50%Netto.pdf` came
    ///   out as `/tmp/50report final.pdfetto.pdf`, with `%N` substituted out of the *data*.
    ///
    ///   The handler owns whatever quoting its own values need; the result is inserted as it is.
    ///   Declared *before* `listFile` on purpose: several callers pass the list-file generator as a
    ///   trailing closure, and a new last parameter would silently rebind those to this one.
    public static func expand(_ template: String, context: ParamContext,
                              quoting: Bool = true,
                              brace: ((String) throws -> String)? = nil,
                              listFile: ((ListFileKind) -> String)? = nil) rethrows -> String {
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

        func value(_ raw: String) -> String { quoting ? quoteIfNeeded(raw) : raw }

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
            // Before the letter table, because `{` would otherwise fall to the default branch and be
            // emitted verbatim — which is precisely the behaviour kept when no handler is given.
            if token == "{", brace != nil {
                guard let close = template[next...].firstIndex(of: "}") else {
                    // Unterminated. Emitted verbatim: a template somebody is still typing must not
                    // become an error somewhere else.
                    result.append(contentsOf: template[index...])
                    return result
                }
                let inner = String(template[template.index(after: next)..<close])
                // Called through the optional rather than through a bound local: `rethrows` only
                // tracks calls to the parameter itself, and `if let brace` breaks that thread.
                result += try brace?(inner) ?? ""
                index = template.index(after: close)
                continue
            }
            switch token {
            case "P", "p":
                result += value(context.sourceDir)
            case "N", "n":
                result += value(context.cursorName)
            case "T", "t":
                result += value(context.targetDir)
            case "M", "m":
                result += value(context.targetName)
            case "S", "s":
                result += context.selectedNames.map(value).joined(separator: " ")
            case "L", "l":
                result += value(resolvedListFile(.fullPaths))
            case "F", "f":
                result += value(resolvedListFile(.names))
            case "D", "d":
                result += value(resolvedListFile(.dosNames))
            case "W", "w":
                result += value(resolvedListFile(.withoutPath))
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

    /// `value` as one shell word.
    ///
    /// Always quoted, and with single quotes. The previous version wrapped a value in *double* quotes
    /// only when it contained whitespace — so `$(id).txt`, `` `id`.txt `` and `a;id;b.txt`, all legal
    /// macOS file names, went into the command line raw and ran when the user invoked any user-defined
    /// command on that folder. A name containing a double quote broke out of the quoting outright. Even
    /// double-quoting everything would not have been enough: a shell still substitutes inside those.
    private static func quoteIfNeeded(_ value: String) -> String {
        ShellQuoting.quote(value)
    }
}
