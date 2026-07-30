# Configuration & File Locations

## On-disk layout (ADR-007)

```
~/Library/Application Support/PeachCommander/
  peachcmd.ini        main config (layout, operation, display, colors, packer, …)
  session.ini         window frames, tabs, paths, sort orders, cmdline history
  hotlist.ini         directory hotlist (Ctrl+D)
  usercmd.ini         user commands (em_*)
  default.bar         main button bar (TC .bar format)
  keymap-user.ini     user shortcut overrides (base scheme chosen in peachcmd.ini)
  ftp-sites.ini       FTP/SFTP sessions (NO passwords — Keychain refs only)
  plugins/            installed plugins (*.pcxplugin, *.pfxplugin, *.plxplugin, *.pdxplugin)
  plugins.ini         plugin enable/disable + extension associations + settings
  searches.ini        saved search templates
  renames.ini         saved multi-rename presets
  syncs.ini           saved synchronize presets
~/Library/Caches/PeachCommander/   thumbnails, temp archive extractions
~/Library/Logs/PeachCommander/     rotating file log (opt-in verbose)
```

Override root for tests/portable use: launch arg `-ConfigRoot <path>` or env
`PEACHCMD_CONFIG_ROOT` (F-277). All engine code receives paths via `ConfigPaths`
struct — never hardcode.

## INI conventions

- UTF-8, `[Section]`, `key=value`, `;` comments preserved on rewrite (parser keeps
  a token list, so user comments survive saves — important, TC users edit INIs).
- Key names mirror wincmd.ini where a concept maps 1:1 (e.g. `[Configuration]
  ShowHiddenSystem=`, `[Layout] ButtonBar=1`, `[Colors] InverseCursor=`), so TC
  documentation/muscle memory transfers and a future importer (F-276) is easy.
- Writes are atomic (temp+rename), debounced 1 s, and versioned with
  `[meta] version=1` for migrations.

## Config access in code

`ConfigStore` (PCFoundation): typed accessors, change notifications per key-path,
thread-safe actor. UI binds via small helpers; no NSUserDefaults for app config
(defaults only for trivial OS-integration bits like NSWindow autosave names).

## Secrets

Passwords/keys (FTP, archives if user opts to save): Keychain
(`kSecClassGenericPassword`, service `com.peachcommander.<kind>`, account = site id).
`ftp-sites.ini` stores `password=keychain` marker only. Master-password feature of
TC is replaced by Keychain + Touch ID (document in SPEC-011 §6).
