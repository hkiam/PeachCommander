// SPDX-License-Identifier: Apache-2.0
// PanelController+Clipboard.swift - Clipboard (Cmd+C/X/V) and F4 edit (I04 T07/T08).
//
// Writes Finder-compatible file URLs to the general pasteboard. A cut is a copy
// to the pasteboard plus a marker (the pasteboard change count) so that the next
// paste of that exact content performs a move instead of a copy.

import AppKit
import PCFoundation
import PCOperations

/// Tracks the pasteboard change count at the moment of the last "cut".
enum ClipboardState {
    static var cutChangeCount: Int = -1
}

extension PanelController {

    func copyToClipboard() async {
        let items = await selectedOrCursorPaths()
        guard !items.isEmpty else { return }
        writeToPasteboard(items)
        ClipboardState.cutChangeCount = -1
    }

    func cutToClipboard() async {
        let items = await selectedOrCursorPaths()
        guard !items.isEmpty else { return }
        let changeCount = writeToPasteboard(items)
        ClipboardState.cutChangeCount = changeCount
    }

    func pasteFromClipboard() async {
        let pb = NSPasteboard.general
        guard let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty else { return }
        let dest = await getCurrentDirectory()
        let items = urls.map { $0.path }
        let isCut = pb.changeCount == ClipboardState.cutChangeCount
        await runTransfer(isCut ? .move(items: items, toDirectory: dest, options: defaultCopyOptions())
                                : .copy(items: items, toDirectory: dest, options: defaultCopyOptions()),
                          title: isCut ? String(localized: "Moving") : String(localized: "Copying"))
        if isCut { ClipboardState.cutChangeCount = -1 }
    }

    func editCursorFile() async {
        guard let path = tableView.cursorItemFullPath() else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func editNewFile() async {
        let parent = await getCurrentDirectory()
        let dialog = InputDialog(title: String(localized: "New Text File"),
                                 prompt: String(localized: "File name:"),
                                 initialValue: "new.txt")
        var name: String?
        dialog.onConfirm = { name = $0 }
        dialog.runModalDialog()
        guard let leaf = name?.trimmingCharacters(in: .whitespaces), !leaf.isEmpty else { return }
        let full = (parent as NSString).appendingPathComponent(leaf)
        if !FileManager.default.fileExists(atPath: full) {
            FileManager.default.createFile(atPath: full, contents: Data())
        }
        await reload()
        NSWorkspace.shared.open(URL(fileURLWithPath: full))
    }

    // MARK: - Copy names to clipboard (I13 §6, F-092)

    func copyNamesToClip() async {
        let items = await selectedOrCursorPaths()
        guard !items.isEmpty else { return }
        writeText(items.map { ($0 as NSString).lastPathComponent }.joined(separator: "\n"))
    }

    func copyFullNamesToClip() async {
        let items = await selectedOrCursorPaths()
        guard !items.isEmpty else { return }
        writeText(items.joined(separator: "\n"))
    }

    func copyNetNamesToClip() async {
        let items = await selectedOrCursorPaths()
        guard !items.isEmpty else { return }
        let urls = items.map { URL(fileURLWithPath: $0).absoluteString }
        writeText(urls.joined(separator: "\n"))
    }

    func copySrcPathToClip() async {
        writeText(await currentDirectory())
    }

    func copyFileDetailsToClip() async {
        let names = Set(await selectedOrCursorPaths().map { ($0 as NSString).lastPathComponent })
        guard !names.isEmpty else { return }
        let rows = fileListRows(namesFilter: names)
        writeText(FileListFormatter.format(rows, as: .tsv))
    }

    // MARK: - Helpers

    private func writeText(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    @discardableResult
    private func writeToPasteboard(_ paths: [String]) -> Int {
        let pb = NSPasteboard.general
        pb.clearContents()
        let objects = paths.map { URL(fileURLWithPath: $0) as NSURL }
        pb.writeObjects(objects)
        return pb.changeCount
    }

    private func getCurrentDirectory() async -> String {
        await currentDirectory()
    }
}
