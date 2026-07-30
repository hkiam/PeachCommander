// ContributionMenus.swift - Inject plugin menu contributions into the menu bar
// and validate their `when` enablement on open.
//
// Plugin items are appended to their target top-level menu (after a separator),
// ordered by (group, order). Each item rides the existing dispatch path
// (representedObject = commandId → runMenuCommand). A shared NSMenuDelegate
// re-evaluates each item's `when` expression against a fresh context snapshot in
// menuNeedsUpdate, so enablement tracks state without responder-chain validation
// (which the app does not use). `hides` remove built-in items by command id.
//
// v1 places plugin items at the end of the matched menu; fine-grained interleaving
// with built-ins arrives when built-ins themselves become contributions.
//
// Localization: leaf item titles arrive already localized from the registry
// (ContributionRegistry resolves each through the contributing plugin's own bundle,
// see PluginTitleLocalizer). Top-level menu matching (topSubmenu) tries the English
// title then its localized form so plugins still target e.g. "Commands"/"Befehle".

import AppKit
import PCPluginHost

@MainActor
enum ContributionMenuInjector {
    /// Inject the registry's menu contributions into `mainMenu`. Returns the
    /// validator (retain it; NSMenu holds its delegate weakly).
    static func inject(into mainMenu: NSMenu,
                       registry: ContributionRegistry,
                       target: AnyObject,
                       action: Selector,
                       contextProvider: @escaping () -> ContributionContext) -> ContributionMenuValidator {
        let validator = ContributionMenuValidator(contextProvider: contextProvider)

        // Group by the top-level menu (first path component); the remaining path
        // components (e.g. "Commands/Git") become nested submenus.
        let grouped = Dictionary(grouping: registry.menuItems()) {
            $0.contribution.menu.components(separatedBy: "/").first ?? $0.contribution.menu
        }
        for (menuTitle, items) in grouped {
            guard let topMenu = topSubmenu(mainMenu, title: menuTitle), !items.isEmpty else { continue }
            topMenu.addItem(.separator())
            for (contrib, title) in items {
                let container = nestedSubmenu(path: contrib.menu, topMenu: topMenu)
                let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
                item.representedObject = contrib.command
                item.target = target
                container.addItem(item)
                validator.track(item: item, in: container, when: contrib.when)
            }
        }

        // Static hiding of built-in items by command id (dynamic hiding: future).
        let hidden = registry.hiddenCommandIds(context: contextProvider())
        if !hidden.isEmpty { applyHides(mainMenu, hidden) }

        validator.installAsDelegate()
        return validator
    }

    private static func topSubmenu(_ menu: NSMenu, title: String) -> NSMenu? {
        menu.items.first { $0.submenu?.title == title }?.submenu
            ?? menu.items.first { $0.submenu?.title == String(localized: String.LocalizationValue(title)) }?.submenu
    }

    /// Resolve (find or create) the nested submenu for a `menu` path within its
    /// already-resolved top-level menu. "Commands/Git" → the "Git" submenu inside
    /// Commands; "Commands" → Commands itself.
    private static func nestedSubmenu(path: String, topMenu: NSMenu) -> NSMenu {
        var current = topMenu
        for title in path.components(separatedBy: "/").dropFirst() where !title.isEmpty {
            if let existing = current.items.first(where: { $0.submenu?.title == title })?.submenu {
                current = existing
            } else {
                let sub = NSMenu(title: title)
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.submenu = sub
                current.addItem(item)
                current = sub
            }
        }
        return current
    }

    private static func applyHides(_ menu: NSMenu, _ hidden: Set<String>) {
        for item in menu.items {
            if let cmd = item.representedObject as? String, hidden.contains(cmd) { item.isHidden = true }
            if let sub = item.submenu { applyHides(sub, hidden) }
        }
    }
}

/// Re-evaluates the `when` enablement of injected plugin menu items when their
/// menu is about to open.
@MainActor
final class ContributionMenuValidator: NSObject, NSMenuDelegate {
    private let contextProvider: () -> ContributionContext
    private var tracked: [ObjectIdentifier: [(item: NSMenuItem, when: String?)]] = [:]
    private var menus: [NSMenu] = []

    init(contextProvider: @escaping () -> ContributionContext) { self.contextProvider = contextProvider }

    func track(item: NSMenuItem, in menu: NSMenu, when: String?) {
        tracked[ObjectIdentifier(menu), default: []].append((item, when))
        if !menus.contains(where: { $0 === menu }) { menus.append(menu) }
    }

    func installAsDelegate() { for m in menus { m.delegate = self } }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let items = tracked[ObjectIdentifier(menu)] else { return }
        let ctx = contextProvider()
        for (item, when) in items {
            item.isEnabled = WhenExpression.evaluate(when, context: ctx)
        }
    }
}
