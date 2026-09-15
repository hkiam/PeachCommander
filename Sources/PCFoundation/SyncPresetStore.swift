// SPDX-License-Identifier: Apache-2.0
// SyncPresetStore.swift - Persists named directory-sync presets as JSON (F-194).
//
// A preset is a reusable comparison profile: the SyncOptions plus the file mask, the
// recurse-subdirectories flag, the advanced filter and what the result grid shows.
// Directories themselves are per-session and not part of a preset. Mirrors RenamePresetStore.
//
// Two things here are about the *list* rather than about one preset, and both exist so that the
// window can open on something: `seedIfMissing` puts a default in an installation that has none,
// and `lastUsed` says which one to come back to.

import Foundation

/// What the result grid shows once a comparison is done.
///
/// A string-backed enum rather than the popup's index: an index is only meaningful next to the
/// popup that produced it, and this one is written to a file that outlives the window.
public enum SyncResultFilter: String, Codable, Equatable, Sendable {
    case all
    case toRight
    case toLeft
}

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
    /// Which rows the grid shows, and whether the identical ones are left out — the two controls
    /// under the Compare button.
    ///
    /// They narrow the *result* rather than the comparison, which is why a preset did not carry them
    /// at first. That was the wrong line to draw: what a preset is for is "show me this pair of
    /// folders the way I always look at them", and half of that is which rows are on screen. Loading
    /// a preset and then ticking "Hide identical" again, every time, is the work a preset exists to
    /// remove.
    public var resultFilter: SyncResultFilter
    public var hideEqual: Bool
    /// When this preset was last chosen or saved, so the window can come back to it.
    ///
    /// On the preset rather than in a file beside the list: a second file is a second thing that can
    /// disagree with the first, and this one answers a question about a preset ("when was it last
    /// used") which is exactly where it belongs. Optional, so a list written before this existed
    /// decodes — and "never used" then sorts below anything that has been.
    public var lastUsed: Date?

    public init(name: String, options: SyncOptions, fileMask: String = "*.*", withSubdirs: Bool = true,
                ignoreHidden: Bool = false, filter: SyncFilter? = nil,
                resultFilter: SyncResultFilter = .all, hideEqual: Bool = false,
                lastUsed: Date? = nil) {
        self.name = name
        self.options = options
        self.fileMask = fileMask
        self.withSubdirs = withSubdirs
        self.ignoreHidden = ignoreHidden
        self.filter = filter
        self.resultFilter = resultFilter
        self.hideEqual = hideEqual
        self.lastUsed = lastUsed
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
        resultFilter = try c.decodeIfPresent(SyncResultFilter.self, forKey: .resultFilter) ?? .all
        hideEqual = try c.decodeIfPresent(Bool.self, forKey: .hideEqual) ?? false
        lastUsed = try c.decodeIfPresent(Date.self, forKey: .lastUsed)
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

    /// The preset a fresh installation starts with, under the name the window hands in.
    ///
    /// Deliberately the window's own defaults and nothing cleverer. The point of shipping one is not
    /// to recommend a comparison: it is that "Preset:" was an empty popup until somebody saved
    /// something into it, which says the feature is broken rather than unused, and that there was
    /// nothing to *overwrite* — the shortest way to make a preset is to change two controls and save
    /// over one that exists. A default that also changed what a comparison does would make the first
    /// run of this window differ from every run of it before, which is a different promise.
    public static func shipped(named name: String) -> SyncPreset {
        SyncPreset(name: name, options: SyncOptions(), fileMask: "*.*", withSubdirs: true,
                   ignoreHidden: false, filter: nil, resultFilter: .all, hideEqual: false)
    }

    /// Write the shipped default, once, if this installation has no presets file yet.
    ///
    /// Keyed on the *file*, not on the list: seeding whenever the list came back empty would put the
    /// default back after somebody deleted it, for ever, which is the one thing a deletable item may
    /// not do. It also leaves a file that exists but does not decode alone — `load()` answers `[]`
    /// for that too, and overwriting it is exactly what `upsert` refuses to do.
    @discardableResult
    public func seedIfMissing(named name: String) -> [SyncPreset] {
        guard (try? url.checkResourceIsReachable()) != true else { return load() }
        let list = [Self.shipped(named: name)]
        _ = save(list)
        return list
    }

    /// The preset to come back to: the one most recently chosen or saved, else the first.
    ///
    /// `nil` only when there are none at all. "Most recently used" and not "the first in the file"
    /// because the file is in insertion order, and the preset somebody works with every day is
    /// usually not the one they made first.
    public func lastUsed() -> SyncPreset? {
        let presets = load()
        return presets.max { a, b in
            (a.lastUsed ?? .distantPast) < (b.lastUsed ?? .distantPast)
        } ?? presets.first
    }

    /// Record that a preset was chosen, so the next window opens on it.
    ///
    /// Writes only the stamp, through `upsert`, so choosing a preset cannot rewrite its settings from
    /// a window the user has since changed — the preset on disk is the one that gets its date.
    public func markUsed(name: String, at date: Date = Date()) {
        guard var preset = load().first(where: { $0.name == name }) else { return }
        preset.lastUsed = date
        _ = upsert(preset)
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
