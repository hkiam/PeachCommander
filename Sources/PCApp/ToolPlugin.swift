// ToolPlugin.swift - ToolHost: the host-services seam for action plugins.
//
// The base set of host services an action/tool needs (cursor, selection,
// Trash/delete via the op engine, panel reload, window presentation). It is the
// base protocol of `ContributionHost`, so an external contribution plugin reaches
// these through the unified PcHostServices C-ABI bridge. (The former in-process
// ToolPlugin protocol + registry are gone — tools are external contribution
// plugins now; see docs/plugin-contribution-architecture.md.)

import AppKit

/// Host services an action/tool plugin may use. Implemented by the window controller.
@MainActor
public protocol ToolHost: AnyObject {
    /// Full path of the item under the cursor in the active panel (nil on "..").
    func toolCursorPath() -> String?
    /// Local path of the cursor file, extracting from an archive to a temp file
    /// if needed; nil for a directory/".." or non-extractable item.
    func toolLocalCursorPath() async -> String?
    /// Marked selection, or the cursor item if nothing is marked.
    func toolSelectionPaths() async -> [String]
    /// The window tools should present sheets/modals over.
    var toolParentWindow: NSWindow? { get }
    /// Move paths to Trash (reversible).
    func toolMoveToTrash(_ paths: [String])
    /// Delete paths permanently.
    func toolDeletePermanently(_ paths: [String])
    /// Reload the active panel after a mutation.
    func toolReloadActivePanel()
    /// Show an informational message.
    func toolPresentInfo(_ title: String, _ message: String)
}
