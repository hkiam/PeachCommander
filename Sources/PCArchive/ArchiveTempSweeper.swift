// SPDX-License-Identifier: Apache-2.0
// ArchiveTempSweeper.swift - Clear away extractions older builds left behind (F-463).
//
// Extracting a member from an archive writes a real file, and until F-463 nothing ever
// removed it: `ArchiveFS` and `PCXArchiveFS` each made a fresh directory per call, and
// because the name embedded an fsID carrying the archive's path, `appendingPathComponent`
// turned the slashes in it into further directories. Viewing a handful of files inside a
// few archives could leave a small tree behind each time.
//
// Both filesystems clean up after themselves now, which fixes it going forward. This
// fixes it backwards: what is already sitting in the temp directory of everyone who ran
// an earlier build stays there until the OS decides otherwise, and on a Mac that is left
// running that can be a long time.

import Foundation

/// Removes archive extraction directories nobody is using any more.
public enum ArchiveTempSweeper {
    /// Directory-name prefixes the two archive filesystems stage extractions under.
    static let prefixes = ["PCArchive-", "PCX-"]

    /// Anything younger than this may belong to a mount that is still open — a panel
    /// sitting inside an archive with the viewer showing one of its files — so it is left
    /// alone. A day is far longer than any extraction stays useful and far shorter than
    /// the temp directory's own housekeeping.
    static let minimumAge: TimeInterval = 24 * 60 * 60

    /// Sweeps the temp directory. Returns how many directories were removed.
    ///
    /// Safe to call at launch and cheap: it reads one directory listing and stats the few
    /// entries whose names match. Never throws — a temp directory we cannot read is not a
    /// reason to hold up a launch.
    @discardableResult
    public static func sweep(now: Date = Date()) -> Int {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
        guard let names = try? fm.contentsOfDirectory(atPath: root.path) else { return 0 }
        var removed = 0
        for name in names where prefixes.contains(where: { name.hasPrefix($0) }) {
            let url = root.appendingPathComponent(name)
            guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                  let modified = attrs[.modificationDate] as? Date,
                  now.timeIntervalSince(modified) > minimumAge else { continue }
            if (try? fm.removeItem(at: url)) != nil { removed += 1 }
        }
        return removed
    }
}
