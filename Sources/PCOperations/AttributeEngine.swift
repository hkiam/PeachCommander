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

    /// Children first, then the item itself.
    ///
    /// The other way round is what `chmod -R` does and it cannot work here: applying a mode that
    /// takes away the folder's own execute bit — 0400 is an ordinary thing to ask for — makes the
    /// listing that comes next impossible, and the descent then finds nothing. Measured before this
    /// was turned round: `chmod -R 400` over a folder with a file in a subfolder changed the top
    /// folder, left everything below it untouched, and reported "1 changed, 0 failed". The user asked
    /// for a recursive change and was told they got one.
    ///
    /// Post-order also means a directory whose listing failed is *not* reported as changed, because
    /// its own `setAttributes` still runs and the failure of the walk is counted on its own.
    private static func applyOne(_ attrs: VFSAttributes, to path: VFSPath, on fs: VirtualFileSystem,
                                 recursive: Bool) async -> (Int, Int) {
        var changed = 0, failed = 0

        if recursive, let entry = try? await fs.stat(path), entry.kind == .directory {
            do {
                for try await batch in fs.list(path) {
                    for e in batch.entries where e.name != ".." && e.name != "." {
                        // The name comes out of a listing, which for a server or a plugin mount is
                        // whatever the far side chose to send. A name with a separator in it would
                        // put the change on something outside the tree the user selected.
                        guard PathContainment.isSafeComponent(e.name) else { failed += 1; continue }
                        let (c, f) = await applyOne(attrs, to: path.joining(e.name), on: fs, recursive: true)
                        changed += c; failed += f
                    }
                }
            } catch {
                // Counted, not swallowed: a walk that could not be finished means items were left
                // alone, and the comment that used to be here said the counts reported that when
                // nothing added to them.
                failed += 1
            }
        }

        do { try await fs.setAttributes(path, attributes: attrs); changed += 1 } catch { failed += 1 }
        return (changed, failed)
    }
}
