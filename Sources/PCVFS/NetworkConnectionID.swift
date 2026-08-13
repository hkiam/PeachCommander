// SPDX-License-Identifier: Apache-2.0
// NetworkConnectionID.swift - Turning a mount's connection id into a drive-chip name.
//
// A file-system plugin's connect is interactive, and the only thing it hands back about the server
// is an id of its own devising — "webdav:files.example.org" — which the host also uses to qualify
// the mount's saved columns. When such a connection became a drive of its own, that id was suddenly
// something a user reads off a chip, so it needs splitting: the chip has room for the host, and
// repeating "webdav:" in front of it says what the chip's kind already says.
//
// Here rather than in the drive bar because it is a rule about a string, and the interesting part is
// what it does with the ids that are not the expected shape — those are what a plugin author gets
// wrong, and an empty chip cannot be clicked or told from its neighbour.

import Foundation

public enum NetworkConnectionID {

    /// Split `id` into the name a chip shows and the kind it is, or a nil kind when the id carries
    /// no scheme to take one from (the caller supplies its own wording for that case).
    ///
    /// * `"webdav:files.example.org"` → `("files.example.org", "WebDAV")`
    /// * `"files.example.org"` → `("files.example.org", nil)` — no scheme to strip
    /// * `"webdav:"` → `("webdav:", nil)` — stripping would leave nothing to show
    /// * `"webdav:host:8080/pub"` → `("host:8080/pub", "WebDAV")` — split once, so a port or a
    ///   path with colons in it stays with the name it belongs to
    public static func split(_ id: String) -> (name: String, kind: String?) {
        let parts = id.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[1].isEmpty, !parts[0].isEmpty else { return (id, nil) }
        return (parts[1], displayKind(forScheme: parts[0]))
    }

    /// The scheme as a name worth showing. Upper-cased by default, because these are acronyms
    /// (FTP, SFTP, SCP) — with the ones that are not spelled out rather than shouted.
    private static func displayKind(forScheme scheme: String) -> String {
        switch scheme.lowercased() {
        case "webdav": return "WebDAV"
        case "icloud": return "iCloud"
        default: return scheme.uppercased()
        }
    }
}
