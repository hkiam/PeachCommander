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
    /// Directory-name prefixes the archive filesystems and the member stage extract under.
    static let prefixes = ["PCArchive-", "PCX-", "PCStage-"]

    /// `PCStage-<pid>-<uuid>` carries the process it belonged to (F-479), which is a better question
    /// than the age: a root whose process is gone is leftover *now*, and one belonging to a second
    /// running copy of the app must be left alone whatever its age says. The age rule below stays as
    /// the fallback for the two older prefixes, which carry no pid.
    static func ownerPID(of name: String) -> pid_t? {
        guard name.hasPrefix("PCStage-") else { return nil }
        let rest = name.dropFirst("PCStage-".count)
        guard let dash = rest.firstIndex(of: "-") else { return nil }
        return pid_t(rest[rest.startIndex..<dash])
    }

    /// Whether some process still holds that id. `kill(pid, 0)` fails with `ESRCH` only when there is
    /// no such process; `EPERM` means there is one and it is not ours, which counts as alive.
    static func processIsAlive(_ pid: pid_t) -> Bool {
        guard pid > 0 else { return false }
        if kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }

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
            if let pid = ownerPID(of: name) {
                // Its own process says whether it is leftover, so a crash mid-session does not leave
                // a staged file sitting in the temp directory for a day.
                guard !processIsAlive(pid) else { continue }
                if (try? fm.removeItem(at: url)) != nil { removed += 1 }
                continue
            }
            guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                  let modified = attrs[.modificationDate] as? Date,
                  now.timeIntervalSince(modified) > minimumAge else { continue }
            if (try? fm.removeItem(at: url)) != nil { removed += 1 }
        }
        return removed
    }
}
