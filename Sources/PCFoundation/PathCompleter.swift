// PathCompleter - filesystem path completion for a command-line entry field.
import Foundation

/// Completes partial filesystem paths against directory contents.
public enum PathCompleter {
    /// Directory entries whose names start with the partial leaf of `token`,
    /// resolved relative to `baseDirectory` (supports absolute paths and a
    /// leading `~`). Directories are returned with a trailing "/". Matching is
    /// case-insensitive. Results are sorted, and hidden files are excluded
    /// unless the leaf itself starts with ".".
    public static func completions(for token: String,
                                    in baseDirectory: String,
                                    home: String = NSHomeDirectory()) -> [String] {
        let (dirPart, leaf) = split(token)
        let directory = resolveDirectory(dirPart, baseDirectory: baseDirectory, home: home)

        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            return []
        }

        let showHidden = leaf.hasPrefix(".")
        let lowerLeaf = leaf.lowercased()

        let matched = entries.filter { name in
            guard name.lowercased().hasPrefix(lowerLeaf) else {
                return false
            }
            if !showHidden && name.hasPrefix(".") {
                return false
            }
            return true
        }

        let withSuffix = matched.map { name -> String in
            let fullPath = (directory as NSString).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory)
            return isDirectory.boolValue ? name + "/" : name
        }

        return withSuffix.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Applies the longest common completion: returns `token` extended by the
    /// common prefix of all candidates (`nil` when there are no candidates).
    /// If exactly one candidate matches, returns the fully-completed token.
    public static func complete(_ token: String,
                                 in baseDirectory: String,
                                 home: String = NSHomeDirectory()) -> String? {
        let (dirPart, _) = split(token)
        let candidates = completions(for: token, in: baseDirectory, home: home)

        guard !candidates.isEmpty else {
            return nil
        }
        if candidates.count == 1 {
            return dirPart + candidates[0]
        }

        return dirPart + longestCommonPrefix(of: candidates)
    }

    // MARK: - Private helpers

    /// Splits `token` into a directory part (including any trailing "/") and a
    /// leaf part, on the last "/" in the token.
    private static func split(_ token: String) -> (dirPart: String, leaf: String) {
        guard let slashIndex = token.lastIndex(of: "/") else {
            return ("", token)
        }
        let dirPart = String(token[token.startIndex...slashIndex])
        let leaf = String(token[token.index(after: slashIndex)...])
        return (dirPart, leaf)
    }

    /// Resolves a directory part (possibly empty, `~`-prefixed, absolute, or
    /// relative) against `baseDirectory`/`home` into an absolute filesystem path.
    private static func resolveDirectory(_ dirPart: String, baseDirectory: String, home: String) -> String {
        guard !dirPart.isEmpty else {
            return baseDirectory
        }

        var anchor = baseDirectory
        var remainder = dirPart

        if dirPart == "~" || dirPart.hasPrefix("~/") {
            anchor = home
            remainder = String(dirPart.dropFirst(1))
            if remainder.hasPrefix("/") {
                remainder = String(remainder.dropFirst())
            }
        } else if dirPart.hasPrefix("/") {
            anchor = "/"
            remainder = String(dirPart.dropFirst())
        }

        if remainder.hasSuffix("/") {
            remainder = String(remainder.dropLast())
        }

        guard !remainder.isEmpty else {
            return (anchor as NSString).standardizingPath
        }

        let resolved = URL(fileURLWithPath: remainder, relativeTo: URL(fileURLWithPath: anchor, isDirectory: true))
        return resolved.standardizedFileURL.path
    }

    /// The longest common prefix shared by all of `strings`, or "" when empty.
    private static func longestCommonPrefix(of strings: [String]) -> String {
        guard let first = strings.first else {
            return ""
        }

        var prefix = Array(first)
        for string in strings.dropFirst() {
            let chars = Array(string)
            var index = 0
            while index < prefix.count && index < chars.count && prefix[index] == chars[index] {
                index += 1
            }
            prefix = Array(prefix.prefix(index))
            if prefix.isEmpty {
                break
            }
        }

        return String(prefix)
    }
}
