// SPDX-License-Identifier: Apache-2.0
// FileWritability.swift - Why a file cannot be written, before anyone tries (F-357).
//
// The editor learned this the wrong way round: you open a file, spend ten minutes on it, press ⌘S, and
// only then find out. Sometimes that ends in the administrator prompt (F-099) and is fine; sometimes it
// cannot work at all, and the ten minutes were wasted.
//
// The four reasons a save fails are not interchangeable, and each has a different answer:
//
//   * the volume is mounted read-only — a disk image, a snapshot. Nothing helps; save elsewhere.
//   * the file is owned by somebody else, usually root — an /etc config, a launchd plist. Saving will
//     ask for authorization and then work.
//   * the file is yours but its mode says no — you can change that yourself.
//   * the file is flagged immutable, or protected by the system (SIP). `chflags` for the first; for the
//     second, not even root, and saying so beats an authorization prompt that fails anyway.
//
// Nothing here is AppKit's business, and nothing here asks the user anything: it answers a question, and
// the caller decides what to say.

import Foundation

/// Whether a file can be written, and if not, why.
public enum FileWritability: Equatable, Sendable {
    case writable
    /// The whole volume is read-only. Saving is impossible, not merely restricted.
    case readOnlyVolume
    /// Not writable by this user, and owned by someone else — saving can ask for authorization.
    case ownedByAnotherUser(owner: String)
    /// Yours, but the mode denies writing. The user can fix this without authorization.
    case permissionsDeny
    /// The immutable flag is set (`chflags uchg`/`schg`).
    case immutable
    /// System-protected (SIP, `SF_RESTRICTED`): not writable even with authorization.
    case systemProtected

    /// Whether saving through the privileged path has a chance of succeeding.
    public var administratorMayHelp: Bool {
        switch self {
        case .ownedByAnotherUser: return true
        case .writable, .readOnlyVolume, .permissionsDeny, .immutable, .systemProtected: return false
        }
    }

    public var isWritable: Bool { self == .writable }
}

public enum FileWritabilityCheck {
    // From <sys/stat.h>. Spelled out because Swift does not import all of them on every SDK, and a
    // silently missing constant here would read as "not flagged".
    private static let userImmutable: UInt32 = 0x0000_0002    // UF_IMMUTABLE
    private static let systemImmutable: UInt32 = 0x0002_0000  // SF_IMMUTABLE
    private static let systemRestricted: UInt32 = 0x0008_0000  // SF_RESTRICTED (SIP)

    /// Why `path` cannot be written, or `.writable`.
    ///
    /// Order matters: the checks run from the most absolute obstacle to the least, because that is the
    /// one worth telling the user about. A file on a read-only volume also has a mode and an owner, and
    /// reporting the mode would send them to chmod for nothing.
    public static func check(path: String) -> FileWritability {
        var fs = statfs()
        if statfs(path, &fs) == 0, fs.f_flags & UInt32(MNT_RDONLY) != 0 {
            return .readOnlyVolume
        }
        var info = stat()
        // A file that cannot be stat'ed is not this function's problem: the caller is about to fail on
        // reading it anyway, and guessing here would be worse than saying nothing.
        guard stat(path, &info) == 0 else { return .writable }
        if info.st_flags & systemRestricted != 0 { return .systemProtected }
        if info.st_flags & (userImmutable | systemImmutable) != 0 { return .immutable }
        if access(path, W_OK) == 0 { return .writable }
        if info.st_uid == geteuid() { return .permissionsDeny }
        return .ownedByAnotherUser(owner: name(ofUser: info.st_uid))
    }

    /// The owner's login name, or the numeric uid when it has none (a deleted account, a container).
    private static func name(ofUser uid: uid_t) -> String {
        guard let entry = getpwuid(uid), let name = entry.pointee.pw_name else { return String(uid) }
        return String(cString: name)
    }
}
