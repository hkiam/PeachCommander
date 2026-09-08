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
    ///
    /// - Parameters:
    ///   - control: Checked before each item, so a recursive run over a large tree can be paused or
    ///     called off. Cancelling returns the counts as they stand rather than throwing: the items
    ///     already done are done, and a chmod cannot be taken back by unwinding.
    ///   - progress: Reported per item, with a total counted up front the way `DeleteEngine` counts
    ///     one. Recursive over a home folder this walk runs for minutes, and it used to run with no
    ///     way to see it or stop it.
    @discardableResult
    public static func apply(posixMode: UInt16?, modified: Date?,
                             bsdFlags: UInt32? = nil, ownerName: String? = nil, groupName: String? = nil,
                             to paths: [VFSPath],
                             on fs: VirtualFileSystem, recursive: Bool = false,
                             control: OperationControl? = nil,
                             progress: (@Sendable (OpProgress) -> Void)? = nil) async -> (changed: Int, failed: Int) {
        let attrs = VFSAttributes(posixMode: posixMode, modified: modified,
                                  bsdFlags: bsdFlags, ownerName: ownerName, groupName: groupName)
        var state = OpProgress()
        if progress != nil, recursive {
            state.filesTotal = await countItems(paths, on: fs)
        } else if progress != nil {
            state.filesTotal = paths.count
        }
        progress?(state)

        var changed = 0, failed = 0
        for path in paths {
            let (c, f) = await applyOne(attrs, to: path, on: fs, recursive: recursive,
                                        control: control, progress: progress, state: &state)
            changed += c; failed += f
        }
        return (changed, failed)
    }

    /// How many items the walk will visit. Only asked for when somebody is watching: it is a second
    /// pass over the tree, which is the whole cost of this operation.
    private static func countItems(_ paths: [VFSPath], on fs: VirtualFileSystem) async -> Int {
        var count = 0
        for path in paths {
            count += 1
            guard let entry = try? await fs.stat(path), entry.kind == .directory else { continue }
            var children: [VFSPath] = []
            if let batches = try? await collect(fs.list(path)) {
                for e in batches where PathContainment.isSafeComponent(e.name) {
                    children.append(path.joining(e.name))
                }
            }
            count += await countItems(children, on: fs)
        }
        return count
    }

    private static func collect(_ stream: AsyncThrowingStream<VFSEntryBatch, Error>) async throws -> [VFSEntry] {
        var out: [VFSEntry] = []
        for try await batch in stream {
            out += batch.entries.filter { $0.name != ".." && $0.name != "." }
        }
        return out
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
                                 recursive: Bool, control: OperationControl?,
                                 progress: (@Sendable (OpProgress) -> Void)?,
                                 state: inout OpProgress) async -> (Int, Int) {
        var changed = 0, failed = 0
        if let control {
            // Between items, not inside one: a `setAttributes` is a single syscall and there is
            // nothing to interrupt in the middle of it.
            do { try await control.checkpoint() } catch { return (0, 0) }
        }

        if recursive, let entry = try? await fs.stat(path), entry.kind == .directory {
            do {
                for try await batch in fs.list(path) {
                    for e in batch.entries where e.name != ".." && e.name != "." {
                        // The name comes out of a listing, which for a server or a plugin mount is
                        // whatever the far side chose to send. A name with a separator in it would
                        // put the change on something outside the tree the user selected.
                        guard PathContainment.isSafeComponent(e.name) else { failed += 1; continue }
                        let (c, f) = await applyOne(attrs, to: path.joining(e.name), on: fs,
                                                    recursive: true, control: control,
                                                    progress: progress, state: &state)
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
        if progress != nil {
            state.filesDone += 1
            state.currentItem = path.lastComponent()
            progress?(state)
        }
        return (changed, failed)
    }
}
