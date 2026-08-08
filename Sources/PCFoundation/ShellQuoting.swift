// SPDX-License-Identifier: Apache-2.0
// ShellQuoting.swift - Putting an untrusted name into a shell command line (F-252).
//
// Three places in this app build a command line out of a file name and hand it to a shell: the elevated
// save, the toolbar buttons, and the user (Start-menu) commands. A file name is untrusted input — it
// comes from a download, an extracted archive, a shared volume — and every one of those places needs the
// same answer to the same question, so there is one implementation of it here.
//
// Single quotes, not double. Inside double quotes a shell still performs command substitution and
// variable expansion, so `"$(id)"` runs `id`; inside single quotes nothing is interpreted at all, and
// the only character that needs care is the single quote itself. `'` is closed, escaped and reopened:
//   it's here   →   'it'\''s here'
//
// This was not academic. The %-parameter expander quoted a value only when it contained *whitespace*, so
// a file called `$(id).txt` — a perfectly legal macOS name — went into the command line raw, and running
// any user-defined command on that folder executed it.

import Foundation

public enum ShellQuoting {
    /// `value` as a single shell word: safe to interpolate into a command line for `/bin/sh -c`.
    ///
    /// Always quoted, including for names that look harmless. A rule of "quote only when it looks
    /// necessary" is a rule somebody has to get right for every character a shell treats specially, and
    /// the version of that rule this app had listed exactly one of them.
    public static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
