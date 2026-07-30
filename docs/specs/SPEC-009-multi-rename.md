# SPEC-009 — Multi-Rename Tool (Ctrl+M)

Covers: F-170..F-176.

## §1 Dialog (TC layout)

- Top: "Rename mask: file name" field + placeholder buttons ([N] [N#-#] [C] [E]
  [d]...), "Extension" mask field. Combos with history.
- Search & Replace block: search for (multiple via `|`), replace with (parallel
  via `|`), checkboxes: case sensitive, regex (+ "substitution" for $1 groups),
  repeat replace.
- Case block: unchanged / lowercase / UPPERCASE / First letter big / Every Word.
- Counter block: start, step, digits (leading zeros).
- Plugins button → insert `[=plugin.field.unit]` (I16, F-172).
- Preview grid: old name | new name, live, invalid/colliding rows red.
- Buttons: Start, Undo (after run), Result list, Load/Save preset (F2 combo),
  "Edit names via editor" (F-174), Close.

## §2 Placeholder language (implement exactly; unit-test table)

| Token | Meaning |
|---|---|
| `[N]` | whole name without extension |
| `[N2-5]` | chars 2..5 of name; `[N2,3]` 3 chars from pos 2; `[N-8,5]` from 8th-last; `[N2-]` from 2 to end |
| `[E]`, `[E1-2]` etc. | extension analogues |
| `[C]` | counter per counter-block; `[C10+5:3]` start 10 step 5 digits 3 |
| `[d]` | date as YMD; `[Y] [M] [D] [h] [m] [s]` parts (mod time) |
| `[P]`, `[P2-3]` | parent dir name |
| `[G]` | grandparent |
| `[U]` / `[L]` / `[F]` / `[n]` | case-modifiers region toggles (upper/lower/first/back to normal) — TC uses [U][L][F][n] |
| `[=plug.field.unit]` | content plugin field (I16) |
| `[[` `]]` | literal brackets |

Order of application: mask expansion → search/replace → case block.

## §3 Execution

- Runs as queue operation (rename per file, VFS): collision-safe two-phase
  (rename to temp UUID names first when target set intersects source set).
- Log kept (old↔new) → Undo (reverse renames, best-effort with report) (F-175).
- Works in archives (zip rename support) and on FTP (VFS capability-gated).

## §4 Editor round-trip (F-174)

Export `old<TAB>new` lines to temp file, open editor (association), on save+
close re-import; validate count/uniqueness; show diff-preview.

## §5 Tests

Exhaustive unit tests of §2 token table incl. negative positions, unicode
(grapheme-cluster counting!), collisions, undo, regex substitution, presets
round-trip. Integration: 5k files rename < 5 s.
