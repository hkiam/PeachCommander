// SPDX-License-Identifier: Apache-2.0
// MarkdownSettings.swift — this plugin's own page in the host's Settings window.
//
// Contributed as a view in the "settings" container, the same way the decompiler plugins do it.
// Deliberately not a page built into the host: this plugin is optional and removable, and a host page
// for something that may not be installed is dead UI — while settings written into the host's own
// peachcmd.ini would outlive the plugin that meant something by them. They live in
// `<configRoot>/markdown.ini` instead.
//
// Everything on it is a setting somebody would otherwise have to discover: whether F3 shows the
// rendered page at all, whether diagrams and formulae are drawn, where the engines came from, how
// large a document may be before it is left to the text viewer, and what "Export to PDF…" produces.
//
// The "where from" row is the one that earns its place. "It is not working" and "it is working from a
// copy you put in that folder six months ago and forgot" look identical from the outside, and the
// decompiler plugin learned that the hard way — hence its "Check Engines" button, and hence this.

import AppKit

/// Build the settings pane if `viewId` is this plugin's.
///
/// `@MainActor` because it builds a view; `PcMakeView` is called on the main thread and asserts so.
@MainActor
func makeMarkdownSettingsView(_ viewId: UnsafePointer<CChar>?,
                              _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    guard let viewId, String(cString: viewId) == MarkdownOptions.settingsViewId else { return nil }
    let root = contextValue(services, "configRoot")
    let view = MarkdownSettingsView(configRoot: root)
    return Unmanaged.passRetained(view).toOpaque()
}

func releaseMarkdownSettingsView(_ view: UnsafeMutableRawPointer?) {
    guard let view else { return }
    Unmanaged<MarkdownSettingsView>.fromOpaque(view).release()
}

@MainActor
final class MarkdownSettingsView: NSView {
    private let configRoot: String
    private var options: MarkdownOptions

    private let claim = NSButton(checkboxWithTitle: L("Show .md and .html rendered when opened with F3"),
                                target: nil, action: nil)
    private let diagrams = NSButton(checkboxWithTitle: L("Draw ```mermaid blocks as diagrams"),
                                    target: nil, action: nil)
    private let maths = NSButton(checkboxWithTitle: L("Typeset $…$ and $$…$$ as mathematics"),
                                 target: nil, action: nil)
    private let sizeLimit = NSTextField()
    private let engineStatus = NSTextField(labelWithString: "")

    private let pdfExport = NSButton(checkboxWithTitle: L("Offer “Export to PDF” on .md and .html files"),
                                     target: nil, action: nil)
    private let pdfPaper = NSPopUpButton()
    private let pdfOverwrite = NSButton(checkboxWithTitle: L("Replace an existing PDF of the same name"),
                                        target: nil, action: nil)
    private let pdfReveal = NSButton(checkboxWithTitle: L("Show the new PDF in the panel"),
                                     target: nil, action: nil)

    init(configRoot: String) {
        self.configRoot = configRoot
        self.options = MarkdownOptions.read(configRoot: configRoot)
        super.init(frame: NSRect(x: 0, y: 0, width: 520, height: 500))
        build()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        var rows: [NSView] = []

        rows.append(heading(L("Rendering")))
        for (box, state) in [(claim, options.claimFiles), (diagrams, options.diagrams),
                             (maths, options.maths)] {
            box.state = state ? .on : .off
            box.target = self
            box.action = #selector(optionsChanged)
            rows.append(box)
        }
        claim.toolTip = L("Off: F3 leaves both formats to the built-in text viewer. The outline still works, because it is read from the source.")
        diagrams.toolTip = L("A document with no diagram loads no engine either way; this refuses it for documents that do have one.")

        rows.append(heading(L("Engines")))
        engineStatus.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        engineStatus.textColor = .secondaryLabelColor
        engineStatus.lineBreakMode = .byWordWrapping
        engineStatus.maximumNumberOfLines = 6
        rows.append(engineStatus)
        let folder = NSButton(title: L("Engine Folder…"), target: self, action: #selector(openEngineFolder))
        folder.bezelStyle = .rounded
        folder.toolTip = L("A copy of mermaid.min.js or katex.min.js placed here is used instead of the one inside the plugin. Nothing is ever downloaded.")
        let check = NSButton(title: L("Check Engines"), target: self, action: #selector(checkEngines))
        check.bezelStyle = .rounded
        let buttons = NSStackView(views: [folder, check])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        rows.append(buttons)

        rows.append(heading(L("Limits")))
        sizeLimit.stringValue = String(options.maxSizeMB)
        sizeLimit.alignment = .right
        sizeLimit.target = self
        sizeLimit.action = #selector(optionsChanged)
        rows.append(labelled(L("Render files up to (MB):"), sizeLimit, width: 60))

        rows.append(heading(L("PDF")))
        pdfExport.state = options.pdfExport ? .on : .off
        pdfExport.target = self
        pdfExport.action = #selector(optionsChanged)
        // Says what the switch can and cannot do, because the menu entry stays where it is either
        // way: the host builds a plugin's menus from the manifest without loading the plugin, so
        // nothing in this file is readable at the moment that menu is built. See MarkdownOptions.
        pdfExport.toolTip = L("The menu entry is built from the plugin's manifest and stays visible; switched off, the command declines and says so.")
        rows.append(pdfExport)
        // Paper names are the same word everywhere, so they are not translated.
        pdfPaper.addItems(withTitles: ["A4", "US Letter"])
        pdfPaper.selectItem(at: options.pdfPaper == .letter ? 1 : 0)
        pdfPaper.target = self
        pdfPaper.action = #selector(optionsChanged)
        rows.append(labelled(L("Paper:"), pdfPaper, width: 120))
        for (box, state) in [(pdfOverwrite, options.pdfOverwrite), (pdfReveal, options.pdfReveal)] {
            box.state = state ? .on : .off
            box.target = self
            box.action = #selector(optionsChanged)
            rows.append(box)
        }
        pdfOverwrite.toolTip = L("Off, a second export is written beside the first as “name 2.pdf” instead of replacing it.")

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])
        refreshEngineStatus()
    }

    private func heading(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        return label
    }

    private func labelled(_ text: String, _ control: NSView, width: CGFloat) -> NSStackView {
        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(equalToConstant: width).isActive = true
        let row = NSStackView(views: [NSTextField(labelWithString: text), control])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    /// Name each engine, its version if it can be told, and **where it came from**.
    private func refreshEngineStatus() {
        var lines: [String] = []
        for (label, file) in [("Mermaid", "mermaid.min.js"), ("KaTeX", "katex.min.js")] {
            if let found = MarkdownAssets.locate(file, configRoot: configRoot) {
                let size = MarkdownListerView.fileSize(of: found.url.path)
                lines.append(String(format: L("%@: %@ — %@ KB"), label, found.source.description,
                                    String(size / 1024)))
            } else {
                lines.append(String(format: L("%@: not found"), label))
            }
        }
        engineStatus.stringValue = lines.joined(separator: "\n")
    }

    @objc private func optionsChanged() {
        options.claimFiles = claim.state == .on
        options.diagrams = diagrams.state == .on
        options.maths = maths.state == .on
        options.maxSizeMB = max(1, Int(sizeLimit.stringValue) ?? options.maxSizeMB)
        sizeLimit.stringValue = String(options.maxSizeMB)
        options.pdfExport = pdfExport.state == .on
        options.pdfPaper = pdfPaper.indexOfSelectedItem == 1 ? .letter : .a4
        options.pdfOverwrite = pdfOverwrite.state == .on
        options.pdfReveal = pdfReveal.state == .on
        options.write(configRoot: configRoot)
    }

    @objc private func openEngineFolder() {
        let path = MarkdownAssets.overrideDirectory(configRoot: configRoot)
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc private func checkEngines() {
        refreshEngineStatus()
    }
}
