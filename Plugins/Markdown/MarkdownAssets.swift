// SPDX-License-Identifier: Apache-2.0
// MarkdownAssets.swift — where the rendering engines come from, and how they reach the page.
//
// Two engines ship inside the plugin bundle: Mermaid for ```mermaid blocks and KaTeX for $…$ and
// $$…$$. Both are MIT and both are *files*, which is the whole reason this works offline — the plugin
// fetches nothing, ever, and there is no code here that could.
//
// A reader can put their own copy in `<configRoot>/markdown-assets/` and it wins. That is the
// decompiler plugin's rule for engines, and for the same reason it gives: a file somebody went to the
// trouble of placing there is an explicit instruction, and being unable to update Mermaid without
// waiting for a release of this application would be a poor bargain. Unlike the decompilers, the
// bundled copies mean it works the moment it is switched on.
//
// Nothing is loaded until a document needs it. A Markdown file with no diagram and no formula gets no
// JavaScript at all — which is the useful half of "lazily loaded" without a network in it.

import AppKit
import Foundation

enum MarkdownAssets {

    /// One engine, and where its bytes came from — which the settings page shows, because "it is not
    /// working" and "it is working from a copy you forgot you put there" look identical otherwise.
    enum Source: Equatable {
        case bundle
        case folder(String)

        var description: String {
            switch self {
            case .bundle: return "bundled"
            case .folder(let path): return path
            }
        }
    }

    /// The directory a reader may drop their own engine files into.
    static func overrideDirectory(configRoot: String) -> String {
        (configRoot as NSString).appendingPathComponent("markdown-assets")
    }

    /// The plugin's own `Resources/engines`, or nil in a context with no bundle (a test target
    /// compiles these sources directly, and then only the override directory exists).
    private static var bundledEngines: URL? {
        Bundle(for: MarkdownListerView.self).resourceURL?.appendingPathComponent("engines")
    }

    /// Locate `name` — the reader's copy first, then the bundle's.
    ///
    /// Returns the source as well as the URL: a caller that reports where an engine came from cannot
    /// work it out again afterwards without repeating the search.
    static func locate(_ name: String, configRoot: String) -> (url: URL, source: Source)? {
        let override = URL(fileURLWithPath: overrideDirectory(configRoot: configRoot))
            .appendingPathComponent(name)
        if FileManager.default.isReadableFile(atPath: override.path) {
            return (override, .folder(override.deletingLastPathComponent().path))
        }
        if let bundled = bundledEngines?.appendingPathComponent(name),
           FileManager.default.isReadableFile(atPath: bundled.path) {
            return (bundled, .bundle)
        }
        return nil
    }

    /// The Mermaid engine's source, ready to inject as a user script.
    static func mermaidScript(configRoot: String) -> (js: String, source: Source)? {
        guard let found = locate("mermaid.min.js", configRoot: configRoot),
              let js = try? String(contentsOf: found.url, encoding: .utf8) else { return nil }
        return (js, found.source)
    }

    /// The KaTeX engine: its script, plus its stylesheet with the fonts inlined.
    static func katexScript(configRoot: String) -> (js: String, css: String, source: Source)? {
        guard let script = locate("katex.min.js", configRoot: configRoot),
              let js = try? String(contentsOf: script.url, encoding: .utf8),
              let sheet = locate("katex.min.css", configRoot: configRoot),
              let rawCSS = try? String(contentsOf: sheet.url, encoding: .utf8) else { return nil }
        return (js, inlineFonts(rawCSS, beside: sheet.url), script.source)
    }

    /// `katex.min.css` with every `url(fonts/…woff2)` replaced by a `data:` URI.
    ///
    /// The page is loaded with `loadHTMLString`, so its base URL is the *document's* folder and it has
    /// no read access to this bundle; and its policy is `font-src file: data:`, which admits a `data:`
    /// URI and nothing that would need a network. Inlining is what makes the fonts reachable without
    /// relaxing either — see Vendor/katex/README.md.
    ///
    /// Only woff2, because every WebKit this application runs on takes it. The `.ttf` and `.woff`
    /// urls in each `@font-face` are left as they are and fail silently, which is what a font stack
    /// is for; carrying all three formats would be 800 KB of nothing.
    private static func inlineFonts(_ css: String, beside sheet: URL) -> String {
        let fonts = sheet.deletingLastPathComponent().appendingPathComponent("fonts")
        var out = css
        for name in (try? FileManager.default.contentsOfDirectory(atPath: fonts.path)) ?? []
        where name.hasSuffix(".woff2") {
            guard let data = try? Data(contentsOf: fonts.appendingPathComponent(name)) else { continue }
            out = out.replacingOccurrences(
                of: "url(fonts/\(name))",
                with: "url(data:font/woff2;base64,\(data.base64EncodedString()))")
        }
        return out
    }
}
