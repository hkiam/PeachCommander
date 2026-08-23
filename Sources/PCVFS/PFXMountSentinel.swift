// SPDX-License-Identifier: Apache-2.0
// PFXMountSentinel.swift - The sentinel path a plugin drive chip carries.
//
// Here rather than in PCApp because it is a `Volume` concern: `VolumeKind` already classifies by
// this prefix, and the two reading the format from different places is how they drift. Also the
// only way it can have a unit test — PCApp is the application target and no test bundle links it.

import Foundation

/// The `pfxmount:` sentinel path a plugin drive chip carries, and how to read it back.
///
/// It used to be `pfxmount:<pluginId>` and nothing else, which loses which *volume* was clicked — and
/// `driveBar.onSelect` hands on the path and nothing else, so by the time anything could act on the
/// click the identity was already gone. A plugin with one volume never noticed; a plugin with a chip
/// per saved connection could only ever open its own dialog.
///
/// The volume id is appended after a `#`, percent-encoded. The encoding is what makes the split
/// unambiguous: both fields may contain almost anything — the plugin id is a bundle path, the volume
/// id is a plugin-chosen token — but an encoded volume id contains no `#`, so splitting on the LAST
/// one is exact.
///
/// A sentinel with no `#` still parses, with no volume id. Not compatibility for its own sake:
/// `session.ini` stores these, so a session written by an earlier build restores through here and
/// must restore rather than be thrown away.
public enum PFXMountSentinel {
    public static let prefix = "pfxmount:"

    public static func make(pluginId: String, volumeId: String) -> String {
        guard !volumeId.isEmpty else { return prefix + pluginId }
        let encoded = volumeId.addingPercentEncoding(
            withAllowedCharacters: CharacterSet.alphanumerics) ?? volumeId
        return prefix + pluginId + "#" + encoded
    }

    /// Returns nil for a path that is not a plugin-drive sentinel at all.
    public static func parse(_ path: String) -> (pluginId: String, volumeId: String?)? {
        guard path.hasPrefix(prefix) else { return nil }
        let body = String(path.dropFirst(prefix.count))
        guard let hash = body.lastIndex(of: "#") else { return (body, nil) }
        let pluginId = String(body[body.startIndex..<hash])
        let encoded = String(body[body.index(after: hash)...])
        let volumeId = encoded.removingPercentEncoding ?? encoded
        return (pluginId, volumeId.isEmpty ? nil : volumeId)
    }
}
