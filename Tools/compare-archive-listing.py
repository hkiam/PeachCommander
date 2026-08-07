#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Compare the app's archive listing with Python's zipfile/tarfile (F-377).

Python's modules are the independent witness: separate implementations of the same formats that know
nothing about this project, and — unlike parsing `unzip -l` / `tar -tvf` output — they give exact sizes
and handle non-ASCII member names without a text-parsing step of my own to get wrong. The first version of
this script did parse the tools' output, and took the *owner* column for the size, which made every entry
look missing.

Three questions per archive:

  * does the app see the same set of files?
  * does it agree on their uncompressed sizes?
  * can it open what the reference can?

Directories are excluded on both sides: whether a directory gets its own entry depends on how the archive
was written, and that difference is not a defect in either reader.

Usage: compare.py <probe-output> <archive-list>
"""
import collections
import pathlib
import sys
import tarfile
import unicodedata
import zipfile


def app_listing(probe_output: str):
    """{archive path: {entry: size} or None} from the Swift probe's output."""
    out, current = {}, None
    for line in probe_output.splitlines():
        if line.startswith("ARCHIVE "):
            current = line.split(" ", 2)[2]
            out[current] = {}
        elif line.startswith("  E ") and current:
            rest = line[4:]
            size, _, entry = rest.partition(" ")
            out[current][entry] = int(size)
        elif line.startswith("OPENFAIL "):
            out[line.split(" ", 2)[2]] = None
    return out


def reference_listing(path: str):
    """{entry: size} from Python, or None when Python cannot read it either."""
    name = path.lower()
    try:
        if name.endswith((".tar", ".tar.gz", ".tgz")):
            with tarfile.open(path) as tf:
                return {m.name: m.size for m in tf.getmembers() if m.isfile()}
        with zipfile.ZipFile(path) as zf:
            return {i.filename: i.file_size for i in zf.infolist() if not i.is_dir()}
    except Exception:                               # noqa: BLE001 — unreadable for the reference too
        return None


def normalize(name: str) -> str:
    """Reduce a member name to the bytes it stands for, so two readers can be compared at all.

    Two representation differences would otherwise drown the real findings:

    * **Unicode form.** macOS writes names decomposed (NFD) and archivers pass through whatever they were
      handed, so the same name can be spelled two ways.
    * **The zip codepage.** By the letter of the specification a name is CP437 unless bit 11 of the
      general-purpose flags says UTF-8. Info-ZIP on macOS writes UTF-8 bytes *without* setting that flag,
      so Python decodes such a name as CP437 ("Gr├╝├ƒe.txt") while this app decodes it as UTF-8
      ("Grüße.txt"). Both readers saw the same bytes; only the guess differs, and in the world the app
      lives in — archives made on macOS and Linux — the app's guess is the useful one. Re-encoding
      Python's CP437 reading back to bytes and reading those as UTF-8 puts the two on the same footing.
    """
    name = name.lstrip("./")
    try:
        as_bytes = name.encode("cp437")
        name = as_bytes.decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        pass                                        # already UTF-8, or not representable: leave it
    return unicodedata.normalize("NFC", name)


def main() -> int:
    probe = pathlib.Path(sys.argv[1]).read_text(errors="replace")
    archives = [l.strip() for l in pathlib.Path(sys.argv[2]).read_text().splitlines() if l.strip()]
    app = app_listing(probe)

    compared = 0
    problems = collections.Counter()
    for path in archives:
        theirs_raw = reference_listing(path)
        if theirs_raw is None:
            continue
        mine_raw = app.get(path)
        if mine_raw is None:
            print(f"  ⚠️  cannot open, but Python can: {path}")
            problems["open"] += 1
            continue
        compared += 1
        # AppleDouble sidecars: macOS `tar` stores extended attributes as separate `._name` members.
        # Both readers see them; they are excluded so the comparison is about real files.
        mine = {normalize(k): v for k, v in mine_raw.items()
                if not pathlib.PurePath(k).name.startswith("._")}
        theirs = {normalize(k): v for k, v in theirs_raw.items()
                  if not pathlib.PurePath(k).name.startswith("._")}
        missing = set(theirs) - set(mine)
        extra = set(mine) - set(theirs)
        wrong = {e for e in set(mine) & set(theirs) if mine[e] != theirs[e]}
        label = pathlib.Path(path).name
        if missing:
            print(f"  ⚠️  {label}: {len(missing)} entries in Python but NOT in the app: {sorted(missing)[:3]}")
            problems["missing"] += 1
        if extra:
            print(f"  ⚠️  {label}: {len(extra)} entries in the app but NOT in Python: {sorted(extra)[:3]}")
            problems["extra"] += 1
        if wrong:
            e = sorted(wrong)[0]
            print(f"  ⚠️  {label}: size differs for {e}: app={mine[e]} python={theirs[e]}")
            problems["size"] += 1
        if not (missing or extra or wrong):
            print(f"{label:12} ok  {len(mine)} entries")

    print(f"archives={compared} problems={sum(problems.values())} {dict(problems)}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
