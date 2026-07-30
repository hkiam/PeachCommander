// PreviewToggleHandle.swift - A thin, always-visible strip at the window's right
// edge that shows/hides the preview panel. A chevron points left (‹) when the
// panel is collapsed ("click to show") and right (›) when it is open ("click to
// hide"), so the quick toggle is discoverable and matches the edge affordance.

import AppKit
import PCFoundation

final class PreviewToggleHandle: NSView {
    static let width: CGFloat = 16

    var onClick: (() -> Void)?
    var isPanelOpen: Bool = false { didSet { updateChevron() } }

    private let chevron = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.imageScaling = .scaleProportionallyDown
        addSubview(chevron)
        NSLayoutConstraint.activate([
            chevron.centerXAnchor.constraint(equalTo: centerXAnchor),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 10),
            chevron.heightAnchor.constraint(equalToConstant: 22),
        ])
        toolTip = String(localized: "Show/hide the preview panel")
        applyTheme()
        updateChevron()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func mouseDown(with event: NSEvent) { onClick?() }

    private func updateChevron() {
        // Collapsed → ‹ (pull open from the right); open → › (push closed).
        let name = isPanelOpen ? "chevron.right" : "chevron.left"
        chevron.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        chevron.contentTintColor = Theme.current.pathBarText
    }

    func applyTheme() {
        layer?.backgroundColor = Theme.current.pathBarBackground.cgColor
        chevron.contentTintColor = Theme.current.pathBarText
    }

    // A visible separator line on the inner edge.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        Theme.current.pathBarSeparator.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0.5, y: 0))
        path.line(to: NSPoint(x: 0.5, y: bounds.height))
        path.lineWidth = 1
        path.stroke()
    }
}
