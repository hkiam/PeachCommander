// SPDX-License-Identifier: Apache-2.0
// PathBarHit.swift - What a click on the path bar means (F-444).
//
// Split out of the view for the same reason as `PathSegments`: this decides where a click goes, which
// is worth a test, and the view around it pulls in the theme, the tracking areas and an AppKit event.
// `DriveBarHit` is the same arrangement one bar over.

import Foundation

/// The path bar's regions, as a click resolves them.
public enum PathBarHit: Equatable, Sendable {
    /// A breadcrumb segment: navigate to that folder.
    case navigate(String)
    /// The free-text path editor: the area right of the last segment, or a double-click anywhere.
    case edit
    /// Nothing there.
    case none
}

/// One breadcrumb segment as it was drawn, with the folder it navigates to.
public struct PathBarSegmentFrame: Equatable, Sendable {
    public let rect: CGRect
    public let path: String

    public init(rect: CGRect, path: String) {
        self.rect = rect
        self.path = path
    }
}

/// Resolve a click in the path bar.
///
/// `contentEndX` is the right edge of the last segment as drawn. Everything from there to the panel's
/// edge — the pencil button included — opens the editor, because that button is an 18-point target and
/// the empty space beside it means nothing else. The gaps *between* segments do not: they are three
/// pixels wide, and a click that just misses a folder name is a miss, not a request to type a path.
///
/// A `nil` `contentEndX` means the bar has never drawn. There are no segments to hit and nothing anyone
/// could have aimed at, so a single click resolves to `.none`.
///
/// Segments are tested before the trailing area, so a segment that reaches under the reserved trailing
/// inset still navigates.
public func pathBarHit(at point: CGPoint,
                       segments: [PathBarSegmentFrame],
                       contentEndX: CGFloat?,
                       clickCount: Int) -> PathBarHit {
    if clickCount >= 2 { return .edit }
    if let hit = segments.first(where: { $0.rect.contains(point) }) { return .navigate(hit.path) }
    if let end = contentEndX, point.x >= end { return .edit }
    return .none
}
