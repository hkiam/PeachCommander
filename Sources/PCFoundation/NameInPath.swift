// SPDX-License-Identifier: Apache-2.0
// NameInPath.swift - Which part of a path or a file name is "the name" (F-399, F-081).
//
// Two places in the app highlight a name for editing: the in-cell rename in the panel, and the
// dialogs that come up prefilled with a path (Shift+F5 "Copy as", Rename, New Text File). Both mean
// the same thing by "the name" — everything up to the last dot, with the extension left alone — and
// both had their own copy of the rule. This is the one rule, so the dialog and the cell editor
// cannot drift apart, and so it can be tested without a window.

import Foundation

public enum NameInPath {

    /// The range of the name inside a full path: the last component, without its extension.
    ///
    /// Four cases, all of which reach the prompts:
    ///
    ///   * `/dir/notes.txt` → `notes`, so the extension and the folder in front of it survive the
    ///     first keystroke.
    ///   * `/dir/.profile` → the whole name. A leading dot is part of the name, not an extension.
    ///   * `/dir/*.*` → the whole mask. That is what a multi-item copy offers, and its "extension"
    ///     is not something anybody keeps.
    ///   * `/dir/` → an empty range at the end, which leaves a plain caret rather than a selection.
    /// - Parameter isDirectory: whether the last component names a folder. It has no extension to
    ///   protect — `Backup 2026.01` is a folder with a dot in its name — and the in-cell rename has
    ///   always known that, so a dialog renaming the same thing has to be told.
    public static func range(in value: String, isDirectory: Bool = false) -> NSRange {
        let ns = value as NSString
        let separator = ns.range(of: "/", options: .backwards)
        let start = separator.location == NSNotFound ? 0 : separator.location + separator.length
        let name = ns.substring(from: start) as NSString
        // A mask is selected whole, and only here: a *prompt* can be prefilled with `*.*`, and
        // splitting that into `*` plus `.*` makes the one thing anybody types into it — a different
        // mask — a two-step edit. A file the panel is renaming in place cannot be a mask, it can
        // only be a file whose name happens to contain the character, and there `report*.txt` keeps
        // its extension like every other name. Which is why this is not in `basenameLength`.
        if name.rangeOfCharacter(from: Self.wildcards).location != NSNotFound {
            return NSRange(location: start, length: name.length)
        }
        return NSRange(location: start,
                       length: basenameLength(name as String, isDirectory: isDirectory))
    }

    private static let wildcards = CharacterSet(charactersIn: "*?")

    /// How much of a bare name is the name rather than the extension.
    ///
    /// `isDirectory` is the whole of it: a folder called `my.stuff` has no extension, it has a dot
    /// in its name, and renaming it must offer all of it.
    public static func basenameLength(_ name: String, isDirectory: Bool) -> Int {
        let ns = name as NSString
        if isDirectory { return ns.length }
        let dot = ns.range(of: ".", options: .backwards)
        if dot.location == NSNotFound || dot.location == 0 { return ns.length }
        return dot.location
    }
}
