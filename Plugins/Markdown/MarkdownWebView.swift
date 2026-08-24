// SPDX-License-Identifier: Apache-2.0
// MarkdownWebView.swift — the plugin's web view, and the two policies it is created under.
//
// This file carries the security posture that used to live in the host's viewer, and the reason it
// is a *file* rather than a flag: the plugin renders two very different things through WebKit.
//
//   * A page this plugin generated from Markdown. That one may run JavaScript, because Mermaid and
//     KaTeX are JavaScript and there is no other way to draw a diagram or set a formula.
//   * A document somebody else wrote — a .html file on disk. That one may NOT. Opening a downloaded
//     HTML file to look at it must not run its scripts, and the core never did.
//
// Hence two `WKWebViewConfiguration` objects and no switch anywhere. A switch is a thing that gets
// set wrongly once; two constructors cannot be confused at a call site that has to name which one
// it wants.
//
// Both share the network block, which is the property the whole arrangement rests on: a Markdown or
// HTML file is content from somewhere else, and `![](http://…/x.png?who=…)` is a read receipt —
// previewing the file tells that server when it was opened and from which address. It was measured
// going out (F-116), the viewer's comment at the time claimed it could not happen because
// JavaScript was off, and an image element needs no JavaScript.

import AppKit
import WebKit

/// What a web view is about to show, which decides whether scripts may run in it.
enum MarkdownWebPolicy {
    /// A page this plugin generated. Scripts allowed — the rendering engines are scripts.
    case ownDocument
    /// A document from disk that somebody else wrote. Scripts refused.
    case foreignDocument

    var allowsScripts: Bool { self == .ownDocument }
}

/// A `WKWebView` created under `policy`, with the network blocked either way.
///
/// The block is a `WKContentRuleList`, installed before the load rather than beside it — see
/// `load(_:policy:then:)` for why that ordering is not a detail.
func makeMarkdownWebView(policy: MarkdownWebPolicy) -> MarkdownWebContentView {
    let config = WKWebViewConfiguration()
    config.defaultWebpagePreferences.allowsContentJavaScript = policy.allowsScripts
    let web = MarkdownWebContentView(frame: .zero, configuration: config)
    web.policy = policy
    return web
}

/// Every network scheme, blocked, whatever document is being shown.
///
/// One rule per scheme on purpose: WebKit's filter engine rejects `^(https?|wss?)://` with
/// "Disjunctions are not supported yet", and a rule list that does not compile fails *open* — the
/// page would load and the block would exist only in the source. That was measured, not guessed,
/// which is why it is written the long way.
private let noNetworkRules = """
[{"trigger":{"url-filter":"^http://"},"action":{"type":"block"}},
 {"trigger":{"url-filter":"^https://"},"action":{"type":"block"}},
 {"trigger":{"url-filter":"^ws://"},"action":{"type":"block"}},
 {"trigger":{"url-filter":"^wss://"},"action":{"type":"block"}},
 {"trigger":{"url-filter":"^ftp://"},"action":{"type":"block"}},
 {"trigger":{"url-filter":"^ftps://"},"action":{"type":"block"}}]
"""

/// Compiled once per process; compiling is asynchronous and the result is reusable.
@MainActor private var noNetworkList: WKContentRuleList?

/// The identifier the compiled list is stored under. Named for the plugin rather than the viewer,
/// because the store is shared with whatever else on this machine uses one.
private let noNetworkIdentifier = "pc-markdown-plugin-no-network"

/// Install the network block on `web`, then run `load`.
///
/// The load runs *in* the completion rather than beside it. Compiling is asynchronous, so loading
/// alongside it would leave the very first document after launch unprotected — once, quietly, and
/// never in a way a later test would notice.
@MainActor
func loadWithoutNetwork(_ web: WKWebView, then load: @escaping () -> Void) {
    func install(_ list: WKContentRuleList?) {
        web.configuration.userContentController.removeAllContentRuleLists()
        if let list { web.configuration.userContentController.add(list) }
        load()
    }
    if let list = noNetworkList { install(list); return }
    guard let store = WKContentRuleListStore.default() else {
        NSLog("[markdown] no content rule list store — this document is not blocked from the network")
        load(); return
    }
    store.compileContentRuleList(forIdentifier: noNetworkIdentifier,
                                 encodedContentRuleList: noNetworkRules) { list, error in
        if let error {
            NSLog("[markdown] network block failed to compile: %@", error.localizedDescription)
        }
        noNetworkList = list
        install(list)
    }
}

/// The web view the plugin hands the host, which lets the viewer keep its own keys.
///
/// WebKit consumes `keyDown` for everything, so a plugin view that simply forwards to `super`
/// swallows the viewer's mode digits, its find-again keys and anything the host adds later. The
/// host's own web view solved this by asking the controller first; a plugin has no controller to
/// ask, so it does the other half of the same thing: the keys WebKit needs in order to scroll go to
/// WebKit, and every other key is handed up the responder chain, where the viewer's container view
/// is waiting for it.
final class MarkdownWebContentView: WKWebView {
    fileprivate(set) var policy: MarkdownWebPolicy = .foreignDocument

    /// Keys a reader expects to scroll the page with. Everything else belongs to whoever embedded us.
    private static let scrollKeys: Set<UInt16> = [
        49,   // space
        116, 121,  // page up, page down
        115, 119,  // home, end
        123, 124, 125, 126,  // left, right, down, up
    ]

    override func keyDown(with event: NSEvent) {
        if Self.scrollKeys.contains(event.keyCode) {
            super.keyDown(with: event)
            return
        }
        // Deliberately not `super.keyDown` — that *is* WebKit's implementation, and it consumes the
        // event instead of passing it on.
        nextResponder?.keyDown(with: event)
    }
}
