// SPDX-License-Identifier: Apache-2.0
// PrivilegedTransfer.swift - Retrying a copy or move as administrator (F-099).
//
// Deleting a root-owned file, changing its mode and saving one from the editor already offer to retry
// with administrator privileges. Copying and moving did not, which is the case a file manager runs into
// most: drop something into /Library or /usr/local and the operation stops with "permission denied" and
// no way forward.
//
// Two questions have to be answered before offering that, and both are asked of the file system rather
// than of an error message — messages are localized, and matching on their text is a bug waiting for a
// German user:
//
//   * which items did not arrive (the destination is missing and the source is still there), and
//   * whether the destination is one this user may not write to. A copy can also fail because the disk
//     is full, and offering to redo *that* as root is a way to fill it as root.
//
// What is built here is the shell line. Every path goes through `ShellQuoting`, whose composition with
// the AppleScript layer that carries the command to the authorization dialog is measured in
// ShellQuoteTests — this is the one path in the app that runs as root, and a file name is untrusted
// input.

import Foundation
import PCFoundation

public enum PrivilegedTransfer {

    /// One thing to move or copy, and where it was supposed to end up.
    public struct Item: Sendable, Equatable {
        public let source: String
        public let destination: String
        public init(source: String, destination: String) {
            self.source = source
            self.destination = destination
        }
    }

    /// The items that did not arrive: no destination, and a source still there to retry from.
    ///
    /// "Destination missing" rather than the operation's own error list, because a user who answered
    /// "skip" in the overwrite dialog left a destination that *does* exist — that is how the two are
    /// told apart without reading any message.
    public static func missing(_ items: [Item], exists: (String) -> Bool) -> [Item] {
        items.filter { !exists($0.destination) && exists($0.source) }
    }

    /// The command that retries `items`, or nil when there is nothing to retry.
    ///
    /// One shell invocation for all of them, so the user is asked for their password once rather than
    /// once per file — and the commands are separated by `;` rather than `&&` so one failure does not
    /// swallow the rest. Nothing here inspects the result: what actually arrived is read back off the
    /// disk afterwards, which is the only answer that counts.
    ///
    /// `cp -R` and not `-a`: `-a` is not in POSIX cp and macOS's own is fine with `-R -p`, which keeps
    /// mode, timestamps and ownership flags without pulling in the rest of the archive semantics.
    public static func command(for items: [Item], move: Bool) -> String? {
        guard !items.isEmpty else { return nil }
        let tool = move ? "/bin/mv" : "/bin/cp"
        let flags = move ? "-f" : "-Rp"
        return items.map { item in
            "\(tool) \(flags) \(ShellQuoting.quote(item.source)) \(ShellQuoting.quote(item.destination))"
        }.joined(separator: "; ")
    }

    /// Is this a failure administrator privileges could actually fix?
    ///
    /// Only when the destination folder is one this user cannot write to. A copy that failed because
    /// the volume is full, or because the source is unreadable, is not helped by running it as root —
    /// and offering it anyway teaches people to answer a password prompt to no purpose.
    public static func wouldPrivilegeHelp(destinationDirectory: String,
                                          isWritable: (String) -> Bool) -> Bool {
        !isWritable(destinationDirectory)
    }
}
