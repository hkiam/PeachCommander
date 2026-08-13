// SPDX-License-Identifier: Apache-2.0
// RegexTextSearch.swift - Regular-expression find and replace over text held in memory (F-151).
//
// The editor's Find and Replace are the *native* macOS find bar (`NSTextFinder`), which is good at
// what it does — ⌘G, the shared find pasteboard, incremental highlighting — and cannot do regular
// expressions at all. Nothing in AppKit lets a pattern be handed to it: `NSTextFinder` searches on
// its own behalf, and its client protocol supplies text, not a matcher.
//
// So the pattern side is its own layer rather than a replacement for the bar, and the decisions that
// make it behave like a text editor rather than like `NSRegularExpression` live here, where they can
// be tested without a window:
//
//   * **Wrapping.** "Find next" from the last match wraps to the top, because that is what every
//     editor does and what ⌘G means; a search that simply stops looking reads as "no more matches"
//     when there are several above the caret.
//   * **Scope.** A selection is a scope, not a starting point: "replace in selection" must not touch
//     a line below it, and the caller gets the count so it can say what happened.
//   * **Empty matches.** A pattern like `x*` matches the empty string everywhere. Stepping through
//     those one at a time never advances, so an empty match moves the cursor on by one; replacing
//     them is left to `NSRegularExpression`, which handles it without looping.
//
// This is the in-memory counterpart to `ChunkRegexSearcher`, which does the same job for a file too
// large to hold. They deliberately do not share code: one answers in byte offsets over windows of a
// mapped file, the other in UTF-16 ranges over a String, and folding those together would give a
// type that is wrong for both.

import Foundation

public enum RegexTextSearch {

    /// Compile `pattern`, or the reason it will not compile.
    ///
    /// The reason is the point: a malformed pattern finds nothing, which reads exactly like "that
    /// text is not in this document" — so the user concludes the wrong thing and stops looking.
    public static func compile(_ pattern: String,
                               caseInsensitive: Bool) -> (regex: NSRegularExpression?, error: String?) {
        // Line anchors, as in the viewer: `^warning` means a line that begins with it, which is what
        // anyone typing it expects and what every other search tool means by it.
        var options: NSRegularExpression.Options = [.anchorsMatchLines]
        if caseInsensitive { options.insert(.caseInsensitive) }
        do { return (try NSRegularExpression(pattern: pattern, options: options), nil) }
        catch { return (nil, error.localizedDescription) }
    }

    /// The next match at or after `from`, wrapping to the start of `scope` when there is none below.
    ///
    /// Returns nil only when the pattern matches nowhere in `scope` at all — so a caller can tell
    /// "nothing to find" from "you have come back round to the first one".
    public static func next(_ regex: NSRegularExpression, in text: String,
                            from: Int, scope: NSRange? = nil) -> NSRange? {
        let ns = text as NSString
        let area = clamp(scope, to: ns.length)
        guard area.length > 0 else { return nil }
        let start = min(max(from, area.location), area.location + area.length)

        let ahead = NSRange(location: start, length: area.location + area.length - start)
        if ahead.length > 0, let m = regex.firstMatch(in: text, options: [], range: ahead) {
            return m.range
        }
        // Wrap: look again from the top of the scope.
        return regex.firstMatch(in: text, options: [], range: area)?.range
    }

    /// The last match strictly before `before`, wrapping to the end of `scope` when there is none.
    ///
    /// `NSRegularExpression` has no reverse mode, so this collects the matches ahead of the point
    /// and takes the last — which is also the only honest way to answer "the previous one" for a
    /// pattern whose matches can overlap in length.
    public static func previous(_ regex: NSRegularExpression, in text: String,
                                before: Int, scope: NSRange? = nil) -> NSRange? {
        let ns = text as NSString
        let area = clamp(scope, to: ns.length)
        guard area.length > 0 else { return nil }
        let end = min(max(before, area.location), area.location + area.length)

        let behind = NSRange(location: area.location, length: end - area.location)
        if behind.length > 0, let last = regex.matches(in: text, options: [], range: behind).last {
            return last.range
        }
        return regex.matches(in: text, options: [], range: area).last?.range
    }

    /// Every match in `scope`, in order — for counting and for highlighting all of them.
    public static func all(_ regex: NSRegularExpression, in text: String,
                           scope: NSRange? = nil) -> [NSRange] {
        let area = clamp(scope, to: (text as NSString).length)
        guard area.length > 0 else { return [] }
        return regex.matches(in: text, options: [], range: area).map(\.range)
    }

    /// Replace every match in `scope`, returning the rewritten *scope* and how many were replaced.
    ///
    /// `template` is `NSRegularExpression`'s: `$1` is the first capture group, `$0` the whole match,
    /// and `\$` a literal dollar. Only the scope comes back, not the whole document — the caller
    /// splices it in through whatever makes the change undoable, and handing back the full text
    /// would make "replace in selection" indistinguishable from "replace everywhere".
    public static func replaceAll(_ regex: NSRegularExpression, in text: String,
                                  template: String, scope: NSRange? = nil) -> (text: String, count: Int) {
        let ns = text as NSString
        let area = clamp(scope, to: ns.length)
        guard area.length > 0 else { return (ns.substring(with: area), 0) }
        let count = regex.numberOfMatches(in: text, options: [], range: area)
        guard count > 0 else { return (ns.substring(with: area), 0) }
        let replaced = regex.stringByReplacingMatches(in: text, options: [], range: area,
                                                      withTemplate: template)
        // `stringByReplacingMatches` returns the *whole* string with the scope rewritten, so cut the
        // scope back out — its length has changed by however much the replacements added or removed.
        let tail = ns.length - (area.location + area.length)
        let newLength = (replaced as NSString).length - area.location - tail
        return ((replaced as NSString).substring(with: NSRange(location: area.location,
                                                               length: max(0, newLength))), count)
    }

    /// Replace one match — the one at `range` — and return the text that goes in its place.
    ///
    /// Runs the template against that match alone, so `$1` refers to its capture groups and not to
    /// some other match's. Nil when `range` is not actually a match, which is how a stale selection
    /// (the document changed underneath it) is refused rather than silently rewritten.
    public static func replaceOne(_ regex: NSRegularExpression, in text: String,
                                  at range: NSRange, template: String) -> String? {
        let ns = text as NSString
        guard range.location >= 0, NSMaxRange(range) <= ns.length,
              let m = regex.firstMatch(in: text, options: [.anchored], range: range),
              m.range == range else { return nil }
        return regex.replacementString(for: m, in: text, offset: 0, template: template)
    }

    /// Where to continue a forward walk after a match, so an empty match cannot stall it.
    ///
    /// `x*` matches nothing, everywhere. Continuing at the match's end would hand back the same
    /// empty match for ever — pressing "find next" and watching the cursor not move.
    public static func advance(past range: NSRange) -> Int {
        range.length == 0 ? range.location + 1 : NSMaxRange(range)
    }

    private static func clamp(_ scope: NSRange?, to length: Int) -> NSRange {
        guard let scope else { return NSRange(location: 0, length: length) }
        let location = min(max(0, scope.location), length)
        return NSRange(location: location, length: min(scope.length, length - location))
    }
}
