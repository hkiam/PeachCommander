// SPDX-License-Identifier: Apache-2.0
// PFXHostBridge.swift - App-side bridge & adapter for external PFX file-system plugins.
//
// PFXHostBridge builds the PfxHostServices C-callback table from a FileSystemHost
// (non-capturing @convention(c) trampolines; the bridge is recovered from the
// opaque `host` token). Passwords go through a Keychain-backed crypt callback so
// plugins never link Security or touch disk for secrets. LoadedPFXPlugin adapts a
// loaded PFX plugin to the FileSystemPlugin protocol: static drives → the drive
// bar, an interactive connect → a mounted PFXFileSystem. The plugin code itself
// lives entirely in an external .pfxplugin bundle.

import AppKit
import PCVFS
import PCFoundation
import PCPluginHost
import CPFX
import Security

/// Bridges a FileSystemHost to the PFX C-ABI host-services table.
@MainActor
final class PFXHostBridge {
    private weak var host: FileSystemHost?
    private let keychainService = "com.peachcommander.pfx"

    /// Where a plugin's transfer progress goes, and where its abort answer comes from.
    ///
    /// `nonisolated let` on purpose: the plugin reports progress from the connection's serial queue,
    /// so the C trampoline below must be able to reach this without hopping to the main actor. The
    /// sink does its own locking; see `PFXProgressSink`.
    nonisolated let progressSink = PFXProgressSink()

    init(_ host: FileSystemHost) { self.host = host }

    func makeServices() -> PfxHostServices {
        var s = PfxHostServices()
        s.host = Unmanaged.passUnretained(self).toOpaque()
        s.parentWindow = host?.fsParentWindow.map { Unmanaged.passUnretained($0).toOpaque() }

        // Progress. Unlike every other callback here this one does NOT hop to the main actor: the
        // plugin reports from the queue its transfer is running on, and `MainActor.assumeIsolated`
        // off the main thread traps rather than hops (F-422 bought that lesson once already).
        // `PFXProgressSink` is built for exactly this — its own lock, no isolation.
        s.progress = { host, name, pct in
            guard let host else { return Int32(PC_CONTINUE) }
            let bridge = Unmanaged<PFXHostBridge>.fromOpaque(host).takeUnretainedValue()
            let carryOn = bridge.progressSink.report(name.map { String(cString: $0) } ?? "", Int(pct))
            return carryOn ? Int32(PC_CONTINUE) : Int32(PC_ABORT)
        }

        s.presentInfo = { host, title, message in
            guard let host else { return }
            MainActor.assumeIsolated {
                let b = Unmanaged<PFXHostBridge>.fromOpaque(host).takeUnretainedValue()
                b.host?.fsPresentInfo(title.map { String(cString: $0) } ?? "",
                                      message.map { String(cString: $0) } ?? "")
            }
        }

        s.crypt = { host, mode, store, password, maxlen in
            guard let host else { return Int32(PC_E_NOT_SUPPORTED) }
            return MainActor.assumeIsolated {
                let b = Unmanaged<PFXHostBridge>.fromOpaque(host).takeUnretainedValue()
                return b.crypt(mode: Int(mode), store: store.map { String(cString: $0) } ?? "",
                               password: password, maxlen: Int(maxlen))
            }
        }

        s.getContext = { host, key, out, maxlen in
            guard let host, let key, let out, maxlen > 0 else { return 0 }
            return MainActor.assumeIsolated {
                let b = Unmanaged<PFXHostBridge>.fromOpaque(host).takeUnretainedValue()
                guard let value = b.context(String(cString: key)) else { return 0 }
                _ = value.withCString { strlcpy(out, $0, Int(maxlen)) }
                return 1
            }
        }
        return s
    }

    /// The table for `PfxInit`, which is the same one minus the parent window.
    ///
    /// At load time there is nothing to be modal to — the plugin has not asked for a dialog and
    /// the window it would attach to may not exist yet. Handing over a window pointer that is only
    /// valid by accident invites a plugin to keep it; the ABI documents NULL here and points at
    /// PfxConnect's services for the real one.
    func makeLoadTimeServices() -> PfxHostServices {
        var s = makeServices()
        s.parentWindow = nil
        return s
    }

    /// Answer a host context key, or nil for one we do not know.
    ///
    /// `configRoot` is the whole reason this exists. Plugins used to build their own path under
    /// Application Support, which meant `-ConfigRoot` isolated the host and nothing else: an
    /// automated run wrote its throwaway sites into the user's real configuration. Handing out the
    /// host's resolved root is what makes a plugin follow the host wherever it has been pointed.
    private func context(_ key: String) -> String? {
        switch key {
        case "configRoot": return ConfigPaths.resolve().root.path
        default: return nil
        }
    }

    // MARK: - Keychain-backed credential store

    private func crypt(mode: Int, store: String, password: UnsafeMutablePointer<CChar>?, maxlen: Int) -> Int32 {
        guard !store.isEmpty else { return Int32(PC_E_NOT_SUPPORTED) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: store,
        ]
        switch mode {
        case Int(PC_CRYPT_SAVE_PASSWORD):
            guard let password else { return Int32(PC_E_NOT_SUPPORTED) }
            let data = Data(String(cString: password).utf8)
            SecItemDelete(query as CFDictionary)
            var add = query; add[kSecValueData as String] = data
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess ? Int32(PC_OK) : Int32(PC_E_EWRITE)
        case Int(PC_CRYPT_LOAD_PASSWORD), Int(PC_CRYPT_COPY_PASSWORD):
            guard let password, maxlen > 0 else { return Int32(PC_E_NOT_SUPPORTED) }
            var copy = query
            copy[kSecReturnData as String] = true
            copy[kSecMatchLimit as String] = kSecMatchLimitOne
            var out: CFTypeRef?
            guard SecItemCopyMatching(copy as CFDictionary, &out) == errSecSuccess,
                  let data = out as? Data, let str = String(data: data, encoding: .utf8) else {
                return Int32(PC_E_EOPEN)
            }
            _ = str.withCString { strlcpy(password, $0, maxlen) }
            return Int32(PC_OK)
        case Int(PC_CRYPT_DELETE):
            SecItemDelete(query as CFDictionary)
            return Int32(PC_OK)
        default:
            return Int32(PC_E_NOT_SUPPORTED)
        }
    }
}

/// Presents a loaded external PFX plugin to the app as a FileSystemPlugin.
@MainActor
final class LoadedPFXPlugin: FileSystemPlugin {
    let id: String
    private let plugin: PFXPlugin
    /// The bridge behind the services table given to `PfxInit`. Held, not used: the plugin may
    /// call back through it at any time while it is loaded, and the trampolines recover the bridge
    /// from an unretained opaque pointer — so if nothing here kept it alive it would be freed the
    /// moment loading finished, and the first callback would land in released memory.
    private let loadBridge: PFXHostBridge?

    init(id: String, plugin: PFXPlugin, retaining loadBridge: PFXHostBridge? = nil) {
        self.id = id
        self.plugin = plugin
        self.loadBridge = loadBridge
    }

    var connectTitle: String? { plugin.connectTitle() }

    func connect(host: FileSystemHost) {
        let bridge = PFXHostBridge(host)
        var services = bridge.makeServices()
        guard let conn = withUnsafePointer(to: &services, { plugin.connect(services: $0) }) else { return }
        let fsID = plugin.connectionId(conn)
        // The connection id qualifies this mount's content columns (fieldID =
        // "<fsID>.<leaf>") so a saved column set keeps matching across sessions.
        let fs = PFXFileSystem(plugin: plugin, conn: conn, fsID: fsID,
                               capabilities: plugin.capabilities, retaining: bridge,
                               contentQualifier: fsID, progressSink: bridge.progressSink)
        host.fsMount(fs, startPath: "/")
    }

    func driveVolumes() -> [Volume] {
        plugin.volumes().map { v in
            guard v.isLocal else {
                // Non-local volume (e.g. "TaskManager"): a drive chip whose click
                // connects + mounts this plugin. The "pfxmount:" sentinel path
                // carries the plugin id; the host routes it to connect(host:)
                // instead of a filesystem navigation. Icon + order are plugin-owned.
                return Volume(id: "pfxvol:\(id):\(v.id)", name: v.name,
                              path: "pfxmount:\(id)", isRemovable: false, isEjectable: false,
                              isHidden: false, capacity: 0, freeSpace: 0, fsType: "Plugin",
                              icon: v.icon, sortOrder: v.order)
            }
            let rv = try? URL(fileURLWithPath: v.path).resourceValues(
                forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            return Volume(id: v.id, name: v.name, path: v.path,
                          isRemovable: v.isRemovable, isEjectable: v.isRemovable, isHidden: false,
                          capacity: Int64(rv?.volumeTotalCapacity ?? 0),
                          freeSpace: Int64(rv?.volumeAvailableCapacity ?? 0), fsType: "Cloud",
                          icon: v.icon, sortOrder: v.order)
        }
    }
}
