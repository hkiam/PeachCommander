# SPEC-013 — Options Dialog & Associations

Covers: F-270..F-277. Storage: docs/architecture/configuration.md.

## §1 Dialog shell

Settings window (Cmd+, / Configuration > Options…): left source-list tree of
pages, right content, Apply/OK/Cancel (Apply = live; most layout toggles apply
instantly on toggle like TC). Pages appear as their features land — a page per
iteration list below.

## §2 Pages (TC page set, adapted)

| Page | Contents | Iter |
|---|---|---|
| Layout | checkboxes for every chrome element (F-270), vertical arrangement, fkey-bar style | I05 |
| Display | file list font+size, row height, show hidden, ext column vs appended, size format, date format, brackets around dirs | I05 |
| Colors | fg/bg, selection, cursor, alternating rows; by-file-type rules (mask or search template → color), dark-mode variants | I05 |
| Icons | icon mode (F-029), size 16/32, show overlay for links | I05 |
| Operation | mouse selection mode, quick search mode, deletion→Trash?, confirmations (delete/overwrite readonly/…), "select dirs with Num+", cmdline focus policy | I05 |
| Edit/View | viewer/editor associations (§4), quick view settings | I07 |
| Tabs | open-in-fg/bg, tab width limits, confirm close-all, locked-tab behavior on navigation ("directory changes allowed → new tab") | I06 |
| Copy/Delete | default overwrite policy, verify, preserve xattrs/dates/perms, big-buffer size advanced fields, clone-copy toggle | I04 |
| Zip/Packer | zip level, encoding for names, temp dir, packer plugin page link | I09 |
| FTP | default transfer mode? (binary), keep-alive, proxy list editor | I15 |
| Plugins | manager (SPEC-012 §8) | I14 |
| Language | UI language (system/en/de) | I19 |
| Misc | check-updates cadence (I20), logging verbosity, config-root display + "Open config folder" |
| Keys | scheme picker + remap grid (SPEC-014 §5) | I13 |

## §3 Live behavior

Changes write to ConfigStore (debounced persist); observers re-render. "Save
Settings" menu = force flush; "Save Position" stores window frame explicitly
(TC parity F-013).

## §4 Internal associations (F-273)

TC concept: file associations INSIDE the app, independent of Finder: per
extension/mask → viewer mode override, editor app, opener app. Editor grid:
mask | open-with | edit-with | view-mode. Fallback chain: internal → macOS
default. Used by Enter (SPEC-003 §3), F3 (mode hint), F4 (editor choice).

## §5 Tests

Round-trip every option key (write→reload→equal); INI comment preservation;
live-apply smoke (toggle layout elements, verify view hierarchy).
