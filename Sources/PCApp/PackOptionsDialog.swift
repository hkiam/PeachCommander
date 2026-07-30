// PackOptionsDialog.swift - Choose archive format + AES password + split size
// when packing (F-132/F-136). Emits an archive name and PackOptions.

import AppKit
import PCArchive
import PCFoundation

@MainActor
final class PackOptionsDialog: NSWindowController {
    /// Fired on "Pack" with the final archive name (extension applied) and options.
    var onPack: ((_ archiveName: String, _ options: PackOptions) -> Void)?
    /// Fired on "Pack" when a packer-plugin format is chosen (F-137): the archive
    /// name (plugin extension applied) and that extension.
    var onPackPlugin: ((_ archiveName: String, _ ext: String) -> Void)?

    /// Extra formats provided by enabled PCX packer plugins (extension + label).
    private let pluginFormats: [(ext: String, label: String)]

    private let nameField = NSTextField()
    private let formatPopup = NSPopUpButton()
    private let levelPopup = NSPopUpButton()
    private let passwordField = NSSecureTextField()
    private let splitField = NSTextField()
    private let defaultFormat: PackFormat
    private let defaultLevel: Int

    /// Format order shown in the popup, paired with a human label.
    private let formats: [(PackFormat, String)] = [
        (.zip, "Zip"), (.sevenZip, "7z"), (.tar, "Tar"),
        (.tarGz, "Tar + gzip (.tar.gz)"), (.tarBz2, "Tar + bzip2 (.tar.bz2)"),
        (.tarXz, "Tar + xz (.tar.xz)"), (.rar, "RAR"),
    ]

    /// Compression levels offered, paired with the underlying 0…9 value.
    private let levels: [(Int, String)] = [
        (0, String(localized: "Store (no compression)")),
        (1, String(localized: "Fast")),
        (5, String(localized: "Normal")),
        (9, String(localized: "Maximum")),
    ]

    init(defaultBaseName: String, defaultFormat: PackFormat = .zip, defaultLevel: Int = 5,
         pluginFormats: [(ext: String, label: String)] = []) {
        self.defaultFormat = defaultFormat
        self.defaultLevel = defaultLevel
        self.pluginFormats = pluginFormats
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 250),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = String(localized: "Pack Files")
        window.center()
        super.init(window: window)
        build(defaultBaseName: defaultBaseName)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func runModal() { if let window { NSApp.runModal(for: window); window.orderOut(nil) } }

    private func build(defaultBaseName: String) {
        guard let content = window?.contentView else { return }
        nameField.stringValue = defaultBaseName
        for (_, label) in formats { formatPopup.addItem(withTitle: label) }
        for pf in pluginFormats { formatPopup.addItem(withTitle: pf.label) }   // F-137: plugin formats
        if let idx = formats.firstIndex(where: { $0.0 == defaultFormat }) { formatPopup.selectItem(at: idx) }
        formatPopup.target = self
        formatPopup.action = #selector(formatChanged)
        for (_, label) in levels { levelPopup.addItem(withTitle: label) }
        // Select the configured default level (nearest listed value).
        let levelIdx = levels.firstIndex { $0.0 == defaultLevel }
            ?? levels.enumerated().min { abs($0.element.0 - defaultLevel) < abs($1.element.0 - defaultLevel) }?.offset
            ?? 2
        levelPopup.selectItem(at: levelIdx)
        splitField.placeholderString = String(localized: "e.g. 100M (empty = one file)")

        func label(_ s: String) -> NSTextField {
            let l = NSTextField(labelWithString: s); l.alignment = .right; return l
        }
        let rows: [(String, NSView)] = [
            (String(localized: "Name:"), nameField),
            (String(localized: "Format:"), formatPopup),
            (String(localized: "Compression:"), levelPopup),
            (String(localized: "Password:"), passwordField),
            (String(localized: "Split size:"), splitField),
        ]
        let grid = NSGridView(numberOfColumns: 2, rows: rows.count)
        for (i, row) in rows.enumerated() {
            grid.cell(atColumnIndex: 0, rowIndex: i).contentView = label(row.0)
            grid.cell(atColumnIndex: 1, rowIndex: i).contentView = row.1
            row.1.translatesAutoresizingMaskIntoConstraints = false
            row.1.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        }
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(grid)

        let pack = NSButton(title: String(localized: "Pack"), target: self, action: #selector(packAction))
        pack.bezelStyle = .rounded; pack.keyEquivalent = "\r"
        let cancel = NSButton(title: String(localized: "Cancel"), target: self, action: #selector(cancelAction))
        cancel.bezelStyle = .rounded; cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, pack]); buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: grid.bottomAnchor, constant: 16),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])
        updatePasswordEnabled()
    }

    /// The chosen native format, or nil when a plugin format is selected (F-137).
    private var selectedFormat: PackFormat? {
        let idx = formatPopup.indexOfSelectedItem
        return formats.indices.contains(idx) ? formats[idx].0 : nil
    }

    /// The chosen plugin format (ext, label), or nil for a native format.
    private var selectedPluginFormat: (ext: String, label: String)? {
        let idx = formatPopup.indexOfSelectedItem - formats.count
        return pluginFormats.indices.contains(idx) ? pluginFormats[idx] : nil
    }

    @objc private func formatChanged() { updatePasswordEnabled() }

    /// Grey out password/split for formats that don't support them (plugin formats
    /// take no host-side compression/encryption options).
    private func updatePasswordEnabled() {
        let fmt = selectedFormat
        passwordField.isEnabled = fmt?.supportsEncryption ?? false
        splitField.isEnabled = fmt?.supportsSplit ?? false
        levelPopup.isEnabled = fmt != nil && fmt != .tar   // plain tar is uncompressed
    }

    @objc private func packAction() {
        let base = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !base.isEmpty else { NSSound.beep(); return }
        // Strip any user-typed extension so we can append the format's own.
        let stem = (base as NSString).pathExtension.isEmpty ? base : (base as NSString).deletingPathExtension
        // A packer-plugin format was chosen (F-137): route to the plugin.
        if let pf = selectedPluginFormat {
            onPackPlugin?("\(stem).\(pf.ext)", pf.ext)
            NSApp.stopModal()
            return
        }
        let format = selectedFormat ?? .zip
        let password = passwordField.stringValue.isEmpty ? nil : passwordField.stringValue
        let split = ByteSize.parse(splitField.stringValue)
        let archiveName = "\(stem).\(format.fileExtension)"
        let level = levels[levelPopup.indexOfSelectedItem].0
        onPack?(archiveName, PackOptions(format: format, password: password, splitSize: split, level: level))
        NSApp.stopModal()
    }

    @objc private func cancelAction() { NSApp.stopModal() }
}
