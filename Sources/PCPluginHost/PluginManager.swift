// SPDX-License-Identifier: Apache-2.0
// PluginManager.swift - Discovery + enable/disable + associations (I14 T02/T03).
//
// Ties PluginHost.discover to the persisted PluginConfig: it knows which plugins
// exist, which are enabled, and which packer plugin (if any) is associated with a
// file extension. The host consults `packerPlugin(forExtension:)` before the
// built-in archive formats. Actual dylib loading is on demand via PluginHost.openLibrary.

import Foundation
import PCFoundation

/// Failures specific to installing a plugin from a `.zip` / `.pcplug` distribution (F-235).
public enum PluginInstallError: Error, Equatable {
    case unzipFailed
    case noPluginFound
    /// More than one plugin bundle in the package and no `pluginst.inf` naming which one.
    ///
    /// Previously the first one in enumeration order was installed and the others were dropped
    /// without a word — a silent choice on the user's behalf, made from an ordering nobody
    /// controls.
    case ambiguousPackage([String])
    /// A path in the archive resolved outside the staging directory (a `../` entry, or a symlink
    /// pointing out of the tree). Refused rather than repaired.
    case escapesPackage(String)
}

/// A plugin package inspected but not yet installed — everything the install prompt needs to
/// describe what is about to be loaded, read without running a line of the plugin's code (F-482).
///
/// Staging and committing are separate steps for one reason: installing a plugin is running code
/// with the whole user's files in reach, and the only honest place to ask is *after* we can name
/// the plugin, its version and what it claims, and *before* anything is copied anywhere.
public struct StagedPlugin: Sendable {
    /// The bundle inside the staging directory.
    public let bundleURL: URL
    public let manifest: PluginManifest
    /// The TC-style install descriptor, when the package carries one.
    public let installInfo: PluginInstallInfo?
    /// Whether the package arrived with `com.apple.quarantine` — i.e. off the internet.
    public let isQuarantined: Bool
    /// The temporary tree to delete once the caller is done, whatever the outcome.
    public let stagingRoot: URL
    /// The version already installed under this identifier, if any (upgrade / downgrade / same).
    public let installedVersion: SemanticVersion?
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
        // Deduped by identifier, not by display name: that is what makes a user-installed copy
        // override the bundled one *of the same plugin* rather than of any plugin that happens
        // to share its title.
        discovered = result.discovered.filter { seen.insert($0.manifest.identifier).inserted }
        failures = result.failures
        let text = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        config = PluginConfig(parsing: text)
        migrateConfigKeys()
    }

    /// Rewrite a `plugins.ini` written before entries were keyed on the identifier (F-482).
    ///
    /// Runs on every reload and is a no-op after the first one that had something to do — the
    /// alternative, a "migrated" marker, is another piece of state to get wrong.
    ///
    /// Guarded on a non-empty discovery, and that guard is the whole safety of it: on a first
    /// launch, or with the plugins directory not yet created, the map would be empty and there
    /// would be nothing to rewrite *toward*. A migration that runs against no plugins can only
    /// misread a perfectly good config.
    private func migrateConfigKeys() {
        guard !discovered.isEmpty else { return }
        var map: [String: String] = [:]
        for plugin in discovered where plugin.manifest.identifier != plugin.manifest.name {
            // A name shared by two plugins cannot be migrated: there is no way to know which of
            // them the old entry meant. Leaving it alone keeps the pre-identifier behaviour for
            // that one entry, which is the least surprising thing available.
            if map[plugin.manifest.name] != nil {
                map[plugin.manifest.name] = nil
                continue
            }
            map[plugin.manifest.name] = plugin.manifest.identifier
        }
        guard let migrated = config.migratedKeys(nameToIdentifier: map) else { return }
        config = migrated
        persist()
    }

    /// All discovered plugins that are currently enabled.
    public func enabledPlugins() -> [DiscoveredPlugin] {
        // Consults the manifest, not just the deny-list: a plugin that ships disabled is only in
        // here once the user turns it on. Using the name-only rule silently defeated that.
        discovered.filter { config.isEnabled($0.manifest.identifier, enabledByDefault: $0.manifest.enabledByDefault) }
    }

    /// Whether `key` is on, honouring a manifest that asks to start off (F-345).
    ///
    /// `key` is a plugin identifier; a display name is still accepted for a plugin that declares
    /// no identifier, because for those the two are the same string. A key matching no
    /// discovered plugin falls back to the plain rule, so callers holding only a key — the
    /// settings list, the packer lookup — keep working.
    public func isEnabled(_ key: String) -> Bool {
        guard let m = manifest(forKey: key) else {
            return config.isEnabled(key)
        }
        return config.isEnabled(m.identifier, enabledByDefault: m.enabledByDefault)
    }

    public func setEnabled(_ key: String, _ enabled: Bool) {
        config.setEnabled(manifest(forKey: key)?.identifier ?? key, enabled)
        persist()
    }

    /// The manifest for an identifier, or for a display name when nothing claims that identifier.
    ///
    /// The name lookup is the compatibility half: `plugins.ini` files, saved associations and
    /// callers written before identifiers existed all speak names, and they must keep resolving.
    private func manifest(forKey key: String) -> PluginManifest? {
        if let m = discovered.first(where: { $0.manifest.identifier == key })?.manifest { return m }
        return discovered.first(where: { $0.manifest.name == key })?.manifest
    }

    /// The enabled PCX plugin associated with `ext`, honouring an explicit
    /// association first, then any enabled PCX plugin that declares the extension.
    public func packerPlugin(forExtension ext: String) -> DiscoveredPlugin? {
        let normalized = ext.lowercased()
        if let key = config.plugin(forExtension: normalized),
           let plugin = discovered.first(where: { $0.manifest.identifier == key || $0.manifest.name == key }),
           plugin.manifest.type == .pcx, isEnabled(plugin.manifest.identifier) {
            return plugin
        }
        return enabledPlugins().first {
            $0.manifest.type == .pcx && $0.manifest.extensions.contains(normalized)
        }
    }

    /// Every enabled PCX plugin, for the content-detection fallback.
    ///
    /// `packerPlugin(forExtension:)` answers the question the host asks first, and it can
    /// only ever answer it by name. A filesystem image called `firmware.bin`, or a rootfs
    /// with no extension at all, is not something an extension list can match — and those
    /// are exactly the files somebody installs an image reader for. The caller loads each
    /// of these and asks `CanYouHandleThisFile`, so the decision stays with the plugin.
    public func packerPlugins() -> [DiscoveredPlugin] {
        enabledPlugins().filter { $0.manifest.type == .pcx }
    }

    public func setAssociation(ext: String, plugin: String?) {
        config.setAssociation(ext: ext, plugin: plugin)
        persist()
    }

    public func currentConfig() -> PluginConfig { config }

    /// Install a plugin bundle by copying it into the plugins directory, then reload.
    /// Returns the discovered plugin on success. Throws on copy/validation failure.
    @discardableResult
    /// Install (or upgrade) a plugin bundle, and leave the previous one alone unless the new one loads.
    ///
    /// The old bundle is moved aside rather than deleted, because these two steps used to run in the
    /// wrong order: remove what is there, copy the new one in, and — if it fails to load — delete that
    /// too. An upgrade that turned out to be broken therefore left the user with *nothing* where they
    /// had something that worked, which is the one outcome an install must never produce (F-235).
    ///
    /// Validation happens at the final path, not at a temporary one: loading a bundle can depend on
    /// where it is, and a check that passes somewhere else is not a check.
    public func install(bundleURL: URL) throws -> DiscoveredPlugin {
        let fm = FileManager.default
        try fm.createDirectory(at: pluginsDir, withIntermediateDirectories: true)
        let dest = pluginsDir.appendingPathComponent(bundleURL.lastPathComponent)

        var backup: URL?
        if fm.fileExists(atPath: dest.path) {
            let aside = pluginsDir.appendingPathComponent(".pcinstall-\(UUID().uuidString)")
            try fm.moveItem(at: dest, to: aside)
            backup = aside
        }
        do {
            try fm.copyItem(at: bundleURL, to: dest)
        } catch {
            if let backup { try? fm.moveItem(at: backup, to: dest) }
            throw error
        }

        switch PluginHost.load(bundle: dest) {
        case .success(let plugin):
            if let backup { try? fm.removeItem(at: backup) }
            reload()
            return plugin
        case .failure(let error):
            try? fm.removeItem(at: dest)
            if let backup { try? fm.moveItem(at: backup, to: dest) }   // the working one comes back
            reload()
            throw error
        }
    }

    /// Install a plugin from a `.zip` / `.pcplug` (TC-style distribution): unpack it, locate the
    /// plugin bundle inside (honoring a `pluginst.inf` `file=` if present), and install that
    /// bundle. F-235.
    ///
    /// The unattended path. Anything user-facing goes through `stage` → prompt → `commit`
    /// instead, so the user is told what is about to be loaded before it is.
    @discardableResult
    public func installFromZip(zipURL: URL) throws -> DiscoveredPlugin {
        let staged = try stage(packageURL: zipURL)
        defer { discard(staged) }
        return try commit(staged, clearQuarantine: false)
    }

    /// Unpack `packageURL` into a temporary tree and read what it says about itself.
    ///
    /// Nothing is copied into the plugins directory and no code is loaded; the caller must
    /// eventually call `commit` or `discard`.
    public func stage(packageURL: URL) throws -> StagedPlugin {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("pc-plugin-install-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)

        var packageIsDirectory: ObjCBool = false
        _ = fm.fileExists(atPath: packageURL.path, isDirectory: &packageIsDirectory)

        let bundle: URL
        if packageIsDirectory.boolValue {
            // An already-unpacked bundle chosen or dropped directly: staged by reference, so the
            // rest of this path is the same whether the user picked a folder or a package.
            bundle = packageURL
        } else {
            do {
                try Self.unpack(packageURL, into: temp)
                bundle = try Self.locateSingleBundle(in: temp)
            } catch {
                try? fm.removeItem(at: temp)
                throw error
            }
        }

        let discoveredBundle: DiscoveredPlugin
        switch PluginHost.load(bundle: bundle) {
        case .success(let plugin): discoveredBundle = plugin
        case .failure(let error):
            try? fm.removeItem(at: temp)
            throw error
        }

        let infPath = temp.appendingPathComponent("pluginst.inf")
        let installInfo = (try? String(contentsOf: infPath, encoding: .utf8))
            .map(PluginInstallInfoParser.parse)

        let identifier = discoveredBundle.manifest.identifier
        let installedVersion = discovered.first { $0.manifest.identifier == identifier }?.manifest.version

        return StagedPlugin(bundleURL: bundle,
                            manifest: discoveredBundle.manifest,
                            installInfo: installInfo,
                            isQuarantined: Quarantine.isQuarantined(packageURL),
                            stagingRoot: temp,
                            installedVersion: installedVersion)
    }

    /// Install a staged plugin. `clearQuarantine` reflects the user's explicit consent.
    @discardableResult
    public func commit(_ staged: StagedPlugin, clearQuarantine: Bool) throws -> DiscoveredPlugin {
        let installed = try install(bundleURL: staged.bundleURL)
        if clearQuarantine {
            Quarantine.clear(URL(fileURLWithPath: installed.bundlePath))
        }
        return installed
    }

    /// Delete a staging tree. Safe to call twice.
    ///
    /// Only ever the staging root, which is why a bundle staged *by reference* — an unpacked folder
    /// the user picked — is safe: that one sits outside the root and is theirs, not ours to delete.
    /// (This used to branch on exactly that distinction and then do the same thing in both arms,
    /// which read as a safeguard while being none.)
    public func discard(_ staged: StagedPlugin) {
        try? FileManager.default.removeItem(at: staged.stagingRoot)
    }

    /// Unpack a zip-shaped package into `destination`, refusing anything that would land outside it.
    ///
    /// `unzip` declines absolute paths on its own, but the guarantee this install needs is
    /// stronger and cheaper to state than to trust: after unpacking, every item's *resolved* path
    /// must still be inside the staging root. That covers a `../` entry and the subtler case — a
    /// symlink in the archive that points somewhere else entirely and would be followed later by
    /// the copy into the plugins directory.
    nonisolated private static func unpack(_ package: URL, into destination: URL) throws {
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-q", "-o", package.path, "-d", destination.path]
        unzip.standardOutput = FileHandle.nullDevice
        unzip.standardError = FileHandle.nullDevice
        do { try unzip.run() } catch { throw PluginInstallError.unzipFailed }
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else { throw PluginInstallError.unzipFailed }
        try verifyContained(destination)
    }

    /// Every item under `root` must resolve to a path still under `root`.
    nonisolated private static func verifyContained(_ root: URL) throws {
        let fm = FileManager.default
        let realRoot = URL(fileURLWithPath: root.path).resolvingSymlinksInPath().path
        guard let en = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { return }
        for case let url as URL in en {
            let resolved = url.resolvingSymlinksInPath().path
            guard resolved == realRoot || resolved.hasPrefix(realRoot + "/") else {
                throw PluginInstallError.escapesPackage(url.lastPathComponent)
            }
        }
    }

    /// The one plugin bundle in an unpacked tree, or a stated reason there isn't one.
    nonisolated static func locateSingleBundle(in dir: URL) throws -> URL {
        let (candidates, wantedFile) = scanForBundles(in: dir)
        if let wantedFile, let match = candidates.first(where: { $0.lastPathComponent == wantedFile }) {
            return match
        }
        guard let first = candidates.first else { throw PluginInstallError.noPluginFound }
        guard candidates.count == 1 else {
            throw PluginInstallError.ambiguousPackage(candidates.map(\.lastPathComponent).sorted())
        }
        return first
    }

    /// Find the plugin bundle inside an unpacked directory tree: a directory whose
    /// name ends with "plugin" and contains Contents/Info.plist. If a `pluginst.inf`
    /// names a `file=`, that bundle wins; otherwise the first candidate is used.
    nonisolated static func locatePluginBundle(in dir: URL) -> URL? {
        let (candidates, wantedFile) = scanForBundles(in: dir)
        if let wantedFile, let match = candidates.first(where: { $0.lastPathComponent == wantedFile }) {
            return match
        }
        return candidates.first
    }

    /// Every bundle-shaped directory in the tree, plus the `file=` a `pluginst.inf` asked for.
    nonisolated private static func scanForBundles(in dir: URL) -> (candidates: [URL], wantedFile: String?) {
        let fm = FileManager.default
        var candidates: [URL] = []
        var wantedFile: String?
        guard let en = fm.enumerator(at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                                     options: [.skipsHiddenFiles]) else { return ([], nil) }
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
        return (candidates, wantedFile)
    }

    /// Remove the plugin with the given name, then reload. A user-installed bundle is
    /// deleted; a bundle shipped inside the app can't be deleted, so it is disabled
    /// instead (and would otherwise reappear on the next scan).
    public func remove(name key: String) {
        if let plugin = discovered.first(where: { $0.manifest.identifier == key || $0.manifest.name == key }) {
            let identifier = plugin.manifest.identifier
            if plugin.bundlePath.hasPrefix(pluginsDir.path + "/") {
                try? FileManager.default.removeItem(atPath: plugin.bundlePath)
                config.setEnabled(identifier, true)    // drop any stale disabled entry
            } else {
                config.setEnabled(identifier, false)   // bundled: keep the file, disable it
            }
        }
        persist()
        reload()
    }

    private func persist() {
        try? config.serialized().write(to: configURL, atomically: true, encoding: .utf8)
    }
}
