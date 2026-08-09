// SPDX-License-Identifier: Apache-2.0
// ViewContainerRegistry.swift - Generic named mount points for plugin views.
//
// Host areas that can host a plugin view register under a name ("sidebar",
// "preview", "bottombar", …). When the set of enabled view contributions changes,
// refresh(host:) rebuilds each container's provider list from the Contribution
// registry (filtered by `when`) and hands it to the container's mount closure.
// Each provider lazily instantiates the plugin's NSView via the behavior ABI
// (PcMakeView) and tears it down via PcCloseView. This is the foundation for
// "a plugin can embed a view at nearly any visual seam"; today one container
// (the preview panel as "sidebar") is wired, and more attach the same way.

import AppKit
import PCFoundation
import PCPluginHost

/// A plugin view a container can show: lazily built, and **not** the container's to destroy.
///
/// `makeView` is idempotent — asking twice gives the same view, not a second one — which is what lets
/// a view move from one container to another by being re-parented rather than rebuilt.
///
/// `closeView` tears the mount down for real (`PcCloseView`). The registry calls it itself for
/// contributions that have gone away, so **a container must not call it while handling a refresh**:
/// a view missing from the new list may simply have moved elsewhere, and closing it there would kill
/// whatever the plugin was running in it. Dropping the reference and letting the new container adopt
/// the view is the whole of a container's job. It stays available for a container that owns a view
/// outright and is genuinely finished with it — the settings window closing its panes.
struct PreviewViewProvider {
    let id: String
    let title: String
    let makeView: () -> NSView?
    let closeView: () -> Void
}

/// Owns one embedded plugin view's lifetime across the C behavior ABI. Retains
/// the host-services bridge for as long as the view may call back.
@MainActor
final class PluginViewMount {
    let id: String
    private(set) var title: String
    private let plugin: ContribPlugin
    private let viewId: String
    /// Where this view is mounted. Mutable, because a view can move between containers without being
    /// rebuilt; see `move(to:)`.
    private(set) var container: String
    /// The manifest says this view consumes key events itself (F-381).
    private(set) var wantsRawKeyboard: Bool
    private let bridge: ContribHostBridge
    private var viewPtr: UnsafeMutableRawPointer?

    init(contribution: ViewContribution, plugin: ContribPlugin, bridge: ContribHostBridge) {
        self.id = contribution.id
        self.title = contribution.title
        self.plugin = plugin
        self.viewId = contribution.id
        self.container = contribution.container
        self.wantsRawKeyboard = contribution.rawKeyboard
        self.bridge = bridge
    }

    /// Build the plugin's view (NSView* from PcMakeView; +1 owned until close()).
    ///
    /// Idempotent. Asking a second time returns the view that already exists rather than calling
    /// `PcMakeView` again — which would leak the first view and, for anything with a process behind
    /// it, silently start a second one. A container that adopts an existing view calls this and gets
    /// the same NSView, and `addSubview` does the re-parenting.
    func makeView() -> NSView? {
        if let existing = viewPtr {
            return Unmanaged<NSView>.fromOpaque(existing).takeUnretainedValue()
        }
        var services = bridge.makeServices()
        let ptr = withUnsafePointer(to: &services) {
            plugin.makeView(viewId, container: container, services: $0)
        }
        guard let ptr else { return nil }
        viewPtr = ptr
        return Unmanaged<NSView>.fromOpaque(ptr).takeUnretainedValue()
    }

    /// Record a new container and tell the view about it.
    ///
    /// `PcMakeView` already receives the container id, so a plugin can render for the room it was
    /// built in — but nothing told it when the room changed, and the rooms are not alike: the sidebar
    /// gives a monospaced font 26 columns at its minimum width and the bottom dock gives 161. What to
    /// do about that is the plugin's decision; the host's job is to say that it happened.
    func move(to newContainer: String) {
        guard newContainer != container else { return }
        container = newContainer
        notify(key: "container", value: newContainer)
    }

    /// Refresh what a re-resolved contribution says (a plugin may change either, and the mount
    /// outlives the `ViewContribution` value it was built from).
    func update(from contribution: ViewContribution) {
        title = contribution.title
        wantsRawKeyboard = contribution.rawKeyboard
    }

    /// The built view, without building one. Asking `makeView()` would create it, which is not what a
    /// keyboard question should do on every key press.
    var existingView: NSView? {
        guard let p = viewPtr else { return nil }
        return Unmanaged<NSView>.fromOpaque(p).takeUnretainedValue()
    }

    func close() {
        if let p = viewPtr { plugin.closeView(p); viewPtr = nil }
    }

    /// Push a host context change to the (already-created) view.
    func notify(key: String, value: String) {
        if let p = viewPtr { plugin.notifyView(p, key: key, value: value) }
    }

    #if DEBUG
    /// Diagnostic: is the view built, and what has the ABI been asked to do (F-381)?
    var automationState: (container: String, built: Bool, made: Int, closed: Int) {
        (container, viewPtr != nil, plugin.viewsMade, plugin.viewsClosed)
    }
    #endif
}

@MainActor
final class ViewContainerRegistry {
    static let shared = ViewContainerRegistry()

    private var mounts: [String: ([PreviewViewProvider]) -> Void] = [:]
    /// Live mounts by identity, so a refresh can tell what already exists. Keyed by (plugin, view id)
    /// rather than view id alone: two plugins may declare the same id, and merging them would hand one
    /// plugin the other's view.
    private var live: [ViewMountKey: PluginViewMount] = [:]   // retains bridges for embedded views
    // One long-lived host-services bridge per host, kept for the process lifetime: a
    // plugin may copy the services table (with the bridge's `host` token) and call back
    // OFF the main thread LATER — even after its view mount is refreshed away — so the
    // bridge behind the token must never be freed while the plugin lives.
    private var bridges: [ObjectIdentifier: ContribHostBridge] = [:]
    private func bridge(for host: ContributionHost) -> ContribHostBridge {
        let key = ObjectIdentifier(host as AnyObject)
        if let b = bridges[key] { return b }
        let b = ContribHostBridge(host); bridges[key] = b; return b
    }

    /// Register a host area under `container`; `mount` receives the current
    /// providers whenever they change.
    ///
    /// `acceptsMoves` is whether a user may send a view here. Off by default, because most containers
    /// are not places anyone would choose: "settings" holds the panes of the settings dialog and
    /// "titlebar" is a strip a few points tall. Being a *declared* destination is a separate matter —
    /// a manifest may name any registered container, and this only governs what the user is offered.
    func register(container: String, acceptsMoves: Bool = false,
                  mount: @escaping ([PreviewViewProvider]) -> Void) {
        mounts[container] = mount
        if acceptsMoves { movable.insert(container) } else { movable.remove(container) }
    }

    /// The containers this window offers, which is what an override is checked against.
    var registeredContainers: Set<String> { Set(mounts.keys) }

    /// The containers a user may move a view into.
    private(set) var moveTargets: Set<String> = []
    private var movable: Set<String> {
        get { moveTargets }
        set { moveTargets = newValue }
    }

    // MARK: - Placement (F-381)
    //
    // The manifest declares where a view goes by default; this is where the user's disagreement with
    // that lives. Kept here rather than in the window controller because `refresh` is the only place
    // it is ever consulted, and a preference read in one place should live next to that place.

    /// viewId -> container the user chose. See `ViewPlacement` for what makes an override valid.
    private var placements: [String: String] = [:]
    /// Called whenever the placements change, so the owner can write them out. Not a config
    /// dependency here: the registry does not know where preferences live and should not.
    var onPlacementsChanged: (([String: String]) -> Void)?

    /// Load placements (from preferences at startup). Does not persist them back.
    func setPlacements(_ placements: [String: String]) {
        self.placements = placements
    }

    /// Where a view is right now, if it is mounted at all.
    func container(ofViewId viewId: String) -> String? {
        live.first { $0.key.viewId == viewId }?.value.container
    }

    /// Move a view to another container, or back to its manifest's choice with `container: nil`.
    ///
    /// Returns false if nothing changed, so a caller does not persist and re-resolve for a drop the
    /// user made onto the container the view was already in.
    @discardableResult
    func place(viewId: String, in container: String?, host: ContributionHost) -> Bool {
        let before = placements[viewId]
        if let container { placements[viewId] = container } else { placements[viewId] = nil }
        guard placements[viewId] != before else { return false }
        refresh(host: host)
        onPlacementsChanged?(placements)
        return true
    }

    /// Put every view back where its manifest asked for it.
    @discardableResult
    func resetPlacements(host: ContributionHost) -> Bool {
        guard !placements.isEmpty else { return false }
        placements.removeAll()
        refresh(host: host)
        onPlacementsChanged?(placements)
        return true
    }

    /// Has the user moved this view away from its declared container?
    func isMoved(viewId: String) -> Bool { placements[viewId] != nil }

    /// Re-resolve every container's providers from the contribution registry.
    ///
    /// **Incremental, and that is the point.** This used to close every mounted plugin view and build
    /// them all again, which is fine for a comment field and fatal for anything holding a process:
    /// `PcCloseView` is how a terminal kills its sessions, and a refresh happens for reasons that have
    /// nothing to do with the view being rebuilt — enabling any plugin, disabling another, a `when`
    /// expression flipping somewhere else. Now a mount that is still wanted is kept, a mount that has
    /// moved is re-parented and told so, and only a mount whose contribution has genuinely gone away
    /// is closed. What changed is worked out by `ViewMountPlan`, which is pure and therefore testable
    /// — this function cannot be, because `ContribPlugin` wraps a real dlopen'ed library.
    func refresh(host: ContributionHost) {
        let ctx = host.contributionContext()

        // Resolve everything first, then decide: a container's wanted list is meaningless on its own,
        // since a view "missing" from one container may have moved to another.
        let registered = registeredContainers
        var wanted: [(key: ViewMountKey, container: String)] = []
        var resolved: [ViewMountKey: (contribution: ViewContribution, plugin: ContribPlugin, pluginId: String)] = [:]
        var byContainer: [String: [ViewMountKey]] = [:]
        for item in ContributionRegistry.shared.allViewItems()
        where WhenExpression.evaluate(item.contribution.when, context: ctx) {
            let key = ViewMountKey(pluginId: item.pluginId, viewId: item.contribution.id)
            guard resolved[key] == nil else { continue }   // first declaration wins; see ViewMountPlan
            // Where it *should* be: the manifest's answer unless the user has said otherwise, and only
            // if what they said still names a container this window has.
            let container = ViewPlacement.container(declared: item.contribution.container,
                                                    override: placements[item.contribution.id],
                                                    registered: registered)
            // A container nobody registered mounts nothing — the case a manifest naming, say,
            // "statusbar" has always fallen into, and now also a stale override's fallback.
            guard registered.contains(container) else { continue }
            resolved[key] = item
            wanted.append((key: key, container: container))
            byContainer[container, default: []].append(key)
        }

        let plan = ViewMountPlan.plan(live: live.mapValues(\.container), wanted: wanted)

        for key in plan.close {
            live[key]?.close()
            live[key] = nil
        }
        for key in plan.create {
            guard let item = resolved[key] else { continue }
            live[key] = PluginViewMount(contribution: item.contribution, plugin: item.plugin,
                                        bridge: bridge(for: host))
        }
        for entry in plan.moved { live[entry.key]?.move(to: entry.to) }
        // A title can change without the mount changing (a plugin updating its manifest, a different
        // localization); the mount outlives the contribution value it was built from.
        for key in plan.keep + plan.moved.map(\.key) {
            if let item = resolved[key] { live[key]?.update(from: item.contribution) }
        }

        // Hand every container its list — including the ones that lost a view, which is how they learn
        // to drop it. A container that is unchanged still gets called; deciding that is cheaper here
        // than making every container work out whether anything moved.
        for (container, mount) in mounts {
            let providers = (byContainer[container] ?? []).compactMap { key -> PreviewViewProvider? in
                guard let m = live[key], let item = resolved[key] else { return nil }
                return PreviewViewProvider(
                    id: m.id, title: PluginTitleLocalizer.localize(m.title, bundlePath: item.pluginId),
                    makeView: { [weak m] in m?.makeView() },
                    closeView: { [weak m] in m?.close() })
            }
            mount(providers)
        }
    }

    /// Push a host context change (e.g. current cursor path / dir) to every live
    /// embedded plugin view.
    /// Mounted plugin views that declared `rawKeyboard` and have actually been built.
    ///
    /// Only the built ones: a view that has never been made cannot contain the first responder, and
    /// building one to answer a keyboard question would be an odd way to start a terminal.
    func rawKeyboardViews() -> [NSView] {
        live.values.compactMap { $0.wantsRawKeyboard ? $0.existingView : nil }
    }

    func notifyViews(key: String, value: String) {
        for m in live.values { m.notify(key: key, value: value) }
    }

    #if DEBUG
    /// Diagnostic: every live mount, where it is, and what the ABI was asked to do (F-381).
    ///
    /// The counts are per *plugin*, not per mount — that is what the ABI boundary can see — so a
    /// plugin contributing two views reports the sum against both. That is fine for the question
    /// being asked: after a refresh that changes nothing, the number of closes must still be zero.
    func automationReport() -> String {
        live.map { key, mount -> String in
            let s = mount.automationState
            return "\(key.pluginId)/\(key.viewId) container=\(s.container) built=\(s.built) "
                 + "made=\(s.made) closed=\(s.closed)"
        }.sorted().joined(separator: "\n") + "\n"
    }
    #endif
}
