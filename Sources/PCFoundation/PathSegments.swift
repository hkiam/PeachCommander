// SPDX-License-Identifier: Apache-2.0
// PathSegments.swift - The breadcrumbs in the path bar (F-007).
//
// Split out of the view because this decides *where a click navigates*, which is worth a test, and the
// view around it pulls in the theme and the tracking areas.

import Foundation

public enum PathSegments {
    /// Break a path into cumulative breadcrumb segments.
    ///
    /// `"/Users/maik1"` → `[("/", "/"), ("Users", "/Users"), ("maik1", "/Users/maik1")]`.
    ///
    /// Doubled separators collapse and a trailing one is ignored, so `//Users//maik1/` gives the same
    /// three segments as the plain form — those arise from joining paths and must not produce a
    /// breadcrumb that navigates somewhere else.
    ///
    /// The input is always a file-system path, never a URL: an `smb://…` address is handed to the
    /// system to mount, and the panel then shows the `/Volumes/…` path it appears at. (Checked, because
    /// a URL *would* come apart here — "smb:" would become a segment.)
    public static func make(_ path: String) -> [(name: String, path: String)] {
        guard !path.isEmpty else { return [] }
        if path == "/" { return [("/", "/")] }
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        var segs: [(String, String)] = []
        let absolute = trimmed.hasPrefix("/")
        if absolute { segs.append(("/", "/")) }
        var cumulative = absolute ? "" : "."
        for comp in trimmed.split(separator: "/") {
            cumulative += "/" + comp
            segs.append((String(comp), cumulative))
        }
        return segs
    }
}
