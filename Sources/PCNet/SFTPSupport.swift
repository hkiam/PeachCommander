// SPDX-License-Identifier: Apache-2.0
// SFTPSupport.swift - libssh2 integration probe + shared helpers (F-214).

import Foundation
import CSSH2

public enum SFTPSupport {
    /// The linked libssh2 version string — proves the C module compiles, links,
    /// and the dylib loads at runtime.
    public static func libssh2Version() -> String {
        guard let c = libssh2_version(0) else { return "" }
        return String(cString: c)
    }
}
