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

    /// Index (into `volumes`) of the chip to highlight.
    ///
    /// `mountedVolumePath` is the sentinel path of a mounted plugin volume (e.g.
    /// "pfxmount:…/TaskManager.pfxplugin") when the panel is showing that mount rather than a
    /// directory on a real volume. It wins over `path`, and no fallback follows it: inside such a
    /// mount the panel's path is the mount's own "/", which by prefix belongs to the boot drive —
    /// so falling back would highlight a drive the user is not on and make the plugin look like a
    /// mere view switch instead of the drive it was selected as.
    public static func currentIndex(in volumes: [Volume], for path: String,
                                    mountedVolumePath: String? = nil) -> Int? {
        if let mountedVolumePath {
            return volumes.firstIndex { $0.path == mountedVolumePath }
        }
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

/// Which of a drive bar's clickable rectangles a point lands on (F-385).
///
/// Split out of the view because the ordering *is* the correctness: a volume's eject glyph is drawn
/// inside that volume's own chip, so its rectangle lies entirely within the chip's. Whichever is
/// consulted first wins, and getting that backwards leaves a glyph that is drawn, looks clickable,
/// and does nothing but navigate — a defect no compiler and no screenshot would catch.
public enum DriveBarHit {
    /// One clickable region, in the order they should be consulted.
    public struct Region<Payload>: Sendable where Payload: Sendable {
        public let rect: CGRect
        public let payload: Payload
        public init(rect: CGRect, payload: Payload) {
            self.rect = rect
            self.payload = payload
        }
    }

    /// The first region containing `point`, or nil. First, not smallest: the caller decides
    /// precedence by the order it builds the list in, which keeps this honest about what it does.
    public static func region<Payload>(at point: CGPoint,
                                       in regions: [Region<Payload>]) -> Region<Payload>? {
        regions.first { $0.rect.contains(point) }
    }
}
