// SPDX-License-Identifier: Apache-2.0
// SyncPresetStore.swift - Persists named directory-sync presets as JSON (F-194).
//
// A preset is a reusable comparison profile: the SyncOptions plus the file mask
// and the recurse-subdirectories flag. Directories themselves are per-session and
// not part of a preset. Mirrors RenamePresetStore.

import Foundation

/// A named directory-sync configuration.
public struct SyncPreset: Codable, Equatable, Sendable {
    public var name: String
    public var options: SyncOptions
    public var fileMask: String
    public var withSubdirs: Bool

    public init(name: String, options: SyncOptions, fileMask: String = "*.*", withSubdirs: Bool = true) {
        self.name = name
        self.options = options
        self.fileMask = fileMask
        self.withSubdirs = withSubdirs
    }
}

/// Loads/saves `[SyncPreset]` as JSON at a fixed file URL.
public final class SyncPresetStore {
    private let url: URL
    public init(url: URL) { self.url = url }

    public func load() -> [SyncPreset] {
        guard let data = try? Data(contentsOf: url),
              let presets = try? JSONDecoder().decode([SyncPreset].self, from: data) else { return [] }
        return presets
    }

    @discardableResult
    public func save(_ presets: [SyncPreset]) -> Bool {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(presets) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    /// Insert or replace the preset with the same name, returning the new list.
    @discardableResult
    public func upsert(_ preset: SyncPreset) -> [SyncPreset] {
        var presets = load()
        if let idx = presets.firstIndex(where: { $0.name == preset.name }) { presets[idx] = preset }
        else { presets.append(preset) }
        _ = save(presets)
        return presets
    }

    /// Remove the preset named `name`, returning the new list.
    @discardableResult
    public func remove(name: String) -> [SyncPreset] {
        var presets = load()
        presets.removeAll { $0.name == name }
        _ = save(presets)
        return presets
    }
}
