// SPDX-License-Identifier: Apache-2.0
// MarkdownEngines.swift — which engines a document needs, and the scripts that drive them.
//
// The rule this file exists to keep: a Markdown file with no diagram and no formula gets **no
// JavaScript at all**. Injecting 3.5 MB of engine into every README to serve the few that need it
// would be the wrong trade twice over — once for speed, and once because the smallest script surface
// is the one that cannot be got at.
//
// Both engines are injected as `WKUserScript`, not as `<script>` in the document. That keeps the
// document's own Content-Security-Policy free of `script-src`: a user script is installed by the
// application through WebKit's own channel rather than authored by the page, and the page's policy
// governs the page. Measured rather than assumed — see the note on `scriptSourceIsNotNeeded` below.

import Foundation
import WebKit

enum MarkdownEngines {

    /// What a document turns out to need. Both false is the common case and costs nothing.
    struct Needs: Equatable {
        var diagrams = false
        var maths = false
        var any: Bool { diagrams || maths }
    }

    /// What `markdown` needs, from its source.
    ///
    /// Deliberately generous about maths and strict about diagrams. A diagram is a fence naming
    /// `mermaid`, which is unambiguous. Maths is a pair of dollar signs, which is not — `$5 and $6` is
    /// not a formula — so this only decides *whether to load KaTeX*, and KaTeX's own auto-render
    /// decides what is actually a formula, in the page, where it can see that a `$` sits inside a
    /// code block. A false positive here costs an unnecessary injection; a wrong decision there would
    /// cost a mangled sentence.
    static func needs(of markdown: String) -> Needs {
        var needs = Needs()
        var inFence = false
        for raw in markdown.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                // The fence's own info string is where a diagram announces itself.
                if !inFence {
                    let info = line.drop(while: { $0 == "`" || $0 == "~" })
                        .trimmingCharacters(in: .whitespaces).lowercased()
                    if info.hasPrefix("mermaid") { needs.diagrams = true }
                }
                inFence.toggle()
                continue
            }
            if inFence || needs.maths { continue }
            if line.contains("$$") { needs.maths = true; continue }
            // A single-dollar formula has to open and close on the same line to be worth loading for.
            let dollars = line.filter { $0 == "$" }.count
            if dollars >= 2 { needs.maths = true }
        }
        return needs
    }

    /// Install the user scripts `needs` calls for, replacing whatever the previous document needed.
    ///
    /// Replacing matters: the same view is reused for the next file (`ListLoadNext`), and a document
    /// with no diagram must not inherit the engine of the one before it — that would quietly undo the
    /// rule at the top of this file.
    @MainActor
    static func install(_ needs: Needs, into web: WKWebView, configRoot: String) -> [String] {
        let controller = web.configuration.userContentController
        controller.removeAllUserScripts()
        guard needs.any else { return [] }

        var loaded: [String] = []
        if needs.diagrams, let mermaid = MarkdownAssets.mermaidScript(configRoot: configRoot) {
            add(mermaid.js, to: controller)
            add(mermaidBootstrap, to: controller)
            loaded.append("mermaid (\(mermaid.source.description))")
        }
        if needs.maths, let katex = MarkdownAssets.katexScript(configRoot: configRoot),
           let autoRender = MarkdownAssets.locate("auto-render.min.js", configRoot: configRoot),
           let autoRenderJS = try? String(contentsOf: autoRender.url, encoding: .utf8) {
            add(katex.js, to: controller)
            add(autoRenderJS, to: controller)
            add(katexBootstrap(css: katex.css), to: controller)
            loaded.append("katex (\(katex.source.description))")
        }
        return loaded
    }

    private static func add(_ source: String, to controller: WKUserContentController) {
        // At document end: both engines walk the DOM, so they need one. `forMainFrameOnly` because a
        // rendered Markdown page has no frames and a document that smuggles one is not getting an
        // engine.
        controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentEnd,
                                              forMainFrameOnly: true))
    }

    /// Turn every ```` ```mermaid ```` block into its diagram.
    ///
    /// The renderer emits `<pre><code class="language-mermaid">` with the source HTML-escaped, so
    /// `textContent` gives the diagram back exactly as it was written. The `<pre>` is replaced rather
    /// than filled, because a diagram in a scrolling code box is not a diagram.
    ///
    /// `theme: 'base'` with explicit colours rather than Mermaid's own palette: the page follows
    /// `prefers-color-scheme`, and a diagram in Mermaid's default lavender on a dark page is the one
    /// element that does not belong to the document it is in.
    private static let mermaidBootstrap = """
    (function () {
      var blocks = document.querySelectorAll('pre > code.language-mermaid');
      if (!blocks.length || typeof mermaid === 'undefined') { return; }
      var dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      mermaid.initialize({
        startOnLoad: false,
        // Mermaid draws its own "Syntax error in text" figure into the page *as well as* rejecting
        // the promise, so a broken diagram was reported twice — once by us, where the block was and
        // with its source, and once by Mermaid at the bottom of the document. Measured in a picture,
        // which is the only place it was visible.
        suppressErrorRendering: true,
        theme: 'base',
        themeVariables: dark
          ? { background: '#0d1117', primaryColor: '#161b22', primaryTextColor: '#e6edf3',
              primaryBorderColor: '#30363d', lineColor: '#8b949e', secondaryColor: '#161b22',
              tertiaryColor: '#0d1117', fontSize: '14px' }
          : { background: '#ffffff', primaryColor: '#f6f8fa', primaryTextColor: '#1f2328',
              primaryBorderColor: '#d0d7de', lineColor: '#656d76', secondaryColor: '#f6f8fa',
              tertiaryColor: '#ffffff', fontSize: '14px' }
      });
      blocks.forEach(function (code, i) {
        var pre = code.parentElement;
        var holder = document.createElement('div');
        holder.className = 'pc-diagram';
        pre.replaceWith(holder);
        mermaid.render('pc-mermaid-' + i, code.textContent).then(function (result) {
          holder.innerHTML = result.svg;
        }).catch(function (error) {
          // A diagram that will not parse must say so *where it was*, with its source intact — a
          // silently missing figure is the failure that gets reported as "the viewer lost my text".
          var box = document.createElement('pre');
          box.className = 'pc-diagram-error';
          box.textContent = String(error && error.message ? error.message : error)
                            + '\\n\\n' + code.textContent;
          holder.replaceWith(box);
        });
      });
    })();
    """

    /// Set the maths, and bring KaTeX's stylesheet with the fonts already inlined.
    ///
    /// The stylesheet goes in as a `<style>` element built here rather than as a `<link>`: the page's
    /// policy is `style-src 'unsafe-inline'` and has no `link` source at all, and there is nothing to
    /// link *to* — see MarkdownAssets.inlineFonts.
    private static func katexBootstrap(css: String) -> String {
        """
        (function () {
          if (typeof renderMathInElement === 'undefined') { return; }
          var style = document.createElement('style');
          style.textContent = \(jsString(css));
          document.head.appendChild(style);
          renderMathInElement(document.body, {
            delimiters: [
              { left: '$$', right: '$$', display: true },
              { left: '$', right: '$', display: false },
              { left: '\\\\[', right: '\\\\]', display: true },
              { left: '\\\\(', right: '\\\\)', display: false }
            ],
            // Its own defaults already skip pre and code; naming them keeps that true if the
            // defaults ever change, because "a $ inside a code block is not maths" is the half a
            // hand-written scanner gets wrong and the reason this extension is used at all.
            ignoredTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code'],
            throwOnError: false
          });
        })();
        """
    }

    /// A Swift string as a JavaScript string literal.
    private static func jsString(_ s: String) -> String {
        var out = "\""
        for character in s.unicodeScalars {
            switch character {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            // U+2028/9 terminate a JavaScript line inside a string literal, which is a real way for a
            // stylesheet to become a syntax error.
            case "\u{2028}": out += "\\u2028"
            case "\u{2029}": out += "\\u2029"
            default: out.unicodeScalars.append(character)
            }
        }
        return out + "\""
    }
}
