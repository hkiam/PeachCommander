---
title: "Tutorial: Set up views and workspaces"
slug: tutorial-views-workspaces
group: Tutorials
section: tutorials
order: 114
related: [view-modes-and-sorting, workspaces, panels-and-tabs]
---

# Tutorial: Set up views and workspaces

Peach Commander shows two folders side by side, and almost everything about how each side looks is yours to arrange: the view mode, the sort order, which columns appear, and which folders are open as tabs. Once you have an arrangement you like, you can save the whole thing as a named workspace and bring it back with a single choice.

This tutorial walks through a realistic setup end to end. Our sample task: you are importing photos from a shoot on the left while keeping your project folders handy on the right, and you want to be able to return to exactly this layout next week. By the end you will have chosen a view mode, sorted and configured columns, opened the tabs you use, and saved it all as a workspace called "Photo import."

You do not need any files prepared in advance. Substitute your own folders wherever the steps mention a specific one.

![The main Peach Commander window with two panels side by side](screenshots/main-window.png)
*The dual-panel main window. The active panel has the highlighted title bar; new tabs and view changes always apply to it.*

## Step 1: Pick the active panel

Every view and tab change applies to the panel that is currently active, so start by choosing one.

1. Click anywhere inside the **left** panel. Its title bar highlights to show it is now active.
2. If you are ever unsure which side is active, press **Tab** to switch focus between the two panels and watch the highlight move.

We will set up the left panel as our photo-import view first.

## Step 2: Navigate the left panel to your photos

1. With the left panel active, go to the folder that holds the photos you want to review. You can double-click folders to drill in, or press **Backspace** (or double-click the `..` entry) to go up one level.
2. For this tutorial, open a folder that contains a mix of image files, for example `~/Pictures/Shoot`.

For more ways to move around, see [Navigating](navigating.md).

## Step 3: Switch the left panel to a gallery view

A grid of large thumbnails is the natural way to review photos.

1. With the left panel active, open the **View** menu.
2. Choose **Thumbnails (Gallery)**. The file list changes to large previews. (The shortcut is **Ctrl+Shift+F1**.)
3. If you want to compare modes quickly, press **Cmd+Shift+M** to cycle through Details, Brief, Icons, Gallery, and Tree. Stop on Gallery.

![The same folder shown as details, brief, icons, and a gallery of thumbnails](screenshots/view-modes.png)
*The five view modes. Gallery (thumbnails) suits photo review; Details suits column-based work.*

View mode is remembered per panel, so the left side can stay a gallery while the right side stays a detailed list. For the full reference on every mode, see [View modes & sorting](view-modes-and-sorting.md).

## Step 4: Sort the photos newest first

You will usually want the latest shots at the top.

1. Keep the left panel active.
2. Open **View > Sort By** and choose **Date**. Sorting by date puts the newest items first.
3. To flip the order (oldest first), choose **View > Sort By > Date** again, or use the date shortcut **Ctrl+F6**.

Folders always group together at the top, and the `..` entry that takes you up one level stays pinned first regardless of sort.

## Step 5: Set up the right panel as a detailed list

Now switch sides and build the working view for your project folders.

1. Press **Tab** (or click the right panel) to make the **right** panel active.
2. Navigate it to your project folder, for example `~/Projects`.
3. Open the **View** menu and choose **Full (Details)** to get the column list. (Shortcut: **Ctrl+F2**.)
4. Sort by name: click the **Name** column header, or choose **View > Sort By > Name**. A small arrow in the header shows the sort column and direction; click the header again to reverse it.

## Step 6: Choose which columns appear

The Details view lets you decide exactly which columns show, so you see only the information you care about.

1. With the right panel active and in Details view, choose **Configuration > Columns…**.
2. Turn columns on or off and drag them into the order you want. Available columns include Name, Ext, Size, Date, Attr (attributes), Tags, and Comment.
3. For a project folder, a useful set is **Name**, **Size**, **Date**, and **Tags**. Turn on Tags and turn off any columns you do not need.
4. Apply your changes. Columns affect the active panel's Details view.
5. Back in the panel, fine-tune widths by dragging the divider between two column headers.

Column choices, like view mode and sort order, are remembered per panel.

## Step 7: Open tabs for the folders you use

Tabs keep several folders one click apart inside a single panel. Set up the tabs you expect to jump between.

1. Make the **right** panel active.
2. Press **Cmd+T** (or click the **+** at the end of the tab bar) to open a new tab. It opens on the current folder.
3. In the new tab, navigate to a second project folder, for example `~/Projects/Website`.
4. Add one more tab the same way and point it at, say, `~/Projects/Archive`.
5. Switch between tabs with **Cmd+}** (next) and **Cmd+{** (previous), or click a tab chip directly.
6. On the **left** (gallery) panel, add a second tab for the folder you will copy photos *into*, for example `~/Pictures/2026/Selects`. Now you can review in one tab and drop into another without losing your place.

Tip: if there is a folder you keep coming back to, select its tab and choose **View > Lock Tab**. A lock icon appears, and navigating elsewhere opens a new tab instead of moving the pinned one. See [Tabs](panels-and-tabs.md) for the full set of tab actions.

## Step 8: Save the arrangement as a workspace

Now capture the whole setup, both panels and all their tabs, so you can return to it later.

1. Make one last check that both panels show what you want: the left as a date-sorted gallery with your review and destination tabs, the right as a name-sorted detailed list with your project tabs.
2. Click the panel you want focused when the workspace reopens (say, the left one).
3. Open the **Go** menu and choose **Save Workspace…** (shortcut **Cmd+Ctrl+S**).
4. Type a name, for example `Photo import`, and confirm.

The snapshot stores the folders each panel shows, every open tab, which tab is active on each side, and which panel is focused. It does not store the files themselves, so it stays valid as the folders' contents change.

## Step 9: Restore the workspace later

1. Open the **Go** menu and choose **Workspaces…**.
2. In the pop-up list, click **Photo import**. Both panels, all their tabs, and the active side snap back into place.
3. Your first nine saved workspaces get quick-select number keys **1**–**9**, so once you have a few, you can switch with a single keystroke.

To remove a workspace, open **Workspaces…**, point at **Delete**, and choose its name from the submenu.

Loading a workspace replaces the tabs in both panels with the saved set, so anything you had open but did not save is not kept. If you want to keep your current layout too, save it as its own workspace first.

## What to try next

- Build a second workspace for a different job, for example a "Backups" layout with your source folder on one side and a backup drive on the other, so you can flip between projects in one keystroke.
- Add the folders you open most often to your favorites so new tabs are quicker to fill; see [Favorites](favorites.md).
- Explore the rest of the view options, including natural (numeric) sorting and the Tree mode, in [View modes & sorting](view-modes-and-sorting.md), and the finer points of saving and restoring layouts in [Workspaces](workspaces.md).
