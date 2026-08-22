---
title: Deleting files
slug: deleting-files
group: Using Peach Commander
section: Files & folders
order: 28
related: [copying-files]
---

When you no longer need files or folders, Peach Commander can move them to the Trash so you can recover them later, or delete them permanently to reclaim space right away. Deletions act on the current selection in the active panel; if nothing is marked, the item under the cursor is deleted.

## How to delete files

1. In the active panel, mark the files and folders you want to remove. If you don't mark anything, the item under the cursor is used.
2. Press **F8** (or the **Delete** key) to move the selection to the Trash. To choose it from the menu, use **File > Delete**.
3. If a confirmation appears, review the list of items and click **Delete** to continue, or **Cancel** to stop.

Items sent to the Trash stay there until you empty it, so you can restore them from the Finder if you change your mind.

## How to delete permanently

1. Mark the files and folders to remove.
2. Press **Shift+F8**, or choose **File > Delete Permanently**.
3. Confirm the deletion. This bypasses the Trash, so the items are gone immediately and cannot be recovered.

If some items can't be removed — for example, because they're locked or you don't have permission — Peach Commander tells you which ones failed and lets you retry or skip them and continue with the rest.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Delete to Trash | F8 or Delete |
| Delete permanently | Shift+F8 |

## Notes

- **Confirmation.** By default Peach Commander asks you to confirm before deleting. You can turn this off in **Configuration > Confirmation** by clearing **Confirm before delete**. Even so, treat permanent deletions with care, since they can't be undone.
- **Default behavior of F8.** Normally F8 moves items to the Trash. If you prefer F8 to delete permanently by default, change the delete option in the **Configuration > Operation** settings. Shift+F8 always deletes permanently regardless of this setting.
- **Deleting inside archives.** When you're browsing inside a supported archive, deleting removes the selected entries from the archive. Read-only locations, such as some network or plugin folders, cannot be changed this way.
- **Folders.** Deleting a folder removes everything inside it. Be sure you've selected the right items before confirming, especially for a permanent delete.
