# SPEC-005 — Lister (File Viewer) & Quick View

Covers: F-110..F-123. Perf: performance.md §Viewer rules.

## §1 Window & modes

- Own window (multiple allowed), remembers frame/size. Menu in-window minimal:
  File/Edit/Options like TC Lister. Status bar: position %, size, encoding, mode.
- Modes (keys as TC): 1=Text, 2=Binary (fixed width), 3=Hex, 4=Image/Multimedia,
  5=HTML, 6=Unicode(→ merged into text w/ encoding), 7=Lister-plugins (I16).
  'A'uto default: detect by content/extension/detect-strings.
- N/P keys: next/previous file in source dir (viewer reuse, TC behavior).

## §2 Text engine

- Backing: `FileSlice` abstraction over mmap (local) or progressive temp download
  (VFS w/o mmap). Line index built lazily in 1 MB chunks (background), enabling
  jump-to-% before full index. Word wrap mode (W) re-flows visible window only.
- Encodings: UTF-8 (BOM/heuristic), UTF-16LE/BE, Latin-1/CP1252, macRoman, +
  ICU list menu; autodetect on first 64 KB (uchardet-like heuristic, keep simple).
- Display: custom NSView drawing visible lines via CoreText (NOT NSTextView —
  cannot handle 50 GB); selection & copy; font configurable; ANSI-escape option
  off (P3).

## §3 Hex/binary modes

- Hex: `offset  16 bytes hex  ascii` rows, fixed row height → trivial virtual
  scrolling; goto-offset dialog; edit NOT in scope (viewer only, like TC).
- Binary: fixed 75/custom columns of raw bytes as chars.

## §4 Search (F-113)

- Ctrl+F/F7 dialog: text (respecting encoding), case, whole words, hex string
  mode, backwards; F3 = next. Streams through FileSlice (chunked, overlap =
  needle-1); highlights + scrolls. Works in all modes (hex search in hex view).

## §5 Media (F-115..F-117)

- Images: ImageIO/NSImage; fit-to-window (default) vs 1:1, zoom +/-, arrows pan;
  slideshow n/p. EXIF info line. Animated GIF via NSImageView animation.
- HTML: WKWebView, local file only, JavaScript disabled, no network (config to
  allow). RTF: NSAttributedString view. Office formats: not built-in → plugins.
- AV: AVPlayerView for audio/video with standard controls.

## §6 Quick View (Ctrl+Q) (F-118)

- Replaces the INACTIVE panel with an embedded Lister view following the cursor
  of the active panel (debounced 150 ms, cancels previous load). Esc/Ctrl+Q
  closes and restores panel (incl. its list state — keep model alive).
- Uses the same mode engines; plugin views too (I16). Separate-window quick view
  (Ctrl+Shift+Q → open Lister) standard.

## §7 VFS integration (F-120)

- Viewing a file inside an archive/FTP: `localFileIfAvailable` → temp extract
  with progress; temp files cleaned per-session LRU (Caches dir), and on quit.

## §8 Lister plugins (I16, SPEC-012 §5)

- Plugin views layered per detect-string priority; keys 1..n or "next viewer"
  cycles: plugin view ↔ built-in modes. `ListSendCommand`/search bridged.

## §9 Tests

- Unit: line indexer (CRLF/LF/mixed/no-EOL, huge lines), encoding detection,
  hex formatter, search chunking incl. needle across chunk boundary.
- Perf: 50 GB sparse fixture — open, seek 50%, search; budgets in perf doc.
- UI smoke: open each fixture type, switch all modes, quick view toggling.
