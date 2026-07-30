// SPDX-License-Identifier: Apache-2.0
// logconfig.swift — persisted configuration for the Log Viewer plugin.
//
// Settings (per-level colours + display options; log formats are added in a later
// phase) live in a JSON file under the host's config root. The config root is
// resolved from the `-ConfigRoot <path>` argument or the PEACHCMD_CONFIG_ROOT
// environment variable first, so an isolated test/dev root is honoured and the
// user's real configuration is never touched; production falls back to the
// standard Application Support location. This mirrors the SystemMonitor plugin's
// ConfigStore convention (never UserDefaults, which ignores -ConfigRoot).

import AppKit

struct LogConfig: Codable {
    /// LogLevel.rawValue → "#RRGGBB". An absent entry means "use the built-in
    /// dynamic default" (which adapts to light/dark), so custom colours are opt-in.
    var levelColors: [String: String]
    var showLineNumbers: Bool
    var wordWrap: Bool
    /// User-defined formats (built-in formats live in code, see LogFormat.builtins).
    var customFormats: [LogFormat]

    init(levelColors: [String: String] = [:], showLineNumbers: Bool = true,
         wordWrap: Bool = false, customFormats: [LogFormat] = []) {
        self.levelColors = levelColors
        self.showLineNumbers = showLineNumbers
        self.wordWrap = wordWrap
        self.customFormats = customFormats
    }

    // Tolerate missing keys (older/newer config files) by falling back to defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        levelColors = try c.decodeIfPresent([String: String].self, forKey: .levelColors) ?? [:]
        showLineNumbers = try c.decodeIfPresent(Bool.self, forKey: .showLineNumbers) ?? true
        wordWrap = try c.decodeIfPresent(Bool.self, forKey: .wordWrap) ?? false
        customFormats = try c.decodeIfPresent([LogFormat].self, forKey: .customFormats) ?? []
    }

    /// Built-in formats followed by the user's custom ones.
    var allFormats: [LogFormat] { LogFormat.builtins + customFormats }
}

extension Notification.Name {
    /// Posted (main thread) whenever the persisted LogConfig changes so open viewer
    /// windows can refresh their rendering.
    static let logViewerConfigChanged = Notification.Name("PCLogViewerConfigChanged")
}

final class LogConfigStore {
    static let shared = LogConfigStore()
    private(set) var config: LogConfig

    private let url: URL = {
        let root: URL
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-ConfigRoot"), i + 1 < args.count {
            root = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        } else if let env = ProcessInfo.processInfo.environment["PEACHCMD_CONFIG_ROOT"], !env.isEmpty {
            root = URL(fileURLWithPath: env, isDirectory: true)
        } else {
            root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("PeachCommander", isDirectory: true)
        }
        let base = root.appendingPathComponent("logviewer", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("config.json")
    }()

    private init() {
        if let data = try? Data(contentsOf: url), let c = try? JSONDecoder().decode(LogConfig.self, from: data) {
            config = c
        } else {
            config = LogConfig()
        }
    }

    func update(_ mutate: (inout LogConfig) -> Void) {
        mutate(&config)
        try? JSONEncoder().encode(config).write(to: url, options: .atomic)
        NotificationCenter.default.post(name: .logViewerConfigChanged, object: nil)
    }
}

// MARK: - Shared level styling (used by both the viewer window and the settings pane)

enum LogStyle {
    /// Localized display name for a level (checkbox labels; uppercased for the Level
    /// column). The raw values ("error"…) are internal/parsing tokens, not shown.
    static func displayName(_ level: LogLevel) -> String {
        switch level {
        case .error: return L("Error")
        case .warning: return L("Warning")
        case .info: return L("Info")
        case .debug: return L("Debug")
        case .trace: return L("Trace")
        case .unknown: return L("Unknown")
        }
    }

    /// Built-in dynamic default colour (adapts to light/dark).
    static func defaultColor(_ level: LogLevel) -> NSColor {
        switch level {
        case .error: return .systemRed
        case .warning: return .systemOrange
        case .info: return .labelColor
        case .debug: return .secondaryLabelColor
        case .trace: return .tertiaryLabelColor
        case .unknown: return .labelColor
        }
    }

    /// Effective colour for a level: the user's configured override, else the default.
    static func color(_ level: LogLevel, config: LogConfig) -> NSColor {
        if let hex = config.levelColors[level.rawValue], let c = NSColor(hexString: hex) { return c }
        return defaultColor(level)
    }

    /// Levels in display order.
    static let ordered: [LogLevel] = [.error, .warning, .info, .debug, .trace, .unknown]
}

// MARK: - Colour helpers

extension NSColor {
    /// Parse "#RRGGBB" / "RRGGBB" as an sRGB colour.
    convenience init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255.0,
                  green: CGFloat((v >> 8) & 0xFF) / 255.0,
                  blue: CGFloat(v & 0xFF) / 255.0, alpha: 1.0)
    }

    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "#000000" }
        return String(format: "#%02X%02X%02X",
                      Int(round(c.redComponent * 255)),
                      Int(round(c.greenComponent * 255)),
                      Int(round(c.blueComponent * 255)))
    }
}
