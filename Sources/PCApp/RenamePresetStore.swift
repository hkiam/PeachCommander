// SPDX-License-Identifier: Apache-2.0
// RenamePresetStore.swift - Persists named multi-rename presets as JSON (F-176).
//
// Mirrors the search-template store: a preset is just a name plus the window's
// SpecValues snapshot, so loading one repopulates every rename control.

import Foundation

/// A named multi-rename configuration.
struct RenamePreset: Codable, Equatable {
    var name: String
    var values: MultiRenameWindowController.SpecValues
}

extension MultiRenameWindowController.SpecValues: Equatable {
    public static func == (a: Self, b: Self) -> Bool {
        a.nameMask == b.nameMask && a.extMask == b.extMask && a.search == b.search
            && a.replace == b.replace && a.useRegex == b.useRegex && a.caseSensitive == b.caseSensitive
            && a.repeatReplace == b.repeatReplace && a.caseModeIndex == b.caseModeIndex
            && a.counterStart == b.counterStart && a.counterStep == b.counterStep
            && a.counterDigits == b.counterDigits
    }
}

/// Loads/saves `[RenamePreset]` as JSON at a fixed file URL.
final class RenamePresetStore {
    private let url: URL
    init(url: URL) { self.url = url }

    func load() -> [RenamePreset] {
        guard let data = try? Data(contentsOf: url),
              let presets = try? JSONDecoder().decode([RenamePreset].self, from: data) else { return [] }
        return presets
    }

    @discardableResult
    func save(_ presets: [RenamePreset]) -> Bool {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(presets) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    /// Insert or replace the preset with the same name, returning the new list.
    @discardableResult
    func upsert(_ preset: RenamePreset) -> [RenamePreset] {
        var presets = load()
        if let idx = presets.firstIndex(where: { $0.name == preset.name }) { presets[idx] = preset }
        else { presets.append(preset) }
        _ = save(presets)
        return presets
    }
}
