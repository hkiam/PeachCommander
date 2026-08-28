// SPDX-License-Identifier: Apache-2.0
// MacroSeed.swift — the example macros the app ships with (F-478).
//
// Kept here rather than as a string literal in the window controller for one reason that matters: a
// shipped example that names a tool the catalogue does not have, or leaves out a required argument,
// is a macro that appears in the Command Browser and fails on its first run. As data in this module
// it is validated by `MacroPlan.problems(of:)` in a unit test, against the same catalogue the runner
// uses — so the examples cannot rot when a tool is renamed.
//
// The file is written once, when the user first opens the macro editor, and is theirs afterwards:
// nothing here overwrites an existing `macros.json`.
//
// **English, deliberately.** `macros.json` is a file of tool names and argument templates — the tool
// names are English and cannot be otherwise, so a German title above an English `set_selection` would
// translate the half that needs it least. The Help Book explains the examples in all nineteen
// languages; this file explains the *shape* next to the thing it describes.
//
// Every entry carries a `_comment`, which the decoder ignores (unknown keys are dropped by the
// synthesized `Codable`). JSON has no comments and this is the one form the format allows — the same
// trick the `.mnu` and `usercmd.ini` seeds use with `;`.

import Foundation

public enum MacroSeed {

    /// The seed file's exact text, ready to write to `macros.json`.
    ///
    /// Hand-written rather than encoded from `Macro` values: the `_comment` entries are the point of
    /// the file, and an encoder would drop every one of them.
    public static let json = """
    [
      {
        "id": "_readme",
        "title": "How this file works (delete this entry)",
        "steps": [],
        "_comment": [
          "A macro is a list of steps. Each step names a tool and the arguments to call it with,",
          "and the macros below are working examples — change them, or delete the ones you do not",
          "want. An entry with no steps (like this one) is ignored.",
          "",
          "Each macro becomes a command called mc_<id>, so it can go on a button, in the Start menu,",
          "or on a key — see 'Configuration > Edit Shortcuts'. 'Configuration > Command Browser'",
          "lists every tool a step may name.",
          "",
          "Placeholders in an argument:",
          "  %P  the active panel's folder        %T  the other panel's folder",
          "  %N  the file under the cursor        %S  the selected files (a list)",
          "  %{date:yyyy-MM}  the date the macro started, in that format",
          "  %{1}  the result of step 1, when that step produced a path or a list of paths",
          "  %{1.destination}  one named value out of step 1's result",
          "  %{ask:Folder name=Archive}  asks you when the macro runs; 'Archive' is the default",
          "",
          "Two rules worth knowing before you write your own:",
          "  * A step whose %S or %{1} comes out EMPTY stops the macro instead of running with",
          "    nothing to act on. A move with no files is not a smaller move.",
          "  * A macro is held to the most demanding thing in it: one that ends in a permanent",
          "    delete is gated like a permanent delete, before any of it runs."
        ]
      },
      {
        "id": "todays-folder",
        "title": "Open today's folder",
        "icon": "calendar.badge.plus",
        "_comment": [
          "The smallest useful macro: make today's folder in the active panel and go into it.",
          "Creating a folder that is already there is not an error, so this doubles as 'go to",
          "today' on the second run. Change %P to %T to work in the other panel instead."
        ],
        "steps": [
          { "tool": "make_directory", "arguments": { "path": "%P/%{date:yyyy-MM-dd}" } },
          { "tool": "open_path",      "arguments": { "path": "%P/%{date:yyyy-MM-dd}" } }
        ]
      },
      {
        "id": "stage-by-month",
        "title": "File the selection into a dated folder",
        "icon": "calendar",
        "_comment": [
          "The classic tidy-up: every PDF in the active panel into a year-month folder on the other",
          "side. The first step selects the files, so the macro does not depend on what you had",
          "selected when you started it — and it stops if nothing matches, rather than moving the",
          "selection you happened to be holding. Change the mask to *.* to file everything."
        ],
        "steps": [
          { "tool": "set_selection",  "arguments": { "mask": "*.pdf" } },
          { "tool": "make_directory", "arguments": { "path": "%T/%{date:yyyy-MM}" } },
          { "tool": "move",           "arguments": { "sources": "%S", "destination": "%T/%{date:yyyy-MM}" } }
        ]
      },
      {
        "id": "backup-selection",
        "title": "Copy the selection to a dated backup folder",
        "icon": "doc.on.doc",
        "_comment": [
          "Copies what YOU have selected — there is no set_selection step, so the macro acts on the",
          "panel as you left it, and stops with 'nothing is selected' if you started it by mistake.",
          "The destination carries the date, so running it twice on two days keeps both copies."
        ],
        "steps": [
          { "tool": "make_directory", "arguments": { "path": "%T/Backup %{date:yyyy-MM-dd}" } },
          { "tool": "copy",           "arguments": { "sources": "%S", "destination": "%T/Backup %{date:yyyy-MM-dd}" } }
        ]
      },
      {
        "id": "sort-images",
        "title": "Move the pictures into an Images subfolder",
        "icon": "photo.on.rectangle",
        "_comment": [
          "One mask, one subfolder, in the folder you are already in. Add more masks by adding more",
          "set_selection + move pairs — set_selection REPLACES the selection each time, so two",
          "masks in a row do not accumulate.",
          "To catch more kinds of picture, run it once per mask rather than trying *.jp*g."
        ],
        "steps": [
          { "tool": "set_selection",  "arguments": { "mask": "*.jpg" } },
          { "tool": "make_directory", "arguments": { "path": "%P/Images" } },
          { "tool": "move",           "arguments": { "sources": "%S", "destination": "%P/Images" } }
        ]
      },
      {
        "id": "merge-csv",
        "title": "Merge the CSV files into one and open it",
        "icon": "tablecells",
        "_comment": [
          "Shows how one step uses what an earlier step produced. merge_files reports where it wrote",
          "the result, and %{2.destination} is that value — so the last step opens the file the",
          "second step just made, whatever it ended up being called.",
          "merge_files keeps a CSV header only once, which is why this is a CSV example."
        ],
        "steps": [
          { "tool": "set_selection", "arguments": { "mask": "*.csv" } },
          { "tool": "merge_files",   "arguments": { "sources": "%S",
                                                    "destination": "%P/merged-%{date:yyyy-MM-dd}.csv" } },
          { "tool": "open_path",     "arguments": { "path": "%{2.destination}" },
            "note": "Show the merged file in the panel" }
        ]
      },
      {
        "id": "file-into-named-folder",
        "title": "File the selection into a folder you name",
        "icon": "folder.badge.questionmark",
        "_comment": [
          "The one macro that asks. %{ask:...} puts a question to you when the macro runs, and the",
          "answer is in the plan before you approve it — so the rows say where the files are really",
          "going, not 'wherever you are about to type'.",
          "A value after '=' is what the field starts out holding. The same question asked twice is",
          "asked once and used in both places, which is why the two steps below agree.",
          "This is how you write 'move to a folder I name' without wiring the folder in."
        ],
        "steps": [
          { "tool": "make_directory", "arguments": { "path": "%T/%{ask:Folder name=Archive}" } },
          { "tool": "move",           "arguments": { "sources": "%S",
                                                     "destination": "%T/%{ask:Folder name=Archive}" } }
        ]
      },
      {
        "id": "mark-reviewed",
        "title": "Mark the file under the cursor as reviewed",
        "icon": "checkmark.seal",
        "_comment": [
          "Acts on ONE file — the one under the cursor — rather than on the selection, which is what",
          "%N is for. The tag is a macOS Finder tag (the coloured label the panel shows and Spotlight",
          "searches); the comment is stored in descript.ion beside the file and mirrored into the",
          "Finder comment, so it survives copying.",
          "Note that set_tags REPLACES the tags on the file. Add previous_tags if you want undo to",
          "restore what was there."
        ],
        "steps": [
          { "tool": "set_tags",    "arguments": { "path": "%P/%N", "tags": ["Reviewed"] } },
          { "tool": "set_comment", "arguments": { "path": "%P/%N",
                                                  "comment": "Reviewed %{date:yyyy-MM-dd}" } }
        ]
      },
      {
        "id": "clean-temp",
        "title": "Put the temporary files in the Trash",
        "icon": "trash",
        "_comment": [
          "A deleting macro, and the one to try the permission gate on: because a macro is held to",
          "the most demanding thing in it, this whole macro is gated like a delete — you are shown",
          "the two steps and asked, before either of them runs.",
          "move_to_trash is reversible; delete_permanently is the same shape and is not."
        ],
        "steps": [
          { "tool": "set_selection", "arguments": { "mask": "*.tmp" } },
          { "tool": "move_to_trash", "arguments": { "paths": "%S" } }
        ]
      }
    ]

    """

    /// The seed decoded, for the tests and for anything that wants the examples without the file.
    public static func macros() -> [Macro] {
        (try? JSONDecoder().decode([Macro].self, from: Data(json.utf8))) ?? []
    }
}
