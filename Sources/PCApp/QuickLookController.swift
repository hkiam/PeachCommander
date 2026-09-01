// SPDX-License-Identifier: Apache-2.0
// QuickLookController.swift - Native Quick Look preview panel (TODOS I18, F-290).
//
// Shows the shared QLPreviewPanel for the selected (or cursor) files, the way Finder's
// spacebar/Cmd-Y preview works. Acts as the panel's data source directly so it works without
// threading control through the responder chain.
//
// It used to say "local files only (FTP/archive entries would need extraction first)", and the
// caller beeped inside an archive. They are extracted first now (F-479) — by `MemberStage`, which
// this pins while the panel is showing them: a staged preview is evictable by design, and the one
// thing that must not happen is the file disappearing from under an open Quick Look panel.

import AppKit
import Quartz
import PCVFS

@MainActor
final class QuickLookController: NSObject, QLPreviewPanelDataSource {
    private var urls: [URL] = []
    /// Staged copies this panel is holding open. Released when the set changes or the panel closes.
    private var pinned: [URL] = []
    private var observing = false

    /// Preview the given file paths (no-op if empty). Staged copies are pinned for as long as the
    /// panel shows them.
    func show(_ paths: [String]) {
        urls = paths.filter { FileManager.default.fileExists(atPath: $0) }
                    .map { URL(fileURLWithPath: $0) }
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        repin(urls)
        observeClose(panel)
        panel.dataSource = self
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    private func repin(_ next: [URL]) {
        let previous = pinned
        pinned = next
        Task {
            for url in previous { await MemberStage.shared.unpin(url) }
            for url in next { await MemberStage.shared.pin(url) }
        }
    }

    /// The panel is a window, so its closing is a notification like any other — and it is the moment
    /// the staged copies stop being needed.
    private func observeClose(_ panel: QLPreviewPanel) {
        guard !observing else { return }
        observing = true
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                               object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.repin([]) }
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
