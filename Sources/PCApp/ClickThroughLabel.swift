// SPDX-License-Identifier: Apache-2.0
// ClickThroughLabel.swift - A label that lets clicks reach the view underneath (F-444).

import AppKit

/// A label that never answers a click, so the view it is laid over keeps its own (F-444).
///
/// The panel's three indicators — the quick filter, the type-ahead prefix and a failure message — are
/// constrained *over* the path bar, and a plain `NSTextField` answers `hitTest` whether or not it can do
/// anything with the click. So while the quick filter was showing, its indicator sat on the pencil at
/// the right end of the bar and the pencil could not be clicked at all; a message did the same to the
/// breadcrumb segments at the left end. Nothing said so, because the indicator looks like part of the
/// bar and the bar simply stopped responding.
final class ClickThroughLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
