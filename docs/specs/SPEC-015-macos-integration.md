# SPEC-015 — macOS Integration (Beyond TC)

Covers: F-088, F-099, F-123, F-159, F-218, F-290..F-300. Principle: additive,
never replacing TC behavior; every macOS extra is toggleable, defaults chosen
to feel native without surprising TC users.

## §1 Quick Look (F-290, F-123)

- `QLPreviewPanel` bound to selection; default key in macOS-native scheme:
  Space?? NO — Space is TC-select. Use ⌘Y + dedicated cm_QuickLook (users may
  remap). Toolbar button. Quick Look thumbnails feed thumbnail view (I17).

## §2 Tags (F-291)

- Column "Tags" (builtin content field), colored dots render; edit via context
  menu > Tags… (token field editor); filter/search by tag in Find Files
  (Advanced tab gains tag row); `NSURL.tagNamesKey` read, setResourceValue write.

## §3 Services & Share (F-292, F-293)

- Selection registered for Services (NSServices consumer + `NSApp.servicesMenu`).
- Share menu item + toolbar button → `NSSharingServicePicker` (AirDrop, Mail…).
- "Open Terminal Here": Terminal.app via AppleScript/`open -a`, iTerm detect;
  config for custom command. cm_OpenTerminal.

## §4 Spotlight (F-159, F-294)

- Built-in PDX-style provider "spotlight" exposing kMDItem* fields (dimensions,
  duration, authors, where-from…) as content fields → columns/search/rename.
- Find Files: "Use Spotlight index" checkbox (NSMetadataQuery prefilter for
  name/content, then verify with real matcher — index can be stale).

## §5 File system niceties

- APFS clonefile fast copy (F-088, default ON, info line in progress dialog
  "cloned"), sparse-file preservation (`SEEK_HOLE` walk on copy fallback).
- Trash integration (F-297): "Open Trash" hotlist entry; put-back via Finder
  metadata when available; show trash item count in volume menu (P3).
- Mount helper (F-218): "Connect to Server" dialog wrapping
  `NetFSMountURLAsync` for smb/afp/nfs; mounted volume then browsed normally.
- dmg: Enter mounts via `hdiutil attach -nobrowse` into temp mount dir and
  enters it; leaving unmounts if we mounted it (P3).

## §6 Permissions & security UX (F-099, F-298, F-299)

- Full Disk Access onboarding: first-run check (try reading a protected dir);
  sheet explains + deep-link `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`.
- Inspector dialog (Alt+Enter "Properties" gains tabs): General | Permissions
  (POSIX + owner picker, recursive apply) | ACLs (list, add/remove entries) |
  xattrs (list, view hex, delete, export) | Tags. Privileged fallback per
  SPEC-004 §9.
- Quarantine: show badge column option; "remove quarantine" context action
  (with warning) — power-user favorite. P3.

## §7 Look & feel (F-295, F-300)

- Dark mode via semantic theme layer; TC-classic light is default scheme,
  "System" option follows appearance. Trackpad: two-finger swipe = history
  back/forward; pinch = font size in Lister. Retina: all icons vector/2x.

## §8 Tests

Each integration: unit-test the non-UI logic (tag read/write on temp files,
xattr editor model, spotlight field mapping) + manual demo-script entries
(docs/testing §manual) since OS panels resist automation.
