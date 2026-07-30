// SPDX-License-Identifier: Apache-2.0
// CrashReportCollector.swift - Local crash-report detection (I20-T?, F-313)
//
// On launch, checks the system DiagnosticReports directory for crash logs
// (.ips / legacy .crash) that belong to Peach Commander and are newer than the
// last time we looked. If any appeared, the user is offered — with explicit
// consent — to reveal the report in Finder or copy its contents to the
// clipboard for filing a bug report. Nothing is ever transmitted automatically
// and there is no third-party crash-reporting SaaS involved.

import AppKit
import PCFoundation

@MainActor
final class CrashReportCollector {
    private let logger = PCFoundationLogger.logger
    private let defaults: UserDefaults
    private let lastScanKey = "PCLastCrashScan"

    nonisolated init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Scans for new crash reports and, if found, prompts the user. Safe to call
    /// once on launch; it advances a watermark so the same crash never nags twice.
    func checkForNewReports() {
        let fm = FileManager.default
        let dir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)

        // First-ever launch: record the watermark but never surface pre-existing,
        // possibly unrelated reports.
        guard let watermark = storedWatermark else {
            markScannedNow()
            return
        }

        guard let entries = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            markScannedNow()
            return
        }

        let reports = entries
            .filter { isPeachCommanderReport($0) && modificationDate($0) > watermark }
            .sorted { modificationDate($0) > modificationDate($1) }

        markScannedNow()

        guard let newest = reports.first else { return }
        logger.info("Found \(reports.count, privacy: .public) new crash report(s)")
        presentPrompt(count: reports.count, newest: newest)
    }

    // MARK: - Detection helpers

    private func isPeachCommanderReport(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        guard name.hasPrefix("peachcommander") else { return false }
        return name.hasSuffix(".ips") || name.hasSuffix(".crash")
    }

    private func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private var storedWatermark: Date? {
        let t = defaults.double(forKey: lastScanKey)
        return t > 0 ? Date(timeIntervalSinceReferenceDate: t) : nil
    }

    private func markScannedNow() {
        defaults.set(Date().timeIntervalSinceReferenceDate, forKey: lastScanKey)
    }

    // MARK: - User consent prompt

    private func presentPrompt(count: Int, newest: URL) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Peach Commander quit unexpectedly")
        alert.informativeText = count == 1
            ? String(localized: "A crash report was found. You can reveal it in Finder or copy its contents to the clipboard to include in a bug report. Nothing is sent automatically.")
            : String(format: String(localized: "%d crash reports were found. You can reveal the most recent one in Finder or copy its contents to the clipboard to include in a bug report. Nothing is sent automatically."), count)

        alert.addButton(withTitle: String(localized: "Show in Finder"))
        alert.addButton(withTitle: String(localized: "Copy Report to Clipboard"))
        alert.addButton(withTitle: String(localized: "Ignore"))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.activateFileViewerSelecting([newest])
        case .alertSecondButtonReturn:
            copyToClipboard(newest)
        default:
            break
        }
    }

    private func copyToClipboard(_ url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            logger.error("Could not read crash report at \(url.path, privacy: .public)")
            NSSound.beep()
            return
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        logger.info("Copied crash report to clipboard (\(text.count, privacy: .public) chars)")
    }
}
