// SPDX-License-Identifier: Apache-2.0
// PCXArchiveBackend.swift - What the installed PCX packer plugins can open (F-463).
//
// This logic used to be a closure inside `MainWindowController.loadPlugins`, wired
// only to the panels. That is why a `.tar.gz` could be opened with Enter — the
// shipped "libarchive Reader" plugin claims `tgz` and `gz` and is enabled by
// default — while the search, which built a bare `ArchiveFS` and never asked a
// plugin, reported the file as containing nothing.
//
// Moving it here puts it in the module that owns `PluginManager`, `PCXArchive` and
// `PCXArchiveFS`, where `PCPluginHostTests` can reach it, and behind the same
// protocol the built-in readers implement — so every consumer gets plugins for
// free instead of each remembering to ask.

import Foundation
import PCVFS

/// Archives handled by an enabled PCX packer plugin.
///
/// Registered ahead of the native backend, because `SPEC-012 §2` puts plugin
/// associations first: a user who installed a reader for a format meant it to win.
public struct PCXArchiveBackend: ArchiveBackend {
    public let backendID = "pcx"

    private let pluginManager: PluginManager

    public init(pluginManager: PluginManager) {
        self.pluginManager = pluginManager
    }

    /// Every extension declared by an enabled PCX plugin's manifest.
    ///
    /// Read from the manifests rather than kept as a list here: a plugin that
    /// already declares `tgz` starts working everywhere the moment it is enabled,
    /// with no edit on this side. That is the whole point of the registry.
    public func nameSet() async -> ArchiveNameSet {
        let exts = await pluginManager.enabledPlugins()
            .filter { $0.manifest.type == .pcx }
            .flatMap { $0.manifest.extensions }
        return ArchiveNameSet(extensions: Set(exts))
    }

    public func open(localFile: URL, intent: ArchiveOpenIntent) async -> ArchiveOpenOutcome {
        let path = localFile.path
        let ext = (path as NSString).pathExtension.lowercased()
        guard let plugin = await pluginManager.packerPlugin(forExtension: ext),
              case .success(let lib) = PluginHost.openLibrary(plugin),
              let fs = PCXArchiveFS(archivePath: path, library: lib, fsID: "pcx:\(path)") else {
            // No plugin claimed the extension, or the one that did could not open it.
            // Either way the native reader deserves its turn, so this is not a refusal.
            return .notAnArchive
        }
        return .opened(OpenedArchive(fs: fs, localURL: localFile, isTemporary: false,
                                     memberAccessCost: .processPerMember, backendID: backendID),
                       dispose: {})
    }

    /// Whether any enabled packer offered to decide by content.
    ///
    /// Costed deliberately: the probe reads a header off every file whose extension
    /// matched nothing, and nobody who has not installed such a plugin should pay
    /// for that — or have their files read speculatively at all.
    public var detectsByContent: Bool {
        get async {
            for plugin in await pluginManager.packerPlugins() {
                guard case .success(let lib) = PluginHost.openLibrary(plugin) else { continue }
                if PCXArchive(library: lib, pluginID: plugin.manifest.name).detectsByContent { return true }
            }
            return false
        }
    }

    /// Ask each content-detecting plugin whether this is theirs.
    ///
    /// The case an extension list can never cover: a filesystem image called
    /// `firmware.bin`, or a rootfs with no extension at all, is exactly the file
    /// somebody installs an image reader for. `CanYouHandleThisFile` leaves the
    /// decision with the plugin.
    public func openByContent(localFile: URL) async -> OpenedArchive? {
        let path = localFile.path
        for plugin in await pluginManager.packerPlugins() {
            guard case .success(let lib) = PluginHost.openLibrary(plugin) else { continue }
            let archive = PCXArchive(library: lib, pluginID: plugin.manifest.name)
            guard archive.detectsByContent, archive.canHandle(fileName: path) == true else { continue }
            if let fs = PCXArchiveFS(archivePath: path, library: lib, fsID: "pcx:\(path)") {
                return OpenedArchive(fs: fs, localURL: localFile, isTemporary: false,
                                     memberAccessCost: .processPerMember, backendID: backendID)
            }
        }
        return nil
    }
}
