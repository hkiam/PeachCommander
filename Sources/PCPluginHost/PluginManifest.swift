// SPDX-License-Identifier: Apache-2.0
// PluginManifest.swift - Plugin manifest model, validation, and pluginst.inf parsing
//
// Implements SPEC-012 §1, §8 (feature F-235): the plugin manifest read from a
// plugin bundle's Info.plist, and the TC-compatible `pluginst.inf` install
// descriptor shipped inside a plugin .zip archive.
//
// Pure, deterministic, Sendable. No IO, no AppKit.

import Foundation
import PCFoundation

/// The four Total Commander-derived plugin kinds Peach Commander supports:
/// packer (pcx), file-system (pfx), lister (plx), and content/detector (pdx).
public enum PluginType: String, Sendable, CaseIterable {
    case pcx, pfx, plx, pdx, ptx

    /// Map a TC descriptor type (wcx/wfx/wlx/wdx, case-insensitive) to a
    /// `PluginType`. Also accepts the native names (pcx/pfx/plx/pdx,
    /// case-insensitive). Returns nil for anything else.
    public static func fromTCType(_ raw: String) -> PluginType? {
        switch raw.lowercased() {
        case "wcx", "pcx": return .pcx
        case "wfx", "pfx": return .pfx
        case "wlx", "plx": return .plx
        case "wdx", "pdx": return .pdx
        case "ptx": return .ptx   // tool/action plugin — Peach Commander extension (no TC analog)
        default: return nil
        }
    }
}

/// What a plugin says it needs of the host before it will run.
///
/// One Info.plist key, `PCPluginMinHostVersion`, carries both shapes, because it already
/// existed as an integer in every shipped manifest and those must keep loading. An integer is
/// the old meaning — an API level, checked against `PC_API_VERSION`. A string is the useful
/// one: a marketing version, checked against the running app. Neither was checked against
/// anything at all before this.
public enum PluginHostRequirement: Sendable, Equatable {
    /// Legacy integer form: the plugin needs at least this plugin-API level.
    case apiLevel(Int)
    /// A `major.minor.patch` string: the plugin needs at least this version of the app.
    case hostVersion(SemanticVersion)
}

/// A validated plugin manifest, built from a plugin bundle's Info.plist.
public struct PluginManifest: Sendable, Equatable {
    public let type: PluginType
    public let apiVersion: Int
    public let name: String
    /// Stable, host-facing identity — `PCPluginIdentifier`, falling back to `name`.
    ///
    /// Everything the host persists about a plugin is keyed on this: the enabled/disabled lists
    /// in `plugins.ini`, the packer associations, the discovery dedupe. It used to be keyed on
    /// the display name, which meant two plugins sharing a name silently displaced each other,
    /// renaming one orphaned the user's setting, and a name containing `;` or `,` tore the INI
    /// list in half. The fallback is what keeps every plugin built before this key existed
    /// working unchanged — including its saved on/off state.
    public let identifier: String
    /// The plugin's own version — `PCPluginVersion`, else `CFBundleShortVersionString`, else 0.0.0.
    public let version: SemanticVersion
    /// Default file-extension associations (lowercased, without a leading dot).
    public let extensions: [String]
    public let detectString: String?
    public let minHostVersion: PluginHostRequirement?
    /// Whether the plugin is on as soon as it is installed (F-345).
    ///
    /// `Info.plist` key `PCPluginEnabledByDefault`; absent means true, which is what every plugin
    /// shipped so far expects. A plugin sets it to false when it is only useful to some users and
    /// would otherwise claim files they never want it to touch — the Java decompiler is the first.
    public let enabledByDefault: Bool

    public init(
        type: PluginType,
        apiVersion: Int,
        name: String,
        identifier: String? = nil,
        version: SemanticVersion = SemanticVersion(0, 0, 0),
        extensions: [String] = [],
        detectString: String? = nil,
        minHostVersion: PluginHostRequirement? = nil,
        enabledByDefault: Bool = true
    ) {
        self.type = type
        self.apiVersion = apiVersion
        self.name = name
        self.identifier = identifier ?? name
        self.version = version
        self.extensions = extensions
        self.detectString = detectString
        self.minHostVersion = minHostVersion
        self.enabledByDefault = enabledByDefault
    }
}

/// Reasons an Info.plist dictionary fails to validate as a plugin manifest.
public enum PluginManifestError: Error, Equatable {
    /// `PCPluginType` key is absent entirely.
    case missingType
    /// `PCPluginType` is present but doesn't map to a known `PluginType`.
    case invalidType(String)
    /// `PCPluginName` is absent or empty.
    case missingName
    /// `PCPluginAPIVersion` is absent or not an integer.
    case missingAPIVersion
    /// `PCPluginAPIVersion` is below the oldest version this host still serves.
    case apiVersionTooOld(Int, minimumSupported: Int)
    /// `PCPluginAPIVersion` is newer than this host understands — the *host* is what is old here,
    /// and saying so is the difference between a user who updates and a user who gives up.
    case apiVersionTooNew(Int, current: Int)
    /// `PCPluginIdentifier` is present but is not a usable key (empty, or carries a character
    /// that would tear the `plugins.ini` list apart).
    case invalidIdentifier(String)
}

/// Builds and validates `PluginManifest` values from a bundle's Info.plist.
public enum PluginManifestParser {
    /// The API version this host currently supports — mirrors `PC_API_VERSION` in pc_common.h.
    public static let currentAPIVersion = 1
    /// The oldest API version this host still loads — mirrors `PC_API_MIN_SUPPORTED`.
    ///
    /// Kept as a window rather than a single number on purpose. The check used to be equality,
    /// so the first bump to 2 would have invalidated every third-party plugin in existence, in
    /// the manifest check and the runtime handshake at once, with no release in between where
    /// both worked.
    public static let minimumSupportedAPIVersion = 1

    /// Validate & build a manifest from an Info.plist dictionary (as read from
    /// the bundle). `PCPluginExtensions` may be `[String]` or a `;` / `,` /
    /// whitespace separated `String`.
    public static func parse(infoPlist dict: [String: Any]) -> Result<PluginManifest, PluginManifestError> {
        // --- type ---
        guard let rawType = dict["PCPluginType"] else {
            return .failure(.missingType)
        }
        let typeString = String(describing: rawType)
        // `fromTCType` rather than `PluginType(rawValue:)`: the architecture guide has always
        // said a ported plugin may declare `wcx`/`wfx`/`wlx`/`wdx` here, and until now only the
        // `pluginst.inf` path honoured that while the manifest path rejected exactly those.
        guard let type = PluginType.fromTCType(typeString) else {
            return .failure(.invalidType(typeString))
        }

        // --- name ---
        let name: String
        if let rawName = dict["PCPluginName"] {
            name = String(describing: rawName).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            name = ""
        }
        guard !name.isEmpty else {
            return .failure(.missingName)
        }

        // --- API version ---
        guard let apiVersion = intValue(from: dict["PCPluginAPIVersion"]) else {
            return .failure(.missingAPIVersion)
        }
        guard apiVersion >= minimumSupportedAPIVersion else {
            return .failure(.apiVersionTooOld(apiVersion, minimumSupported: minimumSupportedAPIVersion))
        }
        guard apiVersion <= currentAPIVersion else {
            return .failure(.apiVersionTooNew(apiVersion, current: currentAPIVersion))
        }

        // --- extensions ---
        let extensions = extractExtensions(from: dict["PCPluginExtensions"])

        // --- detect string ---
        let detectString: String?
        if let rawDetect = dict["PCPluginDetectString"] {
            let s = String(describing: rawDetect)
            detectString = s.isEmpty ? nil : s
        } else {
            detectString = nil
        }

        // --- identifier ---
        let identifier: String
        if let raw = dict["PCPluginIdentifier"] {
            let candidate = String(describing: raw).trimmingCharacters(in: .whitespacesAndNewlines)
            guard isUsableIdentifier(candidate) else {
                return .failure(.invalidIdentifier(candidate))
            }
            identifier = candidate
        } else {
            // No identifier declared: the display name stands in, which is what every key in
            // `plugins.ini` meant before this field existed. So an old plugin keeps its saved
            // on/off state, and a new one gets a name it can be renamed away from.
            identifier = name
        }

        // --- plugin version ---
        // `PCPluginVersion` first, then the bundle's own `CFBundleShortVersionString` — which
        // every plugin already carries and the host had never once read.
        let version = (dict["PCPluginVersion"] as? String).flatMap(SemanticVersion.init)
            ?? (dict["CFBundleShortVersionString"] as? String).flatMap(SemanticVersion.init)
            ?? SemanticVersion(0, 0, 0)

        // --- minimum host requirement ---
        let minHostVersion = hostRequirement(from: dict["PCPluginMinHostVersion"])
        let enabledByDefault = (dict["PCPluginEnabledByDefault"] as? Bool) ?? true

        return .success(PluginManifest(
            type: type,
            apiVersion: apiVersion,
            name: name,
            identifier: identifier,
            version: version,
            extensions: extensions,
            detectString: detectString,
            minHostVersion: minHostVersion,
            enabledByDefault: enabledByDefault
        ))
    }

    /// Whether `candidate` can serve as the persisted key for a plugin.
    ///
    /// The forbidden characters are not stylistic: `plugins.ini` stores the enabled and disabled
    /// sets as `;`-separated (and `,`-tolerant) lists, and `=` and `[`/`]` are INI structure. An
    /// identifier carrying one of those would be written out and read back as two plugins, or as
    /// none.
    static func isUsableIdentifier(_ candidate: String) -> Bool {
        guard !candidate.isEmpty, candidate.count <= 255 else { return false }
        let forbidden = CharacterSet(charactersIn: ";,=[]\n\r\t")
        guard candidate.rangeOfCharacter(from: forbidden) == nil else { return false }
        return candidate.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
    }

    /// Read `PCPluginMinHostVersion` in either of its two shapes (see `PluginHostRequirement`).
    ///
    /// A string that does not parse as a version yields nil rather than a requirement of 0.0.0:
    /// a typo must not quietly become "runs anywhere".
    private static func hostRequirement(from raw: Any?) -> PluginHostRequirement? {
        guard let raw else { return nil }
        // Bool bridges to NSNumber on macOS, and `PCPluginMinHostVersion` is never a Bool — but
        // checking the String case first keeps "1.0.0" out of the integer path either way.
        if let s = raw as? String {
            if let version = SemanticVersion(s), s.contains(".") {
                return .hostVersion(version)
            }
            if let level = Int(s.trimmingCharacters(in: .whitespaces)) {
                return .apiLevel(level)
            }
            return nil
        }
        if let level = intValue(from: raw) {
            return .apiLevel(level)
        }
        return nil
    }

    /// Read an Int defensively from a plist value that may arrive as an Int,
    /// NSNumber, or numeric String.
    private static func intValue(from raw: Any?) -> Int? {
        guard let raw = raw else { return nil }
        if let i = raw as? Int {
            return i
        }
        if let n = raw as? NSNumber {
            return n.intValue
        }
        if let s = raw as? String, let i = Int(s.trimmingCharacters(in: .whitespaces)) {
            return i
        }
        return nil
    }

    /// Normalize `PCPluginExtensions` (either `[String]` or a delimited
    /// `String`) into a lowercased list of extensions without leading dots.
    private static func extractExtensions(from raw: Any?) -> [String] {
        var rawList: [String] = []
        if let array = raw as? [String] {
            rawList = array
        } else if let array = raw as? [Any] {
            rawList = array.map { String(describing: $0) }
        } else if let str = raw as? String {
            let separators = CharacterSet(charactersIn: ";, ").union(.whitespaces)
            rawList = str.components(separatedBy: separators)
        }

        return rawList
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { ext -> String in
                var e = ext.lowercased()
                if e.hasPrefix(".") {
                    e.removeFirst()
                }
                return e
            }
            .filter { !$0.isEmpty }
    }
}

/// The subset of a `pluginst.inf` `[plugininstall]` section Peach Commander
/// cares about when offering to install a downloaded plugin archive.
public struct PluginInstallInfo: Sendable, Equatable {
    /// Mapped from the TC `type` key (wcx/wfx/wlx/wdx) to our `PluginType`.
    public let type: PluginType?
    public let file: String?
    public let description: String?
    public let defaultDir: String?

    public init(type: PluginType?, file: String?, description: String?, defaultDir: String?) {
        self.type = type
        self.file = file
        self.description = description
        self.defaultDir = defaultDir
    }
}

/// Hand-rolled parser for the TC `pluginst.inf` install descriptor format.
public enum PluginInstallInfoParser {
    /// Parse a `pluginst.inf` body (the `[plugininstall]` section).
    /// Keys are case-insensitive; unknown keys are ignored. If the section is
    /// absent, returns an all-nil `PluginInstallInfo`.
    public static func parse(_ text: String) -> PluginInstallInfo {
        var inTargetSection = false
        var values: [String: String] = [:]  // lowercased key -> raw value

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            // Comments: TC .inf files use ';' for comments on their own line.
            if line.hasPrefix(";") || line.hasPrefix("#") { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                let header = line.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
                inTargetSection = header.lowercased() == "plugininstall"
                continue
            }

            guard inTargetSection else { continue }

            guard let eqIndex = line.firstIndex(of: "=") else { continue }
            let key = line[line.startIndex..<eqIndex]
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            let value = line[line.index(after: eqIndex)...]
                .trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            values[key] = value
        }

        let typeString = values["type"]
        let type = typeString.flatMap { PluginType.fromTCType($0) }

        return PluginInstallInfo(
            type: type,
            file: values["file"],
            description: values["description"],
            defaultDir: values["defaultdir"]
        )
    }
}
