// SPDX-License-Identifier: Apache-2.0
// LaunchOptions.swift - Command-line launch parameters (TC-inspired subset).
//
// Sensible, macOS-adapted parameters (cf. Total Commander's command-line
// parameters):
//   -LeftPath <dir>    initial directory for the left panel   (TC /L=)
//   -RightPath <dir>   initial directory for the right panel  (TC /R=)
//   -ActivePanel L|R   which panel is active on launch        (TC /P=)
//   -Tab               open the path(s) in a new tab          (TC /T)
//   <dir> [<dir>]      bare absolute paths: first = left, second = right
//   -ConfigRoot <dir>  config location (handled by ConfigPaths; skipped here)
//
// Parsing is pure and unit-tested. macOS injects flags like
// `-NSDocumentRevisionsDebugMode YES`; unknown `-flags` consume their following
// value (when it isn't itself a flag) so those don't leak into the positionals.

import Foundation

public struct LaunchOptions: Equatable, Sendable {
    public enum Panel: String, Sendable { case left = "L", right = "R" }

    public var leftPath: String?
    public var rightPath: String?
    public var activePanel: Panel?
    public var openInNewTab: Bool
    /// Path to a debug automation script (`-AutomationScript`). DEBUG builds only.
    public var automationScript: String?
    /// File to open directly in the viewer on launch (`-View <file>`, F-113).
    public var viewFile: String?
    /// Search term to pre-apply in that viewer (`-ViewSearch <term>`, F-113).
    public var viewSearch: String?
    /// Bare (non-flag) arguments, in order — candidate directory paths.
    public var positionals: [String]

    public init(leftPath: String? = nil, rightPath: String? = nil, activePanel: Panel? = nil,
                openInNewTab: Bool = false, automationScript: String? = nil,
                viewFile: String? = nil, viewSearch: String? = nil, positionals: [String] = []) {
        self.leftPath = leftPath
        self.rightPath = rightPath
        self.activePanel = activePanel
        self.openInNewTab = openInNewTab
        self.automationScript = automationScript
        self.viewFile = viewFile
        self.viewSearch = viewSearch
        self.positionals = positionals
    }

    /// The effective left/right directories: explicit flags win, else the first
    /// two positionals fill left then right.
    public var effectiveLeft: String? { leftPath ?? positionals.first }
    public var effectiveRight: String? {
        if let rightPath { return rightPath }
        // If a left flag was given, the first positional is the right dir; else
        // the second positional.
        return leftPath == nil ? (positionals.count > 1 ? positionals[1] : nil) : positionals.first
    }

    /// Flags that take a following value and are consumed (case-insensitive).
    private static let valueFlags: Set<String> = ["-leftpath", "-rightpath", "-activepanel", "-configroot", "-automationscript", "-view", "-viewsearch"]

    public static func parse(_ arguments: [String]) -> LaunchOptions {
        var opts = LaunchOptions()
        var i = 1                       // skip the executable path at index 0
        func nextValue() -> String? {
            guard i + 1 < arguments.count, !arguments[i + 1].hasPrefix("-") else { return nil }
            i += 1
            return arguments[i]
        }
        while i < arguments.count {
            let arg = arguments[i]
            let lower = arg.lowercased()
            if arg.hasPrefix("-") {
                switch lower {
                case "-leftpath": opts.leftPath = nextValue()
                case "-rightpath": opts.rightPath = nextValue()
                case "-activepanel":
                    if let v = nextValue()?.lowercased() {
                        opts.activePanel = (v == "r" || v == "right") ? .right
                                         : (v == "l" || v == "left") ? .left : nil
                    }
                case "-tab": opts.openInNewTab = true
                case "-automationscript": opts.automationScript = nextValue()
                case "-view": opts.viewFile = nextValue()
                case "-viewsearch": opts.viewSearch = nextValue()
                default:
                    // Unknown flag (incl. macOS-injected ones): swallow its value.
                    _ = nextValue()
                }
            } else {
                opts.positionals.append(arg)
            }
            i += 1
        }
        return opts
    }
}
