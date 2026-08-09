// SPDX-License-Identifier: Apache-2.0
// CrashReportSelection.swift - Which crash reports are worth mentioning (F-313).
//
// macOS writes crash logs to ~/Library/Logs/DiagnosticReports for everything on the machine. Two
// questions decide what the app may raise with the user, and both are easy to get quietly wrong:
// which files are ours, and which are new since the last look.
//
// Getting the second one wrong is the one that shows: a watermark that does not advance asks about the
// same crash at every launch, and a first-ever launch that reports everything it finds surfaces months
// of unrelated crashes as though the app had just produced them.
//
// The rule lives here because the collector is an AppKit object no test bundle can reach, while this
// is a question about names and dates.

import Foundation

public enum CrashReportSelection {

    /// Is `fileName` a crash report belonging to this app?
    ///
    /// Case-insensitive, because the file is named after the executable and the comparison should not
    /// depend on how that was capitalised. Both extensions macOS has used are accepted.
    public static func isOurReport(_ fileName: String, appName: String = "PeachCommander") -> Bool {
        let name = fileName.lowercased()
        guard name.hasPrefix(appName.lowercased()) else { return false }
        return name.hasSuffix(".ips") || name.hasSuffix(".crash")
    }

    /// The reports to raise with the user: ours, newer than `watermark`, newest first.
    ///
    /// `watermark` is nil on the first ever launch, and the answer is then *nothing* — the reports
    /// sitting there predate the app knowing anything about them, and offering to send a stranger's
    /// crash log is not a good introduction. The caller still advances the watermark.
    public static func newReports(_ files: [(name: String, modified: Date)],
                                  since watermark: Date?,
                                  appName: String = "PeachCommander") -> [(name: String, modified: Date)] {
        guard let watermark else { return [] }
        return files
            .filter { isOurReport($0.name, appName: appName) && $0.modified > watermark }
            .sorted { $0.modified > $1.modified }
    }
}
