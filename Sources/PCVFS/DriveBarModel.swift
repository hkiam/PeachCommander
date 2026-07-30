// SPDX-License-Identifier: Apache-2.0
// DriveBarModel.swift - Which volumes the drive-button bar shows, and which is current.
//
// Pure selection/ordering logic for the per-panel drive bar (TODOS #9): hide hidden
// volumes, list the root first then the rest by name, and resolve which volume owns a
// given path (longest matching mount prefix). Unit-testable; the AppKit bar just renders.

import Foundation

public enum DriveBarModel {
    /// Volumes to show, root ("/") first, then the rest by name; hidden ones dropped.
    /// Volumes sharing a display name are collapsed to one (APFS volume groups expose
    /// several internal volumes all named e.g. "Macintosh HD"); the first after sorting
    /// wins, so the root "/" entry represents the boot drive.
    public static func display(_ volumes: [Volume]) -> [Volume] {
        // Order: boot drive first; then volumes a plugin pinned via `sortOrder`
        // (>0, lower first) right after it — so a tool like TaskManager defines its
        // own position; then the remaining volumes by name. Sort key per volume:
        // (tier, pinnedOrder, name) where tier 0 = boot, 1 = pinned, 2 = ordinary.
        func key(_ v: Volume) -> (Int, Int, String) {
            if v.path == "/" { return (0, 0, "") }
            if v.sortOrder > 0 { return (1, v.sortOrder, v.name.lowercased()) }
            return (2, 0, v.name.lowercased())
        }
        let sorted = volumes
            .filter { !$0.isHidden }
            .sorted { lhs, rhs in
                let (lt, lo, ln) = key(lhs), (rt, ro, rn) = key(rhs)
                if lt != rt { return lt < rt }
                if lo != ro { return lo < ro }
                return ln.localizedCaseInsensitiveCompare(rn) == .orderedAscending
            }
        var seenNames = Set<String>()
        return sorted.filter { seenNames.insert($0.name.lowercased()).inserted }
    }

    /// Index (into `volumes`) of the volume owning `path` — the longest mount prefix —
    /// or nil if none match.
    public static func currentIndex(in volumes: [Volume], for path: String) -> Int? {
        var best: Int?
        var bestLength = -1
        for (i, volume) in volumes.enumerated() {
            let mount = volume.path
            let prefix = mount.hasSuffix("/") ? mount : mount + "/"
            if path == mount || path.hasPrefix(prefix) {
                if mount.count > bestLength { bestLength = mount.count; best = i }
            }
        }
        return best
    }
}
