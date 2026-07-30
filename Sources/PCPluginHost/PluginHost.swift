// SPDX-License-Identifier: Apache-2.0
// PluginHost.swift - Plugin bundle discovery & validation (SPEC-012 §1, I14 T02).
//
// The non-dynamic-loading half of the host: it scans plugin directories for
// `*.pcxplugin` (and sibling type) bundles, reads and validates each
// Contents/Info.plist into a PluginManifest, and confirms the dylib is present.
// dlopen/dlsym symbol resolution and the per-plugin executor build on top of the
// DiscoveredPlugin values this produces.

import Foundation

/// A bundle that passed manifest validation and has a binary to load.
public struct DiscoveredPlugin: Sendable, Equatable {
    public let bundlePath: String
    public let manifest: PluginManifest
    /// Absolute path to Contents/MacOS/<name> (the dylib to dlopen).
    public let binaryPath: String
    public init(bundlePath: String, manifest: PluginManifest, binaryPath: String) {
        self.bundlePath = bundlePath
        self.manifest = manifest
        self.binaryPath = binaryPath
    }
}

/// Why a candidate bundle could not be loaded (surfaced in the plugin manager).
public enum PluginLoadError: Error, Equatable {
    case notABundle
    case missingInfoPlist
    case unreadableInfoPlist
    case manifest(PluginManifestError)
    case missingBinary(String)   // expected path
}

public struct PluginDiscoveryResult: Sendable {
    public let discovered: [DiscoveredPlugin]
    public let failures: [(bundlePath: String, error: PluginLoadError)]
    public init(discovered: [DiscoveredPlugin], failures: [(bundlePath: String, error: PluginLoadError)]) {
        self.discovered = discovered
        self.failures = failures
    }
}

public enum PluginHost {
    /// Recognised plugin bundle extensions (one per plugin type).
    public static let bundleExtensions = ["pcxplugin", "pfxplugin", "plxplugin", "pdxplugin", "ptxplugin"]

    /// Scan `directories` for plugin bundles, returning validated plugins and
    /// per-bundle load failures. Missing directories are skipped silently.
    public static func discover(in directories: [URL]) -> PluginDiscoveryResult {
        let fm = FileManager.default
        var ok: [DiscoveredPlugin] = []
        var fail: [(String, PluginLoadError)] = []
        for dir in directories {
            guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in entries.sorted(by: { $0.path < $1.path })
            where bundleExtensions.contains(url.pathExtension.lowercased()) {
                switch load(bundle: url) {
                case .success(let plugin): ok.append(plugin)
                case .failure(let err): fail.append((url.path, err))
                }
            }
        }
        return PluginDiscoveryResult(discovered: ok, failures: fail.map { (bundlePath: $0.0, error: $0.1) })
    }

    /// Validate a single bundle directory into a DiscoveredPlugin.
    public static func load(bundle url: URL) -> Result<DiscoveredPlugin, PluginLoadError> {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return .failure(.notABundle)
        }
        let infoPlist = url.appendingPathComponent("Contents/Info.plist")
        guard fm.fileExists(atPath: infoPlist.path) else { return .failure(.missingInfoPlist) }
        guard let dict = NSDictionary(contentsOf: infoPlist) as? [String: Any] else {
            return .failure(.unreadableInfoPlist)
        }
        switch PluginManifestParser.parse(infoPlist: dict) {
        case .failure(let e):
            return .failure(.manifest(e))
        case .success(let manifest):
            let base = url.deletingPathExtension().lastPathComponent
            let binary = url.appendingPathComponent("Contents/MacOS/\(base)")
            guard fm.fileExists(atPath: binary.path) else {
                return .failure(.missingBinary(binary.path))
            }
            return .success(DiscoveredPlugin(bundlePath: url.path, manifest: manifest, binaryPath: binary.path))
        }
    }
}
