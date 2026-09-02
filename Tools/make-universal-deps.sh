#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
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
        return json.load(r)


meta = {f: api(f) for f in FORMULAE}
files = {f: meta[f]["bottle"]["stable"]["files"] for f in FORMULAE}


def newest(formula, arch):
    """The newest macOS bottle tag this formula has for `arch`, or None.

    Homebrew names macOS bottles <codename> for x86_64 and arm64_<codename> for Apple Silicon, and
    the API's dict order is its own — newest first. Never hardcode a codename: they change every
    year, and a stale one is exactly how the Xcode pin broke once.

    Asked **per formula and per architecture**, which is the part that had to change. Requiring one
    codename serving both architectures of both formulae stopped working the day Homebrew dropped
    Intel macOS bottles for openssl@3 — four days after it last worked — because the two formulae
    then overlapped nowhere and the release refused to package at all.
    """
    for tag in files[formula]:
        if arch == "arm64":
            if tag.startswith("arm64_") and tag != "arm64_linux":
                return tag
        elif not tag.startswith("arm64_") and not tag.endswith("_linux"):
            return tag
    return None


missing = []
for arch in ("arm64", "x86_64"):
    dest = os.path.join(STAGE, arch)
    os.makedirs(dest, exist_ok=True)
    for formula in FORMULAE:
        tag = newest(formula, arch)
        if tag is None:
            # No bottle for this slice. Nothing here can invent one, so the caller is told what to
            # build from source instead — with the formula's *own* stable version and checksum, so
            # the slice that gets built is the same release as the slice that gets fetched.
            if arch != "x86_64":
                sys.exit("error: %s has no arm64 macOS bottle - nothing to build against" % formula)
            stable = meta[formula]["urls"]["stable"]
            missing.append((formula, meta[formula]["versions"]["stable"],
                            stable["url"], stable.get("checksum", "")))
            print("--> %s [x86_64]: no bottle; will build from source" % formula, file=sys.stderr)
            continue
        spec = files[formula][tag]
        print("--> %s [%s]" % (formula, tag), file=sys.stderr)
        req = urllib.request.Request(spec["url"], headers=HEADERS)
        with urllib.request.urlopen(req, timeout=300) as r:
            blob = r.read()
        got = hashlib.sha256(blob).hexdigest()
        if got != spec["sha256"]:
            sys.exit("error: checksum mismatch for %s [%s]:\n  expected %s\n  got      %s"
                     % (formula, tag, spec["sha256"], got))
        archive = os.path.join(dest, "%s.tar.gz" % formula.replace("@", "-"))
        with open(archive, "wb") as fh:
            fh.write(blob)
        with tarfile.open(archive) as tf:
            tf.extractall(dest)          # trusted, checksum-verified Homebrew bottle
        os.remove(archive)

# One line per slice the caller has to build itself: formula, version, url, sha256.
for formula, version, url, sha in missing:
    print("source\t%s\t%s\t%s\t%s" % (formula, version, url, sha))
PY
}

# --- Build one x86_64 slice from source, when Homebrew has no bottle for it ---
#
# Only openssl@3, and deliberately so: it is the formula that lost its Intel bottles, and libssh2
# needs an openssl to build *against*, so a general "build anything" here would be a build system
# rather than a fallback. If libssh2 ever loses its x86_64 bottle too, this stops with a sentence
# saying exactly that instead of half working.
#
# Cross-compiling on Apple Silicon is what OpenSSL's own `darwin64-x86_64` target is for: it sets
# `-arch x86_64`, and 3.x generates its assembly with perl rather than with compiled helpers, so
# nothing has to *run* what is being built. `no-tests`/`no-docs` because neither is shipped.
#
# The version and the checksum come from the same formula API the bottles do, so the slice that is
# built is the same OpenSSL release as the arm64 slice that is fetched — not merely a compatible one.
build_source_slice() {  # <formula> <version> <url> <sha256> <arch-stage>
  local formula="$1" version="$2" url="$3" sha="$4" stage="$5"
  if [ "$formula" != "openssl@3" ]; then
    echo "error: no source build for $formula. Homebrew dropped its x86_64 macOS bottle and this" >&2
    echo "       script only knows how to build openssl@3 (see the comment above it)." >&2
    exit 1
  fi
  # `--libdir=lib` is not decoration: without it OpenSSL's `mkinstallvars.pl` resolves LIBDIR to
  # the *source* directory and prints a page of "uninitialized value" warnings while doing it. The
  # install still landed in the right place, which is the kind of luck worth removing.
  local work="$stage/.src" prefix="$stage/openssl@3/$version"
  mkdir -p "$work" "$prefix"
  echo "==> no x86_64 bottle for openssl@3 — building $version from source"
  curl -fsSL "$url" -o "$work/openssl.tar.gz"
  if [ -n "$sha" ]; then
    local got
    got="$(shasum -a 256 "$work/openssl.tar.gz" | awk '{print $1}')"
    if [ "$got" != "$sha" ]; then
      echo "error: checksum mismatch for the openssl source:" >&2
      echo "  expected $sha" >&2
      echo "  got      $got" >&2
      exit 1
    fi
  fi
  tar xzf "$work/openssl.tar.gz" -C "$work"
  local abs log
  abs="$(cd "$prefix" && pwd)"
  # Logged rather than silenced. OpenSSL 3.6's `mkinstallvars.pl` prints a page of DEBUG lines and
  # perl "uninitialized value" warnings while installing, even when everything is right — noise that
  # would bury a real problem in a release log. So the whole build goes to a file, which is thrown
  # away on success and printed on failure. Nothing is hidden; it is just not read out when it went
  # well.
  log="$stage/openssl-build.log"
  if ! ( cd "$work/openssl-$version" \
           && ./Configure darwin64-x86_64 shared no-tests no-docs \
                --prefix="$abs" --openssldir="$abs/etc" --libdir=lib \
           && make -j"$(sysctl -n hw.ncpu)" build_sw \
           && make install_sw ) >"$log" 2>&1; then
    echo "error: building openssl $version for x86_64 failed; last 40 lines:" >&2
    tail -40 "$log" >&2
    exit 1
  fi
  rm -f "$log"
  rm -rf "$work"
  # The layout the rest of this script expects from a keg: <formula>/<version>/{lib,include}.
  if [ ! -f "$prefix/lib/libssl.3.dylib" ]; then
    echo "error: the source build left no libssl.3.dylib in $prefix/lib" >&2
    exit 1
  fi
  if ! lipo -archs "$prefix/lib/libssl.3.dylib" | grep -qw x86_64; then
    echo "error: the source build produced no x86_64 slice. OpenSSL's darwin64-x86_64 target may" >&2
    echo "       no longer cross-compile on this host, which is the point at which shipping a" >&2
    echo "       universal binary needs a different answer (see RELEASE.md)." >&2
    exit 1
  fi
}

rm -rf "$STAGE" "$OUT"
mkdir -p "$STAGE" "$LIB" "$INC"
# Anything with no bottle comes back as `source<TAB>formula<TAB>version<TAB>url<TAB>sha256`.
while IFS="$(printf '\t')" read -r kind formula version url sha; do
  [ "$kind" = "source" ] || continue
  build_source_slice "$formula" "$version" "$url" "$sha" "$STAGE/x86_64"
done < <(fetch_bottles "$STAGE")

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
