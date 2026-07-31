// SPDX-License-Identifier: Apache-2.0
// FlippedViews.swift - Top-origin views for use as NSScrollView content.
//
// AppKit places a non-flipped document view's origin at the *bottom* left. As a result
// content that is shorter than the scroll view sits at the foot of the empty space instead
// of starting at the top, and content that is taller opens scrolled to its end. Neither is
// what anyone expects from a settings pane or a list of items.
//
// NSTableView, NSOutlineView and NSTextView are already flipped, so scroll views built
// around those need nothing. Everything else — an NSStackView of rows, a plain container,
// a wrapping label — does.

import AppKit

/// A top-origin container. Use when the content view is arbitrary (or comes from a plugin)
/// and cannot be subclassed.
final class FlippedContainerView: NSView {
    override var isFlipped: Bool { true }
}

/// A top-origin stack, for the common case of a vertical NSStackView used directly as a
/// scroll view's documentView.
final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}
