// SPDX-License-Identifier: Apache-2.0
// TreemapConfig.swift — persisted preferences + the Settings pane for Disk Map.
//
// Like SystemMonitor/LogViewer, the plugin owns its config as JSON under the host's
// config root (honoring an isolated `-ConfigRoot` / PEACHCMD_CONFIG_ROOT for testing),
// and contributes a pane into the host Settings dialog (container "settings"). Changing
// a setting posts a notification so an open Disk Map re-renders immediately.

import AppKit

/// Posted (on the main thread) whenever the user changes a Disk Map setting.
let kTreemapConfigChanged = Notification.Name("PCTreemapConfigChanged")

struct TreemapConfig: Codable {
    var chartType: String = "treemap"       // "treemap" | "sunburst"
    var colorScheme: String = "category"     // "category" | "heatmap"
    var stayOnVolume: Bool = true            // stop at other-volume mount points
    var showVolumeRing: Bool = true          // reconciling Used/Free/Purgeable/Hidden bar
    var showLargestFiles: Bool = false       // side list of the biggest files
}

final class ConfigStore {
    static let shared = ConfigStore()
    private(set) var config: TreemapConfig

    private let url: URL = {
        let root: URL
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-ConfigRoot"), i + 1 < args.count {
            root = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        } else if let env = ProcessInfo.processInfo.environment["PEACHCMD_CONFIG_ROOT"], !env.isEmpty {
            root = URL(fileURLWithPath: env, isDirectory: true)
        } else {
            root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("PeachCommander", isDirectory: true)
        }
        let base = root.appendingPathComponent("treemap", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("config.json")
    }()

    private init() {
        if let data = try? Data(contentsOf: url), let c = try? JSONDecoder().decode(TreemapConfig.self, from: data) {
            config = c
        } else {
            config = TreemapConfig()
        }
    }

    func update(_ mutate: (inout TreemapConfig) -> Void) {
        mutate(&config)
        if let data = try? JSONEncoder().encode(config) { try? data.write(to: url, options: .atomic) }
        NotificationCenter.default.post(name: kTreemapConfigChanged, object: nil)
    }
}

/// The Settings pane shown inside the host Settings dialog.
final class TreemapSettingsView: NSView {
    private let chartPopup = NSPopUpButton()
    private let colorPopup = NSPopUpButton()
    private let stayOnVolume = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let showRing = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let showLargest = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    private let chartValues = ["treemap", "sunburst"]
    private let colorValues = ["category", "heatmap"]

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 460, height: 260))
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        let cfg = ConfigStore.shared.config

        chartPopup.addItems(withTitles: [L("Treemap (rectangles)"), L("Sunburst (rings)")])
        chartPopup.selectItem(at: max(0, chartValues.firstIndex(of: cfg.chartType) ?? 0))
        chartPopup.target = self; chartPopup.action = #selector(changed)

        colorPopup.addItems(withTitles: [L("By file type (category)"), L("By size (heatmap)")])
        colorPopup.selectItem(at: max(0, colorValues.firstIndex(of: cfg.colorScheme) ?? 0))
        colorPopup.target = self; colorPopup.action = #selector(changed)

        configure(stayOnVolume, L("Stay on the starting volume (don't cross into other disks)"), cfg.stayOnVolume)
        configure(showRing, L("Show the volume bar (Used / Free / Purgeable / Hidden)"), cfg.showVolumeRing)
        configure(showLargest, L("Show the largest-files list"), cfg.showLargestFiles)

        let note = NSTextField(wrappingLabelWithString: L("Disk Map measures actual on-disk (allocated) size, counts hard-linked files once, and reconciles what it scanned against the volume's used space — the remainder (system-protected folders, other users, snapshots) is shown as “hidden”. Purgeable space is what macOS can reclaim automatically."))
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [
            row(L("Chart style:"), chartPopup),
            row(L("Color coding:"), colorPopup),
            stayOnVolume, showRing, showLargest, note,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            note.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
        ])
    }

    private func configure(_ b: NSButton, _ title: String, _ on: Bool) {
        b.title = title; b.state = on ? .on : .off; b.target = self; b.action = #selector(changed)
    }
    private func row(_ title: String, _ control: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        let r = NSStackView(views: [label, control])
        r.orientation = .horizontal; r.spacing = 8; r.alignment = .firstBaseline
        return r
    }

    @objc private func changed() {
        ConfigStore.shared.update { c in
            c.chartType = chartValues[max(0, chartPopup.indexOfSelectedItem)]
            c.colorScheme = colorValues[max(0, colorPopup.indexOfSelectedItem)]
            c.stayOnVolume = stayOnVolume.state == .on
            c.showVolumeRing = showRing.state == .on
            c.showLargestFiles = showLargest.state == .on
        }
    }
}
