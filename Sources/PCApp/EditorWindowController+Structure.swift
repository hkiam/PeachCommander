// SPDX-License-Identifier: Apache-2.0
// EditorWindowController+Structure.swift - Working with JSON, YAML and XML by structure (F-369).
//
// The outline sidebar (F-368) gave these formats a tree. This is what an administrator actually does with
// one: move out to the enclosing service, on to the next server, select the block, copy the path for a jq
// filter, and check the file before saving it into a deployment.
//
// Everything here is a query against that same tree, so it works for every format the outline supports —
// and nothing here parses text a second time.
//
// Shortcuts: ⌃⌘ plus the arrow keys, as a four-way structural move (out, in, previous, next). Ctrl+Cmd
// with arrows is free on macOS, unlike ⌥⇧arrow (extend selection by word) and ⌃arrow (Spaces), both of
// which would shadow bindings people rely on. See Tools/check-hotkeys.py, which fails the build on a
// shortcut that is taken twice or reserved by the system.

import AppKit
import PCFoundation

extension EditorWindowController {

    /// The Structure menu: navigation, selection, the path, and validation.
    ///
    /// Built only for files that have a structure to navigate — for a Swift file the outline comes from
    /// tree-sitter and these operations are either meaningless (a jq path) or already covered.
    func makeStructureMenu(forPullDown: Bool) -> NSMenu {
        let menu = NSMenu(title: String(localized: "Structure"))
        if forPullDown {
            menu.addItem(NSMenuItem(title: String(localized: "Structure"), action: nil, keyEquivalent: ""))
        }
        func add(_ title: String, _ action: Selector, _ key: String,
                 _ mask: NSEvent.ModifierFlags = [.control, .command]) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = mask
            item.target = self
            menu.addItem(item)
        }
        // The arrow keys as characters: AppKit matches a key equivalent against the character the key
        // produces, and for the arrows those are the private-use scalars below.
        let up = String(UnicodeScalar(NSUpArrowFunctionKey)!)
        let down = String(UnicodeScalar(NSDownArrowFunctionKey)!)
        let left = String(UnicodeScalar(NSLeftArrowFunctionKey)!)
        let right = String(UnicodeScalar(NSRightArrowFunctionKey)!)
        add(String(localized: "Go to Enclosing Node"), #selector(structureGoToParent), up)
        add(String(localized: "Go to First Child"), #selector(structureGoToChild), down)
        add(String(localized: "Go to Previous Sibling"), #selector(structureGoToPrevious), left)
        add(String(localized: "Go to Next Sibling"), #selector(structureGoToNext), right)
        menu.addItem(.separator())
        add(String(localized: "Select Enclosing Node"), #selector(structureSelectEnclosing), "a")
        menu.addItem(.separator())
        add(String(localized: "Copy Structural Path"), #selector(structureCopyPath), "c")
        menu.addItem(.separator())
        add(String(localized: "Validate Document"), #selector(structureValidate), "v")
        menu.addItem(.separator())
        // ⌥⌘ with the arrows, as Xcode binds folding — a different family from the ⌃⌘ navigation above, so
        // collapsing a block and moving to one are not neighbouring keystrokes.
        add(String(localized: "Fold Node"), #selector(structureFold), left, [.option, .command])
        add(String(localized: "Unfold Node"), #selector(structureUnfold), right, [.option, .command])
        add(String(localized: "Fold Top Level"), #selector(structureFoldAll), up, [.option, .command])
        add(String(localized: "Unfold All"), #selector(structureUnfoldAll), down, [.option, .command])
        // The transformations get no shortcuts: they rewrite the whole document, and a document-wide
        // rewrite one keystroke away from a navigation command is a mistake waiting to be made.
        menu.addItem(.separator())
        for transform in StructureTransforms.available(forExtension: (path as NSString).pathExtension) {
            let item = NSMenuItem(title: Self.title(for: transform),
                                  action: #selector(structureTransform(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = transform.rawValue
            menu.addItem(item)
        }
        return menu
    }

    /// The menu title for a transformation. Named after what the user gets, not after the function.
    static func title(for transform: StructureTransforms.Transform) -> String {
        switch transform {
        case .minify: return String(localized: "Minify (one line)")
        case .sortKeys: return String(localized: "Sort Keys Recursively")
        case .escapeAsJSONString: return String(localized: "Escape as JSON String")
        case .unescapeJSONString: return String(localized: "Unescape JSON String")
        case .jsonToYAML: return String(localized: "Convert JSON to YAML")
        }
    }

    /// Whether this file has a structure these commands can work on.
    var hasNavigableStructure: Bool {
        StructureOutline.supports(ext: (path as NSString).pathExtension)
    }

    // MARK: - Navigation

    @objc func structureGoToParent() {
        move(to: StructureNavigation.parent(symbolSidebar.tree, at: caret),
             whenMissing: String(localized: "Already at the outermost level."))
    }

    @objc func structureGoToChild() {
        move(to: StructureNavigation.firstChild(symbolSidebar.tree, at: caret),
             whenMissing: String(localized: "Nothing is nested here."))
    }

    @objc func structureGoToNext() {
        move(to: StructureNavigation.sibling(symbolSidebar.tree, at: caret, delta: 1),
             whenMissing: String(localized: "Last entry at this level."))
    }

    @objc func structureGoToPrevious() {
        move(to: StructureNavigation.sibling(symbolSidebar.tree, at: caret, delta: -1),
             whenMissing: String(localized: "First entry at this level."))
    }

    /// Select the whole node the caret is in; repeating it grows outwards.
    @objc func structureSelectEnclosing() {
        let selection = textView.selectedRange()
        let range = selection.location..<(selection.location + selection.length)
        guard let node = StructureNavigation.enclosing(symbolSidebar.tree, selection: range) else {
            structureNote(String(localized: "Nothing larger to select."))
            NSSound.beep()
            return
        }
        let length = textView.string.utf16.count
        let start = max(0, min(node.start, length))
        let end = max(start, min(node.end, length))
        let target = NSRange(location: start, length: end - start)
        textView.setSelectedRange(target)
        textView.scrollRangeToVisible(target)
        structureNote(String(format: String(localized: "Selected %@ — %d line(s)."), node.name,
                             LineEndings.lineCount((textView.string as NSString).substring(with: target))))
    }

    // MARK: - Path

    /// Put the caret's path on the clipboard in the notation the format's own tools take.
    @objc func structureCopyPath() {
        let ext = (path as NSString).pathExtension
        guard let style = StructurePath.style(forExtension: ext) else {
            structureNote(String(localized: "This format has no path notation."))
            return
        }
        guard let text = StructurePath.path(symbolSidebar.tree, utf16: caret, style: style) else {
            structureNote(String(localized: "The caret is not inside any node."))
            NSSound.beep()
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        structureNote(String(format: String(localized: "Copied: %@"), text))
    }

    // MARK: - Validation

    /// Check the document and put the caret on the first problem.
    ///
    /// The caret move is the feature. "Invalid JSON" is what the Format button already says, and it leaves
    /// the user to find the missing comma in 900 lines.
    @objc func structureValidate() {
        let ext = (path as NSString).pathExtension
        let outcome = StructureValidator.validate(textView.string, ext: ext)
        if case .problem(let problem) = outcome {
            let length = textView.string.utf16.count
            let location = max(0, min(problem.utf16Location, length))
            let range = NSRange(location: location, length: min(1, length - location))
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
            textView.window?.makeFirstResponder(textView)
            NSSound.beep()
        }
        structureNote(StructureProblemText.summary(for: outcome))
    }

    // MARK: - Folding (F-371)

    /// Collapse the body of the node the caret is in.
    @objc func structureFold() {
        // Innermost first, then outwards along the enclosing path: the caret usually sits on a leaf like
        // `image: nginx`, which is one line and has no body, so the useful answer is the nearest ancestor
        // that *can* be folded. Walking by "the parent of the position before this node" instead landed a
        // line earlier and folded the grandparent — `services` where the user meant `web`.
        let path = symbolSidebar.enclosingPath(utf16: caret)
        guard !path.isEmpty else {
            structureNote(String(localized: "The caret is not inside any node."))
            NSSound.beep()
            return
        }
        let text = textView.string as NSString
        for node in path.reversed() where folding.fold(node: node, in: text) {
            afterFoldChange()
            structureNote(String(format: String(localized: "Folded %@."), node.name))
            return
        }
        structureNote(String(localized: "Nothing here can be folded."))
        NSSound.beep()
    }

    @objc func structureUnfold() {
        guard folding.unfold(at: caret, in: textView.string as NSString) else {
            structureNote(String(localized: "Nothing is folded here."))
            NSSound.beep()
            return
        }
        afterFoldChange()
        structureNote(String(localized: "Unfolded."))
    }

    /// Collapse every node at the outermost level — the overview of a long file in one keystroke.
    @objc func structureFoldAll() {
        let count = folding.foldAll(symbolSidebar.tree, in: textView.string as NSString)
        guard count > 0 else {
            structureNote(String(localized: "Nothing here can be folded."))
            NSSound.beep()
            return
        }
        afterFoldChange()
        structureNote(String(format: String(localized: "Folded %d node(s)."), count))
    }

    @objc func structureUnfoldAll() {
        let count = folding.unfoldAll()
        guard count > 0 else {
            structureNote(String(localized: "Nothing is folded."))
            return
        }
        afterFoldChange()
        structureNote(String(format: String(localized: "Unfolded %d node(s)."), count))
    }

    /// Mark the header lines of every fold, so a collapsed block is visibly collapsed.
    ///
    /// A temporary attribute, not a real one: it must not become part of the document, and it must
    /// survive neither a save nor an undo. Text that is simply *gone* from the screen with nothing to
    /// show why is the failure mode of every folding editor.
    private func afterFoldChange() {
        guard let manager = textView.layoutManager else { return }
        let text = textView.string as NSString
        let whole = NSRange(location: 0, length: text.length)
        manager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: whole)
        for range in folding.hidden where range.location > 0 {
            let header = text.lineRange(for: NSRange(location: range.location - 1, length: 0))
            manager.addTemporaryAttributes([.backgroundColor: Theme.current.selectionFillActive.withAlphaComponent(0.35)],
                                           forCharacterRange: header)
        }
        refreshHighlightAfterFold()
    }

    // MARK: - Transformations

    /// Apply a whole-document transformation, in one undoable step.
    ///
    /// The selection is used when there is one — escaping *this* certificate rather than the file — and
    /// otherwise the whole document. Written through `EditorTextFilter.replace`, never by assigning
    /// `textView.string`: that clears the undo stack, and the first thing anybody does after a
    /// transformation they did not expect is press Cmd+Z (see CONVENTIONS.md).
    @objc func structureTransform(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let transform = StructureTransforms.Transform(rawValue: raw) else { return }
        let selection = textView.selectedRange()
        let whole = NSRange(location: 0, length: textView.string.utf16.count)
        let range = selection.length > 0 ? selection : whole
        let input = (textView.string as NSString).substring(with: range)
        let title = Self.title(for: transform)
        do {
            let output = try StructureTransforms.apply(transform, to: input,
                                                       ext: (path as NSString).pathExtension)
            guard output != input else {
                structureNote(String(format: String(localized: "%@: nothing changed."), title))
                return
            }
            guard EditorTextFilter.replace(range, with: output, in: textView, actionName: title) else {
                structureNote(String(format: String(localized: "%@: the document is read-only."), title))
                return
            }
            afterProgrammaticEdit()
            structureNote(String(format: String(localized: "%@ — %d line(s)."), title,
                                 LineEndings.lineCount(output)))
        } catch {
            // The document is untouched. Saying why beats saying "failed": a trailing comma and a missing
            // brace need different fixes.
            structureNote(String(format: String(localized: "%@ failed: %@"), title,
                                 Self.reason(for: error)))
            NSSound.beep()
        }
    }

    private static func reason(for error: Error) -> String {
        switch error {
        case StructureTransforms.TransformError.invalid(let message):
            return message
        case StructureTransforms.TransformError.notApplicable:
            return String(localized: "the text is not a JSON string")
        case StructureTransforms.TransformError.cannotRepresent(let what):
            return String(format: String(localized: "%@ cannot represent this value"), what)
        default:
            return error.localizedDescription
        }
    }

    // MARK: - Shared

    private var caret: Int { textView.selectedRange().location }

    private func move(to node: SymbolNode?, whenMissing message: String) {
        guard let node else {
            structureNote(message)
            NSSound.beep()
            return
        }
        let length = textView.string.utf16.count
        let location = max(0, min(node.utf16Location, length))
        let range = NSRange(location: location, length: 0)
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        textView.window?.makeFirstResponder(textView)
        structureNote(node.name)
    }

    /// Say it in the window's subtitle: a sheet for "last entry at this level" would be absurd, and the
    /// status line already carries the breadcrumb.
    private func structureNote(_ text: String) {
        window?.subtitle = text
    }
}

#if DEBUG
extension EditorWindowController {

    /// Diagnostic: exercise the Structure menu the way a user does — by *sending the menu items*, not by
    /// calling the methods — and report what each one did (F-369).
    ///
    /// Going through the menu is the point: an item whose target is wrong, or whose selector no longer
    /// exists, is disabled on screen and works perfectly when called directly. That is the class of defect
    /// this project has shipped before.
    func automationStructure(startAt needle: String) -> String {
        var report = ""
        let ns = textView.string as NSString
        let start = ns.range(of: needle).location
        report += "start=\(start == NSNotFound ? -1 : start) needle=\(needle)\n"
        guard start != NSNotFound else { return report + "FAILED: needle not in document\n" }
        textView.setSelectedRange(NSRange(location: start, length: 0))

        let menu = makeStructureMenu(forPullDown: false)
        func fire(_ title: String) -> String {
            guard let item = menu.items.first(where: { $0.title.hasPrefix(title) }) else {
                return "NO SUCH ITEM"
            }
            guard let action = item.action, let target = item.target,
                  (target as? NSObject)?.responds(to: action) == true else {
                return "NOT WIRED (target=\(item.target == nil ? "nil" : "set"))"
            }
            window?.subtitle = ""
            NSApp.sendAction(action, to: target, from: item)
            let selection = textView.selectedRange()
            return "sel=\(selection.location)+\(selection.length) said=\(window?.subtitle ?? "")"
        }
        for title in ["Go to First Child", "Go to Next Sibling", "Go to Previous Sibling",
                      "Go to Enclosing Node", "Copy Structural Path", "Select Enclosing Node",
                      "Select Enclosing Node", "Validate Document"] {
            report += "\(title): \(fire(title))\n"
        }
        // The transformations rewrite the document, so they run last and each one reports what the text
        // became — read back from the text view, because that is the thing that is written to disk.
        //
        // Only the ones this format offers: minify and sort keys are JSON-only, and firing them on a YAML
        // file reported "NO SUCH ITEM" for a menu that is correctly not there. The list is dumped so the
        // format-dependence itself is checked.
        let transforms = StructureTransforms.available(forExtension: (path as NSString).pathExtension)
        report += "transforms=" + transforms.map(\.rawValue).joined(separator: ",") + "\n"
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        for title in transforms.map(Self.title(for:)) {
            let before = textView.string
            let outcome = fire(title)
            let after = textView.string
            report += "\(title): \(outcome) changed=\(before != after) "
                + "undo=\(textView.undoManager?.canUndo == true) "
                + "text=\(after.replacingOccurrences(of: "\n", with: "⏎").prefix(90))\n"
        }
        // Folding (F-371): the number of line fragments actually laid out is the only honest measure —
        // reading the folded ranges back would prove the bookkeeping, not that anything is hidden.
        textView.setSelectedRange(NSRange(location: start, length: 0))
        report += "fragments=\(automationVisibleLineCount()) folds=\(folding.hidden.count)\n"
        // Each measured from an unfolded document, or the second one reports "nothing to fold" for the
        // right reason in the wrong place — which is exactly what the first run of this did.
        for title in ["Fold Node", "Unfold All", "Fold Top Level", "Unfold All"] {
            let said = fire(title)
            report += "\(title): \(said) fragments=\(automationVisibleLineCount()) "
                + "folds=\(folding.hidden.count)\n"
        }
        // And the safety rule: a caret placed inside a fold must open it again.
        _ = fire("Fold Top Level")
        let insideFold = folding.hidden.first.map { $0.location + 1 } ?? 0
        textView.setSelectedRange(NSRange(location: insideFold, length: 0))
        report += "caretIntoFold: folds=\(folding.hidden.count) "
            + "fragments=\(automationVisibleLineCount())\n"
        // Leave the document folded, so the screenshot shows a collapsed block and its marked header line
        // rather than the state after the last unfold.
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        _ = fire("Fold Top Level")
        report += "clipboard=\(NSPasteboard.general.string(forType: .string) ?? "")\n"
        report += "shortcuts=" + menu.items.filter { !$0.keyEquivalent.isEmpty }
            .map { "\($0.title)|\($0.keyEquivalent.unicodeScalars.map { s in s.value < 128 ? String(s) : "arrow" }.joined())" }
            .joined(separator: " ") + "\n"
        return report
    }
}
#endif
