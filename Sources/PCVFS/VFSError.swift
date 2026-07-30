// SPDX-License-Identifier: Apache-2.0
// VFSError.swift - Typed errors for the VFS layer (SPEC-006 §1).

import Foundation

public enum VFSError: Error, Sendable, Equatable {
    case notFound(String)
    case permissionDenied(needsElevation: Bool)
    case exists(String)
    case noSpace
    case connectionLost(retryable: Bool)
    case cancelled
    case unsupported
    case underlying(code: Int32, message: String)

    /// Map a POSIX errno into a VFSError.
    public static func fromErrno(_ code: Int32, path: String = "") -> VFSError {
        switch code {
        case ENOENT: return .notFound(path)
        case EACCES, EPERM: return .permissionDenied(needsElevation: code == EPERM)
        case EEXIST: return .exists(path)
        case ENOSPC: return .noSpace
        default: return .underlying(code: code, message: String(cString: strerror(code)))
        }
    }
}
