// PluginManager.swift - Discovery + enable/disable + associations (I14 T02/T03).
//
// Ties PluginHost.discover to the persisted PluginConfig: it knows which plugins
// exist, which are enabled, and which packer plugin (if any) is associated with a
// file extension. The host consults `packerPlugin(forExtension:)` before the
// built-in archive formats. Actual dylib loading is on demand via PluginHost.openLibrary.

import Foundation

/// Failures specific to installing a plugin from a `.zip` distribution (F-235).
public enum PluginInstallError: Error, Equatable {
    case unzipFailed
    case noPluginFound
}

public actor PluginManager {
    /// User-writable plugins dir (installs/removes land here).
    private let pluginsDir: URL
    /// Read-only plugins shipped inside the app bundle (Contents/PlugIns). Present
    /// on installed builds so a fresh DMG install has all plugins out of the box.
    private let bundledPluginsDir: URL?
    private let configURL: URL
    private var config: PluginConfig
    public private(set) var discovered: [DiscoveredPlugin]
    public private(set) var failures: [(bundlePath: String, error: PluginLoadError)]

    public init(pluginsDir: URL, configURL: URL, bundledPluginsDir: URL? = nil) {
        self.pluginsDir = pluginsDir
        self.bundledPluginsDir = bundledPluginsDir
        self.configURL = configURL
        self.config = PluginConfig()
        self.discovered = []
        self.failures = []
    }

    /// Re-scan the plugin directories and reload the config. The user dir is scanned
    /// first so a user-installed copy overrides the bundled one of the same name.
    public func reload() {
        let dirs = [pluginsDir, bundledPluginsDir].compactMap { $0 }
        let result = PluginHost.discover(in: dirs)
        var seen = Set<String>()
        discovered = result.discovered.filter { seen.insert($0.manifest.name).inserted }
        failures = result.failures
        let text = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        config = PluginConfig(parsing: text)
    }

    /// All discovered plugins that are currently enabled.
    public func enabledPlugins() -> [DiscoveredPlugin] {
        discovered.filter { config.isEnabled($0.manifest.name) }
    }

    public func isEnabled(_ name: String) -> Bool { config.isEnabled(name) }

    public func setEnabled(_ name: String, _ enabled: Bool) {
        config.setEnabled(name, enabled)
        persist()
    }

    /// The enabled PCX plugin associated with `ext`, honouring an explicit
    /// association first, then any enabled PCX plugin that declares the extension.
    public func packerPlugin(forExtension ext: String) -> DiscoveredPlugin? {
        let normalized = ext.lowercased()
        if let name = config.plugin(forExtension: normalized),
           let plugin = discovered.first(where: { $0.manifest.name == name }),
           plugin.manifest.type == .pcx, config.isEnabled(name) {
            return plugin
        }
        return enabledPlugins().first {
            $0.manifest.type == .pcx && $0.manifest.extensions.contains(normalized)
        }
    }

    public func setAssociation(ext: String, plugin: String?) {
        config.setAssociation(ext: ext, plugin: plugin)
        persist()
    }

    public func currentConfig() -> PluginConfig { config }

    /// Install a plugin bundle by copying it into the plugins directory, then reload.
    /// Returns the discovered plugin on success. Throws on copy/validation failure.
    @discardableResult
    public func install(bundleURL: URL) throws -> DiscoveredPlugin {
        let fm = FileManager.default
        try fm.createDirectory(at: pluginsDir, withIntermediateDirectories: true)
        let dest = pluginsDir.appendingPathComponent(bundleURL.lastPathComponent)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.copyItem(at: bundleURL, to: dest)
        switch PluginHost.load(bundle: dest) {
        case .success(let plugin):
            reload()
            return plugin
        case .failure(let error):
            try? fm.removeItem(at: dest)   // roll back an invalid install
            throw error
        }
    }

    /// Install a plugin from a `.zip` (TC-style distribution): unpack it, locate the
    /// plugin bundle inside (honoring a `pluginst.inf` `file=` if present), and
    /// install that bundle. F-235.
    @discardableResult
    public func installFromZip(zipURL: URL) throws -> DiscoveredPlugin {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("pc-plugin-install-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temp) }

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-q", "-o", zipURL.path, "-d", temp.path]
        unzip.standardOutput = FileHandle.nullDevice
        unzip.standardError = FileHandle.nullDevice
        do { try unzip.run() } catch { throw PluginInstallError.unzipFailed }
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else { throw PluginInstallError.unzipFailed }

        guard let bundle = Self.locatePluginBundle(in: temp) else { throw PluginInstallError.noPluginFound }
        return try install(bundleURL: bundle)
    }

    /// Find the plugin bundle inside an unpacked directory tree: a directory whose
    /// name ends with "plugin" and contains Contents/Info.plist. If a `pluginst.inf`
    /// names a `file=`, that bundle wins; otherwise the first candidate is used.
    nonisolated static func locatePluginBundle(in dir: URL) -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        var wantedFile: String?
        guard let en = fm.enumerator(at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                                     options: [.skipsHiddenFiles]) else { return nil }
        for case let url as URL in en {
            if url.lastPathComponent.lowercased() == "pluginst.inf",
               let text = try? String(contentsOf: url, encoding: .utf8) {
                wantedFile = PluginInstallInfoParser.parse(text).file
            }
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir, url.lastPathComponent.lowercased().hasSuffix("plugin"),
               fm.fileExists(atPath: url.appendingPathComponent("Contents/Info.plist").path) {
                candidates.append(url)
            }
        }
        if let wantedFile, let match = candidates.first(where: { $0.lastPathComponent == wantedFile }) {
            return match
        }
        return candidates.first
    }

    /// Remove the plugin with the given name, then reload. A user-installed bundle is
    /// deleted; a bundle shipped inside the app can't be deleted, so it is disabled
    /// instead (and would otherwise reappear on the next scan).
    public func remove(name: String) {
        if let plugin = discovered.first(where: { $0.manifest.name == name }) {
            if plugin.bundlePath.hasPrefix(pluginsDir.path + "/") {
                try? FileManager.default.removeItem(atPath: plugin.bundlePath)
                config.setEnabled(name, true)    // drop any stale disabled entry
            } else {
                config.setEnabled(name, false)   // bundled: keep the file, disable it
            }
        }
        persist()
        reload()
    }

    private func persist() {
        try? config.serialized().write(to: configURL, atomically: true, encoding: .utf8)
    }
}
