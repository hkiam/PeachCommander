#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Compare this app's digests and checksum-file parsing with independent implementations (F-097).

Two separate questions, and the second is the one that was actually broken:

  * **Are the digests right?** `hashlib` and `zlib.crc32` against the app's own hashers. CRC-32 matters
    most here — the app carries its own table-driven implementation rather than wrapping a library.
  * **Can the app read a checksum file it did not write?** The inputs are produced by `shasum` and `md5`,
    then also converted to CRLF with a BOM. Both shapes must yield exactly the same entries as the LF
    original: a parser that drops a line does not fail loudly, it verifies fewer files and still says OK.

Usage: compare-checksums.py <files-dir> <digests> <parsed-lf> <parsed-crlf> <parsed-md5>
"""
import hashlib
import pathlib
import sys
import unicodedata
import zlib


def reference_digests(directory: pathlib.Path) -> dict:
    """{(algorithm, name): hex} from Python, for every file in the directory."""
    out = {}
    for path in sorted(directory.iterdir()):
        if not path.is_file():
            continue
        data = path.read_bytes()
        name = path.name
        out[("crc32", name)] = format(zlib.crc32(data) & 0xFFFFFFFF, "08x")
        for algorithm, fn in (("md5", hashlib.md5), ("sha1", hashlib.sha1),
                              ("sha256", hashlib.sha256), ("sha512", hashlib.sha512)):
            out[(algorithm, name)] = fn(data).hexdigest()
    return out


def app_digests(path: str) -> dict:
    out = {}
    for line in pathlib.Path(path).read_text().splitlines():
        if line.startswith("D "):
            _, algorithm, hexdigest, name = line.split(" ", 3)
            out[(algorithm, name)] = hexdigest
    return out


def parsed_entries(path: str) -> dict:
    """{name: digest} from the probe's report of what the parser made of a checksum file."""
    out = {}
    for line in pathlib.Path(path).read_text().splitlines():
        if line.startswith("P "):
            _, digest, name = line.split(" ", 2)
            # macOS hands out decomposed names and the tools pass them through; the comparison is about
            # which files were listed, not about which normal form anybody chose.
            out[unicodedata.normalize("NFC", name)] = digest
    return out


def main() -> int:
    files_dir = pathlib.Path(sys.argv[1])
    theirs = reference_digests(files_dir)
    mine = app_digests(sys.argv[2])
    problems = 0

    # ---- the digests ------------------------------------------------------
    missing = set(theirs) - set(mine)
    if missing:
        print(f"  ⚠️  the app produced no digest for {len(missing)}: {sorted(missing)[:3]}")
        problems += 1
    wrong = {k for k in set(mine) & set(theirs) if mine[k] != theirs[k]}
    for key in sorted(wrong):
        print(f"  ⚠️  {key[0]} of {key[1]}: app={mine[key]} python={theirs[key]}")
    problems += len(wrong)
    print(f"digests: {len(set(mine) & set(theirs))} compared, {len(wrong)} wrong")

    # ---- reading what the system tools wrote ------------------------------
    lf, crlf, md5 = (parsed_entries(p) for p in sys.argv[3:6])
    expected_names = {unicodedata.normalize("NFC", p.name) for p in files_dir.iterdir() if p.is_file()}

    for label, entries in (("shasum output (LF)", lf), ("the same file as CRLF + BOM", crlf),
                           ("md5 -r output", md5)):
        got = set(entries)
        if got != expected_names:
            print(f"  ⚠️  {label}: parsed {len(got)} of {len(expected_names)} entries; "
                  f"missing {sorted(expected_names - got)[:3]}, extra {sorted(got - expected_names)[:3]}")
            problems += 1
        else:
            print(f"{label}: all {len(got)} entries")

    # The CRLF file is the same data; disagreeing with the LF reading means the line endings changed the
    # answer, which is the defect this gate exists for.
    if lf and crlf and lf != crlf:
        differing = {n for n in set(lf) & set(crlf) if lf[n] != crlf[n]}
        print(f"  ⚠️  CRLF+BOM parsed differently from LF: {len(set(lf) ^ set(crlf))} entries differ, "
              f"{len(differing)} digests differ")
        problems += 1

    # …and the digests in those files must be the ones the app itself computes, or "verified" means
    # nothing: the app would be agreeing with its own reading of a number it never checked.
    for name, digest in sorted(lf.items()):
        expected = mine.get(("sha256", name)) or mine.get(("sha256", unicodedata.normalize("NFD", name)))
        if expected and digest != expected:
            print(f"  ⚠️  {name}: shasum says {digest}, the app computes {expected}")
            problems += 1

    print(f"problems={problems}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
