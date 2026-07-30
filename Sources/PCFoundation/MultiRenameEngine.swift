// SPDX-License-Identifier: Apache-2.0
// MultiRenameEngine - Total-Commander-style multi-rename tool engine.
// A pure Foundation implementation of the placeholder/transform "mask"
// language used to batch-rename files: mask token expansion, search &
// replace, and case transforms. Contains no AppKit / UI dependencies so it
// can be exercised and tested headlessly.

import Foundation

/// How a batch rename should transform the final combined name.
public enum RenameCase: Sendable, Equatable {
    /// No case transform.
    case unchanged
    /// `String.localizedLowercase` applied to the whole name.
    case lower
    /// `String.localizedUppercase` applied to the whole name.
    case upper
    /// First character uppercased, remaining characters lowercased.
    case firstUpper
    /// First letter of every word uppercased, remaining letters of that
    /// word lowercased. Word boundaries are space, underscore, dot, and
    /// hyphen (see `MultiRenameEngine`'s `everyWord` documentation).
    case everyWord
}

/// One item to be renamed: its current name plus the metadata the mask
/// language can reference (`[Y]`, `[P]`, `[G]`, ...).
public struct RenameInput: Sendable, Equatable {
    /// Full filename including its extension, e.g. `"Photo.JPG"`.
    public let name: String
    /// The file's modification date, used by the `[Y][M][D][h][m][s][d]`
    /// date tokens.
    public let modified: Date
    /// The immediate parent directory's name, used by `[P]`.
    public let parentName: String
    /// The parent's parent directory's name, used by `[G]`.
    public let grandparentName: String
    /// Precomputed content-plugin field values keyed by qualified id
    /// ("fileinfo.width"), used by the `[=id]` token. The caller resolves these
    /// (e.g. via ContentFieldRegistry) before building the input.
    public let fields: [String: String]

    public init(name: String, modified: Date, parentName: String = "", grandparentName: String = "",
                fields: [String: String] = [:]) {
        self.name = name
        self.modified = modified
        self.parentName = parentName
        self.grandparentName = grandparentName
        self.fields = fields
    }
}

/// A batch-rename configuration: the mask templates plus optional
/// search/replace and case-transform steps.
public struct RenameSpec: Sendable {
    /// Mask expanded to produce the new base name (before the extension).
    public var nameMask: String
    /// Mask expanded to produce the new extension (after the dot).
    public var extMask: String
    /// Search term(s). Empty means "no search/replace". Multiple terms are
    /// separated by `|`.
    public var search: String
    /// Replacement(s), paired positionally with `search`'s `|`-separated
    /// terms. Extra terms with no matching replacement use `""`.
    public var replace: String
    /// Treat each search term as an `NSRegularExpression` pattern (with
    /// `$1`-style group references in `replace`) instead of a literal.
    public var useRegex: Bool
    /// Whether matching is case-sensitive.
    public var caseSensitive: Bool
    /// Re-apply each replacement repeatedly until it no longer changes the
    /// string (capped to guard against infinite growth/loops).
    public var repeatReplace: Bool
    /// Case transform applied last, to the whole combined name.
    public var caseMode: RenameCase
    /// Counter value used by a bare `[C]` for the first item (item index 0).
    public var counterStart: Int
    /// Amount the counter advances per item index for a bare `[C]`.
    public var counterStep: Int
    /// Zero-padded width used by a bare `[C]`.
    public var counterDigits: Int

    public init(nameMask: String = "[N]", extMask: String = "[E]", search: String = "", replace: String = "",
                useRegex: Bool = false, caseSensitive: Bool = false, repeatReplace: Bool = false,
                caseMode: RenameCase = .unchanged, counterStart: Int = 1, counterStep: Int = 1, counterDigits: Int = 1) {
        self.nameMask = nameMask
        self.extMask = extMask
        self.search = search
        self.replace = replace
        self.useRegex = useRegex
        self.caseSensitive = caseSensitive
        self.repeatReplace = repeatReplace
        self.caseMode = caseMode
        self.counterStart = counterStart
        self.counterStep = counterStep
        self.counterDigits = counterDigits
    }
}

/// The computed outcome for a single `RenameInput`.
public struct RenameResult: Sendable, Equatable {
    /// The original filename, unchanged.
    public let oldName: String
    /// The computed new filename.
    public let newName: String
    /// `false` when `newName` is empty or contains `"/"` or a NUL character.
    public let isValid: Bool
    /// `true` when another result in the same batch has the same `newName`,
    /// compared case-insensitively.
    public let collides: Bool

    public init(oldName: String, newName: String, isValid: Bool, collides: Bool) {
        self.oldName = oldName
        self.newName = newName
        self.isValid = isValid
        self.collides = collides
    }
}

// MARK: - Internal mask-expansion support types

/// Word-boundary characters shared by the `[F]` mask region and the
/// `.everyWord` case mode: space, underscore, dot, and hyphen.
private func isWordBoundaryCharacter(_ ch: Character) -> Bool {
    ch == " " || ch == "_" || ch == "." || ch == "-"
}

/// A parsed `[N...]` / `[E...]` / `[P...]` / `[G...]` range specifier.
/// Positions are 1-based over grapheme clusters; negative positions count
/// from the end (`-1` is the last character).
private enum RangeSpec {
    /// `[N]` - the whole string, unranged.
    case whole
    /// `[N5]` (bare position; not in the formal grammar but accepted for
    /// robustness) - a single character at that position.
    case single(Int)
    /// `[N2-5]` / `[N2-]` - inclusive start...end, or start...end-of-string
    /// when `end` is `nil`.
    case dashRange(start: Int, end: Int?)
    /// `[N2,3]` / `[N-8,5]` - `count` characters starting at `start`.
    case countRange(start: Int, count: Int)
}

/// Case-region state threaded through a single mask expansion. `[U]`,
/// `[L]`, `[F]`, and `[n]` tokens mutate `region`; every character emitted
/// afterward (literal text or further token output) within that same mask
/// expansion is transformed accordingly.
///
/// This intentionally uses plain (non-localized) `uppercased()` /
/// `lowercased()` rather than `localizedUppercase` / `localizedLowercase`,
/// so mask expansion is deterministic regardless of the host locale. The
/// final `RenameCase` transform (applied once, to the whole combined name)
/// is the one that follows the localized convention.
private final class MaskExpansionState {
    private enum Region {
        case normal
        case upper
        case lower
        case firstWordUpper
    }

    private var region: Region = .normal
    private var atWordStart = true
    private(set) var output = ""

    /// Switches to plain UPPER for subsequently appended text.
    func setUpper() { region = .upper }
    /// Switches to plain lower for subsequently appended text.
    func setLower() { region = .lower }
    /// Switches back to unmodified text for subsequently appended text.
    func setNormal() { region = .normal }
    /// Switches to First-Letter-Of-Each-Word for subsequently appended text.
    func setFirstWord() {
        region = .firstWordUpper
        atWordStart = true
    }

    /// Appends `text`, transforming each character per the current region.
    func append(_ text: String) {
        for ch in text {
            output.append(contentsOf: transformed(ch))
        }
    }

    private func transformed(_ ch: Character) -> String {
        switch region {
        case .normal:
            return String(ch)
        case .upper:
            return String(ch).uppercased()
        case .lower:
            return String(ch).lowercased()
        case .firstWordUpper:
            if isWordBoundaryCharacter(ch) {
                atWordStart = true
                return String(ch)
            }
            let piece = atWordStart ? String(ch).uppercased() : String(ch).lowercased()
            atWordStart = false
            return piece
        }
    }
}

/// The placeholder/transform engine for Total-Commander-style multi-rename.
///
/// `compute(_:spec:)` runs, per item, in order: (1) mask token expansion for
/// `nameMask` and `extMask`, combined into one string; (2) search/replace on
/// that combined string; (3) the whole-name case transform. It then flags
/// duplicate results across the batch.
///
/// Date tokens (`[Y][M][D][h][m][s][d]`) read `RenameInput.modified` through
/// a Gregorian calendar pinned to the UTC time zone, so results are
/// deterministic regardless of the host machine's time zone or locale.
public enum MultiRenameEngine {

    /// Calendar used to decompose `RenameInput.modified` for date tokens:
    /// Gregorian, UTC. Fixed (rather than `.current`) so date-token output
    /// is deterministic in tests and across machines.
    private static let dateCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    /// Safety cap on repeated-replacement iterations, guarding against
    /// patterns that would otherwise grow or loop forever (e.g. replacing
    /// `"a"` with `"aa"` under `repeatReplace`).
    private static let maxReplaceIterations = 1000

    /// Compute the new names for a batch. See the type-level documentation
    /// for the per-item pipeline; after all items are computed, any results
    /// sharing the same `newName` (case-insensitively) are flagged via
    /// `collides`.
    public static func compute(_ inputs: [RenameInput], spec: RenameSpec) -> [RenameResult] {
        var newNames: [String] = []
        newNames.reserveCapacity(inputs.count)

        for (index, input) in inputs.enumerated() {
            let combined = expandedCombinedName(for: input, index: index, spec: spec)
            let replaced = applySearchReplace(combined, spec: spec)
            let cased = applyCase(replaced, mode: spec.caseMode)
            newNames.append(cased)
        }

        // Case-insensitive collision counts. Uses plain `.lowercased()`
        // (not `.localizedLowercase`) so collision detection - unlike the
        // `.lower` / `.upper` / `.firstUpper` case modes, which follow the
        // spec's explicit localized convention - stays locale-independent.
        var countsByFoldedName: [String: Int] = [:]
        for name in newNames {
            countsByFoldedName[name.lowercased(), default: 0] += 1
        }

        var results: [RenameResult] = []
        results.reserveCapacity(inputs.count)
        for (index, input) in inputs.enumerated() {
            let newName = newNames[index]
            let collides = (countsByFoldedName[newName.lowercased()] ?? 0) > 1
            let isValid = !newName.isEmpty && !newName.contains("/") && !newName.contains("\0")
            results.append(RenameResult(oldName: input.name, newName: newName, isValid: isValid, collides: collides))
        }
        return results
    }

    // MARK: - Name / extension split

    /// Splits `name` into (base, extension) using the "text after the last
    /// dot" rule, except that a name whose *only* dot is its first
    /// character (e.g. `".bashrc"`) is treated as having no extension: the
    /// whole string is the base and the extension is empty.
    private static func splitNameExtension(_ name: String) -> (base: String, ext: String) {
        guard let lastDot = name.lastIndex(of: ".") else {
            return (name, "")
        }
        if lastDot == name.startIndex {
            return (name, "")
        }
        let base = String(name[name.startIndex..<lastDot])
        let ext = String(name[name.index(after: lastDot)...])
        return (base, ext)
    }

    // MARK: - Per-item combined name

    private static func expandedCombinedName(for input: RenameInput, index: Int, spec: RenameSpec) -> String {
        let (base, ext) = splitNameExtension(input.name)
        let expandedName = expandMask(spec.nameMask, base: base, ext: ext, input: input, index: index, spec: spec)
        let expandedExt = expandMask(spec.extMask, base: base, ext: ext, input: input, index: index, spec: spec)
        return expandedExt.isEmpty ? expandedName : expandedName + "." + expandedExt
    }

    // MARK: - Mask scanning

    /// Expands one mask string (`nameMask` or `extMask`) against the given
    /// per-item context. `[[` / `]]` become literal `[` / `]`; `[...]`
    /// tokens are dispatched to `expandToken`; unknown tokens and
    /// unterminated `[` are handled without crashing (see call sites).
    private static func expandMask(_ mask: String, base: String, ext: String, input: RenameInput, index: Int, spec: RenameSpec) -> String {
        let state = MaskExpansionState()
        let chars = Array(mask)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if ch == "[" {
                if i + 1 < chars.count && chars[i + 1] == "[" {
                    state.append("[")
                    i += 2
                    continue
                }
                if let closeIndex = chars[(i + 1)...].firstIndex(of: "]") {
                    let content = String(chars[(i + 1)..<closeIndex])
                    let expanded = expandToken(content, base: base, ext: ext, input: input, index: index, spec: spec, state: state)
                    state.append(expanded)
                    i = closeIndex + 1
                } else {
                    // No closing bracket for this '[': treat it as a literal
                    // character rather than failing.
                    state.append("[")
                    i += 1
                }
            } else if ch == "]" {
                if i + 1 < chars.count && chars[i + 1] == "]" {
                    state.append("]")
                    i += 2
                    continue
                }
                // Stray, unmatched ']': pass it through literally.
                state.append("]")
                i += 1
            } else {
                state.append(String(ch))
                i += 1
            }
        }
        return state.output
    }

    /// Expands the content of a single `[...]` token (without its
    /// brackets). Unknown token heads - including an empty `[]` - expand to
    /// `""` rather than throwing or crashing.
    private static func expandToken(_ content: String, base: String, ext: String, input: RenameInput, index: Int, spec: RenameSpec, state: MaskExpansionState) -> String {
        guard let head = content.first else { return "" }
        let rest = content.dropFirst()
        switch head {
        case "N":
            return expandRange(base, spec: parseRangeSpec(rest))
        case "E":
            return expandRange(ext, spec: parseRangeSpec(rest))
        case "P":
            return expandRange(input.parentName, spec: parseRangeSpec(rest))
        case "G":
            return expandRange(input.grandparentName, spec: parseRangeSpec(rest))
        case "C":
            let (startOverride, stepOverride, digitsOverride) = parseCounterSpec(rest)
            let start = startOverride ?? spec.counterStart
            let step = stepOverride ?? spec.counterStep
            let digits = digitsOverride ?? spec.counterDigits
            return formattedCounter(start + index * step, digits: digits)
        case "Y", "M", "D", "h", "m", "s", "d":
            return dateToken(head, modified: input.modified)
        case "U":
            state.setUpper()
            return ""
        case "L":
            state.setLower()
            return ""
        case "F":
            state.setFirstWord()
            return ""
        case "n":
            state.setNormal()
            return ""
        case "=":
            // Content-plugin field: [=provider.field], resolved from precomputed values.
            return input.fields[String(rest)] ?? ""
        default:
            return ""
        }
    }

    // MARK: - Range parsing (`[N...]`, `[E...]`, `[P...]`, `[G...]`)

    /// Consumes a leading, optionally `-`-signed integer from `s`. Returns
    /// `nil` (leaving `s` untouched) if no digits are found.
    private static func takeSignedInt(_ s: inout Substring) -> Int? {
        guard !s.isEmpty else { return nil }
        var idx = s.startIndex
        if s[idx] == "-" {
            idx = s.index(after: idx)
        }
        let digitsStart = idx
        while idx < s.endIndex && s[idx].isNumber {
            idx = s.index(after: idx)
        }
        guard idx > digitsStart else { return nil }
        let numStr = s[s.startIndex..<idx]
        guard let value = Int(numStr) else { return nil }
        s = s[idx...]
        return value
    }

    private static func parseRangeSpec(_ content: Substring) -> RangeSpec {
        guard !content.isEmpty else { return .whole }
        var s = content
        guard let first = takeSignedInt(&s) else { return .whole }
        if s.isEmpty {
            return .single(first)
        }
        let separator = s.removeFirst()
        switch separator {
        case ",":
            guard let count = takeSignedInt(&s) else { return .whole }
            return .countRange(start: first, count: count)
        case "-":
            if s.isEmpty {
                return .dashRange(start: first, end: nil)
            }
            guard let end = takeSignedInt(&s) else { return .whole }
            return .dashRange(start: first, end: end)
        default:
            return .whole
        }
    }

    /// Resolves `spec` against `text`, clamping to `text`'s grapheme-cluster
    /// bounds. Never throws or crashes; out-of-range or empty results
    /// resolve to `""`.
    private static func expandRange(_ text: String, spec: RangeSpec) -> String {
        switch spec {
        case .whole:
            return text
        case .single(let position):
            return graphemeSubstring(text, start: position, end: position)
        case .dashRange(let start, let end):
            if let end = end {
                return graphemeSubstring(text, start: start, end: end)
            }
            return graphemeSubstring(text, start: start, end: text.count)
        case .countRange(let start, let count):
            return graphemeSubstring(text, start: start, end: start + count - 1)
        }
    }

    /// Resolves a 1-based, possibly-negative token position against
    /// `length`. Non-negative values are used as-is; negative values count
    /// from the end (`-1` is the last character). The result is clamped to
    /// `1...length`.
    private static func resolvePosition(_ raw: Int, length: Int) -> Int {
        let pos = raw >= 0 ? raw : length + raw + 1
        return max(1, min(pos, length))
    }

    /// Extracts the inclusive, 1-based, grapheme-cluster range
    /// `start...end` from `text`, clamping both ends to `text`'s bounds. An
    /// empty `text`, or a range that clamps to an empty span, yields `""`.
    private static func graphemeSubstring(_ text: String, start: Int, end: Int) -> String {
        let characters = Array(text)
        let length = characters.count
        guard length > 0 else { return "" }
        let s = resolvePosition(start, length: length)
        let e = resolvePosition(end, length: length)
        guard s <= e else { return "" }
        return String(characters[(s - 1)...(e - 1)])
    }

    // MARK: - Counter parsing (`[C]`, `[C10+5:3]`, ...)

    /// Parses the text following `C` in a counter token, e.g. `"10+5:3"`,
    /// `"10"`, `"10+5"`, `":3"`, or `""`. Each of start/step/digits is `nil`
    /// when not present in the token, so the caller can fall back to the
    /// block-level `RenameSpec` values.
    private static func parseCounterSpec(_ rest: Substring) -> (start: Int?, step: Int?, digits: Int?) {
        var s = rest
        var start: Int?
        var step: Int?
        var digits: Int?

        if !s.isEmpty && s.first != "+" && s.first != ":" {
            start = takeSignedInt(&s)
        }
        if s.first == "+" {
            s.removeFirst()
            step = takeSignedInt(&s)
        }
        if s.first == ":" {
            s.removeFirst()
            digits = takeSignedInt(&s)
        }
        return (start, step, digits)
    }

    /// Zero-pads `value`'s magnitude to `digits` width, preserving a `-`
    /// sign in front for negative values (e.g. `-5` at width 3 -> `"-005"`).
    private static func formattedCounter(_ value: Int, digits: Int) -> String {
        let width = max(digits, 0)
        var digitsString = String(abs(value))
        if digitsString.count < width {
            digitsString = String(repeating: "0", count: width - digitsString.count) + digitsString
        }
        return value < 0 ? "-\(digitsString)" : digitsString
    }

    // MARK: - Date tokens

    /// Expands a single date-token letter (`Y`, `M`, `D`, `h`, `m`, `s`, or
    /// `d`) using `dateCalendar` (Gregorian, UTC).
    private static func dateToken(_ letter: Character, modified: Date) -> String {
        let comps = dateCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: modified)
        switch letter {
        case "Y":
            return String(format: "%04d", comps.year ?? 0)
        case "M":
            return String(format: "%02d", comps.month ?? 0)
        case "D":
            return String(format: "%02d", comps.day ?? 0)
        case "h":
            return String(format: "%02d", comps.hour ?? 0)
        case "m":
            return String(format: "%02d", comps.minute ?? 0)
        case "s":
            return String(format: "%02d", comps.second ?? 0)
        case "d":
            return dateToken("Y", modified: modified) + dateToken("M", modified: modified) + dateToken("D", modified: modified)
        default:
            return ""
        }
    }

    // MARK: - Search / replace

    /// Applies `spec`'s search/replace step to the mask-expanded combined
    /// name. Does nothing when `spec.search` is empty. Multiple terms
    /// separated by `|` in `search` pair positionally with `|`-separated
    /// terms in `replace`; a search term with no matching replace term uses
    /// `""`. Empty individual terms (e.g. from `"a||b"`) are skipped so they
    /// cannot match everywhere.
    private static func applySearchReplace(_ text: String, spec: RenameSpec) -> String {
        guard !spec.search.isEmpty else { return text }
        let searchTerms = spec.search.components(separatedBy: "|")
        let replaceTerms = spec.replace.components(separatedBy: "|")
        var result = text
        for (index, term) in searchTerms.enumerated() {
            guard !term.isEmpty else { continue }
            let replacement = index < replaceTerms.count ? replaceTerms[index] : ""
            result = applySingleReplace(result, search: term, replace: replacement, spec: spec)
        }
        return result
    }

    private static func applySingleReplace(_ text: String, search: String, replace: String, spec: RenameSpec) -> String {
        if spec.useRegex {
            var options: NSRegularExpression.Options = []
            if !spec.caseSensitive {
                options.insert(.caseInsensitive)
            }
            guard let regex = try? NSRegularExpression(pattern: search, options: options) else {
                // Invalid pattern: leave the text unchanged rather than crash.
                return text
            }
            if spec.repeatReplace {
                var current = text
                var iterations = 0
                while iterations < maxReplaceIterations {
                    let range = NSRange(current.startIndex..<current.endIndex, in: current)
                    let next = regex.stringByReplacingMatches(in: current, options: [], range: range, withTemplate: replace)
                    if next == current { break }
                    current = next
                    iterations += 1
                }
                return current
            } else {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replace)
            }
        } else {
            let compareOptions: String.CompareOptions = spec.caseSensitive ? [] : [.caseInsensitive]
            if spec.repeatReplace {
                var current = text
                var iterations = 0
                while iterations < maxReplaceIterations {
                    let next = current.replacingOccurrences(of: search, with: replace, options: compareOptions)
                    if next == current { break }
                    current = next
                    iterations += 1
                }
                return current
            }
            return text.replacingOccurrences(of: search, with: replace, options: compareOptions)
        }
    }

    // MARK: - Case mode

    /// Applies `mode` to the whole combined (post search/replace) name.
    private static func applyCase(_ text: String, mode: RenameCase) -> String {
        switch mode {
        case .unchanged:
            return text
        case .lower:
            return text.localizedLowercase
        case .upper:
            return text.localizedUppercase
        case .firstUpper:
            guard let first = text.first else { return text }
            return String(first).localizedUppercase + text.dropFirst().localizedLowercase
        case .everyWord:
            return everyWordCase(text)
        }
    }

    /// `.everyWord`: uppercases the first letter of every word and
    /// lowercases the rest, where a "word" is a maximal run of characters
    /// that are not a space, underscore, dot, or hyphen (so, deliberately,
    /// the extension separator dot also starts a new "word" - e.g.
    /// `"my_photo.jpg"` -> `"My_Photo.Jpg"`).
    private static func everyWordCase(_ text: String) -> String {
        var result = ""
        var atWordStart = true
        for ch in text {
            if isWordBoundaryCharacter(ch) {
                result.append(ch)
                atWordStart = true
            } else {
                result += atWordStart ? String(ch).localizedUppercase : String(ch).localizedLowercase
                atWordStart = false
            }
        }
        return result
    }
}
