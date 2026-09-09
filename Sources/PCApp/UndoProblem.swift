// SPDX-License-Identifier: Apache-2.0
// UndoProblem.swift - What an undo could not do.
//
// Every closure on the operation-undo stack used to swallow its failures behind `try?`, and
// `undoLastOperation` popped the entry either way. So a ⌘Z that could not put a file back — because
// something is at that path again, or the Trash entry is gone — looked exactly like one that had
// worked, and the entry was spent. One reason and one path per item, in the shape
// `ErrorLogWindowController` already takes, which is the window F-089 opens for a partly failed
// operation.

import Foundation

struct UndoProblem: Sendable, Equatable {
    let path: String
    let reason: String
}
