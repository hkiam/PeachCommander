// SPDX-License-Identifier: Apache-2.0
// PluginManifest.swift - Plugin manifest model, validation, and pluginst.inf parsing
//
// Implements SPEC-012 §1, §8 (feature F-235): the plugin manifest read from a
// plugin bundle's Info.plist, and the TC-compatible `pluginst.inf` install
// descriptor shipped inside a plugin .zip archive.
//
// Pure, deterministic, Sendable. No IO, no AppKit.

import Foundation

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

/// A validated plugin manifest, built from a plugin bundle's Info.plist.
public struct PluginManifest: Sendable, Equatable {
    public let type: PluginType
    public let apiVersion: Int
    public let name: String
    /// Default file-extension associations (lowercased, without a leading dot).
    public let extensions: [String]
    public let detectString: String?
    public let minHostVersion: Int?
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
        extensions: [String] = [],
        detectString: String? = nil,
        minHostVersion: Int? = nil,
        enabledByDefault: Bool = true
    ) {
        self.type = type
        self.apiVersion = apiVersion
        self.name = name
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
    /// `PCPluginAPIVersion` is present but doesn't match the version we support.
    case unsupportedAPIVersion(Int, current: Int)
}

/// Builds and validates `PluginManifest` values from a bundle's Info.plist.
public enum PluginManifestParser {
    /// The API version this host currently supports.
    public static let currentAPIVersion = 1

    /// Validate & build a manifest from an Info.plist dictionary (as read from
    /// the bundle). `PCPluginExtensions` may be `[String]` or a `;` / `,` /
    /// whitespace separated `String`.
    public static func parse(infoPlist dict: [String: Any]) -> Result<PluginManifest, PluginManifestError> {
        // --- type ---
        guard let rawType = dict["PCPluginType"] else {
            return .failure(.missingType)
        }
        let typeString = String(describing: rawType)
        guard let type = PluginType(rawValue: typeString.lowercased()) else {
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
        guard apiVersion == currentAPIVersion else {
            return .failure(.unsupportedAPIVersion(apiVersion, current: currentAPIVersion))
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

        // --- min host version ---
        let minHostVersion = intValue(from: dict["PCPluginMinHostVersion"])
        let enabledByDefault = (dict["PCPluginEnabledByDefault"] as? Bool) ?? true

        return .success(PluginManifest(
            type: type,
            apiVersion: apiVersion,
            name: name,
            extensions: extensions,
            detectString: detectString,
            minHostVersion: minHostVersion,
            enabledByDefault: enabledByDefault
        ))
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
