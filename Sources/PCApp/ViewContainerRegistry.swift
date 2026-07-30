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
import PCPluginHost

/// A plugin view a container can show: lazily built, explicitly torn down.
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
    let title: String
    private let plugin: ContribPlugin
    private let viewId: String
    private let container: String
    private let bridge: ContribHostBridge
    private var viewPtr: UnsafeMutableRawPointer?

    init(contribution: ViewContribution, plugin: ContribPlugin, bridge: ContribHostBridge) {
        self.id = contribution.id
        self.title = contribution.title
        self.plugin = plugin
        self.viewId = contribution.id
        self.container = contribution.container
        self.bridge = bridge
    }

    /// Build the plugin's view (NSView* from PcMakeView; +1 owned until close()).
    func makeView() -> NSView? {
        var services = bridge.makeServices()
        let ptr = withUnsafePointer(to: &services) {
            plugin.makeView(viewId, container: container, services: $0)
        }
        guard let ptr else { return nil }
        viewPtr = ptr
        return Unmanaged<NSView>.fromOpaque(ptr).takeUnretainedValue()
    }

    func close() {
        if let p = viewPtr { plugin.closeView(p); viewPtr = nil }
    }

    /// Push a host context change to the (already-created) view.
    func notify(key: String, value: String) {
        if let p = viewPtr { plugin.notifyView(p, key: key, value: value) }
    }
}

@MainActor
final class ViewContainerRegistry {
    static let shared = ViewContainerRegistry()

    private var mounts: [String: ([PreviewViewProvider]) -> Void] = [:]
    private var live: [PluginViewMount] = []   // retains bridges for embedded views
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
    func register(container: String, mount: @escaping ([PreviewViewProvider]) -> Void) {
        mounts[container] = mount
    }

    /// Rebuild every container's providers from the contribution registry.
    func refresh(host: ContributionHost) {
        live.forEach { $0.close() }
        live.removeAll()
        let ctx = host.contributionContext()
        for (container, mount) in mounts {
            let items = ContributionRegistry.shared.viewItems(container: container)
                .filter { WhenExpression.evaluate($0.contribution.when, context: ctx) }
            var providers: [PreviewViewProvider] = []
            for item in items {
                let m = PluginViewMount(contribution: item.contribution, plugin: item.plugin,
                                        bridge: bridge(for: host))
                live.append(m)
                providers.append(PreviewViewProvider(
                    id: m.id, title: PluginTitleLocalizer.localize(m.title, bundlePath: item.pluginId),
                    makeView: { [weak m] in m?.makeView() },
                    closeView: { [weak m] in m?.close() }))
            }
            mount(providers)
        }
    }

    /// Push a host context change (e.g. current cursor path / dir) to every live
    /// embedded plugin view.
    func notifyViews(key: String, value: String) {
        for m in live { m.notify(key: key, value: value) }
    }
}
