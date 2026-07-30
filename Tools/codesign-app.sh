#!/usr/bin/env bash
# codesign-app.sh — sign a built PeachCommander.app for Developer ID distribution.
#
# Usage: codesign-app.sh <path-to-.app>
#
# No-op unless PC_CODESIGN_IDENTITY is set, so the ordinary unsigned build path is
# unchanged. Called by Tools/make-dmg.sh *before* the disk image is created —
# signing after packaging would leave the app inside the DMG unsigned.
#
# Signs inside-out (nested code first, the app bundle last), which is what
# codesign requires; --deep is explicitly not used, since Apple documents it as
# unsuitable for signing for distribution and it would apply the app's
# entitlements to nested code.
#
# Entitlements come from Resources/PeachCommander.entitlements: no App Sandbox
# (a file manager needs the whole disk), hardened runtime on, library validation
# relaxed so third-party plugins can be loaded. See ADR-006 / arch-security.
set -euo pipefail

APP="${1:?usage: codesign-app.sh <path-to-.app>}"
cd "$(dirname "$0")/.."
ENTITLEMENTS="$PWD/Resources/PeachCommander.entitlements"

if [ -z "${PC_CODESIGN_IDENTITY:-}" ]; then
  echo "==> PC_CODESIGN_IDENTITY not set — leaving the app ad-hoc signed (UNSIGNED build)"
  exit 0
fi
[ -f "$ENTITLEMENTS" ] || { echo "error: entitlements not found: $ENTITLEMENTS" >&2; exit 1; }

ID="$PC_CODESIGN_IDENTITY"
# --timestamp needs network access; a notarized build requires the secure timestamp.
COMMON=(--force --timestamp --options runtime --sign "$ID")

echo "==> Signing nested code…"
# Embedded dylibs and frameworks. Nested code carries no entitlements of its own.
while IFS= read -r f; do
  codesign "${COMMON[@]}" "$f"
done < <(find "$APP/Contents/Frameworks" -maxdepth 1 \( -name '*.dylib' -o -name '*.framework' \) 2>/dev/null)

echo "==> Signing plugins…"
for plugin in "$APP"/Contents/PlugIns/*; do
  [ -e "$plugin" ] || continue
  codesign "${COMMON[@]}" "$plugin"
done

echo "==> Signing the app bundle…"
codesign "${COMMON[@]}" --entitlements "$ENTITLEMENTS" "$APP"

echo "==> Verifying…"
# --strict --deep here is verification, not signing: it walks the whole bundle.
codesign --verify --deep --strict --verbose=2 "$APP"
echo "==> Signed with: $ID"
