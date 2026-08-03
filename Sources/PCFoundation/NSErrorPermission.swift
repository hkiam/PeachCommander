// SPDX-License-Identifier: Apache-2.0
// NSErrorPermission.swift - "the user is not allowed to write this" as a question, not a number.
//
// Foundation reports a refused write in two different vocabularies depending on how deep the failure
// happened: a POSIX EPERM/EACCES, or a Cocoa NSFileWriteNoPermissionError. Callers that want to offer
// an elevated retry need both, and spelling out the pair at each call site is how one of them gets
// forgotten.

import Foundation

public extension NSError {
    /// Whether this error means "you may not write there", in either vocabulary Foundation uses.
    var isPermissionDenied: Bool {
        if domain == NSCocoaErrorDomain {
            return code == NSFileWriteNoPermissionError || code == NSFileReadNoPermissionError
        }
        if domain == NSPOSIXErrorDomain {
            return code == Int(EACCES) || code == Int(EPERM) || code == Int(EROFS)
        }
        return false
    }
}
