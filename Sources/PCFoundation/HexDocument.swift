// SPDX-License-Identifier: Apache-2.0
// HexDocument.swift - Editable byte buffer with undo/redo for the hex editor (TODOS #26).
//
// Backs the hex editor: overwrite, insert and delete bytes, each recorded as a
// reversible replace so undo/redo work. `isModified` compares against the loaded
// bytes; `bytes` is what the editor writes back (after a .bak backup). Pure and
// fully unit-testable. (An array buffer — fine for the sizes a hex editor handles;
// a piece table can replace it later for very large files.)

import Foundation

public final class HexDocument {
    private(set) public var bytes: [UInt8]
    private var original: [UInt8]

    private struct Edit { let range: Range<Int>; let old: [UInt8]; let new: [UInt8] }
    private var undoStack: [Edit] = []
    private var redoStack: [Edit] = []

    public init(_ bytes: [UInt8]) {
        self.bytes = bytes
        self.original = bytes
    }

    public var count: Int { bytes.count }
    public var isModified: Bool { bytes != original }

    /// Bumped by every edit, including undo and redo.
    ///
    /// The editor's `onChange` fires for selection and caret movement too, so "did the
    /// bytes change" is not answerable from it — and anything derived from the bytes (the
    /// strings panel) would either recompute on every arrow key or go quietly stale. A
    /// counter is the cheap honest answer; comparing buffers is not (they can be large, and
    /// an edit that restores an earlier value is still an edit).
    public private(set) var revision = 0
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public func byte(at index: Int) -> UInt8? {
        bytes.indices.contains(index) ? bytes[index] : nil
    }

    /// Whether the byte at `index` differs from the loaded/last-saved content at the
    /// same offset — used to highlight edits until saved. Positional: bytes past the
    /// original length (or after an insert shifts everything) count as changed, which
    /// matches "this offset no longer holds what the file has on disk".
    public func isChanged(at index: Int) -> Bool {
        guard index >= 0, index < bytes.count else { return false }
        guard index < original.count else { return true }
        return bytes[index] != original[index]
    }

    /// Reset the change baseline to the current bytes (call after a successful save)
    /// so `isModified`/`isChanged` clear. Undo history is preserved.
    public func markSaved() { original = bytes }

    /// General edit: replace `range` with `new` (records undo, clears redo).
    public func replace(_ range: Range<Int>, with new: [UInt8]) {
        let clamped = clamp(range)
        let old = Array(bytes[clamped])
        guard old != new else { return }
        bytes.replaceSubrange(clamped, with: new)
        undoStack.append(Edit(range: clamped, old: old, new: new))
        redoStack.removeAll()
        revision += 1
    }

    /// Overwrite bytes starting at `offset`, extending the buffer if `new` runs past the end.
    public func overwrite(at offset: Int, with new: [UInt8]) {
        guard offset >= 0, offset <= bytes.count, !new.isEmpty else { return }
        let end = Swift.min(offset + new.count, bytes.count)
        replace(offset..<end, with: new)
    }

    /// Insert `new` before `offset`.
    public func insert(at offset: Int, _ new: [UInt8]) {
        guard offset >= 0, offset <= bytes.count, !new.isEmpty else { return }
        replace(offset..<offset, with: new)
    }

    /// Delete the bytes in `range`.
    public func delete(_ range: Range<Int>) {
        let clamped = clamp(range)
        guard !clamped.isEmpty else { return }
        replace(clamped, with: [])
    }

    public func undo() {
        guard let edit = undoStack.popLast() else { return }
        // After applying, `new` occupies [lowerBound, lowerBound + new.count). Restore `old`.
        let placed = edit.range.lowerBound ..< (edit.range.lowerBound + edit.new.count)
        bytes.replaceSubrange(placed, with: edit.old)
        redoStack.append(edit)
        revision += 1
    }

    public func redo() {
        guard let edit = redoStack.popLast() else { return }
        bytes.replaceSubrange(edit.range, with: edit.new)
        undoStack.append(edit)
        revision += 1
    }

    private func clamp(_ range: Range<Int>) -> Range<Int> {
        let lo = Swift.max(0, Swift.min(range.lowerBound, bytes.count))
        let hi = Swift.max(lo, Swift.min(range.upperBound, bytes.count))
        return lo..<hi
    }
}
