#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# check-pack-formats.sh — can anything else read the archives this app writes? (F-132)
#
# The failure this guards against is not "packing crashes". It is an archive that is written happily and
# then turns out to be missing a file, or to hold the wrong bytes, or not to open at all in another tool
# — noticed months later, by which time the originals may be gone.
#
# The witness is Python's `zipfile`/`tarfile` plus `7z t`, none of which know anything about this project.
# The corpus contains the names that break a packer driven by command line: one beginning with a dash
# (which used to be read as a *switch* — `tar` answered "Can't specify both -x and -c" and the whole
# operation failed, and a file called "-C" would have made tar change directory and archive something
# else entirely), plus spaces, non-ASCII, an empty file and a nested directory.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/src/sub" "$WORK/out"

# ---- the corpus -----------------------------------------------------------
printf 'plain content\n'      > "$WORK/src/plain.txt"
printf 'leading dash\n'       > "$WORK/src/-x.txt"
printf 'double dash\n'        > "$WORK/src/--verbose.txt"
printf 'spaces in the name\n' > "$WORK/src/two words.txt"
printf 'umlaut Grüße\n'       > "$WORK/src/Grüße.txt"
printf 'nested\n'             > "$WORK/src/sub/inner.txt"
: > "$WORK/src/empty.txt"
# Bigger than one compression window, so a level that never reaches the tool is visible as a size.
python3 -c "
import sys
open(sys.argv[1],'wb').write((b'compress me '*40000))
" "$WORK/src/big.txt"

# ---- pack with this app ---------------------------------------------------
cat > "$WORK/main.swift" <<'SWIFT'
import Foundation
let src = CommandLine.arguments[1], out = CommandLine.arguments[2]
let names = (try? FileManager.default.contentsOfDirectory(atPath: src))?.sorted() ?? []
let items = names.map { (src as NSString).appendingPathComponent($0) }

func pack(_ label: String, _ format: PackFormat, level: Int = 5) {
    let archive = "\(out)/\(label).\(format.fileExtension)"
    do {
        try PackEngine.pack(items: items, to: archive, options: PackOptions(format: format, level: level))
        print("PACKED \(label) \(archive)")
    } catch {
        print("FAILED \(label) \(error)")
    }
}
pack("zip", .zip)
pack("tar", .tar)
pack("tgz", .tarGz)
pack("sevenzip", .sevenZip)
// Store versus maximum: the level has to reach the tool, or the setting is decoration.
pack("zip-store", .zip, level: 0)
pack("zip-max", .zip, level: 9)
SWIFT
swiftc -O -o "$WORK/probe" "$WORK/main.swift" Sources/PCArchive/PackEngine.swift
"$WORK/probe" "$WORK/src" "$WORK/out" > "$WORK/packed.txt"
cat "$WORK/packed.txt"

python3 Tools/compare-pack.py "$WORK/src" "$WORK/out" "$WORK/packed.txt"
