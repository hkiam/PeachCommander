#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# check-checksums.sh — do this app's digests and checksum files agree with the tools everyone else uses?
#
# A checksum feature that is quietly wrong is worse than none: it answers "verified" and the user stops
# looking. Two independent witnesses, neither of which knows anything about this project:
#
#   * Python's `hashlib` and `zlib.crc32` for the digests themselves — separate implementations, and for
#     CRC-32 a genuinely different one (this app carries its own table-driven CRC).
#   * the system's own `shasum` and `md5`, whose *output files* the app must be able to read. They write
#     the conventions real files use, so this checks the parser against reality rather than against the
#     text a test author would have typed. The parser used to split lines on `$0 == "\n"`, which in Swift
#     never matches a CRLF, so every Windows-written .sfv verified nothing at all (F-097).
#
# The corpus is generated here so the awkward cases are actually present: an empty file, one byte, a file
# larger than the streaming chunk, names with spaces and non-ASCII, and raw binary.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/files"

# ---- the corpus -----------------------------------------------------------
: > "$WORK/files/empty.bin"
printf 'a' > "$WORK/files/one-byte.bin"
printf 'hello world\n' > "$WORK/files/plain.txt"
printf 'two words with spaces\n' > "$WORK/files/two words.txt"
printf 'umlaut\n' > "$WORK/files/Grüße.txt"
# Larger than any sane read chunk, so a streaming bug shows up rather than hiding in one buffer.
python3 -c "
import sys
open(sys.argv[1],'wb').write(bytes(range(256))*4096)
" "$WORK/files/binary-1mb.bin"
printf 'line1\r\nline2\r\n' > "$WORK/files/crlf.txt"

# ---- what this app computes ----------------------------------------------
cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

// Streamed in small chunks on purpose: `ChecksumEngine` hashes a file piece by piece, and a one-shot
// hash over the whole buffer would not exercise the incremental path at all.
func digest(_ url: URL, _ algorithm: ChecksumAlgorithm) -> String? {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }
    let hasher = ChecksumHasher(algorithm)
    while let chunk = try? handle.read(upToCount: 7919), !chunk.isEmpty {   // a prime, so chunks
        hasher.update(chunk)                                                // straddle every boundary
    }
    return hasher.finalizeHex()
}

func run() {
    let mode = CommandLine.arguments[1]
    if mode == "digest" {
        let dir = URL(fileURLWithPath: CommandLine.arguments[2])
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?.sorted() ?? []
        for name in names {
            for algorithm in ChecksumAlgorithm.allCases {
                guard let hex = digest(dir.appendingPathComponent(name), algorithm) else { continue }
                print("D \(algorithm.rawValue) \(hex) \(name)")
            }
        }
    } else if mode == "parse" {
        // Read a checksum file the system tools wrote and print what the app makes of it.
        let path = CommandLine.arguments[2]
        let format: ChecksumFileFormat = CommandLine.arguments[3] == "sfv" ? .sfv : .digestFirst
        let data = (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()
        for entry in ChecksumFile.parse(String(decoding: data, as: UTF8.self), format: format) {
            print("P \(entry.digest) \(entry.filename)")
        }
    }
}
run()
SWIFT
swiftc -O -o "$WORK/probe" "$WORK/main.swift" \
    Sources/PCFoundation/ChecksumAlgorithm.swift Sources/PCFoundation/ChecksumFile.swift
"$WORK/probe" digest "$WORK/files" > "$WORK/digests.txt"

# ---- checksum files as the system tools write them ------------------------
# Written from inside the directory so the names in the file are bare, the way the app expects them.
( cd "$WORK/files" && shasum -a 256 -- * > "$WORK/sys-sha256.txt" )
( cd "$WORK/files" && md5 -r -- * > "$WORK/sys-md5.txt" )
# The same list with CRLF endings and a BOM — what a Windows tool produces, and what the parser used to
# drop on the floor entirely.
python3 - "$WORK/sys-sha256.txt" "$WORK/sys-sha256-crlf.txt" <<'PY'
import sys
data = open(sys.argv[1], "rb").read().replace(b"\n", b"\r\n")
open(sys.argv[2], "wb").write(b"\xef\xbb\xbf" + data)
PY
"$WORK/probe" parse "$WORK/sys-sha256.txt" digestFirst > "$WORK/parsed-lf.txt"
"$WORK/probe" parse "$WORK/sys-sha256-crlf.txt" digestFirst > "$WORK/parsed-crlf.txt"
"$WORK/probe" parse "$WORK/sys-md5.txt" digestFirst > "$WORK/parsed-md5.txt"

python3 Tools/compare-checksums.py "$WORK/files" "$WORK/digests.txt" \
    "$WORK/parsed-lf.txt" "$WORK/parsed-crlf.txt" "$WORK/parsed-md5.txt"
