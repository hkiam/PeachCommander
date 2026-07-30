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
import PCPluginHost
import CPFX
import Security

/// Bridges a FileSystemHost to the PFX C-ABI host-services table.
@MainActor
final class PFXHostBridge {
    private weak var host: FileSystemHost?
    private let keychainService = "com.peachcommander.pfx"
    init(_ host: FileSystemHost) { self.host = host }

    func makeServices() -> PfxHostServices {
        var s = PfxHostServices()
        s.host = Unmanaged.passUnretained(self).toOpaque()
        s.parentWindow = host?.fsParentWindow.map { Unmanaged.passUnretained($0).toOpaque() }

        // Progress: no host sink yet — never abort.
        s.progress = { _, _, _ in Int32(PC_CONTINUE) }

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
        return s
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

    init(id: String, plugin: PFXPlugin) {
        self.id = id
        self.plugin = plugin
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
                               contentQualifier: fsID)
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
