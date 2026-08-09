// SPDX-License-Identifier: Apache-2.0
// ViewPlacementMenu.swift - Moving a plugin view from one container to another (F-381).
//
// A view's container used to be whatever its manifest said. Now the manifest declares the default and
// the user may disagree, which needs a way to say so. Dragging is the direct way; this is the one that
// can be found without knowing it exists, that works from the keyboard, and that VoiceOver can read —
// a drag is none of those things, and a feature reachable only by drag is a feature most people never
// discover.
//
// It acts on the view that is **currently showing** in a container rather than on whatever the pointer
// happens to be over. A segmented control does not publish its per-segment rectangles, so hit-testing
// one means guessing at its internal metrics; and acting on what the user can see is not a compromise
// forced by that — it is the less surprising rule anyway.
//
// Only containers that make sense as a destination are offered. "settings" holds the panes of the
// settings dialog and "titlebar" is a strip a few points tall; dropping a terminal into either is not
// a preference anybody has. Containers opt in when they register.

import AppKit
import PCFoundation

@MainActor
enum ViewPlacementMenu {

    /// What a container is called in front of a user. The registry knows containers by the names in
    /// the plugin ABI ("sidebar", "bottom"), which are not names to show anyone.
    static func displayName(forContainer container: String) -> String {
        switch container {
        case "sidebar": return String(localized: "Side Panel")
        case "bottom": return String(localized: "Bottom Dock")
        default: return container
        }
    }

    /// The menu for one plugin view, or nil when there is nothing to offer.
    ///
    /// Nothing to offer means: the view is not mounted, or there is exactly one place it could go and
    /// it is already there. A menu whose only item is disabled tells the user less than no menu.
    static func menu(forViewId viewId: String, title: String,
                     host: ContributionHost, controller: MainWindowController) -> NSMenu? {
        let registry = ViewContainerRegistry.shared
        guard let current = registry.container(ofViewId: viewId) else { return nil }
        let targets = registry.moveTargets.subtracting([current]).sorted()
        let moved = registry.isMoved(viewId: viewId)
        guard !targets.isEmpty || moved else { return nil }

        let menu = NSMenu()
        // Names the view, because the menu acts on the one that is showing and not on whatever the
        // pointer was over — with two views docked side by side that is worth spelling out.
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        for target in targets {
            let item = NSMenuItem(title: String(localized: "Move to \(displayName(forContainer: target))"),
                                  action: #selector(MainWindowController.movePluginViewFromMenu(_:)),
                                  keyEquivalent: "")
            item.target = controller
            item.representedObject = ViewPlacementRequest(viewId: viewId, container: target)
            menu.addItem(item)
        }

        if moved {
            menu.addItem(.separator())
            let item = NSMenuItem(title: String(localized: "Move Back to Default"),
                                  action: #selector(MainWindowController.movePluginViewFromMenu(_:)),
                                  keyEquivalent: "")
            item.target = controller
            // No container: "forget the override", which is not the same as writing the container the
            // manifest happens to name today. A plugin update may change its own default, and the user
            // who reset it should get the new one.
            item.representedObject = ViewPlacementRequest(viewId: viewId, container: nil)
            menu.addItem(item)
        }
        return menu
    }
}

/// What a placement menu item asks for. A class because `representedObject` is `Any?` and a reference
/// type survives the round trip through it without being boxed twice.
final class ViewPlacementRequest: NSObject {
    let viewId: String
    /// Where to put it, or nil to forget the override entirely.
    let container: String?
    init(viewId: String, container: String?) {
        self.viewId = viewId
        self.container = container
    }
}

/// A segmented control that asks for its context menu when it is needed rather than holding one.
///
/// The menu depends on which segment is selected and on where the view currently sits, so a menu
/// assigned once would be stale the first time either changed.
final class PlacementSegmentedControl: NSSegmentedControl {
    var contextMenuProvider: (() -> NSMenu?)?
    override func menu(for event: NSEvent) -> NSMenu? { contextMenuProvider?() }
}
