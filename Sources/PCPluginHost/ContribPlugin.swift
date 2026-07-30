// SPDX-License-Identifier: Apache-2.0
// ContribPlugin.swift - Host wrapper for a loaded plugin's contribution behavior
// ABI (Plugins/SDK/contrib.h). Resolves the id-based entry points and exposes
// typed calls: run a declared command / build a declared view, passing a
// host-provided PcHostServices table. Mirrors PTXTool/PLXLister. Placement
// (menus, context, keys, views) is declarative in the manifest — this is only
// the behavior side.

import Foundation
import CContrib

public enum ContribSymbols {
    // Nothing is strictly required: a plugin may contribute only commands
    // (PcRunCommand), only views (PcMakeView), or both.
    public static let required: [String] = []
    public static let optional = ["PcRunCommand", "PcMakeView", "PcCloseView", "PcConfigure", "PcNotifyView", "PcGetApiVersion", "PcInvokeTool"]
}

public final class ContribPlugin {
    private let lib: PluginLibrary

    private typealias RunFn = @convention(c) (UnsafePointer<CChar>?, UnsafePointer<PcHostServices>?) -> Void
    private typealias MakeViewFn = @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer?
    private typealias CloseViewFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private typealias NotifyViewFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Void
    private typealias InvokeToolFn = @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafePointer<PcHostServices>?) -> UnsafeMutablePointer<CChar>?

    public init(library: PluginLibrary) { self.lib = library }

    /// Whether this library actually carries the contribution behavior ABI.
    public var hasBehavior: Bool { lib.symbol("PcRunCommand") != nil }

    /// Run the command `id`, passing the host services table.
    public func runCommand(_ id: String, services: UnsafePointer<PcHostServices>) {
        guard let ptr = lib.symbol("PcRunCommand") else { return }
        id.withCString { unsafeBitCast(ptr, to: RunFn.self)($0, services) }
    }

    /// Build the view `viewId` for `containerId` (returns an NSView* as a raw
    /// pointer), or nil if unsupported.
    public func makeView(_ viewId: String, container containerId: String,
                         services: UnsafePointer<PcHostServices>) -> UnsafeMutableRawPointer? {
        guard let ptr = lib.symbol("PcMakeView") else { return nil }
        return viewId.withCString { v in containerId.withCString { c in
            unsafeBitCast(ptr, to: MakeViewFn.self)(v, c, services)
        } }
    }

    public func closeView(_ view: UnsafeMutableRawPointer) {
        guard let ptr = lib.symbol("PcCloseView") else { return }
        unsafeBitCast(ptr, to: CloseViewFn.self)(view)
    }

    /// Push a host context change (e.g. "cursorPath") to a view from makeView.
    public func notifyView(_ view: UnsafeMutableRawPointer, key: String, value: String) {
        guard let ptr = lib.symbol("PcNotifyView") else { return }
        key.withCString { k in value.withCString { v in
            unsafeBitCast(ptr, to: NotifyViewFn.self)(view, k, v)
        } }
    }

    public var hasTools: Bool { lib.symbol("PcInvokeTool") != nil }

    /// Execute a contributed tool by name; returns the plugin's result string (freed
    /// here) or nil if the plugin has no tool ABI.
    public func invokeTool(_ name: String, argumentsJson: String,
                           services: UnsafePointer<PcHostServices>) -> String? {
        guard let ptr = lib.symbol("PcInvokeTool") else { return nil }
        let out = name.withCString { n in argumentsJson.withCString { a in
            unsafeBitCast(ptr, to: InvokeToolFn.self)(n, a, services)
        } }
        guard let out else { return nil }
        defer { free(out) }
        return String(cString: out)
    }
}
