// SPDX-License-Identifier: Apache-2.0
// Quarantine.swift - Clearing com.apple.quarantine from an installed plugin (F-482).
//
// Everything a browser, a mail client or an archive utility writes carries the quarantine
// extended attribute. For an ordinary document that is a prompt the user answers once; for a
// dylib the host is about to `dlopen`, it is Gatekeeper refusing the load outright once the app
// itself is signed and notarized — with an error that says nothing a user can act on.
//
// This is deliberately NOT done as part of unpacking. It runs only after the install prompt has
// told the user, in plain words, what a plugin is allowed to do and they have said yes: removing
// the attribute is exactly the moment the user's decision replaces Gatekeeper's, and it should
// not be reachable any other way. SPEC-012 §8 asked for the flag to be respected; this is the
// respecting of it — surfaced, then cleared on consent, rather than silently stripped or
// silently fatal.
//
// Implemented with removexattr(2) rather than `xattr -d -r`: no shell, no argument quoting, and
// a failure on one file does not abandon the rest of the tree.

import Foundation

public enum Quarantine {
    public static let attributeName = "com.apple.quarantine"

    /// Whether `url` — or, for a directory, anything inside it — carries the quarantine attribute.
    public static func isQuarantined(_ url: URL) -> Bool {
        for item in tree(of: url) where hasAttribute(item) { return true }
        return false
    }

    /// Remove the quarantine attribute from `url` and everything below it.
    ///
    /// Returns the number of items cleared. Best effort by design: a plugin bundle can contain a
    /// file whose attribute cannot be removed (a stale ACL, a read-only copy), and refusing to
    /// clear the other ninety-nine would leave the plugin just as unloadable.
    @discardableResult
    public static func clear(_ url: URL) -> Int {
        var cleared = 0
        for item in tree(of: url) where hasAttribute(item) {
            if item.withUnsafeFileSystemRepresentation({ path -> Bool in
                guard let path else { return false }
                // XATTR_NOFOLLOW: a symlink inside the bundle must have *its own* attribute
                // cleared, never the attribute of whatever it points at outside the bundle.
                return removexattr(path, attributeName, XATTR_NOFOLLOW) == 0
            }) {
                cleared += 1
            }
        }
        return cleared
    }

    private static func hasAttribute(_ url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path -> Bool in
            guard let path else { return false }
            return getxattr(path, attributeName, nil, 0, 0, XATTR_NOFOLLOW) >= 0
        }
    }

    /// `url` itself plus, when it is a directory, everything beneath it — symlinks included and
    /// never followed.
    private static func tree(of url: URL) -> [URL] {
        var out = [url]
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return out }
        // No options: hidden files carry the attribute as readily as visible ones, and
        // `.skipsPackageDescendants` would stop at the plugin bundle itself — which is precisely
        // the directory whose contents need clearing.
        guard let en = fm.enumerator(at: url, includingPropertiesForKeys: nil) else { return out }
        for case let item as URL in en { out.append(item) }
        return out
    }
}
