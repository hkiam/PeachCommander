// SPDX-License-Identifier: Apache-2.0
// PluginConfig.swift - Plugin enable/disable state + extension associations (I14 T02/T03).
//
// The persisted `plugins.ini` model (pure, testable, no IO):
//   [Plugins]                 ; most plugins are on unless listed here…
//   Disabled=OldPacker;Broken
//   Enabled=JavaDecompiler    ; …and opt-in ones are off until listed here (F-345)
//   [PackerAssoc]             ; extension -> plugin name; consulted before built-ins
//   pak=SamplePacker
//   cbz=SamplePacker
// Extension keys are stored lowercased without a leading dot.

import Foundation
import PCFoundation

public struct PluginConfig: Equatable, Sendable {
    /// Plugin names explicitly disabled.
    public private(set) var disabled: Set<String>
    /// Plugin names explicitly *enabled*.
    ///
    /// Needed because "never touched" and "switched off" used to be the same state, which made a
    /// plugin that should start off impossible to express: turning it on would have been
    /// indistinguishable from the default. A plugin whose manifest opts out of being on by
    /// default stays off until its name appears here (F-345).
    public private(set) var enabled: Set<String>
    /// Lowercased extension → plugin name (packer associations).
    public private(set) var packerAssoc: [String: String]

    public init(disabled: Set<String> = [], enabled: Set<String> = [],
                packerAssoc: [String: String] = [:]) {
        self.disabled = disabled
        self.enabled = enabled
        self.packerAssoc = packerAssoc
    }

    /// Parse a `plugins.ini` body.
    public init(parsing text: String) {
        let ini = INIDocument(parsing: text)
        let disabledList = ini.value(section: "Plugins", key: "Disabled") ?? ""
        let parts: [Substring] = disabledList.split(whereSeparator: { $0 == ";" || $0 == "," })
        let names: [String] = parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        self.disabled = Set(names)
        let enabledList = ini.value(section: "Plugins", key: "Enabled") ?? ""
        self.enabled = Set(enabledList.split(whereSeparator: { $0 == ";" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        var assoc: [String: String] = [:]
        for key in ini.keys(inSection: "PackerAssoc") {
            if let plugin = ini.value(section: "PackerAssoc", key: key)?.trimmingCharacters(in: .whitespaces),
               !plugin.isEmpty {
                assoc[Self.normalizeExt(key)] = plugin
            }
        }
        self.packerAssoc = assoc
    }

    /// Serialize back to `plugins.ini` text (deterministic key order).
    public func serialized() -> String {
        var doc = INIDocument()
        if !disabled.isEmpty {
            doc.set(disabled.sorted().joined(separator: ";"), section: "Plugins", key: "Disabled")
        }
        if !enabled.isEmpty {
            doc.set(enabled.sorted().joined(separator: ";"), section: "Plugins", key: "Enabled")
        }
        for ext in packerAssoc.keys.sorted() {
            doc.set(packerAssoc[ext]!, section: "PackerAssoc", key: ext)
        }
        return doc.serialized()
    }

    // MARK: - Queries

    /// Whether `pluginName` is on, for a plugin that is on unless disabled (the normal case).
    public func isEnabled(_ pluginName: String) -> Bool { !disabled.contains(pluginName) }

    /// Whether `pluginName` is on, honouring a manifest that asks to start off.
    ///
    /// `enabledByDefault == false` inverts the rule: the plugin is off until the user turns it on,
    /// and an explicit disable still wins so that turning it off after turning it on works.
    public func isEnabled(_ pluginName: String, enabledByDefault: Bool) -> Bool {
        if disabled.contains(pluginName) { return false }
        return enabledByDefault || enabled.contains(pluginName)
    }

    /// The plugin associated with a file extension (case/dot-insensitive), if any.
    public func plugin(forExtension ext: String) -> String? {
        packerAssoc[Self.normalizeExt(ext)]
    }

    // MARK: - Mutation

    public mutating func setEnabled(_ pluginName: String, _ on: Bool) {
        // Both sets are updated so the state is unambiguous whichever default the manifest asks
        // for: an opt-in plugin needs its name recorded to stay on, an ordinary one to stay off.
        if on {
            disabled.remove(pluginName)
            enabled.insert(pluginName)
        } else {
            enabled.remove(pluginName)
            disabled.insert(pluginName)
        }
    }

    /// Associate `ext` with `plugin` (nil removes the association).
    public mutating func setAssociation(ext: String, plugin: String?) {
        let key = Self.normalizeExt(ext)
        if let plugin, !plugin.isEmpty { packerAssoc[key] = plugin } else { packerAssoc[key] = nil }
    }

    private static func normalizeExt(_ ext: String) -> String {
        var e = ext.lowercased().trimmingCharacters(in: .whitespaces)
        while e.hasPrefix(".") { e.removeFirst() }
        return e
    }
}
