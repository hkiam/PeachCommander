// SPDX-License-Identifier: Apache-2.0
// PluginAIHost.swift — the handful of contrib C-ABI reads both AI plugins need.
//
// Reading the cursor, the selection and a context value is the same work whether the plugin is
// running a chat or a direct action, and it is fiddly enough (fixed buffers, 1/0 returns) to be
// worth having once. Shared through the SDK source pool rather than a framework, because that is
// how this repo shares plugin code — see the two decompiler plugins.

import AppKit

enum AIHost {
    /// Read a host context value via the getContext service callback.
    static func context(_ svc: PcHostServices, _ key: String) -> String? {
        guard let fn = svc.getContext else { return nil }
        var buf = [CChar](repeating: 0, count: 4096)
        let ok = key.withCString { k in fn(svc.host, k, &buf, 4096) }
        return ok == 1 ? String(cString: buf) : nil
    }

    /// The full path of the file under the cursor.
    static func cursorPath(_ svc: PcHostServices) -> String? {
        guard let fn = svc.cursorPath else { return nil }
        var buf = [CChar](repeating: 0, count: 4096)
        return fn(svc.host, &buf, 4096) == 1 ? String(cString: buf) : nil
    }

    /// Every selected path, or just the cursor's when nothing is marked. This is what makes an
    /// "AI ▸" action a commander action: the same thing over forty files, not one.
    static func selectedPaths(_ svc: PcHostServices) -> [String] {
        guard let count = svc.selectionCount, let pathAt = svc.selectionPath else {
            return cursorPath(svc).map { [$0] } ?? []
        }
        let n = Int(count(svc.host))
        guard n > 0 else { return cursorPath(svc).map { [$0] } ?? [] }
        var paths: [String] = []
        for i in 0..<n {
            var buf = [CChar](repeating: 0, count: 4096)
            if pathAt(svc.host, Int32(i), &buf, 4096) == 1 { paths.append(String(cString: buf)) }
        }
        return paths.isEmpty ? (cursorPath(svc).map { [$0] } ?? []) : paths
    }

    /// How many entries are actually MARKED, as opposed to sitting under the cursor.
    ///
    /// `selectedPaths` deliberately falls back to the cursor, which is right for an action on one
    /// file and wrong for deciding whether the reader meant "these" or "this folder".
    static func markedCount(_ svc: PcHostServices) -> Int {
        guard let count = svc.selectionCount else { return 0 }
        return Int(count(svc.host))
    }

    /// The configuration directory the host is using, or the home directory if it will not say.
    static func configRoot(_ svc: PcHostServices) -> String {
        context(svc, "configRoot") ?? NSHomeDirectory()
    }

    /// The window a plugin may present a sheet over, if there is one.
    static func parentWindow(_ svc: PcHostServices) -> NSWindow? {
        svc.parentWindow.map { Unmanaged<NSWindow>.fromOpaque($0).takeUnretainedValue() }
    }
}
