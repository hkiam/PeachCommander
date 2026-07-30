// SPDX-License-Identifier: Apache-2.0
// StatusBarView.swift - Status bar per panel for Peach Commander
//
// Shows:
// - Current path
// - Number of files/selected files
// - Free space on current volume
// - Current sort order

import AppKit
import PCVFS
import PCFoundation

/// Status bar view for a single panel
class StatusBarView: NSView {
    private let logger = PCFoundationLogger.logger

    let position: PanelPosition

    private let pathLabel = NSTextField()
    private let countLabel = NSTextField()
    private let freeSpaceLabel = NSTextField()
    private let sortLabel = NSTextField()

    private var currentVolume: Volume?

    init(position: PanelPosition) {
        self.position = position
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: Metrics.statusBarHeight).isActive = true

        // Give the bar a visible background (it was transparent, so an as-yet-empty
        // status line looked "missing"). Matches the drive bar's background.
        wantsLayer = true
        layer?.backgroundColor = Theme.current.statusBarBackground.cgColor

        // Configure labels. Each MUST disable autoresizing-mask constraints, or its
        // Auto Layout constraints below conflict and the label collapses to a zero
        // frame (the cause of the "status bar not visible" bug, TODOS #177).
        for label in [pathLabel, countLabel, freeSpaceLabel, sortLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.isEditable = false
            label.isBezeled = false
            label.drawsBackground = false
            // Use the theme's status-bar text color explicitly rather than the
            // dynamic system labelColor, so text always matches our bar background
            // (otherwise dark-mode labelColor = white lands on a light bar).
            label.textColor = Theme.current.statusBarText
        }
        pathLabel.font = Fonts.system13

        countLabel.font = Fonts.system13
        countLabel.alignment = .right

        freeSpaceLabel.font = Fonts.monospacedDigit13
        freeSpaceLabel.alignment = .right

        sortLabel.font = Fonts.system13
        sortLabel.alignment = .right

        // Add labels to view
        addSubview(pathLabel)
        addSubview(countLabel)
        addSubview(freeSpaceLabel)
        addSubview(sortLabel)

        // Layout constraints
        NSLayoutConstraint.activate([
            pathLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            pathLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            countLabel.leadingAnchor.constraint(equalTo: pathLabel.trailingAnchor, constant: 20),
            countLabel.trailingAnchor.constraint(equalTo: freeSpaceLabel.leadingAnchor, constant: -10),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            freeSpaceLabel.leadingAnchor.constraint(equalTo: countLabel.trailingAnchor, constant: 20),
            freeSpaceLabel.trailingAnchor.constraint(equalTo: sortLabel.leadingAnchor, constant: -10),
            freeSpaceLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            sortLabel.leadingAnchor.constraint(equalTo: freeSpaceLabel.trailingAnchor, constant: 20),
            sortLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            sortLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    /// Re-apply theme colors (called on light/dark appearance changes).
    func applyTheme() {
        layer?.backgroundColor = Theme.current.statusBarBackground.cgColor
        for label in [pathLabel, countLabel, freeSpaceLabel, sortLabel] {
            label.textColor = Theme.current.statusBarText
        }
    }

    /// Update the status bar with panel information (TC-style counts + sizes).
    func update(path: String,
                volume: Volume?,
                selected: Int,
                total: Int,
                selectedBytes: Int64,
                totalBytes: Int64,
                selectedFiles: Int,
                totalFiles: Int,
                selectedDirs: Int,
                totalDirs: Int,
                sortDescriptor: DirectoryModel.SortDescriptor) {
        pathLabel.stringValue = shortenPath(path)
        countLabel.stringValue = SelectionSummaryFormatter.detailed(
            selectedFiles: selectedFiles,
            totalFiles: totalFiles,
            selectedDirs: selectedDirs,
            totalDirs: totalDirs,
            selectedBytes: selectedBytes,
            totalBytes: totalBytes
        )
        updateFreeSpace(for: volume)
        sortLabel.stringValue = sortDescriptor.toDisplayString()
    }

    /// Shorten path to fit in status bar
    private func shortenPath(_ path: String) -> String {
        let maxChars = 60
        if path.count <= maxChars {
            return path
        }

        // Try to show beginning and end of path
        let components = path.components(separatedBy: "/")
        if components.count <= 2 {
            return String(path.prefix(maxChars - 3)) + "..."
        }

        var result = ""
        var currentLength = 0

        // Always show first component (volume name)
        if let first = components.first {
            result += first
            currentLength = first.count + 1
        }

        // Always show last component
        let last = components.last ?? ""

        // Try to add middle components
        for i in 1..<(components.count - 1) {
            let component = components[i]
            let newLength = currentLength + component.count + 1

            if i == components.count - 2 {
                // Last component - add it with ellipsis if needed
                let remaining = max(0, maxChars - newLength - last.count - 3)
                if remaining > 0 {
                    result += "/" + component + "/" + last
                } else {
                    result += "/..." + last
                }
                break
            }

            if newLength + last.count + 3 < maxChars {
                result += "/" + component
                currentLength = newLength
            } else {
                result += "/..." + last
                break
            }
        }

        return result
    }

    /// Update free space label based on volume
    private func updateFreeSpace(for volume: Volume?) {
        guard let volume = volume else {
            freeSpaceLabel.stringValue = ""
            return
        }

        let byteSize = ByteSize(volume.freeSpace)
        let freeSpace = byteSize.formatted(style: .mb)

        freeSpaceLabel.stringValue = String(format: String(localized: "Free: %@"), freeSpace)
    }
}
