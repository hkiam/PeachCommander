// SPDX-License-Identifier: Apache-2.0
// QuickLookController.swift - Native Quick Look preview panel (TODOS I18, F-290).
//
// Shows the shared QLPreviewPanel for the selected (or cursor) local files, the way
// Finder's spacebar/Cmd-Y preview works. Local files only for now (FTP/archive
// entries would need extraction first). Acts as the panel's data source directly so
// it works without threading control through the responder chain.

import AppKit
import Quartz

@MainActor
final class QuickLookController: NSObject, QLPreviewPanelDataSource {
    private var urls: [URL] = []

    /// Preview the given local file paths (no-op if empty).
    func show(_ paths: [String]) {
        urls = paths.filter { FileManager.default.fileExists(atPath: $0) }
                    .map { URL(fileURLWithPath: $0) }
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel) -> Int { urls.count }

    func previewPanel(_ panel: QLPreviewPanel, previewItemAt index: Int) -> QLPreviewItem {
        urls[index] as NSURL
    }
}
