// SPDX-License-Identifier: Apache-2.0
// PropertiesDialog.swift - Read-only "Properties" dialog (Alt+Enter, I03-T07)
//
// Renders a `PCVFS.FileProperties` value in a simple label/value grid, TC-style.
// Editing (permissions/dates) is out of scope here — see docs/iterations/I17,I18.
// The orchestrator wires the Alt+Enter key to this dialog separately.

import AppKit
import CoreServices
import PCFoundation
import PCVFS

/// Read-only properties panel for a single file/directory/symlink.
final class PropertiesDialog: NSWindowController {
    private let logger = PCFoundationLogger.logger

    private let properties: FileProperties

    /// Builds the dialog for the given, already-read properties snapshot.
    init(properties: FileProperties) {
        self.properties = properties

        let window = NSWindow(
            contentRect: NSMakeRect(0, 0, 420, 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Properties", comment: "Properties dialog window title")
        window.center()
        window.level = .modalPanel

        super.init(window: window)

        setupDialog()
        logger.info("PropertiesDialog opened for \(properties.path, privacy: .public)")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupDialog() {
        guard let window = window else { return }

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        let grid = NSStackView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 8
        contentView.addSubview(grid)

        for (label, value) in rows() {
            grid.addArrangedSubview(makeRow(label: label, value: value))
        }

        let okButton = NSButton()
        okButton.title = String(localized: "OK", comment: "Properties dialog close button")
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        okButton.action = #selector(closeAction)
        okButton.target = self

        // Invisible (not `isHidden`, so it still participates in key-equivalent
        // dispatch) zero-size button so Esc closes the dialog like the OK button.
        let escButton = NSButton()
        escButton.translatesAutoresizingMaskIntoConstraints = false
        escButton.alphaValue = 0
        escButton.keyEquivalent = "\u{1B}"
        escButton.action = #selector(closeAction)
        escButton.target = self
        contentView.addSubview(escButton)
        NSLayoutConstraint.activate([
            escButton.widthAnchor.constraint(equalToConstant: 0),
            escButton.heightAnchor.constraint(equalToConstant: 0),
            escButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            escButton.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])

        let buttonStack = NSStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.distribution = .equalSpacing
        buttonStack.addArrangedSubview(NSView()) // spacer to push OK to the right
        buttonStack.addArrangedSubview(okButton)
        contentView.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),

            buttonStack.topAnchor.constraint(greaterThanOrEqualTo: grid.bottomAnchor, constant: 20),
            buttonStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
    }

    /// Builds the ordered (label, value) rows to display.
    private func rows() -> [(String, String)] {
        var result: [(String, String)] = []

        result.append((String(localized: "Name:", comment: "Properties dialog field label"), properties.name))
        result.append((String(localized: "Kind:", comment: "Properties dialog field label"), properties.kindDescription))
        result.append((String(localized: "Path:", comment: "Properties dialog field label"), properties.path))
        result.append((String(localized: "Size:", comment: "Properties dialog field label"), properties.sizeText))
        result.append((String(localized: "Permissions:", comment: "Properties dialog field label"), properties.permissionsText))

        if let modified = properties.modified {
            result.append((String(localized: "Modified:", comment: "Properties dialog field label"), Self.dateFormatter.string(from: modified)))
        }
        if let created = properties.created {
            result.append((String(localized: "Created:", comment: "Properties dialog field label"), Self.dateFormatter.string(from: created)))
        }
        if let owner = properties.ownerName {
            result.append((String(localized: "Owner:", comment: "Properties dialog field label"), owner))
        }
        if let group = properties.groupName {
            result.append((String(localized: "Group:", comment: "Properties dialog field label"), group))
        }
        if properties.isSymbolicLink, let target = properties.symlinkTarget {
            result.append((String(localized: "→ Target:", comment: "Properties dialog field label for symlink target"), target))
        }

        result.append(contentsOf: spotlightRows())
        return result
    }

    /// Extra rows from Spotlight metadata (kMDItem*): localized kind, image
    /// dimensions, media duration, download source. Only non-empty rows are shown.
    private func spotlightRows() -> [(String, String)] {
        guard !properties.isSymbolicLink,
              let item = MDItemCreate(kCFAllocatorDefault, properties.path as CFString) else { return [] }
        func string(_ attr: CFString) -> String? { MDItemCopyAttribute(item, attr) as? String }
        func number(_ attr: CFString) -> Double? { (MDItemCopyAttribute(item, attr) as? NSNumber)?.doubleValue }
        var out: [(String, String)] = []
        if let kind = string(kMDItemKind) {
            out.append((String(localized: "Content type:"), kind))
        }
        if let w = number(kMDItemPixelWidth), let h = number(kMDItemPixelHeight), w > 0, h > 0 {
            out.append((String(localized: "Dimensions:"), "\(Int(w)) × \(Int(h))"))
        }
        if let dur = number(kMDItemDurationSeconds), dur > 0 {
            let s = Int(dur.rounded())
            out.append((String(localized: "Duration:"), String(format: "%d:%02d", s / 60, s % 60)))
        }
        if let wheres = MDItemCopyAttribute(item, kMDItemWhereFroms) as? [String],
           let first = wheres.first(where: { !$0.isEmpty }) {
            out.append((String(localized: "Downloaded from:"), first))
        }
        return out
    }

    private func makeRow(label: String, value: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8

        let labelField = NSTextField(labelWithString: label)
        labelField.font = Fonts.bold13
        labelField.alignment = .right
        labelField.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let valueField = NSTextField(labelWithString: value)
        valueField.font = Fonts.system13
        valueField.lineBreakMode = .byTruncatingMiddle
        valueField.maximumNumberOfLines = 1

        row.addArrangedSubview(labelField)
        row.addArrangedSubview(valueField)

        return row
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    @objc private func closeAction() {
        close()
    }
}
