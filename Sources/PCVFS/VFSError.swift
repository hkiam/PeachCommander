// SPDX-License-Identifier: Apache-2.0
// VFSError.swift - Typed errors for the VFS layer (SPEC-006 §1).

import Foundation

public enum VFSError: Error, Sendable, Equatable {
    case notFound(String)
    case permissionDenied(Refusal)
    case exists(String)
    case noSpace
    case connectionLost(retryable: Bool)
    case cancelled
    case unsupported
    case underlying(code: Int32, message: String)

    /// Which of the kernel's two refusals a `permissionDenied` was.
    ///
    /// This used to be `needsElevation: Bool`, and the name claimed something the value never said. It
    /// records `errno`, nothing more — and it was read by exactly one caller, for exactly that. The
    /// question of whether administrator rights would help is answered elsewhere and properly, by
    /// `FileWritability.administratorMayHelp`, which looks at the file rather than guessing from a
    /// refusal. Worse, on macOS the EPERM case is usually the privacy gate, where elevation is the one
    /// thing that cannot help — so the old name pointed at the wrong remedy exactly when it mattered
    /// (F-449).
    public enum Refusal: Sendable, Equatable {
        /// EACCES — the mode bits said no.
        case modeBits
        /// EPERM — refused for a reason the mode bits do not express. On macOS usually the privacy
        /// gate; `PrivateLocation` is what tells that apart from an ordinary refusal.
        case notPermitted
    }

    /// Map a POSIX errno into a VFSError.
    public static func fromErrno(_ code: Int32, path: String = "") -> VFSError {
        switch code {
        case ENOENT: return .notFound(path)
        case EACCES, EPERM: return .permissionDenied(code == EPERM ? .notPermitted : .modeBits)
        case EEXIST: return .exists(path)
        case ENOSPC: return .noSpace
        default: return .underlying(code: code, message: String(cString: strerror(code)))
        }
    }
}
