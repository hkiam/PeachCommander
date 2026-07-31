// SPDX-License-Identifier: Apache-2.0
// ContributionRegistry.swift - Single source of truth for plugin UI contributions.
//
// Aggregates the declared contributions of every ENABLED plugin (parsed from
// their Info.plist, no dylib code run to decide presence) and owns dispatching a
// contributed command to its plugin's behavior ABI. The menu/context/keybinding
// builders read from here; enabling/disabling/removing a plugin mutates the
// registry and fires `onChange` so the UI rebuilds. Nothing here is specific to
// any one plugin — a plugin's entire presence is data it supplies.

import AppKit
import PCFoundation
import PCPluginHost
import PCAutomation

@MainActor
final class ContributionRegistry {
    static let shared = ContributionRegistry()

    private struct Entry {
        let contributions: PluginContributions
        let plugin: ContribPlugin
    }
    private var entries: [String: Entry] = [:]   // keyed by pluginId
    private var order: [String] = []
    // One long-lived bridge per host — its opaque token must stay valid for the
    // lifetime of any window/view a command spawns (e.g. the Notes editor calling
    // openPath on a link click long after the command returned).
    private var bridge: ContribHostBridge?

    /// Called whenever the set of contributions changes (rebuild the UI).
    var onChange: (() -> Void)?

    // MARK: - Lifecycle

    func register(pluginId: String, contributions: PluginContributions, plugin: ContribPlugin) {
        if entries[pluginId] == nil { order.append(pluginId) }
        entries[pluginId] = Entry(contributions: contributions, plugin: plugin)
        onChange?()
    }

    func remove(pluginId: String) {
        guard entries.removeValue(forKey: pluginId) != nil else { return }
        order.removeAll { $0 == pluginId }
        onChange?()
    }

    /// Tell every loaded plugin the colour theme changed (F-338).
    ///
    /// Errors are not possible here — a plugin without the entry point is skipped — so this is
    /// safe to call on every theme change, including the startup one.
    func notifyThemeChanged() {
        for id in order { entries[id]?.plugin.notifyThemeChanged() }
    }

    func removeAll() {
        guard !entries.isEmpty else { return }
        entries.removeAll(); order.removeAll(); onChange?()
    }

    // MARK: - Queries (for the menu/context/keybinding builders)

    /// Main-menu contributions with their resolved display title, in deterministic
    /// (menu, group, order) order.
    func menuItems() -> [(contribution: MenuContribution, title: String)] {
        var out: [(MenuContribution, String)] = []
        for id in order {
            guard let e = entries[id] else { continue }
            let titles = Dictionary(uniqueKeysWithValues: e.contributions.commands.map { ($0.id, $0.title) })
            for m in e.contributions.menus {
                let title = m.titleOverride ?? titles[m.command] ?? m.command
                out.append((m, PluginTitleLocalizer.localize(title, bundlePath: id)))
            }
        }
        return out.sorted { a, b in
            if a.0.menu != b.0.menu { return a.0.menu < b.0.menu }
            if a.0.group != b.0.group { return a.0.group < b.0.group }
            return a.0.order < b.0.order
        }
    }

    /// Context-menu contributions for a surface, with resolved title.
    func contextItems(surface: String) -> [(contribution: ContextMenuContribution, title: String, submenu: String?)] {
        var out: [(ContextMenuContribution, String, String?)] = []
        for id in order {
            guard let e = entries[id] else { continue }
            let titles = Dictionary(uniqueKeysWithValues: e.contributions.commands.map { ($0.id, $0.title) })
            for cm in e.contributions.contextMenus where cm.surface == surface {
                let title = titles[cm.command] ?? cm.command
                // Localize both the item title and its submenu group label via the
                // contributing plugin's own bundle.
                let submenu = cm.submenu.map { PluginTitleLocalizer.localize($0, bundlePath: id) }
                out.append((cm, PluginTitleLocalizer.localize(title, bundlePath: id), submenu))
            }
        }
        return out.sorted { a, b in
            if a.0.group != b.0.group { return a.0.group < b.0.group }
            return a.0.order < b.0.order
        }
    }

    /// View contributions for a named container, with their owning plugin and its
    /// pluginId (== bundle path, for localizing the view's title).
    func viewItems(container: String) -> [(contribution: ViewContribution, plugin: ContribPlugin, pluginId: String)] {
        var out: [(ViewContribution, ContribPlugin, String)] = []
        for id in order {
            guard let e = entries[id] else { continue }
            for v in e.contributions.views where v.container == container {
                out.append((v, e.plugin, id))
            }
        }
        return out.sorted { $0.0.order < $1.0.order }
    }

    /// Command ids a plugin has declared that should be hidden (built-in hiding).
    func hiddenCommandIds(context: ContributionContext) -> Set<String> {
        var out: Set<String> = []
        for id in order {
            guard let e = entries[id] else { continue }
            for h in e.contributions.hides where WhenExpression.evaluate(h.when, context: context) {
                out.insert(h.command)
            }
        }
        return out
    }

    /// The command bound to `chord` by an enabled plugin whose keybinding `when`
    /// passes, or nil. First match wins (registration order).
    func keybindingCommand(for chord: KeyChord, context: ContributionContext) -> String? {
        for id in order {
            guard let e = entries[id] else { continue }
            for kb in e.contributions.keybindings {
                guard let parsed = KeyChord(parsing: kb.key), parsed == chord else { continue }
                if WhenExpression.evaluate(kb.when, context: context) { return kb.command }
            }
        }
        return nil
    }

    func command(_ id: String) -> CommandContribution? {
        for pid in order {
            if let c = entries[pid]?.contributions.commands.first(where: { $0.id == id }) { return c }
        }
        return nil
    }

    func canHandle(_ commandId: String) -> Bool { command(commandId) != nil }

    // MARK: - Dispatch

    /// Run a contributed command via its plugin's behavior ABI. Returns false if
    /// no enabled plugin owns it. Pre-resolves async host data (local path,
    /// selection) so the plugin's synchronous callbacks can serve it.
    /// Every tool contributed by an enabled plugin, in plugin order. Used by
    /// FormatterSetup to pick out the ones that declare `formatsExtensions`.
    func allTools() -> [ToolContribution] {
        order.compactMap { entries[$0]?.contributions.tools }.flatMap { $0 }
    }

    /// Automation tools contributed by loaded plugins, as catalogue entries (KI-06).
    func toolDefinitions() -> [ToolDefinition] {
        order.flatMap { pid -> [ToolDefinition] in
            guard let e = entries[pid] else { return [] }
            return e.contributions.tools.map { t in
                ToolDefinition(t.name, Capability(rawValue: t.capability) ?? .read,
                               PluginTitleLocalizer.localize(t.description, bundlePath: pid),
                               t.params.map { ToolParameter($0.name, ToolParameter.Kind(rawValue: $0.type) ?? .string,
                                                            $0.description, required: $0.required) })
            }
        }
    }

    /// Execute a contributed tool by name against its owning plugin.
    func invokeTool(_ name: String, argumentsJson: String, host: ContributionHost) async -> String? {
        guard let pid = order.first(where: { entries[$0]?.contributions.tools.contains { $0.name == name } == true }),
              let plugin = entries[pid]?.plugin else { return nil }
        let selection = await host.toolSelectionPaths()
        let b = hostBridge(for: host)
        b.update(localPath: nil, selection: selection)
        var services = b.makeServices()
        return withUnsafePointer(to: &services) { plugin.invokeTool(name, argumentsJson: argumentsJson, services: $0) }
    }

    func dispatch(_ commandId: String, host: ContributionHost) async -> Bool {
        guard let (pluginId, cmd) = owner(of: commandId) else { return false }
        guard let plugin = entries[pluginId]?.plugin else { return false }
        // A command with no PcRunCommand behavior may map to a generic host facet,
        // e.g. a PFX plugin's connect+mount (host-orchestrated, builds the VFS).
        if !plugin.hasBehavior, host.contribConnectFileSystem(pluginId: pluginId) { return true }
        let localPath = cmd.needsLocalPath ? await host.toolLocalCursorPath() : nil
        let selection = await host.toolSelectionPaths()
        let b = hostBridge(for: host)
        b.update(localPath: localPath, selection: selection)
        var services = b.makeServices()
        withUnsafePointer(to: &services) { plugin.runCommand(commandId, services: $0) }
        return true
    }

    private func hostBridge(for host: ContributionHost) -> ContribHostBridge {
        if let bridge { return bridge }
        let b = ContribHostBridge(host); bridge = b; return b
    }

    private func owner(of commandId: String) -> (pluginId: String, command: CommandContribution)? {
        for pid in order {
            if let c = entries[pid]?.contributions.commands.first(where: { $0.id == commandId }) {
                return (pid, c)
            }
        }
        return nil
    }
}
