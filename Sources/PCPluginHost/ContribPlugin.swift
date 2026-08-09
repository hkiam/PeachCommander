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
    public static let optional = ["PcRunCommand", "PcMakeView", "PcCloseView", "PcConfigure", "PcNotifyView", "PcNotifyThemeChanged", "PcGetApiVersion", "PcInvokeTool"]
}

public final class ContribPlugin {
    private let lib: PluginLibrary

    private typealias RunFn = @convention(c) (UnsafePointer<CChar>?, UnsafePointer<PcHostServices>?) -> Void
    private typealias MakeViewFn = @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer?
    private typealias CloseViewFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private typealias NotifyViewFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Void
    private typealias NotifyThemeFn = @convention(c) () -> Void
    private typealias InvokeToolFn = @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafePointer<PcHostServices>?) -> UnsafeMutablePointer<CChar>?

    public init(library: PluginLibrary) { self.lib = library }

    #if DEBUG
    /// How many times this plugin's views were built and destroyed across the C ABI (F-381).
    ///
    /// The host used to close and rebuild every mounted view on every contribution change, and the
    /// fix for that lives two levels up in `ViewContainerRegistry`. Counting here rather than there
    /// means the check does not ask the changed code whether it behaved — these two lines sit on the
    /// `PcMakeView` / `PcCloseView` call sites themselves, which is as close to the plugin's own
    /// account of events as the host can get without shipping a plugin built to tell tales.
    public private(set) var viewsMade = 0
    public private(set) var viewsClosed = 0
    #endif

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
        #if DEBUG
        viewsMade += 1
        #endif
        return viewId.withCString { v in containerId.withCString { c in
            unsafeBitCast(ptr, to: MakeViewFn.self)(v, c, services)
        } }
    }

    public func closeView(_ view: UnsafeMutableRawPointer) {
        guard let ptr = lib.symbol("PcCloseView") else { return }
        #if DEBUG
        viewsClosed += 1
        #endif
        unsafeBitCast(ptr, to: CloseViewFn.self)(view)
    }

    /// Push a host context change (e.g. "cursorPath") to a view from makeView.
    public func notifyView(_ view: UnsafeMutableRawPointer, key: String, value: String) {
        guard let ptr = lib.symbol("PcNotifyView") else { return }
        key.withCString { k in value.withCString { v in
            unsafeBitCast(ptr, to: NotifyViewFn.self)(view, k, v)
        } }
    }

    /// Tell the plugin the host's colour theme changed, so its own windows can repaint.
    ///
    /// Views get the finer-grained PcNotifyView("theme", id); this covers windows the plugin
    /// opened itself, which the host cannot address by view pointer. Absent symbol = no-op, which
    /// is every plugin built before the theme keys existed.
    public func notifyThemeChanged() {
        guard let ptr = lib.symbol("PcNotifyThemeChanged") else { return }
        unsafeBitCast(ptr, to: NotifyThemeFn.self)()
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
