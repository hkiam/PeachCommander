#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Read back the archives this app wrote, with implementations that are not this app (F-132).

Three questions per archive, and the second is the one that actually bites:

  * is every source file in it?
  * does each entry hold the source's bytes?
  * and for zip, does the compression *level* reach the tool at all — "store" and "maximum" must not
    produce the same size, or the setting is decoration.

7z is checked with `7z t` rather than read member by member: Python has no 7z reader, and "the reference
implementation says this archive is intact" is the honest thing to ask of it.

Usage: compare-pack.py <src-dir> <out-dir> <packed-report>
"""
import pathlib
import subprocess
import sys
import tarfile
import unicodedata
import zipfile


def source_files(src: pathlib.Path) -> dict:
    """{relative name: bytes} for everything under src."""
    out = {}
    for path in sorted(src.rglob("*")):
        if path.is_file():
            rel = str(path.relative_to(src))
            out[unicodedata.normalize("NFC", rel)] = path.read_bytes()
    return out


def read_zip(path: pathlib.Path) -> dict:
    with zipfile.ZipFile(path) as archive:
        return {unicodedata.normalize("NFC", i.filename): archive.read(i)
                for i in archive.infolist() if not i.is_dir()}


def read_tar(path: pathlib.Path) -> dict:
    out = {}
    with tarfile.open(path) as archive:
        for member in archive.getmembers():
            if not member.isfile():
                continue
            # macOS tar stores extended attributes as separate "._name" members; they are not source
            # files and their absence or presence is not this gate's business.
            if pathlib.PurePath(member.name).name.startswith("._"):
                continue
            handle = archive.extractfile(member)
            out[unicodedata.normalize("NFC", member.name)] = handle.read() if handle else b""
    return out


def main() -> int:
    src = pathlib.Path(sys.argv[1])
    out = pathlib.Path(sys.argv[2])
    report = pathlib.Path(sys.argv[3]).read_text()

    failed = [line for line in report.splitlines() if line.startswith("FAILED")]
    for line in failed:
        print(f"  ⚠️  {line}")

    expected = source_files(src)
    problems = len(failed)

    for label, reader in (("zip.zip", read_zip), ("tar.tar", read_tar), ("tgz.tar.gz", read_tar)):
        path = out / label
        if not path.exists():
            print(f"  ⚠️  {label}: never written")
            problems += 1
            continue
        try:
            got = reader(path)
        except Exception as e:                      # noqa: BLE001 — the message is the finding
            print(f"  ⚠️  {label}: an independent reader cannot open it: {e}")
            problems += 1
            continue
        missing = set(expected) - set(got)
        extra = set(got) - set(expected)
        wrong = {n for n in set(got) & set(expected) if got[n] != expected[n]}
        if missing or extra or wrong:
            if missing:
                print(f"  ⚠️  {label}: {len(missing)} source file(s) not in the archive: {sorted(missing)[:3]}")
            if extra:
                print(f"  ⚠️  {label}: {len(extra)} entries that are not source files: {sorted(extra)[:3]}")
            if wrong:
                print(f"  ⚠️  {label}: wrong bytes for {sorted(wrong)[:3]}")
            problems += 1
        else:
            print(f"{label:14} ok  {len(got)} entries, contents identical")

    # 7z: no Python reader, so ask the reference implementation whether it is intact.
    seven = out / "sevenzip.7z"
    if seven.exists():
        result = subprocess.run(["7z", "t", str(seven)], capture_output=True, text=True)
        if result.returncode == 0:
            print("sevenzip.7z    ok  7z reports it intact")
        else:
            print(f"  ⚠️  sevenzip.7z: 7z cannot verify it: {result.stdout[-300:]}")
            problems += 1
    else:
        print("  ⚠️  sevenzip.7z: never written")
        problems += 1

    # The compression level has to reach the tool.
    store, maximum = out / "zip-store.zip", out / "zip-max.zip"
    if store.exists() and maximum.exists():
        if store.stat().st_size <= maximum.stat().st_size:
            print(f"  ⚠️  compression level ignored: store={store.stat().st_size} "
                  f"max={maximum.stat().st_size} — level 0 must be larger than level 9")
            problems += 1
        else:
            print(f"levels         ok  store={store.stat().st_size} max={maximum.stat().st_size}")
    else:
        print("  ⚠️  the level archives were not written")
        problems += 1

    print(f"problems={problems}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
