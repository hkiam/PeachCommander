// SPDX-License-Identifier: Apache-2.0
// TypeColorsWindowController.swift - GUI editor for by-file-type row colours (F-032).
//
// The panel colours files by wildcard mask through a `Display.TypeColors` config
// string of the form "mask=RRGGBB,mask=RRGGBB". This dialog edits that string
// visually: one row per rule (a mask field + a colour well) with add/remove, and
// serialises back to the same string on Done.

import AppKit
import PCFoundation

final class TypeColorsWindowController: NSWindowController {
    /// Called on Done with the serialized "mask=RRGGBB,…" config string.
    var onSave: ((String) -> Void)?

    private let rowsStack = FlippedStackView()   // documentView: must be top-origin
    private var rowViews: [(mask: NSTextField, well: NSColorWell)] = []

    init(config: String) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = String(localized: "File-Type Colors")
        super.init(window: window)
        buildUI()
        for (mask, hex) in Self.parse(config) { addRow(mask: mask, hex: hex) }
        if rowViews.isEmpty { addRow(mask: "*.txt", hex: "cc0000") }   // a starter example
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Parse "mask=RRGGBB,…" into (mask, hex) pairs.
    private static func parse(_ config: String) -> [(String, String)] {
        config.split(separator: ",").compactMap { rule in
            guard let eq = rule.firstIndex(of: "=") else { return nil }
            let mask = rule[rule.startIndex..<eq].trimmingCharacters(in: .whitespaces)
            let hex = rule[rule.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            return mask.isEmpty ? nil : (mask, hex)
        }
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let heading = NSTextField(labelWithString: String(localized: "Colour files whose name matches a mask (e.g. *.zip):"))
        heading.font = .boldSystemFont(ofSize: 12)
        heading.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(heading)

        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 6
        rowsStack.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = rowsStack   // the stack's intrinsic height drives scrolling
        content.addSubview(scroll)

        let add = NSButton(title: String(localized: "Add Rule"), target: self, action: #selector(addRuleTapped))
        add.bezelStyle = .rounded
        add.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(add)

        let done = NSButton(title: String(localized: "Done"), target: self, action: #selector(saveAndClose))
        done.bezelStyle = .rounded; done.keyEquivalent = "\r"
        let cancel = NSButton(title: String(localized: "Cancel"), target: self, action: #selector(cancel))
        cancel.bezelStyle = .rounded; cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, done]); buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)

        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            heading.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scroll.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            scroll.bottomAnchor.constraint(equalTo: add.topAnchor, constant: -10),
            rowsStack.widthAnchor.constraint(equalTo: scroll.widthAnchor),   // match width; height is intrinsic
            add.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            add.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -10),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
        ])
    }

    private func addRow(mask: String, hex: String) {
        let maskField = NSTextField(string: mask)
        maskField.placeholderString = "*.ext"
        maskField.widthAnchor.constraint(equalToConstant: 200).isActive = true
        let well = NSColorWell()
        well.color = Self.color(fromHex: hex) ?? .systemRed
        well.widthAnchor.constraint(equalToConstant: 44).isActive = true
        let remove = NSButton(title: "–", target: self, action: #selector(removeRow(_:)))
        remove.bezelStyle = .rounded
        let row = NSStackView(views: [maskField, well, remove])
        row.spacing = 8
        remove.tag = rowViews.count
        rowsStack.addArrangedSubview(row)
        rowViews.append((maskField, well))
    }

    @objc private func addRuleTapped() { addRow(mask: "", hex: "3399ff") }

    @objc private func removeRow(_ sender: NSButton) {
        // Rebuild from the surviving fields (tags shift, so match by the sender's row).
        guard let row = sender.superview as? NSStackView else { return }
        if let idx = rowsStack.arrangedSubviews.firstIndex(of: row) {
            rowsStack.removeArrangedSubview(row); row.removeFromSuperview()
            if rowViews.indices.contains(idx) { rowViews.remove(at: idx) }
        }
    }

    @objc private func saveAndClose() {
        window?.makeFirstResponder(nil)
        let parts = rowViews.compactMap { entry -> String? in
            let mask = entry.mask.stringValue.trimmingCharacters(in: .whitespaces)
            guard !mask.isEmpty else { return nil }
            return "\(mask)=\(Self.hex(from: entry.well.color))"
        }
        onSave?(parts.joined(separator: ","))
        close()
    }

    @objc private func cancel() { close() }

    // MARK: - Colour <-> hex

    private static func color(fromHex hex: String) -> NSColor? {
        var s = hex; if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    private static func hex(from color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = Int((c.redComponent * 255).rounded()), g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        return String(format: "%02x%02x%02x", r, g, b)
    }
}
