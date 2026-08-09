#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# verify-shipping.sh — guard the two promises the release makes about plugins and slices.
#
#   Tools/verify-shipping.sh                 # static checks only (fast, no build needed)
#   Tools/verify-shipping.sh path/to/App.app # plus: every Mach-O inside is universal
#
# Both checks exist because both promises were broken silently before:
#
#   1. Every shipping plugin is actually in the shipping set. The CSV lister lived in
#      Plugins/ for weeks without being built into the app.
#   2. Every Mach-O in the shipped bundle is arm64 + x86_64. Twelve plugins were
#      host-architecture-only inside a "universal" DMG, and the CSV lister nearly repeated
#      it, because its build script had never been routed through pc-universal.sh.
#
# RELEASE.md documented check 2 as a one-liner to run by hand, which is exactly why nobody
# ran it. make-dmg.sh now calls this before creating the image.
set -uo pipefail
cd "$(dirname "$0")/.."

APP="${1:-}"
FAILED=0
fail() { echo "  ✗ $*" >&2; FAILED=1; }

# ── 1. Shipping set completeness ─────────────────────────────────────────────
# Plugins/Sample* are SDK examples, Plugins/SDK is the SDK itself — neither ships.
echo "==> Checking every shipping plugin is in build-all-plugins.sh"
SCRIPTS="$(sed -n '/^SCRIPTS=(/,/^)/p' Tools/build-all-plugins.sh | grep -oE 'build-[a-z0-9-]+')"
[ -n "$SCRIPTS" ] || { echo "  ✗ could not read the SCRIPTS list" >&2; exit 1; }

for dir in Plugins/*/; do
  name="$(basename "$dir")"
  case "$name" in Sample*|SDK) continue ;; esac
  # A plugin counts as covered when some listed script references its directory (one script
  # can build several bundles — build-pfx-plugins does WebDAV and ICloud).
  covered=0
  for s in $SCRIPTS; do
    [ -f "Tools/$s.sh" ] || continue
    if grep -q "Plugins/$name\b" "Tools/$s.sh"; then covered=1; break; fi
  done
  if [ "$covered" = 1 ]; then
    echo "  ✓ $name"
  else
    fail "$name is in Plugins/ but no script in build-all-plugins.sh builds it — it would not ship"
  fi
done

# ── 1b. Nothing half-built in a release ──────────────────────────────────────
# A plugin under construction still has to be in the shipping set: that is how it gets built, loaded
# and exercised in the VM, and how removability is proved before there is anything to lose. What it
# must not do is reach a user. A plugin declares `PCPluginIncomplete` in its Info.plist while it is
# scaffolding, and that is fatal here — but only when an actual bundle is being checked, which is the
# release path (make-dmg.sh passes one; CI's static run does not). So development stays unblocked and
# a DMG cannot be built by accident.
if [ -n "$APP" ]; then
  echo "==> Checking no plugin is still marked incomplete"
  for plist in Plugins/*/Info.plist; do
    name="$(basename "$(dirname "$plist")")"
    case "$name" in Sample*|SDK) continue ;; esac
    if /usr/libexec/PlistBuddy -c "Print :PCPluginIncomplete" "$plist" >/dev/null 2>&1; then
      fail "$name declares PCPluginIncomplete — finish it or take it out of build-all-plugins.sh"
    fi
  done
fi

# ── 2. Universality of the shipped bundle ────────────────────────────────────
if [ -n "$APP" ]; then
  [ -d "$APP" ] || { echo "  ✗ no such app bundle: $APP" >&2; exit 1; }
  echo "==> Checking every Mach-O in $(basename "$APP") is arm64 + x86_64"
  total=0
  while IFS= read -r f; do
    archs="$(lipo -archs "$f" 2>/dev/null)" || continue
    [ -n "$archs" ] || continue
    total=$((total + 1))
    case "$archs" in
      *arm64*) case "$archs" in *x86_64*) ;; *) fail "single-architecture ($archs): ${f#"$APP/"}" ;; esac ;;
      *) fail "single-architecture ($archs): ${f#"$APP/"}" ;;
    esac
  done < <(find "$APP" -type f)
  echo "  checked $total Mach-O binaries"
fi

if [ "$FAILED" = 0 ]; then
  echo "==> OK"
else
  echo "==> FAILED — see above" >&2
fi
exit "$FAILED"
