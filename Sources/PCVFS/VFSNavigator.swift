// SPDX-License-Identifier: Apache-2.0
// VFSNavigator.swift - Per-tab navigation stack of (fs, path) (SPEC-006 §2).

import Foundation

/// Tracks a single panel/tab's navigation state as a stack of frames, each a
/// `(filesystem, path)` pair.
///
/// The root frame is the panel's top-level filesystem (typically `LocalFS`).
/// Entering a nested filesystem (e.g. opening an archive) pushes a new frame
/// whose display path is composed on top of the frame it was entered from;
/// leaving it pops back to the host frame. This lets the same navigator
/// transparently walk into archives, and archives-within-archives, without
/// the caller needing to know how deep the stack currently is.
public final class VFSNavigator {
    /// One level of the navigation stack.
    private struct Frame {
        let fs: VirtualFileSystem
        var path: VFSPath
        /// Display path this frame is mounted at (e.g. `"/Users/x/a.zip"`).
        /// `nil` for the root frame, whose display path is simply `path.path`.
        let hostDisplayBase: String?
    }

    private var stack: [Frame]

    /// Creates a navigator rooted at `path` on `fs`.
    public init(fs: VirtualFileSystem, path: VFSPath) {
        self.stack = [Frame(fs: fs, path: path, hostDisplayBase: nil)]
    }

    /// The filesystem of the current (topmost) frame.
    public var currentFS: VirtualFileSystem { stack[stack.count - 1].fs }

    /// The path of the current (topmost) frame.
    public var currentPath: VFSPath { stack[stack.count - 1].path }

    /// Number of frames on the stack; `1` at the root.
    public var depth: Int { stack.count }

    /// Navigates within the current filesystem, replacing the current
    /// frame's path in place. The filesystem itself and the rest of the
    /// stack are untouched.
    public func go(to path: VFSPath) {
        stack[stack.count - 1].path = path
    }

    /// Enters a nested filesystem (e.g. an archive) mounted at `hostDisplay`,
    /// the display path of the file being entered (e.g. `"/Users/x/a.zip"`).
    /// `path` is the initial location within the newly-entered filesystem.
    public func push(fs: VirtualFileSystem, at hostDisplay: String, path: VFSPath) {
        stack.append(Frame(fs: fs, path: path, hostDisplayBase: hostDisplay))
    }

    /// Leaves the current nested filesystem, popping the top frame.
    ///
    /// - Returns: the host display path the popped frame was mounted at (the
    ///   mount point, i.e. the archive file to reselect in the parent
    ///   listing), or `nil` if already at the root (nothing is popped).
    @discardableResult
    public func pop() -> String? {
        guard stack.count > 1 else { return nil }
        let popped = stack.removeLast()
        return popped.hostDisplayBase
    }

    /// Composed display path across the whole navigation stack, e.g.
    /// `"/Users/x/a.zip/dir/file"`.
    public func displayPath() -> String {
        let top = stack[stack.count - 1]
        guard let base = top.hostDisplayBase else { return top.path.path }
        return base + (top.path.path == "/" ? "" : top.path.path)
    }
}
