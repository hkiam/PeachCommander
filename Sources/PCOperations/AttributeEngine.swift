// SPDX-License-Identifier: Apache-2.0
// AttributeEngine.swift - Apply permission/date changes over the VFS (SPEC-016 §2).
//
// Sets POSIX permissions and/or the modification date on a set of paths, optionally
// recursing into directories, via VirtualFileSystem.setAttributes. Reports how many
// items were changed vs. failed.

import Foundation
import PCFoundation
import PCVFS

public enum AttributeEngine {
    /// Apply the given attributes (any nil field is left unchanged) to `paths`.
    /// When `recursive`, directory trees are descended and every item updated.
    /// Returns (#changed, #failed).
    @discardableResult
    public static func apply(posixMode: UInt16?, modified: Date?,
                             bsdFlags: UInt32? = nil, ownerName: String? = nil, groupName: String? = nil,
                             to paths: [VFSPath],
                             on fs: VirtualFileSystem, recursive: Bool = false) async -> (changed: Int, failed: Int) {
        let attrs = VFSAttributes(posixMode: posixMode, modified: modified,
                                  bsdFlags: bsdFlags, ownerName: ownerName, groupName: groupName)
        var changed = 0, failed = 0
        for path in paths {
            let (c, f) = await applyOne(attrs, to: path, on: fs, recursive: recursive)
            changed += c; failed += f
        }
        return (changed, failed)
    }

    private static func applyOne(_ attrs: VFSAttributes, to path: VFSPath, on fs: VirtualFileSystem,
                                 recursive: Bool) async -> (Int, Int) {
        var changed = 0, failed = 0
        do { try await fs.setAttributes(path, attributes: attrs); changed += 1 } catch { failed += 1 }

        if recursive, let entry = try? await fs.stat(path), entry.kind == .directory {
            do {
                for try await batch in fs.list(path) {
                    for e in batch.entries where e.name != ".." && e.name != "." {
                        let (c, f) = await applyOne(attrs, to: path.joining(e.name), on: fs, recursive: true)
                        changed += c; failed += f
                    }
                }
            } catch { /* partial application is reported via counts */ }
        }
        return (changed, failed)
    }
}
