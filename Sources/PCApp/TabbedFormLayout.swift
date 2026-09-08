// SPDX-License-Identifier: Apache-2.0
// TabbedFormLayout.swift - Building a tabbed criteria form, with the constraint priorities that work.
//
// Lifted out of FindFilesWindowController when a second window needed the same shape (the directory
// synchronisation's filter sheet). Copying it was the alternative, and the reason not to is not tidiness:
// the priorities in here are measured, not chosen. `docs/metadata/layout-baseline.json` counts AppKit's
// reported constraint conflicts per screen and the numbers may only go down — `find-files` sits at 0 —
// so a second tab builder with subtly different priorities is a red build rather than a cosmetic
// difference. The comments came across word for word, because what they record is what was tried.
//
// One instance per window: it accumulates the row labels whose column is measured at the end, and the
// tab stacks the tab view's minimum height is measured from.

import AppKit
import PCFoundation

final class TabbedFormLayout {

    /// The labels of the "label: control" rows, so their column can be measured (see `alignRowLabels`).
    ///
    /// Readable from outside because the automation report measures truncation from them: whether a
    /// label fits is a comparison of its frame against its fitting size, which no screenshot of one
    /// language could show.
    private(set) var rowLabels: [NSTextField] = []

    /// The stacks inside the tabs, so the tab view's minimum height can be *measured* rather than
    /// guessed. Two guesses in a row got it wrong: 250 clipped the content silently, and 320 turned
    /// that into a reported conflict on every layout pass once the tab gained a bottom bound.
    private(set) var tabStacks: [NSStackView] = []

    /// What NSTabView spends on its tab strip and border, on top of the tallest page's own height.
    /// Measured, not chosen.
    static let tabChromeHeight: CGFloat = 34

    /// The minimum height the tab view needs: the tallest page's own fitting height plus the chrome.
    ///
    /// At least tall enough for the tallest tab, never exactly that — the caller uses it as a lower
    /// bound. A tab pinned to its measured height only moved the problem: the stack's own minimum
    /// spacings then no longer fit, and AppKit reported the whole set on every layout pass.
    func measuredTabHeight(fallback: CGFloat = 300) -> CGFloat {
        (tabStacks.map(\.fittingSize.height).max() ?? fallback) + Self.tabChromeHeight
    }

    /// Activate a width the layout should honour *if it can*.
    ///
    /// Every width in such a dialog is a preference about how wide a control looks, not a fact about
    /// the world — and during setup the page it sits in has no width at all, so as required rules they
    /// cannot hold and AppKit reports the row. At 999 the rows still get the shape they ask for and a
    /// zero-width page costs nothing. Measured: this and the tab pages' bottom bound together took the
    /// Find Files dialog from 37 reported conflicts to 12.
    func preferWidth(_ view: NSView, exactly: CGFloat? = nil, atLeast: CGFloat? = nil) {
        for constraint in [exactly.map { view.widthAnchor.constraint(equalToConstant: $0) },
                           atLeast.map { view.widthAnchor.constraint(greaterThanOrEqualToConstant: $0) }]
        .compactMap({ $0 }) {
            constraint.priority = .init(999)
            constraint.isActive = true
        }
    }

    /// One width for every "label: control" row, measured from the longest label rather than chosen.
    ///
    /// 90 pt was enough for "Search for:" in English and is not enough for "Szöveg keresése:" — and a
    /// truncated label in a dialog whose whole subject is text is the kind of thing only a Hungarian user
    /// would ever report. The labels report what they need; the widest one sets the column, so the rows
    /// stay aligned in all nineteen languages.
    func alignRowLabels() {
        let widest = rowLabels.map(\.fittingSize.width).max() ?? 90
        for label in rowLabels { preferWidth(label, exactly: max(90, widest.rounded(.up))) }
    }

    /// A horizontal stack row of leading-aligned controls.
    func hStack(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .horizontal
        s.alignment = .centerY
        s.spacing = spacing
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }

    /// A "label: control" row: a right-aligned label plus the control. The label's width is settled once
    /// all of them exist, by `alignRowLabels`.
    func labeledField(_ title: String, _ control: NSView, controlMinWidth: CGFloat = 300) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = Fonts.system13
        label.alignment = .right
        rowLabels.append(label)
        preferWidth(control, atLeast: controlMinWidth)
        return hStack([label, control], spacing: 8)
    }

    /// A dimmed, wrapping explanatory label used at the top of a sparse tab.
    func hintLabel(_ text: String) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: text)
        l.font = NSFont.systemFont(ofSize: 11)
        l.textColor = .secondaryLabelColor
        l.widthAnchor.constraint(lessThanOrEqualToConstant: 560).isActive = true
        return l
    }

    /// Build a tab page: a top-anchored vertical stack of `rows` inside a container.
    func makeTab(_ title: String, rows: [NSView]) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: title)
        item.label = title
        let page = NSView()
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(stack)
        let stackBottom = stack.bottomAnchor.constraint(lessThanOrEqualTo: page.bottomAnchor)
        stackBottom.priority = .init(999)
        // Same reasoning one dimension over: a page that is not the visible tab has no width either,
        // and the rows inside carry the stack's own minimum spacings, which cannot be lowered from
        // out here. Pinning the leading edge as a rule made those minimums the reported conflict.
        let stackLeading = stack.leadingAnchor.constraint(equalTo: page.leadingAnchor)
        stackLeading.priority = .init(999)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: page.topAnchor),
            stackLeading,
            stack.trailingAnchor.constraint(lessThanOrEqualTo: page.trailingAnchor),
            // An advisory bound, not a rule. Without it a tab whose rows outgrow its height drew over
            // whatever was below and nothing reported it; required, it became the loudest conflict in
            // the app, because a tab page that is not the visible one has height *zero* until it is
            // shown, and no stack fits in nothing. Measured: the visible page was 380 pt with a stack
            // needing 250, while the three hidden ones were 0 pt with stacks needing 154 and 76 —
            // there was never a shortage of room, only a constraint applied to pages that had no size
            // yet. Same shape as the preview panel's `width == 0`.
            //
            // At 999 it yields on a zero-height page and still shapes the layout everywhere else.
            // Real overflow is caught by the regression harness's screenshots, which is where a human
            // would notice it anyway.
            stackBottom,
        ])
        tabStacks.append(stack)
        item.view = page
        return item
    }
}
