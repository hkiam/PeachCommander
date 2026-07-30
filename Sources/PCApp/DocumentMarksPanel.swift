// DocumentMarksPanel.swift - Composition object that owns the docked marks
// panel and the horizontal split with the content view, shared by the editor
// and the viewer (previously each carried an identical copy of this wiring,
// the show/hide/close logic and the NSSplitViewDelegate). The window controller
// embeds `splitView` in its layout, implements `MarksPanelHost`, and supplies an
// `onClearAll` closure for the panel's Close button.

import AppKit

@MainActor
final class DocumentMarksPanel: NSObject, NSSplitViewDelegate {
    let splitView = NSSplitView()
    let panel = MarksPanelView()
    private let defaultHeight: CGFloat = 190
    private let minPane: CGFloat = 80

    /// Called by the panel's Close (×) button: clear every mark, then collapse.
    var onClearAll: (() -> Void)?

    /// - Parameters:
    ///   - content: the window's content scroll view (top pane).
    ///   - host: the controller that maps its mark backend for the panel.
    init(content: NSView, host: MarksPanelHost) {
        super.init()
        content.translatesAutoresizingMaskIntoConstraints = true
        panel.translatesAutoresizingMaskIntoConstraints = true
        panel.host = host
        panel.onHide = { [weak self] in self?.hide() }
        panel.onClose = { [weak self] in self?.onClearAll?(); self?.hide() }
        splitView.isVertical = false
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.addArrangedSubview(content)
        splitView.addArrangedSubview(panel)
        panel.isHidden = true
    }

    var isHidden: Bool { panel.isHidden }
    func reload() { panel.reload() }

    /// Reveal the panel at its default height (idempotent).
    func show() {
        panel.reload()
        guard panel.isHidden else { return }
        panel.isHidden = false
        splitView.layoutSubtreeIfNeeded()
        let h = splitView.bounds.height
        if h > 0 { splitView.setPosition(max(minPane, h - defaultHeight), ofDividerAt: 0) }
    }

    /// Collapse the panel, keeping the marks.
    func hide() { panel.isHidden = true; splitView.layoutSubtreeIfNeeded() }

    func toggle() { isHidden ? show() : hide() }

    // MARK: - NSSplitViewDelegate (content keeps ≥ minPane; panel keeps ≥ minPane)

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMin: CGFloat, ofDividerAt i: Int) -> CGFloat {
        minPane
    }
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMax: CGFloat, ofDividerAt i: Int) -> CGFloat {
        max(minPane, splitView.bounds.height - minPane)
    }
    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        subview === panel
    }
}
