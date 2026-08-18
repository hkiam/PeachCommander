// SPDX-License-Identifier: Apache-2.0
// MnuMenuBuilder.swift - Build live NSMenus from a parsed TC .mnu (F-257).
//
// Walks a MenuFile tree and produces the "command" menus for the main bar, using
// the SAME item convention as AppMenu.command(...): every command item carries its
// resolved cm_/em_ name in `representedObject` and shares the one `commandAction`
// selector, so dispatch (runMenuCommand → runCommandNamed / runUserCommand), keymap
// accelerator application and the enable/disable pass (KeymapMenu) all keep working
// unchanged. Accelerators in the .mnu (the "\t<key>" caption hint) are intentionally
// ignored — the active keymap remains the source of truth for shortcuts, so a label
// out of the file would state a key that may not be bound.
//
// A token that resolves to nothing (a numeric TC id this app has no command for — TC
// has several hundred, this registry ~150 — or a misspelled name) becomes a *visibly
// disabled* item and is reported to the caller. It used to be passed through as the
// represented command, where KeymapMenu's enable pass ignored it for not starting
// with `cm_`: the entry looked live and did nothing when clicked.

import AppKit
import PCFoundation

enum MnuMenuBuilder {

    struct Result {
        /// One menu per top-level popup, in file order.
        let menus: [NSMenu]
        /// Raw command tokens that resolved to no command, in file order (duplicates kept
        /// out; the caller reports them).
        let unresolved: [String]
    }

    /// Build one NSMenu per top-level popup in `roots`. `resolve` maps a raw command
    /// token (numeric TC id or cm_/em_ name) to a cm_/em_ name, or nil when this app
    /// has no such command.
    static func build(roots: [MenuNode], target: AnyObject, action: Selector,
                      resolve: (String) -> String?) -> Result {
        var menus: [NSMenu] = []
        var unresolved: [String] = []
        for node in roots {
            if case .popup(let caption, let children) = node {
                let menu = NSMenu(title: MenuFile.displayCaption(caption))
                fill(menu, children: children, target: target, action: action,
                     resolve: resolve, unresolved: &unresolved)
                menus.append(menu)
            }
            // Top-level non-popup entries have no menu-bar home; the parser reports them
            // (MenuDiagnostic.itemOutsideMenu), so dropping them here is not silent.
        }
        return Result(menus: menus, unresolved: unresolved)
    }

    private static func fill(_ menu: NSMenu, children: [MenuNode], target: AnyObject,
                             action: Selector, resolve: (String) -> String?,
                             unresolved: inout [String]) {
        for child in children {
            switch child {
            case .separator:
                menu.addItem(.separator())
            case .command(let caption, let command):
                let title = MenuFile.displayCaption(caption)
                guard let resolved = resolve(command) else {
                    // No action and no represented command: AppKit disables it, KeymapMenu
                    // skips it, and the user sees their own caption greyed out rather than a
                    // menu entry that swallows the click.
                    let dead = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                    dead.isEnabled = false
                    menu.addItem(dead)
                    if !unresolved.contains(command) { unresolved.append(command) }
                    continue
                }
                let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
                item.target = target
                item.representedObject = resolved
                menu.addItem(item)
            case .popup(let caption, let subChildren):
                let sub = NSMenu(title: MenuFile.displayCaption(caption))
                fill(sub, children: subChildren, target: target, action: action,
                     resolve: resolve, unresolved: &unresolved)
                let item = NSMenuItem(title: MenuFile.displayCaption(caption), action: nil, keyEquivalent: "")
                item.submenu = sub
                menu.addItem(item)
            }
        }
    }
}
