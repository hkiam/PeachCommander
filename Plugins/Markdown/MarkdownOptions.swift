// SPDX-License-Identifier: Apache-2.0
// MarkdownOptions.swift — what the reader chose, and where it is kept.
//
// `<configRoot>/markdown.ini`, not the host's `peachcmd.ini`, for the reason the decompiler plugin's
// settings give: this plugin is removable, and a setting written into the host's own file would
// outlive the plugin that meant something by it. An INI because that is what every other
// configuration in this application is, hand-editable included.
//
// Read on every use rather than cached. Each read is one small file, the settings pane writes it, and
// a cache would mean a scripted run or a hand edit taking effect only after a restart — which the
// decompiler plugin explicitly avoided for its detect string, for the same reason.

import Foundation

/// The paper an exported PDF is laid out on.
///
/// Two sizes rather than the system's whole list: the page is a document, not a form, and A4 or
/// Letter is the entire question anyone has ever had about it. Sizes are in points (72 to the inch),
/// which is what `NSPrintInfo` wants and what keeps this file free of AppKit — it is compiled into
/// the test bundle too.
enum MarkdownPaper: String {
    case a4
    case letter

    var size: CGSize {
        switch self {
        case .a4: return CGSize(width: 595, height: 842)
        case .letter: return CGSize(width: 612, height: 792)
        }
    }
}

struct MarkdownOptions {
    /// Whether F3 shows the rendered page at all. Off, the plugin's detect string comes back empty
    /// and the host falls back to its own text viewer — with the outline still working, because that
    /// is read from the source.
    var claimFiles = true
    var diagrams = true
    var maths = true
    /// Above this, the file is left to the text viewer. Rendering a 40 MB generated report as HTML is
    /// not a thing anybody wants to wait for, and the viewer exists for files that need not fit in
    /// memory.
    var maxSizeMB = 8

    /// Whether the "Export to PDF…" command does anything.
    ///
    /// It cannot hide the menu entry, and that is not an oversight: the host builds a plugin's menus
    /// from its manifest **without loading the plugin**, deliberately, so that a disabled plugin
    /// contributes nothing and no plugin code decides menu presence. There is therefore nowhere for a
    /// setting in this file to be read at menu-build time. Switched off, the command says so and does
    /// nothing — which is the honest half of the feature that is available to it.
    var pdfExport = true
    /// What an exported PDF is laid out on.
    var pdfPaper = MarkdownPaper.a4
    /// Whether an export replaces an existing PDF of the same name, rather than numbering the new one.
    var pdfOverwrite = false
    /// Whether the panel moves its cursor to the PDF that was just written.
    var pdfReveal = true

    /// The view id this plugin's settings pane is contributed under (Info.plist must agree).
    static let settingsViewId = "plugin.markdown.settings"

    private static func path(configRoot: String) -> String {
        (configRoot as NSString).appendingPathComponent("markdown.ini")
    }

    static func read(configRoot: String) -> MarkdownOptions {
        var options = MarkdownOptions()
        guard !configRoot.isEmpty,
              let text = try? String(contentsOfFile: path(configRoot: configRoot), encoding: .utf8)
        else { return options }
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), !trimmed.hasPrefix(";"),
                  let equals = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[trimmed.startIndex..<equals].trimmingCharacters(in: .whitespaces).lowercased()
            let value = trimmed[trimmed.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "claimfiles": options.claimFiles = isTrue(value)
            case "diagrams": options.diagrams = isTrue(value)
            case "maths": options.maths = isTrue(value)
            case "maxsizemb": options.maxSizeMB = max(1, Int(value) ?? options.maxSizeMB)
            case "pdfexport": options.pdfExport = isTrue(value)
            // An unrecognised paper name is A4 rather than a failure, the way an unrecognised
            // boolean is "no": a hand-edited file should lose one setting, never the rest of them.
            case "pdfpaper": options.pdfPaper = MarkdownPaper(rawValue: value.lowercased()) ?? .a4
            case "pdfoverwrite": options.pdfOverwrite = isTrue(value)
            case "pdfreveal": options.pdfReveal = isTrue(value)
            default: break
            }
        }
        return options
    }

    /// Forgiving in the way the theme files are: `1`, `yes` and `true` all mean yes, and anything
    /// unrecognised means no rather than throwing the whole file away.
    private static func isTrue(_ value: String) -> Bool {
        ["1", "yes", "true", "on"].contains(value.lowercased())
    }

    func write(configRoot: String) {
        guard !configRoot.isEmpty else { return }
        let text = """
        # Peach Commander — Markdown lister plugin.
        # Written by the plugin's page in Settings; safe to edit by hand.
        [Markdown]
        ClaimFiles=\(claimFiles ? 1 : 0)
        Diagrams=\(diagrams ? 1 : 0)
        Maths=\(maths ? 1 : 0)
        MaxSizeMB=\(maxSizeMB)
        PDFExport=\(pdfExport ? 1 : 0)
        PDFPaper=\(pdfPaper.rawValue)
        PDFOverwrite=\(pdfOverwrite ? 1 : 0)
        PDFReveal=\(pdfReveal ? 1 : 0)
        """
        try? text.write(toFile: Self.path(configRoot: configRoot), atomically: true, encoding: .utf8)
    }
}
