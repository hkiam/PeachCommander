// NetworkShare.swift - Normalise a typed network location into a mountable URL (TODOS #36).
//
// Accepts smb/afp/nfs/cifs URLs, Windows UNC paths (\\server\share\dir), //server/share
// and bare server/share, producing a URL the OS can mount. Pure and unit-testable;
// the actual mount is done by the app via NSWorkspace.

import Foundation

public enum NetworkShare {
    private static let schemes: Set<String> = ["smb", "afp", "nfs", "cifs"]

    /// Convert `input` to a mountable network URL, or nil if it is not a share address.
    public static func url(from input: String) -> URL? {
        var s = input.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }

        if s.hasPrefix("\\\\") {
            // UNC: \\server\share\dir → smb://server/share/dir
            s = "smb://" + s.dropFirst(2).replacingOccurrences(of: "\\", with: "/")
        } else if s.hasPrefix("//") {
            // //server/share → smb://server/share
            s = "smb:" + s
        } else if !s.contains("://") {
            // bare server/share → smb://server/share
            s = "smb://" + s
        }

        guard let url = URL(string: s), let scheme = url.scheme?.lowercased(),
              schemes.contains(scheme), let host = url.host, !host.isEmpty else {
            return nil
        }
        return url
    }
}
