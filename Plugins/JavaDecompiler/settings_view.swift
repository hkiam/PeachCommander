// SPDX-License-Identifier: Apache-2.0
// settings_view.swift — the plugin's own page in Settings (F-352).
//
// Contributed as a view in the host's "settings" container, the same way the System Monitor plugin
// does it. Deliberately not a page built into the host: this plugin is optional and removable, and a
// host page for something that may not be installed is dead UI — while settings written into the
// host's own peachcmd.ini would outlive the plugin that meant something by them.
//
// Everything here is a setting somebody would otherwise have to discover: which engine runs, how long
// it may take, whether F3 opens a plugin window at all, whether a search may spend seconds per class,
// and how much disk the cache is allowed to keep.

import AppKit

@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?, _ containerId: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    guard let viewId, String(cString: viewId) == "plugin.javadecompiler.settings" else { return nil }
    // The host's config root when it offers one, so a scripted or -ConfigRoot run edits the same
    // files the rest of the plugin reads.
    let root = services.flatMap { context($0.pointee, "configRoot") } ?? configRoot()
    let view = DecompilerSettingsView(configRoot: root)
    return Unmanaged.passRetained(view).toOpaque()
}

@_cdecl("PcCloseView")
public func PcCloseView(_ view: UnsafeMutableRawPointer?) {
    guard let view else { return }
    Unmanaged<DecompilerSettingsView>.fromOpaque(view).release()
}

final class DecompilerSettingsView: NSView {
    private let configRootPath: String
    private var options: PluginDecompilerOptions
    private var registry: PluginDecompilerRegistry

    private let claimArchives = NSButton(checkboxWithTitle: L("F3 on a .jar, .apk or .dex shows the decompiled tree"),
                                         target: nil, action: nil)
    private let searchDecompile = NSButton(checkboxWithTitle: L("Allow decompiling while searching file contents"),
                                           target: nil, action: nil)
    private let classTimeout = NSTextField()
    private let archiveTimeout = NSTextField()
    private let cacheAge = NSTextField()
    private let cacheLabel = NSTextField(labelWithString: "")
    private let enginePopups: [(kind: String, popup: NSPopUpButton)]
    private let engineStatus = NSTextField(labelWithString: "")

    init(configRoot: String) {
        self.configRootPath = configRoot
        self.options = PluginDecompilerOptions.read(configRoot: configRoot)
        self.registry = PluginDecompilerRegistry(configRoot: configRoot)
        // One row per kind the plugin handles, so "which engine for JARs" and "which for a single
        // class" are separate answers — they usually are, since javap only does the latter.
        self.enginePopups = ["class", "jar", "apk", "dex"].map { ($0, NSPopUpButton()) }
        super.init(frame: NSRect(x: 0, y: 0, width: 520, height: 460))
        build()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        var rows: [NSView] = []

        rows.append(heading(L("Engines")))
        let preferred = PluginDecompilerPreference.read(configRoot: configRootPath)
        for (kind, popup) in enginePopups {
            let candidates = pluginDecompilerArchiveKinds.contains(kind)
                ? registry.archiveEngines(for: kind) : registry.engines(for: kind)
            popup.addItem(withTitle: L("First available"))
            popup.lastItem?.tag = -1
            for (i, engine) in candidates.enumerated() {
                popup.addItem(withTitle: engine.name + (engine.isAvailable ? "" : " — " + L("not installed")))
                popup.lastItem?.tag = i
            }
            popup.selectItem(withTag: candidates.firstIndex { $0.id == preferred[kind] } ?? -1)
            popup.target = self
            popup.action = #selector(engineChanged(_:))
            popup.isEnabled = !candidates.isEmpty
            // An empty popup would say nothing about *why*; the label does.
            popup.identifier = NSUserInterfaceItemIdentifier(kind)
            rows.append(labelled(String(format: L(".%@ files:"), kind), popup))
        }
        engineStatus.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        engineStatus.textColor = .secondaryLabelColor
        engineStatus.lineBreakMode = .byWordWrapping
        engineStatus.maximumNumberOfLines = 3
        rows.append(engineStatus)
        let folder = NSButton(title: L("Engine Folder…"), target: self, action: #selector(openEngineFolder))
        folder.bezelStyle = .rounded
        rows.append(folder)

        rows.append(heading(L("Viewing and searching")))
        for (box, action) in [(claimArchives, #selector(optionsChanged)),
                              (searchDecompile, #selector(optionsChanged))] {
            box.target = self
            box.action = action
        }
        claimArchives.state = options.claimArchives ? .on : .off
        claimArchives.toolTip = L("Off: F3 leaves archives to the built-in viewer. Decompile to Sources still works from the Commands menu and puts the classes in a file panel.")
        searchDecompile.state = options.allowSearchDecompile ? .on : .off
        searchDecompile.toolTip = L("The host asks separately in its search dialog; this refuses it here as well, for machines where decompiling is too slow to spend on a search.")
        rows.append(claimArchives)
        rows.append(searchDecompile)

        rows.append(heading(L("Limits")))
        for (field, value) in [(classTimeout, options.classTimeout), (archiveTimeout, options.archiveTimeout),
                               (cacheAge, options.cacheMaxAgeDays)] {
            field.stringValue = String(value)
            field.alignment = .right
            field.target = self
            field.action = #selector(optionsChanged)
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 70).isActive = true
        }
        classTimeout.placeholderString = "0"
        rows.append(labelled(L("Timeout for one class (s, 0 = engine default):"), classTimeout))
        rows.append(labelled(L("Timeout for a whole archive (s, 0 = engine default):"), archiveTimeout))

        rows.append(heading(L("Cache")))
        rows.append(labelled(L("Keep results for (days):"), cacheAge))
        cacheLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        cacheLabel.textColor = .secondaryLabelColor
        rows.append(cacheLabel)
        let clear = NSButton(title: L("Clear Cache Now"), target: self, action: #selector(clearCache))
        clear.bezelStyle = .rounded
        rows.append(clear)

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
        ])
        refreshStatus()
    }

    private func heading(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: 13)
        return label
    }

    private func labelled(_ text: String, _ control: NSView) -> NSView {
        let label = NSTextField(labelWithString: text)
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    // MARK: Actions

    @objc private func engineChanged(_ sender: NSPopUpButton) {
        guard let kind = sender.identifier?.rawValue else { return }
        let candidates = pluginDecompilerArchiveKinds.contains(kind)
            ? registry.archiveEngines(for: kind) : registry.engines(for: kind)
        let tag = sender.selectedItem?.tag ?? -1
        if tag < 0 {
            // "First available" is the absence of a preference, not a preference for the first entry:
            // recording an id here would freeze today's answer even after a better engine is installed.
            PluginDecompilerPreference.clear(forKind: kind, configRoot: configRootPath)
        } else if candidates.indices.contains(tag) {
            PluginDecompilerPreference.set(engine: candidates[tag].id, forKind: kind,
                                           configRoot: configRootPath)
        }
        refreshStatus()
    }

    @objc private func optionsChanged() {
        options.claimArchives = claimArchives.state == .on
        options.allowSearchDecompile = searchDecompile.state == .on
        options.classTimeout = max(0, Int(classTimeout.stringValue) ?? 0)
        options.archiveTimeout = max(0, Int(archiveTimeout.stringValue) ?? 0)
        options.cacheMaxAgeDays = max(1, Int(cacheAge.stringValue) ?? 30)
        // Written on every change rather than on an OK button: this is a settings pane inside the
        // host's window, and it has no OK of its own to hang a commit on.
        options.write(configRoot: configRootPath)
        refreshStatus()
    }

    @objc private func openEngineFolder() {
        let dir = PluginDecompilerRegistry.engineDirectory(configRoot: configRootPath)
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: dir)])
    }

    @objc private func clearCache() {
        try? FileManager.default.removeItem(atPath: PluginDecompilerCache.directory(configRoot: configRootPath))
        refreshStatus()
    }

    private func refreshStatus() {
        registry = PluginDecompilerRegistry(configRoot: configRootPath)
        let installed = registry.engines.filter(\.isAvailable)
        engineStatus.stringValue = installed.isEmpty
            ? L("No engine is installed. Nothing is downloaded for you — “Engine Folder…” opens the folder they belong in, and its README names each engine and its licence.")
            : String(format: L("Installed: %@"), installed.map(\.name).joined(separator: ", "))
        let count = PluginDecompilerCache.entryCount(configRoot: configRootPath)
        let bytes = PluginDecompilerCache.sizeInBytes(configRoot: configRootPath)
        cacheLabel.stringValue = count == 0
            ? L("Nothing cached.")
            : String(format: L("%d cached result(s), %@ on disk"), count,
                     ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
    }
}
