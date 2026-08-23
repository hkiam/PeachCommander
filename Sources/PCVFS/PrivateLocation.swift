// SPDX-License-Identifier: Apache-2.0
// PrivateLocation.swift - Telling macOS's privacy gate apart from an ordinary permission (F-445).
//
// A location macOS keeps private — iOS device backups under MobileSync, Mail, Messages, another app's
// data — answers a listing with EPERM even when the mode bits say the owner may read it. The gate is on
// the *application*, not on the user, so it is the one refusal that elevation cannot fix and the only
// one worth naming Full Disk Access for. EACCES is the ordinary case and stays ordinary.

import Foundation

public enum PrivateLocation {

    /// The decision, given what `stat` said about the directory.
    ///
    /// Separated from the file system so it can be tested: a protected location cannot be *created* for
    /// a fixture — the list is macOS's own — so the only testable form is the rule itself.
    ///
    /// `eperm` distinguishes the two refusals the kernel has. EACCES means the mode bits refused, which
    /// they are entitled to do and which says nothing about privacy. EPERM together with mode bits that
    /// *would* have allowed the read is the contradiction that only the privacy gate produces.
    public static func isPrivacyRefusal(eperm: Bool, mode: mode_t, owner: uid_t, us: uid_t) -> Bool {
        guard eperm else { return false }
        // Read *and* traverse: a directory needs both to be listed, so a missing x bit is a genuine
        // refusal by the mode rather than a contradiction.
        let readable: mode_t = owner == us ? (S_IRUSR | S_IXUSR) : (S_IROTH | S_IXOTH)
        return mode & readable == readable
    }

    /// The same question about a real directory.
    ///
    /// `stat` itself is not gated — the protected directory can be *seen*, only its contents cannot be
    /// listed, which is exactly what makes this checkable.
    public static func isPrivacyRefusal(eperm: Bool, path: String) -> Bool {
        guard eperm else { return false }
        var info = stat()
        guard lstat(path, &info) == 0 else { return false }
        return isPrivacyRefusal(eperm: true, mode: info.st_mode, owner: info.st_uid, us: getuid())
    }

    /// Whether `error` from a listing is the privacy gate rather than the file system.
    ///
    /// `VFSError.permissionDenied` carries the distinction already: `fromErrno` records `.notPermitted`
    /// for EPERM and `.modeBits` for EACCES. That payload used to be a `Bool` called `needsElevation`,
    /// which named the wrong thing — this reader was its only one, and it wanted the errno (F-449).
    public static func isPrivacyRefusal(_ error: Error, path: String) -> Bool {
        guard case VFSError.permissionDenied(let refusal) = error else { return false }
        return isPrivacyRefusal(eperm: refusal == .notPermitted, path: path)
    }
}
