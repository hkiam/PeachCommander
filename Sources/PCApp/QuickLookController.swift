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

    // `nonisolated` + `assumeIsolated` for the same reason as the panel's services witnesses:
    // `QLPreviewPanelDataSource` is an unannotated ObjC protocol, so a main-actor witness crosses
    // an isolation boundary the compiler only warns about today. Quick Look drives its data source
    // from the main thread; this asserts it rather than reading `urls` from anywhere (F-436).
    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel) -> Int {
        MainActor.assumeIsolated { urls.count }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel, previewItemAt index: Int) -> QLPreviewItem {
        MainActor.assumeIsolated { urls[index] as NSURL }
    }
}
