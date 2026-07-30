// SPDX-License-Identifier: Apache-2.0
// FileSystemPlugin.swift - PFX "file system" plugin API (in-process realization).
//
// A file-system plugin exposes a VirtualFileSystem to be mounted like a drive
// (Total Commander's WFX). It may contribute always-available drives (e.g. iCloud
// as a local sync folder) and/or an interactive "connect" action (e.g. WebDAV,
// which prompts for a URL). Plugins reach the app only through `FileSystemHost`
// (mount a VFS in the active panel, present dialogs), so the core no longer
// hard-wires WebDAV/iCloud; it registers plugins and routes to them.
//
// In-process (shared frameworks, native VirtualFileSystem, no per-file ABI
// marshalling) is the resource-ideal form for bundled providers; a future C-ABI
// `.pfxplugin` loader can register discovered plugins here too. See
// docs/plugin-externalization-assessment.md.

import AppKit
import PCVFS

@MainActor
public protocol FileSystemHost: AnyObject {
    /// Mount `fs` in the active panel and open `startPath` (like a drive).
    func fsMount(_ fs: VirtualFileSystem, startPath: String)
    var fsParentWindow: NSWindow? { get }
    func fsPresentInfo(_ title: String, _ message: String)
}

@MainActor
public protocol FileSystemPlugin: AnyObject {
    var id: String { get }
    /// Title for an interactive connect command, or nil if the plugin only
    /// contributes static drives.
    var connectTitle: String? { get }
    /// Perform the interactive connect (show a dialog, build a VFS, host.fsMount).
    func connect(host: FileSystemHost)
    /// Always-available drives this plugin contributes to the drive bar.
    func driveVolumes() -> [Volume]
}

public extension FileSystemPlugin {
    var connectTitle: String? { nil }
    func connect(host: FileSystemHost) {}
    func driveVolumes() -> [Volume] { [] }
}

@MainActor
public final class FileSystemPluginRegistry {
    public static let shared = FileSystemPluginRegistry()
    private var plugins: [String: FileSystemPlugin] = [:]
    private var order: [String] = []

    public func register(_ plugin: FileSystemPlugin) {
        if plugins[plugin.id] == nil { order.append(plugin.id) }
        plugins[plugin.id] = plugin
    }

    /// Drop all registered plugins (before re-aggregating enabled plugins).
    public func removeAll() { plugins.removeAll(); order.removeAll() }

    public func plugin(id: String) -> FileSystemPlugin? { plugins[id] }
    public var all: [FileSystemPlugin] { order.compactMap { plugins[$0] } }

    /// Plugins that expose an interactive connect command.
    public var connectPlugins: [FileSystemPlugin] { all.filter { $0.connectTitle != nil } }

    /// Aggregate of every plugin's contributed drives (for the drive bar).
    public func driveVolumes() -> [Volume] { all.flatMap { $0.driveVolumes() } }
}
