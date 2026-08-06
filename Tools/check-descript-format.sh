#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# check-descript-format.sh — does the descript.ion writer produce what other tools read? (F-374)
#
# `descript.ion` is an interchange format: Total Commander, DOS Navigator, ACDSee and Take Command all
# read it, and this app writes it. Unit tests can only show that the code agrees with itself — they
# decode with the same decoder that encoded. So this compiles the real encoder, writes one file per
# supported encoding, and hands the bytes to **Python's** codecs, which know nothing about this project.
#
# What it checks:
#   * the BOM is the one the encoding requires,
#   * the text survives a decode by an independent implementation, byte for byte,
#   * Total Commander's multi-line marker (0x04 0xC2) is still in the bytes.
#
# Reading a UTF-16 `descript.ion` as UTF-8 used to turn it into replacement characters, and writing it
# back destroyed every comment in that directory — including the ones nobody had touched. That is the
# failure this exists to prevent, and it is not the kind that announces itself.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation
func run() {
    let dir = CommandLine.arguments[1]
    let marker = "\u{04}\u{C2}"
    let text = "a.txt Grüße aus Zürich\n\"two words.txt\" 日本語\\nzweite Zeile\(marker)\nplain.txt hello\n"
    try! text.write(toFile: "\(dir)/expected.txt", atomically: true, encoding: .utf8)
    for (name, enc) in [("utf8", DescriptionFile.Encoding.utf8), ("utf8bom", .utf8BOM),
                        ("utf16le", .utf16LE), ("utf16be", .utf16BE)] {
        try! DescriptionFile.encode(text, as: enc)
            .write(to: URL(fileURLWithPath: "\(dir)/descript.\(name)"))
    }
}
run()
SWIFT

swiftc -o "$WORK/probe" "$WORK/main.swift" Sources/PCFoundation/DescriptionFile.swift
"$WORK/probe" "$WORK"

python3 - "$WORK" <<'PY'
import pathlib
import sys

work = pathlib.Path(sys.argv[1])
want = (work / "expected.txt").read_text(encoding="utf-8")
cases = [("utf8", "utf-8", b""), ("utf8bom", "utf-8-sig", b"\xef\xbb\xbf"),
         ("utf16le", "utf-16", b"\xff\xfe"), ("utf16be", "utf-16", b"\xfe\xff")]

problems = 0
for name, codec, bom in cases:
    raw = (work / f"descript.{name}").read_bytes()
    if bom and not raw.startswith(bom):
        print(f"  ⚠️  {name}: missing the {bom.hex()} BOM")
        problems += 1
    try:
        got = raw.decode(codec)
    except Exception as e:                      # noqa: BLE001 — the message is the finding
        print(f"  ⚠️  {name}: python cannot decode it as {codec}: {e}")
        problems += 1
        continue
    if got != want:
        print(f"  ⚠️  {name}: text differs after an independent decode")
        print(f"        want {want!r}")
        print(f"        got  {got!r}")
        problems += 1
    elif "Â" not in got:
        print(f"  ⚠️  {name}: Total Commander's multi-line marker is gone")
        problems += 1
    else:
        print(f"{name:8} ok  bytes={len(raw):4}")
print(f"encodings={len(cases)} problems={problems}")
raise SystemExit(1 if problems else 0)
PY
