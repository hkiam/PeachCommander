// SPDX-License-Identifier: Apache-2.0
// MnuMenuBuilder.swift - Build live NSMenus from a parsed TC .mnu (F-257).
//
// Walks a MenuFile tree and produces the "command" menus for the main bar, using
// the SAME item convention as AppMenu.command(...): every command item carries its
// resolved cm_/em_ name in `representedObject` and shares the one `commandAction`
// selector, so dispatch (runMenuCommand → runCommandNamed), keymap accelerator
// application and the enable/disable pass (KeymapMenu) all keep working unchanged.
// Accelerators in the .mnu (the "\t<key>" caption hint) are intentionally ignored
// in v1 — the active keymap remains the source of truth for shortcuts.

import AppKit
import PCFoundation

enum MnuMenuBuilder {

    /// Build one NSMenu per top-level popup in `roots`. `resolve` maps a raw command
    /// token (numeric TC id or cm_/em_ name) to a cm_/em_ name; unresolved tokens are
    /// passed through so the later keymap pass can disable them.
    static func build(roots: [MenuNode], target: AnyObject, action: Selector,
                      resolve: (String) -> String) -> [NSMenu] {
        var menus: [NSMenu] = []
        for node in roots {
            if case .popup(let caption, let children) = node {
                let menu = NSMenu(title: MenuFile.displayCaption(caption))
                fill(menu, children: children, target: target, action: action, resolve: resolve)
                menus.append(menu)
            }
            // Top-level non-popup entries have no menu-bar home; ignore them.
        }
        return menus
    }

    private static func fill(_ menu: NSMenu, children: [MenuNode], target: AnyObject,
                             action: Selector, resolve: (String) -> String) {
        for child in children {
            switch child {
            case .separator:
                menu.addItem(.separator())
            case .command(let caption, let command):
                let item = NSMenuItem(title: MenuFile.displayCaption(caption), action: action, keyEquivalent: "")
                item.target = target
                item.representedObject = resolve(command)
                menu.addItem(item)
            case .popup(let caption, let subChildren):
                let sub = NSMenu(title: MenuFile.displayCaption(caption))
                fill(sub, children: subChildren, target: target, action: action, resolve: resolve)
                let item = NSMenuItem(title: MenuFile.displayCaption(caption), action: nil, keyEquivalent: "")
                item.submenu = sub
                menu.addItem(item)
            }
        }
    }
}
