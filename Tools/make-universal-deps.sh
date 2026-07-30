#!/usr/bin/env bash
# make-universal-deps.sh — assemble universal (arm64 + x86_64) libssh2 + openssl@3
# into build/universal-deps, for the universal release build (F-214).
#
# Why this exists: PCNet links libssh2, whose headers and dylib come from a
# Homebrew keg — and a keg only ever holds the host architecture. Building the app
# for both slices therefore fails to link the x86_64 half, and even if it linked,
# Tools/bundle-libssh2.sh would embed arm64-only dylibs and SFTP would break on
# Intel. So: fetch both architectures' bottles and lipo the dylibs together.
#
# The bottles are pulled straight from Homebrew's registry rather than via
# `brew fetch --bottle-tag`, which refuses a foreign architecture on an
# arm64 install ("Bottle for tag :tahoe is unavailable"). Downloads are checksum
# verified against the formula API. Consequently this script needs no Homebrew at
# all — only curl, python3 and the Xcode command line tools.
#
# Output layout (a drop-in replacement for the keg prefixes):
#   build/universal-deps/include/...          headers (architecture-independent)
#   build/universal-deps/lib/libssh2.1.dylib  2-slice, id = @rpath/...
#   build/universal-deps/lib/libssl.3.dylib
#   build/universal-deps/lib/libcrypto.3.dylib
#
# Idempotent: re-running with the output already universal is a no-op.
# Called by Tools/make-dmg.sh; safe to run on its own to inspect the result.
set -euo pipefail

cd "$(dirname "$0")/.."

OUT="build/universal-deps"
STAGE="build/universal-deps-stage"
LIB="$OUT/lib"
INC="$OUT/include"
DYLIBS=(libssh2.1.dylib libssl.3.dylib libcrypto.3.dylib)

# --- Already done? -----------------------------------------------------------
all_universal() {
  local d
  for d in "${DYLIBS[@]}"; do
    [ -f "$LIB/$d" ] || return 1
    lipo -archs "$LIB/$d" 2>/dev/null | grep -q arm64  || return 1
    lipo -archs "$LIB/$d" 2>/dev/null | grep -q x86_64 || return 1
  done
  [ -f "$INC/libssh2.h" ] || return 1
  # Unversioned aliases too, so a prefix staged by an older revision of this
  # script (which lacked them) is rebuilt rather than silently reused.
  for d in libssh2.dylib libssl.dylib libcrypto.dylib; do
    [ -e "$LIB/$d" ] || return 1
  done
}
if all_universal; then
  echo "==> $OUT already universal — nothing to do"
  exit 0
fi

# --- Fetch + verify + unpack both architectures ------------------------------
# The heredoc lives in a function: bash 3.2 (macOS /bin/bash) mis-parses a
# heredoc written directly inside $( ).
fetch_bottles() {
  STAGE="$1" python3 - <<'PY'
import hashlib, json, os, sys, tarfile, urllib.request

STAGE = os.environ["STAGE"]
FORMULAE = ["libssh2", "openssl@3"]
API = "https://formulae.brew.sh/api/formula/{}.json"
# Homebrew's own anonymous token for its ghcr.io registry.
HEADERS = {"Authorization": "Bearer QQ=="}


def api(formula):
    with urllib.request.urlopen(API.format(formula.replace("@", "%40")), timeout=60) as r:
        return json.load(r)["bottle"]["stable"]["files"]


files = {f: api(f) for f in FORMULAE}

# Homebrew names macOS bottles <codename> for x86_64 and arm64_<codename> for
# Apple Silicon. Don't hardcode a codename (they change every year, and a stale
# one is exactly how the Xcode pin broke): pick the newest the API offers for
# both architectures of both formulae. Dict order is the API's own, newest first.
codename = None
for tag in files[FORMULAE[0]]:
    if not tag.startswith("arm64_") or tag == "arm64_linux":
        continue
    name = tag[len("arm64_"):]
    if all(t in files[f] for f in FORMULAE for t in (tag, name)):
        codename = name
        break
if not codename:
    sys.exit("error: no macOS codename has both arm64 and x86_64 bottles for " + ", ".join(FORMULAE))

tags = {"arm64": "arm64_" + codename, "x86_64": codename}
print(f"==> bottle tags: {tags['arm64']} (arm64) + {tags['x86_64']} (x86_64)", file=sys.stderr)

for arch, tag in tags.items():
    dest = os.path.join(STAGE, arch)
    os.makedirs(dest, exist_ok=True)
    for formula in FORMULAE:
        spec = files[formula][tag]
        print(f"--> {formula} [{tag}]", file=sys.stderr)
        req = urllib.request.Request(spec["url"], headers=HEADERS)
        with urllib.request.urlopen(req, timeout=300) as r:
            blob = r.read()
        got = hashlib.sha256(blob).hexdigest()
        if got != spec["sha256"]:
            sys.exit(f"error: checksum mismatch for {formula} [{tag}]:\n  expected {spec['sha256']}\n  got      {got}")
        archive = os.path.join(dest, f"{formula.replace('@','-')}.tar.gz")
        with open(archive, "wb") as fh:
            fh.write(blob)
        with tarfile.open(archive) as tf:
            tf.extractall(dest)          # trusted, checksum-verified Homebrew bottle
        os.remove(archive)

print(codename)
PY
}

rm -rf "$STAGE" "$OUT"
mkdir -p "$STAGE" "$LIB" "$INC"
fetch_bottles "$STAGE" >/dev/null

# A bottle unpacks to <name>/<version>/…; resolve each keg's real prefix.
keg() {  # keg <arch> <formula-dir-name>
  local d
  d="$(find "$STAGE/$1/$2" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)"
  [ -n "$d" ] || { echo "error: no keg for $2 ($1)" >&2; exit 1; }
  printf '%s' "$d"
}

ARM_SSH2="$(keg arm64 libssh2)";   X86_SSH2="$(keg x86_64 libssh2)"
ARM_SSL="$(keg  arm64 openssl@3)"; X86_SSL="$(keg  x86_64 openssl@3)"

# --- Headers (architecture-independent; take the arm64 copies) ---------------
cp -R "$ARM_SSH2/include/." "$INC/"
cp -R "$ARM_SSL/include/."  "$INC/"

# --- lipo the dylibs ---------------------------------------------------------
merge() {  # merge <basename> <arm-keg> <x86-keg>
  local base="$1" a="$2/lib/$1" x="$3/lib/$1"
  [ -f "$a" ] || { echo "error: missing $a" >&2; exit 1; }
  [ -f "$x" ] || { echo "error: missing $x" >&2; exit 1; }
  lipo -create "$a" "$x" -output "$LIB/$base"
  chmod u+w "$LIB/$base"
  # @rpath id up front, so the copies bundled into the app need no rewriting.
  # The "invalidates the code signature" warnings are expected — every dylib is
  # re-signed ad-hoc below — so drop just those and keep any real diagnostics.
  install_name_tool -id "@rpath/$base" "$LIB/$base" 2>&1 \
    | grep -v "will invalidate the code signature" || true
}
merge libssh2.1.dylib   "$ARM_SSH2" "$X86_SSH2"
merge libssl.3.dylib    "$ARM_SSL"  "$X86_SSL"
merge libcrypto.3.dylib "$ARM_SSL"  "$X86_SSL"

# Unversioned aliases, exactly as a keg carries them: the linker resolves -lssh2
# through libssh2.dylib, so without these it silently falls back to the Homebrew
# keg on the search path and the x86_64 slice fails to link.
ln -sf libssh2.1.dylib   "$LIB/libssh2.dylib"
ln -sf libssl.3.dylib    "$LIB/libssl.dylib"
ln -sf libcrypto.3.dylib "$LIB/libcrypto.dylib"

# --- Rewrite cross-references among them to @rpath ---------------------------
for base in "${DYLIBS[@]}"; do
  otool -L "$LIB/$base" | awk 'NR>1{print $1}' | while read -r dep; do
    case "$dep" in
      */libssh2.*.dylib|*/libssl.*.dylib|*/libcrypto.*.dylib)
        install_name_tool -change "$dep" "@rpath/$(basename "$dep")" "$LIB/$base" 2>&1 \
          | grep -v "will invalidate the code signature" || true ;;
    esac
  done
  codesign --force --sign - "$LIB/$base" 2>/dev/null || true
done

rm -rf "$STAGE"

all_universal || { echo "error: output is not universal after merging" >&2; exit 1; }

echo "==> universal deps in $OUT"
for base in "${DYLIBS[@]}"; do
  printf '    %-20s %s\n' "$base" "$(lipo -archs "$LIB/$base")"
done
