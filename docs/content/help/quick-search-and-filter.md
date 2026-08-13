---
title: Quick search & filter
slug: quick-search-and-filter
section: Organizing your view
order: 44
related: [searching, view-modes-and-sorting]
---

When a folder holds hundreds of items, you rarely need to scroll. Peach Commander lets you jump straight to a file by typing its name (quick search), pare the list down to just the items you care about (quick filter), and reveal or hide the dotfiles macOS normally keeps out of sight. All three work inside the active panel without opening a dialog.

## Jump to a file by typing (quick search)

1. Click a file panel so it is active.
2. Start typing the beginning of a name. The cursor jumps to the first matching item.
3. Keep typing to refine the match, or press the same letter again to cycle through items that start with that letter.
4. What you have typed appears above the panel, together with which match you are on and how many there are — for example `⌕ re  2/3`. It turns red when nothing matches.
5. Press Backspace to take back the last letter, or Esc to end the search. Backspace only edits the search while one is running; at any other time it still goes to the parent folder.
6. The search ends on its own after a couple of seconds without typing, so you can start a new one at any time.

By default, plain letters go to the command line and quick search is triggered with Ctrl+Option+letter (the classic behavior). You can switch quick search to respond to plain typing instead, or turn it off, in Configuration settings.

## Filter the list (quick filter)

1. In the active panel, press Ctrl+S to turn on the quick filter.
2. Type a filter mask. The panel narrows live to matching items as you type.
3. Press Esc to clear the filter and show everything again.

The filter accepts several kinds of masks:

- **Plain text** matches any name that contains what you typed (for example, `report` shows every item with "report" anywhere in its name).
- **Wildcards** use `*` (any characters) and `?` (one character). Separate several masks with a semicolon and add exclusions after a vertical bar, for example `*.jpg;*.png|*thumb*` to show images but hide thumbnails.
- **Finder tags** filter by tag color: type `tag:red` (or `#red`) to show only red-tagged items, or a bare `tag:` to show everything that carries any tag.

## Show hidden files

Press Ctrl+H, or choose the command from the View menu, to toggle hidden items (names beginning with a dot and system-hidden files). The setting applies to the active panel and is remembered between sessions.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Quick search (classic mode) | Ctrl+Option+letter |
| Quick filter on/off | Ctrl+S |
| Clear filter / cancel | Esc |
| Show/hide hidden files | Ctrl+H |

## Notes

- Quick search only moves the cursor; quick filter actually changes which items are listed. Use the filter when you want to work on a subset (for example, select or copy only the matches).
- The filter and hidden-files settings are per panel, so the two sides can show different things at once.
- Quick search matches names from the start; quick filter's plain-text mode matches anywhere in the name. Use a wildcard like `*text*` if you want the filter to behave the same way.
