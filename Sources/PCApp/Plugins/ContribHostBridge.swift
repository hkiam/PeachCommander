// SPDX-License-Identifier: Apache-2.0
// ContribHostBridge.swift - App-side bridge for the contribution behavior ABI.
//
// Builds the unified PcHostServices C-callback table (Plugins/SDK/contrib.h) from
// a ContributionHost via non-capturing @convention(c) trampolines that recover the
// bridge from the opaque `host` token. Async host data (local cursor path,
// selection) is pre-resolved by the dispatcher and passed as a snapshot so the
// synchronous C callbacks can serve it. Passwords go through a Keychain-backed
// crypt callback. Mirrors PTXHostBridge/PFXHostBridge, unified.

import AppKit
import PCVFS
import PCPluginHost
import PCAutomation
import CContrib
import Security

/// Host services a contributed command/view may use. The window controller
/// implements it (already a ToolHost); the two extra hooks cover the unified ABI.
@MainActor
public protocol ContributionHost: ToolHost {
    /// Read a context value by key (same keys the declarative `when` sees).
    func contribContextValue(_ key: String) -> String?
    /// Trigger any host or plugin command by id (composition).
    func contribInvokeCommand(_ id: String)
    /// Show two files side by side in the host's compare window (F-416).
    func contribCompareFiles(pathA: String, pathB: String, titleA: String?, titleB: String?)
    /// Run the generic PFX connect+mount for the plugin bundle `pluginId` (used
    /// when a contributed command's behavior is "connect this file-system plugin"
    /// rather than a self-contained PcRunCommand). Returns true if handled.
    func contribConnectFileSystem(pluginId: String) -> Bool
    /// Install a plugin window's own menu-bar menus while that window is key.
    func contribRegisterToolWindow(window: UnsafeMutableRawPointer,
                                   editMenu: UnsafeMutableRawPointer?,
                                   contentMenu: UnsafeMutableRawPointer?, title: String)
    /// Resolve an internal link: navigate to a folder or reveal/open a file.
    func contribOpenPath(_ path: String)
    /// The `descript.ion` comment for a path, or nil — the one the Comment column shows (F-372).
    func contribFileComment(_ path: String) -> String?
    /// Set or clear it, keeping the Finder mirror in step.
    func contribSetFileComment(_ comment: String?, path: String)
    /// Navigate a specific main panel (side 0 = left, 1 = right) to `path`
    /// (a file selects it in its parent folder).
    func contribOpenPathInPanel(side: Int, path: String)
    /// Mount the plugin view `viewId` in the sidebar on demand, rooted at `root`.
    func contribPresentSidebarView(viewId: String, root: String)
    /// Remove an on-demand sidebar view.
    func contribDismissSidebarView(viewId: String)
    /// Add host-specific keys to the `when`/getContext snapshot (dynamic dispatch
    /// hook so concrete hosts can extend the context).
    func contribAugmentContext(_ context: inout ContributionContext)
    /// The host's automation core (tool engine), for plugins that drive the file
    /// manager (e.g. the AI assistant) via the automation* host services.
    func contribAutomationCore() -> AutomationCore?
    /// The host's current autonomy policy (applied to plugin-invoked tools).
    func contribAutomationPolicy() async -> PermissionPolicy
}

public extension ContributionHost {
    func contribConnectFileSystem(pluginId: String) -> Bool { false }
    func contribRegisterToolWindow(window: UnsafeMutableRawPointer,
                                   editMenu: UnsafeMutableRawPointer?,
                                   contentMenu: UnsafeMutableRawPointer?, title: String) {}
    func contribOpenPath(_ path: String) {}
    func contribFileComment(_ path: String) -> String? { nil }
    func contribSetFileComment(_ comment: String?, path: String) {}
    func contribOpenPathInPanel(side: Int, path: String) {}
    func contribPresentSidebarView(viewId: String, root: String) {}
    func contribDismissSidebarView(viewId: String) {}
    func contribAugmentContext(_ context: inout ContributionContext) {}
    func contribAutomationCore() -> AutomationCore? { nil }
    func contribAutomationPolicy() async -> PermissionPolicy { .standard }
}

public extension ContributionHost {
    /// Synchronous context snapshot for menu/keybinding `when` evaluation. Built
    /// from the (sync) cursor path; selection-count etc. resolve async elsewhere.
    func contributionContext() -> ContributionContext {
        var c = ContributionContext()
        let path = toolCursorPath()
        c.set("cursorPath", path)
        c.set("cursorName", path.map { ($0 as NSString).lastPathComponent })
        c.set("cursorExt", path.map { ($0 as NSString).pathExtension.lowercased() })
        c.set("cursorIsApp", path?.lowercased().hasSuffix(".app") ?? false)
        c.set("hasSelection", path != nil)
        contribAugmentContext(&c)   // dynamic dispatch: host adds its own keys
        return c
    }
    func contribContextValue(_ key: String) -> String? {
        let v = contributionContext()[key]
        return v == .absent ? nil : v.asString
    }
}

@MainActor
final class ContribHostBridge {
    private weak var host: ContributionHost?
    // Per-dispatch snapshot (async host data served to synchronous C callbacks).
    // The bridge is long-lived (its `host` token must stay valid for windows/views
    // that call back after the command returns); the snapshot is refreshed before
    // each command dispatch. Late callers use only host-live or explicit-arg
    // services (cursorPath, presentInfo, openPath, …), not the snapshot.
    private var localPath: String?
    private var selection: [String] = []
    private let keychainService = "com.peachcommander.contrib"

    init(_ host: ContributionHost) { self.host = host }

    func update(localPath: String?, selection: [String]) {
        self.localPath = localPath
        self.selection = selection
    }

    func makeServices() -> PcHostServices {
        var s = PcHostServices()
        s.host = Unmanaged.passUnretained(self).toOpaque()
        s.parentWindow = host?.toolParentWindow.map { Unmanaged.passUnretained($0).toOpaque() }

        s.cursorPath = { host, out, maxlen in
            guard let host, let out else { return 0 }
            return MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                guard let p = b.host?.toolCursorPath() else { return Int32(0) }
                _ = strlcpy(out, p, Int(maxlen)); return Int32(1)
            }
        }
        s.localCursorPath = { host, out, maxlen in
            guard let host, let out else { return 0 }
            return MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                guard let p = b.localPath else { return Int32(0) }
                _ = strlcpy(out, p, Int(maxlen)); return Int32(1)
            }
        }
        s.selectionCount = { host in
            guard let host else { return 0 }
            return MainActor.assumeIsolated {
                Int32(Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue().selection.count)
            }
        }
        s.selectionPath = { host, index, out, maxlen in
            guard let host, let out else { return 0 }
            return MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                guard b.selection.indices.contains(Int(index)) else { return Int32(0) }
                _ = strlcpy(out, b.selection[Int(index)], Int(maxlen)); return Int32(1)
            }
        }
        s.moveToTrash = { host, paths, count in
            guard let host else { return }
            MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                b.host?.toolMoveToTrash(ContribHostBridge.strings(paths, count))
            }
        }
        s.deletePermanently = { host, paths, count in
            guard let host else { return }
            MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                b.host?.toolDeletePermanently(ContribHostBridge.strings(paths, count))
            }
        }
        s.reloadActivePanel = { host in
            guard let host else { return }
            MainActor.assumeIsolated {
                Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue().host?.toolReloadActivePanel()
            }
        }
        s.presentInfo = { host, title, message in
            guard let host else { return }
            MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                b.host?.toolPresentInfo(title.map { String(cString: $0) } ?? "",
                                        message.map { String(cString: $0) } ?? "")
            }
        }
        s.getContext = { host, key, out, maxlen in
            guard let host, let key, let out else { return 0 }
            return MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                guard let v = b.host?.contribContextValue(String(cString: key)) else { return Int32(0) }
                _ = strlcpy(out, v, Int(maxlen)); return Int32(1)
            }
        }
        s.invokeCommand = { host, commandId in
            guard let host, let commandId else { return }
            MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                b.host?.contribInvokeCommand(String(cString: commandId))
            }
        }
        s.crypt = { host, mode, store, password, maxlen in
            guard let host else { return Int32(PC_E_NOT_SUPPORTED) }
            return MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                return b.crypt(mode: Int(mode), store: store.map { String(cString: $0) } ?? "",
                               password: password, maxlen: Int(maxlen))
            }
        }
        s.registerToolWindow = { host, window, editMenu, contentMenu, title in
            guard let host, let window else { return }
            MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                b.host?.contribRegisterToolWindow(window: window, editMenu: editMenu,
                                                  contentMenu: contentMenu,
                                                  title: title.map { String(cString: $0) } ?? "")
            }
        }
        s.openPath = { host, path in
            guard let host, let path else { return }
            MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                b.host?.contribOpenPath(String(cString: path))
            }
        }
        s.openPathInPanel = { host, side, path in
            guard let host, let path else { return }
            MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                b.host?.contribOpenPathInPanel(side: Int(side), path: String(cString: path))
            }
        }
        s.compareFiles = { host, pathA, pathB, titleA, titleB in
            guard let host, let pathA, let pathB else { return }
            MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                b.host?.contribCompareFiles(pathA: String(cString: pathA), pathB: String(cString: pathB),
                                            titleA: titleA.map { String(cString: $0) },
                                            titleB: titleB.map { String(cString: $0) })
            }
        }
        s.presentSidebarView = { host, viewId, root in
            guard let host, let viewId, let root else { return }
            MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                b.host?.contribPresentSidebarView(viewId: String(cString: viewId), root: String(cString: root))
            }
        }
        s.dismissSidebarView = { host, viewId in
            guard let host, let viewId else { return }
            MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                b.host?.contribDismissSidebarView(viewId: String(cString: viewId))
            }
        }

        // Automation core — these BLOCK (per contrib.h) and must be called off-main.
        s.automationToolsJson = { host in
            guard let host else { return nil }
            let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
            return ContribHostBridge.blockingCoreString(b) { core, _ in
                (try? JSONEncoder().encode(core.tools)).flatMap { String(data: $0, encoding: .utf8) }
            }
        }
        s.automationContextJson = { host in
            guard let host else { return nil }
            let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
            return ContribHostBridge.blockingCoreString(b) { core, _ in
                guard let ctx = try? await core.context() else { return nil }
                return (try? JSONEncoder().encode(ctx)).flatMap { String(data: $0, encoding: .utf8) }
            }
        }
        s.automationInvoke = { host, toolC, argsC in
            guard let host, let toolC else { return nil }
            let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
            let tool = String(cString: toolC)
            let args = argsC.map { Data(String(cString: $0).utf8) }
            return ContribHostBridge.blockingCoreString(b) { core, policy in
                ContribHostBridge.encodeOutcome(try? await core.invoke(tool: tool, arguments: args, policy: policy))
            }
        }
        s.automationConfirm = { host, tokenC in
            guard let host, let tokenC else { return nil }
            let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
            let token = String(cString: tokenC)
            return ContribHostBridge.blockingCoreString(b) { core, _ in
                ContribHostBridge.encodeOutcome(try? await core.confirm(token: token))
            }
        }
        s.automationFree = { _, ptr in if let ptr { free(ptr) } }
        // Per-file comments (F-372). Synchronous by design: a plugin view asks while drawing, and the
        // read is one small file in the directory the panel is already looking at.
        s.getFileComment = { host, pathC, out, maxlen in
            guard let host, let pathC, let out, maxlen > 0 else { return 0 }
            let path = String(cString: pathC)
            let text: String? = MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                return b.host?.contribFileComment(path)
            }
            guard let text, !text.isEmpty else { return 0 }
            let bytes = Array(text.utf8.prefix(Int(maxlen) - 1)) + [0]
            bytes.withUnsafeBufferPointer { src in
                out.update(from: UnsafeRawPointer(src.baseAddress!)
                    .assumingMemoryBound(to: CChar.self), count: bytes.count)
            }
            return 1
        }
        s.setFileComment = { host, pathC, commentC in
            guard let host, let pathC else { return }
            let path = String(cString: pathC)
            let comment = commentC.map { String(cString: $0) }
            MainActor.assumeIsolated {
                let b = Unmanaged<ContribHostBridge>.fromOpaque(host).takeUnretainedValue()
                b.host?.contribSetFileComment(comment, path: path)
            }
        }
        return s
    }

    /// Sendable box to carry a string result out of a Task across a semaphore barrier.
    private final class StringBox: @unchecked Sendable { var s: String? }

    /// Run an async op with the host's automation core + policy, blocking the CALLING
    /// (background) thread until it completes. Returns a strdup'd C string (freed by
    /// `automationFree`) or nil. MUST NOT be called on the main thread.
    nonisolated private static func blockingCoreString(
        _ b: ContribHostBridge,
        _ op: @escaping @Sendable (AutomationCore, PermissionPolicy) async -> String?
    ) -> UnsafeMutablePointer<CChar>? {
        let sem = DispatchSemaphore(value: 0)
        let box = StringBox()
        Task { @MainActor in
            guard let core = b.host?.contribAutomationCore() else { sem.signal(); return }
            let policy = await b.host?.contribAutomationPolicy() ?? .standard
            box.s = await op(core, policy)
            sem.signal()
        }
        sem.wait()
        return box.s.map { strdup($0) } ?? nil
    }

    /// Encode an AutomationOutcome into the JSON envelope the contrib.h automation
    /// callbacks return (payload as base64 so any bytes survive).
    nonisolated static func encodeOutcome(_ o: AutomationOutcome?) -> String {
        var d: [String: Any]
        switch o {
        case .ok(let payload):
            d = ["status": "ok"]
            if let payload { d["payloadB64"] = payload.base64EncodedString() }
        case .needsConfirmation(let plan, let token):
            d = ["status": "needsConfirmation", "plan": plan, "token": token]
        case .refused(let reason):
            d = ["status": "refused", "reason": reason]
        case .failed(let error):
            d = ["status": "failed", "error": error]
        case .none:
            d = ["status": "failed", "error": "no outcome"]
        }
        return (try? JSONSerialization.data(withJSONObject: d))
            .flatMap { String(data: $0, encoding: .utf8) } ?? #"{"status":"failed","error":"encode"}"#
    }

    private static func strings(_ p: UnsafePointer<UnsafePointer<CChar>?>?, _ count: Int32) -> [String] {
        guard let p else { return [] }
        return (0..<Int(count)).compactMap { p[$0].map { String(cString: $0) } }
    }

    private func crypt(mode: Int, store: String, password: UnsafeMutablePointer<CChar>?, maxlen: Int) -> Int32 {
        guard !store.isEmpty else { return Int32(PC_E_NOT_SUPPORTED) }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: keychainService,
                                     kSecAttrAccount as String: store]
        switch mode {
        case Int(PC_CRYPT_SAVE_PASSWORD):
            guard let password else { return Int32(PC_E_NOT_SUPPORTED) }
            SecItemDelete(query as CFDictionary)
            var add = query; add[kSecValueData as String] = Data(String(cString: password).utf8)
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess ? Int32(PC_OK) : Int32(PC_E_EWRITE)
        case Int(PC_CRYPT_LOAD_PASSWORD), Int(PC_CRYPT_COPY_PASSWORD):
            guard let password, maxlen > 0 else { return Int32(PC_E_NOT_SUPPORTED) }
            var copy = query; copy[kSecReturnData as String] = true; copy[kSecMatchLimit as String] = kSecMatchLimitOne
            var out: CFTypeRef?
            guard SecItemCopyMatching(copy as CFDictionary, &out) == errSecSuccess,
                  let data = out as? Data, let str = String(data: data, encoding: .utf8) else { return Int32(PC_E_EOPEN) }
            _ = str.withCString { strlcpy(password, $0, maxlen) }
            return Int32(PC_OK)
        case Int(PC_CRYPT_DELETE):
            SecItemDelete(query as CFDictionary); return Int32(PC_OK)
        default: return Int32(PC_E_NOT_SUPPORTED)
        }
    }
}
