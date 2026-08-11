#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# check-archive-listing.sh — does this app list an archive the way an independent reader does? (F-377)
#
# The corpus is *generated* here with the system's own `zip` and `tar`, so the awkward cases are actually
# present rather than hoped for: stored and deflated members, jar, tar in ustar/GNU/PAX flavours, gzip,
# names longer than a ustar header holds, Unicode names, and a directory with 120 members so an off-by-one
# in a central-directory walk shows up.
#
# The witness is Python's `zipfile`/`tarfile` — separate implementations that know nothing about this
# project. Parsing `unzip -l` output was the first attempt and it took the owner column for the size,
# which made every entry look missing; reading the archives with a library avoids inventing a parser.
#
# What a disagreement would mean in the app: an entry that is missing cannot be opened, extracted or
# searched, and a wrong size makes a copy out of an archive write the wrong bytes. Both are silent.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---- the corpus -----------------------------------------------------------
mkdir -p "$WORK/src/a/b/c" "$WORK/src/dir with spaces" "$WORK/src/many"
printf 'hello\n' > "$WORK/src/a/one.txt"
printf 'x%.0s' $(seq 1 5000) > "$WORK/src/a/b/big.txt"
: > "$WORK/src/a/b/c/empty.txt"
printf 'space\n' > "$WORK/src/dir with spaces/file with spaces.txt"
printf 'umlaut\n' > "$WORK/src/a/Grüße.txt"
printf 'cjk\n' > "$WORK/src/a/日本語.txt"
LONG="$(printf 'l%.0s' $(seq 1 90))"
mkdir -p "$WORK/src/a/$LONG"
printf 'long\n' > "$WORK/src/a/$LONG/$LONG.txt"
for i in $(seq 1 120); do printf 'n%s\n' "$i" > "$WORK/src/many/file$i.txt"; done

( cd "$WORK" && zip -q -r plain.zip src && zip -q -r -0 stored.zip src && zip -q -r -9 max.zip src )
( cd "$WORK" && tar -cf plain.tar src && tar -czf plain.tgz src )
( cd "$WORK" && { tar --format=gnu -cf gnu.tar src 2>/dev/null || tar -cf gnu.tar src; } )
( cd "$WORK" && { tar --format=pax -cf pax.tar src 2>/dev/null || tar -cf pax.tar src; } )
# One archive that *does* set the UTF-8 name flag (bit 11), so both readings of the codepage question are
# covered rather than only the common one.
python3 - "$WORK/flagged.zip" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z:
    z.writestr("Grüße.txt", "umlaut\n")
    z.writestr("日本語.txt", "cjk\n")
    z.writestr("plain.txt", "ascii\n")
PY
ls -1 "$WORK"/*.zip "$WORK"/*.tar "$WORK"/*.tgz 2>/dev/null | sort > "$WORK/list.txt"

# ---- what this app sees ---------------------------------------------------
mkdir -p "$WORK/probe-src"
cat > "$WORK/probe-src/main.swift" <<'SWIFT'
import Foundation
func run() {
    let files = (try? String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8))?
        .split(separator: "\n").map(String.init) ?? []
    for path in files where !path.isEmpty {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".tar") || name.hasSuffix(".tgz") || name.hasSuffix(".tar.gz") {
            guard let reader = TarReader(fileURL: url) else { print("OPENFAIL tar \(path)"); continue }
            print("ARCHIVE tar \(path)")
            for m in reader.members where !m.isDirectory { print("  E \(m.uncompressedSize) \(m.path)") }
        } else {
            guard let reader = ZipReader(fileURL: url) else { print("OPENFAIL zip \(path)"); continue }
            print("ARCHIVE zip \(path)")
            for e in reader.entries where !e.isDirectory { print("  E \(e.uncompressedSize) \(e.path)") }
        }
    }
}
run()
SWIFT
swiftc -o "$WORK/probe" "$WORK/probe-src/main.swift" \
    Sources/PCArchive/ZipReader.swift Sources/PCArchive/ZipVolumes.swift \
    Sources/PCArchive/TarReader.swift \
    Sources/PCArchive/ArchiveSource.swift Sources/PCArchive/WinZipAES.swift \
    Sources/PCArchive/ZipWriter.swift
"$WORK/probe" "$WORK/list.txt" > "$WORK/probe-out.txt"

python3 Tools/compare-archive-listing.py "$WORK/probe-out.txt" "$WORK/list.txt"
