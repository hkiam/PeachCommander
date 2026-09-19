#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# codesign-app.sh — seal a built PeachCommander.app.
#
# Usage: codesign-app.sh <path-to-.app>
#
# PC_CODESIGN_IDENTITY picks the identity; without one the app is signed AD-HOC
# ("-"), which is free, needs no Apple account and never expires. It is not a
# substitute for Developer ID — Gatekeeper still treats the build as coming from
# an unidentified developer — but it is what gives the bundle a seal, and macOS 27
# stores no TCC folder permission for a bundle without one: the app asked for
# Desktop, Documents and Downloads on every access and forgot the answer each time
# (issue #3). This used to return early with no identity, so no build was ever
# sealed and the defect that made sealing fail at all (a stray .build-stamps
# directory inside Contents/PlugIns, see build-all-plugins.sh) stayed hidden.
#
# Called by Tools/make-dmg.sh *before* the disk image is created — signing after
# packaging would leave the app inside the DMG unsigned.
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

[ -f "$ENTITLEMENTS" ] || { echo "error: entitlements not found: $ENTITLEMENTS" >&2; exit 1; }

ID="${PC_CODESIGN_IDENTITY:--}"
COMMON=(--force --options runtime --sign "$ID")
if [ "$ID" = "-" ]; then
  echo "==> No PC_CODESIGN_IDENTITY — sealing the app ad-hoc (not Developer ID)"
else
  # --timestamp needs network access, and a notarized build requires the secure timestamp. An ad-hoc
  # signature cannot carry one, so asking would spend a round trip per file to be refused.
  COMMON+=(--timestamp)
fi

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
