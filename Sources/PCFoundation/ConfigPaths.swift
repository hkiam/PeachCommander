// SPDX-License-Identifier: Apache-2.0
// ConfigPaths.swift - Resolves the on-disk configuration root and well-known
// file locations within it (see docs/architecture/configuration.md, ADR-007).

import Foundation

/// Resolves the configuration root directory and the well-known config file
/// URLs within it. All engine code should receive paths via this struct
/// rather than hardcoding locations, so tests can point at an isolated
/// temporary directory (F-277).
public struct ConfigPaths: Sendable {

    /// The configuration root directory (created if missing by ``resolve``).
    public let root: URL

    /// Create paths rooted at an explicit directory. Does not create the directory.
    public init(root: URL) {
        self.root = root
    }

    /// Main config: layout, operation, display, colors, packer, etc.
    public var mainConfig: URL {
        root.appendingPathComponent("peachcmd.ini")
    }

    /// Session state: window frames, tabs, paths, sort orders, cmdline history.
    public var session: URL {
        root.appendingPathComponent("session.ini")
    }

    /// Directory hotlist (Ctrl+D).
    public var hotlist: URL {
        root.appendingPathComponent("hotlist.ini")
    }

    /// Saved workspaces: named panel layouts (tabs + locations).
    public var workspaces: URL {
        root.appendingPathComponent("workspaces.ini")
    }

    /// User (Start-menu) commands, TC usercmd.ini analog (I13 §4).
    /// Command-line aliases (F-256), `aliases.ini`.
    public var aliases: URL {
        root.appendingPathComponent("aliases.ini")
    }

    public var userCommands: URL {
        root.appendingPathComponent("usercmd.ini")
    }

    /// The default button bar, TC .bar format (I13 §2).
    public var buttonBar: URL {
        root.appendingPathComponent("default.bar")
    }

    /// User keyboard-remapping overrides, `[Shortcuts]` INI (I13 §5).
    public var userKeymap: URL {
        root.appendingPathComponent("keymap-user.ini")
    }

    /// Optional user main-menu override, TC `.mnu` format (F-257). When present it
    /// replaces the built-in command menus.
    public var mainMenu: URL {
        root.appendingPathComponent("default.mnu")
    }

    /// Directory holding additional `.mnu` files appended after the main menu (F-257).
    public var menusDirectory: URL {
        root.appendingPathComponent("menus", isDirectory: true)
    }

    /// Saved FTP/network connections (ftp-sites.ini); passwords live in the Keychain.
    public var ftpSites: URL {
        root.appendingPathComponent("ftp-sites.ini")
    }

    /// Directory holding installed plugin bundles (I14 §8).
    public var pluginsDirectory: URL {
        root.appendingPathComponent("plugins", isDirectory: true)
    }

    /// Plugin enable/disable + associations, `plugins.ini` (I14).
    public var pluginsConfig: URL {
        root.appendingPathComponent("plugins.ini")
    }

    /// Custom column sets, `columns.ini` (SPEC-002 §3).
    public var columns: URL {
        root.appendingPathComponent("columns.ini")
    }

    /// Saved Find-Files search templates, `search-templates.json`.
    public var searchTemplates: URL {
        root.appendingPathComponent("search-templates.json")
    }

    /// Saved multi-rename presets, `rename-presets.json`.
    public var renamePresets: URL {
        root.appendingPathComponent("rename-presets.json")
    }

    /// Saved directory-sync presets, `sync-presets.json` (F-194).
    public var syncPresets: URL {
        root.appendingPathComponent("sync-presets.json")
    }

    /// Per-extension viewer/editor associations, `associations.ini` (F-273).
    public var associations: URL {
        root.appendingPathComponent("associations.ini")
    }

    /// User-defined "Mark All" highlight colors, `markcolors.ini` (#7).
    public var markColors: URL {
        root.appendingPathComponent("markcolors.ini")
    }

    /// Resolve the configuration root, in priority order:
    /// 1. `-ConfigRoot <path>` launch argument
    /// 2. `PEACHCMD_CONFIG_ROOT` environment variable
    /// 3. `~/Library/Application Support/PeachCommander`
    ///
    /// The resolved directory is created (including intermediate directories)
    /// if it doesn't already exist.
    public static func resolve(
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ConfigPaths {
        let root: URL

        if let argRoot = valueForArgument("-ConfigRoot", in: arguments) {
            root = URL(fileURLWithPath: argRoot, isDirectory: true)
        } else if let envRoot = environment["PEACHCMD_CONFIG_ROOT"], !envRoot.isEmpty {
            root = URL(fileURLWithPath: envRoot, isDirectory: true)
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support", isDirectory: true)
            root = appSupport.appendingPathComponent("PeachCommander", isDirectory: true)
        }

        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        return ConfigPaths(root: root)
    }

    /// Extract the value following a `-flag value` pair in an argument list.
    private static func valueForArgument(_ flag: String, in arguments: [String]) -> String? {
        guard let flagIndex = arguments.firstIndex(of: flag), flagIndex + 1 < arguments.count else {
            return nil
        }
        return arguments[flagIndex + 1]
    }
}
