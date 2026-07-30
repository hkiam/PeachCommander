#!/usr/bin/env bash
# bundle-libssh2.sh — embed libssh2 + its openssl@3 deps into an .app so SFTP
# (F-214) works on machines without Homebrew. Copies the dylibs into
# Contents/Frameworks, rewrites every install name to @rpath, and re-signs
# ad-hoc. Idempotent; safe to re-run. Called by Tools/make-dmg.sh.
set -euo pipefail

APP="${1:?usage: bundle-libssh2.sh <path-to-.app>}"
FW="$APP/Contents/Frameworks"
mkdir -p "$FW"

# PC_SSH2_PREFIX (set by make-dmg.sh) points at build/universal-deps, which holds
# arm64+x86_64 dylibs and carries openssl alongside libssh2 in one lib dir. Without
# it, fall back to the Homebrew kegs — fine for a host-architecture-only build, but
# note a keg is single-architecture, so a universal app needs the prefix.
if [ -n "${PC_SSH2_PREFIX:-}" ] && [ -d "$PC_SSH2_PREFIX/lib" ]; then
  SSH2_LIB="$PC_SSH2_PREFIX/lib"
  SSL_LIB="$PC_SSH2_PREFIX/lib"
else
  SSH2_LIB="$(brew --prefix libssh2 2>/dev/null)/lib"
  SSL_LIB="$(brew --prefix openssl@3 2>/dev/null)/lib"
fi
[ -d "$SSH2_LIB" ] || { echo "error: libssh2 not found (brew install libssh2, or set PC_SSH2_PREFIX)" >&2; exit 1; }

SOURCES=(
  "$SSH2_LIB/libssh2.1.dylib"
  "$SSL_LIB/libssl.3.dylib"
  "$SSL_LIB/libcrypto.3.dylib"
)
BASES=(libssh2.1.dylib libssl.3.dylib libcrypto.3.dylib)

# 1) Copy + set each dylib's own id to @rpath.
for src in "${SOURCES[@]}"; do
  base="$(basename "$src")"
  cp -f "$src" "$FW/$base"
  chmod u+w "$FW/$base"
  install_name_tool -id "@rpath/$base" "$FW/$base"
done

# Rewrite any absolute libssh2/libssl/libcrypto reference in `$1` to @rpath.
fix_refs() {
  local target="$1"
  otool -L "$target" 2>/dev/null | awk 'NR>1{print $1}' | while read -r dep; do
    case "$dep" in
      */libssh2.*.dylib|*/libssl.*.dylib|*/libcrypto.*.dylib)
        install_name_tool -change "$dep" "@rpath/$(basename "$dep")" "$target" ;;
    esac
  done
}

# 2) Fix cross-references among the bundled dylibs.
for base in "${BASES[@]}"; do fix_refs "$FW/$base"; done

# 3) Fix every Mach-O in the app that still points at the Homebrew libs
#    (PCNet.framework — inside Frameworks — and the app binary if a release build
#    links it directly). fix_refs is idempotent, so re-touching the bundled
#    dylibs is harmless.
while IFS= read -r f; do
  if otool -L "$f" 2>/dev/null | grep -qE "/opt/homebrew.*/lib(ssh2|ssl|crypto)\."; then fix_refs "$f"; fi
done < <(find "$APP" -type f)

# 4) Ensure the main executable can find @rpath libs (usually already present).
MAIN="$APP/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist" 2>/dev/null || echo PeachCommander)"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MAIN" 2>/dev/null || true

# 5) Ad-hoc re-sign the binaries we modified (invalidated their signatures).
for base in "${BASES[@]}"; do codesign --force --sign - "$FW/$base" 2>/dev/null || true; done
codesign --force --sign - "$MAIN" 2>/dev/null || true

echo "Bundled libssh2 (+ openssl) into $FW"
