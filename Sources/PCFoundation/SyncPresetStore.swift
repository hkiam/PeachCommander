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
    /// Whether dot-named entries are left out of the comparison.
    ///
    /// This was the one setting the window offered and the preset did not carry: it reached the
    /// engine as a bare argument, so saving a preset "without hidden files" and loading it back gave
    /// you a comparison *with* them, silently. It is here rather than in `SyncOptions` because it is
    /// a question about which entries the scan visits, not about how two of them are compared.
    public var ignoreHidden: Bool
    /// The advanced filter, or nil for a preset that carries none.
    ///
    /// Optional rather than a defaulted value so that "this preset has no filter" and "this preset
    /// has an empty one" are the same thing on disk, and so a preset written before filters existed
    /// decodes without one.
    public var filter: SyncFilter?

    public init(name: String, options: SyncOptions, fileMask: String = "*.*", withSubdirs: Bool = true,
                ignoreHidden: Bool = false, filter: SyncFilter? = nil) {
        self.name = name
        self.options = options
        self.fileMask = fileMask
        self.withSubdirs = withSubdirs
        self.ignoreHidden = ignoreHidden
        self.filter = filter
    }

    /// Decode field by field, every one optional. See `SyncOptions.init(from:)` for why: the
    /// synthesized decoder throws on a missing key instead of using the default, `load()` turns any
    /// throw into `[]`, and the next `save` writes that empty list over the file.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        options = try c.decodeIfPresent(SyncOptions.self, forKey: .options) ?? SyncOptions()
        fileMask = try c.decodeIfPresent(String.self, forKey: .fileMask) ?? "*.*"
        withSubdirs = try c.decodeIfPresent(Bool.self, forKey: .withSubdirs) ?? true
        ignoreHidden = try c.decodeIfPresent(Bool.self, forKey: .ignoreHidden) ?? false
        filter = try c.decodeIfPresent(SyncFilter.self, forKey: .filter)
    }
}

/// Loads/saves `[SyncPreset]` as JSON at a fixed file URL.
public final class SyncPresetStore {
    private let url: URL
    public init(url: URL) { self.url = url }

    public func load() -> [SyncPreset] {
        guard let data = try? Data(contentsOf: url),
              let presets = try? Self.decoder().decode([SyncPreset].self, from: data) else { return [] }
        return presets
    }

    @discardableResult
    public func save(_ presets: [SyncPreset]) -> Bool {
        guard let data = try? Self.encoder().encode(presets) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    /// Insert or replace the preset with the same name, returning the new list.
    ///
    /// Refuses when the file is there, is not empty, and does not decode. `load()` cannot tell
    /// "no presets yet" from "I could not read this", and it answers `[]` for both — so without this
    /// check, saving one preset over a file this build cannot parse replaces every preset in it with
    /// that single one. A file that cannot be read is left exactly as it is; the caller learns that
    /// nothing was added because the returned list does not contain the preset.
    @discardableResult
    public func upsert(_ preset: SyncPreset) -> [SyncPreset] {
        if let data = try? Data(contentsOf: url), !data.isEmpty,
           (try? Self.decoder().decode([SyncPreset].self, from: data)) == nil {
            return []
        }
        var presets = load()
        if let idx = presets.firstIndex(where: { $0.name == preset.name }) { presets[idx] = preset }
        else { presets.append(preset) }
        _ = save(presets)
        return presets
    }

    /// One date strategy on both sides, chosen while the format still carries no date at all.
    /// A filter's "modified after" will need it, and by then a file written by the old encoder would
    /// have to be read by the new decoder — a migration for something that costs nothing today.
    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// Remove the preset named `name`, returning the new list.
    ///
    /// No unreadable-file check here, unlike `upsert`: a file that does not decode leaves the popup
    /// with nothing selected, so there is no name to remove and this cannot be reached that way.
    @discardableResult
    public func remove(name: String) -> [SyncPreset] {
        var presets = load()
        presets.removeAll { $0.name == name }
        _ = save(presets)
        return presets
    }
}
