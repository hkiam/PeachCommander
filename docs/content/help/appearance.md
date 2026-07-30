---
title: Appearance
slug: appearance
section: Customizing
order: 114
related: [settings]
---

Peach Commander can match the look of the rest of your Mac or take on a style of its own. You can follow the system light or dark setting (or force one), recolor the file panels, highlight files by type, and adjust the list font size and date format so the panels read exactly the way you like.

## Set light, dark, or system appearance

1. Open the settings window by choosing Configuration > Options…, or press Cmd+,.
2. Select the **Colors** page.
3. From the **Appearance** menu, choose one of:
   - **System (follow macOS)** — matches your Mac's current light/dark setting automatically.
   - **Light** — always use the light palette.
   - **Dark** — always use the dark palette.

![Colors settings page showing the Appearance menu and custom panel color wells](screenshots/settings-colors.png)
*(Figure: The Colors page: choose an appearance and override individual panel colors.)*

## Customize panel colors

On the same **Colors** page, under **Custom panel colors**, turn on the checkbox next to any element and pick a color from the well beside it:

- **Text** — the file and folder names.
- **Background** — the panel background.
- **Selected text** — the color used for marked files.
- **Cursor frame** — the outline around the current item.

Leave a checkbox off to keep the built-in color for that element. Click **Reset to defaults** to clear all overrides at once.

## Color files by type

1. Open Configuration > Options… and select the **Display** page.
2. Click **File-Type Colors…**.
3. Add a rule with a name mask such as `*.zip` or `*.txt`, then pick a color for files that match it.
4. Use **Add Rule** for more masks; click **Done** to save or **Cancel** to discard.

Matching files then appear in your chosen color in both panels.

## Adjust font size and date format

On the **Display** page you can also:

- Choose the panel list **Font size** in points.
- Enter a **Date format** pattern to control how modification dates are shown; leave it empty to use your Mac's regional format. A live preview appears below the field as you type.
- Turn on **Alternating row background** for zebra striping that makes long lists easier to scan.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Open settings | Cmd+, |

## Notes

- The Appearance setting styles the file panels. System dialogs, alerts, and standard controls always follow macOS.
- The built-in file viewer uses matching light and dark syntax-highlighting palettes, so highlighted code stays readable in either appearance.
- Custom colors and file-type rules are saved with your settings and reapplied every time you open the app.
