// SPDX-License-Identifier: Apache-2.0
// ContributionModel.swift - Typed model + parser for a plugin's declarative
// contributions (SPEC-013 §"Manifest: PCContributions").
//
// A plugin declares WHAT it offers (commands, views) and WHERE it appears (menus,
// context menus, keybindings, view containers) in its Info.plist `PCContributions`
// dict. This is the pure, deterministic, Sendable model the host reads to build UI
// WITHOUT loading the plugin's dylib — so a disabled/removed plugin contributes
// nothing and no plugin code ever runs to decide menu presence. Behavior (running
// a command, building a view) is the separate C-ABI in Plugins/SDK/contrib.h.
//
// Parsing is tolerant: malformed entries are skipped (collected in `warnings`)
// rather than failing the whole plugin, so one bad line can't hide a plugin.

import Foundation

/// A named action a plugin exposes; menus/context/keys/refer to it by `id`.
public struct CommandContribution: Sendable, Equatable {
    public let id: String
    public let title: String
    public let category: String?
    /// If true, the host resolves the cursor's local (VFS→temp) path before
    /// dispatching, so the plugin's synchronous callbacks can read it.
    public let needsLocalPath: Bool
}

/// Placement of a command in the main menu bar.
public struct MenuContribution: Sendable, Equatable {
    public let command: String
    public let menu: String        // menu path, e.g. "File" or "File/Export"
    public let group: String
    public let order: Int
    public let when: String?
    public let titleOverride: String?
}

/// Placement of a command in a named context-menu surface.
public struct ContextMenuContribution: Sendable, Equatable {
    public let command: String
    public let surface: String     // "panel.item" | "panel.background" | "tab" | "drivebar"
    /// Optional submenu title: items sharing a submenu are grouped under one
    /// nested menu (e.g. "Git") instead of appearing directly in the surface.
    public let submenu: String?
    public let group: String
    public let order: Int
    public let when: String?
}

/// A keybinding for a command.
public struct KeybindingContribution: Sendable, Equatable {
    public let command: String
    public let key: String         // e.g. "cmd+shift+u"
    public let when: String?
}

/// An embedded view in a named host container.
public struct ViewContribution: Sendable, Equatable {
    public let id: String
    public let container: String   // "sidebar" | "preview" | "bottombar"
    public let title: String
    public let order: Int
    public let when: String?
}

/// Additive hiding of a built-in / other command's entries by id.
public struct HideContribution: Sendable, Equatable {
    public let command: String
    public let when: String?
}

/// One parameter of a contributed automation tool.
public struct ToolParamSpec: Sendable, Equatable {
    public let name: String
    public let type: String       // string|integer|boolean|array|object
    public let description: String
    public let required: Bool
    public init(name: String, type: String, description: String, required: Bool) {
        self.name = name; self.type = type; self.description = description; self.required = required
    }
}

/// A tool a plugin adds to the assistant's automation catalogue (KI-06).
public struct ToolContribution: Sendable, Equatable {
    public let name: String
    public let description: String
    public let capability: String   // read|navigate|write|delete|config|runCommand|network
    public let params: [ToolParamSpec]
    public init(name: String, description: String, capability: String, params: [ToolParamSpec]) {
        self.name = name; self.description = description; self.capability = capability; self.params = params
    }
}

/// Everything a plugin contributes to the UI.
public struct PluginContributions: Sendable, Equatable {
    public var commands: [CommandContribution]
    public var menus: [MenuContribution]
    public var contextMenus: [ContextMenuContribution]
    public var keybindings: [KeybindingContribution]
    public var views: [ViewContribution]
    public var hides: [HideContribution]
    public var tools: [ToolContribution]

    public init(commands: [CommandContribution] = [], menus: [MenuContribution] = [],
                contextMenus: [ContextMenuContribution] = [], keybindings: [KeybindingContribution] = [],
                views: [ViewContribution] = [], hides: [HideContribution] = [],
                tools: [ToolContribution] = []) {
        self.commands = commands
        self.menus = menus
        self.contextMenus = contextMenus
        self.keybindings = keybindings
        self.views = views
        self.hides = hides
        self.tools = tools
    }

    public static let empty = PluginContributions()
    public var isEmpty: Bool {
        commands.isEmpty && menus.isEmpty && contextMenus.isEmpty
            && keybindings.isEmpty && views.isEmpty && hides.isEmpty && tools.isEmpty
    }
}

/// Parses the `PCContributions` Info.plist dict into a `PluginContributions`.
public enum ContributionParser {
    public struct Result: Sendable {
        public let contributions: PluginContributions
        public let warnings: [String]
    }

    /// Parse the top-level Info.plist dict; reads its `PCContributions` value.
    public static func parse(infoPlist dict: [String: Any]) -> Result {
        guard let raw = dict["PCContributions"] as? [String: Any] else {
            return Result(contributions: .empty, warnings: [])
        }
        return parse(contributions: raw)
    }

    /// Parse a `PCContributions` dict directly.
    public static func parse(contributions raw: [String: Any]) -> Result {
        var warnings: [String] = []
        func arr(_ key: String) -> [[String: Any]] {
            guard let v = raw[key] else { return [] }
            guard let a = v as? [[String: Any]] else {
                warnings.append("PCContributions.\(key) is not an array of dicts — ignored")
                return []
            }
            return a
        }
        func str(_ d: [String: Any], _ k: String) -> String? {
            (d[k] as? String).flatMap { $0.isEmpty ? nil : $0 }
        }
        func int(_ d: [String: Any], _ k: String, default def: Int) -> Int {
            if let i = d[k] as? Int { return i }
            if let s = d[k] as? String, let i = Int(s) { return i }
            return def
        }
        func bool(_ d: [String: Any], _ k: String) -> Bool {
            if let b = d[k] as? Bool { return b }
            if let i = d[k] as? Int { return i != 0 }
            return false
        }

        var c = PluginContributions()

        for d in arr("commands") {
            guard let id = str(d, "id"), let title = str(d, "title") else {
                warnings.append("command missing id/title — skipped"); continue
            }
            c.commands.append(CommandContribution(
                id: id, title: title, category: str(d, "category"),
                needsLocalPath: bool(d, "needsLocalPath")))
        }
        for d in arr("menus") {
            guard let command = str(d, "command"), let menu = str(d, "menu") else {
                warnings.append("menu contribution missing command/menu — skipped"); continue
            }
            c.menus.append(MenuContribution(
                command: command, menu: menu, group: str(d, "group") ?? "9_plugins",
                order: int(d, "order", default: 100), when: str(d, "when"),
                titleOverride: str(d, "title")))
        }
        for d in arr("contextMenus") {
            guard let command = str(d, "command"), let surface = str(d, "surface") else {
                warnings.append("contextMenu contribution missing command/surface — skipped"); continue
            }
            c.contextMenus.append(ContextMenuContribution(
                command: command, surface: surface, submenu: str(d, "submenu"),
                group: str(d, "group") ?? "9_plugins",
                order: int(d, "order", default: 100), when: str(d, "when")))
        }
        for d in arr("tools") {
            guard let name = str(d, "name") else {
                warnings.append("tool contribution missing name — skipped"); continue
            }
            let params = (d["params"] as? [[String: Any]] ?? []).compactMap { p -> ToolParamSpec? in
                guard let pn = str(p, "name") else { return nil }
                return ToolParamSpec(name: pn, type: str(p, "type") ?? "string",
                                     description: str(p, "description") ?? "",
                                     required: (p["required"] as? Bool) ?? true)
            }
            c.tools.append(ToolContribution(name: name, description: str(d, "description") ?? "",
                                            capability: str(d, "capability") ?? "read", params: params))
        }
        for d in arr("keybindings") {
            guard let command = str(d, "command"), let key = str(d, "key") else {
                warnings.append("keybinding missing command/key — skipped"); continue
            }
            c.keybindings.append(KeybindingContribution(command: command, key: key, when: str(d, "when")))
        }
        for d in arr("views") {
            guard let id = str(d, "id"), let container = str(d, "container"), let title = str(d, "title") else {
                warnings.append("view contribution missing id/container/title — skipped"); continue
            }
            c.views.append(ViewContribution(
                id: id, container: container, title: title,
                order: int(d, "order", default: 100), when: str(d, "when")))
        }
        for d in arr("hides") {
            guard let command = str(d, "command") else {
                warnings.append("hide contribution missing command — skipped"); continue
            }
            c.hides.append(HideContribution(command: command, when: str(d, "when")))
        }

        return Result(contributions: c, warnings: warnings)
    }
}
