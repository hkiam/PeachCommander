// SPDX-License-Identifier: Apache-2.0
// PathContainment.swift - Turning a name from somewhere else into a local path (F-131).
//
// Two places in this app take a name out of a listing and build a local path from it: the archive
// extractor, and the panel's "extract/copy to…" walk over a virtual filesystem. The name is not the
// user's — it comes out of a zip's central directory, or out of what an FTP server chose to put in its
// LIST response — and a member called ".." or "../../evil.txt" lands the write above the folder the
// user picked, silently, while the operation reports success. That is "zip slip", and it is not
// hypothetical here: listing a crafted zip through ArchiveFS yields an entry named exactly ".." with
// kind `.directory`, and descending into it yields the payload.
//
// The extractor had this rule and the panel walk did not, which is the usual shape — one path gets
// fixed, its twin keeps the defect, and nothing connects them. So the rule lives here once, and both
// ask it the same question.
//
// Both checks are kept, because they fail differently. Rejecting the component catches a malformed
// name whatever it would resolve to; the containment test catches spellings not thought of here,
// including an absolute name and anything a symlink in the destination would redirect.

import Foundation

public enum PathContainment {

    /// Is `name` usable as a single path component — not a traversal, not empty, not a path itself?
    public static func isSafeComponent(_ name: String) -> Bool {
        !name.isEmpty && name != ".." && name != "." && !name.contains("/")
    }

    /// Is `candidate` really inside `root`?
    ///
    /// Resolved first, because the destination is usually reached through a symlink (`/var` →
    /// `/private/var`) and a textual prefix test would wrongly say no. `root` itself counts as inside.
    public static func isInside(_ candidate: URL, root: URL) -> Bool {
        let resolved = candidate.standardizedFileURL.resolvingSymlinksInPath().standardizedFileURL
        let base = root.standardizedFileURL.resolvingSymlinksInPath().standardizedFileURL
        guard resolved != base else { return true }
        return resolved.path.hasPrefix(base.path.hasSuffix("/") ? base.path : base.path + "/")
    }

    /// Where `name` may be written under `parent`, or nil if it must not be written at all.
    ///
    /// `root` is the folder the user actually chose; `parent` is the level currently being walked,
    /// which is at or below it. Callers skip a nil rather than failing the whole operation — refusing
    /// one crafted member must not abandon the honest ones beside it.
    public static func childURL(_ name: String, under parent: URL, root: URL) -> URL? {
        guard isSafeComponent(name) else { return nil }
        let candidate = parent.appendingPathComponent(name)
        return isInside(candidate, root: root) ? candidate : nil
    }

    /// `childURL` for the call sites that carry paths as strings.
    public static func childPath(_ name: String, under parent: String, root: String) -> String? {
        childURL(name, under: URL(fileURLWithPath: parent), root: URL(fileURLWithPath: root))?.path
    }
}
