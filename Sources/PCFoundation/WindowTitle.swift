// SPDX-License-Identifier: Apache-2.0
// WindowTitle.swift - What the main window is called (F-012).
//
// The row promised "window title shows active path; option % free space". The title was assigned once
// at startup — the literal string "Peach Commander" — and never touched again, so it said nothing
// about where you were. That matters more than it sounds: the title is what Mission Control, the
// window menu and Cmd-Tab show, and with two windows open on two folders they were indistinguishable.
//
// Here rather than in the window controller because it is a question about text, and the interesting
// parts are the edges: a path inside the home folder, the home folder itself, the root, and a volume
// that will not say how big it is.

import Foundation

public enum WindowTitle {

    /// The window title for `path`, optionally with the volume's free space.
    ///
    /// `home` is passed in rather than read from the environment so the abbreviation can be checked
    /// without depending on whose machine the test runs on.
    public static func text(path: String,
                            appName: String = "Peach Commander",
                            home: String = NSHomeDirectory(),
                            freeSpace: Int64? = nil,
                            capacity: Int64? = nil,
                            showFreeSpace: Bool = false,
                            locale: Locale = .current) -> String {
        let shown = abbreviate(path, home: home)
        guard !shown.isEmpty else { return appName }

        var title = shown
        if showFreeSpace, let freeSpace, freeSpace >= 0 {
            var part = ByteSize(freeSpace).formatted(style: .mb, locale: locale) + " free"
            // The percentage only when there is a capacity to be a percentage *of*: a network mount
            // that will not answer reports zero, and "0 % free" is worse than saying nothing.
            if let capacity, capacity > 0 {
                let percent = Int((Double(freeSpace) / Double(capacity) * 100).rounded())
                part += " (\(percent) %)"
            }
            title += " — " + part
        }
        return title
    }

    /// `path` with the home directory replaced by `~`, the way the Finder and the shell write it.
    ///
    /// Only a real prefix counts: `/Users/maiko` must not become `~o` because it starts with
    /// `/Users/maik`. The home folder itself is `~`, and the root stays `/`.
    public static func abbreviate(_ path: String, home: String = NSHomeDirectory()) -> String {
        guard !home.isEmpty, path == home || path.hasPrefix(home + "/") else { return path }
        return path == home ? "~" : "~" + path.dropFirst(home.count)
    }
}
