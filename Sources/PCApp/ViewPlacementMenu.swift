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
        // The same words the View menu uses. "Move to Bottom Dock" against a menu item called
        // "Bottom Area" is two names for one place, which is how a user learns to distrust both.
        case "bottom": return String(localized: "Bottom Area")
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

/// The pasteboard type a plugin view is dragged on.
///
/// Private to the app: a view id means nothing outside it, and a drag that other applications could
/// accept would let someone drop a panel into a text editor and wonder why nothing happened.
extension NSPasteboard.PasteboardType {
    static let pcPluginView = NSPasteboard.PasteboardType("com.peachcommander.plugin-view")
}

/// A segmented control that asks for its context menu when it is needed, and can be dragged.
///
/// The menu depends on which segment is selected and on where the view currently sits, so a menu
/// assigned once would be stale the first time either changed.
///
/// Dragging carries the *showing* view, for the same reason the menu acts on it: a segmented control
/// does not publish its per-segment rectangles, so working out which one the finger went down on
/// means guessing at its internal metrics.
final class PlacementSegmentedControl: NSSegmentedControl, NSDraggingSource {
    var contextMenuProvider: (() -> NSMenu?)?
    /// The view id to drag, or nil when what is showing is not movable (a built-in mode).
    var draggableViewId: (() -> String?)?
    /// A picture for the drag. Without one the pointer carries nothing and the gesture feels broken.
    var dragImageProvider: (() -> NSImage?)?

    override func menu(for event: NSEvent) -> NSMenu? { contextMenuProvider?() }

    private var mouseDownPoint: NSPoint?

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        // A threshold, or every slightly imprecise click on a segment becomes a drag and the control
        // stops being clickable.
        guard let start = mouseDownPoint, let id = draggableViewId?() else {
            super.mouseDragged(with: event)
            return
        }
        let here = convert(event.locationInWindow, from: nil)
        guard abs(here.x - start.x) > 4 || abs(here.y - start.y) > 4 else {
            super.mouseDragged(with: event)
            return
        }
        mouseDownPoint = nil

        let item = NSPasteboardItem()
        item.setString(id, forType: .pcPluginView)
        let dragItem = NSDraggingItem(pasteboardWriter: item)
        let image = dragImageProvider?() ?? NSImage(size: NSSize(width: 60, height: 20))
        dragItem.setDraggingFrame(NSRect(origin: here, size: image.size), contents: image)
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }
}

/// What a container does with a dropped plugin view.
///
/// Shared by the side panel and the bottom area so the two cannot drift: both light up for the same
/// drag, refuse the same ones, and hand the same id to the same place.
@MainActor
final class ViewDropTarget {
    /// Called with the dropped view id. The container knows nothing about placement.
    var onDrop: ((String) -> Void)?
    /// The container's own name, so a view already here is refused rather than "moved" to itself.
    let container: String
    private(set) var isHighlighted = false

    init(container: String) { self.container = container }

    func draggedViewId(_ sender: NSDraggingInfo) -> String? {
        sender.draggingPasteboard.string(forType: .pcPluginView)
    }

    /// Would this drop do anything? A view already in this container would not — and refusing it is
    /// not pedantry: accepting would light the container up as a destination and then do nothing,
    /// which is the drag equivalent of a button that does not work.
    ///
    /// Decided on the id rather than on the drag, so the rule can be exercised without a drag. The
    /// gesture itself cannot be scripted, the same limitation the button bar's `bardrop` has.
    func accepts(viewId: String) -> Bool {
        ViewContainerRegistry.shared.container(ofViewId: viewId) != container
    }

    func accepts(_ sender: NSDraggingInfo) -> Bool {
        draggedViewId(sender).map(accepts(viewId:)) ?? false
    }

    func setHighlighted(_ on: Bool, in view: NSView) {
        guard isHighlighted != on else { return }
        isHighlighted = on
        view.needsDisplay = true
    }

    /// Draw the "drop here" outline. Inset by a point so it is not clipped by the view's own edge.
    func drawHighlight(in view: NSView) {
        guard isHighlighted else { return }
        let path = NSBezierPath(rect: view.bounds.insetBy(dx: 1.5, dy: 1.5))
        path.lineWidth = 3
        NSColor.controlAccentColor.setStroke()
        path.stroke()
    }

    @discardableResult
    func perform(viewId: String) -> Bool {
        guard accepts(viewId: viewId) else { return false }
        onDrop?(viewId)
        return true
    }

    func perform(_ sender: NSDraggingInfo) -> Bool {
        guard let id = draggedViewId(sender) else { return false }
        return perform(viewId: id)
    }
}
