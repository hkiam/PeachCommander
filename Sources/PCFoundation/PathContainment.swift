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
        let resolved = normalized(candidate)
        let base = normalized(root)
        guard resolved != base else { return true }
        return resolved.path.hasPrefix(base.path.hasSuffix("/") ? base.path : base.path + "/")
    }

    /// Resolve symlinks for the part of `url` that exists, then re-append the rest.
    ///
    /// `resolvingSymlinksInPath()` only resolves components that are there — and on macOS it *also*
    /// shortens a leading `/private`, which is where the two sides of the comparison came apart: the
    /// destination folder exists and becomes `/tmp/…`, while the file about to be written does not and
    /// keeps `/private/tmp/…`. The prefix test then says "outside", and since callers skip a refusal
    /// rather than failing loudly, **every** extraction into a folder under `/private/tmp` or
    /// `/private/var` quietly produced nothing. Measured with Foundation alone:
    ///
    ///     root  -> /tmp/pc-contain-demo/out
    ///     cand  -> /private/tmp/pc-contain-demo/out/nope.txt
    ///
    /// `/var/folders/…` — the system temp directory every app is handed — is exactly such a path, so
    /// this was not an exotic case. Normalising both sides the same way is the whole fix; it takes
    /// nothing away from the guard, because a symlink *inside* the destination is still resolved (it
    /// exists, so it is part of the resolved prefix) and a traversal is still refused by
    /// `isSafeComponent`.
    private static func normalized(_ url: URL) -> URL {
        let fm = FileManager.default
        var missing: [String] = []
        var probe = url.standardizedFileURL
        while !fm.fileExists(atPath: probe.path), probe.pathComponents.count > 1 {
            missing.append(probe.lastPathComponent)
            probe = probe.deletingLastPathComponent()
        }
        var resolved = probe.resolvingSymlinksInPath().standardizedFileURL
        for component in missing.reversed() { resolved.appendPathComponent(component) }
        return resolved.standardizedFileURL
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
