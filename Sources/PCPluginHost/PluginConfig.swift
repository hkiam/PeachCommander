// PluginConfig.swift - Plugin enable/disable state + extension associations (I14 T02/T03).
//
// The persisted `plugins.ini` model (pure, testable, no IO):
//   [Plugins]                 ; plugins are enabled by default; list only disabled ones
//   Disabled=OldPacker;Broken
//   [PackerAssoc]             ; extension -> plugin name; consulted before built-ins
//   pak=SamplePacker
//   cbz=SamplePacker
// Extension keys are stored lowercased without a leading dot.

import Foundation
import PCFoundation

public struct PluginConfig: Equatable, Sendable {
    /// Plugin names explicitly disabled (everything else is enabled by default).
    public private(set) var disabled: Set<String>
    /// Lowercased extension → plugin name (packer associations).
    public private(set) var packerAssoc: [String: String]

    public init(disabled: Set<String> = [], packerAssoc: [String: String] = [:]) {
        self.disabled = disabled
        self.packerAssoc = packerAssoc
    }

    /// Parse a `plugins.ini` body.
    public init(parsing text: String) {
        let ini = INIDocument(parsing: text)
        let disabledList = ini.value(section: "Plugins", key: "Disabled") ?? ""
        let parts: [Substring] = disabledList.split(whereSeparator: { $0 == ";" || $0 == "," })
        let names: [String] = parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        self.disabled = Set(names)
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
        for ext in packerAssoc.keys.sorted() {
            doc.set(packerAssoc[ext]!, section: "PackerAssoc", key: ext)
        }
        return doc.serialized()
    }

    // MARK: - Queries

    public func isEnabled(_ pluginName: String) -> Bool { !disabled.contains(pluginName) }

    /// The plugin associated with a file extension (case/dot-insensitive), if any.
    public func plugin(forExtension ext: String) -> String? {
        packerAssoc[Self.normalizeExt(ext)]
    }

    // MARK: - Mutation

    public mutating func setEnabled(_ pluginName: String, _ enabled: Bool) {
        if enabled { disabled.remove(pluginName) } else { disabled.insert(pluginName) }
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
